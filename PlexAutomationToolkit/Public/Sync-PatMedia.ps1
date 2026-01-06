function Sync-PatMedia {
    <#
    .SYNOPSIS
        Syncs media from a Plex playlist to a destination folder.

    .DESCRIPTION
        Downloads media files from a Plex playlist to a destination folder with Plex-compatible
        folder structure. Optionally removes files at the destination that are not in the playlist.
        Supports subtitle downloads and progress reporting.

    .PARAMETER PlaylistName
        The name of the playlist to sync. Defaults to 'Travel'. Supports tab completion.

    .PARAMETER PlaylistId
        The unique identifier of the playlist to sync. Use this instead of PlaylistName
        when you need to specify a playlist by its numeric ID.

    .PARAMETER Destination
        The destination path where media files will be synced (e.g., 'E:\' for a USB drive).

    .PARAMETER SkipSubtitles
        When specified, does not download external subtitle files. By default, subtitles
        are included in the sync.

    .PARAMETER SkipRemoval
        When specified, does not remove files at the destination that are not in the playlist.

    .PARAMETER Force
        Skip the space sufficiency check and proceed even if there may not be enough space.

    .PARAMETER PassThru
        Returns the sync plan after completion.

    .PARAMETER ServerUri
        The base URI of the Plex server. If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER SyncWatchStatus
        After syncing media, compares watch status between the source and target servers and
        syncs watched items from the target (travel) server back to the source (home) server.
        Requires -SourceServerName and -TargetServerName parameters.

    .PARAMETER RemoveWatched
        After syncing, prompts to remove watched items from the playlist. Items are first
        marked as watched on the source server (if -SyncWatchStatus is also specified),
        then removed from the playlist. Requires -SourceServerName and -TargetServerName.

    .PARAMETER SourceServerName
        The name of the source (home) server for watch status operations. Required when
        using -SyncWatchStatus or -RemoveWatched.

    .PARAMETER TargetServerName
        The name of the target (travel/portable) server for watch status operations.
        Required when using -SyncWatchStatus or -RemoveWatched.

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\'

        Syncs the default 'Travel' playlist to drive E:, including subtitles.

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\' -SkipSubtitles

        Syncs the 'Travel' playlist without downloading external subtitles.

    .EXAMPLE
        Sync-PatMedia -PlaylistName 'Vacation' -Destination 'E:\' -WhatIf

        Shows what would be synced from the 'Vacation' playlist without making changes.

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\' -SourceServerName 'Home' -TargetServerName 'Travel' -SyncWatchStatus

        After vacation: syncs media and marks items watched on the travel server as watched on home.

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\' -SourceServerName 'Home' -TargetServerName 'Travel' -SyncWatchStatus -RemoveWatched

        Full vacation workflow: syncs media, syncs watch status, then removes watched items from playlist.

    .OUTPUTS
        PlexAutomationToolkit.SyncPlan (with -PassThru)
        Returns the sync plan with operation results.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
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
        [switch]
        $SkipSubtitles,

        [Parameter(Mandatory = $false)]
        [switch]
        $SkipRemoval,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $SyncWatchStatus,

        [Parameter(Mandatory = $false)]
        [switch]
        $RemoveWatched,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceServerName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetServerName
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
            # Get the sync plan
            $syncPlanParameters = @{
                Destination = $Destination
                ErrorAction = 'Stop'
            }
            if ($ServerUri) {
                $syncPlanParameters['ServerUri'] = $ServerUri
            }
            if ($Token) {
                $syncPlanParameters['Token'] = $Token
            }
            if ($PlaylistId) {
                $syncPlanParameters['PlaylistId'] = $PlaylistId
            }
            else {
                $syncPlanParameters['PlaylistName'] = $PlaylistName
            }

            Write-Verbose "Generating sync plan..."
            $syncPlan = Get-PatSyncPlan @syncPlanParameters

            # Display summary
            $downloadSizeGB = [math]::Round($syncPlan.BytesToDownload / 1GB, 2)
            $removeSizeGB = [math]::Round($syncPlan.BytesToRemove / 1GB, 2)

            Write-Verbose "Sync plan for playlist '$($syncPlan.PlaylistName)':"
            Write-Verbose "  Items to add: $($syncPlan.ItemsToAdd) ($downloadSizeGB GB)"
            Write-Verbose "  Items to remove: $($syncPlan.ItemsToRemove) ($removeSizeGB GB)"
            Write-Verbose "  Items unchanged: $($syncPlan.ItemsUnchanged)"

            # Check space
            if (-not $syncPlan.SpaceSufficient -and -not $Force) {
                $freeGB = [math]::Round($syncPlan.DestinationFree / 1GB, 2)
                throw "Insufficient space at destination. Free: $freeGB GB, Required: $downloadSizeGB GB. Use -Force to proceed anyway."
            }

            # Confirm with user
            $syncDescription = "Sync $($syncPlan.ItemsToAdd) items ($downloadSizeGB GB)"
            if ($syncPlan.ItemsToRemove -gt 0 -and -not $SkipRemoval) {
                $syncDescription += ", remove $($syncPlan.ItemsToRemove) items ($removeSizeGB GB)"
            }

            if (-not $PSCmdlet.ShouldProcess($Destination, $syncDescription)) {
                return
            }

            # Remove files first (to free up space)
            if (-not $SkipRemoval -and $syncPlan.RemoveOperations.Count -gt 0) {
                Write-Verbose "Removing $($syncPlan.RemoveOperations.Count) items..."

                $removeCount = 0
                foreach ($removeOp in $syncPlan.RemoveOperations) {
                    $removeCount++
                    $percentComplete = [int](($removeCount / $syncPlan.RemoveOperations.Count) * 100)

                    Write-Progress -Activity "Removing old files" `
                        -Status "Removing $removeCount of $($syncPlan.RemoveOperations.Count)" `
                        -PercentComplete $percentComplete `
                        -CurrentOperation $removeOp.Path `
                        -Id 1

                    Write-Verbose "Removing: $($removeOp.Path)"
                    Remove-Item -Path $removeOp.Path -Force -ErrorAction SilentlyContinue

                    # Try to remove empty parent directories
                    $parent = Split-Path -Path $removeOp.Path -Parent
                    while ($parent -and (Test-Path -Path $parent)) {
                        $items = Get-ChildItem -Path $parent -Force -ErrorAction SilentlyContinue
                        if (-not $items) {
                            Remove-Item -Path $parent -Force -ErrorAction SilentlyContinue
                            $parent = Split-Path -Path $parent -Parent
                        }
                        else {
                            break
                        }
                    }
                }

                Write-Progress -Activity "Removing old files" -Completed -Id 1
            }

            # Download files
            if ($syncPlan.AddOperations.Count -gt 0) {
                Write-Verbose "Downloading $($syncPlan.AddOperations.Count) items..."

                # Retrieve token once before the download loop (supports vault storage)
                # Use explicitly provided Token parameter first, then fall back to server config
                $effectiveToken = if ($Token) {
                    $Token
                } elseif ($server) {
                    Get-PatServerToken -ServerConfiguration $server
                } else {
                    $null
                }

                $downloadCount = 0
                $downloadedBytes = 0
                $totalBytes = $syncPlan.BytesToDownload

                foreach ($addOp in $syncPlan.AddOperations) {
                    $downloadCount++
                    $overallPercent = [int](($downloadedBytes / $totalBytes) * 100)

                    $itemDisplay = if ($addOp.Type -eq 'episode') {
                        "$($addOp.GrandparentTitle) - S$($addOp.ParentIndex.ToString('D2'))E$($addOp.Index.ToString('D2'))"
                    }
                    else {
                        "$($addOp.Title) ($($addOp.Year))"
                    }

                    Write-Progress -Activity "Syncing media" `
                        -Status "Downloading $downloadCount of $($syncPlan.AddOperations.Count): $itemDisplay" `
                        -PercentComplete $overallPercent `
                        -Id 1

                    # Construct download URL (token passed via header, not URL for security)
                    $downloadUrl = "$effectiveUri$($addOp.PartKey)?download=1"

                    Write-Verbose "Downloading: $($addOp.DestinationPath)"

                    try {
                        $downloadParameters = @{
                            Uri              = $downloadUrl
                            OutFile          = $addOp.DestinationPath
                            ExpectedSize     = $addOp.MediaSize
                            Resume           = $true
                            ProgressActivity = "Downloading: $itemDisplay"
                            ProgressId       = 2
                            ProgressParentId = 1
                            ErrorAction      = 'Stop'
                        }
                        if ($effectiveToken) {
                            $downloadParameters['Token'] = $effectiveToken
                        }
                        Invoke-PatFileDownload @downloadParameters | Out-Null

                        # Download subtitles if requested
                        if (-not $SkipSubtitles -and $addOp.SubtitleCount -gt 0) {
                            # Get full media info to get subtitle streams
                            $mediaInformationParameters = @{
                                RatingKey   = $addOp.RatingKey
                                ErrorAction = 'Stop'
                            }
                            if ($ServerUri) {
                                $mediaInformationParameters['ServerUri'] = $ServerUri
                            }
                            if ($Token) {
                                $mediaInformationParameters['Token'] = $Token
                            }

                            $mediaInformation = Get-PatMediaInfo @mediaInformationParameters

                            if ($mediaInformation.Media -and $mediaInformation.Media[0].Part) {
                                $subtitleStreams = $mediaInformation.Media[0].Part[0].Streams |
                                    Where-Object { $_.StreamType -eq 3 -and $_.External -and $_.Key }

                                foreach ($sub in $subtitleStreams) {
                                    $lang = if ($sub.LanguageCode) { $sub.LanguageCode } else { 'und' }
                                    $format = if ($sub.Format) { $sub.Format } else { 'srt' }

                                    $basePath = [System.IO.Path]::ChangeExtension($addOp.DestinationPath, $null).TrimEnd('.')
                                    $subPath = "$basePath.$lang.$format"

                                    # Token passed via header, not URL for security
                                    $subUrl = "$effectiveUri$($sub.Key)?download=1"

                                    Write-Verbose "Downloading subtitle: $subPath"

                                    try {
                                        $subtitleDownloadParameters = @{
                                            Uri         = $subUrl
                                            OutFile     = $subPath
                                            ErrorAction = 'Stop'
                                        }
                                        if ($effectiveToken) {
                                            $subtitleDownloadParameters['Token'] = $effectiveToken
                                        }
                                        Invoke-PatFileDownload @subtitleDownloadParameters | Out-Null
                                    }
                                    catch {
                                        Write-Warning "Failed to download subtitle for '$itemDisplay': $($_.Exception.Message)"
                                    }
                                }
                            }
                        }

                        $downloadedBytes += $addOp.MediaSize
                    }
                    catch {
                        Write-Warning "Failed to download '$itemDisplay': $($_.Exception.Message)"
                    }
                }

                Write-Progress -Activity "Syncing media" -Completed -Id 1
            }

            Write-Verbose "Sync completed"

            # Handle vacation workflow: sync watch status and remove watched items
            if ($SyncWatchStatus -or $RemoveWatched) {
                # Validate server names are provided
                if (-not $SourceServerName -or -not $TargetServerName) {
                    Write-Warning "SyncWatchStatus and RemoveWatched require -SourceServerName and -TargetServerName parameters. Skipping watch status operations."
                }
                else {
                    Write-Progress -Activity "Processing watch status" `
                        -Status "Comparing watch status between servers..." `
                        -Id 1

                    # Get items watched on target (travel server) but not source (home server)
                    $watchDiffs = @(Compare-PatWatchStatus -SourceServerName $TargetServerName `
                        -TargetServerName $SourceServerName `
                        -WatchedOnSourceOnly `
                        -ErrorAction SilentlyContinue)

                    if ($watchDiffs.Count -gt 0) {
                        Write-Verbose "Found $($watchDiffs.Count) items watched on '$TargetServerName'"

                        # Sync watch status first if requested
                        if ($SyncWatchStatus) {
                            if ($PSCmdlet.ShouldProcess("$($watchDiffs.Count) items", "Sync watch status from '$TargetServerName' to '$SourceServerName'")) {
                                Write-Progress -Activity "Syncing watch status" `
                                    -Status "Marking $($watchDiffs.Count) items as watched on '$SourceServerName'..." `
                                    -Id 1

                                $syncResults = Sync-PatWatchStatus -SourceServerName $TargetServerName `
                                    -TargetServerName $SourceServerName `
                                    -PassThru `
                                    -Confirm:$false

                                $successCount = @($syncResults | Where-Object { $_.Status -eq 'Success' }).Count
                                Write-Verbose "Synced watch status for $successCount items"
                            }
                        }

                        # Remove watched items from playlist if requested
                        if ($RemoveWatched) {
                            # Get playlist with items to map RatingKey to PlaylistItemId
                            $getPlaylistParameters = @{
                                IncludeItems = $true
                                ErrorAction  = 'Stop'
                            }
                            if ($PlaylistId) {
                                $getPlaylistParameters['PlaylistId'] = $PlaylistId
                            }
                            else {
                                $getPlaylistParameters['PlaylistName'] = $PlaylistName
                            }
                            if ($ServerUri) {
                                $getPlaylistParameters['ServerUri'] = $ServerUri
                            }
                            if ($Token) {
                                $getPlaylistParameters['Token'] = $Token
                            }

                            $playlist = Get-PatPlaylist @getPlaylistParameters

                            # Build lookup from RatingKey to PlaylistItem
                            $ratingKeyToItem = @{}
                            foreach ($item in $playlist.Items) {
                                $ratingKeyToItem[[string]$item.RatingKey] = $item
                            }

                            # Find watched items that are in the playlist
                            # Use TargetRatingKey which corresponds to the source (home) server's keys
                            $itemsToRemove = @()
                            foreach ($diff in $watchDiffs) {
                                $key = [string]$diff.TargetRatingKey
                                if ($ratingKeyToItem.ContainsKey($key)) {
                                    $itemsToRemove += @{
                                        PlaylistItem = $ratingKeyToItem[$key]
                                        WatchDiff    = $diff
                                    }
                                }
                            }

                            if ($itemsToRemove.Count -gt 0) {
                                $removeDescription = "$($itemsToRemove.Count) watched items from playlist '$($playlist.Title)'"

                                if ($PSCmdlet.ShouldProcess($removeDescription, 'Remove')) {
                                    $removedCount = 0
                                    $totalToRemove = $itemsToRemove.Count

                                    foreach ($itemToRemove in $itemsToRemove) {
                                        $removedCount++
                                        $playlistItem = $itemToRemove.PlaylistItem
                                        $itemDisplay = if ($playlistItem.Type -eq 'episode') {
                                            "$($playlistItem.GrandparentTitle) - S$($playlistItem.ParentIndex.ToString('D2'))E$($playlistItem.Index.ToString('D2'))"
                                        }
                                        else {
                                            "$($playlistItem.Title) ($($playlistItem.Year))"
                                        }

                                        $percentComplete = [int](($removedCount / $totalToRemove) * 100)
                                        Write-Progress -Activity "Removing watched items from playlist" `
                                            -Status "Removing $removedCount of $totalToRemove`: $itemDisplay" `
                                            -PercentComplete $percentComplete `
                                            -Id 1

                                        try {
                                            Remove-PatPlaylistItem -PlaylistId $playlist.PlaylistId `
                                                -PlaylistItemId $playlistItem.PlaylistItemId `
                                                -Confirm:$false `
                                                -ErrorAction Stop

                                            Write-Verbose "Removed '$itemDisplay' from playlist"
                                        }
                                        catch {
                                            Write-Warning "Failed to remove '$itemDisplay': $($_.Exception.Message)"
                                        }
                                    }

                                    Write-Progress -Activity "Removing watched items from playlist" -Completed -Id 1
                                    Write-Verbose "Removed $removedCount watched items from playlist"
                                }
                            }
                            else {
                                Write-Verbose "No watched items found in playlist to remove"
                            }
                        }
                    }
                    else {
                        Write-Progress -Activity "Processing watch status" -Completed -Id 1
                        Write-Verbose "No watched items found on '$TargetServerName' to process"
                    }
                }
            }

            if ($PassThru) {
                $syncPlan
            }
        }
        catch {
            throw "Failed to sync media: $($_.Exception.Message)"
        }
    }
}
