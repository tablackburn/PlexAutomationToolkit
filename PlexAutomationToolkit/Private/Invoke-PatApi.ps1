function Invoke-PatApi {
    <#
    .SYNOPSIS
        Invokes the Plex API.

    .DESCRIPTION
        Internal function that sends HTTP requests to the Plex API and returns the response.

    .PARAMETER Uri
        The complete URI to call

    .PARAMETER Method
        The HTTP method to use (default: Get)

    .PARAMETER Headers
        Optional headers to include in the request (default: Accept = application/json)

    .OUTPUTS
        PSCustomObject
        Returns the MediaContainer object from the Plex API response if present, otherwise returns the full response
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Method = 'Get',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Headers = @{
            Accept = 'application/json'
        }
    )

    # Warn if using HTTP with authentication token
    if ($Uri -match '^http://' -and $Headers.ContainsKey('X-Plex-Token')) {
        Write-Warning "Sending authentication token over unencrypted HTTP connection. Consider using HTTPS."
    }

    $apiQueryParameters = @{
        Method      = $Method
        Uri         = $Uri
        Headers     = $Headers
        ErrorAction = 'Stop'
    }
    Write-Debug 'Invoking Plex API with the following parameters:'
    $apiQueryParameters | Out-String | Write-Debug

    try {
        $response = Invoke-RestMethod @apiQueryParameters
        if ($response.PSObject.Properties['MediaContainer']) {
            return $response.MediaContainer
        }
        return $response
    }
    catch {
        throw "Error invoking Plex API: $($_.Exception.Message)"
    }
}
