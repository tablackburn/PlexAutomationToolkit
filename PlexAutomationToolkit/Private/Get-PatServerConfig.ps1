function Get-PatServerConfig {
    <#
    .SYNOPSIS
        Reads the server configuration file.

    .DESCRIPTION
        Loads and validates the server configuration from the JSON config file.
        Returns a default empty config if file doesn't exist.

    .OUTPUTS
        PSCustomObject
        Returns the configuration object with version and servers array
    #>
    [CmdletBinding()]
    param ()

    $configPath = Get-PatConfigPath

    if (-not (Test-Path $configPath)) {
        # Return default empty config
        return [PSCustomObject]@{
            version = '1.0'
            servers = @()
        }
    }

    try {
        $content = Get-Content -Path $configPath -Raw -ErrorAction Stop
        $config = $content | ConvertFrom-Json -ErrorAction Stop

        # Validate schema
        if (-not $config.PSObject.Properties['version']) {
            throw "Configuration missing 'version' property"
        }

        if (-not $config.PSObject.Properties['servers']) {
            throw "Configuration missing 'servers' property"
        }

        if ($config.servers -isnot [array]) {
            throw "Configuration 'servers' must be an array"
        }

        return $config
    }
    catch {
        throw "Failed to read server configuration: $($_.Exception.Message)"
    }
}
