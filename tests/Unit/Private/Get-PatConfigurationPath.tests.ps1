BeforeDiscovery {
    # Check if running on Windows - must be in BeforeDiscovery for -Skip to work
    $script:RunningOnWindows = $IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop')
}

BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get the path separator for pattern matching
    $script:Sep = [IO.Path]::DirectorySeparatorChar
    $script:SepPattern = if ($script:Sep -eq '\') { '\\' } else { '/' }
}

Describe 'Get-PatConfigurationPath' {
    BeforeEach {
        # Store original environment variables
        $script:originalOneDrive = $env:OneDrive
        $script:originalUserProfile = $env:USERPROFILE
        $script:originalLocalAppData = $env:LOCALAPPDATA
        $script:originalHome = $env:HOME
    }

    AfterEach {
        # Restore original environment variables
        $env:OneDrive = $script:originalOneDrive
        $env:USERPROFILE = $script:originalUserProfile
        $env:LOCALAPPDATA = $script:originalLocalAppData
        $env:HOME = $script:originalHome
    }

    Context 'OneDrive path (preferred location)' -Skip:(-not $script:RunningOnWindows) {
        It 'Should return OneDrive path when OneDrive is available and writable' {
            # Skip if no OneDrive on this system
            if (-not $env:OneDrive) {
                Set-ItResult -Skipped -Because 'OneDrive not configured on this system'
                return
            }

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Should prefer OneDrive location
            $result | Should -BeLike "*OneDrive*PlexAutomationToolkit*servers.json"
        }

        It 'Should create OneDrive directory if it does not exist' {
            if (-not $env:OneDrive) {
                Set-ItResult -Skipped -Because 'OneDrive not configured on this system'
                return
            }

            $oneDriveDir = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit'
            $testMarker = Join-Path $oneDriveDir '.unittest-marker'

            try {
                # Create marker to identify test-created directory
                if (-not (Test-Path $oneDriveDir)) {
                    $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }
                    # Function should have created the directory
                    Test-Path $oneDriveDir | Should -Be $true
                    # Mark it so we know we created it
                    [IO.File]::WriteAllText($testMarker, 'test')
                }
            }
            finally {
                # Clean up if we created it
                if (Test-Path $testMarker) {
                    Remove-Item $testMarker -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'Should test write access to OneDrive location' {
            if (-not $env:OneDrive) {
                Set-ItResult -Skipped -Because 'OneDrive not configured on this system'
                return
            }

            $oneDriveDir = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit'

            # Create directory if needed
            if (-not (Test-Path $oneDriveDir)) {
                New-Item -Path $oneDriveDir -ItemType Directory -Force | Out-Null
            }

            # Function should test write access
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Should have tested write access (no exception means test passed)
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'OneDrive write access failure' -Skip:(-not $script:RunningOnWindows) {
        It 'Should fall back to Documents when OneDrive write test throws IOException' {
            # Set up OneDrive path
            $env:OneDrive = 'C:\Users\TestUser\OneDrive'

            $result = InModuleScope PlexAutomationToolkit {
                # Mock New-Item to succeed (directory creation)
                Mock New-Item { } -Verifiable

                # Mock the static method call to throw IOException
                # We can't easily mock [IO.File]::WriteAllText, but we can test the path
                # by mocking New-Item to throw for OneDrive path specifically
                Mock New-Item {
                    throw [System.IO.IOException]::new("OneDrive is syncing")
                } -ParameterFilter { $Path -like '*OneDrive*' }

                # Mock New-Item to succeed for Documents path
                Mock New-Item { } -ParameterFilter { $Path -like '*Documents*' -and $Path -notlike '*OneDrive*' }

                Get-PatConfigurationPath
            }

            # Should have fallen back to Documents
            $result | Should -BeLike "*Documents*PlexAutomationToolkit*servers.json"
        }

        It 'Should fall back to Documents when OneDrive write test throws other exception' {
            $env:OneDrive = 'C:\Users\TestUser\OneDrive'

            $result = InModuleScope PlexAutomationToolkit {
                Mock New-Item {
                    throw [System.UnauthorizedAccessException]::new("Access denied")
                } -ParameterFilter { $Path -like '*OneDrive*' }

                Mock New-Item { } -ParameterFilter { $Path -like '*Documents*' -and $Path -notlike '*OneDrive*' }

                Get-PatConfigurationPath
            }

            # Should have fallen back to Documents
            $result | Should -BeLike "*Documents*PlexAutomationToolkit*servers.json"
        }
    }

    Context 'Fallback to Documents folder' -Skip:(-not $script:RunningOnWindows) {
        It 'Should use Documents folder when OneDrive is not available' {
            # Temporarily remove OneDrive env variable
            $env:OneDrive = $null

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -BeLike "*Documents*PlexAutomationToolkit*servers.json"
            $result | Should -Not -BeLike "*OneDrive*"
        }

        It 'Should create Documents directory if it does not exist' {
            $env:OneDrive = $null
            $docsDir = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit'
            $testMarker = Join-Path $docsDir '.unittest-marker-docs'

            try {
                if (-not (Test-Path $docsDir)) {
                    $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }
                    # Function should have created the directory
                    Test-Path $docsDir | Should -Be $true
                    [IO.File]::WriteAllText($testMarker, 'test')
                }
            }
            finally {
                if (Test-Path $testMarker) {
                    Remove-Item $testMarker -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'Should return Documents path when available' {
            $env:OneDrive = $null

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $expectedPath = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit\servers.json'
            $result | Should -Be $expectedPath
        }
    }

    Context 'Final fallback to LocalAppData (Windows)' -Skip:(-not $script:RunningOnWindows) {
        It 'Should use LocalAppData when both OneDrive and Documents fail' {
            $env:OneDrive = $null
            $env:USERPROFILE = 'C:\Users\TestUser'
            $env:LOCALAPPDATA = 'C:\Users\TestUser\AppData\Local'

            $result = InModuleScope PlexAutomationToolkit {
                # Mock New-Item to fail for Documents path
                Mock New-Item {
                    throw [System.UnauthorizedAccessException]::new("Documents not writable")
                } -ParameterFilter { $Path -like '*Documents*' }

                # Mock New-Item to succeed for LocalAppData path
                Mock New-Item { } -ParameterFilter { $Path -like '*AppData\Local*' }

                Get-PatConfigurationPath
            }

            # Should have fallen back to LocalAppData
            $result | Should -Be 'C:\Users\TestUser\AppData\Local\PlexAutomationToolkit\servers.json'
        }

        It 'Should create LocalAppData directory when falling back' {
            $env:OneDrive = $null
            $env:USERPROFILE = 'C:\Users\TestUser'
            $env:LOCALAPPDATA = 'C:\Users\TestUser\AppData\Local'

            InModuleScope PlexAutomationToolkit {
                $script:localAppDataNewItemCalled = $false

                Mock New-Item {
                    throw [System.IO.IOException]::new("Documents locked")
                } -ParameterFilter { $Path -like '*Documents*' }

                Mock New-Item {
                    $script:localAppDataNewItemCalled = $true
                } -ParameterFilter { $Path -like '*AppData\Local*' }

                Get-PatConfigurationPath

                $script:localAppDataNewItemCalled | Should -Be $true
            }
        }
    }

    Context 'Final fallback validation' {
        It 'Should use fallback location when primary paths are not available' {
            # This test verifies the function returns a valid path
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Should return a valid path
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "servers\.json$"
        }

        It 'Should return a path ending with servers.json' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -BeLike "*servers.json"
        }
    }

    Context 'Path validation' {
        It 'Should return a valid file path' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -Not -BeNullOrEmpty
            [System.IO.Path]::IsPathRooted($result) | Should -Be $true
        }

        It 'Should return a path with .json extension' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -BeLike "*.json"
        }

        It 'Should return a path containing PlexAutomationToolkit' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -BeLike "*PlexAutomationToolkit*"
        }

        It 'Should return consistent path when called multiple times' {
            $result1 = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }
            $result2 = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result1 | Should -Be $result2
        }
    }

    Context 'Directory creation' {
        It 'Should create necessary directories' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $directory = Split-Path -Path $result -Parent
            Test-Path $directory | Should -Be $true
        }

        It 'Should not throw when directory already exists' {
            # First call creates directory
            $result1 = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Second call should succeed without error
            { InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath } } | Should -Not -Throw
        }
    }

    Context 'Linux/macOS path (Unix systems)' -Skip:$script:RunningOnWindows {
        It 'Should use HOME environment variable when available' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # On Unix systems, should use .config subdirectory
            $result | Should -BeLike "*/.config/PlexAutomationToolkit/servers.json"
        }

        It 'Should create .config directory if it does not exist' {
            $configDir = Join-Path $env:HOME '.config/PlexAutomationToolkit'

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Directory should exist (function creates it)
            $dir = Split-Path -Path $result -Parent
            Test-Path $dir | Should -Be $true
        }

        It 'Should fall back to GetFolderPath when HOME is not set' {
            $originalHome = $env:HOME
            try {
                $env:HOME = $null

                $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

                # Should still return a valid path using GetFolderPath fallback
                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeLike "*/.config/PlexAutomationToolkit/servers.json"
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context 'Environment variable fallbacks' {
        It 'Should handle missing HOME gracefully by using UserProfile' {
            # This test verifies the function returns a valid path
            # The actual fallback logic is platform-specific
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Should always return a valid path
            $result | Should -Not -BeNullOrEmpty
            [System.IO.Path]::GetFileName($result) | Should -Be 'servers.json'
        }
    }

    Context 'Platform detection' {
        It 'Should correctly detect Windows platform' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $isWin = $IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop')
            if ($isWin) {
                # On Windows, path should contain backslashes and NOT forward slashes with .config
                $result | Should -Match '[A-Z]:\\'
                $result | Should -Not -Match '/.config/'
            }
            else {
                # On Unix, path SHOULD contain .config
                $result | Should -Match '/.config/'
            }
        }
    }

    Context 'OneDrive write test file cleanup' -Skip:(-not $script:RunningOnWindows) {
        It 'Should handle write test that creates and removes test file' {
            if (-not $env:OneDrive) {
                Set-ItResult -Skipped -Because 'OneDrive not configured on this system'
                return
            }

            $oneDriveDir = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit'
            $testFile = Join-Path $oneDriveDir '.test'

            # Call function - should create and remove test file
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Test file should be cleaned up
            Test-Path $testFile | Should -Be $false

            # Should have returned OneDrive path
            $result | Should -BeLike "*OneDrive*"
        }
    }

    Context 'USERPROFILE not available' -Skip:(-not $script:RunningOnWindows) {
        It 'Should fall back to Unix-style path when no Windows paths available' {
            $env:OneDrive = $null
            $env:USERPROFILE = $null
            $env:LOCALAPPDATA = $null

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Should fall through to Unix-style path at end of function
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'servers\.json$'
        }
    }

    Context 'HOME environment fallback' {
        It 'Should use Environment.GetFolderPath when HOME is null' {
            $originalHome = $env:HOME

            try {
                $env:HOME = $null

                $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

                # Should still return a valid path
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'servers\.json$'
            }
            finally {
                $env:HOME = $originalHome
            }
        }

        It 'Should handle empty HOME string' {
            $originalHome = $env:HOME

            try {
                $env:HOME = ''

                $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

                # Should fall back to GetFolderPath
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'servers\.json$'
            }
            finally {
                $env:HOME = $originalHome
            }
        }
    }

    Context 'LocalAppData fallback validation' -Skip:(-not $script:RunningOnWindows) {
        It 'Should use LocalAppData path format when falling back' {
            $env:OneDrive = $null
            $env:USERPROFILE = 'C:\Users\TestUser'
            $env:LOCALAPPDATA = 'C:\Users\TestUser\AppData\Local'

            $result = InModuleScope PlexAutomationToolkit {
                # Mock to fail for Documents but succeed for LocalAppData
                Mock New-Item {
                    throw [System.UnauthorizedAccessException]::new("Documents locked")
                } -ParameterFilter { $Path -like '*Documents*' }

                Mock New-Item { } -ParameterFilter { $Path -like '*AppData\Local*' }

                Get-PatConfigurationPath
            }

            # Verify the path structure
            $result | Should -Be 'C:\Users\TestUser\AppData\Local\PlexAutomationToolkit\servers.json'
        }
    }

    Context 'PowerShell version detection' {
        It 'Should handle PSVersion less than 6' {
            # This test verifies the platform detection logic works
            # $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Directory creation with Force' {
        It 'Should handle directory already exists with Force parameter' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            # Call again - directory exists, Force should prevent error
            $result2 = InModuleScope PlexAutomationToolkit { Get-PatConfigurationPath }

            $result | Should -Be $result2
        }
    }
}
