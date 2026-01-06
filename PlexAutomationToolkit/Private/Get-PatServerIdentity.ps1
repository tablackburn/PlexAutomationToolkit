function Get-PatServerIdentity {
    <#
    .SYNOPSIS
        Gets the unique machine identifier and basic info from a Plex server.

    .DESCRIPTION
        Queries a Plex server's root endpoint to retrieve its identity information,
        including the machineIdentifier which uniquely identifies the server regardless
        of how it's accessed (local IP, public hostname, etc.).

    .PARAMETER ServerUri
        The URI of the Plex server to query.

    .PARAMETER Token
        Optional Plex authentication token. Some servers require authentication
        even for basic identity queries.

    .OUTPUTS
        PSCustomObject with properties:
        - MachineIdentifier: Unique server identifier
        - FriendlyName: Server's display name
        - Version: Plex Media Server version
        - Platform: Server platform (e.g., Linux, Windows)

    .EXAMPLE
        $identity = Get-PatServerIdentity -ServerUri "http://192.168.1.100:32400"
        Write-Host "Server ID: $($identity.MachineIdentifier)"

    .EXAMPLE
        $identity = Get-PatServerIdentity -ServerUri "https://plex.example.com:32400" -Token $token

    .NOTES
        The machineIdentifier is essential for matching servers across different
        connection methods (local vs remote URIs).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [string]
        $Token
    )

    $uri = Join-PatUri -BaseUri $ServerUri -Endpoint '/'

    $headers = @{
        'Accept' = 'application/json'
    }

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers['X-Plex-Token'] = $Token
    }

    Write-Verbose "Querying server identity from $ServerUri"

    try {
        $response = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction Stop

        if (-not $response.machineIdentifier) {
            throw "Server response missing machineIdentifier"
        }

        return [PSCustomObject]@{
            MachineIdentifier = $response.machineIdentifier
            FriendlyName      = $response.friendlyName
            Version           = $response.version
            Platform          = $response.platform
        }
    }
    catch {
        throw "Failed to get server identity from '$ServerUri': $($_.Exception.Message)"
    }
}
