BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Create stub functions for SecretManagement cmdlets (if not already present)
    if (-not (Get-Command -Name 'Get-SecretVault' -ErrorAction SilentlyContinue)) {
        function global:Get-SecretVault { param() }
    }

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatSecretManagementAvailable.ps1')
}

Describe 'Get-PatSecretManagementAvailable' {
    Context 'When SecretManagement module is not installed' {
        BeforeAll {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Microsoft.PowerShell.SecretManagement' }
        }

        It 'Should return false' {
            Get-PatSecretManagementAvailable | Should -Be $false
        }
    }

    Context 'When SecretManagement module is installed but no vaults registered' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement'; Version = '1.0.0' }
            } -ParameterFilter { $ListAvailable -eq $true -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Microsoft.PowerShell.SecretManagement' -and -not $ListAvailable }
            Mock Import-Module { }
            Mock Get-SecretVault { @() }
        }

        It 'Should return false' {
            Get-PatSecretManagementAvailable | Should -Be $false
        }
    }

    Context 'When SecretManagement is fully configured' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement'; Version = '1.0.0' }
            } -ParameterFilter { $ListAvailable -eq $true -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement' }
            } -ParameterFilter { $Name -eq 'Microsoft.PowerShell.SecretManagement' -and -not $ListAvailable }

            Mock Get-SecretVault {
                @([PSCustomObject]@{ Name = 'TestVault' })
            }
        }

        It 'Should return true' {
            Get-PatSecretManagementAvailable | Should -Be $true
        }
    }

    Context 'When Get-SecretVault throws an error' {
        BeforeAll {
            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement'; Version = '1.0.0' }
            } -ParameterFilter { $ListAvailable -eq $true -and $Name -eq 'Microsoft.PowerShell.SecretManagement' }

            Mock Get-Module {
                [PSCustomObject]@{ Name = 'Microsoft.PowerShell.SecretManagement' }
            } -ParameterFilter { $Name -eq 'Microsoft.PowerShell.SecretManagement' -and -not $ListAvailable }

            Mock Get-SecretVault { throw 'Vault error' }
        }

        It 'Should return false and not throw' {
            { Get-PatSecretManagementAvailable } | Should -Not -Throw
            Get-PatSecretManagementAvailable | Should -Be $false
        }
    }
}
