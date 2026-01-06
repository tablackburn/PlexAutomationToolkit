function Select-PatServerUri {
    <#
    .SYNOPSIS
        Intelligently selects the best URI to connect to a Plex server.

    .DESCRIPTION
        Given a server configuration with both primary and local URIs, this function
        determines the optimal connection method based on network context. It prefers
        local connections when available and reachable, falling back to the primary URI.

        Selection logic:
        1. If PreferLocal is enabled and LocalUri is configured:
           a. Test if LocalUri is reachable
           b. If reachable, use LocalUri
           c. If not reachable, fall back to primary Uri
        2. If PreferLocal is disabled or no LocalUri, use primary Uri

    .PARAMETER Server
        The server configuration object containing Uri, LocalUri, and PreferLocal properties.

    .PARAMETER ForceLocal
        If specified, attempts to use LocalUri without testing reachability first.
        Useful when you know you're on the local network and want to skip the test.

    .PARAMETER ForceRemote
        If specified, uses the primary Uri regardless of LocalUri availability.
        Useful for testing or when local network access is known to be unavailable.

    .PARAMETER Token
        Optional authentication token for reachability testing.

    .OUTPUTS
        PSCustomObject with properties:
        - Uri: The selected URI to use
        - IsLocal: Boolean indicating if the local URI was selected
        - SelectionReason: Human-readable reason for the selection

    .EXAMPLE
        $server = Get-PatStoredServer -Default
        $selection = Select-PatServerUri -Server $server
        Write-Host "Using $($selection.Uri) (Local: $($selection.IsLocal))"

    .EXAMPLE
        $selection = Select-PatServerUri -Server $server -ForceLocal
        # Uses local URI without testing reachability

    .NOTES
        For best performance, configure servers with LocalUri during Add-PatServer
        so this function can make intelligent routing decisions.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $Server,

        [Parameter(Mandatory = $false)]
        [switch]
        $ForceLocal,

        [Parameter(Mandatory = $false)]
        [switch]
        $ForceRemote,

        [Parameter(Mandatory = $false)]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $SkipCertificateCheck
    )

    # Validate server has at least a primary URI
    if ([string]::IsNullOrWhiteSpace($Server.uri)) {
        throw "Server configuration missing required 'uri' property"
    }

    $primaryUri = $Server.uri
    $localUri = $Server.localUri
    $preferLocal = $Server.preferLocal -eq $true

    Write-Verbose "Selecting URI for server '$($Server.name)' (Primary: $primaryUri, Local: $localUri, PreferLocal: $preferLocal)"

    # Handle ForceRemote - always use primary
    if ($ForceRemote) {
        Write-Verbose "ForceRemote specified - using primary URI"
        return [PSCustomObject]@{
            Uri             = $primaryUri
            IsLocal         = $false
            SelectionReason = 'ForceRemote parameter specified'
        }
    }

    # If no local URI configured, use primary
    if ([string]::IsNullOrWhiteSpace($localUri)) {
        Write-Verbose "No local URI configured - using primary URI"
        return [PSCustomObject]@{
            Uri             = $primaryUri
            IsLocal         = $false
            SelectionReason = 'No local URI configured'
        }
    }

    # Handle ForceLocal - use local URI without testing
    if ($ForceLocal) {
        Write-Verbose "ForceLocal specified - using local URI without testing"
        return [PSCustomObject]@{
            Uri             = $localUri
            IsLocal         = $true
            SelectionReason = 'ForceLocal parameter specified'
        }
    }

    # If preferLocal is disabled, use primary
    if (-not $preferLocal) {
        Write-Verbose "PreferLocal disabled - using primary URI"
        return [PSCustomObject]@{
            Uri             = $primaryUri
            IsLocal         = $false
            SelectionReason = 'PreferLocal is disabled'
        }
    }

    # PreferLocal is enabled and we have a local URI - test reachability
    Write-Verbose "Testing local URI reachability: $localUri"

    $reachabilityParams = @{
        ServerUri      = $localUri
        Token          = $Token
        TimeoutSeconds = 2
    }
    if ($SkipCertificateCheck) {
        $reachabilityParams['SkipCertificateCheck'] = $true
    }
    $reachability = Test-PatServerReachable @reachabilityParams

    if ($reachability.Reachable) {
        Write-Verbose "Local URI is reachable ($($reachability.ResponseTimeMs)ms) - using local connection"
        return [PSCustomObject]@{
            Uri             = $localUri
            IsLocal         = $true
            SelectionReason = "Local URI reachable ($($reachability.ResponseTimeMs)ms)"
        }
    }
    else {
        Write-Verbose "Local URI not reachable - falling back to primary URI"
        return [PSCustomObject]@{
            Uri             = $primaryUri
            IsLocal         = $false
            SelectionReason = "Local URI not reachable: $($reachability.Error)"
        }
    }
}
