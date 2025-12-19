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

    .EXAMPLE
        Add-PatServer -Name "Main Server" -ServerUri "http://plex.local:32400" -Default
        Adds a new server and marks it as default

    .EXAMPLE
        Add-PatServer -Name "Remote Server" -ServerUri "http://remote.plex.com:32400"
        Adds a new server without marking it as default
    #>
    [CmdletBinding(SupportsShouldProcess)]
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
        $Default
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

        $config.servers += $newServer

        if ($PSCmdlet.ShouldProcess($Name, 'Add server to configuration')) {
            Set-PatServerConfig -Config $config -ErrorAction Stop
            Write-Verbose "Added server '$Name' to configuration"
        }
    }
    catch {
        throw "Failed to add server: $($_.Exception.Message)"
    }
}
