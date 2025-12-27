function Clear-PatDefaultServer {
    <#
    .SYNOPSIS
        Clears the default Plex server designation.

    .DESCRIPTION
        Removes the default flag from all configured servers. After clearing the
        default server, cmdlets will require an explicit -ServerUri parameter.

        This is useful when you want to ensure explicit server selection in scripts
        or when managing multiple servers where no single default is appropriate.

    .PARAMETER PassThru
        If specified, returns the updated server configuration objects after clearing the default.

    .EXAMPLE
        Clear-PatDefaultServer

        Clears the default server designation. All cmdlets will now require -ServerUri.

    .EXAMPLE
        Clear-PatDefaultServer -PassThru

        Clears the default server and returns all server configurations.

    .EXAMPLE
        Clear-PatDefaultServer -WhatIf

        Shows what would happen if the default server was cleared without actually clearing it.

    .OUTPUTS
        None
        Or PlexAutomationToolkit.ServerConfig[] if -PassThru is specified

    .LINK
        Set-PatDefaultServer
    .LINK
        Get-PatStoredServer
    .LINK
        Add-PatServer
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    try {
        $configuration = Get-PatServerConfiguration -ErrorAction Stop

        if ($configuration.servers.Count -eq 0) {
            Write-Warning "No servers configured. Use Add-PatServer to add a server."
            return
        }

        # Check if there's currently a default server
        $currentDefault = $configuration.servers | Where-Object { $_.default -eq $true }

        if (-not $currentDefault) {
            Write-Verbose "No default server is currently set"
            if ($PassThru) {
                $configuration.servers
            }
            return
        }

        if ($PSCmdlet.ShouldProcess("All servers", 'Clear default server designation')) {
            # Clear all defaults
            foreach ($server in $configuration.servers) {
                $server.default = $false
            }

            Set-PatServerConfiguration -Configuration $configuration -ErrorAction Stop
            Write-Verbose "Cleared default server designation from '$($currentDefault.name)'"

            if ($PassThru) {
                $configuration.servers
            }
        }
    }
    catch {
        throw "Failed to clear default server: $($_.Exception.Message)"
    }
}
