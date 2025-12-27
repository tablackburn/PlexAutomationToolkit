function Set-PatServerConfiguration {
    <#
    .SYNOPSIS
        Writes the server configuration file.

    .DESCRIPTION
        Saves the server configuration to the JSON config file.
        Creates the file if it doesn't exist.

    .PARAMETER Configuration
        The configuration object to save

    .EXAMPLE
        $configuration = Get-PatServerConfiguration
        $configuration.servers += [PSCustomObject]@{ name = 'Main'; uri = 'http://plex:32400'; default = $true }
        Set-PatServerConfiguration -Configuration $configuration
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $Configuration
    )

    $configurationPath = Get-PatConfigurationPath

    if (-not $PSCmdlet.ShouldProcess($configurationPath, 'Write server configuration')) {
        return
    }

    try {
        # Validate required properties
        if (-not $Configuration.PSObject.Properties['version']) {
            throw "Configuration missing 'version' property"
        }

        if (-not $Configuration.PSObject.Properties['servers']) {
            throw "Configuration missing 'servers' property"
        }

        # Validate only one default server
        $defaultServers = @($Configuration.servers | Where-Object { $_.default -eq $true })
        if ($defaultServers.Count -gt 1) {
            Write-Warning "Configuration has multiple default servers: $($defaultServers.name -join ', '). Only first will be used."
        }

        # Convert to JSON with proper formatting
        $json = $Configuration | ConvertTo-Json -Depth 10 -ErrorAction Stop

        # Ensure directory exists
        $configurationDirectory = Split-Path $configurationPath -Parent
        if (-not (Test-Path $configurationDirectory)) {
            New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        # Write file with UTF-8 encoding (no BOM)
        [IO.File]::WriteAllText($configurationPath, $json, [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        throw "Failed to write server configuration: $($_.Exception.Message)"
    }
}
