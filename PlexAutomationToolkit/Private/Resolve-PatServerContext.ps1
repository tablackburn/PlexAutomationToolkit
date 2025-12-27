function Resolve-PatServerContext {
    <#
    .SYNOPSIS
        Resolves server connection context including URI and authentication headers.

    .DESCRIPTION
        Centralizes the logic for resolving which Plex server to use and obtaining
        the appropriate authentication headers. This helper eliminates duplicated
        boilerplate across cmdlets and provides a consistent pattern for handling
        both explicit ServerUri parameters and default server configurations.

        The returned context object includes a WasExplicitUri flag that indicates
        whether the user explicitly specified a ServerUri. This is critical for
        internal cmdlet-to-cmdlet calls: when using the default server, child
        cmdlets should NOT receive ServerUri so they can perform their own default
        server resolution with proper authentication.

    .PARAMETER ServerUri
        Optional URI of the Plex server. If not specified, uses the default stored server.

    .OUTPUTS
        PSCustomObject with properties:
        - Uri: The effective server URI to use
        - Headers: Hashtable of HTTP headers including authentication if available
        - WasExplicitUri: Boolean indicating if ServerUri was explicitly provided
        - Server: The server configuration object (only when using default server)

    .EXAMPLE
        $ctx = Resolve-PatServerContext -ServerUri $ServerUri
        $response = Invoke-PatApi -Uri $ctx.Uri -Headers $ctx.Headers

    .EXAMPLE
        # For internal cmdlet calls, only pass ServerUri if it was explicit:
        $ctx = Resolve-PatServerContext -ServerUri $ServerUri
        $params = @{ CollectionId = 123 }
        if ($ctx.WasExplicitUri) { $params['ServerUri'] = $ctx.Uri }
        Get-PatCollection @params

    .NOTES
        This function throws if no default server is configured and ServerUri is not provided.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $ServerUri
    )

    if ($ServerUri) {
        Write-Verbose "Using explicitly specified server: $ServerUri"
        return [PSCustomObject]@{
            Uri            = $ServerUri
            Headers        = @{ Accept = 'application/json' }
            WasExplicitUri = $true
            Server         = $null
        }
    }

    $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
    if (-not $server) {
        throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
    }

    Write-Verbose "Using default server: $($server.uri)"
    return [PSCustomObject]@{
        Uri            = $server.uri
        Headers        = Get-PatAuthHeader -Server $server
        WasExplicitUri = $false
        Server         = $server
    }
}
