function Resolve-PatServerContext {
    <#
    .SYNOPSIS
        Resolves server connection context including URI and authentication headers.

    .DESCRIPTION
        Centralizes the logic for resolving which Plex server to use and obtaining
        the appropriate authentication headers. This helper eliminates duplicated
        boilerplate across cmdlets and provides a consistent pattern for handling
        explicit ServerUri parameters, stored server names, and default server configurations.

        When using a stored server with local URI configuration, this function
        intelligently selects the best URI based on network reachability. If the
        server has PreferLocal enabled and a LocalUri configured, it will test
        reachability and use the local connection when available.

        The returned context object includes a WasExplicitUri flag that indicates
        whether the user explicitly specified a ServerUri. This is critical for
        internal cmdlet-to-cmdlet calls: when using the default server, child
        cmdlets should NOT receive ServerUri so they can perform their own default
        server resolution with proper authentication.

    .PARAMETER ServerName
        Optional name of a stored server to use. The server must be configured via
        Add-PatServer. This is more convenient than ServerUri as you don't need to
        remember the URI or provide a token.

    .PARAMETER ServerUri
        Optional URI of the Plex server. If not specified, uses the default stored server.

    .PARAMETER Token
        Optional Plex authentication token. Required when using explicit ServerUri
        to authenticate with the server. If not specified with ServerUri, requests
        will be unauthenticated and may fail with 401 errors.

    .PARAMETER ForceLocal
        If specified, forces use of the local URI without testing reachability.
        Only applies when using a stored server with LocalUri configured.

    .PARAMETER ForceRemote
        If specified, forces use of the primary (remote) URI regardless of
        local URI availability. Useful for testing or when local access is unavailable.

    .OUTPUTS
        PSCustomObject with properties:
        - Uri: The effective server URI to use
        - Headers: Hashtable of HTTP headers including authentication if available
        - WasExplicitUri: Boolean indicating if ServerUri was explicitly provided
        - Server: The server configuration object (only when using default server)
        - IsLocalConnection: Boolean indicating if using a local network connection

    .EXAMPLE
        $ctx = Resolve-PatServerContext -ServerName 'Home'
        $response = Invoke-PatApi -Uri $ctx.Uri -Headers $ctx.Headers

    .EXAMPLE
        $ctx = Resolve-PatServerContext -ServerUri $ServerUri
        $response = Invoke-PatApi -Uri $ctx.Uri -Headers $ctx.Headers

    .EXAMPLE
        # For internal cmdlet calls, only pass ServerUri if it was explicit:
        $ctx = Resolve-PatServerContext -ServerUri $ServerUri
        $params = @{ CollectionId = 123 }
        if ($ctx.WasExplicitUri) { $params['ServerUri'] = $ctx.Uri }
        Get-PatCollection @params

    .EXAMPLE
        # Force local connection when you know you're on the local network:
        $ctx = Resolve-PatServerContext -ForceLocal
        Write-Host "Connected via: $($ctx.Uri)"

    .NOTES
        This function throws if no default server is configured and ServerUri is not provided.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false)]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $ForceLocal,

        [Parameter(Mandatory = $false)]
        [switch]
        $ForceRemote
    )

    # Validate that ServerName and ServerUri are not both specified
    if ($ServerName -and $ServerUri) {
        throw "Cannot specify both -ServerName and -ServerUri. Use -ServerName for stored servers or -ServerUri for direct connection."
    }

    # ServerName - look up the stored server
    if ($ServerName) {
        Write-Verbose "Using stored server by name: $ServerName"
        $server = Get-PatStoredServer -Name $ServerName -ErrorAction 'Stop'

        # Get authentication token for the named server
        $serverToken = Get-PatServerToken -ServerConfig $server

        # Use intelligent URI selection if server has local URI configured
        $selectedUri = $server.uri
        $isLocal = $false

        if ($server.localUri -or $ForceLocal -or $ForceRemote) {
            $selection = Select-PatServerUri -Server $server -Token $serverToken -ForceLocal:$ForceLocal -ForceRemote:$ForceRemote
            $selectedUri = $selection.Uri
            $isLocal = $selection.IsLocal
            Write-Verbose "URI selection: $($selection.SelectionReason)"
        }

        Write-Verbose "Using named server '$ServerName': $selectedUri (local: $isLocal)"
        return [PSCustomObject]@{
            Uri               = $selectedUri
            Headers           = Get-PatAuthenticationHeader -Server $server
            WasExplicitUri    = $false
            Server            = $server
            Token             = $null
            IsLocalConnection = $isLocal
        }
    }

    if ($ServerUri) {
        Write-Verbose "Using explicitly specified server: $ServerUri"
        $headers = @{ Accept = 'application/json' }
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $headers['X-Plex-Token'] = $Token
            Write-Debug "Adding X-Plex-Token header for authenticated request"
        }
        return [PSCustomObject]@{
            Uri               = $ServerUri
            Headers           = $headers
            WasExplicitUri    = $true
            Server            = $null
            Token             = $Token
            IsLocalConnection = $false
        }
    }

    $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
    if (-not $server) {
        throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
    }

    # Get authentication token for reachability testing
    $serverToken = Get-PatServerToken -ServerConfig $server

    # Use intelligent URI selection if server has local URI configured
    $selectedUri = $server.uri
    $isLocal = $false

    if ($server.localUri -or $ForceLocal -or $ForceRemote) {
        $selection = Select-PatServerUri -Server $server -Token $serverToken -ForceLocal:$ForceLocal -ForceRemote:$ForceRemote
        $selectedUri = $selection.Uri
        $isLocal = $selection.IsLocal
        Write-Verbose "URI selection: $($selection.SelectionReason)"
    }

    Write-Verbose "Using default server: $selectedUri (local: $isLocal)"
    return [PSCustomObject]@{
        Uri               = $selectedUri
        Headers           = Get-PatAuthenticationHeader -Server $server
        WasExplicitUri    = $false
        Server            = $server
        Token             = $null  # Token retrieved from stored server, not needed for nested calls
        IsLocalConnection = $isLocal
    }
}
