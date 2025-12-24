function Add-PatServer {
    <#
    .SYNOPSIS
        Adds a Plex server to the configuration.

    .DESCRIPTION
        Adds a new Plex server entry to the server configuration file.
        Optionally marks the server as default.

    .PARAMETER Name
        Friendly name for the server (e.g., "Main Plex Server")

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)

    .PARAMETER Default
        If specified, marks this server as the default server

    .PARAMETER Token
        Optional Plex authentication token (X-Plex-Token). Required for servers that don't allow
        unauthenticated local network access. Use Get-PatToken for instructions on obtaining your token.

        WARNING: Tokens are stored in PLAINTEXT in servers.json. Only use on trusted systems.

    .PARAMETER PassThru
        If specified, returns the server configuration object after adding.

    .EXAMPLE
        Add-PatServer -Name "Main Server" -ServerUri "http://plex.local:32400" -Default

        Adds a new server and marks it as default.

    .EXAMPLE
        Add-PatServer -Name "Remote Server" -ServerUri "http://remote.plex.com:32400"

        Adds a new server without marking it as default.

    .EXAMPLE
        Add-PatServer -Name "Authenticated Server" -ServerUri "http://plex.remote.com:32400" -Token "ABC123xyz" -Default

        Adds a new server with authentication token and marks it as default.

    .EXAMPLE
        Add-PatServer -Name "New Server" -ServerUri "http://plex.local:32400" -PassThru

        Adds a new server and returns the server configuration object.

    .NOTES
        Security Warning: Authentication tokens are stored in PLAINTEXT in the servers.json configuration file.
        Your Plex token provides full access to your Plex account. Only use on trusted systems with
        appropriate file permissions.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [switch]
        $Default,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    try {
        $config = Get-PatServerConfig -ErrorAction Stop

        # Check for duplicate name
        if ($config.servers | Where-Object { $_.name -eq $Name }) {
            throw "A server with name '$Name' already exists"
        }

        # If marking as default, unset other defaults
        if ($Default) {
            foreach ($server in $config.servers) {
                $server.default = $false
            }
        }

        # Add new server
        $newServer = [PSCustomObject]@{
            name    = $Name
            uri     = $ServerUri
            default = $Default.IsPresent
        }

        # Conditionally add token if provided
        if ($Token) {
            $newServer | Add-Member -NotePropertyName 'token' -NotePropertyValue $Token
        }

        $config.servers += $newServer

        if ($PSCmdlet.ShouldProcess($Name, 'Add server to configuration')) {
            Set-PatServerConfig -Config $config -ErrorAction Stop
            Write-Verbose "Added server '$Name' to configuration"

            if ($PassThru) {
                $newServer
            }
        }
    }
    catch {
        throw "Failed to add server: $($_.Exception.Message)"
    }
}
