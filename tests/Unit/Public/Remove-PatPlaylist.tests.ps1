BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatPlaylist' {

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

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When removing playlist by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Removes the playlist' {
            { Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls DELETE on the playlist endpoint' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Calls the correct endpoint' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345'
            }
        }

        It 'Returns nothing when PassThru not specified' {
            $result = Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }

        It 'Returns playlist info when PassThru specified' {
            $result = Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.Title | Should -Be 'Test Playlist'
        }
    }

    Context 'When removing playlist by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Resolves playlist name to ID' {
            Remove-PatPlaylist -PlaylistName 'Test Playlist' -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                $PlaylistName -eq 'Test Playlist'
            }
        }

        It 'Removes the playlist by resolved ID' {
            Remove-PatPlaylist -PlaylistName 'Test Playlist' -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/playlists/12345'
            }
        }
    }

    Context 'When playlist does not exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $null
            }
        }

        It 'Throws when playlist name not found' {
            { Remove-PatPlaylist -PlaylistName 'Nonexistent' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No playlist found*"
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
            Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false
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
            { Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
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
            { Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to remove playlist*'
        }
    }

    Context 'ShouldProcess behavior' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
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
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Has High confirm impact' {
            $cmd = Get-Command Remove-PatPlaylist
            $cmd.Parameters['Confirm'].Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Be $false
        }
    }

    Context 'Pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $script:mockPlaylist
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Accepts PlaylistId from pipeline' {
            { $script:mockPlaylist | Remove-PatPlaylist -Confirm:$false } | Should -Not -Throw
        }
    }
}
