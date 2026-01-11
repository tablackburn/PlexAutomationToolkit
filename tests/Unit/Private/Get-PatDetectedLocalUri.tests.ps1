BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get reference to private function
    $script:GetPatDetectedLocalUri = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatDetectedLocalUri }
}

Describe 'Get-PatDetectedLocalUri' {

    Context 'Parameter validation' {
        It 'Requires ServerUri parameter' {
            { & $script:GetPatDetectedLocalUri -Token 'test-token' } | Should -Throw
        }

        It 'Requires Token parameter' {
            { & $script:GetPatDetectedLocalUri -ServerUri 'http://192.168.1.100:32400' } | Should -Throw
        }

        It 'Rejects empty ServerUri' {
            { & $script:GetPatDetectedLocalUri -ServerUri '' -Token 'test-token' } | Should -Throw
        }

        It 'Rejects empty Token' {
            { & $script:GetPatDetectedLocalUri -ServerUri 'http://192.168.1.100:32400' -Token '' } | Should -Throw
        }

        It 'Rejects null ServerUri' {
            { & $script:GetPatDetectedLocalUri -ServerUri $null -Token 'test-token' } | Should -Throw
        }

        It 'Rejects null Token' {
            { & $script:GetPatDetectedLocalUri -ServerUri 'http://192.168.1.100:32400' -Token $null } | Should -Throw
        }
    }

    Context 'Successful detection of local URI' {
        BeforeEach {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                        FriendlyName      = 'Test Server'
                        Version           = '1.32.0.6918'
                        Platform          = 'Linux'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            IPv6     = $false
                            Protocol = 'http'
                            Address  = '192.168.1.100'
                            Port     = 32400
                        }
                    )
                }
            }
        }

        It 'Returns local URI when different from ServerUri' {
            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'http://192.168.1.100:32400'
        }

        It 'Calls Get-PatServerIdentity with correct parameters' {
            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Get-PatServerIdentity -Times 1 -ParameterFilter {
                    $ServerUri -eq 'https://plex.example.com:32400' -and
                    $Token -eq 'test-token'
                }
            }
        }

        It 'Calls Get-PatServerConnection with machine identifier' {
            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Get-PatServerConnection -Times 1 -ParameterFilter {
                    $MachineIdentifier -eq 'abc123-machine-id' -and
                    $Token -eq 'test-token'
                }
            }
        }

        It 'Returns string type' {
            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeOfType [string]
        }
    }

    Context 'Prefers HTTPS over HTTP' {
        It 'Returns HTTPS connection when both HTTP and HTTPS available' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                        FriendlyName      = 'Test Server'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'https://192.168.1.100:32400'
        }

        It 'Returns first HTTPS connection when multiple HTTPS connections available' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                        FriendlyName      = 'Test Server'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.101:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'https://192.168.1.100:32400'
        }

        It 'Returns HTTP connection when HTTPS not available' {
            $mockConnectionsHttpOnly = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                        FriendlyName      = 'Test Server'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'http://192.168.1.100:32400'
        }
    }

    Context 'Returns null when no connections found' {
        It 'Returns null when connections array is empty' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { return @() }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when connections is null' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { return $null }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Returns null when no local connections found' {
        It 'Returns null when all connections are remote' {
            $mockRemoteConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://plex.example.com:32400'
                    Local    = $false
                    Relay    = $false
                    Protocol = 'https'
                },
                [PSCustomObject]@{
                    Uri      = 'https://plex2.example.com:32400'
                    Local    = $false
                    Relay    = $false
                    Protocol = 'https'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://plex.example.com:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://plex2.example.com:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when Local property is false' {
            $mockNonLocalConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $false
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Returns null when only relay connections found' {
        It 'Returns null when all connections are relay' {
            $mockRelayConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://relay1.plex.direct:32400'
                    Local    = $false
                    Relay    = $true
                    Protocol = 'https'
                },
                [PSCustomObject]@{
                    Uri      = 'https://relay2.plex.direct:32400'
                    Local    = $false
                    Relay    = $true
                    Protocol = 'https'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://relay1.plex.direct:32400'
                            Local    = $false
                            Relay    = $true
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://relay2.plex.direct:32400'
                            Local    = $false
                            Relay    = $true
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when connection is local but also relay' {
            $mockLocalRelayConnection = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $true
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $true
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns local non-relay connection when mixed relay and non-relay available' {
            $mockMixedConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://relay.plex.direct:32400'
                    Local    = $false
                    Relay    = $true
                    Protocol = 'https'
                },
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://relay.plex.direct:32400'
                            Local    = $false
                            Relay    = $true
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'http://192.168.1.100:32400'
        }
    }

    Context 'Returns null when local URI matches server URI' {
        It 'Returns null when detected local URI is same as ServerUri' {
            $mockSameUriConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'http://192.168.1.100:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when preferred HTTPS local URI matches ServerUri' {
            $mockHttpsMatchConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                },
                [PSCustomObject]@{
                    Uri      = 'https://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'https'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://192.168.1.100:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns different local URI when HTTP variant available but HTTPS is ServerUri' {
            $mockDifferentProtocolConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://192.168.1.100:32400' -Token 'test-token'

            $result | Should -Be 'http://192.168.1.100:32400'
        }
    }

    Context 'Error handling when Get-PatServerIdentity fails' {
        It 'Returns null and writes warning when Get-PatServerIdentity throws' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity { throw 'Connection refused' }
                Mock Write-Warning { }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Writes warning message when Get-PatServerIdentity fails' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity { throw 'Network timeout' }
                Mock Write-Warning { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -match 'Failed to detect local URI'
                }
            }
        }

        It 'Includes original error message in warning' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity { throw 'Authentication failed: 401 Unauthorized' }
                Mock Write-Warning { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -match 'Authentication failed: 401 Unauthorized'
                }
            }
        }
    }

    Context 'Error handling when Get-PatServerConnection fails' {
        It 'Returns null and writes warning when Get-PatServerConnection throws' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { throw 'API error' }
                Mock Write-Warning { }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Writes warning message when Get-PatServerConnection fails' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { throw 'Plex.tv API unavailable' }
                Mock Write-Warning { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -match 'Failed to detect local URI'
                }
            }
        }

        It 'Includes original error message in warning' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { throw '403 Forbidden' }
                Mock Write-Warning { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -match '403 Forbidden'
                }
            }
        }
    }

    Context 'Verbose output' {
        It 'Writes verbose message at start of detection' {
            $mockConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'Attempting to detect local URI'
                }
            }
        }

        It 'Writes verbose message with machine identifier' {
            $mockConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'abc123-machine-id'
                }
            }
        }

        It 'Writes verbose message when local URI detected' {
            $mockConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'Detected local URI.*192.168.1.100'
                }
            }
        }

        It 'Writes verbose message when no connections found' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { return @() }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'No connections found'
                }
            }
        }

        It 'Writes verbose message when no local connections found' {
            $mockRemoteConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://plex.example.com:32400'
                    Local    = $false
                    Relay    = $false
                    Protocol = 'https'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://plex.example.com:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://plex2.example.com:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'No local.*non-relay.*connections found'
                }
            }
        }

        It 'Writes verbose message when local URI matches server URI' {
            $mockSameUriConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
                Mock Write-Verbose { }
            }

            & $script:GetPatDetectedLocalUri -ServerUri 'http://192.168.1.100:32400' -Token 'test-token' -Verbose

            & (Get-Module PlexAutomationToolkit) {
                Should -Invoke Write-Verbose -ParameterFilter {
                    $Message -match 'No distinct local URI found'
                }
            }
        }
    }

    Context 'Complex scenarios' {
        It 'Filters correctly with mixed local, remote, and relay connections' {
            $mockComplexConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://relay.plex.direct:32400'
                    Local    = $false
                    Relay    = $true
                    Protocol = 'https'
                },
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                },
                [PSCustomObject]@{
                    Uri      = 'https://plex.example.com:32400'
                    Local    = $false
                    Relay    = $false
                    Protocol = 'https'
                },
                [PSCustomObject]@{
                    Uri      = 'https://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'https'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://relay.plex.direct:32400'
                            Local    = $false
                            Relay    = $true
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://plex.example.com:32400'
                            Local    = $false
                            Relay    = $false
                            Protocol = 'https'
                        },
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'https://192.168.1.100:32400'
        }

        It 'Works with IPv6 local connections' {
            $mockIpv6Connections = @(
                [PSCustomObject]@{
                    Uri      = 'http://[fe80::1]:32400'
                    Local    = $true
                    Relay    = $false
                    IPv6     = $true
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://[fe80::1]:32400'
                            Local    = $true
                            Relay    = $false
                            IPv6     = $true
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'http://[fe80::1]:32400'
        }

        It 'Handles connections with different ports' {
            $mockDifferentPortConnections = @(
                [PSCustomObject]@{
                    Uri      = 'https://192.168.1.100:8443'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'https'
                    Port     = 8443
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'https://192.168.1.100:8443'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'https'
                            Port     = 8443
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -Be 'https://192.168.1.100:8443'
        }
    }

    Context 'Output type validation' {
        It 'Returns string when local URI found' {
            $mockConnections = @(
                [PSCustomObject]@{
                    Uri      = 'http://192.168.1.100:32400'
                    Local    = $true
                    Relay    = $false
                    Protocol = 'http'
                }
            )

            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection {
                    return @(
                        [PSCustomObject]@{
                            Uri      = 'http://192.168.1.100:32400'
                            Local    = $true
                            Relay    = $false
                            Protocol = 'http'
                        }
                    )
                }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeOfType [string]
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns null type when no local URI found' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { return @() }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null type on error' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity { throw 'Error' }
                Mock Write-Warning { }
            }

            $result = & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'ErrorAction Stop behavior' {
        It 'Catches errors when Get-PatServerIdentity called with ErrorAction Stop' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity { throw 'Server error' }
                Mock Write-Warning { }
            }

            # Should not throw because function catches the error
            { & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' } |
                Should -Not -Throw
        }

        It 'Catches errors when Get-PatServerConnection called with ErrorAction Stop' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Get-PatServerIdentity {
                    return [PSCustomObject]@{
                        MachineIdentifier = 'abc123-machine-id'
                    }
                }
                Mock Get-PatServerConnection { throw 'API error' }
                Mock Write-Warning { }
            }

            # Should not throw because function catches the error
            { & $script:GetPatDetectedLocalUri -ServerUri 'https://plex.example.com:32400' -Token 'test-token' } |
                Should -Not -Throw
        }
    }
}
