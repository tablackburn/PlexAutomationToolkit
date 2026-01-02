BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatServerToken' {
    # Note: SecretManagement is a binary module - Pester cannot mock binary cmdlets (Get-Secret, Remove-Secret)
    # These tests verify the mockable code paths; integration tests verify actual vault behavior

    Context 'Basic functionality' {
        It 'Should call Get-PatSecretManagementAvailable to check vault availability' {
            Mock -CommandName Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -MockWith { $false }

            InModuleScope PlexAutomationToolkit {
                Remove-PatServerToken -ServerName 'TestServer'
            }

            Should -Invoke Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Should not throw when vault is not available' {
            Mock -CommandName Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -MockWith { $false }

            InModuleScope PlexAutomationToolkit {
                { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
            }
        }

        It 'Should accept ServerName parameter' {
            Mock -CommandName Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -MockWith { $false }

            InModuleScope PlexAutomationToolkit {
                { Remove-PatServerToken -ServerName 'My-Server' } | Should -Not -Throw
            }
        }

        It 'Should require ServerName parameter' {
            InModuleScope PlexAutomationToolkit {
                { Remove-PatServerToken } | Should -Throw
            }
        }
    }

    Context 'When vault is not available' {
        BeforeAll {
            Mock -CommandName Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -MockWith { $false }
        }

        It 'Should not throw' {
            InModuleScope PlexAutomationToolkit {
                { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
            }
        }

        It 'Should complete silently without vault' {
            InModuleScope PlexAutomationToolkit {
                $result = Remove-PatServerToken -ServerName 'TestServer'
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Error handling when vault operations fail' {
        # When Get-PatSecretManagementAvailable returns true but vault operations fail,
        # the function should catch errors and emit warnings instead of throwing

        It 'Should not throw even if vault operation would fail' {
            # This test verifies error handling - when vault is available but operation fails
            # The actual error scenario requires a real vault; here we just verify non-throwing behavior
            Mock -CommandName Get-PatSecretManagementAvailable -ModuleName PlexAutomationToolkit -MockWith { $false }

            InModuleScope PlexAutomationToolkit {
                { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
            }
        }
    }

    Context 'When vault is available and secret exists' -Skip:(-not (Get-Module -ListAvailable -Name 'Microsoft.PowerShell.SecretManagement')) {
        # Note: Remove-Secret is a binary cmdlet that's difficult to mock directly
        # We test behavior instead of invocation

        It 'Checks for secret using Get-SecretInfo' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatSecretManagementAvailable { $true }
                Mock Get-SecretInfo { [PSCustomObject]@{ Name = 'PlexAutomationToolkit/TestServer' } }
                Mock Remove-Secret { }

                Remove-PatServerToken -ServerName 'TestServer'

                Should -Invoke Get-SecretInfo -Times 1 -ParameterFilter {
                    $Name -eq 'PlexAutomationToolkit/TestServer'
                }
            }
        }

        It 'Attempts to remove the secret when it exists (emits warning on failure)' {
            # Since Remove-Secret binary cmdlet is hard to mock, we verify by checking
            # that when the secret exists, an attempt is made (which fails with a warning)
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatSecretManagementAvailable { $true }
                Mock Get-SecretInfo { [PSCustomObject]@{ Name = 'PlexAutomationToolkit/TestServer' } }

                $warnings = Remove-PatServerToken -ServerName 'TestServer' 3>&1
                # When Remove-Secret is called but fails (not properly mocked), we get a warning
                $warnings | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'When vault is available but secret does not exist' -Skip:(-not (Get-Module -ListAvailable -Name 'Microsoft.PowerShell.SecretManagement')) {
        It 'Does not attempt to remove secret' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatSecretManagementAvailable { $true }
                Mock Get-SecretInfo { $null }
                Mock Remove-Secret { }

                Remove-PatServerToken -ServerName 'TestServer'

                Should -Invoke Remove-Secret -Times 0
            }
        }
    }

    Context 'When Remove-Secret throws an error' -Skip:(-not (Get-Module -ListAvailable -Name 'Microsoft.PowerShell.SecretManagement')) {
        It 'Catches the error and emits a warning' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatSecretManagementAvailable { $true }
                Mock Get-SecretInfo { [PSCustomObject]@{ Name = 'PlexAutomationToolkit/TestServer' } }
                Mock Remove-Secret { throw 'Vault access denied' }

                $warnings = Remove-PatServerToken -ServerName 'TestServer' 3>&1
                $warnings | Should -Not -BeNullOrEmpty
                $warnings[0].Message | Should -Match 'Failed to remove token from vault'
            }
        }

        It 'Does not throw' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatSecretManagementAvailable { $true }
                Mock Get-SecretInfo { [PSCustomObject]@{ Name = 'PlexAutomationToolkit/TestServer' } }
                Mock Remove-Secret { throw 'Vault access denied' }

                { Remove-PatServerToken -ServerName 'TestServer' } | Should -Not -Throw
            }
        }
    }
}
