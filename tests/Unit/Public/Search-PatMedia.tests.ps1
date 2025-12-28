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
                    hubKey      = 'movie'
                    type        = 'movie'
                    hubIdentifier = 'movie'
                    size        = 2
                    title       = 'Movies'
                    Metadata    = @(
                        @{
                            ratingKey           = '12345'
                            key                 = '/library/metadata/12345'
                            type                = 'movie'
                            title               = 'The Matrix'
                            summary             = 'A computer hacker learns about the true nature of reality.'
                            year                = 1999
                            thumb               = '/library/metadata/12345/thumb/1234567890'
                            librarySectionID    = 2
                            librarySectionTitle = 'Movies'
                        }
                        @{
                            ratingKey           = '12346'
                            key                 = '/library/metadata/12346'
                            type                = 'movie'
                            title               = 'The Matrix Reloaded'
                            summary             = 'Neo and the rebels continue their fight.'
                            year                = 2003
                            thumb               = '/library/metadata/12346/thumb/1234567891'
                            librarySectionID    = 2
                            librarySectionTitle = 'Movies'
                        }
                    )
                }
                @{
                    hubKey      = 'show'
                    type        = 'show'
                    hubIdentifier = 'show'
                    size        = 1
                    title       = 'TV Shows'
                    Metadata    = @(
                        @{
                            ratingKey           = '22345'
                            key                 = '/library/metadata/22345'
                            type                = 'show'
                            title               = 'Matrix Documentary'
                            summary             = 'Behind the scenes of The Matrix.'
                            year                = 2020
                            thumb               = '/library/metadata/22345/thumb/1234567892'
                            librarySectionID    = 3
                            librarySectionTitle = 'TV Shows'
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
}
