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

    .PARAMETER ServerUri
        The base URI of the Plex server. If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .EXAMPLE
        Get-PatSyncPlan -Destination 'E:\'

        Shows what files would be synced from the default 'Travel' playlist to drive E:.

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
        # Use default server if ServerUri not specified
        $server = $null
        $effectiveUri = $ServerUri
        if (-not $ServerUri) {
            try {
                $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
                if (-not $server) {
                    throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
                }
                $effectiveUri = $server.uri
                Write-Verbose "Using default server: $effectiveUri"
            }
            catch {
                throw "Failed to get default server: $($_.Exception.Message)"
            }
        }
    }

    process {
        try {
            # Resolve destination to absolute path early
            $resolvedDestination = [System.IO.Path]::GetFullPath($Destination)
            Write-Verbose "Resolved destination path: $resolvedDestination"

            # Get the playlist
            $playlistParams = @{
                IncludeItems = $true
                ErrorAction  = 'Stop'
            }
            if ($effectiveUri -and -not $ServerUri) {
                # Using default server, don't pass ServerUri
            }
            elseif ($ServerUri) {
                $playlistParams['ServerUri'] = $ServerUri
                if ($Token) {
                    $playlistParams['Token'] = $Token
                }
            }

            if ($PlaylistId) {
                $playlistParams['PlaylistId'] = $PlaylistId
            }
            else {
                $playlistParams['PlaylistName'] = $PlaylistName
            }

            Write-Verbose "Retrieving playlist..."
            $playlist = Get-PatPlaylist @playlistParams

            if (-not $playlist) {
                throw "Playlist not found"
            }

            Write-Verbose "Playlist '$($playlist.Title)' has $($playlist.ItemCount) items"

            # Get media info for each playlist item (cache results to avoid redundant API calls)
            $addOperations = @()
            $totalBytesToDownload = 0
            $mediaInfoCache = @{}

            if ($playlist.Items -and $playlist.Items.Count -gt 0) {
                $itemCount = 0
                foreach ($item in $playlist.Items) {
                    $itemCount++
                    Write-Verbose "Analyzing item $itemCount of $($playlist.Items.Count): $($item.Title)"

                    $mediaInfoParams = @{
                        RatingKey   = $item.RatingKey
                        ErrorAction = 'Stop'
                    }
                    if ($ServerUri) {
                        $mediaInfoParams['ServerUri'] = $ServerUri
                    }
                    if ($Token) {
                        $mediaInfoParams['Token'] = $Token
                    }

                    $mediaInfo = Get-PatMediaInfo @mediaInfoParams

                    # Cache media info for reuse when building expected paths
                    $mediaInfoCache[$item.RatingKey] = $mediaInfo

                    if (-not $mediaInfo.Media -or $mediaInfo.Media.Count -eq 0) {
                        Write-Warning "No media files found for '$($item.Title)'"
                        continue
                    }

                    # Use the first media version (default behavior)
                    $media = $mediaInfo.Media[0]
                    if (-not $media.Part -or $media.Part.Count -eq 0) {
                        Write-Warning "No media parts found for '$($item.Title)'"
                        continue
                    }

                    $part = $media.Part[0]

                    # Determine destination path
                    $extension = if ($part.Container) { $part.Container } else { 'mkv' }
                    $destPath = Get-PatMediaPath -MediaInfo $mediaInfo -BasePath $resolvedDestination -Extension $extension

                    # Check if file already exists with correct size
                    $needsDownload = $true
                    if (Test-Path -Path $destPath) {
                        $existingFile = Get-Item -Path $destPath
                        if ($existingFile.Length -eq $part.Size) {
                            $needsDownload = $false
                            Write-Verbose "File already exists with correct size: $destPath"
                        }
                        else {
                            Write-Verbose "File exists but size mismatch: $destPath"
                        }
                    }

                    if ($needsDownload) {
                        # Count external subtitles
                        $subtitleCount = 0
                        if ($part.Streams) {
                            $subtitleCount = ($part.Streams | Where-Object { $_.StreamType -eq 3 -and $_.External }).Count
                        }

                        $addOperations += [PSCustomObject]@{
                            PSTypeName      = 'PlexAutomationToolkit.SyncAddOperation'
                            RatingKey       = $mediaInfo.RatingKey
                            Title           = $mediaInfo.Title
                            Type            = $mediaInfo.Type
                            Year            = $mediaInfo.Year
                            GrandparentTitle = $mediaInfo.GrandparentTitle
                            ParentIndex     = $mediaInfo.ParentIndex
                            Index           = $mediaInfo.Index
                            DestinationPath = $destPath
                            MediaSize       = $part.Size
                            SubtitleCount   = $subtitleCount
                            PartKey         = $part.Key
                            Container       = $part.Container
                        }

                        $totalBytesToDownload += $part.Size
                    }
                }
            }

            # Scan destination for files to remove (items not in playlist)
            $removeOperations = @()
            $totalBytesToRemove = 0

            $moviesPath = [System.IO.Path]::Combine($resolvedDestination, 'Movies')
            $tvPath = [System.IO.Path]::Combine($resolvedDestination, 'TV Shows')

            # Get all expected paths from playlist
            $expectedPaths = @{}
            foreach ($op in $addOperations) {
                $expectedPaths[$op.DestinationPath] = $true
            }

            # Also mark existing items that don't need download (use cached media info)
            if ($playlist.Items) {
                foreach ($item in $playlist.Items) {
                    # Use cached media info instead of making another API call
                    $mediaInfo = $mediaInfoCache[$item.RatingKey]
                    if ($mediaInfo -and $mediaInfo.Media -and $mediaInfo.Media.Count -gt 0) {
                        $media = $mediaInfo.Media[0]
                        if ($media.Part -and $media.Part.Count -gt 0) {
                            $extension = if ($media.Part[0].Container) { $media.Part[0].Container } else { 'mkv' }
                            $destPath = Get-PatMediaPath -MediaInfo $mediaInfo -BasePath $resolvedDestination -Extension $extension
                            $expectedPaths[$destPath] = $true
                        }
                    }
                }
            }

            # Find files to remove in Movies folder
            if (Test-Path -Path $moviesPath) {
                $movieFiles = Get-ChildItem -Path $moviesPath -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -match '\.(mkv|mp4|avi|m4v|mov|ts|wmv)$' }

                foreach ($file in $movieFiles) {
                    if (-not $expectedPaths.ContainsKey($file.FullName)) {
                        $removeOperations += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.SyncRemoveOperation'
                            Path       = $file.FullName
                            Size       = $file.Length
                            Type       = 'movie'
                        }
                        $totalBytesToRemove += $file.Length
                    }
                }
            }

            # Find files to remove in TV Shows folder
            if (Test-Path -Path $tvPath) {
                $tvFiles = Get-ChildItem -Path $tvPath -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -match '\.(mkv|mp4|avi|m4v|mov|ts|wmv)$' }

                foreach ($file in $tvFiles) {
                    if (-not $expectedPaths.ContainsKey($file.FullName)) {
                        $removeOperations += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.SyncRemoveOperation'
                            Path       = $file.FullName
                            Size       = $file.Length
                            Type       = 'episode'
                        }
                        $totalBytesToRemove += $file.Length
                    }
                }
            }

            # Get destination drive info
            $destinationFree = 0
            try {
                # Handle both drive letters and UNC paths
                if ($resolvedDestination -match '^([A-Z]):') {
                    $driveLetter = $Matches[1]
                    $drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
                    $destinationFree = $drive.Free
                }
                else {
                    # For UNC paths or when drive info isn't available, try filesystem info
                    $driveInfo = [System.IO.DriveInfo]::GetDrives() |
                        Where-Object { $resolvedDestination.StartsWith($_.Name, [StringComparison]::OrdinalIgnoreCase) } |
                        Select-Object -First 1
                    if ($driveInfo) {
                        $destinationFree = $driveInfo.AvailableFreeSpace
                    }
                }
            }
            catch {
                Write-Warning "Could not determine free space at destination: $($_.Exception.Message)"
            }

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
