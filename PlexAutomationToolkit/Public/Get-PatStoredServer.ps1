function Get-PatStoredServer {
    <#
    .SYNOPSIS
        Gets stored Plex server configurations.

    .DESCRIPTION
        Retrieves Plex server configurations from the config file.
        Can retrieve all servers, the default server, or a specific server by name.

    .PARAMETER Name
        Optional name of a specific server to retrieve

    .PARAMETER Default
        If specified, returns only the default server

    .EXAMPLE
        Get-PatStoredServer

        Returns all stored servers.

    .EXAMPLE
        Get-PatStoredServer -Default

        Returns the default server.

    .EXAMPLE
        Get-PatStoredServer -Name "Main Server"

        Returns the server named "Main Server".

    .OUTPUTS
        PSCustomObject
        Returns server configuration objects with name, uri, and default properties
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [switch]
        $Default
    )

    try {
        $configuration = Get-PatServerConfiguration -ErrorAction Stop

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $server = $configuration.servers | Where-Object { $_.name -eq $Name }
                if (-not $server) {
                    throw "No server found with name '$Name'"
                }
                $server
            }
            'Default' {
                Write-Debug "Default switch specified: $($Default.IsPresent)"
                $defaultServers = @($configuration.servers | Where-Object { $_.default -eq $true })
                if ($defaultServers.Count -eq 0) {
                    throw "No default server configured"
                }
                if ($defaultServers.Count -gt 1) {
                    Write-Warning "Multiple default servers found in configuration. Using first: $($defaultServers[0].name). Run Set-PatDefaultServer to fix."
                }
                $defaultServers[0]
            }
            'All' {
                # Return servers if any exist, otherwise return nothing (not $null)
                if ($configuration.servers -and $configuration.servers.Count -gt 0) {
                    $configuration.servers
                }
                else {
                    Write-Information "No servers configured. Use Add-PatServer to add one." -InformationAction Continue
                }
            }
        }
    }
    catch {
        throw "Failed to get stored servers: $($_.Exception.Message)"
    }
}
