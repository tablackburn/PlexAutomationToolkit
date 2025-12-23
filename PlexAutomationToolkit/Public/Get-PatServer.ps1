function Get-PatServer {
    <#
    .SYNOPSIS
        Retrieves Plex server information.

    .DESCRIPTION
        Gets information about a Plex server including version, platform, and capabilities.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .EXAMPLE
        Get-PatServer -ServerUri "http://plex.example.com:32400"
        Retrieves server information from the specified Plex server

    .EXAMPLE
        Get-PatServer
        Retrieves server information from the default stored server

    .OUTPUTS
        PSCustomObject
        Returns the MediaContainer object from the Plex API response
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri
    )

    # Use default server if ServerUri not specified
    $server = $null
    if (-not $ServerUri) {
        try {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
            if (-not $server) {
                throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
            }
            $ServerUri = $server.uri
        }
        catch {
            throw "Failed to get default server: $($_.Exception.Message)"
        }
    }

    $uri = Join-PatUri -BaseUri $ServerUri -Endpoint '/'

    # Build headers with authentication if we have server object
    $headers = if ($server) {
        Get-PatAuthHeaders -Server $server
    }
    else {
        @{ Accept = 'application/json' }
    }

    try {
        Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to get Plex server information: $($_.Exception.Message)"
    }
}
