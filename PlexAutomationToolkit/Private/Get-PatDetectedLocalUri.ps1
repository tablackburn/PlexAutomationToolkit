function Get-PatDetectedLocalUri {
    <#
    .SYNOPSIS
        Detects the local network URI for a Plex server from the Plex.tv API.

    .DESCRIPTION
        Internal helper function that queries the Plex.tv API to find local network
        connections for a server. Returns the best local URI (preferring HTTPS) or
        $null if no local connection is found.

    .PARAMETER ServerUri
        The primary server URI to get the machine identifier from.

    .PARAMETER Token
        The Plex authentication token for API access.

    .OUTPUTS
        System.String or $null
        Returns the detected local URI, or $null if none found or detection fails.

    .EXAMPLE
        Get-PatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'abc123'

        Returns the local URI if detected, such as 'http://192.168.1.100:32400'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
    )

    process {
        Write-Verbose "Attempting to detect local URI from Plex.tv API"

        try {
            # First, get the server's machine identifier
            $serverIdentity = Get-PatServerIdentity -ServerUri $ServerUri -Token $Token -ErrorAction Stop
            Write-Verbose "Server machineIdentifier: $($serverIdentity.MachineIdentifier)"

            # Query Plex.tv for all connections to this server
            $connections = Get-PatServerConnection -MachineIdentifier $serverIdentity.MachineIdentifier -Token $Token -ErrorAction Stop

            if (-not $connections -or $connections.Count -eq 0) {
                Write-Verbose "No connections found in Plex.tv API response"
                return $null
            }

            # Find a local, non-relay connection (prefer HTTPS if available)
            $localConnections = $connections | Where-Object { $_.Local -eq $true -and $_.Relay -ne $true }

            if (-not $localConnections) {
                Write-Verbose "No local (non-relay) connections found for this server"
                return $null
            }

            # Prefer HTTPS local connection, fall back to HTTP
            $preferredLocal = $localConnections | Where-Object { $_.Protocol -eq 'https' } | Select-Object -First 1
            if (-not $preferredLocal) {
                $preferredLocal = $localConnections | Select-Object -First 1
            }

            if ($preferredLocal -and $preferredLocal.Uri -ne $ServerUri) {
                Write-Verbose "Detected local URI: $($preferredLocal.Uri)"
                return $preferredLocal.Uri
            }
            else {
                Write-Verbose "No distinct local URI found (may already be using local connection)"
                return $null
            }
        }
        catch {
            Write-Warning "Failed to detect local URI: $($_.Exception.Message)"
            return $null
        }
    }
}
