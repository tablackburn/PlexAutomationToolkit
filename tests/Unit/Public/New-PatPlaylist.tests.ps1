BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'New-PatPlaylist' {

    BeforeAll {
        # Mock created playlist response
        $script:mockCreatedPlaylist = @{
            Metadata = @(
                @{
                    ratingKey    = '99999'
                    title        = 'Test Playlist'
                    playlistType = 'video'
                    leafCount    = 0
                    duration     = 0
                    smart        = '0'
                    addedAt      = 1703635200
                    updatedAt    = 1703635200
                }
            )
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

    Context 'When creating a new playlist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return $script:mockCreatedPlaylist
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

        It 'Creates a playlist with the specified title' {
            { New-PatPlaylist -Title 'My New Playlist' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls the playlists endpoint with POST method' {
            New-PatPlaylist -Title 'My New Playlist' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'Returns created playlist when PassThru is specified' {
            $result = New-PatPlaylist -Title 'Test Playlist' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.Title | Should -Be 'Test Playlist'
            $result.PlaylistId | Should -Be 99999
        }

        It 'Returns nothing when PassThru is not specified' {
            $result = New-PatPlaylist -Title 'Test Playlist' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When creating playlist with specific type' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return $script:mockCreatedPlaylist
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

        It 'Accepts video type' {
            { New-PatPlaylist -Title 'Video Playlist' -Type 'video' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Accepts audio type' {
            { New-PatPlaylist -Title 'Audio Playlist' -Type 'audio' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Accepts photo type' {
            { New-PatPlaylist -Title 'Photo Playlist' -Type 'photo' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Defaults to video type' {
            New-PatPlaylist -Title 'Default Type' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'type=video'
            }
        }
    }

    Context 'When creating playlist with initial items' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return $script:mockCreatedPlaylist
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

        It 'Includes URI parameter when rating keys provided' {
            New-PatPlaylist -Title 'With Items' -RatingKey 123, 456 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'uri='
            }
        }

        It 'Accepts rating keys from pipeline' {
            { 123, 456, 789 | New-PatPlaylist -Title 'Pipeline Test' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return $script:mockCreatedPlaylist
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

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeaders {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            New-PatPlaylist -Title 'Default Server Test' -RatingKey 12345 -Confirm:$false
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
            { New-PatPlaylist -Title 'No Server' -RatingKey 12345 -Confirm:$false } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    throw 'Playlist creation failed'
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
            { New-PatPlaylist -Title 'Fail Test' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*Failed to create playlist*"
        }
    }

    Context 'ShouldProcess behavior' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return $script:mockCreatedPlaylist
                }
                return $script:mockServerInfo
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Supports WhatIf' {
            New-PatPlaylist -Title 'WhatIf Test' -RatingKey 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 1 -ParameterFilter {
                $Method -ne 'POST'
            }
        }
    }
}
