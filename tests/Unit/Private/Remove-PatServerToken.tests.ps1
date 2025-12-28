BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Create stub functions for SecretManagement cmdlets (if not already present)
    if (-not (Get-Command -Name 'Get-Secret' -ErrorAction SilentlyContinue)) {
        function global:Get-Secret { param($Name, [switch]$AsPlainText) }
    }
    if (-not (Get-Command -Name 'Remove-Secret' -ErrorAction SilentlyContinue)) {
        function global:Remove-Secret { param($Name) }
    }
    if (-not (Get-Command -Name 'Get-SecretVault' -ErrorAction SilentlyContinue)) {
        function global:Get-SecretVault { param() }
    }

    # Import dependencies
    . (Join-Path $ModuleRoot 'Private\Get-PatSecretManagementAvailable.ps1')

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Remove-PatServerToken.ps1')
}

Describe 'Remove-PatServerToken' {
    Context 'When vault is available and contains token' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Get-Secret { 'existing-token' } -ParameterFilter { $Name -eq 'PlexAutomationToolkit/TestServer' }
            Mock Remove-Secret { }
        }

        It 'Should remove token from vault' {
            Remove-PatServerToken -ServerName 'TestServer'

            Should -Invoke Remove-Secret -ParameterFilter {
                $Name -eq 'PlexAutomationToolkit/TestServer'
            }
        }
    }

    Context 'When vault is available but token does not exist' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Get-Secret { $null }
            Mock Remove-Secret { }
        }

        It 'Should not call Remove-Secret' {
            Remove-PatServerToken -ServerName 'NonExistent'

            Should -Not -Invoke Remove-Secret
        }

        It 'Should not throw' {
            { Remove-PatServerToken -ServerName 'NonExistent' } | Should -Not -Throw
        }
    }

    Context 'When vault is not available' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $false }
            Mock Remove-Secret { }
        }

        It 'Should not attempt to remove from vault' {
            Remove-PatServerToken -ServerName 'TestServer'

            Should -Not -Invoke Remove-Secret
        }

        It 'Should not throw' {
            { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
        }
    }

    Context 'When Remove-Secret throws an error' {
        BeforeAll {
            Mock Get-PatSecretManagementAvailable { $true }
            Mock Get-Secret { 'existing-token' }
            Mock Remove-Secret { throw 'Remove failed' }
        }

        It 'Should emit a warning but not throw' {
            $warnings = Remove-PatServerToken -ServerName 'TestServer' 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should not throw' {
            { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
        }
    }
}
