BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatPlaylist' {

    BeforeAll {
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

        $script:mockServerContext = [PSCustomObject]@{
            Uri            = 'http://plex.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            WasExplicitUri = $true
            Server         = $null
            Token          = 'test-token'
        }

        $script:mockDefaultServerContext = [PSCustomObject]@{
            Uri            = 'http://plex-default.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'default-token' }
            WasExplicitUri = $false
            Server         = @{ name = 'Default'; uri = 'http://plex-default.local:32400' }
            Token          = $null
        }
    }

    Context 'Function definition' {
        It 'Should exist as a public function' {
            Get-Command Remove-PatPlaylist -Module PlexAutomationToolkit | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess' {
            $cmd = Get-Command Remove-PatPlaylist -Module PlexAutomationToolkit
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It 'Should have High ConfirmImpact' {
            $cmd = Get-Command Remove-PatPlaylist -Module PlexAutomationToolkit
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.ConfirmImpact | Should -Be 'High'
        }

        It 'Should have ById as default parameter set' {
            $cmd = Get-Command Remove-PatPlaylist -Module PlexAutomationToolkit
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.DefaultParameterSetName | Should -Be 'ById'
        }
    }

    Context 'When removing playlist by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
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
        }

        It 'Removes the playlist' {
            { Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls Resolve-PatServerContext with ServerUri' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $ServerUri -eq 'http://plex.local:32400'
            }
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

        It 'Passes Token to Resolve-PatServerContext' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Token 'my-token' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
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

        It 'Retrieves playlist info for confirmation message' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -Times 1
        }
    }

    Context 'When playlist info cannot be retrieved for ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                throw 'Playlist not found'
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Still attempts to delete the playlist' {
            Remove-PatPlaylist -PlaylistId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Does not return anything with PassThru when playlist info unavailable' {
            $result = Remove-PatPlaylist -PlaylistId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When removing playlist by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                param($PlaylistName, $PlaylistId)
                if ($PlaylistName -eq 'Test Playlist') {
                    return $script:mockPlaylist
                }
                return $null
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

        It 'Returns playlist with PassThru' {
            $result = Remove-PatPlaylist -PlaylistName 'Test Playlist' -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result.Title | Should -Be 'Test Playlist'
        }
    }

    Context 'When playlist does not exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return $null
            }
        }

        It 'Throws when playlist name not found' {
            { Remove-PatPlaylist -PlaylistName 'Nonexistent' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No playlist found with name 'Nonexistent'*"
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockDefaultServerContext
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
        }

        It 'Uses default server when ServerUri not specified' {
            Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                -not $ServerUri
            }
        }

        It 'Uses URI from server context' {
            Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-default.local:32400'
            }
        }

        It 'Does not pass ServerUri to Get-PatPlaylist when using default' {
            Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('ServerUri')
            }
        }
    }

    Context 'When server resolution fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                throw 'No default server configured. Use Add-PatServer with -Default or specify -ServerUri.'
            }
        }

        It 'Throws an error indicating no default server' {
            { Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false } |
                Should -Throw '*No default server configured*'
        }

        It 'Wraps error with context' {
            { Remove-PatPlaylist -PlaylistId 12345 -Confirm:$false } |
                Should -Throw '*Failed to resolve server*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

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
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
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
        }

        It 'Supports WhatIf' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Still resolves server context with WhatIf' {
            Remove-PatPlaylist -PlaylistId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -Times 1
        }
    }

    Context 'Pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
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
        }

        It 'Accepts PlaylistId from pipeline' {
            { $script:mockPlaylist | Remove-PatPlaylist -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Accepts integer PlaylistId from pipeline' {
            { 12345 | Remove-PatPlaylist -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Processes multiple playlists from pipeline' {
            @(
                [PSCustomObject]@{ PlaylistId = 111 }
                [PSCustomObject]@{ PlaylistId = 222 }
                [PSCustomObject]@{ PlaylistId = 333 }
            ) | Remove-PatPlaylist -ServerUri 'http://plex.local:32400' -Confirm:$false

            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 3 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }

    Context 'Parameter validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }
        }

        It 'Rejects PlaylistId of 0' {
            { Remove-PatPlaylist -PlaylistId 0 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects negative PlaylistId' {
            { Remove-PatPlaylist -PlaylistId -1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects empty PlaylistName' {
            { Remove-PatPlaylist -PlaylistName '' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }
    }

    Context 'PlaylistName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Remove-PatPlaylist
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
                & $completer 'Remove-PatPlaylist' 'PlaylistName' 'My' $null @{}
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
                & $completer 'Remove-PatPlaylist' 'PlaylistName' '' $null @{ ServerUri = 'http://custom:32400' }
            }
            Should -Invoke Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://custom:32400'
            }
        }
    }
}
