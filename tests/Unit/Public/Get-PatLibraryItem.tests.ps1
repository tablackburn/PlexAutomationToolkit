BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatLibraryItem' {

    BeforeAll {
        # Mock API response for library items (movies)
        $script:mockLibraryItemsResponse = @{
            size            = 3
            allowSync       = $true
            art             = '/:/resources/movie-fanart.jpg'
            identifier      = 'com.plexapp.plugins.library'
            librarySectionID = 2
            librarySectionTitle = 'Movies'
            librarySectionUUID = '00000000-0000-0000-0000-000000000002'
            Metadata        = @(
                @{
                    ratingKey           = '12345'
                    key                 = '/library/metadata/12345'
                    guid                = 'plex://movie/5d776b59ad5437001f79c6b8'
                    studio              = 'Test Studio'
                    type                = 'movie'
                    title               = 'Test Movie 1'
                    contentRating       = 'PG-13'
                    summary             = 'A test movie for unit testing.'
                    rating              = 7.5
                    audienceRating      = 8.0
                    year                = 2023
                    thumb               = '/library/metadata/12345/thumb/1234567890'
                    art                 = '/library/metadata/12345/art/1234567890'
                    duration            = 7200000
                    addedAt             = 1700000000
                    updatedAt           = 1700100000
                }
                @{
                    ratingKey           = '12346'
                    key                 = '/library/metadata/12346'
                    guid                = 'plex://movie/5d776b59ad5437001f79c6b9'
                    studio              = 'Another Studio'
                    type                = 'movie'
                    title               = 'Test Movie 2'
                    contentRating       = 'R'
                    summary             = 'Another test movie.'
                    rating              = 6.5
                    audienceRating      = 7.0
                    year                = 2022
                    thumb               = '/library/metadata/12346/thumb/1234567891'
                    art                 = '/library/metadata/12346/art/1234567891'
                    duration            = 5400000
                    addedAt             = 1699000000
                    updatedAt           = 1699100000
                }
                @{
                    ratingKey           = '12347'
                    key                 = '/library/metadata/12347'
                    guid                = 'plex://movie/5d776b59ad5437001f79c6ba'
                    studio              = 'Test Studio'
                    type                = 'movie'
                    title               = 'Test Movie 3'
                    contentRating       = 'PG'
                    summary             = 'Yet another test movie.'
                    rating              = 8.0
                    audienceRating      = 8.5
                    year                = 2024
                    thumb               = '/library/metadata/12347/thumb/1234567892'
                    art                 = '/library/metadata/12347/art/1234567892'
                    duration            = 6600000
                    addedAt             = 1701000000
                    updatedAt           = 1701100000
                }
            )
        }

        # Mock API response for library sections (used when resolving SectionName)
        $script:mockSectionsResponse = @{
            size        = 3
            allowSync   = $false
            title1      = 'Plex Library'
            Directory   = @(
                @{
                    key     = '/library/sections/2'
                    type    = 'movie'
                    title   = 'Movies'
                    uuid    = '00000000-0000-0000-0000-000000000002'
                }
                @{
                    key     = '/library/sections/3'
                    type    = 'show'
                    title   = 'TV Shows'
                    uuid    = '00000000-0000-0000-0000-000000000003'
                }
                @{
                    key     = '/library/sections/9'
                    type    = 'movie'
                    title   = '4K Movies'
                    uuid    = '00000000-0000-0000-0000-000000000009'
                }
            )
        }

        # Mock empty library response
        $script:mockEmptyLibraryResponse = @{
            size            = 0
            allowSync       = $true
            identifier      = 'com.plexapp.plugins.library'
            librarySectionID = 5
            librarySectionTitle = 'Empty Library'
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token-12345'
        }
    }

    Context 'When retrieving items by SectionId with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockLibraryItemsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/all'
            }
        }

        It 'Returns all items from the library section' {
            $result = Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 2
            $result | Should -Not -BeNullOrEmpty
            $result | Should -HaveCount 3
        }

        It 'Returns items with expected properties' {
            $result = Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 2
            $result[0].title | Should -Be 'Test Movie 1'
            $result[0].year | Should -Be 2023
            $result[0].type | Should -Be 'movie'
            $result[1].title | Should -Be 'Test Movie 2'
            $result[2].title | Should -Be 'Test Movie 3'
        }

        It 'Calls Join-PatUri with correct endpoint' {
            Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 2
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-test-server.local:32400' -and
                $Endpoint -eq '/library/sections/2/all'
            }
        }

        It 'Calls Invoke-PatApi exactly once' {
            Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 2
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 1
        }

        It 'Validates SectionId is greater than 0' {
            { Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 0 } | Should -Throw
        }

        It 'Validates SectionId rejects negative values' {
            { Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId -1 } | Should -Throw
        }
    }

    Context 'When retrieving items by SectionName with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockLibraryItemsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/all'
            }
        }

        It 'Resolves SectionName to SectionId and returns items' {
            $result = Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Movies'
            $result | Should -Not -BeNullOrEmpty
            $result | Should -HaveCount 3
        }

        It 'Calls Get-PatLibrary to resolve section name' {
            Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Movies'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -Exactly 1
        }

        It 'Calls Join-PatUri with resolved SectionId' {
            Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Movies'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/sections/2/all'
            }
        }
    }

    Context 'When SectionName is not found' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }
        }

        It 'Throws an error when section name does not exist' {
            { Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionName 'NonExistent' } |
                Should -Throw "*Library section 'NonExistent' not found*"
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeader {
                return @{
                    Accept             = 'application/json'
                    'X-Plex-Token'     = 'test-token-12345'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockLibraryItemsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/all'
            }
        }

        It 'Uses the default server URI' {
            $result = Get-PatLibraryItem -SectionId 2
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Uses authentication headers from default server' {
            Get-PatLibraryItem -SectionId 2
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatAuthHeader -Exactly 1
        }

        It 'Calls Join-PatUri with default server URI' {
            Get-PatLibraryItem -SectionId 2
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-test-server.local:32400'
            }
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Get-PatLibraryItem -SectionId 2 } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When library section is empty' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockEmptyLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/5/all'
            }
        }

        It 'Returns nothing for empty library' {
            $result = Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 5
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection timeout'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/all'
            }
        }

        It 'Throws an error with context' {
            { Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 } |
                Should -Throw '*Failed to get library items*'
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockLibraryItemsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Accepts SectionId from pipeline' {
            $result = 2 | Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Processes multiple SectionIds from pipeline' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockLibraryItemsResponse
            }

            $result = @(2, 3) | Get-PatLibraryItem -ServerUri 'http://plex-test-server.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 2
        }
    }

    Context 'Parameter validation' {
        It 'Validates ServerUri format - rejects invalid URI' {
            { Get-PatLibraryItem -ServerUri 'not-a-valid-uri' -SectionId 2 } | Should -Throw
        }

        It 'Validates ServerUri format - rejects URI without protocol' {
            { Get-PatLibraryItem -ServerUri 'plex.local:32400' -SectionId 2 } | Should -Throw
        }

        It 'Accepts valid HTTP ServerUri' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { return $script:mockLibraryItemsResponse }
            Mock -ModuleName PlexAutomationToolkit Join-PatUri { return 'http://plex.local:32400/library/sections/2/all' }

            { Get-PatLibraryItem -ServerUri 'http://plex.local:32400' -SectionId 2 } | Should -Not -Throw
        }

        It 'Accepts valid HTTPS ServerUri' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { return $script:mockLibraryItemsResponse }
            Mock -ModuleName PlexAutomationToolkit Join-PatUri { return 'https://plex.local:32400/library/sections/2/all' }

            { Get-PatLibraryItem -ServerUri 'https://plex.local:32400' -SectionId 2 } | Should -Not -Throw
        }

        It 'Rejects empty SectionName' {
            { Get-PatLibraryItem -ServerUri 'http://plex.local:32400' -SectionName '' } | Should -Throw
        }
    }
}
