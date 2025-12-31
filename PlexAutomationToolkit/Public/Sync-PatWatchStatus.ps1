function Sync-PatWatchStatus {
    <#
    .SYNOPSIS
        Syncs watch status from one Plex server to another.

    .DESCRIPTION
        Compares watch status between source and target Plex servers and marks items
        as watched on the target server that are watched on the source. Uses the Plex
        scrobble endpoint to mark items as watched.

        Supports bidirectional sync for scenarios like syncing watch status after
        watching media on a travel server.

    .PARAMETER SourceServerName
        The name of the source server (as stored with Add-PatServer).

    .PARAMETER TargetServerName
        The name of the target server (as stored with Add-PatServer).

    .PARAMETER Direction
        The direction of the sync:
        - SourceToTarget (default): Sync watched items from source to target
        - TargetToSource: Sync watched items from target to source
        - Bidirectional: Sync watched items in both directions

    .PARAMETER SectionId
        Optional array of library section IDs to sync. If not specified, syncs all sections.

    .PARAMETER PassThru
        Returns the sync results after completion.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home'

        Syncs all watched status from Travel server to Home server.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -Direction TargetToSource

        Syncs watched status from Home server back to Travel server.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -Direction Bidirectional

        Syncs watched status in both directions between Travel and Home servers.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -SectionId 1, 2

        Syncs watched status only for library sections 1 and 2.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WhatIf

        Shows what would be synced without making changes.

    .OUTPUTS
        PSCustomObject[]
        With -PassThru, returns an array of PlexAutomationToolkit.WatchStatusSyncResult objects with properties:
        - Title: Item title
        - Type: 'movie' or 'episode'
        - ShowName: Series name (episodes only)
        - Season: Season number (episodes only)
        - Episode: Episode number (episodes only)
        - RatingKey: Target server rating key
        - Status: 'Success' or 'Failed'
        - Error: Error message if failed
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetServerName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('SourceToTarget', 'TargetToSource', 'Bidirectional')]
        [string]
        $Direction = 'SourceToTarget',

        [Parameter(Mandatory = $false)]
        [int[]]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        # Get both server configurations
        try {
            $sourceServer = Get-PatStoredServer -Name $SourceServerName -ErrorAction Stop
            if (-not $sourceServer) {
                throw "Source server '$SourceServerName' not found. Use Add-PatServer to configure it."
            }

            $targetServer = Get-PatStoredServer -Name $TargetServerName -ErrorAction Stop
            if (-not $targetServer) {
                throw "Target server '$TargetServerName' not found. Use Add-PatServer to configure it."
            }
        }
        catch {
            throw "Failed to get server configuration: $($_.Exception.Message)"
        }

        Write-Verbose "Syncing watch status between '$SourceServerName' and '$TargetServerName' (Direction: $Direction)"
    }

    process {
        try {
            $allResults = @()

            # Determine which directions to sync
            $syncOperations = switch ($Direction) {
                'SourceToTarget' {
                    @(@{
                        FromName   = $SourceServerName
                        ToName     = $TargetServerName
                        FromServer = $sourceServer
                        ToServer   = $targetServer
                    })
                }
                'TargetToSource' {
                    @(@{
                        FromName   = $TargetServerName
                        ToName     = $SourceServerName
                        FromServer = $targetServer
                        ToServer   = $sourceServer
                    })
                }
                'Bidirectional' {
                    @(
                        @{
                            FromName   = $SourceServerName
                            ToName     = $TargetServerName
                            FromServer = $sourceServer
                            ToServer   = $targetServer
                        },
                        @{
                            FromName   = $TargetServerName
                            ToName     = $SourceServerName
                            FromServer = $targetServer
                            ToServer   = $sourceServer
                        }
                    )
                }
            }

            foreach ($syncOp in $syncOperations) {
                Write-Verbose "Syncing from '$($syncOp.FromName)' to '$($syncOp.ToName)'"

                # Get differences (items watched on source but not target)
                $compareParams = @{
                    SourceServerName    = $syncOp.FromName
                    TargetServerName    = $syncOp.ToName
                    WatchedOnSourceOnly = $true
                    ErrorAction         = 'Stop'
                }

                if ($SectionId) {
                    $compareParams['SectionId'] = $SectionId
                }

                $differences = @(Compare-PatWatchStatus @compareParams)

                if ($differences.Count -eq 0) {
                    Write-Verbose "No differences found for $($syncOp.FromName) -> $($syncOp.ToName)"
                    Write-Information "Watch status already in sync: $($syncOp.FromName) -> $($syncOp.ToName)" -InformationAction Continue
                    continue
                }

                Write-Verbose "Found $($differences.Count) items to mark as watched on '$($syncOp.ToName)'"

                $successCount = 0
                $failCount = 0

                foreach ($item in $differences) {
                    $itemDisplay = if ($item.Type -eq 'episode') {
                        "$($item.ShowName) - S$($item.Season.ToString('D2'))E$($item.Episode.ToString('D2')) - $($item.Title)"
                    }
                    else {
                        "$($item.Title) ($($item.Year))"
                    }

                    $percentComplete = [int]((($successCount + $failCount) / $differences.Count) * 100)
                    Write-Progress -Activity "Syncing watch status to $($syncOp.ToName)" `
                        -Status "Processing $($successCount + $failCount + 1) of $($differences.Count)" `
                        -PercentComplete $percentComplete `
                        -CurrentOperation $itemDisplay `
                        -Id 1

                    if ($PSCmdlet.ShouldProcess($itemDisplay, "Mark as watched on $($syncOp.ToName)")) {
                        try {
                            # Use scrobble endpoint to mark as watched
                            $scrobbleEndpoint = "/:/scrobble?key=$($item.TargetRatingKey)&identifier=com.plexapp.plugins.library"
                            $scrobbleUri = Join-PatUri -BaseUri $syncOp.ToServer.uri -Endpoint $scrobbleEndpoint
                            $headers = Get-PatAuthenticationHeader -Server $syncOp.ToServer

                            Invoke-PatApi -Uri $scrobbleUri -Headers $headers -ErrorAction Stop | Out-Null

                            $successCount++
                            Write-Verbose "Marked as watched: $itemDisplay"

                            $allResults += [PSCustomObject]@{
                                PSTypeName  = 'PlexAutomationToolkit.WatchStatusSyncResult'
                                Title       = $item.Title
                                Type        = $item.Type
                                ShowName    = $item.ShowName
                                Season      = $item.Season
                                Episode     = $item.Episode
                                RatingKey   = $item.TargetRatingKey
                                SyncedTo    = $syncOp.ToName
                                Status      = 'Success'
                                Error       = $null
                            }
                        }
                        catch {
                            $failCount++
                            Write-Warning "Failed to mark as watched: $itemDisplay - $($_.Exception.Message)"

                            $allResults += [PSCustomObject]@{
                                PSTypeName  = 'PlexAutomationToolkit.WatchStatusSyncResult'
                                Title       = $item.Title
                                Type        = $item.Type
                                ShowName    = $item.ShowName
                                Season      = $item.Season
                                Episode     = $item.Episode
                                RatingKey   = $item.TargetRatingKey
                                SyncedTo    = $syncOp.ToName
                                Status      = 'Failed'
                                Error       = $_.Exception.Message
                            }
                        }
                    }
                }

                Write-Progress -Activity "Syncing watch status to $($syncOp.ToName)" -Completed -Id 1
                Write-Verbose "Sync to '$($syncOp.ToName)' completed: $successCount succeeded, $failCount failed"
                Write-Information "Synced $successCount items to '$($syncOp.ToName)'$(if ($failCount -gt 0) { " ($failCount failed)" })" -InformationAction Continue
            }

            if ($PassThru) {
                $allResults
            }
        }
        catch {
            throw "Failed to sync watch status: $($_.Exception.Message)"
        }
    }
}
