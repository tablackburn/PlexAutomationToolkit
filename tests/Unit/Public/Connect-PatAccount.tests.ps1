BeforeAll {
    $script:ModuleName = 'PlexAutomationToolkit'
    $ModuleManifestPath = "$PSScriptRoot/../../../Output/$ModuleName/$((Test-ModuleManifest "$PSScriptRoot/../../../$ModuleName/$ModuleName.psd1").Version)/$ModuleName.psd1"

    if (Get-Module -Name $ModuleName) {
        Remove-Module -Name $ModuleName -Force
    }
    Import-Module $ModuleManifestPath -Force
}

Describe 'Connect-PatAccount' {
    Context 'Parameter Validation' {
        BeforeEach {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { return 'mock-token' }
            }
        }

        It 'Should accept TimeoutSeconds parameter' {
            InModuleScope -ModuleName $script:ModuleName {
                { Connect-PatAccount -TimeoutSeconds 60 } | Should -Not -Throw
            }
        }

        It 'Should reject TimeoutSeconds less than 1' {
            InModuleScope -ModuleName $script:ModuleName {
                { Connect-PatAccount -TimeoutSeconds 0 } | Should -Throw
            }
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            InModuleScope -ModuleName $script:ModuleName {
                { Connect-PatAccount -TimeoutSeconds 2000 } | Should -Throw
            }
        }
    }

    Context 'Functionality' {
        BeforeEach {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { return 'mock-token-abc123' }
            }
        }

        It 'Should return authentication token' {
            InModuleScope -ModuleName $script:ModuleName {
                $result = Connect-PatAccount
                $result | Should -Be 'mock-token-abc123'
            }
        }

        It 'Should return a string' {
            InModuleScope -ModuleName $script:ModuleName {
                $result = Connect-PatAccount
                $result | Should -BeOfType [string]
            }
        }

        It 'Should throw when authentication fails' {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { throw 'Authentication failed' }
                { Connect-PatAccount } | Should -Throw '*Failed to authenticate with Plex*'
            }
        }
    }
}
