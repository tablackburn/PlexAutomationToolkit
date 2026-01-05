BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import required helper functions
    . (Join-Path $ModuleRoot 'Private\ConvertTo-PsCustomObjectFromHashtable.ps1')
    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Invoke-PatApi.ps1')
}

Describe 'Invoke-PatApi' {
    BeforeAll {
        # Mock Invoke-RestMethod for all tests
        Mock Invoke-RestMethod {
            return @{
                MediaContainer = @{
                    size = 1
                    Directory = @(
                        @{ title = 'Test Library'; key = 1 }
                    )
                }
            }
        }
    }

    Context 'Basic API calls' {
        It 'Should call Invoke-RestMethod with correct URI' {
            $uri = 'http://localhost:32400/library/sections'
            Invoke-PatApi -Uri $uri -Method Get

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'http://localhost:32400/library/sections'
            }
        }

        It 'Should default to GET method' {
            $uri = 'http://localhost:32400/library/sections'
            Invoke-PatApi -Uri $uri

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Get'
            }
        }

        It 'Should support POST method' {
            $uri = 'http://localhost:32400/library/sections/1/refresh'
            Invoke-PatApi -Uri $uri -Method Post

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Post'
            }
        }

        It 'Should include Accept header for JSON' {
            $uri = 'http://localhost:32400/library/sections'
            Invoke-PatApi -Uri $uri -Method Get

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/json'
            }
        }
    }

    Context 'Response handling' {
        It 'Should return MediaContainer property when present' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{
                        size = 2
                        Data = 'test-data'
                    }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'
            $result.size | Should -Be 2
            $result.Data | Should -Be 'test-data'
        }

        It 'Should return full response when MediaContainer is absent' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status = 'success'
                    message = 'test-message'
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'
            $result.status | Should -Be 'success'
            $result.message | Should -Be 'test-message'
        }

        It 'Should handle empty MediaContainer' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{
                        size = 0
                    }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'
            $result.size | Should -Be 0
        }
    }

    Context 'Error handling' {
        It 'Should propagate HTTP errors' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Connection refused')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*Error invoking Plex API*"
        }

        It 'Should propagate authentication errors' {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = [System.Net.HttpStatusCode]::Unauthorized
                }
                $exception = [System.Net.WebException]::new('Unauthorized', $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
                throw $exception
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*Error invoking Plex API*"
        }

        It 'Should handle malformed JSON responses' {
            Mock Invoke-RestMethod {
                throw [System.ArgumentException]::new('Invalid JSON')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*Error invoking Plex API*"
        }

        It 'Should include original error message in exception' {
            Mock Invoke-RestMethod {
                throw 'Specific error message'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*Specific error message*"
        }
    }

    Context 'Custom headers' {
        It 'Should use custom headers when provided' {
            $headers = @{
                'X-Plex-Token' = 'test-token'
                'Accept' = 'application/json'
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -Headers $headers

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'test-token'
            }
        }

        It 'Should allow overriding Accept header' {
            $headers = @{ 'Accept' = 'application/xml' }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -Headers $headers

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/xml'
            }
        }

        It 'Should use default Accept header when not specified' {
            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/json'
            }
        }
    }

    Context 'HTTP methods' {
        BeforeAll {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{
                        status = 'ok'
                    }
                }
            }
        }

        It 'Should support PUT method' {
            Invoke-PatApi -Uri 'http://localhost:32400/test' -Method Put

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Put'
            }
        }

        It 'Should support DELETE method' {
            Invoke-PatApi -Uri 'http://localhost:32400/test' -Method Delete

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Delete'
            }
        }

        It 'Should support PATCH method' {
            Invoke-PatApi -Uri 'http://localhost:32400/test' -Method Patch

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Method -eq 'Patch'
            }
        }
    }

    Context 'HTTP error codes' {
        It 'Should handle HTTP 400 Bad Request' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('400 Bad Request')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*400*"
        }

        It 'Should handle HTTP 403 Forbidden' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('403 Forbidden')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*403*"
        }

        It 'Should handle HTTP 404 Not Found' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('404 Not Found')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*404*"
        }

        It 'Should handle HTTP 500 Internal Server Error' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('500 Internal Server Error')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*500*"
        }

        It 'Should handle HTTP 503 Service Unavailable' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('503 Service Unavailable')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*503*"
        }

        It 'Should handle timeout errors' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The operation has timed out')
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' } | Should -Throw "*timed out*"
        }
    }

    Context 'Response type variations' {
        It 'Should handle response as array' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ id = 1; name = 'Item1' },
                    [PSCustomObject]@{ id = 2; name = 'Item2' }
                )
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'

            $result | Should -HaveCount 2
            $result[0].id | Should -Be 1
        }

        It 'Should handle empty string response' {
            Mock Invoke-RestMethod {
                return ''
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'

            $result | Should -Be ''
        }

        It 'Should handle response without MediaContainer' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    status = 'ok'
                    value  = 42
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test'

            $result.status | Should -Be 'ok'
            $result.value | Should -Be 42
        }
    }

    Context 'Security warnings' {
        BeforeAll {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{
                        status = 'ok'
                    }
                }
            }
        }

        It 'Should warn when using HTTP with X-Plex-Token' {
            $headers = @{
                'Accept' = 'application/json'
                'X-Plex-Token' = 'test-token'
            }

            $warnings = @()
            $null = Invoke-PatApi -Uri 'http://localhost:32400/test' -Headers $headers -WarningVariable warnings 3>$null

            $warnings | Should -Match 'unencrypted HTTP'
        }

        It 'Should not warn when using HTTPS with token' {
            $headers = @{
                'Accept' = 'application/json'
                'X-Plex-Token' = 'test-token'
            }

            $warnings = @()
            $null = Invoke-PatApi -Uri 'https://localhost:32400/test' -Headers $headers -WarningVariable warnings 3>$null

            $warnings | Should -BeNullOrEmpty
        }

        It 'Should not warn when using HTTP without token' {
            $headers = @{
                'Accept' = 'application/json'
            }

            $warnings = @()
            $null = Invoke-PatApi -Uri 'http://localhost:32400/test' -Headers $headers -WarningVariable warnings 3>$null

            $warnings | Should -BeNullOrEmpty
        }
    }

    Context 'Retry behavior on transient errors' {
        It 'Should retry on DNS failure and succeed' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw 'No such host is known'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 2
        }

        It 'Should retry on timeout and succeed' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw 'The operation has timed out'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 2
        }

        It 'Should retry on 503 Service Unavailable and succeed' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw '503 Service Unavailable'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 2
        }

        It 'Should retry on 429 Too Many Requests and succeed' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw '429 Too Many Requests'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 2
        }

        It 'Should retry on connection refused and succeed' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    throw 'Unable to connect to the remote server'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 2
        }

        It 'Should exhaust all retries on persistent transient error' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw 'No such host is known'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*No such host*'
            $script:callCount | Should -Be 3
        }

        It 'Should succeed after multiple retries' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                if ($script:callCount -lt 3) {
                    throw 'Connection reset by peer'
                }
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }

            $result = Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0
            $result.status | Should -Be 'ok'
            $script:callCount | Should -Be 3
        }

        It 'Should use default MaxRetries of 3' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw 'No such host is known'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -BaseDelaySeconds 0 } | Should -Throw
            $script:callCount | Should -Be 3
        }
    }

    Context 'No retry on permanent errors' {
        It 'Should not retry on 401 Unauthorized' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw '401 Unauthorized'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*401*'
            $script:callCount | Should -Be 1
        }

        It 'Should not retry on 403 Forbidden' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw '403 Forbidden'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*403*'
            $script:callCount | Should -Be 1
        }

        It 'Should not retry on 404 Not Found' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw '404 Not Found'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*404*'
            $script:callCount | Should -Be 1
        }

        It 'Should not retry on 400 Bad Request' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw '400 Bad Request'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*400*'
            $script:callCount | Should -Be 1
        }

        It 'Should not retry on generic application error' {
            $script:callCount = 0
            Mock Invoke-RestMethod {
                $script:callCount++
                throw 'Invalid JSON response'
            }

            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 3 -BaseDelaySeconds 0 } | Should -Throw '*Invalid JSON*'
            $script:callCount | Should -Be 1
        }
    }

    Context 'Retry parameters validation' {
        BeforeAll {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    MediaContainer = [PSCustomObject]@{ status = 'ok' }
                }
            }
        }

        It 'Should accept MaxRetries parameter' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 5 } | Should -Not -Throw
        }

        It 'Should accept BaseDelaySeconds parameter' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -BaseDelaySeconds 2 } | Should -Not -Throw
        }

        It 'Should reject MaxRetries less than 1' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 0 } | Should -Throw
        }

        It 'Should reject MaxRetries greater than 10' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -MaxRetries 11 } | Should -Throw
        }

        It 'Should accept BaseDelaySeconds of 0 for testing' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -BaseDelaySeconds 0 } | Should -Not -Throw
        }

        It 'Should reject negative BaseDelaySeconds' {
            { Invoke-PatApi -Uri 'http://localhost:32400/test' -BaseDelaySeconds -1 } | Should -Throw
        }
    }
}
