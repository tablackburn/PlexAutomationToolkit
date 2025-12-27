function Get-PatServerConfiguration {
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

    $configurationPath = Get-PatConfigurationPath

    if (-not (Test-Path $configurationPath)) {
        # Return default empty config
        return [PSCustomObject]@{
            version = '1.0'
            servers = @()
        }
    }

    try {
        $content = Get-Content -Path $configurationPath -Raw -ErrorAction Stop
        $configuration = $content | ConvertFrom-Json -ErrorAction Stop

        # Validate schema
        if (-not $configuration.PSObject.Properties['version']) {
            throw "Configuration missing 'version' property"
        }

        if (-not $configuration.PSObject.Properties['servers']) {
            throw "Configuration missing 'servers' property"
        }

        if ($configuration.servers -isnot [array]) {
            throw "Configuration 'servers' must be an array"
        }

        return $configuration
    }
    catch {
        throw "Failed to read server configuration: $($_.Exception.Message)"
    }
}
