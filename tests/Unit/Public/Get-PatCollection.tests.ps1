BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatCollection' {

    BeforeAll {
        $script:mockCollectionsResponse = @{
            size     = 2
            Metadata = @(
                @{
                    ratingKey        = '12345'
                    title            = 'Marvel Movies'
                    librarySectionID = '1'
                    childCount       = 10
                    thumb            = '/library/collections/12345/thumb/1234567890'
                    addedAt          = 1703548800
                    updatedAt        = 1703635200
                }
                @{
                    ratingKey        = '67890'
                    title            = 'Horror Classics'
                    librarySectionID = '1'
                    childCount       = 5
                    thumb            = '/library/collections/67890/thumb/1234567891'
                    addedAt          = 1703462400
                    updatedAt        = 1703548800
                }
            )
        }

        $script:mockCollectionItemsResponse = @{
            size     = 2
            Metadata = @(
                @{
                    ratingKey = '1001'
                    title     = 'Iron Man'
                    type      = 'movie'
                    year      = 2008
                    thumb     = '/library/metadata/1001/thumb/123'
                    addedAt   = 1703548800
                }
                @{
                    ratingKey = '1002'
                    title     = 'The Avengers'
                    type      = 'movie'
                    year      = 2012
                    thumb     = '/library/metadata/1002/thumb/456'
                    addedAt   = 1703548900
                }
            )
        }

        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When retrieving all collections from a library' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns all collections' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result.Count | Should -Be 2
        }

        It 'Calls the collections endpoint with library section' {
            Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/sections/1/collections'
            }
        }

        It 'Returns properly structured collection objects' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'CollectionId'
            $result[0].PSObject.Properties.Name | Should -Contain 'Title'
            $result[0].PSObject.Properties.Name | Should -Contain 'LibraryId'
            $result[0].PSObject.Properties.Name | Should -Contain 'ItemCount'
        }

        It 'Maps API properties correctly' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result[0].CollectionId | Should -Be 12345
            $result[0].Title | Should -Be 'Marvel Movies'
            $result[0].LibraryId | Should -Be 1
            $result[0].ItemCount | Should -Be 10
        }

        It 'Has correct PSTypeName' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
        }

        It 'Includes ServerUri in output' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result[0].ServerUri | Should -Be 'http://plex.local:32400'
        }
    }

    Context 'When retrieving collection by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    librarySectionID = '1'
                    Metadata         = @(
                        @{
                            ratingKey  = '12345'
                            title      = 'Marvel Movies'
                            childCount = 10
                            thumb      = '/library/collections/12345/thumb'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns specific collection' {
            $result = Get-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            $result.CollectionId | Should -Be 12345
            $result.Title | Should -Be 'Marvel Movies'
        }

        It 'Calls the specific collection endpoint' {
            Get-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/collections/12345'
            }
        }
    }

    Context 'When retrieving collection by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns collection matching the name' {
            $result = Get-PatCollection -CollectionName 'Marvel Movies' -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result.Title | Should -Be 'Marvel Movies'
        }

        It 'Throws when collection name not found' {
            { Get-PatCollection -CollectionName 'Nonexistent' -LibraryId 1 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*"
        }
    }

    Context 'When including items' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return $script:mockCollectionsResponse
                }
                else {
                    return $script:mockCollectionItemsResponse
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        BeforeEach {
            $script:callCount = 0
        }

        It 'Returns collections with Items property' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'Items'
        }

        It 'Items have correct structure' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].Items[0].PSObject.Properties.Name | Should -Contain 'RatingKey'
            $result[0].Items[0].PSObject.Properties.Name | Should -Contain 'Title'
            $result[0].Items[0].PSObject.Properties.Name | Should -Contain 'Type'
            $result[0].Items[0].PSObject.Properties.Name | Should -Contain 'Year'
        }

        It 'Items have correct PSTypeName' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].Items[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.CollectionItem'
        }
    }

    Context 'When no collections exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{ size = 0; Metadata = @() }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns empty collection' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Get-PatCollection -LibraryId 1
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Uses authentication headers from stored server' {
            Get-PatCollection -LibraryId 1
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Get-PatCollection -LibraryId 1 } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection refused'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws an error with context' {
            { Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400' } | Should -Throw '*Failed to retrieve collections*'
        }
    }

    Context 'When using LibraryName instead of LibraryId' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies' }
                        @{ key = '2'; title = 'TV Shows' }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Resolves LibraryName to LibraryId' {
            $result = Get-PatCollection -LibraryName 'Movies' -ServerUri 'http://plex.local:32400'
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary
        }

        It 'Throws when LibraryName not found' {
            { Get-PatCollection -LibraryName 'Nonexistent' -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No library found with name*"
        }

        It 'Sets LibraryName in output' {
            $result = Get-PatCollection -LibraryName 'Movies' -ServerUri 'http://plex.local:32400'
            $result[0].LibraryName | Should -Be 'Movies'
        }
    }

    Context 'When retrieving from all libraries' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies' }
                        @{ key = '2'; title = 'TV Shows' }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Retrieves collections from all libraries when no filter specified' {
            $result = Get-PatCollection -ServerUri 'http://plex.local:32400'
            # Should call for each library
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 2
        }

        It 'Gets library list first' {
            Get-PatCollection -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary
        }
    }

    Context 'When no libraries exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{ Directory = @() }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns empty when no libraries found' {
            $result = Get-PatCollection -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When collection by ID not found' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{ Metadata = $null }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns nothing when collection ID not found' {
            $result = Get-PatCollection -CollectionId 99999 -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When retrieving collection by ID with IncludeItems' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @{
                        librarySectionID = '1'
                        Metadata         = @(
                            @{
                                ratingKey  = '12345'
                                title      = 'Marvel Movies'
                                childCount = 10
                                thumb      = '/library/collections/12345/thumb'
                                addedAt    = 1703548800
                                updatedAt  = 1703635200
                            }
                        )
                    }
                }
                else {
                    return $script:mockCollectionItemsResponse
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies' }
                    )
                }
            }
        }

        BeforeEach {
            $script:callCount = 0
        }

        It 'Includes items when fetching by ID' {
            $result = Get-PatCollection -CollectionId 12345 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result.PSObject.Properties.Name | Should -Contain 'Items'
            $result.Items.Count | Should -Be 2
        }

        It 'Calls children endpoint for items' {
            Get-PatCollection -CollectionId 12345 -IncludeItems -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/collections/12345/children'
            }
        }

        It 'Resolves library name for collection' {
            $result = Get-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            $result.LibraryName | Should -Be 'Movies'
        }
    }

    Context 'When items retrieval fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Headers)
                if ($Uri -like '*/children') {
                    throw 'Failed to get items'
                }
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns empty items array when retrieval fails' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400' -WarningAction SilentlyContinue
            $result[0].Items | Should -Be @()
        }

        It 'Writes warning when items retrieval fails' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400' 3>&1
            $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When items have missing optional properties' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return $script:mockCollectionsResponse
                }
                else {
                    return @{
                        Metadata = @(
                            @{
                                ratingKey = '1001'
                                title     = 'Item Without Year'
                                type      = 'movie'
                                # No year, no addedAt
                            }
                        )
                    }
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        BeforeEach {
            $script:callCount = 0
        }

        It 'Handles items without year property' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].Items[0].Year | Should -BeNullOrEmpty
        }

        It 'Handles items without addedAt property' {
            $result = Get-PatCollection -LibraryId 1 -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].Items[0].AddedAt | Should -BeNullOrEmpty
        }
    }

    Context 'When collection has no addedAt or updatedAt' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey  = '12345'
                            title      = 'Test Collection'
                            childCount = 5
                            # No addedAt or updatedAt
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Handles missing timestamp properties' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result[0].AddedAt | Should -BeNullOrEmpty
            $result[0].UpdatedAt | Should -BeNullOrEmpty
        }
    }

    Context 'When using explicit Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Uses token in request headers' {
            Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-token'
            }
        }
    }

    Context 'When items retrieval fails for ById' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Headers)
                if ($Uri -like '*/children') {
                    throw 'Items API error'
                }
                return @{
                    librarySectionID = '1'
                    Metadata         = @(
                        @{
                            ratingKey  = '12345'
                            title      = 'Test Collection'
                            childCount = 5
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns empty items when retrieval fails for ById' {
            $result = Get-PatCollection -CollectionId 12345 -IncludeItems -ServerUri 'http://plex.local:32400' -WarningAction SilentlyContinue
            $result.Items | Should -Be @()
        }
    }

    Context 'When library has no collections' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Continues to next library when current has no collections' {
            $result = Get-PatCollection -LibraryId 1 -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using CollectionName with LibraryName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies' }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Finds collection by name in specified library' {
            $result = Get-PatCollection -CollectionName 'Marvel Movies' -LibraryName 'Movies' -ServerUri 'http://plex.local:32400'
            $result.Title | Should -Be 'Marvel Movies'
        }
    }
}
