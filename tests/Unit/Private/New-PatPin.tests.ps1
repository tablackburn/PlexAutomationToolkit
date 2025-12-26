BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\New-PatPin.ps1')
}

Describe 'New-PatPin' {
    BeforeEach {
        Mock Invoke-RestMethod {
            return [PSCustomObject]@{
                id   = 12345
                code = 'ABCD'
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should require ClientIdentifier parameter' {
            { New-PatPin } | Should -Throw
        }

        It 'Should not accept null or empty ClientIdentifier' {
            { New-PatPin -ClientIdentifier '' } | Should -Throw
        }
    }

    Context 'API Interaction' {
        It 'Should call Plex PIN endpoint' {
            New-PatPin -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://plex.tv/api/v2/pins' -and $Method -eq 'Post'
            }
        }

        It 'Should include required headers' {
            New-PatPin -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['X-Plex-Client-Identifier'] -eq 'test-client-id' -and
                $Headers['X-Plex-Product'] -eq 'PlexAutomationToolkit' -and
                $Headers['X-Plex-Version'] -eq '1.0.0' -and
                $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Should include strong parameter in body' {
            New-PatPin -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $null -ne $Body.strong
            }
        }
    }

    Context 'Response Handling' {
        It 'Should return PIN object with id and code' {
            $result = New-PatPin -ClientIdentifier 'test-client-id'
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 12345
            $result.code | Should -Be 'ABCD'
        }

        It 'Should throw when API call fails' {
            Mock Invoke-RestMethod {
                throw 'API error'
            }
            { New-PatPin -ClientIdentifier 'test-client-id' } | Should -Throw '*Failed to request PIN from Plex*'
        }
    }
}
