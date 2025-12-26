BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

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
}
