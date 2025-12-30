BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Invoke-PatPinAuthentication' {

    BeforeAll {
        # Mock PIN response
        $script:mockPin = [PSCustomObject]@{
            id   = 12345
            code = 'ABCD'
        }
    }

    Context 'Function definition' {
        It 'Should exist as a private function in the module' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication -ErrorAction SilentlyContinue
            }
            $function | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $function.CmdletBinding | Should -Be $true
        }

        It 'Should support ShouldProcess' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $function.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It 'Should have TimeoutSeconds parameter' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $function.Parameters.ContainsKey('TimeoutSeconds') | Should -Be $true
        }

        It 'Should have Force parameter' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $function.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have TimeoutSeconds with ValidateRange attribute' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $param = $function.Parameters['TimeoutSeconds']
            $validateRange = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 1800
        }
    }

    Context 'Parameter validation' {
        It 'Should reject TimeoutSeconds less than 1' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -TimeoutSeconds 0
                }
            } | Should -Throw
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -TimeoutSeconds 2000
                }
            } | Should -Throw
        }
    }

    Context 'Successful authentication flow' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'test-client-identifier-12345'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                return $script:mockPin
            }

            Mock -ModuleName PlexAutomationToolkit Set-Clipboard { }

            Mock -ModuleName PlexAutomationToolkit Start-Process { }

            Mock -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization {
                return 'mock-auth-token-xyz789'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should call Get-PatClientIdentifier' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatClientIdentifier -Times 1
        }

        It 'Should call New-PatPin with client identifier' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit New-PatPin -Times 1 -ParameterFilter {
                $ClientIdentifier -eq 'test-client-identifier-12345'
            }
        }

        It 'Should copy PIN code to clipboard' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Set-Clipboard -Times 1 -ParameterFilter {
                $Value -eq 'ABCD'
            }
        }

        It 'Should open browser when Force is specified' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Start-Process -Times 1 -ParameterFilter {
                $FilePath -eq 'https://plex.tv/link'
            }
        }

        It 'Should call Wait-PatPinAuthorization with correct parameters' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -TimeoutSeconds 120 -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization -Times 1 -ParameterFilter {
                $PinId -eq 12345 -and
                $ClientIdentifier -eq 'test-client-identifier-12345' -and
                $TimeoutSeconds -eq 120
            }
        }

        It 'Should return the authentication token' {
            $result = InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            $result | Should -Be 'mock-auth-token-xyz789'
        }

        It 'Should use default timeout of 300 seconds' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 300
            }
        }

        It 'Should display authentication instructions via Write-Information' {
            InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -Confirm:$false
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Write-Information -Times 1 -ParameterFilter {
                $MessageData -like '*Plex Authentication*'
            }
        }
    }

    Context 'When Force is not specified' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'test-client-id'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                return $script:mockPin
            }

            Mock -ModuleName PlexAutomationToolkit Set-Clipboard { }

            Mock -ModuleName PlexAutomationToolkit Start-Process { }

            Mock -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization {
                return 'mock-token'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should have Force as a switch parameter for non-interactive use' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $param = $function.Parameters['Force']
            $param.ParameterType | Should -Be ([switch])
        }

        It 'Should not require Force parameter' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $param = $function.Parameters['Force']
            $param.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory
            } | Should -BeNullOrEmpty
        }
    }

    Context 'When authorization times out' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'test-client-id'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                return $script:mockPin
            }

            Mock -ModuleName PlexAutomationToolkit Set-Clipboard { }

            Mock -ModuleName PlexAutomationToolkit Start-Process { }

            Mock -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should throw timeout error when Wait-PatPinAuthorization returns null' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -Force -TimeoutSeconds 60 -Confirm:$false
                }
            } | Should -Throw '*timed out*60 seconds*'
        }
    }

    Context 'When Get-PatClientIdentifier fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                throw 'Failed to get client identifier'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should throw wrapped error' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -Force -Confirm:$false
                }
            } | Should -Throw '*PIN authentication failed*'
        }
    }

    Context 'When New-PatPin fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'test-client-id'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                throw 'Failed to request PIN from Plex'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should throw wrapped error' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -Force -Confirm:$false
                }
            } | Should -Throw '*PIN authentication failed*'
        }
    }

    Context 'When Wait-PatPinAuthorization fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'test-client-id'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                return $script:mockPin
            }

            Mock -ModuleName PlexAutomationToolkit Set-Clipboard { }

            Mock -ModuleName PlexAutomationToolkit Start-Process { }

            Mock -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization {
                throw 'Network error during polling'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should throw wrapped error' {
            {
                InModuleScope PlexAutomationToolkit {
                    Invoke-PatPinAuthentication -Force -Confirm:$false
                }
            } | Should -Throw '*PIN authentication failed*Network error*'
        }
    }

    Context 'Edge cases' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatClientIdentifier {
                return 'edge-case-client-id'
            }

            Mock -ModuleName PlexAutomationToolkit New-PatPin {
                return $script:mockPin
            }

            Mock -ModuleName PlexAutomationToolkit Set-Clipboard { }

            Mock -ModuleName PlexAutomationToolkit Start-Process { }

            Mock -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization {
                return 'edge-token'
            }

            Mock -ModuleName PlexAutomationToolkit Write-Information { }
        }

        It 'Should accept minimum timeout value (1)' {
            $result = InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -TimeoutSeconds 1 -Confirm:$false
            }
            $result | Should -Be 'edge-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization -ParameterFilter {
                $TimeoutSeconds -eq 1
            }
        }

        It 'Should accept maximum timeout value (1800)' {
            $result = InModuleScope PlexAutomationToolkit {
                Invoke-PatPinAuthentication -Force -TimeoutSeconds 1800 -Confirm:$false
            }
            $result | Should -Be 'edge-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatPinAuthorization -ParameterFilter {
                $TimeoutSeconds -eq 1800
            }
        }
    }
}
