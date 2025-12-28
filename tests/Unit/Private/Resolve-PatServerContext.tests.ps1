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

        It 'Should propagate the error' {
            { Resolve-PatServerContext } | Should -Throw '*Config file not found*'
        }
    }
}
