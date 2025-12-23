function Set-PatDefaultServer {
    <#
    .SYNOPSIS
        Sets the default Plex server.

    .DESCRIPTION
        Marks a specific server as the default server in the configuration.
        Clears the default flag from all other servers.

    .PARAMETER Name
        Name of the server to mark as default

    .EXAMPLE
        Set-PatDefaultServer -Name "Main Server"

        Marks "Main Server" as the default server.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    try {
        $config = Get-PatServerConfig -ErrorAction Stop

        $server = $config.servers | Where-Object { $_.name -eq $Name }
        if (-not $server) {
            throw "No server found with name '$Name'"
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Set as default server')) {
            # Unset all defaults
            foreach ($s in $config.servers) {
                $s.default = $false
            }

            # Set new default
            $server.default = $true

            Set-PatServerConfig -Config $config -ErrorAction Stop
            Write-Verbose "Set '$Name' as default server"
        }
    }
    catch {
        throw "Failed to set default server: $($_.Exception.Message)"
    }
}
