function Wait-PatPinAuthorization {
    <#
    .SYNOPSIS
        Waits for user to authorize a PIN code on plex.tv.

    .DESCRIPTION
        Polls the Plex API to check if the user has entered the PIN code at plex.tv/link
        and authorized this device. Returns the authentication token once authorized.

    .PARAMETER PinId
        The PIN ID returned from New-PatPin.

    .PARAMETER ClientIdentifier
        The unique client identifier for this device/application.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for authorization in seconds (default: 300 / 5 minutes).

    .PARAMETER PollIntervalSeconds
        How often to check for authorization in seconds (default: 2).

    .OUTPUTS
        System.String
        Returns the authentication token if authorized, or null if timeout occurs
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PinId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClientIdentifier,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1800)]
        [int]
        $TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]
        $PollIntervalSeconds = 2
    )

    $headers = @{
        'Accept'                   = 'application/json'
        'X-Plex-Client-Identifier' = $ClientIdentifier
        'X-Plex-Product'           = 'PlexAutomationToolkit'
        'X-Plex-Version'           = '1.0.0'
    }

    $uri = "https://plex.tv/api/v2/pins/$PinId"
    $startTime = Get-Date
    $deadline = $startTime.AddSeconds($TimeoutSeconds)

    Write-Verbose "Waiting for PIN authorization (timeout: $TimeoutSeconds seconds)"

    try {
        while ((Get-Date) -lt $deadline) {
            $response = Invoke-RestMethod -Uri $uri `
                -Method Get `
                -Headers $headers `
                -ErrorAction Stop

            # Check if authorized
            if ($response.authToken) {
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                Write-Verbose "PIN authorized after $elapsed seconds"
                return $response.authToken
            }

            # Wait before next poll
            Start-Sleep -Seconds $PollIntervalSeconds
        }

        # Timeout reached
        Write-Verbose "PIN authorization timeout after $TimeoutSeconds seconds"
        return $null
    }
    catch {
        throw "Failed to check PIN authorization: $($_.Exception.Message)"
    }
}
