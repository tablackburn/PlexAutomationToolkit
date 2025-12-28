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

    Context 'Force parameter' {
        BeforeEach {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { return 'force-token' }
            }
        }

        It 'Should pass Force to Invoke-PatPinAuthentication' {
            InModuleScope -ModuleName $script:ModuleName {
                Connect-PatAccount -Force

                Should -Invoke Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                    $Force -eq $true
                }
            }
        }

        It 'Should work with Force and custom TimeoutSeconds' {
            InModuleScope -ModuleName $script:ModuleName {
                $result = Connect-PatAccount -Force -TimeoutSeconds 120

                $result | Should -Be 'force-token'
                Should -Invoke Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                    $Force -eq $true -and $TimeoutSeconds -eq 120
                }
            }
        }
    }

    Context 'TimeoutSeconds edge cases' {
        BeforeEach {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { return 'timeout-token' }
            }
        }

        It 'Should accept minimum value (1)' {
            InModuleScope -ModuleName $script:ModuleName {
                $result = Connect-PatAccount -TimeoutSeconds 1

                $result | Should -Be 'timeout-token'
                Should -Invoke Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                    $TimeoutSeconds -eq 1
                }
            }
        }

        It 'Should accept maximum value (1800)' {
            InModuleScope -ModuleName $script:ModuleName {
                $result = Connect-PatAccount -TimeoutSeconds 1800

                $result | Should -Be 'timeout-token'
                Should -Invoke Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                    $TimeoutSeconds -eq 1800
                }
            }
        }

        It 'Should use default value (300) when not specified' {
            InModuleScope -ModuleName $script:ModuleName {
                Connect-PatAccount

                Should -Invoke Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                    $TimeoutSeconds -eq 300
                }
            }
        }
    }

    Context 'Error scenarios' {
        It 'Should handle network timeout' {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { throw 'The operation has timed out' }

                { Connect-PatAccount } | Should -Throw '*timed out*'
            }
        }

        It 'Should handle PIN expiration' {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { throw 'PIN has expired' }

                { Connect-PatAccount } | Should -Throw '*PIN has expired*'
            }
        }

        It 'Should handle user cancellation' {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { throw 'User cancelled authentication' }

                { Connect-PatAccount } | Should -Throw '*cancelled*'
            }
        }

        It 'Should preserve original error message' {
            InModuleScope -ModuleName $script:ModuleName {
                Mock Invoke-PatPinAuthentication { throw 'Specific error from inner function' }

                { Connect-PatAccount } | Should -Throw '*Specific error from inner function*'
            }
        }
    }
}
