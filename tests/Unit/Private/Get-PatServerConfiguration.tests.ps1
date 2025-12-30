BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatServerConfiguration' {
    BeforeEach {
        # Mock Get-PatConfigurationPath to use temp location
        $script:testConfigPath = Join-Path $TestDrive 'servers.json'
        Mock -ModuleName PlexAutomationToolkit Get-PatConfigurationPath { return $script:testConfigPath }
    }

    Context 'When config file does not exist' {
        It 'Should return default empty config' {
            InModuleScope PlexAutomationToolkit -Parameters @{ testConfigPath = $script:testConfigPath } {
                $result = Get-PatServerConfiguration

                $result.version | Should -Be '1.0'
                $result.servers.Count | Should -Be 0
            }
        }

        It 'Should not create the file' {
            InModuleScope PlexAutomationToolkit -Parameters @{ testConfigPath = $script:testConfigPath } {
                Get-PatServerConfiguration
            }
            Test-Path $script:testConfigPath | Should -Be $false
        }
    }

    Context 'When config file exists with valid data' {
        It 'Should load configuration from file' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{
                        name    = 'Test Server'
                        uri     = 'http://test:32400'
                        default = $true
                    }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.version | Should -Be '1.0'
                $result.servers.Count | Should -Be 1
                $result.servers[0].name | Should -Be 'Test Server'
                $result.servers[0].uri | Should -Be 'http://test:32400'
                $result.servers[0].default | Should -Be $true
            }
        }

        It 'Should load multiple servers' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{ name = 'Server1'; uri = 'http://server1:32400'; default = $true }
                    @{ name = 'Server2'; uri = 'http://server2:32400'; default = $false }
                    @{ name = 'Server3'; uri = 'http://server3:32400'; default = $false }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.servers.Count | Should -Be 3
                $result.servers[0].name | Should -Be 'Server1'
                $result.servers[1].name | Should -Be 'Server2'
                $result.servers[2].name | Should -Be 'Server3'
            }
        }

        It 'Should preserve server with token' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{
                        name    = 'Authenticated Server'
                        uri     = 'http://auth:32400'
                        token   = 'ABC123xyz'
                        default = $true
                    }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.servers[0].token | Should -Be 'ABC123xyz'
            }
        }
    }

    Context 'When config file has invalid data' {
        It 'Should throw on missing version property' {
            $invalidConfig = @{
                servers = @()
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw "*version*"
            }
        }

        It 'Should throw on missing servers property' {
            $invalidConfig = @{
                version = '1.0'
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw "*servers*"
            }
        }

        It 'Should throw when servers is not an array' {
            $invalidConfig = @{
                version = '1.0'
                servers = 'not-an-array'
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw "*array*"
            }
        }

        It 'Should throw on invalid JSON' {
            [IO.File]::WriteAllText($script:testConfigPath, '{invalid json')

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw
            }
        }

        It 'Should throw on empty file' {
            [IO.File]::WriteAllText($script:testConfigPath, '')

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw
            }
        }
    }

    Context 'When file read fails' {
        It 'Should throw wrapped error on file access error' {
            # Create a directory with the same name to cause a read error
            $script:testConfigPath = Join-Path $TestDrive 'servers-dir.json'
            New-Item -Path $script:testConfigPath -ItemType Directory -Force | Out-Null

            Mock -ModuleName PlexAutomationToolkit Get-PatConfigurationPath { return $script:testConfigPath }

            InModuleScope PlexAutomationToolkit {
                { Get-PatServerConfiguration } | Should -Throw "*Failed to read server configuration*"
            }
        }
    }

    Context 'When config has edge case values' {
        It 'Should handle empty servers array' {
            $validConfig = @{
                version = '1.0'
                servers = @()
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.version | Should -Be '1.0'
                $result.servers.Count | Should -Be 0
            }
        }

        It 'Should handle servers with minimal properties' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{ name = 'Minimal'; uri = 'http://minimal:32400' }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.servers[0].name | Should -Be 'Minimal'
                $result.servers[0].uri | Should -Be 'http://minimal:32400'
            }
        }

        It 'Should preserve additional server properties' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{
                        name        = 'Extended'
                        uri         = 'http://extended:32400'
                        customField = 'custom-value'
                    }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.servers[0].customField | Should -Be 'custom-value'
            }
        }

        It 'Should handle different version strings' {
            $validConfig = @{
                version = '2.0'
                servers = @()
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            InModuleScope PlexAutomationToolkit {
                $result = Get-PatServerConfiguration

                $result.version | Should -Be '2.0'
            }
        }
    }
}
