function Stop-PatSession {
    <#
    .SYNOPSIS
        Terminates an active playback session on a Plex server.

    .DESCRIPTION
        Stops an active streaming session, disconnecting the user from playback.
        This is useful for server management, freeing up resources, or enforcing
        usage policies. The session owner will see playback stop on their device.

        Use Get-PatSession to find active sessions and their SessionId values.

    .PARAMETER SessionId
        The unique identifier of the session to terminate. This can be obtained
        from Get-PatSession output (the SessionId property).

    .PARAMETER Reason
        Optional message to display to the user whose session is being terminated.
        For example: "Server maintenance in progress" or "Bandwidth limit exceeded".

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the session information before termination.

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123def456'

        Terminates the session with the specified ID (prompts for confirmation).

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123def456' -ServerName 'Home'

        Terminates a session on the stored server named 'Home'.

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123def456' -Reason 'Server maintenance'

        Terminates the session and displays a maintenance message to the user.

    .EXAMPLE
        Get-PatSession -Username 'guest' | Stop-PatSession

        Terminates all sessions for the user 'guest'.

    .EXAMPLE
        Get-PatSession | Where-Object { $_.IsLocal -eq $false } | Stop-PatSession -Reason 'Remote access disabled'

        Terminates all remote (non-local) sessions.

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123' -WhatIf

        Shows what would happen without actually terminating the session.

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123' -Confirm:$false

        Terminates the session without prompting for confirmation.

    .OUTPUTS
        None by default. With -PassThru, returns PlexAutomationToolkit.Session object.

    .NOTES
        This cmdlet has a ConfirmImpact of High, so it will prompt for confirmation
        by default. Use -Confirm:$false to bypass the prompt, or -WhatIf to preview
        the action without executing it.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SessionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Reason,

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
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers
    }

    process {
        Write-Verbose "Terminating session $SessionId on $effectiveUri"

        # Get session details for ShouldProcess message and PassThru
        $sessionInformation = $null
        if ($PassThru -or $PSCmdlet.ShouldProcess) {
            try {
                # Build params for Get-PatSession
                $sessionParams = @{}
                if ($script:serverContext.WasExplicitUri) {
                    $sessionParams['ServerUri'] = $effectiveUri
                    if ($Token) { $sessionParams['Token'] = $Token }
                }
                elseif ($ServerName) {
                    $sessionParams['ServerName'] = $ServerName
                }
                $sessions = Get-PatSession @sessionParams
                $sessionInformation = $sessions | Where-Object { $_.SessionId -eq $SessionId }
            }
            catch {
                Write-Verbose "Could not retrieve session details: $($_.Exception.Message)"
            }
        }

        # Build descriptive target for ShouldProcess
        $target = if ($sessionInformation) {
            "'$($sessionInformation.MediaTitle)' by $($sessionInformation.Username) on $($sessionInformation.PlayerName)"
        }
        else {
            "Session $SessionId"
        }

        if ($PSCmdlet.ShouldProcess($target, 'Terminate session')) {
            # Build the termination endpoint
            # Plex uses /status/sessions/terminate with sessionId and reason as query params
            $endpoint = '/status/sessions/terminate'
            $queryParameters = "sessionId=$([System.Uri]::EscapeDataString($SessionId))"

            if ($Reason) {
                $queryParameters += "&reason=$([System.Uri]::EscapeDataString($Reason))"
            }

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryParameters

            try {
                Invoke-PatApi -Uri $uri -Method 'Get' -Headers $headers -ErrorAction 'Stop'
                Write-Verbose "Session $SessionId terminated successfully"
            }
            catch {
                throw "Failed to terminate session: $($_.Exception.Message)"
            }

            if ($PassThru -and $sessionInformation) {
                $sessionInformation
            }
        }
    }
}
