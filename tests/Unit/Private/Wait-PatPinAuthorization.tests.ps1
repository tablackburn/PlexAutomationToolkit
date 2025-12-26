BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Wait-PatPinAuthorization.ps1')
}

Describe 'Wait-PatPinAuthorization' {
    BeforeEach {
        Mock Start-Sleep {}
    }

    Context 'Parameter Validation' {
        It 'Should require PinId parameter' {
            { Wait-PatPinAuthorization -ClientIdentifier 'test' } | Should -Throw
        }

        It 'Should require ClientIdentifier parameter' {
            { Wait-PatPinAuthorization -PinId '12345' } | Should -Throw
        }

        It 'Should reject TimeoutSeconds less than 1' {
            { Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test' -TimeoutSeconds 0 } | Should -Throw
        }

        It 'Should reject TimeoutSeconds greater than 1800' {
            { Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test' -TimeoutSeconds 2000 } | Should -Throw
        }
    }

    Context 'Successful Authorization' {
        BeforeEach {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    id        = 12345
                    code      = 'ABCD'
                    authToken = 'test-auth-token-123'
                }
            }
        }

        It 'Should return token when authorized' {
            $result = Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id'
            $result | Should -Be 'test-auth-token-123'
        }

        It 'Should call correct PIN status endpoint' {
            Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://plex.tv/api/v2/pins/12345' -and $Method -eq 'Get'
            }
        }

        It 'Should include required headers' {
            Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers['X-Plex-Client-Identifier'] -eq 'test-client-id' -and
                $Headers['X-Plex-Product'] -eq 'PlexAutomationToolkit'
            }
        }
    }

    Context 'Polling Behavior' {
        It 'Should poll until token is received' {
            $script:pollCount = 0
            Mock Invoke-RestMethod {
                $script:pollCount++
                if ($script:pollCount -lt 3) {
                    return [PSCustomObject]@{
                        id        = 12345
                        code      = 'ABCD'
                        authToken = $null
                    }
                }
                return [PSCustomObject]@{
                    id        = 12345
                    code      = 'ABCD'
                    authToken = 'test-token'
                }
            }

            $result = Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id' -PollIntervalSeconds 1
            $result | Should -Be 'test-token'
            $script:pollCount | Should -BeGreaterThan 1
        }

        It 'Should respect PollIntervalSeconds parameter' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    authToken = 'test-token'
                }
            }

            Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id' -PollIntervalSeconds 5
            # Note: We can't easily test the actual sleep duration in unit tests
            # This just verifies the parameter is accepted
        }
    }

    Context 'Timeout Behavior' {
        It 'Should return null when timeout is reached' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    id        = 12345
                    code      = 'ABCD'
                    authToken = $null
                }
            }

            $result = Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id' -TimeoutSeconds 1
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Should throw when API call fails' {
            Mock Invoke-RestMethod {
                throw 'API error'
            }
            { Wait-PatPinAuthorization -PinId '12345' -ClientIdentifier 'test-client-id' } | Should -Throw '*Failed to check PIN authorization*'
        }
    }
}
