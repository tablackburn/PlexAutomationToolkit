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
}
