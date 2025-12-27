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

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\'

        Syncs the default 'Travel' playlist to drive E:, including subtitles.

    .EXAMPLE
        Sync-PatMedia -Destination 'E:\' -SkipSubtitles

        Syncs the 'Travel' playlist without downloading external subtitles.

    .EXAMPLE
        Sync-PatMedia -PlaylistName 'Vacation' -Destination 'E:\' -WhatIf

        Shows what would be synced from the 'Vacation' playlist without making changes.

    .OUTPUTS
        PlexAutomationToolkit.SyncPlan (with -PassThru)
        Returns the sync plan with operation results.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'parameterName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandAst',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $quoteChar = ''
            $strippedWord = $wordToComplete
            if ($wordToComplete -match "^([`"'])(.*)$") {
                $quoteChar = $Matches[1]
                $strippedWord = $Matches[2]
            }

            $getParams = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParams['ServerUri'] = $fakeBoundParameters['ServerUri']
            }

            $playlists = Get-PatPlaylist @getParams

            foreach ($playlist in $playlists) {
                if ($playlist.Title -ilike "$strippedWord*") {
                    $title = $playlist.Title
                    if ($quoteChar) {
                        $text = "$quoteChar$title$quoteChar"
                    }
                    elseif ($title -match '\s') {
                        $text = "'$title'"
                    }
                    else {
                        $text = $title
                    }

                    [System.Management.Automation.CompletionResult]::new(
                        $text,
                        $title,
                        'ParameterValue',
                        $title
                    )
                }
            }
        })]
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
        $ServerUri
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

        # Build auth headers for downloads
        $headers = if ($server) {
            Get-PatAuthHeaders -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }
    }

    process {
        try {
            # Get the sync plan
            $syncPlanParams = @{
                Destination = $Destination
                ErrorAction = 'Stop'
            }
            if ($ServerUri) {
                $syncPlanParams['ServerUri'] = $ServerUri
            }
            if ($PlaylistId) {
                $syncPlanParams['PlaylistId'] = $PlaylistId
            }
            else {
                $syncPlanParams['PlaylistName'] = $PlaylistName
            }

            Write-Verbose "Generating sync plan..."
            $syncPlan = Get-PatSyncPlan @syncPlanParams

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

                    # Construct download URL
                    $token = if ($server -and $server.token) { $server.token } else { $null }
                    $downloadUrl = if ($token) {
                        "$effectiveUri$($addOp.PartKey)?download=1&X-Plex-Token=$token"
                    }
                    else {
                        "$effectiveUri$($addOp.PartKey)?download=1"
                    }

                    Write-Verbose "Downloading: $($addOp.DestinationPath)"

                    try {
                        Invoke-PatFileDownload -Uri $downloadUrl `
                            -OutFile $addOp.DestinationPath `
                            -ExpectedSize $addOp.MediaSize `
                            -Resume `
                            -ErrorAction Stop | Out-Null

                        # Download subtitles if requested
                        if (-not $SkipSubtitles -and $addOp.SubtitleCount -gt 0) {
                            # Get full media info to get subtitle streams
                            $mediaInfoParams = @{
                                RatingKey   = $addOp.RatingKey
                                ErrorAction = 'Stop'
                            }
                            if ($ServerUri) {
                                $mediaInfoParams['ServerUri'] = $ServerUri
                            }

                            $mediaInfo = Get-PatMediaInfo @mediaInfoParams

                            if ($mediaInfo.Media -and $mediaInfo.Media[0].Part) {
                                $subtitleStreams = $mediaInfo.Media[0].Part[0].Streams |
                                    Where-Object { $_.StreamType -eq 3 -and $_.External -and $_.Key }

                                foreach ($sub in $subtitleStreams) {
                                    $lang = if ($sub.LanguageCode) { $sub.LanguageCode } else { 'und' }
                                    $format = if ($sub.Format) { $sub.Format } else { 'srt' }

                                    $basePath = [System.IO.Path]::ChangeExtension($addOp.DestinationPath, $null).TrimEnd('.')
                                    $subPath = "$basePath.$lang.$format"

                                    $subUrl = if ($token) {
                                        "$effectiveUri$($sub.Key)?download=1&X-Plex-Token=$token"
                                    }
                                    else {
                                        "$effectiveUri$($sub.Key)?download=1"
                                    }

                                    Write-Verbose "Downloading subtitle: $subPath"

                                    try {
                                        Invoke-PatFileDownload -Uri $subUrl `
                                            -OutFile $subPath `
                                            -ErrorAction Stop | Out-Null
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

            if ($PassThru) {
                $syncPlan
            }
        }
        catch {
            throw "Failed to sync media: $($_.Exception.Message)"
        }
    }
}
