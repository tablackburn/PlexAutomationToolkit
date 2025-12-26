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

Describe 'Get-PatServer' {
    BeforeAll {
        # Mock API response
        $script:mockApiResponse = [PSCustomObject]@{
            friendlyName = 'Test Plex Server'
            version = '1.32.5.7349'
            platform = 'Windows'
            platformVersion = '10.0'
            machineIdentifier = 'abc123def456'
            myPlex = $true
            myPlexSigninState = 'ok'
            myPlexUsername = 'testuser'
            transcoderActiveVideoSessions = 2
            size = 50000
            allowCameraUpload = $true
            allowChannelAccess = $true
            allowSync = $true
            allowTuners = $false
            backgroundProcessing = $true
            certificate = $true
            companionProxy = $true
        }
    }

    BeforeEach {
        Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockApiResponse
        }

        Mock -CommandName Join-PatUri -ModuleName PlexAutomationToolkit -MockWith {
            return 'http://test:32400/'
        }
    }

    Context 'Using explicit ServerUri' {
        It 'Should retrieve server info from specified URI' {
            $result = Get-PatServer -ServerUri 'http://test:32400'

            $result | Should -Not -BeNullOrEmpty
            $result.FriendlyName | Should -Be 'Test Plex Server'
            $result.Version | Should -Be '1.32.5.7349'
            $result.Platform | Should -Be 'Windows'
        }

        It 'Should call Join-PatUri with correct parameters' {
            Get-PatServer -ServerUri 'http://test:32400'

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $BaseUri -eq 'http://test:32400' -and $Endpoint -eq '/'
            }
        }

        It 'Should call Invoke-PatApi with correct URI' {
            Mock -CommandName Join-PatUri -ModuleName PlexAutomationToolkit -MockWith {
                return 'http://test:32400/'
            }

            Get-PatServer -ServerUri 'http://test:32400'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Uri -eq 'http://test:32400/'
            }
        }

        It 'Should return structured ServerInfo object' {
            $result = Get-PatServer -ServerUri 'http://test:32400'

            $result.PSObject.TypeNames | Should -Contain 'PlexAutomationToolkit.ServerInfo'
            $result.ServerUri | Should -Be 'http://test:32400'
        }

        It 'Should include all server properties' {
            $result = Get-PatServer -ServerUri 'http://test:32400'

            $result.FriendlyName | Should -Be 'Test Plex Server'
            $result.MachineIdentifier | Should -Be 'abc123def456'
            $result.MyPlex | Should -Be $true
            $result.MyPlexUsername | Should -Be 'testuser'
            $result.Transcoders | Should -Be 2
            $result.AllowCameraUpload | Should -Be $true
            $result.AllowChannelAccess | Should -Be $true
            $result.Certificate | Should -Be $true
        }
    }

    Context 'Using default server' {
        BeforeEach {
            $script:mockDefaultServer = [PSCustomObject]@{
                name = 'Default Server'
                uri = 'http://default:32400'
                token = 'test-token'
                default = $true
            }

            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockDefaultServer
            }

            Mock -CommandName Get-PatAuthHeaders -ModuleName PlexAutomationToolkit -MockWith {
                return @{ 'X-Plex-Token' = 'test-token'; 'Accept' = 'application/json' }
            }
        }

        It 'Should use default server when ServerUri not specified' {
            Get-PatServer

            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter { $Default -eq $true }
        }

        It 'Should call API with default server URI' {
            Get-PatServer

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $BaseUri -eq 'http://default:32400'
            }
        }

        It 'Should include authentication headers from stored server' {
            Get-PatServer

            Should -Invoke Get-PatAuthHeaders -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Server.token -eq 'test-token'
            }
        }

        It 'Should throw when no default server configured' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                return $null
            }

            { Get-PatServer } | Should -Throw "*No default server*"
        }

        It 'Should throw when Get-PatStoredServer fails' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Config error'
            }

            { Get-PatServer } | Should -Throw "*Failed to get default server*"
        }

        It 'Should cache default server for performance' {
            Get-PatServer
            Get-PatServer

            # Should only call Get-PatStoredServer once in begin block
            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Pipeline support' {
        It 'Should accept ServerUri from pipeline' {
            'http://server1:32400', 'http://server2:32400' | Get-PatServer

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Should process multiple URIs' {
            $uris = @('http://s1:32400', 'http://s2:32400', 'http://s3:32400')
            $results = $uris | Get-PatServer

            $results.Count | Should -Be 3
        }
    }

    Context 'Error handling' {
        It 'Should throw when API call fails' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatServer -ServerUri 'http://test:32400' } | Should -Throw "*Failed to get Plex server information*"
        }

        It 'Should propagate API error messages' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Connection refused'
            }

            { Get-PatServer -ServerUri 'http://test:32400' } | Should -Throw "*Connection refused*"
        }
    }

    Context 'Authentication handling' {
        It 'Should use default Accept header when no server object' {
            Get-PatServer -ServerUri 'http://test:32400'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Should use auth headers when using stored server' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    name = 'Auth Server'
                    uri = 'http://auth:32400'
                    token = 'secret-token'
                    default = $true
                }
            }

            Mock -CommandName Get-PatAuthHeaders -ModuleName PlexAutomationToolkit -MockWith {
                return @{ 'X-Plex-Token' = 'secret-token' }
            }

            Get-PatServer

            Should -Invoke Get-PatAuthHeaders -ModuleName PlexAutomationToolkit -Times 1
        }
    }
}
