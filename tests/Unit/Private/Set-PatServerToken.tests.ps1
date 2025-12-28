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

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Set-PatServerToken.ps1')
}

Describe 'Set-PatServerToken' {
    Context 'When vault is available' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { }
        }

        It 'Should store token in vault and return Vault storage type' {
            $result = Set-PatServerToken -ServerName 'TestServer' -Token 'test-token-123'

            $result.StorageType | Should -Be 'Vault'
            $result.Token | Should -BeNullOrEmpty
            Should -Invoke Set-Secret -ParameterFilter {
                $Name -eq 'PlexAutomationToolkit/TestServer' -and $Secret -eq 'test-token-123'
            }
        }
    }

    Context 'When vault is not available' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $false }
        }

        It 'Should return Inline storage type with token' {
            $result = Set-PatServerToken -ServerName 'TestServer' -Token 'test-token-456' 3>&1

            $result.StorageType | Should -Be 'Inline'
            $result.Token | Should -Be 'test-token-456'
        }

        It 'Should emit a warning about plaintext storage' {
            $warnings = Set-PatServerToken -ServerName 'TestServer' -Token 'test-token-789' 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0].Message | Should -Match 'PLAINTEXT'
        }
    }

    Context 'When vault write fails' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { throw 'Vault write failed' }
        }

        It 'Should fall back to inline storage' {
            $result = Set-PatServerToken -ServerName 'TestServer' -Token 'test-token-fail' 3>&1 |
                Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }

            $result.StorageType | Should -Be 'Inline'
            $result.Token | Should -Be 'test-token-fail'
        }
    }

    Context 'When Force parameter is used' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Set-Secret { }
        }

        It 'Should skip vault and store inline without warning' {
            $result = Set-PatServerToken -ServerName 'TestServer' -Token 'forced-token' -Force

            $result.StorageType | Should -Be 'Inline'
            $result.Token | Should -Be 'forced-token'
            Should -Not -Invoke Set-Secret
        }
    }
}
