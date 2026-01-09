BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import dependencies
    . (Join-Path $ModuleRoot 'Private\Get-PatSecretManagementAvailable.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatServerToken.ps1')

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Resolve-PatServerContext.ps1')
    . (Join-Path $ModuleRoot 'Private\Get-PatAuthenticationHeader.ps1')
}

Describe 'Resolve-PatServerContext' {
    Context 'When ServerUri is explicitly provided' {
        It 'Should return context with explicit URI' {
            $ctx = Resolve-PatServerContext -ServerUri 'http://explicit:32400'

            $ctx.Uri | Should -Be 'http://explicit:32400'
            $ctx.WasExplicitUri | Should -Be $true
            $ctx.Server | Should -BeNullOrEmpty
        }

        It 'Should return default headers without token' {
            $ctx = Resolve-PatServerContext -ServerUri 'http://explicit:32400'

            $ctx.Headers['Accept'] | Should -Be 'application/json'
            $ctx.Headers.ContainsKey('X-Plex-Token') | Should -Be $false
        }
    }

    Context 'When using default server' {
        BeforeEach {
            # Mock Get-PatStoredServer to return a test server
            function Get-PatStoredServer { }
            Mock Get-PatStoredServer {
                [PSCustomObject]@{
                    name    = 'DefaultServer'
                    uri     = 'http://default:32400'
                    token   = 'test-token-123'
                    default = $true
                }
            }
        }

        It 'Should return context with default server URI' {
            $ctx = Resolve-PatServerContext

            $ctx.Uri | Should -Be 'http://default:32400'
            $ctx.WasExplicitUri | Should -Be $false
            $ctx.Server | Should -Not -BeNullOrEmpty
            $ctx.Server.name | Should -Be 'DefaultServer'
        }

        It 'Should return headers with authentication token' {
            $ctx = Resolve-PatServerContext

            $ctx.Headers['Accept'] | Should -Be 'application/json'
            $ctx.Headers['X-Plex-Token'] | Should -Be 'test-token-123'
        }
    }

    Context 'When default server has no token' {
        BeforeEach {
            function Get-PatStoredServer { }
            Mock Get-PatStoredServer {
                [PSCustomObject]@{
                    name    = 'NoTokenServer'
                    uri     = 'http://notoken:32400'
                    default = $true
                }
            }
        }

        It 'Should return headers without X-Plex-Token' {
            $ctx = Resolve-PatServerContext

            $ctx.Headers['Accept'] | Should -Be 'application/json'
            $ctx.Headers.ContainsKey('X-Plex-Token') | Should -Be $false
        }
    }

    Context 'When no default server is configured' {
        BeforeEach {
            function Get-PatStoredServer { }
            Mock Get-PatStoredServer {
                $null
            }
        }

        It 'Should throw an error' {
            { Resolve-PatServerContext } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When Get-PatStoredServer throws an error' {
        BeforeEach {
            function Get-PatStoredServer { }
            Mock Get-PatStoredServer {
                throw 'Config file not found'
            }
        }

        It 'Should throw with helpful error message including original error' {
            { Resolve-PatServerContext } | Should -Throw '*No server specified and failed to retrieve default server*'
        }

        It 'Should include original error details' {
            { Resolve-PatServerContext } | Should -Throw '*Config file not found*'
        }

        It 'Should suggest alternatives in error message' {
            { Resolve-PatServerContext } | Should -Throw '*-ServerName*-ServerUri*Add-PatServer*'
        }
    }

    Context 'When ServerName is provided' {
        BeforeEach {
            function Get-PatStoredServer { }
            function Select-PatServerUri { }

            Mock Get-PatStoredServer {
                [PSCustomObject]@{
                    name    = 'Home'
                    uri     = 'http://home:32400'
                    token   = 'home-token-123'
                    default = $false
                }
            }

            Mock Select-PatServerUri {
                [PSCustomObject]@{
                    Uri     = 'http://home:32400'
                    IsLocal = $false
                    SelectionReason = 'Primary URI selected'
                }
            }
        }

        It 'Should return context with named server URI' {
            $ctx = Resolve-PatServerContext -ServerName 'Home'

            $ctx.Uri | Should -Be 'http://home:32400'
            $ctx.WasExplicitUri | Should -Be $false
            $ctx.Server | Should -Not -BeNullOrEmpty
        }

        It 'Should return headers with authentication from named server' {
            $ctx = Resolve-PatServerContext -ServerName 'Home'

            $ctx.Headers['Accept'] | Should -Be 'application/json'
            $ctx.Headers['X-Plex-Token'] | Should -Be 'home-token-123'
        }

        It 'Should return server name in context' {
            $ctx = Resolve-PatServerContext -ServerName 'Home'

            $ctx.Server.name | Should -Be 'Home'
        }
    }

    Context 'When both ServerName and ServerUri are provided' {
        It 'Should throw an error' {
            { Resolve-PatServerContext -ServerName 'Home' -ServerUri 'http://explicit:32400' } |
                Should -Throw '*Cannot specify both -ServerName and -ServerUri*'
        }
    }

    Context 'When named server is not found' {
        BeforeEach {
            function Get-PatStoredServer { }
            Mock Get-PatStoredServer {
                throw "Server 'NonExistent' not found"
            }
        }

        It 'Should throw an error' {
            { Resolve-PatServerContext -ServerName 'NonExistent' } |
                Should -Throw "*Server 'NonExistent' not found*"
        }
    }
}
