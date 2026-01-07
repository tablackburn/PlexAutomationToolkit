function Get-PatConfigurationPath {
    <#
    .SYNOPSIS
        Gets the configuration file path for PlexAutomationToolkit.

    .DESCRIPTION
        Determines the best location for the configuration file with fallback options.
        Prefers OneDrive-synced location for cross-machine sync on Windows.
        Uses ~/.config/PlexAutomationToolkit on Linux/macOS.

    .OUTPUTS
        String
        Returns the full path to the configuration file
    #>
    [CmdletBinding()]
    param ()

    $isWindowsPlatform = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows

    if ($isWindowsPlatform) {
        # Try OneDrive location first (syncs across machines)
        if ($env:OneDrive) {
            # Validate OneDrive path doesn't contain path traversal sequences
            $oneDrivePath = $env:OneDrive
            if ($oneDrivePath -match '\.\.' -or $oneDrivePath -match '[\x00-\x1F]') {
                Write-Debug "OneDrive path contains suspicious characters, using fallback"
            }
            else {
                $configurationDirectory = Join-Path $oneDrivePath 'Documents\PlexAutomationToolkit'
                # Resolve to absolute path and verify it's under user profile
                try {
                    $resolvedDir = [System.IO.Path]::GetFullPath($configurationDirectory)
                    $userProfile = [System.IO.Path]::GetFullPath($env:USERPROFILE)

                    # Ensure resolved path is under user profile (security check)
                    if (-not $resolvedDir.StartsWith($userProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
                        Write-Debug "OneDrive configuration path escapes user profile, using fallback"
                    }
                    else {
                        $configurationPath = Join-Path $resolvedDir 'servers.json'

                        # Test if OneDrive location is writable
                        try {
                            # Create directory if needed (Force handles race condition)
                            $null = New-Item -Path $resolvedDir -ItemType Directory -Force -ErrorAction Stop

                            # Test write access
                            $testFile = Join-Path $resolvedDir '.test'
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
                }
                catch {
                    Write-Debug "Failed to resolve OneDrive path ($($_.Exception.GetType().Name)), using fallback"
                }
            }
        }

        # Fallback to user Documents
        if ($env:USERPROFILE) {
            # Validate USERPROFILE doesn't contain path traversal sequences
            $userProfilePath = $env:USERPROFILE
            if ($userProfilePath -notmatch '\.\.' -and $userProfilePath -notmatch '[\x00-\x1F]') {
                $configurationDirectory = Join-Path $userProfilePath 'Documents\PlexAutomationToolkit'
                $configurationPath = Join-Path $configurationDirectory 'servers.json'

                try {
                    # Create directory if needed (Force handles race condition)
                    $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop
                    return $configurationPath
                }
                catch {
                    Write-Debug "Documents folder not accessible ($($_.Exception.GetType().Name)), trying LocalAppData"
                }
            }
            else {
                Write-Debug "USERPROFILE path contains suspicious characters, using fallback"
            }
        }

        # Last resort: LocalAppData
        if ($env:LOCALAPPDATA) {
            # Validate LOCALAPPDATA doesn't contain path traversal sequences
            $localAppDataPath = $env:LOCALAPPDATA
            if ($localAppDataPath -notmatch '\.\.' -and $localAppDataPath -notmatch '[\x00-\x1F]') {
                $configurationDirectory = Join-Path $localAppDataPath 'PlexAutomationToolkit'
                # Create directory if needed (Force handles race condition)
                $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop
                return Join-Path $configurationDirectory 'servers.json'
            }
            else {
                Write-Debug "LOCALAPPDATA path contains suspicious characters"
            }
        }
    }

    # Linux/macOS: use ~/.config/PlexAutomationToolkit
    $homeDir = $env:HOME
    if (-not $homeDir) {
        $homeDir = [Environment]::GetFolderPath('UserProfile')
    }

    # Validate home directory doesn't contain path traversal sequences
    if ($homeDir -match '\.\.' -or $homeDir -match '[\x00-\x1F]') {
        throw "HOME path contains invalid characters - cannot determine safe configuration path"
    }

    $configurationDirectory = Join-Path $homeDir '.config/PlexAutomationToolkit'
    $configurationPath = Join-Path $configurationDirectory 'servers.json'

    # Create directory if needed
    $null = New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue

    return $configurationPath
}
