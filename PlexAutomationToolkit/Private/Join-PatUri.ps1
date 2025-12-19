function Join-PatUri {
    <#
    .SYNOPSIS
        Joins a base URI with an endpoint path.

    .DESCRIPTION
        Safely combines a base URI with an endpoint path using the .NET Uri class.
        Handles trailing and leading slashes automatically.

    .PARAMETER BaseUri
        The base URI (e.g., http://plex.example.com:32400)

    .PARAMETER Endpoint
        The endpoint path to append (e.g., /library/sections)

    .EXAMPLE
        Join-PatUri -BaseUri "http://plex.example.com:32400" -Endpoint "/library/sections"
        Returns: http://plex.example.com:32400/library/sections

    .EXAMPLE
        Join-PatUri -BaseUri "http://1.2.3.4:32400/" -Endpoint "media/providers"
        Returns: http://1.2.3.4:32400/media/providers

    .PARAMETER QueryString
        Optional query string to append to the URI (without leading ?)

    .EXAMPLE
        Join-PatUri -BaseUri "http://plex.example.com:32400" -Endpoint "/library/sections/2/refresh" -QueryString "path=%2Fmedia"
        Returns: http://plex.example.com:32400/library/sections/2/refresh?path=%2Fmedia
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BaseUri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Endpoint,

        [Parameter(Mandatory = $false)]
        [string]
        $QueryString
    )

    try {
        $base = [Uri]::new($BaseUri)
        $combined = [Uri]::new($base, $Endpoint)
        $uri = $combined.AbsoluteUri

        if ($QueryString) {
            $uri += "?$QueryString"
        }

        return $uri
    }
    catch {
        throw "Failed to join URI: $($_.Exception.Message)"
    }
}
