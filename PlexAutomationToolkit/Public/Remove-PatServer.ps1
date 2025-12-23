function Remove-PatServer {
    <#
    .SYNOPSIS
        Removes a Plex server from the configuration.

    .DESCRIPTION
        Removes a Plex server entry from the server configuration file by name.

    .PARAMETER Name
        Name of the server to remove

    .EXAMPLE
        Remove-PatServer -Name "Old Server"

        Removes the server named "Old Server".

    .EXAMPLE
        Remove-PatServer -Name "Test Server" -WhatIf

        Shows what would be removed without actually removing it.
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

        if ($PSCmdlet.ShouldProcess($Name, 'Remove server from configuration')) {
            $config.servers = @($config.servers | Where-Object { $_.name -ne $Name })
            Set-PatServerConfig -Config $config -ErrorAction Stop
            Write-Verbose "Removed server '$Name' from configuration"
        }
    }
    catch {
        throw "Failed to remove server: $($_.Exception.Message)"
    }
}
