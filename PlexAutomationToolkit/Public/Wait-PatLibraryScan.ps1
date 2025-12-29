function Wait-PatLibraryScan {
    <#
    .SYNOPSIS
        Waits for a Plex library scan to complete.

    .DESCRIPTION
        Blocks execution until a library scan completes for the specified section.
        Polls the Plex server's activities endpoint and displays progress.
        Useful after calling Update-PatLibrary to ensure the scan finishes
        before proceeding.

    .PARAMETER SectionId
        The ID of the library section to monitor.

    .PARAMETER SectionName
        The friendly name of the library section to monitor (e.g., "Movies").

    .PARAMETER Timeout
        Maximum time to wait in seconds. Throws an error if exceeded.
        Default: 300 seconds (5 minutes).

    .PARAMETER PollingInterval
        Time between status checks in seconds. Default: 2 seconds.

    .PARAMETER PassThru
        If specified, returns the final activity status when complete.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'
        Wait-PatLibraryScan -SectionName 'Movies'

        Triggers a library scan and waits for it to complete.

    .EXAMPLE
        Wait-PatLibraryScan -SectionId 2 -Timeout 60

        Waits up to 60 seconds for section 2 to finish scanning.

    .EXAMPLE
        $status = Wait-PatLibraryScan -SectionName 'Movies' -PassThru

        Waits for scan completion and returns the final activity status.

    .EXAMPLE
        Update-PatLibrary -SectionId 2
        Wait-PatLibraryScan -SectionId 2 -PollingInterval 5

        Waits for scan, checking every 5 seconds instead of the default 2.

    .OUTPUTS
        None by default. With -PassThru, returns PlexAutomationToolkit.Activity object
        or $null if no scan was in progress.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3600)]
        [int]
        $Timeout = 300,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]
        $PollingInterval = 2,

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
        $Token
    )

    # Build parameters for internal calls
    $serverParams = @{}
    if ($ServerUri) {
        $serverParams['ServerUri'] = $ServerUri
    }
    if ($Token) {
        $serverParams['Token'] = $Token
    }

    # Resolve section name to ID if needed
    $resolvedSectionId = $SectionId
    $sectionDisplayName = $SectionId.ToString()

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        try {
            $libraryPaths = Get-PatLibraryPath @serverParams -SectionName $SectionName -ErrorAction 'Stop'
            if ($libraryPaths) {
                $resolvedSectionId = [int]$libraryPaths[0].sectionId
                $sectionDisplayName = $SectionName
            }
            else {
                throw "Library section '$SectionName' not found"
            }
        }
        catch {
            throw "Failed to resolve section name '$SectionName': $($_.Exception.Message)"
        }
    }

    $startTime = Get-Date
    $lastActivity = $null

    Write-Verbose "Waiting for library scan on section $sectionDisplayName (timeout: ${Timeout}s)"

    while ($true) {
        # Check for timeout
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalSeconds -ge $Timeout) {
            throw "Timeout waiting for library scan to complete after $Timeout seconds"
        }

        # Check for scan activity
        try {
            $activityParams = $serverParams.Clone()
            $activityParams['Type'] = 'library.update.section'
            $activityParams['SectionId'] = $resolvedSectionId

            $activity = Get-PatActivity @activityParams -ErrorAction 'Stop'
        }
        catch {
            Write-Warning "Failed to check activity status: $($_.Exception.Message)"
            $activity = $null
        }

        if ($activity) {
            $lastActivity = $activity

            # Show progress
            $progressParams = @{
                Activity        = "Library scan: $sectionDisplayName"
                Status          = $activity.Subtitle
                PercentComplete = $activity.Progress
            }
            Write-Progress @progressParams

            Write-Verbose "Scan in progress: $($activity.Progress)% - $($activity.Subtitle)"
        }
        else {
            # No scan activity found - either completed or never started
            Write-Progress -Activity "Library scan: $sectionDisplayName" -Completed
            Write-Verbose "No active scan found for section $sectionDisplayName"

            if ($PassThru) {
                return $lastActivity
            }
            return
        }

        # Wait before next poll
        Start-Sleep -Seconds $PollingInterval
    }
}
