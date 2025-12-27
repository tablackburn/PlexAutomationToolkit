function New-PatPin {
    <#
    .SYNOPSIS
        Requests a new PIN code from Plex for device authentication.

    .DESCRIPTION
        Creates a new PIN authentication request with the Plex API. Returns a PIN object
        containing the PIN ID and the 4-character code that users enter at plex.tv/link
        to authorize the device.

    .PARAMETER ClientIdentifier
        The unique client identifier for this device/application.

    .OUTPUTS
        PSCustomObject
        Returns an object with 'id' and 'code' properties
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClientIdentifier
    )

    if (-not $PSCmdlet.ShouldProcess('Plex API', 'Request new PIN')) {
        return
    }

    $headers = @{
        'Accept'                   = 'application/json'
        'X-Plex-Client-Identifier' = $ClientIdentifier
        'X-Plex-Product'           = 'PlexAutomationToolkit'
        'X-Plex-Version'           = '1.0.0'
    }

    try {
        Write-Verbose "Requesting new PIN from Plex API"
        $response = Invoke-RestMethod -Uri 'https://plex.tv/api/v2/pins' `
            -Method Post `
            -Headers $headers `
            -Body @{ strong = $false } `
            -ErrorAction Stop

        Write-Verbose "PIN created successfully. ID: $($response.id), Code: $($response.code)"

        return [PSCustomObject]@{
            id   = $response.id
            code = $response.code
        }
    }
    catch {
        throw "Failed to request PIN from Plex: $($_.Exception.Message)"
    }
}
