function Get-PatConfigPath {
    <#
    .SYNOPSIS
        Gets the configuration file path for PlexAutomationToolkit.

    .DESCRIPTION
        Determines the best location for the configuration file with fallback options.
        Prefers OneDrive-synced location for cross-machine sync.

    .OUTPUTS
        String
        Returns the full path to the configuration file
    #>
    [CmdletBinding()]
    param ()

    # Try OneDrive location first (syncs across machines)
    if ($env:OneDrive) {
        $configDir = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit'
        $configPath = Join-Path $configDir 'servers.json'

        # Test if OneDrive location is writable
        try {
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            # Test write access
            $testFile = Join-Path $configDir '.test'
            [IO.File]::WriteAllText($testFile, 'test')
            Remove-Item $testFile -Force
            return $configPath
        }
        catch {
            # OneDrive path not accessible, continue to fallback
        }
    }

    # Fallback to user Documents
    $configDir = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit'
    $configPath = Join-Path $configDir 'servers.json'

    try {
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        return $configPath
    }
    catch {
        # Documents not accessible, use LocalAppData as last resort
        $configDir = Join-Path $env:LOCALAPPDATA 'PlexAutomationToolkit'
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        return Join-Path $configDir 'servers.json'
    }
}
