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

        # Handle case where response is returned as JSON string (some servers/content-types)
        # Check for both JSON objects ({) and arrays ([)
        $trimmedResponse = if ($response -is [string]) { $response.TrimStart() } else { $null }
        if ($trimmedResponse -and ($trimmedResponse.StartsWith('{') -or $trimmedResponse.StartsWith('['))) {
            Write-Debug "Response is JSON string, parsing with -AsHashtable..."
            # Use -AsHashtable to handle Plex API's case-sensitive keys (e.g., "guid" and "Guid")
            # Then convert back to PSCustomObject for consistent property access patterns
            $hashtable = $response | ConvertFrom-Json -AsHashtable -Depth 100
            $response = ConvertTo-PsCustomObjectFromHashtable -Hashtable $hashtable
        }

        if ($response.PSObject.Properties['MediaContainer']) {
            return $response.MediaContainer
        }
        return $response
    }
    catch {
        throw "Error invoking Plex API: $($_.Exception.Message)"
    }
}
