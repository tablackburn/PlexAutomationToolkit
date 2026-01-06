BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import required helper functions
    . (Join-Path $ModuleRoot 'Private\Join-PatUri.ps1')
    . (Join-Path $ModuleRoot 'Private\Test-PatServerReachable.ps1')
}

Describe 'Test-PatServerReachable' {
    Context 'Server is reachable' {
        BeforeEach {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ machineIdentifier = 'abc123' }
            }
        }

        It 'Returns Reachable = true when server responds' {
            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Reachable | Should -Be $true
        }

        It 'Returns ResponseTimeMs as integer when reachable' {
            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.ResponseTimeMs | Should -BeOfType [long]
            $result.ResponseTimeMs | Should -BeGreaterOrEqual 0
        }

        It 'Returns Error = null when reachable' {
            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Error | Should -BeNullOrEmpty
        }

        It 'Calls correct endpoint' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'http://192.168.1.100:32400/'
            }
        }

        It 'Uses GET method' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Get'
            }
        }

        It 'Uses default timeout of 3 seconds' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $TimeoutSec -eq 3
            }
        }

        It 'Uses custom timeout when specified' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400' -TimeoutSeconds 10

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $TimeoutSec -eq 10
            }
        }
    }

    Context 'Server requires authentication' {
        It 'Returns Reachable = true on 401 Unauthorized' {
            Mock Invoke-RestMethod { throw '401 Unauthorized' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Reachable | Should -Be $true
        }

        It 'Returns Reachable = true on 403 Forbidden' {
            Mock Invoke-RestMethod { throw '403 Forbidden' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Reachable | Should -Be $true
        }

        It 'Returns ResponseTimeMs on auth errors' {
            Mock Invoke-RestMethod { throw '401 Unauthorized' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.ResponseTimeMs | Should -BeGreaterOrEqual 0
        }

        It 'Returns Error = null on auth errors (server is reachable)' {
            Mock Invoke-RestMethod { throw '401 Unauthorized' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Error | Should -BeNullOrEmpty
        }
    }

    Context 'Server is not reachable' {
        It 'Returns Reachable = false on connection refused' {
            Mock Invoke-RestMethod { throw 'Connection refused' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Reachable | Should -Be $false
        }

        It 'Returns Reachable = false on timeout' {
            Mock Invoke-RestMethod { throw 'The operation has timed out' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Reachable | Should -Be $false
        }

        It 'Returns Reachable = false on DNS failure' {
            Mock Invoke-RestMethod { throw 'No such host is known' }

            $result = Test-PatServerReachable -ServerUri 'http://nonexistent.local:32400'

            $result.Reachable | Should -Be $false
        }

        It 'Returns ResponseTimeMs = null when not reachable' {
            Mock Invoke-RestMethod { throw 'Connection refused' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.ResponseTimeMs | Should -BeNullOrEmpty
        }

        It 'Returns Error message when not reachable' {
            Mock Invoke-RestMethod { throw 'Connection refused' }

            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.Error | Should -Be 'Connection refused'
        }
    }

    Context 'Authentication token handling' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Includes token in headers when provided' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400' -Token 'my-secret-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-secret-token'
            }
        }

        It 'Does not include token when not provided' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                -not $Headers.ContainsKey('X-Plex-Token')
            }
        }

        It 'Does not include token when empty' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400' -Token ''

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                -not $Headers.ContainsKey('X-Plex-Token')
            }
        }
    }

    Context 'HTTPS certificate handling' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Does not skip certificate check by default for HTTPS' {
            Test-PatServerReachable -ServerUri 'https://192.168.1.100:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('SkipCertificateCheck') -or
                $SkipCertificateCheck -ne $true
            }
        }

        It 'Skips certificate check for HTTPS when SkipCertificateCheck specified' {
            Test-PatServerReachable -ServerUri 'https://192.168.1.100:32400' -SkipCertificateCheck

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $SkipCertificateCheck -eq $true
            }
        }

        It 'Does not skip certificate check for HTTP even with SkipCertificateCheck' {
            Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400' -SkipCertificateCheck

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('SkipCertificateCheck') -or
                $SkipCertificateCheck -ne $true
            }
        }

        It 'Restores ServerCertificateValidationCallback after HTTPS call on PowerShell 5.1' -Skip:($PSVersionTable.PSVersion.Major -ge 6) {
            # Save the original callback
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            Test-PatServerReachable -ServerUri 'https://192.168.1.100:32400' -SkipCertificateCheck

            # Verify the callback is restored to its original value (even if it was null)
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback | Should -Be $originalCallback
        }
    }

    Context 'Parameter validation' {
        It 'Requires ServerUri parameter' {
            { Test-PatServerReachable } | Should -Throw
        }

        It 'Rejects empty ServerUri' {
            { Test-PatServerReachable -ServerUri '' } | Should -Throw
        }

        It 'Accepts timeout between 1 and 30' {
            Mock Invoke-RestMethod { return @{} }

            { Test-PatServerReachable -ServerUri 'http://test:32400' -TimeoutSeconds 1 } | Should -Not -Throw
            { Test-PatServerReachable -ServerUri 'http://test:32400' -TimeoutSeconds 30 } | Should -Not -Throw
        }

        It 'Rejects timeout less than 1' {
            { Test-PatServerReachable -ServerUri 'http://test:32400' -TimeoutSeconds 0 } | Should -Throw
        }

        It 'Rejects timeout greater than 30' {
            { Test-PatServerReachable -ServerUri 'http://test:32400' -TimeoutSeconds 31 } | Should -Throw
        }
    }

    Context 'Output structure' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Returns PSCustomObject' {
            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Has all expected properties' {
            $result = Test-PatServerReachable -ServerUri 'http://192.168.1.100:32400'

            $result.PSObject.Properties.Name | Should -Contain 'Reachable'
            $result.PSObject.Properties.Name | Should -Contain 'ResponseTimeMs'
            $result.PSObject.Properties.Name | Should -Contain 'Error'
        }
    }
}
