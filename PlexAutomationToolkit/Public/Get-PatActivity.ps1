function Get-PatActivity {
    <#
    .SYNOPSIS
        Retrieves current activities from a Plex server.

    .DESCRIPTION
        Gets a list of ongoing activities on the Plex server, such as library
        scans, media optimization, and other background tasks. This is useful
        for monitoring the progress of operations like library refreshes.

    .PARAMETER Type
        Optional filter for activity type. Common types include:
        - library.update.section (library scanning)
        - media.optimize (media optimization)

    .PARAMETER SectionId
        Optional filter to show only activities for a specific library section.
        Only applies to library-related activities.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .EXAMPLE
        Get-PatActivity

        Retrieves all current activities from the default Plex server.

    .EXAMPLE
        Get-PatActivity -Type 'library.update.section'

        Retrieves only library scan activities.

    .EXAMPLE
        Get-PatActivity -SectionId 2

        Retrieves activities for library section 2.

    .EXAMPLE
        Get-PatActivity -Type 'library.update.section' -SectionId 2

        Retrieves library scan activities for section 2 only.

    .EXAMPLE
        while ($scan = Get-PatActivity -SectionId 2 -Type 'library.update.section') {
            Write-Progress -Activity $scan.Title -PercentComplete $scan.Progress
            Start-Sleep -Seconds 2
        }
        Write-Host "Scan complete!"

        Monitors a library scan until it completes.

    .OUTPUTS
        PSCustomObject with properties:
        - ActivityId: Unique identifier for the activity
        - Type: Activity type (e.g., library.update.section)
        - Title: Human-readable title
        - Subtitle: Current item being processed
        - Progress: Completion percentage (0-100)
        - SectionId: Library section ID (for library activities)
        - Cancellable: Whether the activity can be cancelled
        - UserStopped: Whether a user requested cancellation
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Type,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ($_ -notmatch '^https?://[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*(:[0-9]{1,5})?$') {
                throw "ServerUri must be a valid HTTP or HTTPS URL (e.g., http://plex.local:32400)"
            }
            $true
        })]
        [string]
        $ServerUri
    )

    # Use default server if ServerUri not specified
    $server = $null
    if (-not $ServerUri) {
        try {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
            if (-not $server) {
                throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
            }
            $ServerUri = $server.uri
        }
        catch {
            throw "Failed to get default server: $($_.Exception.Message)"
        }
    }

    try {
        $endpoint = '/activities'
        $uri = Join-PatUri -BaseUri $ServerUri -Endpoint $endpoint

        # Build headers with authentication if we have server object
        $headers = if ($server) {
            Get-PatAuthHeaders -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }

        $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

        # Process activities
        $activities = @()
        if ($result.Activity) {
            foreach ($activity in $result.Activity) {
                # Extract section ID from Context if present
                $activitySectionId = $null
                if ($activity.Context -and $activity.Context.librarySectionID) {
                    $activitySectionId = [int]$activity.Context.librarySectionID
                }

                $activityObj = [PSCustomObject]@{
                    PSTypeName  = 'PlexAutomationToolkit.Activity'
                    ActivityId  = $activity.uuid
                    Type        = $activity.type
                    Title       = $activity.title
                    Subtitle    = $activity.subtitle
                    Progress    = if ($activity.progress) { [int]$activity.progress } else { 0 }
                    SectionId   = $activitySectionId
                    Cancellable = [bool]$activity.cancellable
                    UserStopped = [bool]$activity.userStopped
                }

                $activities += $activityObj
            }
        }

        # Apply filters
        if ($Type) {
            $activities = $activities | Where-Object { $_.Type -eq $Type }
        }

        if ($SectionId) {
            $activities = $activities | Where-Object { $_.SectionId -eq $SectionId }
        }

        # Return activities (may be empty if none match)
        $activities
    }
    catch {
        throw "Failed to retrieve activities: $($_.Exception.Message)"
    }
}
