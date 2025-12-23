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

Describe 'Get-PatLibrary' {

    BeforeAll {
        # Mock API response for all library sections (sanitized test data)
        $script:mockAllSectionsResponse = @{
            size        = 7
            allowSync   = $false
            title1      = 'Plex Library'
            Directory   = @(
                @{
                    allowSync   = $false
                    filters     = $true
                    refreshing  = $false
                    key         = '9'
                    type        = 'movie'
                    title       = '4K Movies'
                    agent       = 'tv.plex.agents.movie'
                    scanner     = 'Plex Movie'
                    language    = 'en-US'
                    uuid        = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'
                }
                @{
                    allowSync   = $false
                    filters     = $true
                    refreshing  = $false
                    key         = '2'
                    type        = 'movie'
                    title       = 'Movies'
                    agent       = 'tv.plex.agents.movie'
                    scanner     = 'Plex Movie'
                    language    = 'en-US'
                    uuid        = 'f1e2d3c4-b5a6-47b8-9c0d-1e2f3a4b5c6d'
                }
                @{
                    allowSync   = $false
                    filters     = $true
                    refreshing  = $false
                    key         = '3'
                    type        = 'show'
                    title       = 'TV Shows'
                    agent       = 'tv.plex.agents.series'
                    scanner     = 'Plex TV Series'
                    language    = 'en-US'
                    uuid        = '9a8b7c6d-5e4f-4321-ab0c-de1f2a3b4c5d'
                }
            )
        }

        # Mock API response for a specific section (sanitized test data)
        $script:mockSectionResponse = @{
            size               = 20
            allowSync          = $false
            art                = '/:/resources/movie-fanart.jpg'
            content            = 'secondary'
            identifier         = 'com.plexapp.plugins.library'
            librarySectionID   = 2
            mediaTagPrefix     = '/system/bundle/media/flags/'
            mediaTagVersion    = 1758205129
            thumb              = '/:/resources/movie.png'
            title1             = 'Movies'
            viewGroup          = 'secondary'
            viewMode           = 65592
            Directory          = @(
                @{
                    key   = 'all'
                    title = 'All Movies'
                }
                @{
                    key   = 'unwatched'
                    title = 'Unwatched'
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://192.168.1.6:32400'
            default = $true
        }
    }

    Context 'When retrieving all library sections with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockAllSectionsResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections'
            }
        }

        It 'Returns all library sections' {
            $result = Get-PatLibrary -ServerUri 'http://192.168.1.6:32400'
            $result | Should -Not -BeNullOrEmpty
            $result.Directory | Should -HaveCount 3
            $result.Directory[0].title | Should -Be '4K Movies'
            $result.Directory[1].title | Should -Be 'Movies'
            $result.Directory[2].title | Should -Be 'TV Shows'
        }

        It 'Calls Join-PatUri with correct endpoint' {
            Get-PatLibrary -ServerUri 'http://192.168.1.6:32400'
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.6:32400' -and
                $Endpoint -eq '/library/sections'
            }
        }

        It 'Calls Invoke-PatApi with correct URI' {
            Get-PatLibrary -ServerUri 'http://192.168.1.6:32400'
            Should -Invoke -ModuleName $Env:BHProjectName Invoke-PatApi -Exactly 1
        }
    }

    Context 'When retrieving a specific library section with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockSectionResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections/2'
            }
        }

        It 'Returns the specific library section' {
            $result = Get-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2
            $result | Should -Not -BeNullOrEmpty
            $result.title1 | Should -Be 'Movies'
            $result.librarySectionID | Should -Be 2
        }

        It 'Calls Join-PatUri with correct endpoint including SectionId' {
            Get-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.6:32400' -and
                $Endpoint -eq '/library/sections/2'
            }
        }

        It 'Validates SectionId is greater than 0' {
            { Get-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 0 } | Should -Throw
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $script:mockAllSectionsResponse
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections'
            }
        }

        It 'Uses the default server URI' {
            $result = Get-PatLibrary
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Calls Join-PatUri with default server URI' {
            Get-PatLibrary
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.6:32400'
            }
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Get-PatLibrary } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                throw 'Connection timeout'
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections'
            }
        }

        It 'Throws an error with context' {
            { Get-PatLibrary -ServerUri 'http://192.168.1.6:32400' } | Should -Throw '*Failed to get Plex library information*'
        }
    }
}
