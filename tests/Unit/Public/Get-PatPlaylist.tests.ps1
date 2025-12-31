BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatPlaylist' {

    BeforeAll {
        # Mock playlists response matching Plex API structure
        $script:mockPlaylistsResponse = @{
            size     = 2
            Metadata = @(
                @{
                    ratingKey    = '12345'
                    title        = 'My Favorites'
                    playlistType = 'video'
                    leafCount    = 10
                    duration     = 36000000
                    smart        = '0'
                    composite    = '/playlists/12345/composite/1234567890'
                    addedAt      = 1703548800
                    updatedAt    = 1703635200
                }
                @{
                    ratingKey    = '67890'
                    title        = 'Watch Later'
                    playlistType = 'video'
                    leafCount    = 5
                    duration     = 18000000
                    smart        = '0'
                    composite    = '/playlists/67890/composite/1234567891'
                    addedAt      = 1703462400
                    updatedAt    = 1703548800
                }
            )
        }

        $script:mockPlaylistItemsResponse = @{
            size     = 2
            Metadata = @(
                @{
                    playlistItemID = '111'
                    ratingKey      = '1001'
                    title          = 'The Matrix'
                    type           = 'movie'
                    duration       = 8160000
                    addedAt        = 1703548800
                }
                @{
                    playlistItemID = '222'
                    ratingKey      = '1002'
                    title          = 'Inception'
                    type           = 'movie'
                    duration       = 8880000
                    addedAt        = 1703548900
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When retrieving all playlists' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockPlaylistsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns all playlists' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result.Count | Should -Be 2
        }

        It 'Calls the playlists endpoint' {
            Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists'
            }
        }

        It 'Returns properly structured playlist objects' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'PlaylistId'
            $result[0].PSObject.Properties.Name | Should -Contain 'Title'
            $result[0].PSObject.Properties.Name | Should -Contain 'Type'
            $result[0].PSObject.Properties.Name | Should -Contain 'ItemCount'
        }

        It 'Maps API properties correctly' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result[0].PlaylistId | Should -Be 12345
            $result[0].Title | Should -Be 'My Favorites'
            $result[0].Type | Should -Be 'video'
            $result[0].ItemCount | Should -Be 10
            $result[0].Smart | Should -Be $false
        }

        It 'Has correct PSTypeName' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Playlist'
        }

        It 'Includes ServerUri in output' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result[0].ServerUri | Should -Be 'http://plex.local:32400'
        }
    }

    Context 'When retrieving playlist by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey    = '12345'
                            title        = 'My Favorites'
                            playlistType = 'video'
                            leafCount    = 10
                            duration     = 36000000
                            smart        = '0'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns specific playlist' {
            $result = Get-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400'
            $result.PlaylistId | Should -Be 12345
            $result.Title | Should -Be 'My Favorites'
        }

        It 'Calls the specific playlist endpoint' {
            Get-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345'
            }
        }
    }

    Context 'When retrieving playlist by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockPlaylistsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns playlist matching the name' {
            $result = Get-PatPlaylist -PlaylistName 'My Favorites' -ServerUri 'http://plex.local:32400'
            $result.Title | Should -Be 'My Favorites'
        }

        It 'Throws when playlist name not found' {
            { Get-PatPlaylist -PlaylistName 'Nonexistent' -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No playlist found with name*"
        }
    }

    Context 'When including items' {
        BeforeAll {
            $callCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $callCount++
                if ($callCount -eq 1) {
                    return $script:mockPlaylistsResponse
                }
                else {
                    return $script:mockPlaylistItemsResponse
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns playlists with Items property' {
            $result = Get-PatPlaylist -IncludeItems -ServerUri 'http://plex.local:32400'
            $result[0].PSObject.Properties.Name | Should -Contain 'Items'
        }
    }

    Context 'When filtering out smart playlists' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    size     = 2
                    Metadata = @(
                        @{
                            ratingKey    = '12345'
                            title        = 'Dumb Playlist'
                            playlistType = 'video'
                            smart        = '0'
                        }
                        @{
                            ratingKey    = '67890'
                            title        = 'Smart Playlist'
                            playlistType = 'video'
                            smart        = '1'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Only returns non-smart playlists' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result.Count | Should -Be 1
            $result[0].Title | Should -Be 'Dumb Playlist'
        }
    }

    Context 'When no playlists exist' {
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
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockPlaylistsResponse
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
            Get-PatPlaylist
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Uses authentication headers from stored server' {
            Get-PatPlaylist
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
            { Get-PatPlaylist } | Should -Throw '*No default server configured*'
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
            { Get-PatPlaylist -ServerUri 'http://plex.local:32400' } | Should -Throw '*Failed to retrieve playlists*'
        }
    }

    Context 'When API returns null' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns nothing when API returns null' {
            $result = Get-PatPlaylist -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When fetching items fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -like '*/items') {
                    throw 'Items retrieval failed'
                }
                return @{
                    Metadata = @(
                        @{
                            ratingKey    = '12345'
                            title        = 'Test Playlist'
                            playlistType = 'video'
                            leafCount    = 5
                            duration     = 18000000
                            smart        = '0'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Emits warning when items retrieval fails' {
            $result = Get-PatPlaylist -IncludeItems -ServerUri 'http://plex.local:32400' 3>&1
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Returns playlist with empty Items array on failure' {
            $result = Get-PatPlaylist -IncludeItems -ServerUri 'http://plex.local:32400'
            $result.Items | Should -BeNullOrEmpty
        }
    }

    Context 'PlaylistName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Get-PatPlaylist
            $playlistNameParam = $command.Parameters['PlaylistName']
            $script:playlistNameCompleter = $playlistNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching playlist names' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:playlistNameCompleter } {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ Title = 'My Favorites' }
                        [PSCustomObject]@{ Title = 'Party Mix' }
                    )
                }
                & $completer 'Get-PatPlaylist' 'PlaylistName' 'My' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:playlistNameCompleter } {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ Title = 'My Favorites' }
                    )
                }
                & $completer 'Get-PatPlaylist' 'PlaylistName' '' $null @{ ServerUri = 'http://custom:32400' }
            }
            Should -Invoke Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://custom:32400'
            }
        }

        It 'Passes Token when provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:playlistNameCompleter } {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ Title = 'My Favorites' }
                    )
                }
                & $completer 'Get-PatPlaylist' 'PlaylistName' '' $null @{ Token = 'my-token' }
            }
            Should -Invoke Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]@{
                    Uri            = 'http://plex.local:32400'
                    Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'my-token' }
                    WasExplicitUri = $true
                    Server         = $null
                    Token          = 'my-token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockPlaylistsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            Get-PatPlaylist -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }
}
