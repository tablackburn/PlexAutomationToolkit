BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Test-PatServer' {

    BeforeAll {
        # Mock server configuration
        $script:mockServer = @{
            name    = 'Home'
            uri     = 'http://plex.local:32400'
            default = $true
        }

        # Mock successful server response
        $script:mockServerInfo = @{
            friendlyName = 'My Plex Server'
            version      = '1.32.0.0'
            platform     = 'Linux'
        }
    }

    Context 'When server is reachable and authenticated' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockServer
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return @{
                    Uri               = 'http://plex.local:32400'
                    Headers           = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
                    WasExplicitUri    = $false
                    Server            = $script:mockServer
                    IsLocalConnection = $false
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/'
            }
        }

        It 'Returns successful test result' {
            $result = Test-PatServer -Name 'Home'
            $result.IsConnected | Should -Be $true
            $result.IsAuthenticated | Should -Be $true
        }

        It 'Returns server details when connected' {
            $result = Test-PatServer -Name 'Home'
            $result.FriendlyName | Should -Be 'My Plex Server'
            $result.Version | Should -Be '1.32.0.0'
        }

        It 'Returns true with -Quiet switch' {
            $result = Test-PatServer -Name 'Home' -Quiet
            $result | Should -Be $true
        }

        It 'Returns no error when successful' {
            $result = Test-PatServer -Name 'Home'
            $result.Error | Should -BeNullOrEmpty
        }
    }

    Context 'When server is unreachable' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockServer
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                throw 'Unable to connect to server'
            }
        }

        It 'Returns unsuccessful test result' {
            $result = Test-PatServer -Name 'Home'
            $result.IsConnected | Should -Be $false
            $result.IsAuthenticated | Should -Be $false
        }

        It 'Returns false with -Quiet switch' {
            $result = Test-PatServer -Name 'Home' -Quiet
            $result | Should -Be $false
        }

        It 'Returns error message' {
            $result = Test-PatServer -Name 'Home'
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When authentication fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockServer
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return @{
                    Uri               = 'http://plex.local:32400'
                    Headers           = @{ Accept = 'application/json' }
                    WasExplicitUri    = $false
                    Server            = $script:mockServer
                    IsLocalConnection = $false
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw '401 Unauthorized'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/'
            }
        }

        It 'Returns connected but not authenticated' {
            $result = Test-PatServer -Name 'Home'
            $result.IsConnected | Should -Be $true
            $result.IsAuthenticated | Should -Be $false
        }

        It 'Returns authentication error message' {
            $result = Test-PatServer -Name 'Home'
            $result.Error | Should -Match 'Authentication'
        }
    }

    Context 'When server not found in configuration' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                throw "Server 'NonExistent' not found"
            }
        }

        It 'Returns error when server not found' {
            $result = Test-PatServer -Name 'NonExistent'
            $result.IsConnected | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }

    Context 'With pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockServer
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return @{
                    Uri               = 'http://plex.local:32400'
                    Headers           = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
                    WasExplicitUri    = $false
                    Server            = $script:mockServer
                    IsLocalConnection = $false
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/'
            }
        }

        It 'Accepts server name from pipeline' {
            $result = 'Home' | Test-PatServer
            $result.Name | Should -Be 'Home'
        }
    }

    Context 'Output type' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockServer
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return @{
                    Uri               = 'http://plex.local:32400'
                    Headers           = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
                    WasExplicitUri    = $false
                    Server            = $script:mockServer
                    IsLocalConnection = $false
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/'
            }
        }

        It 'Returns PlexAutomationToolkit.ServerTestResult type' {
            $result = Test-PatServer -Name 'Home'
            $result.PSObject.TypeNames | Should -Contain 'PlexAutomationToolkit.ServerTestResult'
        }

        It 'Returns boolean with -Quiet' {
            $result = Test-PatServer -Name 'Home' -Quiet
            $result.GetType().Name | Should -Be 'Boolean'
        }
    }
}
