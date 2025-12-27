function Get-PatConfigurationPath {
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
        $configurationDirectory = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit'
        $configurationPath = Join-Path $configurationDirectory 'servers.json'

        # Test if OneDrive location is writable
        try {
            # Create directory if needed (Force handles race condition)
            $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop

            # Test write access
            $testFile = Join-Path $configurationDirectory '.test'
            [IO.File]::WriteAllText($testFile, 'test')
            Remove-Item $testFile -Force
            return $configurationPath
        }
        catch [System.IO.IOException] {
            Write-Debug "OneDrive path not accessible (IOException), using fallback"
        }
        catch {
            Write-Debug "OneDrive path not accessible ($($_.Exception.GetType().Name)), using fallback"
        }
    }

    # Fallback to user Documents
    $configurationDirectory = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit'
    $configurationPath = Join-Path $configurationDirectory 'servers.json'

    try {
        # Create directory if needed (Force handles race condition)
        $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop
        return $configurationPath
    }
    catch {
        # Documents not accessible, use LocalAppData as last resort
        $configurationDirectory = Join-Path $env:LOCALAPPDATA 'PlexAutomationToolkit'
        # Create directory if needed (Force handles race condition)
        $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop
        return Join-Path $configurationDirectory 'servers.json'
    }
}
