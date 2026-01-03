BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatSectionNameCompletion' {
    Context 'Basic functionality' {
        It 'Returns matching section names' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                $results = Get-PatSectionNameCompletion -WordToComplete 'Mov'
                $results | Should -Not -BeNullOrEmpty
                $results.CompletionText | Should -Contain 'Movies'
            }
        }

        It 'Returns all sections when no prefix' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                        )
                    }
                }

                $results = Get-PatSectionNameCompletion -WordToComplete ''
                $results.Count | Should -Be 2
            }
        }

        It 'Returns empty when no matches' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }

                $results = Get-PatSectionNameCompletion -WordToComplete 'ZZZ'
                $results | Should -BeNullOrEmpty
            }
        }

        It 'Passes ServerUri to Get-PatLibrary' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                Get-PatSectionNameCompletion -WordToComplete '' -ServerUri 'http://custom:32400'

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token to Get-PatLibrary' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                Get-PatSectionNameCompletion -WordToComplete '' -Token 'my-token'

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }

        It 'Passes ServerUri and Token together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                Get-PatSectionNameCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -Token 'my-token'

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'Returns empty when Directory is null' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = $null }
                }

                $results = Get-PatSectionNameCompletion -WordToComplete ''
                $results | Should -BeNullOrEmpty
            }
        }

        It 'Handles Get-PatLibrary failure gracefully' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                $results = Get-PatSectionNameCompletion -WordToComplete ''

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for SectionName*'
                }
            }
        }
    }
}

Describe 'Get-PatSectionIdCompletion' {
    Context 'Basic functionality' {
        It 'Returns matching section IDs' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                            @{ key = '/library/sections/2'; title = 'TV Shows' }
                            @{ key = '/library/sections/12'; title = 'Music' }
                        )
                    }
                }

                $results = Get-PatSectionIdCompletion -WordToComplete '1'
                $results | Should -Not -BeNullOrEmpty
                $results.CompletionText | Should -Contain '1'
                $results.CompletionText | Should -Contain '12'
            }
        }

        It 'Returns all section IDs when no prefix' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                            @{ key = '/library/sections/2'; title = 'TV Shows' }
                        )
                    }
                }

                $results = Get-PatSectionIdCompletion -WordToComplete ''
                $results.Count | Should -Be 2
            }
        }

        It 'Passes ServerUri and Token together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ key = '/library/sections/1'; title = 'Movies' }) }
                }

                Get-PatSectionIdCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -Token 'my-token'

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'Handles Get-PatLibrary failure gracefully' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                $results = Get-PatSectionIdCompletion -WordToComplete ''

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for SectionId*'
                }
            }
        }
    }
}

Describe 'Get-PatLibraryPathCompletion' {
    Context 'Default server handling' {
        It 'Returns nothing when no default server exists' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { return $null }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 1
                $results | Should -BeNullOrEmpty
            }
        }

        It 'Returns nothing when Get-PatStoredServer throws' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { throw 'No server configured' }
                Mock Write-Debug { }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 1

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not retrieve default server*'
                }
            }
        }

        It 'Skips default server check when ServerUri is provided' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { throw 'Should not be called' }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -SectionId 1

                Should -Not -Invoke Get-PatStoredServer
                $results | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Section ID resolution' {
        It 'Uses SectionId directly when provided' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 2

                Should -Invoke Get-PatLibraryPath -ParameterFilter {
                    $SectionId -eq 2
                }
            }
        }

        It 'Resolves SectionId from SectionName' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/5'; title = 'Movies' }
                        )
                    }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionName 'Movies'

                Should -Invoke Get-PatLibraryPath -ParameterFilter {
                    $SectionId -eq 5
                }
            }
        }

        It 'Returns nothing when SectionName resolution fails' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionName 'Movies'

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not resolve section name to ID*'
                }
            }
        }

        It 'Returns nothing when neither SectionId nor SectionName provided' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete ''
                $results | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Root path completion' {
        It 'Returns root paths when no input' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                        [PSCustomObject]@{ path = '/mnt/tv' }
                    )
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 1

                $results.Count | Should -Be 2
                $results.CompletionText | Should -Contain '/mnt/movies'
                $results.CompletionText | Should -Contain '/mnt/tv'
            }
        }

        It 'Handles empty root paths' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @()
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 1
                $results | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Path browsing' {
        It 'Browses subdirectories when path matches root exactly' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }
                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                    )
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '/mnt/movies' -SectionId 1

                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $Path -eq '/mnt/movies'
                }
                $results.Count | Should -Be 2
            }
        }

        It 'Filters items by prefix when browsing' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }
                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                        [PSCustomObject]@{ path = '/mnt/movies/Drama' }
                    )
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '/mnt/movies/A' -SectionId 1

                $results.Count | Should -Be 1
                $results.CompletionText | Should -Contain '/mnt/movies/Action'
            }
        }

        It 'Falls back to matching root paths when browsing fails' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                        [PSCustomObject]@{ path = '/mnt/music' }
                    )
                }
                Mock Get-PatLibraryChildItem { throw 'Browse failed' }
                Mock Write-Debug { }

                $results = Get-PatLibraryPathCompletion -WordToComplete '/mnt/m' -SectionId 1

                $results.Count | Should -Be 2
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not browse path*'
                }
            }
        }

        It 'Passes ServerUri to Get-PatLibraryPath when not using default' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }

                Get-PatLibraryPathCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -SectionId 1

                Should -Invoke Get-PatLibraryPath -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes ServerUri to Get-PatLibraryChildItem when not using default' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }
                Mock Get-PatLibraryChildItem {
                    return @([PSCustomObject]@{ path = '/mnt/movies/Action' })
                }

                Get-PatLibraryPathCompletion -WordToComplete '/mnt/movies' -ServerUri 'http://custom:32400' -SectionId 1

                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Handles Get-PatLibraryPath failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath { throw 'Library path failed' }
                Mock Write-Debug { }

                $results = Get-PatLibraryPathCompletion -WordToComplete '' -SectionId 1

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not retrieve library paths*'
                }
            }
        }
    }

    Context 'Path extraction edge cases' {
        It 'Handles Windows absolute path' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = 'C:\Movies' })
                }
                Mock Get-PatLibraryChildItem {
                    return @([PSCustomObject]@{ path = 'C:\Movies\Action' })
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete 'C:\Movies\A' -SectionId 1

                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $Path -eq 'C:\Movies'
                }
            }
        }

        It 'Handles items with Path property (uppercase)' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @([PSCustomObject]@{ path = '/mnt/movies' })
                }
                Mock Get-PatLibraryChildItem {
                    return @([PSCustomObject]@{ Path = '/mnt/movies/Action' })  # Uppercase Path
                }

                $results = Get-PatLibraryPathCompletion -WordToComplete '/mnt/movies' -SectionId 1

                $results | Should -Not -BeNullOrEmpty
                $results.CompletionText | Should -Contain '/mnt/movies/Action'
            }
        }
    }
}

Describe 'Get-PatCollectionTitleCompletion' {
    Context 'Basic functionality' {
        It 'Returns matching collection titles' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ title = 'Marvel Movies' }
                        [PSCustomObject]@{ title = 'DC Movies' }
                        [PSCustomObject]@{ title = 'Horror Classics' }
                    )
                }

                $results = Get-PatCollectionTitleCompletion -WordToComplete 'Mar'
                $results | Should -Not -BeNullOrEmpty
                $results.CompletionText | Should -Contain "'Marvel Movies'"
            }
        }

        It 'Returns all collections when no prefix' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ title = 'Marvel Movies' }
                        [PSCustomObject]@{ title = 'DC Movies' }
                    )
                }

                $results = Get-PatCollectionTitleCompletion -WordToComplete ''
                $results.Count | Should -Be 2
            }
        }

        It 'Passes ServerUri and Token to Get-PatCollection' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @([PSCustomObject]@{ title = 'Marvel Movies' })
                }

                Get-PatCollectionTitleCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -Token 'my-token'

                Should -Invoke Get-PatCollection -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'Handles empty collections' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @()
                }

                $results = Get-PatCollectionTitleCompletion -WordToComplete ''
                $results | Should -BeNullOrEmpty
            }
        }

        It 'Handles Get-PatCollection failure gracefully' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection { throw 'Connection failed' }
                Mock Write-Debug { }

                $results = Get-PatCollectionTitleCompletion -WordToComplete ''

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for Title*'
                }
            }
        }
    }
}

Describe 'Get-PatPlaylistTitleCompletion' {
    Context 'Basic functionality' {
        It 'Returns matching playlist titles' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ title = 'My Favorites' }
                        [PSCustomObject]@{ title = 'Party Mix' }
                    )
                }

                $results = Get-PatPlaylistTitleCompletion -WordToComplete 'My'
                $results | Should -Not -BeNullOrEmpty
                $results.CompletionText | Should -Contain "'My Favorites'"
            }
        }

        It 'Returns all playlists when no prefix' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ title = 'My Favorites' }
                        [PSCustomObject]@{ title = 'Party Mix' }
                    )
                }

                $results = Get-PatPlaylistTitleCompletion -WordToComplete ''
                $results.Count | Should -Be 2
            }
        }

        It 'Passes ServerUri and Token to Get-PatPlaylist' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @([PSCustomObject]@{ title = 'My Favorites' })
                }

                Get-PatPlaylistTitleCompletion -WordToComplete '' -ServerUri 'http://custom:32400' -Token 'my-token'

                Should -Invoke Get-PatPlaylist -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'Handles empty playlists' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @()
                }

                $results = Get-PatPlaylistTitleCompletion -WordToComplete ''
                $results | Should -BeNullOrEmpty
            }
        }

        It 'Handles Get-PatPlaylist failure gracefully' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist { throw 'Connection failed' }
                Mock Write-Debug { }

                $results = Get-PatPlaylistTitleCompletion -WordToComplete ''

                $results | Should -BeNullOrEmpty
                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for Title*'
                }
            }
        }
    }
}
