BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the functions directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatConfigurationPath.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatServerConfiguration.ps1')
}

Describe 'Get-PatServerConfiguration' {
    BeforeEach {
        # Mock Get-PatConfigurationPath to use temp location
        $script:testConfigPath = Join-Path $TestDrive 'servers.json'
        Mock Get-PatConfigurationPath { return $script:testConfigPath }
    }

    Context 'When config file does not exist' {
        It 'Should return default empty config' {
            $result = Get-PatServerConfiguration

            $result.version | Should -Be '1.0'
            $result.servers.Count | Should -Be 0
        }

        It 'Should not create the file' {
            Get-PatServerConfiguration
            Test-Path $script:testConfigPath | Should -Be $false
        }
    }

    Context 'When config file exists with valid data' {
        It 'Should load configuration from file' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{
                        name = 'Test Server'
                        uri = 'http://test:32400'
                        default = $true
                    }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            $result = Get-PatServerConfiguration

            $result.version | Should -Be '1.0'
            $result.servers.Count | Should -Be 1
            $result.servers[0].name | Should -Be 'Test Server'
            $result.servers[0].uri | Should -Be 'http://test:32400'
            $result.servers[0].default | Should -Be $true
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

            $result = Get-PatServerConfiguration

            $result.servers.Count | Should -Be 3
            $result.servers[0].name | Should -Be 'Server1'
            $result.servers[1].name | Should -Be 'Server2'
            $result.servers[2].name | Should -Be 'Server3'
        }

        It 'Should preserve server with token' {
            $validConfig = @{
                version = '1.0'
                servers = @(
                    @{
                        name = 'Authenticated Server'
                        uri = 'http://auth:32400'
                        token = 'ABC123xyz'
                        default = $true
                    }
                )
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $validConfig)

            $result = Get-PatServerConfiguration

            $result.servers[0].token | Should -Be 'ABC123xyz'
        }
    }

    Context 'When config file has invalid data' {
        It 'Should throw on missing version property' {
            $invalidConfig = @{
                servers = @()
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            { Get-PatServerConfiguration } | Should -Throw "*version*"
        }

        It 'Should throw on missing servers property' {
            $invalidConfig = @{
                version = '1.0'
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            { Get-PatServerConfiguration } | Should -Throw "*servers*"
        }

        It 'Should throw when servers is not an array' {
            $invalidConfig = @{
                version = '1.0'
                servers = 'not-an-array'
            } | ConvertTo-Json

            [IO.File]::WriteAllText($script:testConfigPath, $invalidConfig)

            { Get-PatServerConfiguration } | Should -Throw "*array*"
        }

        It 'Should throw on invalid JSON' {
            [IO.File]::WriteAllText($script:testConfigPath, '{invalid json')

            { Get-PatServerConfiguration } | Should -Throw
        }

        It 'Should throw on empty file' {
            [IO.File]::WriteAllText($script:testConfigPath, '')

            { Get-PatServerConfiguration } | Should -Throw
        }
    }
}
