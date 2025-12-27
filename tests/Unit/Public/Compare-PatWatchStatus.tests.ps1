BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Compare-PatWatchStatus' {
    BeforeAll {
        Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
            param($Name)

            if ($Name -eq 'Source') {
                return [PSCustomObject]@{
                    name  = 'Source'
                    uri   = 'http://source.test:32400'
                    token = 'source-token'
                }
            }
            elseif ($Name -eq 'Target') {
                return [PSCustomObject]@{
                    name  = 'Target'
                    uri   = 'http://target.test:32400'
                    token = 'target-token'
                }
            }
            return $null
        }

        Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeaders {
            return @{
                Accept         = 'application/json'
                'X-Plex-Token' = 'test-token'
            }
        }
    }

    Context 'Movie watch status comparison' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                param($ServerUri)

                return @{
                    Directory = @(
                        @{
                            key   = '/library/sections/1'
                            title = 'Movies'
                            type  = 'movie'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryItem {
                param($SectionId, $ServerUri)

                if ($ServerUri -match 'source') {
                    return @(
                        @{
                            ratingKey = 1001
                            title     = 'The Matrix'
                            year      = 1999
                            viewCount = 5  # Watched on source
                        },
                        @{
                            ratingKey = 1002
                            title     = 'Inception'
                            year      = 2010
                            viewCount = 0  # Not watched on source
                        }
                    )
                }
                else {
                    return @(
                        @{
                            ratingKey = 2001
                            title     = 'The Matrix'
                            year      = 1999
                            viewCount = 0  # Not watched on target
                        },
                        @{
                            ratingKey = 2002
                            title     = 'Inception'
                            year      = 2010
                            viewCount = 2  # Watched on target
                        }
                    )
                }
            }
        }

        It 'Returns differences in watch status' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $result | Should -HaveCount 2
        }

        It 'Identifies movies watched on source but not target' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $matrix = $result | Where-Object { $_.Title -eq 'The Matrix' }
            $matrix | Should -Not -BeNullOrEmpty
            $matrix.SourceWatched | Should -Be $true
            $matrix.TargetWatched | Should -Be $false
        }

        It 'Identifies movies watched on target but not source' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $inception = $result | Where-Object { $_.Title -eq 'Inception' }
            $inception | Should -Not -BeNullOrEmpty
            $inception.SourceWatched | Should -Be $false
            $inception.TargetWatched | Should -Be $true
        }

        It 'Filters with WatchedOnSourceOnly' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -WatchedOnSourceOnly

            $result | Should -HaveCount 1
            $result[0].Title | Should -Be 'The Matrix'
        }

        It 'Filters with WatchedOnTargetOnly' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -WatchedOnTargetOnly

            $result | Should -HaveCount 1
            $result[0].Title | Should -Be 'Inception'
        }

        It 'Includes rating keys from both servers' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $matrix = $result | Where-Object { $_.Title -eq 'The Matrix' }
            $matrix.SourceRatingKey | Should -Be 1001
            $matrix.TargetRatingKey | Should -Be 2001
        }
    }

    Context 'TV show watch status comparison' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{
                            key   = '/library/sections/2'
                            title = 'TV Shows'
                            type  = 'show'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryItem {
                param($SectionId, $ServerUri)

                return @(
                    @{
                        ratingKey = 3001
                        title     = 'Breaking Bad'
                        type      = 'show'
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Headers)

                if ($Uri -match 'source') {
                    return @{
                        Metadata = @(
                            @{
                                ratingKey   = 4001
                                title       = 'Pilot'
                                parentIndex = 1
                                index       = 1
                                viewCount   = 1  # Watched on source
                            },
                            @{
                                ratingKey   = 4002
                                title       = "Cat's in the Bag"
                                parentIndex = 1
                                index       = 2
                                viewCount   = 0  # Not watched on source
                            }
                        )
                    }
                }
                else {
                    return @{
                        Metadata = @(
                            @{
                                ratingKey   = 5001
                                title       = 'Pilot'
                                parentIndex = 1
                                index       = 1
                                viewCount   = 0  # Not watched on target
                            },
                            @{
                                ratingKey   = 5002
                                title       = "Cat's in the Bag"
                                parentIndex = 1
                                index       = 2
                                viewCount   = 1  # Watched on target
                            }
                        )
                    }
                }
            }
        }

        It 'Compares TV episode watch status' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $result | Should -HaveCount 2
        }

        It 'Includes show and episode information' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $pilot = $result | Where-Object { $_.Title -eq 'Pilot' }
            $pilot.Type | Should -Be 'episode'
            $pilot.ShowName | Should -Be 'Breaking Bad'
            $pilot.Season | Should -Be 1
            $pilot.Episode | Should -Be 1
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws when source server not found' {
            { Compare-PatWatchStatus -SourceServerName 'NonExistent' -TargetServerName 'Target' } |
                Should -Throw "*not found*"
        }
    }

    Context 'PSTypeName assignment' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{
                            key   = '/library/sections/1'
                            title = 'Movies'
                            type  = 'movie'
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryItem {
                param($ServerUri)
                if ($ServerUri -match 'Source') {
                    return @(@{ ratingKey = 1; title = 'Test'; year = 2020; viewCount = 1 })
                }
                else {
                    return @(@{ ratingKey = 2; title = 'Test'; year = 2020; viewCount = 0 })
                }
            }
        }

        It 'Assigns correct PSTypeName to results' {
            $result = Compare-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target'

            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.WatchStatusDiff'
        }
    }
}
