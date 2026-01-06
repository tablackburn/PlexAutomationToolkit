BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import required helper functions
    . (Join-Path $ModuleRoot 'Private\Join-PatUri.ps1')
    . (Join-Path $ModuleRoot 'Private\ConvertTo-PsCustomObjectFromHashtable.ps1')
    . (Join-Path $ModuleRoot 'Private\Invoke-PatApi.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatServerIdentity.ps1')
}

Describe 'Get-PatServerIdentity' {
    BeforeAll {
        # Sample server identity response
        $script:mockServerResponse = [PSCustomObject]@{
            machineIdentifier = 'abc123-unique-machine-id'
            friendlyName      = 'My Plex Server'
            version           = '1.32.0.6918'
            platform          = 'Linux'
        }
    }

    Context 'Successful identity retrieval' {
        BeforeEach {
            Mock Invoke-PatApi { return $script:mockServerResponse }
        }

        It 'Returns MachineIdentifier' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.MachineIdentifier | Should -Be 'abc123-unique-machine-id'
        }

        It 'Returns FriendlyName' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.FriendlyName | Should -Be 'My Plex Server'
        }

        It 'Returns Version' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.Version | Should -Be '1.32.0.6918'
        }

        It 'Returns Platform' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.Platform | Should -Be 'Linux'
        }

        It 'Calls API with correct URI' {
            Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                $Uri -eq 'http://192.168.1.100:32400/'
            }
        }

        It 'Includes Accept header' {
            Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/json'
            }
        }
    }

    Context 'Authentication' {
        BeforeEach {
            Mock Invoke-PatApi { return $script:mockServerResponse }
        }

        It 'Includes token in headers when provided' {
            Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' -Token 'my-secret-token'

            Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-secret-token'
            }
        }

        It 'Does not include token header when not provided' {
            Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                -not $Headers.ContainsKey('X-Plex-Token')
            }
        }

        It 'Does not include token header when empty string' {
            Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' -Token ''

            Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                -not $Headers.ContainsKey('X-Plex-Token')
            }
        }
    }

    Context 'Invalid server response' {
        It 'Throws when machineIdentifier is missing' {
            Mock Invoke-PatApi {
                return [PSCustomObject]@{
                    friendlyName = 'Server Without ID'
                    version      = '1.32.0'
                }
            }

            { Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' } |
                Should -Throw '*missing machineIdentifier*'
        }

        It 'Throws when machineIdentifier is null' {
            Mock Invoke-PatApi {
                return [PSCustomObject]@{
                    machineIdentifier = $null
                    friendlyName      = 'Server With Null ID'
                }
            }

            { Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' } |
                Should -Throw '*missing machineIdentifier*'
        }
    }

    Context 'API errors' {
        It 'Throws with server URI in error message on connection failure' {
            Mock Invoke-PatApi { throw 'Connection refused' }

            { Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' } |
                Should -Throw "*Failed to get server identity from 'http://192.168.1.100:32400'*"
        }

        It 'Includes original error message' {
            Mock Invoke-PatApi { throw 'Network timeout' }

            { Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400' } |
                Should -Throw '*Network timeout*'
        }
    }

    Context 'Different URI formats' {
        BeforeEach {
            Mock Invoke-PatApi { return $script:mockServerResponse }
        }

        It 'Works with HTTP URI' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.MachineIdentifier | Should -Be 'abc123-unique-machine-id'
        }

        It 'Works with HTTPS URI' {
            $result = Get-PatServerIdentity -ServerUri 'https://plex.example.com:32400'

            $result.MachineIdentifier | Should -Be 'abc123-unique-machine-id'
        }

        It 'Works with hostname' {
            $result = Get-PatServerIdentity -ServerUri 'http://plex.local:32400'

            $result.MachineIdentifier | Should -Be 'abc123-unique-machine-id'
        }
    }

    Context 'Parameter validation' {
        It 'Requires ServerUri parameter' {
            { Get-PatServerIdentity } | Should -Throw
        }

        It 'Rejects empty ServerUri' {
            { Get-PatServerIdentity -ServerUri '' } | Should -Throw
        }
    }

    Context 'Output type' {
        BeforeEach {
            Mock Invoke-PatApi { return $script:mockServerResponse }
        }

        It 'Returns PSCustomObject' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Has all expected properties' {
            $result = Get-PatServerIdentity -ServerUri 'http://192.168.1.100:32400'

            $result.PSObject.Properties.Name | Should -Contain 'MachineIdentifier'
            $result.PSObject.Properties.Name | Should -Contain 'FriendlyName'
            $result.PSObject.Properties.Name | Should -Contain 'Version'
            $result.PSObject.Properties.Name | Should -Contain 'Platform'
        }
    }
}
