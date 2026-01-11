function Get-PatSyncPlan {
    <#
    .SYNOPSIS
        Generates a sync plan for transferring media from a Plex playlist to a destination.

    .DESCRIPTION
        Analyzes a Plex playlist and compares it against the destination folder to determine
        what files need to be added or removed. Calculates space requirements and verifies
        available disk space.

    .PARAMETER PlaylistName
        The name of the playlist to sync. Defaults to 'Travel'. Supports tab completion.

    .PARAMETER PlaylistId
        The unique identifier of the playlist to sync. Use this instead of PlaylistName
        when you need to specify a playlist by its numeric ID.

    .PARAMETER Destination
        The destination path where media files will be synced (e.g., 'E:\' for a USB drive).

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server. If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .EXAMPLE
        Get-PatSyncPlan -Destination 'E:\'

        Shows what files would be synced from the default 'Travel' playlist to drive E:.

    .EXAMPLE
        Get-PatSyncPlan -Destination 'E:\' -ServerName 'Home'

        Shows sync plan for the 'Travel' playlist on the stored server named 'Home'.

    .EXAMPLE
        Get-PatSyncPlan -PlaylistName 'Vacation' -Destination 'D:\PlexMedia'

        Shows the sync plan for the 'Vacation' playlist.

    .OUTPUTS
        PlexAutomationToolkit.SyncPlan

        Object with properties:
        - PlaylistName: Name of the playlist
        - PlaylistId: ID of the playlist
        - Destination: Target path
        - TotalItems: Total items in playlist
        - ItemsToAdd: Number of items to download
        - ItemsToRemove: Number of items to delete
        - ItemsUnchanged: Number of items already synced
        - BytesToDownload: Total bytes to download
        - BytesToRemove: Total bytes to free by removal
        - DestinationFree: Current free space at destination
        - DestinationAfter: Projected free space after sync
        - SpaceSufficient: Whether there's enough space
        - AddOperations: Array of items to add
        - RemoveOperations: Array of items to remove
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $PlaylistName = 'Travel',

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,

        [Parameter(Mandatory = $false)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
    }

    process {
        try {
            # Resolve destination to absolute path early
            $resolvedDestination = [System.IO.Path]::GetFullPath($Destination)
            Write-Verbose "Resolved destination path: $resolvedDestination"

            # Get the playlist - build parameters based on server context
            $serverSplat = Build-PatServerSplat -WasExplicitUri $script:serverContext.WasExplicitUri `
                -ServerUri $ServerUri -Token $Token -ServerName $ServerName
            $playlistParameters = @{
                IncludeItems = $true
                ErrorAction  = 'Stop'
            } + $serverSplat

            if ($PlaylistId) {
                $playlistParameters['PlaylistId'] = $PlaylistId
            }
            else {
                $playlistParameters['PlaylistName'] = $PlaylistName
            }

            Write-Verbose "Retrieving playlist..."
            $playlist = Get-PatPlaylist @playlistParameters

            if (-not $playlist) {
                throw "Playlist not found"
            }

            Write-Verbose "Playlist '$($playlist.Title)' has $($playlist.ItemCount) items"

            # Get media info for each playlist item (cache results to avoid redundant API calls)
            $addOperations = [System.Collections.Generic.List[PSCustomObject]]::new()
            $totalBytesToDownload = 0
            $mediaInformationCache = @{}

            if ($playlist.Items -and $playlist.Items.Count -gt 0) {
                $itemCount = 0
                foreach ($item in $playlist.Items) {
                    $itemCount++
                    Write-Verbose "Analyzing item $itemCount of $($playlist.Items.Count): $($item.Title)"

                    $mediaInformationParameters = @{
                        RatingKey   = $item.RatingKey
                        ErrorAction = 'Stop'
                    } + $serverSplat

                    $mediaInformation = Get-PatMediaInfo @mediaInformationParameters

                    # Cache media info for reuse when building expected paths
                    $mediaInformationCache[$item.RatingKey] = $mediaInformation

                    # Check if this item needs to be downloaded
                    $addOperation = Get-PatSyncAddOperation -MediaInfo $mediaInformation -BasePath $resolvedDestination

                    if ($addOperation) {
                        $addOperations.Add($addOperation)
                        $totalBytesToDownload += $addOperation.MediaSize
                    }
                    elseif (-not $mediaInformation.Media -or $mediaInformation.Media.Count -eq 0) {
                        Write-Warning "No media files found for '$($item.Title)'"
                    }
                    elseif (-not $mediaInformation.Media[0].Part -or $mediaInformation.Media[0].Part.Count -eq 0) {
                        Write-Warning "No media parts found for '$($item.Title)'"
                    }
                }
            }

            # Build expected paths from playlist items
            $expectedPaths = @{}
            foreach ($op in $addOperations) {
                $expectedPaths[$op.DestinationPath] = $true
            }

            # Also mark existing items that don't need download (use cached media info)
            if ($playlist.Items) {
                foreach ($item in $playlist.Items) {
                    # Use cached media info instead of making another API call
                    $mediaInformation = $mediaInformationCache[$item.RatingKey]
                    if ($mediaInformation -and $mediaInformation.Media -and $mediaInformation.Media.Count -gt 0) {
                        $media = $mediaInformation.Media[0]
                        if ($media.Part -and $media.Part.Count -gt 0) {
                            $extension = if ($media.Part[0].Container) { $media.Part[0].Container } else { 'mkv' }
                            $destPath = Get-PatMediaPath -MediaInfo $mediaInformation -BasePath $resolvedDestination -Extension $extension
                            $expectedPaths[$destPath] = $true
                        }
                    }
                }
            }

            # Scan destination for files to remove (items not in playlist)
            $moviesPath = [System.IO.Path]::Combine($resolvedDestination, 'Movies')
            $tvPath = [System.IO.Path]::Combine($resolvedDestination, 'TV Shows')

            $movieRemoveResult = Get-PatSyncRemoveOperation -FolderPath $moviesPath -ExpectedPaths $expectedPaths -MediaType 'movie'
            $tvRemoveResult = Get-PatSyncRemoveOperation -FolderPath $tvPath -ExpectedPaths $expectedPaths -MediaType 'episode'

            $removeOperations = [System.Collections.Generic.List[PSCustomObject]]::new()
            if ($movieRemoveResult.Operations) {
                $movieRemoveResult.Operations | ForEach-Object { $removeOperations.Add($_) }
            }
            if ($tvRemoveResult.Operations) {
                $tvRemoveResult.Operations | ForEach-Object { $removeOperations.Add($_) }
            }
            $totalBytesToRemove = $movieRemoveResult.TotalBytes + $tvRemoveResult.TotalBytes

            # Get destination drive info
            $destinationFree = Get-PatDestinationFreeSpace -Path $resolvedDestination

            # Calculate projected space
            $spaceNeeded = $totalBytesToDownload - $totalBytesToRemove
            $destinationAfter = $destinationFree - $spaceNeeded
            $spaceSufficient = $destinationAfter -ge 0

            # Count unchanged items
            $itemsUnchanged = 0
            if ($playlist.Items) {
                $itemsUnchanged = $playlist.Items.Count - $addOperations.Count
            }

            # Build sync plan
            $syncPlan = [PSCustomObject]@{
                PSTypeName       = 'PlexAutomationToolkit.SyncPlan'
                PlaylistName     = $playlist.Title
                PlaylistId       = $playlist.PlaylistId
                Destination      = $resolvedDestination
                TotalItems       = if ($playlist.Items) { $playlist.Items.Count } else { 0 }
                ItemsToAdd       = $addOperations.Count
                ItemsToRemove    = $removeOperations.Count
                ItemsUnchanged   = $itemsUnchanged
                BytesToDownload  = $totalBytesToDownload
                BytesToRemove    = $totalBytesToRemove
                DestinationFree  = $destinationFree
                DestinationAfter = $destinationAfter
                SpaceSufficient  = $spaceSufficient
                AddOperations    = $addOperations
                RemoveOperations = $removeOperations
                ServerUri        = $effectiveUri
            }

            $syncPlan
        }
        catch {
            throw "Failed to generate sync plan: $($_.Exception.Message)"
        }
    }
}
