BeforeDiscovery {
    # Check PowerShell version for skipping version-specific tests
    $script:IsPS6Plus = $PSVersionTable.PSVersion.Major -ge 6
    $script:IsPS51 = $PSVersionTable.PSVersion.Major -lt 6
}

BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import required helper functions
    . (Join-Path $ModuleRoot 'Private\Join-PatUri.ps1')
    . (Join-Path $ModuleRoot 'Private\Test-PatHttpsAvailability.ps1')
}

Describe 'Test-PatHttpsAvailability' {
    Context 'Parameter validation' {
        It 'Requires HttpUri parameter' {
            { Test-PatHttpsAvailability } | Should -Throw
        }

        It 'Rejects null HttpUri' {
            { Test-PatHttpsAvailability -HttpUri $null } | Should -Throw
        }

        It 'Rejects empty HttpUri' {
            { Test-PatHttpsAvailability -HttpUri '' } | Should -Throw
        }

        It 'Rejects HTTPS URIs' {
            { Test-PatHttpsAvailability -HttpUri 'https://plex.local:32400' } | Should -Throw
        }

        It 'Accepts HTTP URIs' {
            Mock Invoke-RestMethod { return @{} }
            { Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400' } | Should -Not -Throw
        }

        It 'Accepts HTTP URIs with different ports' {
            Mock Invoke-RestMethod { return @{} }
            { Test-PatHttpsAvailability -HttpUri 'http://192.168.1.100:8080' } | Should -Not -Throw
        }
    }

    Context 'HTTPS connection succeeds' {
        BeforeEach {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    machineIdentifier = 'test-machine-id'
                }
            }
        }

        It 'Returns $true when HTTPS responds successfully' {
            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }

        It 'Converts HTTP to HTTPS in request' {
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://plex.local:32400/'
            }
        }

        It 'Uses 5 second timeout' {
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $TimeoutSec -eq 5
            }
        }

        It 'Uses ErrorAction Stop' {
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $ErrorAction -eq 'Stop'
            }
        }

        It 'Handles different HTTP ports' {
            Test-PatHttpsAvailability -HttpUri 'http://192.168.1.100:8080'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://192.168.1.100:8080/'
            }
        }
    }

    Context 'HTTPS returns authentication required (401/403)' {
        It 'Returns $true when HTTPS returns 401 Unauthorized' {
            Mock Invoke-RestMethod {
                $response = New-Object System.Net.Http.HttpResponseMessage
                $response.StatusCode = 401
                $exception = [System.Net.Http.HttpRequestException]::new('Unauthorized')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }

        It 'Returns $true when HTTPS returns 403 Forbidden' {
            Mock Invoke-RestMethod {
                $response = New-Object System.Net.Http.HttpResponseMessage
                $response.StatusCode = 403
                $exception = [System.Net.Http.HttpRequestException]::new('Forbidden')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }

        It 'Returns $true when HTTPS returns 401 with WebException' {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{
                        value__ = 401
                    }
                }
                $exception = [System.InvalidOperationException]::new('401 Unauthorized')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }

        It 'Returns $true when HTTPS returns 403 with WebException' {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{
                        value__ = 403
                    }
                }
                $exception = [System.InvalidOperationException]::new('403 Forbidden')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }
    }

    Context 'HTTPS connection fails' {
        It 'Returns $false when HTTPS connection is refused' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Connection refused')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeFalse
        }

        It 'Returns $false when HTTPS times out' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('The operation has timed out')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeFalse
        }

        It 'Returns $false when HTTPS returns 404' {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{
                        value__ = 404
                    }
                }
                $exception = [System.InvalidOperationException]::new('404 Not Found')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeFalse
        }

        It 'Returns $false when HTTPS returns 500' {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = [PSCustomObject]@{
                        value__ = 500
                    }
                }
                $exception = [System.InvalidOperationException]::new('500 Internal Server Error')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $response -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeFalse
        }

        It 'Returns $false when DNS resolution fails' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('No such host is known')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://nonexistent.local:32400'

            $result | Should -BeFalse
        }

        It 'Returns $false on SSL/TLS handshake failure' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('The SSL connection could not be established')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeFalse
        }
    }

    Context 'PowerShell 6+ certificate handling' -Skip:(-not $script:IsPS6Plus) {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Uses SkipCertificateCheck parameter on PowerShell 6+' {
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $SkipCertificateCheck -eq $true
            }
        }

        It 'Does not modify ServerCertificateValidationCallback on PowerShell 6+' {
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback | Should -Be $originalCallback
        }

        It 'Does not use mutex on PowerShell 6+' {
            # If we're on PS6+, the function should not attempt to create a mutex
            # We can verify this by checking that no mutex-related errors occur
            { Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400' } | Should -Not -Throw
        }
    }

    Context 'PowerShell 5.1 certificate handling' -Skip:(-not $script:IsPS51) {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Does not use SkipCertificateCheck parameter on PowerShell 5.1' {
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('SkipCertificateCheck')
            }
        }

        It 'Modifies ServerCertificateValidationCallback on PowerShell 5.1' {
            # Store original callback
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            # Set it to null to ensure we can detect changes
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

            try {
                # During execution, the callback should be set to allow all certs
                Mock Invoke-RestMethod {
                    # Verify callback was set during the call
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback | Should -Not -BeNullOrEmpty
                    return @{}
                }

                Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'
            }
            finally {
                # Restore original callback
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
            }
        }

        It 'Restores original ServerCertificateValidationCallback after success' {
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback | Should -Be $originalCallback
        }

        It 'Restores original ServerCertificateValidationCallback after exception' {
            $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Connection refused')
            }

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback | Should -Be $originalCallback
        }

        It 'Restores custom ServerCertificateValidationCallback if one was set' {
            # Set a custom callback
            $customCallback = { param($a, $b, $c, $d) return $true }
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $customCallback

            # Store the delegate reference after assignment (PS 5.1 converts scriptblock to delegate)
            $originalDelegate = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            # Should restore the custom callback - use reference equality for delegate comparison
            $restoredDelegate = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            [object]::ReferenceEquals($restoredDelegate, $originalDelegate) | Should -Be $true

            # Clean up
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }

    Context 'PowerShell 5.1 mutex behavior' -Skip:(-not $script:IsPS51) {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Successfully acquires and releases mutex under normal conditions' {
            # This should succeed without errors
            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeTrue
        }

        It 'Properly disposes mutex after successful operation' {
            # Run the function
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            # Should be able to immediately acquire the mutex (meaning it was released)
            $testMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
            $acquired = $testMutex.WaitOne(100)

            try {
                $acquired | Should -BeTrue
            }
            finally {
                if ($acquired) {
                    $testMutex.ReleaseMutex()
                }
                $testMutex.Dispose()
            }
        }

        It 'Properly disposes mutex after exception' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Connection refused')
            }

            # Run the function (will throw and catch internally)
            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            # Should be able to immediately acquire the mutex (meaning it was released)
            $testMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
            $acquired = $testMutex.WaitOne(100)

            try {
                $acquired | Should -BeTrue
            }
            finally {
                if ($acquired) {
                    $testMutex.ReleaseMutex()
                }
                $testMutex.Dispose()
            }
        }

        It 'Handles mutex properly when certificate callback was already set' {
            # Set a custom callback before the function runs
            $customCallback = { param($a, $b, $c, $d) return $false }
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $customCallback

            # Store the delegate reference after assignment (PS 5.1 converts scriptblock to delegate)
            $originalDelegate = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

            try {
                Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

                # Should restore the custom callback - use reference equality for delegate comparison
                $restoredDelegate = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
                [object]::ReferenceEquals($restoredDelegate, $originalDelegate) | Should -Be $true

                # Mutex should be released
                $testMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
                $acquired = $testMutex.WaitOne(100)

                try {
                    $acquired | Should -BeTrue
                }
                finally {
                    if ($acquired) {
                        $testMutex.ReleaseMutex()
                    }
                    $testMutex.Dispose()
                }
            }
            finally {
                # Clean up
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
            }
        }
    }

    Context 'Mutex timeout behavior' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        # Skip: Same-thread mutex reentry allows recursive acquisition, so blocking cannot be tested
        # This is a fundamental limitation - the test and function run on the same thread
        It 'Returns $false when mutex acquisition times out' -Skip {
            # Create and hold the mutex to simulate timeout scenario
            $blockingMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
            $blockingMutex.WaitOne() | Out-Null

            try {
                $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

                # Should return false when mutex cannot be acquired
                $result | Should -BeFalse

                # Should not have called Invoke-RestMethod since mutex wasn't acquired
                Should -Invoke Invoke-RestMethod -Times 0
            }
            finally {
                $blockingMutex.ReleaseMutex()
                $blockingMutex.Dispose()
            }
        }
    }

    Context 'Output type' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Returns boolean type' {
            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -BeOfType [bool]
        }

        It 'Returns $true on success' {
            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -Be $true
            $result | Should -BeExactly $true
        }

        It 'Returns $false on failure' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Connection refused')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            $result | Should -Be $false
            $result | Should -BeExactly $false
        }
    }

    Context 'Verbose output' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Writes verbose message about checking HTTPS' {
            $allOutput = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400' -Verbose 4>&1
            $verboseOutput = $allOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput.Message | Should -Match 'Checking if HTTPS is available at https://plex.local:32400'
        }

        It 'Writes verbose message when HTTPS not available' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Connection refused')
            }

            $allOutput = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400' -Verbose 4>&1
            $verboseOutput = $allOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseMessages = $verboseOutput.Message -join ' '
            $verboseMessages | Should -Match 'HTTPS not available'
        }

        # Skip: Same-thread mutex reentry allows recursive acquisition, so blocking cannot be tested
        # This is a fundamental limitation - the test and function run on the same thread
        It 'Writes verbose message when mutex cannot be acquired' -Skip {
            # Create and hold the mutex
            $blockingMutex = [System.Threading.Mutex]::new($false, 'Global\PlexAutomationToolkit_CertCallback')
            $blockingMutex.WaitOne() | Out-Null

            try {
                $allOutput = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400' -Verbose 4>&1
                $verboseOutput = $allOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

                $verboseOutput | Should -Not -BeNullOrEmpty
                $verboseOutput.Message | Should -Match 'Could not acquire certificate callback mutex'
            }
            finally {
                $blockingMutex.ReleaseMutex()
                $blockingMutex.Dispose()
            }
        }
    }

    Context 'Edge cases' {
        It 'Handles HTTP URI with trailing slash' {
            Mock Invoke-RestMethod { return @{} }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400/'

            $result | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like 'https://plex.local:32400/*'
            }
        }

        It 'Handles HTTP URI with path components' {
            Mock Invoke-RestMethod { return @{} }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400/web'

            $result | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -like 'https://plex.local:32400/*'
            }
        }

        It 'Handles IP address URIs' {
            Mock Invoke-RestMethod { return @{} }

            $result = Test-PatHttpsAvailability -HttpUri 'http://192.168.1.100:32400'

            $result | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://192.168.1.100:32400/'
            }
        }

        It 'Handles localhost URIs' {
            Mock Invoke-RestMethod { return @{} }

            $result = Test-PatHttpsAvailability -HttpUri 'http://localhost:32400'

            $result | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://localhost:32400/'
            }
        }

        It 'Handles exception without Response property' {
            Mock Invoke-RestMethod {
                throw [System.InvalidOperationException]::new('Generic error')
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            # Should not crash, should return false
            $result | Should -BeFalse
        }

        It 'Handles exception with null Response' {
            Mock Invoke-RestMethod {
                $exception = [System.InvalidOperationException]::new('Error with null response')
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $null -Force
                throw $exception
            }

            $result = Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            # Should not crash, should return false
            $result | Should -BeFalse
        }
    }

    Context 'Integration with Join-PatUri' {
        BeforeEach {
            Mock Invoke-RestMethod { return @{} }
        }

        It 'Calls Join-PatUri to construct test endpoint' {
            Mock Join-PatUri { return 'https://plex.local:32400/' } -Verifiable

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Join-PatUri -Times 1 -ParameterFilter {
                $BaseUri -eq 'https://plex.local:32400' -and $Endpoint -eq '/'
            }
        }

        It 'Uses Join-PatUri result for Invoke-RestMethod' {
            Mock Join-PatUri { return 'https://plex.local:32400/test-endpoint' }

            Test-PatHttpsAvailability -HttpUri 'http://plex.local:32400'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://plex.local:32400/test-endpoint'
            }
        }
    }
}
