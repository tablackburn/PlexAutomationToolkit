BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatPlaylistItem' {

    BeforeAll {
        # Mock playlist with items
        $script:mockPlaylistWithItems = [PSCustomObject]@{
            PSTypeName  = 'PlexAutomationToolkit.Playlist'
            PlaylistId  = 12345
            Title       = 'Test Playlist'
            Type        = 'video'
            ItemCount   = 5
            Duration    = 18000000
            Smart       = $false
            ServerUri   = 'http://plex.local:32400'
            Items       = @(
                [PSCustomObject]@{
                    PSTypeName     = 'PlexAutomationToolkit.PlaylistItem'
                    PlaylistItemId = 111
                    RatingKey      = 1001
                    Title          = 'The Matrix'
                    Type           = 'movie'
                    PlaylistId     = 12345
                    ServerUri      = 'http://plex.local:32400'
                }
                [PSCustomObject]@{
                    PSTypeName     = 'PlexAutomationToolkit.PlaylistItem'
                    PlaylistItemId = 222
                    RatingKey      = 1002
                    Title          = 'Inception'
                    Type           = 'movie'
                    PlaylistId     = 12345
                    ServerUri      = 'http://plex.local:32400'
                }
            )
        }

        # Mock updated playlist
        $script:mockUpdatedPlaylist = [PSCustomObject]@{
            PSTypeName  = 'PlexAutomationToolkit.Playlist'
            PlaylistId  = 12345
            Title       = 'Test Playlist'
            Type        = 'video'
            ItemCount   = 4
            Duration    = 10000000
            Smart       = $false
            ServerUri   = 'http://plex.local:32400'
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When removing item from playlist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                param($PlaylistId, $IncludeItems)
                if ($IncludeItems) {
                    return $script:mockPlaylistWithItems
                }
                return $script:mockUpdatedPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Removes the item from the playlist' {
            { Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls DELETE on the playlist item endpoint' {
            Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Calls the correct endpoint' {
            Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345/items/111'
            }
        }

        It 'Returns nothing when PassThru not specified' {
            $result = Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated playlist when PassThru specified' {
            $result = Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.ItemCount | Should -Be 4
        }
    }

    Context 'Pipeline input from playlist items' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                param($PlaylistId, $IncludeItems)
                if ($IncludeItems) {
                    return $script:mockPlaylistWithItems
                }
                return $script:mockUpdatedPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Accepts playlist item objects from pipeline' {
            { $script:mockPlaylistWithItems.Items[0] | Remove-PatPlaylistItem -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Extracts PlaylistId and PlaylistItemId from pipeline object' {
            $script:mockPlaylistWithItems.Items[0] | Remove-PatPlaylistItem -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345/items/111'
            }
        }

        It 'Processes multiple items from pipeline' {
            $script:mockPlaylistWithItems.Items | Remove-PatPlaylistItem -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 2 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylistWithItems
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
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
            Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -Confirm:$false } |
                Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylistWithItems
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Deletion failed'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws an error with context' {
            { Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to remove item*'
        }
    }

    Context 'ShouldProcess behavior' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylistWithItems
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Supports WhatIf' {
            Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 111 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }
}
