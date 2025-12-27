function Get-PatAuthenticationHeader {
    <#
    .SYNOPSIS
        Builds HTTP headers for Plex API requests with optional authentication.

    .DESCRIPTION
        Internal helper function that constructs HTTP headers for Plex API requests.
        Includes default Accept header and conditionally adds X-Plex-Token header
        when a server object with a token is provided.

    .PARAMETER Server
        Optional server object containing token property. If provided and token exists,
        X-Plex-Token header will be included for authenticated requests.

    .OUTPUTS
        Hashtable
        Returns a hashtable of HTTP headers to pass to Invoke-RestMethod

    .EXAMPLE
        $headers = Get-PatAuthenticationHeader -Server $serverObject
        Returns headers with X-Plex-Token if server has token

    .EXAMPLE
        $headers = Get-PatAuthenticationHeader
        Returns default headers without authentication
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $false)]
        [PSCustomObject]
        $Server
    )

    $headers = @{
        Accept = 'application/json'
    }

    # Add X-Plex-Token header if server has a non-empty token
    if ($Server -and
        $Server.PSObject.Properties['token'] -and
        -not [string]::IsNullOrWhiteSpace($Server.token)) {
        $headers['X-Plex-Token'] = $Server.token
        Write-Debug "Adding X-Plex-Token header for authenticated request"
    }
    else {
        Write-Debug "No token available - using unauthenticated request"
    }

    return $headers
}
