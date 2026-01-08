function Get-PatServerToken {
    <#
    .SYNOPSIS
        Retrieves the authentication token for a server.

    .DESCRIPTION
        Internal helper function that retrieves a Plex authentication token for a server.
        First attempts to retrieve from SecretManagement vault, then falls back to the
        inline token stored in the server configuration.

    .PARAMETER ServerName
        The name of the server to get the token for.

    .PARAMETER ServerConfig
        The server configuration object. Must have 'name' property, may have 'token'
        and 'tokenInVault' properties.

    .OUTPUTS
        String or $null
        Returns the token if found, $null otherwise.

    .EXAMPLE
        $token = Get-PatServerToken -ServerConfig $server
        Retrieves token from vault or inline configuration.

    .EXAMPLE
        $token = Get-PatServerToken -ServerName 'Home'
        Retrieves token by server name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]
        $ServerName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByConfig')]
        [ValidateNotNull()]
        [PSCustomObject]
        $ServerConfiguration
    )

    $name = if ($ServerConfiguration) { $ServerConfiguration.name } else { $ServerName }
    $secretName = "PlexAutomationToolkit/$name"

    # Try vault first if SecretManagement is available
    if (Get-PatSecretManagementAvailable) {
        try {
            $secret = Get-Secret -Name $secretName -AsPlainText -ErrorAction SilentlyContinue
            if ($secret) {
                Write-Debug "Retrieved token from vault for server '$name'"
                return $secret
            }
        }
        catch {
            Write-Debug "Failed to retrieve from vault: $($_.Exception.Message)"
        }
    }

    # Fall back to inline token if ServerConfig provided
    if ($ServerConfiguration -and
        $ServerConfiguration.PSObject.Properties['token'] -and
        -not [string]::IsNullOrWhiteSpace($ServerConfiguration.token)) {
        Write-Debug "Using inline token for server '$name'"
        return $ServerConfiguration.token
    }

    Write-Debug "No token found for server '$name'"
    return $null
}
