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

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER PassThru
        If specified, returns the session information before termination.

    .EXAMPLE
        Stop-PatSession -SessionId 'abc123def456'

        Terminates the session with the specified ID (prompts for confirmation).

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
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
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
            }
            catch {
                throw "Failed to get default server: $($_.Exception.Message)"
            }
        }

        # Build headers with authentication
        $headers = if ($server) {
            Get-PatAuthHeader -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }
    }

    process {
        Write-Verbose "Terminating session $SessionId on $effectiveUri"

        # Get session details for ShouldProcess message and PassThru
        $sessionInfo = $null
        if ($PassThru -or $PSCmdlet.ShouldProcess) {
            try {
                $sessions = Get-PatSession -ServerUri $effectiveUri
                $sessionInfo = $sessions | Where-Object { $_.SessionId -eq $SessionId }
            }
            catch {
                Write-Verbose "Could not retrieve session details: $($_.Exception.Message)"
            }
        }

        # Build descriptive target for ShouldProcess
        $target = if ($sessionInfo) {
            "'$($sessionInfo.MediaTitle)' by $($sessionInfo.Username) on $($sessionInfo.PlayerName)"
        }
        else {
            "Session $SessionId"
        }

        if ($PSCmdlet.ShouldProcess($target, 'Terminate session')) {
            # Build the termination endpoint
            # Plex uses /status/sessions/terminate with sessionId and reason as query params
            $endpoint = '/status/sessions/terminate'
            $queryParams = "sessionId=$([System.Uri]::EscapeDataString($SessionId))"

            if ($Reason) {
                $queryParams += "&reason=$([System.Uri]::EscapeDataString($Reason))"
            }

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryParams

            try {
                Invoke-PatApi -Uri $uri -Method 'Get' -Headers $headers -ErrorAction 'Stop'
                Write-Verbose "Session $SessionId terminated successfully"
            }
            catch {
                throw "Failed to terminate session: $($_.Exception.Message)"
            }

            if ($PassThru -and $sessionInfo) {
                $sessionInfo
            }
        }
    }
}
