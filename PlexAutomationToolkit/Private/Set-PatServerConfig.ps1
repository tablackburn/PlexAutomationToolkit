function Set-PatServerConfig {
    <#
    .SYNOPSIS
        Writes the server configuration file.

    .DESCRIPTION
        Saves the server configuration to the JSON config file.
        Creates the file if it doesn't exist.

    .PARAMETER Config
        The configuration object to save

    .EXAMPLE
        $config = Get-PatServerConfig
        $config.servers += [PSCustomObject]@{ name = 'Main'; uri = 'http://plex:32400'; default = $true }
        Set-PatServerConfig -Config $config
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $Config
    )

    $configPath = Get-PatConfigPath

    try {
        # Validate required properties
        if (-not $Config.PSObject.Properties['version']) {
            throw "Configuration missing 'version' property"
        }

        if (-not $Config.PSObject.Properties['servers']) {
            throw "Configuration missing 'servers' property"
        }

        # Validate only one default server
        $defaultServers = @($Config.servers | Where-Object { $_.default -eq $true })
        if ($defaultServers.Count -gt 1) {
            Write-Warning "Configuration has multiple default servers: $($defaultServers.name -join ', '). Only first will be used."
        }

        # Convert to JSON with proper formatting
        $json = $Config | ConvertTo-Json -Depth 10 -ErrorAction Stop

        # Ensure directory exists
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        # Write file with UTF-8 encoding (no BOM)
        [IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        throw "Failed to write server configuration: $($_.Exception.Message)"
    }
}
