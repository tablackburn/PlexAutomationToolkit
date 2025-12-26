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

Describe 'Get-PatActivity' {

    BeforeAll {
        # Mock activities response
        $script:mockActivitiesResponse = @{
            Activity = @(
                @{
                    uuid        = 'abc-123'
                    type        = 'library.update.section'
                    title       = 'Scanning Movies'
                    subtitle    = 'Processing: Action/Movie.mkv'
                    progress    = 45
                    cancellable = $true
                    userStopped = $false
                    Context     = @{
                        librarySectionID = 2
                    }
                }
                @{
                    uuid        = 'def-456'
                    type        = 'media.optimize'
                    title       = 'Optimizing media'
                    subtitle    = 'Video.mkv'
                    progress    = 80
                    cancellable = $true
                    userStopped = $false
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
        }
    }

    Context 'When retrieving all activities' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockActivitiesResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex.local:32400/activities'
            }
        }

        It 'Returns all activities' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400'
            $result.Count | Should -Be 2
        }

        It 'Calls the activities endpoint' {
            Get-PatActivity -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $Endpoint -eq '/activities'
            }
        }

        It 'Returns properly structured activity objects' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'ActivityId'
            $result[0].PSObject.Properties.Name | Should -Contain 'Type'
            $result[0].PSObject.Properties.Name | Should -Contain 'Progress'
        }
    }

    Context 'When filtering by type' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockActivitiesResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex.local:32400/activities'
            }
        }

        It 'Returns only activities matching type' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400' -Type 'library.update.section'
            $result.Count | Should -Be 1
            $result[0].Type | Should -Be 'library.update.section'
        }
    }

    Context 'When filtering by SectionId' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockActivitiesResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex.local:32400/activities'
            }
        }

        It 'Returns only activities for specified section' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400' -SectionId 2
            $result.Count | Should -Be 1
            $result[0].SectionId | Should -Be 2
        }

        It 'Returns nothing when no activities match section' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400' -SectionId 99
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When no activities are running' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return @{ Activity = @() }
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex.local:32400/activities'
            }
        }

        It 'Returns empty collection' {
            $result = Get-PatActivity -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockActivitiesResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex-test-server.local:32400/activities'
            }

            Mock -ModuleName $Env:BHProjectName Get-PatAuthHeaders {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Get-PatActivity
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                throw 'Connection refused'
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://plex.local:32400/activities'
            }
        }

        It 'Throws an error with context' {
            { Get-PatActivity -ServerUri 'http://plex.local:32400' } | Should -Throw '*Failed to retrieve activities*'
        }
    }
}
