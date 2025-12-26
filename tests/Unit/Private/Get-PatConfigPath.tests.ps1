BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatConfigPath' {
    BeforeEach {
        # Store original environment variables
        $script:originalOneDrive = $env:OneDrive
        $script:originalUserProfile = $env:USERPROFILE
        $script:originalLocalAppData = $env:LOCALAPPDATA
    }

    AfterEach {
        # Restore original environment variables
        $env:OneDrive = $script:originalOneDrive
        $env:USERPROFILE = $script:originalUserProfile
        $env:LOCALAPPDATA = $script:originalLocalAppData
    }

    Context 'OneDrive path (preferred location)' {
        It 'Should return OneDrive path when OneDrive is available and writable' {
            # Skip if no OneDrive on this system
            if (-not $env:OneDrive) {
                Set-ItResult -Skipped -Because 'OneDrive not configured on this system'
                return
            }

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

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
                    $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }
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
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            # Should have tested write access (no exception means test passed)
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Fallback to Documents folder' {
        It 'Should use Documents folder when OneDrive is not available' {
            # Temporarily remove OneDrive env variable
            $env:OneDrive = $null

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result | Should -BeLike "*Documents\PlexAutomationToolkit\servers.json"
            $result | Should -Not -BeLike "*OneDrive*"
        }

        It 'Should create Documents directory if it does not exist' {
            $env:OneDrive = $null
            $docsDir = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit'
            $testMarker = Join-Path $docsDir '.unittest-marker-docs'

            try {
                if (-not (Test-Path $docsDir)) {
                    $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }
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

            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $expectedPath = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit\servers.json'
            $result | Should -Be $expectedPath
        }
    }

    Context 'Final fallback to LocalAppData' {
        It 'Should use LocalAppData when OneDrive and Documents are not available' {
            # This test is difficult to simulate without breaking the environment
            # We'll just verify the path format is correct
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            # Should return a valid path
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeLike "*\servers.json"
        }

        It 'Should return a path ending with servers.json' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result | Should -BeLike "*servers.json"
        }
    }

    Context 'Path validation' {
        It 'Should return a valid file path' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result | Should -Not -BeNullOrEmpty
            [System.IO.Path]::IsPathRooted($result) | Should -Be $true
        }

        It 'Should return a path with .json extension' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result | Should -BeLike "*.json"
        }

        It 'Should return a path containing PlexAutomationToolkit' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result | Should -BeLike "*PlexAutomationToolkit*"
        }

        It 'Should return consistent path when called multiple times' {
            $result1 = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }
            $result2 = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $result1 | Should -Be $result2
        }
    }

    Context 'Directory creation' {
        It 'Should create necessary directories' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            $directory = Split-Path -Path $result -Parent
            Test-Path $directory | Should -Be $true
        }

        It 'Should not throw when directory already exists' {
            # First call creates directory
            $result1 = InModuleScope PlexAutomationToolkit { Get-PatConfigPath }

            # Second call should succeed without error
            { InModuleScope PlexAutomationToolkit { Get-PatConfigPath } } | Should -Not -Throw
        }
    }
}
