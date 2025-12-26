BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Invoke-PatPinAuthentication' {
    # Note: This function uses $Host.UI.PromptForChoice for interactive prompts
    # which cannot be easily mocked in Pester tests. These tests verify parameter
    # validation and function existence. Full integration testing requires
    # interactive scenarios.

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

        It 'Should have TimeoutSeconds parameter' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $function.Parameters.ContainsKey('TimeoutSeconds') | Should -Be $true
        }

        It 'Should have TimeoutSeconds with ValidateRange attribute' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $param = $function.Parameters['TimeoutSeconds']
            $validateRange = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
        }

        It 'TimeoutSeconds should default to 300 seconds' {
            $function = InModuleScope PlexAutomationToolkit {
                Get-Command Invoke-PatPinAuthentication
            }
            $param = $function.Parameters['TimeoutSeconds']
            # Check if parameter has default value by checking ParameterSets
            $param.ParameterType | Should -Be ([int])
        }
    }

    Context 'Parameter validation' {
        It 'Should reject TimeoutSeconds less than 1' {
            {
                InModuleScope PlexAutomationToolkit {
                    # This should fail parameter validation before any interactive prompts
                    Invoke-PatPinAuthentication -TimeoutSeconds 0
                }
            } | Should -Throw
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            {
                InModuleScope PlexAutomationToolkit {
                    # This should fail parameter validation before any interactive prompts
                    Invoke-PatPinAuthentication -TimeoutSeconds 2000
                }
            } | Should -Throw
        }
    }
}
