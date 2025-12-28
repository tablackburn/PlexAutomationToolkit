function Remove-PatServer {
    <#
    .SYNOPSIS
        Removes a Plex server from the configuration.

    .DESCRIPTION
        Removes a Plex server entry from the server configuration file by name.

    .PARAMETER Name
        Name of the server to remove

    .PARAMETER PassThru
        If specified, returns the removed server configuration object.

    .EXAMPLE
        Remove-PatServer -Name "Old Server"

        Removes the server named "Old Server".

    .EXAMPLE
        Remove-PatServer -Name "Test Server" -WhatIf

        Shows what would be removed without actually removing it.

    .EXAMPLE
        Remove-PatServer -Name "Old Server" -PassThru

        Removes the server and returns the removed server configuration.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    try {
        $configuration = Get-PatServerConfiguration -ErrorAction Stop

        $server = $configuration.servers | Where-Object { $_.name -eq $Name }
        if (-not $server) {
            throw "No server found with name '$Name'"
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Remove server from configuration')) {
            # Store server before removing for PassThru
            $removedServer = $server

            # Remove token from vault if stored there
            Remove-PatServerToken -ServerName $Name

            $configuration.servers = @($configuration.servers | Where-Object { $_.name -ne $Name })
            Set-PatServerConfiguration -Configuration $configuration -ErrorAction Stop
            Write-Verbose "Removed server '$Name' from configuration"

            if ($PassThru) {
                $removedServer
            }
        }
    }
    catch {
        throw "Failed to remove server: $($_.Exception.Message)"
    }
}
