BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatSession' {

    BeforeAll {
        # Mock sessions response matching Plex API structure
        $script:mockSessionsResponse = @{
            size     = 2
            Metadata = @(
                @{
                    title      = 'The Matrix'
                    type       = 'movie'
                    key        = '/library/metadata/123'
                    duration   = 8160000
                    viewOffset = 4080000
                    Player     = @{
                        title             = 'Living Room TV'
                        address           = '192.168.1.100'
                        platform          = 'Roku'
                        machineIdentifier = 'roku-abc123'
                        local             = $true
                    }
                    Session    = @{
                        id        = 'session-001'
                        bandwidth = 20000
                    }
                    User       = @{
                        id    = '1'
                        title = 'john'
                    }
                }
                @{
                    title      = 'Breaking Bad S01E01'
                    type       = 'episode'
                    key        = '/library/metadata/456'
                    duration   = 3600000
                    viewOffset = 900000
                    Player     = @{
                        title             = 'iPhone'
                        address           = '10.0.0.50'
                        platform          = 'iOS'
                        machineIdentifier = 'iphone-xyz789'
                        local             = $false
                    }
                    Session    = @{
                        id        = 'session-002'
                        bandwidth = 8000
                    }
                    User       = @{
                        id    = '2'
                        title = 'jane'
                    }
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When retrieving all sessions' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSessionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Returns all active sessions' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result.Count | Should -Be 2
        }

        It 'Calls the sessions endpoint' {
            Get-PatSession -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/status/sessions'
            }
        }

        It 'Returns properly structured session objects' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'SessionId'
            $result[0].PSObject.Properties.Name | Should -Contain 'MediaTitle'
            $result[0].PSObject.Properties.Name | Should -Contain 'Username'
            $result[0].PSObject.Properties.Name | Should -Contain 'PlayerName'
            $result[0].PSObject.Properties.Name | Should -Contain 'Progress'
        }

        It 'Maps API properties correctly' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result[0].SessionId | Should -Be 'session-001'
            $result[0].MediaTitle | Should -Be 'The Matrix'
            $result[0].MediaType | Should -Be 'movie'
            $result[0].Username | Should -Be 'john'
            $result[0].PlayerName | Should -Be 'Living Room TV'
            $result[0].PlayerPlatform | Should -Be 'Roku'
            $result[0].IsLocal | Should -Be $true
            $result[0].Bandwidth | Should -Be 20000
        }

        It 'Calculates progress percentage correctly' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result[0].Progress | Should -Be 50
            $result[1].Progress | Should -Be 25
        }

        It 'Has correct PSTypeName' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Session'
        }

        It 'Includes ServerUri in output' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result[0].ServerUri | Should -Be 'http://plex.local:32400'
        }
    }

    Context 'When filtering by Username' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSessionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Returns only sessions for specified username' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Username 'john'
            @($result).Count | Should -Be 1
            $result[0].Username | Should -Be 'john'
        }

        It 'Returns nothing when username does not match' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Username 'nonexistent'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When filtering by Player' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSessionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Returns only sessions for specified player' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Player 'iPhone'
            @($result).Count | Should -Be 1
            $result[0].PlayerName | Should -Be 'iPhone'
        }

        It 'Returns nothing when player does not match' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Player 'Android TV'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When combining filters' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSessionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Applies both Username and Player filters' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Username 'john' -Player 'Living Room TV'
            @($result).Count | Should -Be 1
            $result[0].Username | Should -Be 'john'
            $result[0].PlayerName | Should -Be 'Living Room TV'
        }

        It 'Returns nothing when filters do not match same session' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400' -Username 'john' -Player 'iPhone'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When no sessions are active' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{ size = 0; Metadata = @() }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Returns empty collection' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When Metadata is null' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{ size = 0 }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Handles null Metadata gracefully' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSessionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/status/sessions'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Get-PatSession
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Uses authentication headers from stored server' {
            Get-PatSession
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Get-PatSession } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection refused'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Throws an error with context' {
            { Get-PatSession -ServerUri 'http://plex.local:32400' } | Should -Throw '*Failed to retrieve sessions*'
        }
    }

    Context 'When session has no duration (live content)' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            title      = 'Live TV'
                            type       = 'clip'
                            key        = '/library/metadata/789'
                            duration   = 0
                            viewOffset = 0
                            Player     = @{
                                title             = 'Browser'
                                address           = '192.168.1.50'
                                platform          = 'Chrome'
                                machineIdentifier = 'chrome-123'
                                local             = $true
                            }
                            Session    = @{
                                id        = 'session-003'
                                bandwidth = 5000
                            }
                            User       = @{
                                id    = '1'
                                title = 'john'
                            }
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions'
            }
        }

        It 'Handles zero duration without error' {
            $result = Get-PatSession -ServerUri 'http://plex.local:32400'
            $result.Progress | Should -Be 0
        }
    }
}
