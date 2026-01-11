BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Search-PatMedia' {

    BeforeAll {
        # Mock API response for search results
        $script:mockSearchResponse = @{
            size = 2
            Hub  = @(
                @{
                    hubKey        = 'movie'
                    type          = 'movie'
                    hubIdentifier = 'movie'
                    size          = 2
                    title         = 'Movies'
                    Metadata      = @(
                        @{
                            ratingKey             = '12345'
                            key                   = '/library/metadata/12345'
                            type                  = 'movie'
                            title                 = 'The Matrix'
                            summary               = 'A computer hacker learns about the true nature of reality.'
                            year                  = 1999
                            thumb                 = '/library/metadata/12345/thumb/1234567890'
                            librarySectionID      = 2
                            librarySectionTitle   = 'Movies'
                            duration              = 8160000
                            contentRating         = 'R'
                            rating                = 7.7
                            audienceRating        = 8.5
                            studio                = 'Warner Bros.'
                            viewCount             = 3
                            originallyAvailableAt = '1999-03-31'
                        }
                        @{
                            ratingKey             = '12346'
                            key                   = '/library/metadata/12346'
                            type                  = 'movie'
                            title                 = 'The Matrix Reloaded'
                            summary               = 'Neo and the rebels continue their fight.'
                            year                  = 2003
                            thumb                 = '/library/metadata/12346/thumb/1234567891'
                            librarySectionID      = 2
                            librarySectionTitle   = 'Movies'
                            duration              = 8280000
                            contentRating         = 'R'
                            rating                = 7.2
                            audienceRating        = 7.8
                            studio                = 'Warner Bros.'
                            viewCount             = 2
                            originallyAvailableAt = '2003-05-15'
                        }
                    )
                }
                @{
                    hubKey        = 'show'
                    type          = 'show'
                    hubIdentifier = 'show'
                    size          = 1
                    title         = 'TV Shows'
                    Metadata      = @(
                        @{
                            ratingKey             = '22345'
                            key                   = '/library/metadata/22345'
                            type                  = 'show'
                            title                 = 'Matrix Documentary'
                            summary               = 'Behind the scenes of The Matrix.'
                            year                  = 2020
                            thumb                 = '/library/metadata/22345/thumb/1234567892'
                            librarySectionID      = 3
                            librarySectionTitle   = 'TV Shows'
                            contentRating         = 'TV-14'
                            rating                = 8.0
                        }
                    )
                }
            )
        }

        # Mock empty search response
        $script:mockEmptySearchResponse = @{
            size = 0
            Hub  = @()
        }

        # Mock API response for library sections
        $script:mockSectionsResponse = @{
            size        = 2
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
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token-12345'
        }

        # Mock server context
        $script:mockServerContext = @{
            Uri            = 'http://plex-test-server.local:32400'
            Headers        = @{
                Accept         = 'application/json'
                'X-Plex-Token' = 'test-token-12345'
            }
            WasExplicitUri = $false
            Server         = $script:mockDefaultServer
        }
    }

    Context 'When searching with default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Returns flattened search results' {
            $result = Search-PatMedia -Query 'matrix'
            $result | Should -Not -BeNullOrEmpty
            $result | Should -HaveCount 3
        }

        It 'Returns results with expected properties' {
            $result = Search-PatMedia -Query 'matrix'
            $result[0].PSObject.TypeNames | Should -Contain 'PlexAutomationToolkit.SearchResult'
            $result[0].Type | Should -Be 'movie'
            $result[0].Title | Should -Be 'The Matrix'
            $result[0].Year | Should -Be 1999
            $result[0].RatingKey | Should -Be 12345
            $result[0].LibraryName | Should -Be 'Movies'
        }

        It 'Returns new media detail properties' {
            $result = Search-PatMedia -Query 'matrix'
            $result[0].Duration | Should -Be 8160000
            $result[0].DurationFormatted | Should -Be '2h 16m'
            $result[0].ContentRating | Should -Be 'R'
            $result[0].Rating | Should -Be 7.7
            $result[0].AudienceRating | Should -Be 8.5
            $result[0].Studio | Should -Be 'Warner Bros.'
            $result[0].ViewCount | Should -Be 3
            $result[0].OriginallyAvailableAt | Should -Be ([datetime]'1999-03-31')
        }

        It 'Includes results from all hub types' {
            $result = Search-PatMedia -Query 'matrix'
            $movieResults = $result | Where-Object { $_.Type -eq 'movie' }
            $showResults = $result | Where-Object { $_.Type -eq 'show' }
            $movieResults | Should -HaveCount 2
            $showResults | Should -HaveCount 1
        }

        It 'Calls Join-PatUri with correct endpoint and query' {
            Search-PatMedia -Query 'matrix'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/hubs/search' -and
                $QueryString -match 'query=matrix'
            }
        }

        It 'Uses default limit of 10' {
            Search-PatMedia -Query 'matrix'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'limit=10'
            }
        }
    }

    Context 'When filtering by type' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Filters results to only movie type' {
            $result = Search-PatMedia -Query 'matrix' -Type 'movie'
            $result | Should -HaveCount 2
            $result | ForEach-Object { $_.Type | Should -Be 'movie' }
        }

        It 'Filters results to only show type' {
            $result = Search-PatMedia -Query 'matrix' -Type 'show'
            $result | Should -HaveCount 1
            $result[0].Type | Should -Be 'show'
        }

        It 'Accepts multiple types' {
            $result = Search-PatMedia -Query 'matrix' -Type 'movie', 'show'
            $result | Should -HaveCount 3
        }

        It 'Returns nothing when type filter has no matches' {
            $result = Search-PatMedia -Query 'matrix' -Type 'artist'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When searching with custom limit' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Passes custom limit to API' {
            Search-PatMedia -Query 'matrix' -Limit 5
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'limit=5'
            }
        }
    }

    Context 'When searching by SectionName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Resolves SectionName to SectionId and includes in query' {
            Search-PatMedia -Query 'matrix' -SectionName 'Movies'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'sectionId=2'
            }
        }

        It 'Calls Get-PatLibrary to resolve section name' {
            Search-PatMedia -Query 'matrix' -SectionName 'Movies'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -Exactly 1
        }
    }

    Context 'When searching by SectionId' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Includes SectionId in query' {
            Search-PatMedia -Query 'matrix' -SectionId 2
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'sectionId=2'
            }
        }
    }

    Context 'When SectionName is not found' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }
        }

        It 'Throws an error when section name does not exist' {
            { Search-PatMedia -Query 'matrix' -SectionName 'NonExistent' } |
                Should -Throw "*Library section 'NonExistent' not found*"
        }
    }

    Context 'When search returns no results' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockEmptySearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Returns nothing for empty search results' {
            $result = Search-PatMedia -Query 'nonexistent'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]@{
                    Uri            = 'http://explicit-server.local:32400'
                    Headers        = @{ Accept = 'application/json' }
                    WasExplicitUri = $true
                    Server         = $null
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Uses the explicit ServerUri' {
            $result = Search-PatMedia -Query 'matrix' -ServerUri 'http://explicit-server.local:32400'
            $result | Should -Not -BeNullOrEmpty
            $result[0].ServerUri | Should -Be 'http://explicit-server.local:32400'
        }

        It 'Calls Resolve-PatServerContext with ServerUri' {
            Search-PatMedia -Query 'matrix' -ServerUri 'http://explicit-server.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $ServerUri -eq 'http://explicit-server.local:32400'
            }
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection timeout'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Throws an error with context' {
            { Search-PatMedia -Query 'matrix' } |
                Should -Throw '*Search failed*'
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Accepts Query from pipeline' {
            $result = 'matrix' | Search-PatMedia
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter validation' {
        It 'Requires Query parameter' {
            { Search-PatMedia } | Should -Throw
        }

        It 'Rejects empty Query' {
            { Search-PatMedia -Query '' } | Should -Throw
        }

        It 'Validates Type parameter values' {
            { Search-PatMedia -Query 'test' -Type 'invalid' } | Should -Throw
        }

        It 'Accepts valid Type values' {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }
            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://test/hubs/search?query=test'
            }

            { Search-PatMedia -Query 'test' -Type 'movie' } | Should -Not -Throw
            { Search-PatMedia -Query 'test' -Type 'show' } | Should -Not -Throw
            { Search-PatMedia -Query 'test' -Type 'episode' } | Should -Not -Throw
            { Search-PatMedia -Query 'test' -Type 'artist' } | Should -Not -Throw
        }

        It 'Validates Limit range - rejects 0' {
            { Search-PatMedia -Query 'test' -Limit 0 } | Should -Throw
        }

        It 'Validates Limit range - rejects negative' {
            { Search-PatMedia -Query 'test' -Limit -1 } | Should -Throw
        }

        It 'Validates Limit range - rejects over 1000' {
            { Search-PatMedia -Query 'test' -Limit 1001 } | Should -Throw
        }

        It 'Validates ServerUri format - rejects invalid URI' {
            { Search-PatMedia -Query 'test' -ServerUri 'not-a-valid-uri' } | Should -Throw
        }
    }

    Context 'When searching by SectionId with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]@{
                    Uri            = 'http://explicit-server.local:32400'
                    Headers        = @{ Accept = 'application/json' }
                    WasExplicitUri = $true
                    Server         = $null
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Passes ServerUri to Get-PatLibrary when explicit' {
            Search-PatMedia -Query 'matrix' -SectionId 2 -ServerUri 'http://explicit-server.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $ServerUri -eq 'http://explicit-server.local:32400'
            }
        }

        It 'Gets section name for output' {
            $result = Search-PatMedia -Query 'matrix' -SectionId 2 -ServerUri 'http://explicit-server.local:32400'
            # Should resolve the section name from the ID
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary
        }
    }

    Context 'When searching by SectionName with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]@{
                    Uri            = 'http://explicit-server.local:32400'
                    Headers        = @{ Accept = 'application/json' }
                    WasExplicitUri = $true
                    Server         = $null
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Passes ServerUri to Get-PatLibrary when resolving section name' {
            Search-PatMedia -Query 'matrix' -SectionName 'Movies' -ServerUri 'http://explicit-server.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $ServerUri -eq 'http://explicit-server.local:32400'
            }
        }
    }

    Context 'When result items have missing library info' {
        BeforeAll {
            $script:mockSearchNoLibraryInfo = @{
                size = 1
                Hub  = @(
                    @{
                        hubKey      = 'movie'
                        type        = 'movie'
                        size        = 1
                        title       = 'Movies'
                        Metadata    = @(
                            @{
                                ratingKey = '12345'
                                title     = 'Test Movie'
                                year      = 2023
                                # No librarySectionID or librarySectionTitle
                            }
                        )
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchNoLibraryInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Returns null for library info when not provided' {
            $result = Search-PatMedia -Query 'test'
            $result[0].LibraryId | Should -BeNullOrEmpty
            $result[0].LibraryName | Should -BeNullOrEmpty
        }
    }

    Context 'When result items have missing optional properties' {
        BeforeAll {
            $script:mockSearchMinimalItem = @{
                size = 1
                Hub  = @(
                    @{
                        hubKey   = 'movie'
                        type     = 'movie'
                        size     = 1
                        title    = 'Movies'
                        Metadata = @(
                            @{
                                title = 'Test Movie'
                                # No ratingKey, year, summary, thumb
                            }
                        )
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchMinimalItem
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Handles items without ratingKey' {
            $result = Search-PatMedia -Query 'test'
            $result[0].RatingKey | Should -BeNullOrEmpty
        }

        It 'Handles items without year' {
            $result = Search-PatMedia -Query 'test'
            $result[0].Year | Should -BeNullOrEmpty
        }
    }

    Context 'When hub has empty Metadata' {
        BeforeAll {
            $script:mockSearchEmptyHub = @{
                size = 1
                Hub  = @(
                    @{
                        hubKey   = 'movie'
                        type     = 'movie'
                        size     = 0
                        title    = 'Movies'
                        # Metadata is null or missing
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchEmptyHub
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Skips hubs with no Metadata' {
            $result = Search-PatMedia -Query 'test'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            Search-PatMedia -Query 'matrix' -ServerUri 'http://test:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'When searching returns episode results' {
        BeforeAll {
            $script:mockEpisodeSearchResponse = @{
                size = 1
                Hub  = @(
                    @{
                        hubKey        = 'episode'
                        type          = 'episode'
                        hubIdentifier = 'episode'
                        size          = 2
                        title         = 'Episodes'
                        Metadata      = @(
                            @{
                                ratingKey             = '33001'
                                key                   = '/library/metadata/33001'
                                type                  = 'episode'
                                title                 = 'Pilot'
                                summary               = 'Walter White begins his journey.'
                                year                  = 2008
                                thumb                 = '/library/metadata/33001/thumb/1234567893'
                                librarySectionID      = 3
                                librarySectionTitle   = 'TV Shows'
                                duration              = 3480000
                                contentRating         = 'TV-MA'
                                rating                = 9.0
                                grandparentTitle      = 'Breaking Bad'
                                parentIndex           = 1
                                index                 = 1
                                originallyAvailableAt = '2008-01-20'
                            }
                            @{
                                ratingKey             = '33002'
                                key                   = '/library/metadata/33002'
                                type                  = 'episode'
                                title                 = "Cat's in the Bag..."
                                summary               = 'Walt and Jesse deal with consequences.'
                                year                  = 2008
                                thumb                 = '/library/metadata/33002/thumb/1234567894'
                                librarySectionID      = 3
                                librarySectionTitle   = 'TV Shows'
                                duration              = 2880000
                                contentRating         = 'TV-MA'
                                grandparentTitle      = 'Breaking Bad'
                                parentIndex           = 1
                                index                 = 2
                                originallyAvailableAt = '2008-01-27'
                            }
                        )
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockEpisodeSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Returns episode-specific ShowName property' {
            $result = Search-PatMedia -Query 'breaking'
            $result[0].ShowName | Should -Be 'Breaking Bad'
        }

        It 'Returns episode-specific Season property' {
            $result = Search-PatMedia -Query 'breaking'
            $result[0].Season | Should -Be 1
        }

        It 'Returns episode-specific Episode property' {
            $result = Search-PatMedia -Query 'breaking'
            $result[0].Episode | Should -Be 1
            $result[1].Episode | Should -Be 2
        }

        It 'Returns formatted duration for episodes' {
            $result = Search-PatMedia -Query 'breaking'
            $result[0].Duration | Should -Be 3480000
            $result[0].DurationFormatted | Should -Be '58m'
        }

        It 'Returns content rating for episodes' {
            $result = Search-PatMedia -Query 'breaking'
            $result[0].ContentRating | Should -Be 'TV-MA'
        }
    }

    Context 'When movie results have null episode fields' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]$script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockSearchResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }
        }

        It 'Returns null ShowName for movies' {
            $result = Search-PatMedia -Query 'matrix' -Type 'movie'
            $result[0].ShowName | Should -BeNullOrEmpty
        }

        It 'Returns null Season for movies' {
            $result = Search-PatMedia -Query 'matrix' -Type 'movie'
            $result[0].Season | Should -BeNullOrEmpty
        }

        It 'Returns null Episode for movies' {
            $result = Search-PatMedia -Query 'matrix' -Type 'movie'
            $result[0].Episode | Should -BeNullOrEmpty
        }
    }
}
