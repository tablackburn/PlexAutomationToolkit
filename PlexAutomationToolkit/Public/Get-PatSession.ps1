function Get-PatSession {
    <#
    .SYNOPSIS
        Retrieves active playback sessions from a Plex server.

    .DESCRIPTION
        Gets a list of current streaming sessions on the Plex server, including
        information about what is being played, who is watching, and which device
        is being used. This is useful for monitoring server usage and managing
        active streams.

    .PARAMETER Username
        Optional filter to show only sessions for a specific username.

    .PARAMETER Player
        Optional filter to show only sessions from a specific player/device name.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests will fail.

    .EXAMPLE
        Get-PatSession

        Retrieves all active playback sessions from the default Plex server.

    .EXAMPLE
        Get-PatSession -ServerName 'Home'

        Retrieves all active playback sessions from the stored server named 'Home'.

    .EXAMPLE
        Get-PatSession -Username 'john'

        Retrieves only sessions where user 'john' is watching.

    .EXAMPLE
        Get-PatSession -Player 'Living Room TV'

        Retrieves sessions from the device named 'Living Room TV'.

    .EXAMPLE
        Get-PatSession | Where-Object { $_.Progress -gt 90 }

        Retrieves sessions that are more than 90% complete.

    .EXAMPLE
        Get-PatSession | Format-Table Username, MediaTitle, PlayerName, Progress

        Displays a formatted table of who is watching what.

    .OUTPUTS
        PlexAutomationToolkit.Session

        Objects with properties:
        - SessionId: Unique session identifier (use with Stop-PatSession)
        - MediaTitle: Title of the media being played
        - MediaType: Type of media (movie, episode, track, etc.)
        - MediaKey: Plex library key for the media item
        - Username: Name of the user watching
        - UserId: Plex user ID
        - PlayerName: Name of the playback device
        - PlayerAddress: IP address of the player
        - PlayerPlatform: Platform/OS of the player
        - PlayerMachineId: Unique identifier of the player device
        - IsLocal: Whether the player is on the local network
        - Bandwidth: Current streaming bandwidth in kbps
        - ViewOffset: Current playback position in milliseconds
        - Duration: Total media duration in milliseconds
        - Progress: Playback progress as percentage (0-100)
        - ServerUri: The Plex server URI
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Player,

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

    try {
        $serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
    }
    catch {
        throw "Failed to resolve server: $($_.Exception.Message)"
    }

    $effectiveUri = $serverContext.Uri
    $headers = $serverContext.Headers

    Write-Verbose "Retrieving sessions from $effectiveUri"

    # Query the sessions endpoint
    $endpoint = '/status/sessions'
    $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

    try {
        $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to retrieve sessions: $($_.Exception.Message)"
    }

    # Handle empty response (no active sessions)
    if (-not $result -or -not $result.Metadata) {
        Write-Verbose "No active sessions found"
        Write-Information "No active sessions on server" -InformationAction Continue
        return
    }

    # Transform each session into a structured object
    $sessions = foreach ($session in $result.Metadata) {
        # Calculate progress percentage
        $progress = 0
        if ($session.duration -and $session.duration -gt 0 -and $null -ne $session.viewOffset) {
            $progress = [math]::Round(($session.viewOffset / $session.duration) * 100, 1)
        }

        [PSCustomObject]@{
            PSTypeName       = 'PlexAutomationToolkit.Session'
            SessionId        = $session.Session.id
            MediaTitle       = $session.title
            MediaType        = $session.type
            MediaKey         = $session.key
            Username         = $session.User.title
            UserId           = $session.User.id
            PlayerName       = $session.Player.title
            PlayerAddress    = $session.Player.address
            PlayerPlatform   = $session.Player.platform
            PlayerMachineId  = $session.Player.machineIdentifier
            IsLocal          = [bool]$session.Player.local
            Bandwidth        = [int]($session.Session.bandwidth)
            ViewOffset       = [long]($session.viewOffset)
            Duration         = [long]($session.duration)
            Progress         = $progress
            ServerUri        = $effectiveUri
        }
    }

    # Apply filters if specified
    if ($Username) {
        $sessions = $sessions | Where-Object { $_.Username -eq $Username }
    }

    if ($Player) {
        $sessions = $sessions | Where-Object { $_.PlayerName -eq $Player }
    }

    # Inform user if filtering resulted in no matches
    if (-not $sessions -or @($sessions).Count -eq 0) {
        $filterInformation = @()
        if ($Username) { $filterInformation += "Username='$Username'" }
        if ($Player) { $filterInformation += "Player='$Player'" }
        if ($filterInformation.Count -gt 0) {
            Write-Information "No sessions match filter: $($filterInformation -join ', ')" -InformationAction Continue
        }
        return
    }

    $sessions
}
