BeforeAll {
    $ModuleName = 'PlexAutomationToolkit'
    $ModuleManifestPath = "$PSScriptRoot/../../../Output/$ModuleName/$((Test-ModuleManifest "$PSScriptRoot/../../../$ModuleName/$ModuleName.psd1").Version)/$ModuleName.psd1"

    if (Get-Module -Name $ModuleName) {
        Remove-Module -Name $ModuleName -Force
    }
    Import-Module $ModuleManifestPath -Force
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

        It 'Should request strong PIN' {
            New-PatPin -ClientIdentifier 'test-client-id'
            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Body.strong -eq $true
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
