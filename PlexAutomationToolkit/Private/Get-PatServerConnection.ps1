function Get-PatServerConnection {
    <#
    .SYNOPSIS
        Gets all connection URIs for a Plex server from the Plex.tv API.

    .DESCRIPTION
        Queries the Plex.tv resources API to retrieve all available connection URIs
        for a specific server identified by its machineIdentifier. This includes both
        local network addresses and public/relay URIs.

        This function is used to discover alternative connection methods for a server,
        enabling intelligent selection of local vs remote URIs based on network context.

    .PARAMETER MachineIdentifier
        The unique machine identifier of the Plex server. This can be obtained from
        the server's root endpoint (/) or from Get-PatServer.

    .PARAMETER Token
        The Plex authentication token. Required to query the Plex.tv API.

    .OUTPUTS
        PSCustomObject[]
        Returns an array of connection objects with properties:
        - Uri: The connection URI
        - Local: Boolean indicating if this is a local network connection
        - Relay: Boolean indicating if this connection goes through Plex relay
        - IPv6: Boolean indicating if this is an IPv6 address
        - Protocol: The protocol (http or https)
        - Address: The host/IP address
        - Port: The port number

    .EXAMPLE
        $connections = Get-PatServerConnection -MachineIdentifier "abc123" -Token $token
        $localUri = ($connections | Where-Object { $_.Local -and -not $_.Relay }).Uri | Select-Object -First 1

        Gets all connections for a server and selects a local, non-relay URI.

    .NOTES
        Requires a valid Plex authentication token with access to the target server.
        The Plex.tv API returns connections for all servers the token has access to.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MachineIdentifier,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
    )

    $plexTvResourcesUri = 'https://plex.tv/api/v2/resources'

    $headers = @{
        'Accept'       = 'application/json'
        'X-Plex-Token' = $Token
    }

    Write-Verbose "Querying Plex.tv API for server connections (machineIdentifier: $MachineIdentifier)"

    try {
        $response = Invoke-RestMethod -Uri $plexTvResourcesUri -Headers $headers -ErrorAction Stop

        # Find the server matching our machineIdentifier
        $server = $response | Where-Object { $_.clientIdentifier -eq $MachineIdentifier }

        if (-not $server) {
            Write-Warning "Server with machineIdentifier '$MachineIdentifier' not found in Plex.tv resources"
            return [PSCustomObject[]]@()
        }

        if (-not $server.connections -or $server.connections.Count -eq 0) {
            Write-Warning "No connections found for server '$($server.name)'"
            return [PSCustomObject[]]@()
        }

        Write-Verbose "Found $($server.connections.Count) connection(s) for server '$($server.name)'"

        # Transform connections into standardized objects
        $connections = foreach ($conn in $server.connections) {
            [PSCustomObject]@{
                Uri      = $conn.uri
                Local    = [bool]$conn.local
                Relay    = [bool]$conn.relay
                IPv6     = [bool]$conn.IPv6
                Protocol = $conn.protocol
                Address  = $conn.address
                Port     = $conn.port
            }
        }

        return $connections
    }
    catch {
        $errorMessage = $_.Exception.Message

        if ($errorMessage -match '401|403|Unauthorized|Forbidden') {
            throw "Authentication failed when querying Plex.tv API. Verify your token is valid."
        }

        throw "Failed to get server connections from Plex.tv: $errorMessage"
    }
}
