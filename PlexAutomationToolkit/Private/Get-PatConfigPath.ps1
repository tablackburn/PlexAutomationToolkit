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
            # Create directory if needed (Force handles race condition)
            $null = New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop

            # Test write access
            $testFile = Join-Path $configDir '.test'
            [IO.File]::WriteAllText($testFile, 'test')
            Remove-Item $testFile -Force
            return $configPath
        }
        catch [System.IO.IOException] {
            Write-Debug "OneDrive path not accessible (IOException), using fallback"
        }
        catch {
            Write-Debug "OneDrive path not accessible ($($_.Exception.GetType().Name)), using fallback"
        }
    }

    # Fallback to user Documents
    $configDir = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit'
    $configPath = Join-Path $configDir 'servers.json'

    try {
        # Create directory if needed (Force handles race condition)
        $null = New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop
        return $configPath
    }
    catch {
        # Documents not accessible, use LocalAppData as last resort
        $configDir = Join-Path $env:LOCALAPPDATA 'PlexAutomationToolkit'
        # Create directory if needed (Force handles race condition)
        $null = New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop
        return Join-Path $configDir 'servers.json'
    }
}
