BeforeAll {
    $ModuleName = 'PlexAutomationToolkit'
    $ModuleManifestPath = "$PSScriptRoot/../../../Output/$ModuleName/$((Test-ModuleManifest "$PSScriptRoot/../../../$ModuleName/$ModuleName.psd1").Version)/$ModuleName.psd1"

    if (Get-Module -Name $ModuleName) {
        Remove-Module -Name $ModuleName -Force
    }
    Import-Module $ModuleManifestPath -Force
}

Describe 'Invoke-PatPinAuthentication' {
    BeforeEach {
        Mock Get-PatClientIdentifier {
            return 'test-client-id-456'
        }

        Mock New-PatPin {
            return [PSCustomObject]@{
                id   = 99999
                code = 'WXYZ'
            }
        }

        Mock Wait-PatPinAuthorization {
            return 'authenticated-token-789'
        }

        Mock Write-Host {}
    }

    Context 'Flow Orchestration' {
        It 'Should retrieve client identifier' {
            Invoke-PatPinAuthentication
            Should -Invoke Get-PatClientIdentifier -Times 1
        }

        It 'Should request new PIN' {
            Invoke-PatPinAuthentication
            Should -Invoke New-PatPin -Times 1 -ParameterFilter {
                $ClientIdentifier -eq 'test-client-id-456'
            }
        }

        It 'Should wait for authorization' {
            Invoke-PatPinAuthentication
            Should -Invoke Wait-PatPinAuthorization -Times 1 -ParameterFilter {
                $PinId -eq 99999 -and $ClientIdentifier -eq 'test-client-id-456'
            }
        }

        It 'Should pass timeout to Wait-PatPinAuthorization' {
            Invoke-PatPinAuthentication -TimeoutSeconds 600
            Should -Invoke Wait-PatPinAuthorization -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 600
            }
        }

        It 'Should return authentication token' {
            $result = Invoke-PatPinAuthentication
            $result | Should -Be 'authenticated-token-789'
        }
    }

    Context 'User Instructions' {
        It 'Should display PIN code to user' {
            Invoke-PatPinAuthentication
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match 'WXYZ'
            }
        }

        It 'Should display plex.tv/link URL' {
            Invoke-PatPinAuthentication
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match 'plex\.tv/link'
            }
        }

        It 'Should display success message when authenticated' {
            Invoke-PatPinAuthentication
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match 'successful'
            }
        }
    }

    Context 'Error Handling' {
        It 'Should throw when client identifier retrieval fails' {
            Mock Get-PatClientIdentifier {
                throw 'Client ID error'
            }
            { Invoke-PatPinAuthentication } | Should -Throw '*PIN authentication failed*'
        }

        It 'Should throw when PIN request fails' {
            Mock New-PatPin {
                throw 'PIN request error'
            }
            { Invoke-PatPinAuthentication } | Should -Throw '*PIN authentication failed*'
        }

        It 'Should throw when authorization times out' {
            Mock Wait-PatPinAuthorization {
                return $null
            }
            { Invoke-PatPinAuthentication } | Should -Throw '*timed out*'
        }

        It 'Should throw when authorization fails' {
            Mock Wait-PatPinAuthorization {
                throw 'Authorization error'
            }
            { Invoke-PatPinAuthentication } | Should -Throw '*PIN authentication failed*'
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept TimeoutSeconds parameter' {
            { Invoke-PatPinAuthentication -TimeoutSeconds 120 } | Should -Not -Throw
        }

        It 'Should reject TimeoutSeconds less than 1' {
            { Invoke-PatPinAuthentication -TimeoutSeconds 0 } | Should -Throw
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            { Invoke-PatPinAuthentication -TimeoutSeconds 2000 } | Should -Throw
        }
    }
}
