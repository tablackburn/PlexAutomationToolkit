BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Add-PatPlaylistItem' {

    BeforeAll {
        # Mock playlist response
        $script:mockPlaylist = [PSCustomObject]@{
            PSTypeName  = 'PlexAutomationToolkit.Playlist'
            PlaylistId  = 12345
            Title       = 'Test Playlist'
            Type        = 'video'
            ItemCount   = 5
            Duration    = 18000000
            Smart       = $false
            ServerUri   = 'http://plex.local:32400'
        }

        # Mock updated playlist response
        $script:mockUpdatedPlaylist = [PSCustomObject]@{
            PSTypeName  = 'PlexAutomationToolkit.Playlist'
            PlaylistId  = 12345
            Title       = 'Test Playlist'
            Type        = 'video'
            ItemCount   = 7
            Duration    = 26000000
            Smart       = $false
            ServerUri   = 'http://plex.local:32400'
        }

        # Mock server info response
        $script:mockServerInfo = @{
            machineIdentifier = 'abc123-machine-id'
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When adding items to playlist by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                param($PlaylistId)
                if ($PlaylistId) {
                    return $script:mockUpdatedPlaylist
                }
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Adds items to the playlist' {
            { Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111, 222 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls PUT on the playlist items endpoint' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Calls the correct endpoint' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345/items'
            }
        }

        It 'Includes uri parameter in query string' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'uri='
            }
        }

        It 'Returns nothing when PassThru not specified' {
            $result = Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated playlist when PassThru specified' {
            $result = Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.ItemCount | Should -Be 7
        }
    }

    Context 'When adding items to playlist by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                param($PlaylistName, $PlaylistId)
                if ($PlaylistName) {
                    return $script:mockPlaylist
                }
                return $script:mockUpdatedPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Resolves playlist name to ID' {
            Add-PatPlaylistItem -PlaylistName 'Test Playlist' -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                $PlaylistName -eq 'Test Playlist'
            }
        }
    }

    Context 'When playlist does not exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws when playlist name not found' {
            { Add-PatPlaylistItem -PlaylistName 'Nonexistent' -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No playlist found*"
        }
    }

    Context 'Pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Accepts RatingKey from pipeline' {
            { 111, 222, 333 | Add-PatPlaylistItem -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Collects all pipeline items before adding' {
            111, 222, 333 | Add-PatPlaylistItem -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            # Should only call PUT once with all items
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 1 -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
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
            { Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -Confirm:$false } |
                Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    throw 'Add failed'
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws an error with context' {
            { Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to add items*'
        }
    }

    Context 'ShouldProcess behavior' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Supports WhatIf' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }

    Context 'When machine identifier retrieval fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection failed'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws error with machine identifier context' {
            { Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to retrieve server machine identifier*'
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

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Token 'my-token' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'When playlist info lookup fails for ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                throw 'Playlist not found'
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'PUT') {
                    return $null
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Still adds items when playlist lookup fails' {
            Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Uses fallback description without playlist info' {
            { Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }
    }

    Context 'When no rating keys provided in pipeline' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Returns early when no rating keys after pipeline' {
            # This tests the "nothing to add" path
            @() | Add-PatPlaylistItem -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }
}
