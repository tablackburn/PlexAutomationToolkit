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
        Optional query string to append to the URI (without leading ?).
        IMPORTANT: Query string values must be URL-encoded before passing to this function.
        Use [System.Uri]::EscapeDataString() to encode parameter values.

    .EXAMPLE
        Join-PatUri -BaseUri "http://plex.example.com:32400" -Endpoint "/library/sections/2/refresh" -QueryString "path=%2Fmedia"
        Returns: http://plex.example.com:32400/library/sections/2/refresh?path=%2Fmedia

    .EXAMPLE
        $path = "/media/movies"
        $encodedPath = [System.Uri]::EscapeDataString($path)
        Join-PatUri -BaseUri "http://plex.example.com:32400" -Endpoint "/library/sections/2/refresh" -QueryString "path=$encodedPath"
        Returns: http://plex.example.com:32400/library/sections/2/refresh?path=%2Fmedia%2Fmovies
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
        [ValidateScript({
            # Validate that QueryString doesn't contain unencoded special characters that could indicate injection
            # Block control characters, HTML/script injection chars, and unencoded spaces
            if ($_ -match '[<>\"''\x00-\x1F\s]') {
                throw "QueryString contains invalid characters. Ensure values are properly URL-encoded using [System.Uri]::EscapeDataString()"
            }
            # Validate percent-encoding: % must be followed by exactly two hex digits
            # This prevents malformed percent sequences that could bypass security filters
            if ($_ -match '%(?![0-9A-Fa-f]{2})') {
                throw "QueryString contains invalid percent-encoding. Each '%' must be followed by exactly two hex digits (e.g., %20, %2F)"
            }
            # Validate query string format: should be key=value pairs separated by &
            # Each part must have format: key=value (key is alphanumeric/underscore/hyphen, value is URL-safe or percent-encoded)
            $parts = $_ -split '&'
            foreach ($part in $parts) {
                if ($part -and $part -notmatch '^[a-zA-Z0-9_\-\.]+=[a-zA-Z0-9_\-\.%\+\*]*$') {
                    throw "QueryString has invalid format. Expected 'key=value' pairs with URL-encoded values. Got: '$part'"
                }
            }
            $true
        })]
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
