function Sync-PatWatchStatus {
    <#
    .SYNOPSIS
        Syncs watch status from one Plex server to another.

    .DESCRIPTION
        Compares watch status between source and target Plex servers and marks items
        as watched on the target server that are watched on the source. Uses the Plex
        scrobble endpoint to mark items as watched.

    .PARAMETER SourceServerName
        The name of the source server (as stored with Add-PatServer).

    .PARAMETER TargetServerName
        The name of the target server (as stored with Add-PatServer).

    .PARAMETER SectionId
        Optional array of library section IDs to sync. If not specified, syncs all sections.

    .PARAMETER PassThru
        Returns the sync results after completion.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home'

        Syncs all watched status from Travel server to Home server.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -SectionId 1, 2

        Syncs watched status only for library sections 1 and 2.

    .EXAMPLE
        Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WhatIf

        Shows what would be synced without making changes.

    .OUTPUTS
        PlexAutomationToolkit.WatchStatusSyncResult (with -PassThru)

        Objects with properties:
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
        [int[]]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        # Get target server configuration for scrobble operations
        try {
            $targetServer = Get-PatStoredServer -Name $TargetServerName -ErrorAction Stop
            if (-not $targetServer) {
                throw "Target server '$TargetServerName' not found. Use Add-PatServer to configure it."
            }
        }
        catch {
            throw "Failed to get server configuration: $($_.Exception.Message)"
        }

        Write-Verbose "Syncing watch status from '$SourceServerName' to '$TargetServerName'"
    }

    process {
        try {
            # Get differences (items watched on source but not target)
            $compareParams = @{
                SourceServerName   = $SourceServerName
                TargetServerName   = $TargetServerName
                WatchedOnSourceOnly = $true
                ErrorAction        = 'Stop'
            }

            if ($SectionId) {
                $compareParams['SectionId'] = $SectionId
            }

            $differences = @(Compare-PatWatchStatus @compareParams)

            if ($differences.Count -eq 0) {
                Write-Verbose "No differences found - watch status is already in sync"
                return
            }

            Write-Verbose "Found $($differences.Count) items to mark as watched on target"

            $results = @()
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
                Write-Progress -Activity "Syncing watch status" `
                    -Status "Processing $($successCount + $failCount + 1) of $($differences.Count)" `
                    -PercentComplete $percentComplete `
                    -CurrentOperation $itemDisplay `
                    -Id 1

                if ($PSCmdlet.ShouldProcess($itemDisplay, "Mark as watched on $TargetServerName")) {
                    try {
                        # Use scrobble endpoint to mark as watched
                        $scrobbleEndpoint = "/:/scrobble?key=$($item.TargetRatingKey)&identifier=com.plexapp.plugins.library"
                        $scrobbleUri = Join-PatUri -BaseUri $targetServer.uri -Endpoint $scrobbleEndpoint
                        $headers = Get-PatAuthenticationHeader -Server $targetServer

                        Invoke-PatApi -Uri $scrobbleUri -Headers $headers -ErrorAction Stop | Out-Null

                        $successCount++
                        Write-Verbose "Marked as watched: $itemDisplay"

                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.WatchStatusSyncResult'
                            Title      = $item.Title
                            Type       = $item.Type
                            ShowName   = $item.ShowName
                            Season     = $item.Season
                            Episode    = $item.Episode
                            RatingKey  = $item.TargetRatingKey
                            Status     = 'Success'
                            Error      = $null
                        }
                    }
                    catch {
                        $failCount++
                        Write-Warning "Failed to mark as watched: $itemDisplay - $($_.Exception.Message)"

                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.WatchStatusSyncResult'
                            Title      = $item.Title
                            Type       = $item.Type
                            ShowName   = $item.ShowName
                            Season     = $item.Season
                            Episode    = $item.Episode
                            RatingKey  = $item.TargetRatingKey
                            Status     = 'Failed'
                            Error      = $_.Exception.Message
                        }
                    }
                }
            }

            Write-Progress -Activity "Syncing watch status" -Completed -Id 1

            Write-Verbose "Sync completed: $successCount succeeded, $failCount failed"

            if ($PassThru) {
                $results
            }
        }
        catch {
            throw "Failed to sync watch status: $($_.Exception.Message)"
        }
    }
}
