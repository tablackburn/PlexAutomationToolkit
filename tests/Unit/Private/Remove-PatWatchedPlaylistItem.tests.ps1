BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:RemovePatWatchedPlaylistItem = & (Get-Module PlexAutomationToolkit) { Get-Command Remove-PatWatchedPlaylistItem }
}

Describe 'Remove-PatWatchedPlaylistItem' {
    Context 'Basic removal' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Watched Movie'
                            Type           = 'movie'
                            Year           = 2020
                        },
                        [PSCustomObject]@{
                            RatingKey      = 1002
                            PlaylistItemId = 5002
                            Title          = 'Unwatched Movie'
                            Type           = 'movie'
                            Year           = 2021
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Removes watched items from playlist' {
            $watchDiffs = @(
                [PSCustomObject]@{
                    Title           = 'Watched Movie'
                    TargetRatingKey = 1001
                }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Returns count of removed items' {
            $watchDiffs = @(
                [PSCustomObject]@{
                    Title           = 'Watched Movie'
                    TargetRatingKey = 1001
                }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            $result | Should -Be 1
        }

        It 'Passes correct PlaylistId and PlaylistItemId to Remove-PatPlaylistItem' {
            $watchDiffs = @(
                [PSCustomObject]@{
                    Title           = 'Watched Movie'
                    TargetRatingKey = 1001
                }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -ParameterFilter {
                $PlaylistId -eq 100 -and $PlaylistItemId -eq 5001
            }
        }
    }

    Context 'Multiple items removal' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Movie One'
                            Type           = 'movie'
                            Year           = 2020
                        },
                        [PSCustomObject]@{
                            RatingKey      = 1002
                            PlaylistItemId = 5002
                            Title          = 'Movie Two'
                            Type           = 'movie'
                            Year           = 2021
                        },
                        [PSCustomObject]@{
                            RatingKey      = 1003
                            PlaylistItemId = 5003
                            Title          = 'Movie Three'
                            Type           = 'movie'
                            Year           = 2022
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Removes multiple watched items' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie One'; TargetRatingKey = 1001 },
                [PSCustomObject]@{ Title = 'Movie Three'; TargetRatingKey = 1003 }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 2
            $result | Should -Be 2
        }

        It 'Only removes items that exist in playlist' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie One'; TargetRatingKey = 1001 },
                [PSCustomObject]@{ Title = 'Not In Playlist'; TargetRatingKey = 9999 }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 1
            $result | Should -Be 1
        }
    }

    Context 'No matching items' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Movie'
                            Type           = 'movie'
                            Year           = 2020
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Returns 0 when no items match' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Different Movie'; TargetRatingKey = 9999 }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            $result | Should -Be 0
            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Returns 0 when watch diffs is empty' {
            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff @() -PlaylistName 'Travel'

            $result | Should -Be 0
            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Empty playlist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Empty Playlist'
                    PlaylistId = 100
                    Items      = @()
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Returns 0 for empty playlist' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Empty Playlist'

            $result | Should -Be 0
            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Movie One'
                            Type           = 'movie'
                            Year           = 2020
                        },
                        [PSCustomObject]@{
                            RatingKey      = 1002
                            PlaylistItemId = 5002
                            Title          = 'Movie Two'
                            Type           = 'movie'
                            Year           = 2021
                        }
                    )
                }
            }
        }

        It 'Continues after removal failure' {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw "API Error"
                }
            }

            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie One'; TargetRatingKey = 1001 },
                [PSCustomObject]@{ Title = 'Movie Two'; TargetRatingKey = 1002 }
            )

            $script:callCount = 0
            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' 3>&1

            # Both removals should be attempted
            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Returns count of successful removals' {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw "API Error"
                }
            }

            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie One'; TargetRatingKey = 1001 },
                [PSCustomObject]@{ Title = 'Movie Two'; TargetRatingKey = 1002 }
            )

            $script:callCount = 0
            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' 3>&1 |
                Where-Object { $_ -is [int] }

            # Only second removal succeeded
            $result | Should -Be 1
        }

        It 'Warns when Get-PatPlaylist fails' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                throw "404 Not Found"
            }

            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            $output = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'NotFound' 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -Match 'Failed to get playlist'
        }

        It 'Returns 0 when Get-PatPlaylist fails' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                throw "404 Not Found"
            }

            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'NotFound' 3>&1 |
                Where-Object { $_ -is [int] }

            $result | Should -Be 0
        }
    }

    Context 'Playlist identification' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Movie'
                            Type           = 'movie'
                            Year           = 2020
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Accepts PlaylistId parameter' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistId 100

            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $PlaylistId -eq 100
            }
        }

        It 'Accepts PlaylistName parameter' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $PlaylistName -eq 'Travel'
            }
        }

        It 'Warns when neither PlaylistId nor PlaylistName provided' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            $output = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings | Should -Match 'PlaylistId or PlaylistName must be specified'
        }
    }

    Context 'Server connection parameters' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey      = 1001
                            PlaylistItemId = 5001
                            Title          = 'Movie'
                            Type           = 'movie'
                            Year           = 2020
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Passes ServerName to Get-PatPlaylist' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' -ServerName 'HomeServer'

            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerName -eq 'HomeServer'
            }
        }

        It 'Passes ServerUri and Token to Get-PatPlaylist' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://plex:32400' -and $Token -eq 'test-token'
            }
        }

        It 'Prefers ServerName over ServerUri' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' `
                -ServerName 'HomeServer' -ServerUri 'http://plex:32400'

            Should -Invoke -CommandName Get-PatPlaylist -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerName -eq 'HomeServer' -and -not $ServerUri
            }
        }

        It 'Passes ServerName to Remove-PatPlaylistItem' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' -ServerName 'HomeServer'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerName -eq 'HomeServer'
            }
        }

        It 'Passes ServerUri and Token to Remove-PatPlaylistItem' {
            $watchDiffs = @(
                [PSCustomObject]@{ Title = 'Movie'; TargetRatingKey = 1001 }
            )

            & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel' `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://plex:32400' -and $Token -eq 'test-token'
            }
        }
    }

    Context 'Episode handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    Title      = 'Travel'
                    PlaylistId = 100
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey        = 2001
                            PlaylistItemId   = 6001
                            Title            = 'Pilot'
                            Type             = 'episode'
                            GrandparentTitle = 'Breaking Bad'
                            ParentIndex      = 1
                            Index            = 1
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Remove-PatPlaylistItem { }
        }

        It 'Removes episode items from playlist' {
            $watchDiffs = @(
                [PSCustomObject]@{
                    Title           = 'Pilot'
                    Type            = 'episode'
                    TargetRatingKey = 2001
                }
            )

            $result = & $script:RemovePatWatchedPlaylistItem -WatchDiff $watchDiffs -PlaylistName 'Travel'

            $result | Should -Be 1
            Should -Invoke -CommandName Remove-PatPlaylistItem -ModuleName PlexAutomationToolkit -ParameterFilter {
                $PlaylistItemId -eq 6001
            }
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory WatchDiff parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Remove-PatWatchedPlaylistItem }
            $parameter = $command.Parameters['WatchDiff']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Allows empty collection for WatchDiff' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Remove-PatWatchedPlaylistItem }
            $parameter = $command.Parameters['WatchDiff']

            $allowEmpty = $parameter.Attributes | Where-Object { $_.TypeId.Name -eq 'AllowEmptyCollectionAttribute' }
            $allowEmpty | Should -Not -BeNullOrEmpty
        }

        It 'Returns int type' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Remove-PatWatchedPlaylistItem }
            $outputType = $command.OutputType

            $outputType.Type.Name | Should -Contain 'Int32'
        }
    }
}
