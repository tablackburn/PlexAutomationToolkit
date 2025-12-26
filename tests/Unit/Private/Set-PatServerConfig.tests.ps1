BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the functions directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatConfigPath.ps1')
    . (Join-Path $ModuleRoot 'Private\Set-PatServerConfig.ps1')
}

Describe 'Set-PatServerConfig' {
    BeforeEach {
        # Mock Get-PatConfigPath to use temp location
        $script:testConfigPath = Join-Path $TestDrive 'servers.json'
        Mock Get-PatConfigPath { return $script:testConfigPath }
    }

    Context 'When writing valid config' {
        It 'Should create config file with correct content' {
            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{
                        name = 'Test Server'
                        uri = 'http://test:32400'
                        default = $true
                    }
                )
            }

            Set-PatServerConfig -Config $config

            Test-Path $script:testConfigPath | Should -Be $true

            $content = Get-Content $script:testConfigPath -Raw | ConvertFrom-Json
            $content.version | Should -Be '1.0'
            $content.servers.Count | Should -Be 1
            $content.servers[0].name | Should -Be 'Test Server'
        }

        It 'Should create parent directory if it does not exist' {
            $nestedPath = Join-Path $TestDrive 'nested\dir\servers.json'
            Mock Get-PatConfigPath { return $nestedPath }

            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @()
            }

            Set-PatServerConfig -Config $config

            Test-Path $nestedPath | Should -Be $true
            Test-Path (Split-Path $nestedPath -Parent) | Should -Be $true
        }

        It 'Should overwrite existing config' {
            # Write initial config
            $initialConfig = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{ name = 'Old'; uri = 'http://old:32400'; default = $true }
                )
            }
            Set-PatServerConfig -Config $initialConfig

            # Overwrite with new config
            $newConfig = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{ name = 'New'; uri = 'http://new:32400'; default = $true }
                )
            }
            Set-PatServerConfig -Config $newConfig

            $content = Get-Content $script:testConfigPath -Raw | ConvertFrom-Json
            $content.servers.Count | Should -Be 1
            $content.servers[0].name | Should -Be 'New'
        }

        It 'Should handle empty servers array' {
            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @()
            }

            Set-PatServerConfig -Config $config

            $content = Get-Content $script:testConfigPath -Raw | ConvertFrom-Json
            $content.servers.Count | Should -Be 0
        }

        It 'Should preserve server tokens' {
            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{
                        name = 'Auth Server'
                        uri = 'http://auth:32400'
                        token = 'ABC123xyz'
                        default = $true
                    }
                )
            }

            Set-PatServerConfig -Config $config

            $content = Get-Content $script:testConfigPath -Raw | ConvertFrom-Json
            $content.servers[0].token | Should -Be 'ABC123xyz'
        }

        It 'Should write UTF-8 without BOM' {
            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @()
            }

            Set-PatServerConfig -Config $config

            # Read raw bytes to check for BOM
            $bytes = [IO.File]::ReadAllBytes($script:testConfigPath)
            # UTF-8 BOM is EF BB BF - should NOT be present
            if ($bytes.Length -ge 3) {
                $hasBom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
                $hasBom | Should -Be $false
            }
        }
    }

    Context 'When config is invalid' {
        It 'Should throw on null config' {
            { Set-PatServerConfig -Config $null } | Should -Throw
        }

        It 'Should throw on missing version property' {
            $config = [PSCustomObject]@{
                servers = @()
            }

            { Set-PatServerConfig -Config $config } | Should -Throw "*version*"
        }

        It 'Should throw on missing servers property' {
            $config = [PSCustomObject]@{
                version = '1.0'
            }

            { Set-PatServerConfig -Config $config } | Should -Throw "*servers*"
        }
    }

    Context 'JSON formatting' {
        It 'Should format JSON with proper indentation' {
            $config = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{
                        name = 'Test'
                        uri = 'http://test:32400'
                        default = $true
                    }
                )
            }

            Set-PatServerConfig -Config $config

            $content = Get-Content $script:testConfigPath -Raw
            # Should be formatted JSON (contains newlines)
            $content | Should -Match '\n'
        }
    }
}
