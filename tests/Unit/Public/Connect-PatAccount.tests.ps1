BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Connect-PatAccount' {

    Context 'Function definition' {
        It 'Should exist as a public function' {
            Get-Command Connect-PatAccount -Module PlexAutomationToolkit | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $function = Get-Command Connect-PatAccount -Module PlexAutomationToolkit
            $function.CmdletBinding | Should -Be $true
        }

        It 'Should have OutputType of string' {
            $function = Get-Command Connect-PatAccount -Module PlexAutomationToolkit
            $outputType = $function.OutputType
            $outputType.Type | Should -Contain ([string])
        }

        It 'Should have TimeoutSeconds parameter' {
            $function = Get-Command Connect-PatAccount -Module PlexAutomationToolkit
            $function.Parameters.ContainsKey('TimeoutSeconds') | Should -Be $true
        }

        It 'Should have Force parameter' {
            $function = Get-Command Connect-PatAccount -Module PlexAutomationToolkit
            $function.Parameters.ContainsKey('Force') | Should -Be $true
        }
    }

    Context 'Parameter Validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication { return 'mock-token' }
        }

        It 'Should accept TimeoutSeconds parameter' {
            { Connect-PatAccount -TimeoutSeconds 60 } | Should -Not -Throw
        }

        It 'Should reject TimeoutSeconds less than 1' {
            { Connect-PatAccount -TimeoutSeconds 0 } | Should -Throw
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            { Connect-PatAccount -TimeoutSeconds 2000 } | Should -Throw
        }
    }

    Context 'Successful authentication' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                return 'mock-token-abc123'
            }
        }

        It 'Should return authentication token' {
            $result = Connect-PatAccount
            $result | Should -Be 'mock-token-abc123'
        }

        It 'Should return a string' {
            $result = Connect-PatAccount
            $result | Should -BeOfType [string]
        }

        It 'Should call Invoke-PatPinAuthentication' {
            Connect-PatAccount
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1
        }
    }

    Context 'Force parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                return 'force-token'
            }
        }

        It 'Should pass Force to Invoke-PatPinAuthentication' {
            Connect-PatAccount -Force

            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }

        It 'Should work with Force and custom TimeoutSeconds' {
            $result = Connect-PatAccount -Force -TimeoutSeconds 120

            $result | Should -Be 'force-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $Force -eq $true -and $TimeoutSeconds -eq 120
            }
        }
    }

    Context 'TimeoutSeconds parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                return 'timeout-token'
            }
        }

        It 'Should accept minimum value (1)' {
            $result = Connect-PatAccount -TimeoutSeconds 1

            $result | Should -Be 'timeout-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 1
            }
        }

        It 'Should accept maximum value (1800)' {
            $result = Connect-PatAccount -TimeoutSeconds 1800

            $result | Should -Be 'timeout-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 1800
            }
        }

        It 'Should use default value (300) when not specified' {
            Connect-PatAccount

            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 300
            }
        }

        It 'Should pass custom TimeoutSeconds to Invoke-PatPinAuthentication' {
            Connect-PatAccount -TimeoutSeconds 600

            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 600
            }
        }
    }

    Context 'Error handling' {
        It 'Should throw when authentication fails' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'Authentication failed'
            }
            { Connect-PatAccount } | Should -Throw '*Failed to authenticate with Plex*'
        }

        It 'Should handle network timeout' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'The operation has timed out'
            }

            { Connect-PatAccount } | Should -Throw '*timed out*'
        }

        It 'Should handle PIN expiration' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'PIN has expired'
            }

            { Connect-PatAccount } | Should -Throw '*PIN has expired*'
        }

        It 'Should handle user cancellation' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'User cancelled authentication'
            }

            { Connect-PatAccount } | Should -Throw '*cancelled*'
        }

        It 'Should preserve original error message' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'Specific error from inner function'
            }

            { Connect-PatAccount } | Should -Throw '*Specific error from inner function*'
        }

        It 'Should wrap error with context message' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                throw 'Some internal error'
            }

            { Connect-PatAccount } | Should -Throw 'Failed to authenticate with Plex*'
        }
    }

    Context 'Combined parameters' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication {
                return 'combined-token'
            }
        }

        It 'Should pass both Force and TimeoutSeconds correctly' {
            $result = Connect-PatAccount -Force -TimeoutSeconds 900

            $result | Should -Be 'combined-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $Force -eq $true -and $TimeoutSeconds -eq 900
            }
        }

        It 'Should work without Force but with TimeoutSeconds' {
            $result = Connect-PatAccount -TimeoutSeconds 450

            $result | Should -Be 'combined-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatPinAuthentication -Times 1 -ParameterFilter {
                $Force -ne $true -and $TimeoutSeconds -eq 450
            }
        }
    }
}
