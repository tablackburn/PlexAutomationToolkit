BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatStoredServer' {

    BeforeAll {
        # Mock server configuration data
        $script:mockConfig = @{
            version = '1.0'
            servers = @(
                @{
                    name    = 'Primary Server'
                    uri     = 'http://plex-test-server.local:32400'
                    default = $true
                }
                @{
                    name    = 'Secondary Server'
                    uri     = 'http://plex-test-server-2.local:32400'
                    default = $false
                }
            )
        }
    }

    Context 'When retrieving all servers' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatServerConfig {
                return $script:mockConfig
            }
        }

        It 'Returns all stored servers' {
            $result = Get-PatStoredServer
            $result | Should -HaveCount 2
            $result[0].name | Should -Be 'Primary Server'
            $result[1].name | Should -Be 'Secondary Server'
        }

        It 'Calls Get-PatServerConfig once' {
            Get-PatStoredServer
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatServerConfig -Exactly 1
        }
    }

    Context 'When retrieving the default server' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatServerConfig {
                return $script:mockConfig
            }
        }

        It 'Returns only the default server' {
            $result = Get-PatStoredServer -Default
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Primary Server'
            $result.default | Should -Be $true
        }

        It 'Throws when no default server is configured' {
            Mock -ModuleName $Env:BHProjectName Get-PatServerConfig {
                return @{
                    version = '1.0'
                    servers = @(
                        @{
                            name    = 'Server'
                            uri     = 'http://192.168.1.6:32400'
                            default = $false
                        }
                    )
                }
            }

            { Get-PatStoredServer -Default } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When retrieving a server by name' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatServerConfig {
                return $script:mockConfig
            }
        }

        It 'Returns the server with the specified name' {
            $result = Get-PatStoredServer -Name 'Secondary Server'
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Secondary Server'
            $result.uri | Should -Be 'http://plex-test-server-2.local:32400'
        }

        It 'Throws when server name is not found' {
            { Get-PatStoredServer -Name 'Nonexistent Server' } | Should -Throw "*No server found with name 'Nonexistent Server'*"
        }
    }

    Context 'When Get-PatServerConfig fails' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatServerConfig {
                throw 'Config file not found'
            }
        }

        It 'Throws an error with the underlying message' {
            { Get-PatStoredServer } | Should -Throw '*Failed to get stored servers*'
        }
    }
}
