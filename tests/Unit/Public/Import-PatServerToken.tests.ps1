BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Create stub functions for SecretManagement cmdlets (if not already present)
    if (-not (Get-Command -Name 'Set-Secret' -ErrorAction SilentlyContinue)) {
        function global:Set-Secret { param($Name, $Secret) }
    }
    if (-not (Get-Command -Name 'Get-SecretVault' -ErrorAction SilentlyContinue)) {
        function global:Get-SecretVault { param() }
    }

    # Import dependencies
    . (Join-Path $ModuleRoot 'Private\Get-PatSecretManagementAvailable.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatConfigurationPath.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatServerConfiguration.ps1')
    . (Join-Path $ModuleRoot 'Private\Set-PatServerConfiguration.ps1')

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Public\Import-PatServerToken.ps1')
}

Describe 'Import-PatServerToken' {
    BeforeEach {
        # Create temp config for testing
        $script:tempConfigPath = Join-Path $TestDrive 'servers.json'
        Mock Get-PatConfigurationPath { $script:tempConfigPath }
    }

    Context 'When SecretManagement is not available' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $false }
        }

        It 'Should throw an error' {
            { Import-PatServerToken } | Should -Throw '*SecretManagement is not available*'
        }
    }

    Context 'When migrating tokens' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { }
        }

        BeforeEach {
            $config = @{
                version = '1.0'
                servers = @(
                    @{ name = 'Server1'; uri = 'http://s1:32400'; token = 'token1' }
                    @{ name = 'Server2'; uri = 'http://s2:32400'; token = 'token2' }
                    @{ name = 'Server3'; uri = 'http://s3:32400' }  # No token
                )
            }
            $config | ConvertTo-Json -Depth 10 | Set-Content $script:tempConfigPath
        }

        It 'Should migrate all servers with plaintext tokens' {
            Import-PatServerToken

            Should -Invoke Set-Secret -Times 2
        }

        It 'Should migrate specific server when ServerName specified' {
            Import-PatServerToken -ServerName 'Server1'

            Should -Invoke Set-Secret -Times 1 -ParameterFilter {
                $Name -eq 'PlexAutomationToolkit/Server1'
            }
        }

        It 'Should return results with PassThru' {
            $results = Import-PatServerToken -PassThru

            $results | Should -Not -BeNullOrEmpty
            @($results).Count | Should -Be 3  # 2 migrated + 1 skipped (no token)
            @($results | Where-Object { $_.Status -eq 'Migrated' }).Count | Should -Be 2
            @($results | Where-Object { $_.Status -eq 'Skipped' }).Count | Should -Be 1
        }

        It 'Should skip servers without tokens' {
            $results = Import-PatServerToken -PassThru

            $skipped = $results | Where-Object { $_.ServerName -eq 'Server3' }
            $skipped.Status | Should -Be 'Skipped'
        }

        It 'Should update configuration file after migration' {
            Import-PatServerToken

            $updatedConfig = Get-Content $script:tempConfigPath | ConvertFrom-Json
            $server1 = $updatedConfig.servers | Where-Object { $_.name -eq 'Server1' }

            $server1.tokenInVault | Should -Be $true
            $server1.PSObject.Properties['token'] | Should -BeNullOrEmpty
        }
    }

    Context 'When server already has tokenInVault' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { }
        }

        BeforeEach {
            $config = @{
                version = '1.0'
                servers = @(
                    @{ name = 'VaultServer'; uri = 'http://vault:32400'; tokenInVault = $true }
                )
            }
            $config | ConvertTo-Json -Depth 10 | Set-Content $script:tempConfigPath
        }

        It 'Should skip server that is already in vault' {
            $results = Import-PatServerToken -PassThru

            $results[0].Status | Should -Be 'Skipped'
            $results[0].Message | Should -Match 'already stored in vault'
            Should -Not -Invoke Set-Secret
        }
    }

    Context 'When ServerName does not exist' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
        }

        BeforeEach {
            $config = @{
                version = '1.0'
                servers = @(
                    @{ name = 'ExistingServer'; uri = 'http://s1:32400'; token = 'token1' }
                )
            }
            $config | ConvertTo-Json -Depth 10 | Set-Content $script:tempConfigPath
        }

        It 'Should throw an error' {
            { Import-PatServerToken -ServerName 'NonExistent' } | Should -Throw "*not found*"
        }
    }

    Context 'WhatIf support' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { }
        }

        BeforeEach {
            $config = @{
                version = '1.0'
                servers = @(
                    @{ name = 'TestServer'; uri = 'http://test:32400'; token = 'testtoken' }
                )
            }
            $config | ConvertTo-Json -Depth 10 | Set-Content $script:tempConfigPath
        }

        It 'Should not modify anything with WhatIf' {
            Import-PatServerToken -WhatIf

            Should -Not -Invoke Set-Secret
            $config = Get-Content $script:tempConfigPath | ConvertFrom-Json
            $config.servers[0].token | Should -Be 'testtoken'
        }
    }
}
