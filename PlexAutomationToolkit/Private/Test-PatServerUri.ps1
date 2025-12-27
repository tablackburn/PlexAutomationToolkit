function Test-PatServerUri {
    <#
    .SYNOPSIS
        Validates a Plex server URI format.

    .DESCRIPTION
        Internal helper function to validate that a URI is a properly formatted
        HTTP or HTTPS URL suitable for Plex server connections. This centralizes
        URI validation logic used across multiple cmdlets.

    .PARAMETER Uri
        The URI to validate.

    .OUTPUTS
        Returns $true if valid, throws a descriptive error if invalid.

    .NOTES
        This function is designed for use in ValidateScript attributes:
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Uri
    )

    # Allow empty/null - let ValidateNotNullOrEmpty handle that separately
    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return $true
    }

    # Validate HTTP/HTTPS URL format with optional port
    # Pattern breakdown:
    #   ^https?://                    - HTTP or HTTPS scheme
    #   [a-zA-Z0-9]                   - Hostname must start with alphanumeric
    #   ([a-zA-Z0-9\-]{0,61}...)?     - Hostname segments (max 63 chars per RFC)
    #   (\.[a-zA-Z0-9]...)*           - Additional domain segments
    #   (:[0-9]{1,5})?$               - Optional port number (1-5 digits)
    $pattern = '^https?://[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*(:[0-9]{1,5})?$'

    if ($Uri -notmatch $pattern) {
        throw "ServerUri must be a valid HTTP or HTTPS URL (e.g., http://plex.local:32400). Received: '$Uri'"
    }

    return $true
}
