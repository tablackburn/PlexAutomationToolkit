function Invoke-PatPinAuthentication {
    <#
    .SYNOPSIS
        Performs PIN-based authentication with Plex.

    .DESCRIPTION
        Orchestrates the complete PIN authentication flow:
        1. Generates or retrieves client identifier
        2. Requests a PIN from Plex
        3. Displays the PIN and URL to the user
        4. Waits for user to authorize the PIN
        5. Returns the authentication token

    .PARAMETER TimeoutSeconds
        Maximum time to wait for authorization in seconds (default: 300 / 5 minutes).

    .PARAMETER Force
        Suppresses the interactive prompt to open the browser. When specified,
        automatically opens the browser. Use for non-interactive automation.

    .OUTPUTS
        System.String
        Returns the authentication token if successful
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1800)]
        [int]
        $TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    try {
        # Get or generate client identifier
        $clientIdentifier = Get-PatClientIdentifier
        Write-Verbose "Using client identifier: $clientIdentifier"

        # Request PIN
        Write-Verbose "Requesting PIN from Plex"
        $pin = New-PatPin -ClientIdentifier $clientIdentifier

        # Display instructions to user
        $plexLinkUrl = 'https://plex.tv/link'

        Write-Host "`nPlex Authentication" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        Write-Host "`nEnter this code at " -ForegroundColor White -NoNewline
        Write-Host $plexLinkUrl -ForegroundColor Yellow -NoNewline
        Write-Host ":" -ForegroundColor White
        Write-Host "`n  $($pin.code)" -ForegroundColor Green -NoNewline
        Write-Host " (case-insensitive, copied to clipboard)" -ForegroundColor Gray

        # Copy code to clipboard
        Set-Clipboard -Value $pin.code

        # Open browser if -Force or user confirms
        if ($Force -or $PSCmdlet.ShouldContinue(
            "Open $plexLinkUrl in your browser?",
            'Plex Authentication'
        )) {
            Start-Process $plexLinkUrl
        }

        Write-Host "`nWaiting for authorization..." -ForegroundColor White

        # Wait for authorization
        $token = Wait-PatPinAuthorization -PinId $pin.id `
            -ClientIdentifier $clientIdentifier `
            -TimeoutSeconds $TimeoutSeconds

        if ($token) {
            Write-Host "`nAuthentication successful!" -ForegroundColor Green
            return $token
        }
        else {
            throw "Authentication timed out after $TimeoutSeconds seconds. Please try again."
        }
    }
    catch {
        throw "PIN authentication failed: $($_.Exception.Message)"
    }
}
