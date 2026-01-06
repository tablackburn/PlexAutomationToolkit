BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatServerConnection.ps1')
}

Describe 'Get-PatServerConnection' {
    BeforeAll {
        # Sample Plex.tv API response
        $script:mockPlexTvResponse = @(
            [PSCustomObject]@{
                clientIdentifier = 'abc123-machine-id'
                name             = 'Test Server'
                connections      = @(
                    [PSCustomObject]@{
                        uri      = 'http://192.168.1.100:32400'
                        local    = $true
                        relay    = $false
                        IPv6     = $false
                        protocol = 'http'
                        address  = '192.168.1.100'
                        port     = 32400
                    },
                    [PSCustomObject]@{
                        uri      = 'https://plex.example.com:32400'
                        local    = $false
                        relay    = $false
                        IPv6     = $false
                        protocol = 'https'
                        address  = 'plex.example.com'
                        port     = 32400
                    },
                    [PSCustomObject]@{
                        uri      = 'https://relay.plex.direct:32400'
                        local    = $false
                        relay    = $true
                        IPv6     = $false
                        protocol = 'https'
                        address  = 'relay.plex.direct'
                        port     = 32400
                    }
                )
            },
            [PSCustomObject]@{
                clientIdentifier = 'xyz789-other-server'
                name             = 'Other Server'
                connections      = @(
                    [PSCustomObject]@{
                        uri      = 'http://192.168.1.200:32400'
                        local    = $true
                        relay    = $false
                        IPv6     = $false
                        protocol = 'http'
                        address  = '192.168.1.200'
                        port     = 32400
                    }
                )
            }
        )
    }

    Context 'Successful API calls' {
        BeforeEach {
            Mock Invoke-RestMethod { return $script:mockPlexTvResponse }
        }

        It 'Returns connections for the matching machineIdentifier' {
            $result = Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'test-token'

            $result | Should -HaveCount 3
            $result[0].Uri | Should -Be 'http://192.168.1.100:32400'
        }

        It 'Sets Local property correctly' {
            $result = Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'test-token'

            ($result | Where-Object { $_.Local -eq $true }) | Should -HaveCount 1
            ($result | Where-Object { $_.Local -eq $false }) | Should -HaveCount 2
        }

        It 'Sets Relay property correctly' {
            $result = Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'test-token'

            ($result | Where-Object { $_.Relay -eq $true }) | Should -HaveCount 1
            ($result | Where-Object { $_.Relay -eq $false }) | Should -HaveCount 2
        }

        It 'Includes all expected properties' {
            $result = Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'test-token'

            $result[0].PSObject.Properties.Name | Should -Contain 'Uri'
            $result[0].PSObject.Properties.Name | Should -Contain 'Local'
            $result[0].PSObject.Properties.Name | Should -Contain 'Relay'
            $result[0].PSObject.Properties.Name | Should -Contain 'IPv6'
            $result[0].PSObject.Properties.Name | Should -Contain 'Protocol'
            $result[0].PSObject.Properties.Name | Should -Contain 'Address'
            $result[0].PSObject.Properties.Name | Should -Contain 'Port'
        }

        It 'Calls Plex.tv API with correct headers' {
            Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'my-secret-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-secret-token' -and
                $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Calls correct Plex.tv API endpoint' {
            Get-PatServerConnection -MachineIdentifier 'abc123-machine-id' -Token 'test-token'

            Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -eq 'https://plex.tv/api/v2/resources'
            }
        }
    }

    Context 'Server not found' {
        BeforeEach {
            Mock Invoke-RestMethod { return $script:mockPlexTvResponse }
            Mock Write-Warning { }
        }

        It 'Returns empty array when machineIdentifier not found' {
            $result = Get-PatServerConnection -MachineIdentifier 'nonexistent-id' -Token 'test-token'

            $result | Should -HaveCount 0
        }

        It 'Writes warning when machineIdentifier not found' {
            Get-PatServerConnection -MachineIdentifier 'nonexistent-id' -Token 'test-token'

            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -match 'not found'
            }
        }
    }

    Context 'Server with no connections' {
        BeforeEach {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{
                        clientIdentifier = 'empty-server'
                        name             = 'Empty Server'
                        connections      = @()
                    }
                )
            }
            Mock Write-Warning { }
        }

        It 'Returns empty array when server has no connections' {
            $result = Get-PatServerConnection -MachineIdentifier 'empty-server' -Token 'test-token'

            $result | Should -HaveCount 0
        }

        It 'Writes warning when no connections found' {
            Get-PatServerConnection -MachineIdentifier 'empty-server' -Token 'test-token'

            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -match 'No connections found'
            }
        }
    }

    Context 'Authentication errors' {
        It 'Throws on 401 Unauthorized' {
            Mock Invoke-RestMethod { throw '401 Unauthorized' }

            { Get-PatServerConnection -MachineIdentifier 'abc123' -Token 'bad-token' } |
                Should -Throw '*Authentication failed*'
        }

        It 'Throws on 403 Forbidden' {
            Mock Invoke-RestMethod { throw '403 Forbidden' }

            { Get-PatServerConnection -MachineIdentifier 'abc123' -Token 'bad-token' } |
                Should -Throw '*Authentication failed*'
        }
    }

    Context 'Other errors' {
        It 'Throws with descriptive message on network error' {
            Mock Invoke-RestMethod { throw 'Connection timed out' }

            { Get-PatServerConnection -MachineIdentifier 'abc123' -Token 'test-token' } |
                Should -Throw '*Failed to get server connections*Connection timed out*'
        }
    }

    Context 'Parameter validation' {
        It 'Requires MachineIdentifier parameter' {
            { Get-PatServerConnection -Token 'test-token' } | Should -Throw
        }

        It 'Requires Token parameter' {
            { Get-PatServerConnection -MachineIdentifier 'abc123' } | Should -Throw
        }

        It 'Rejects empty MachineIdentifier' {
            { Get-PatServerConnection -MachineIdentifier '' -Token 'test-token' } | Should -Throw
        }

        It 'Rejects empty Token' {
            { Get-PatServerConnection -MachineIdentifier 'abc123' -Token '' } | Should -Throw
        }
    }
}
