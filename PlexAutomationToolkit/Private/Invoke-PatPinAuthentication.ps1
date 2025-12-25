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

    .OUTPUTS
        System.String
        Returns the authentication token if successful
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1800)]
        [int]
        $TimeoutSeconds = 300
    )

    try {
        # Get or generate client identifier
        $clientIdentifier = Get-PatClientIdentifier
        Write-Verbose "Using client identifier: $clientIdentifier"

        # Request PIN
        Write-Verbose "Requesting PIN from Plex"
        $pin = New-PatPin -ClientIdentifier $clientIdentifier

        # Display instructions to user
        Write-Host "`nPlex Authentication" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan
        Write-Host "`nTo authenticate, please visit:" -ForegroundColor White
        Write-Host "  https://plex.tv/link" -ForegroundColor Yellow
        Write-Host "`nEnter this code when prompted:" -ForegroundColor White
        Write-Host "  $($pin.code)" -ForegroundColor Green -NoNewline
        Write-Host " (case-insensitive)" -ForegroundColor Gray
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
