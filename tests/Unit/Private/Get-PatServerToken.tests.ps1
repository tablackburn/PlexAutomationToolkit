BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Create stub functions for SecretManagement cmdlets (if not already present)
    if (-not (Get-Command -Name 'Get-Secret' -ErrorAction SilentlyContinue)) {
        function global:Get-Secret { param($Name, [switch]$AsPlainText) }
    }
    if (-not (Get-Command -Name 'Get-SecretVault' -ErrorAction SilentlyContinue)) {
        function global:Get-SecretVault { param() }
    }

    # Import dependencies
    . (Join-Path $ModuleRoot 'Private\Get-PatSecretManagementAvailable.ps1')

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatServerToken.ps1')
}

Describe 'Get-PatServerToken' {
    Context 'When vault is available and contains token' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Get-Secret { 'vault-token-123' } -ParameterFilter { $Name -eq 'PlexAutomationToolkit/TestServer' }
        }

        It 'Should return token from vault' {
            $server = [PSCustomObject]@{
                name = 'TestServer'
                uri  = 'http://test:32400'
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -Be 'vault-token-123'
        }

        It 'Should work with ServerName parameter' {
            $token = Get-PatServerToken -ServerName 'TestServer'
            $token | Should -Be 'vault-token-123'
        }
    }

    Context 'When vault is available but token not in vault' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Get-Secret { $null }
        }

        It 'Should fall back to inline token' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = 'inline-token-456'
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -Be 'inline-token-456'
        }

        It 'Should return null when no inline token exists' {
            $server = [PSCustomObject]@{
                name = 'TestServer'
                uri  = 'http://test:32400'
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -BeNullOrEmpty
        }
    }

    Context 'When vault is not available' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $false }
        }

        It 'Should return inline token' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = 'inline-token-789'
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -Be 'inline-token-789'
        }

        It 'Should return null when no inline token and vault unavailable' {
            $server = [PSCustomObject]@{
                name = 'TestServer'
                uri  = 'http://test:32400'
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -BeNullOrEmpty
        }
    }

    Context 'When inline token is empty or whitespace' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $false }
        }

        It 'Should return null for empty string token' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = ''
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -BeNullOrEmpty
        }

        It 'Should return null for whitespace token' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = '   '
            }

            $token = Get-PatServerToken -ServerConfig $server
            $token | Should -BeNullOrEmpty
        }
    }
}
