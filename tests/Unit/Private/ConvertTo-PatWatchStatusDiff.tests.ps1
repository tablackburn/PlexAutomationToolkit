BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertTo-PatWatchStatusDiff' {
    Context 'Parameter Validation' {
        It 'Should throw when Type is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    ConvertTo-PatWatchStatusDiff -Title 'Test' `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                }
            } | Should -Throw
        }

        It 'Should throw for invalid Type value' {
            {
                InModuleScope PlexAutomationToolkit {
                    ConvertTo-PatWatchStatusDiff -Type 'invalid' -Title 'Test' `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                }
            } | Should -Throw
        }

        It 'Should throw when Title is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    ConvertTo-PatWatchStatusDiff -Type 'movie' `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                }
            } | Should -Throw
        }

        It 'Should throw for empty Title' {
            {
                InModuleScope PlexAutomationToolkit {
                    ConvertTo-PatWatchStatusDiff -Type 'movie' -Title '' `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                }
            } | Should -Throw
        }

        It 'Should accept movie as Type' {
            InModuleScope PlexAutomationToolkit {
                {
                    ConvertTo-PatWatchStatusDiff -Type 'movie' -Title 'Test' -Year 2020 `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                } | Should -Not -Throw
            }
        }

        It 'Should accept episode as Type' {
            InModuleScope PlexAutomationToolkit {
                {
                    ConvertTo-PatWatchStatusDiff -Type 'episode' -Title 'Pilot' `
                        -ShowName 'Test Show' -Season 1 -Episode 1 `
                        -SourceWatched $true -TargetWatched $false `
                        -SourceViewCount 1 -TargetViewCount 0 `
                        -SourceRatingKey 123 -TargetRatingKey 456
                } | Should -Not -Throw
            }
        }
    }

    Context 'Movie Diff Creation' {
        It 'Should create correct movie diff object' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'The Matrix' -Year 1999 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 2 -TargetViewCount 0 `
                    -SourceRatingKey 123 -TargetRatingKey 456

                $result.Title | Should -Be 'The Matrix'
                $result.Type | Should -Be 'movie'
                $result.Year | Should -Be 1999
                $result.ShowName | Should -BeNullOrEmpty
                $result.Season | Should -BeNullOrEmpty
                $result.Episode | Should -BeNullOrEmpty
                $result.SourceWatched | Should -Be $true
                $result.TargetWatched | Should -Be $false
                $result.SourceViewCount | Should -Be 2
                $result.TargetViewCount | Should -Be 0
                $result.SourceRatingKey | Should -Be 123
                $result.TargetRatingKey | Should -Be 456
            }
        }

        It 'Should set correct PSTypeName for movie' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test Movie' -Year 2020 `
                    -SourceWatched $false -TargetWatched $true `
                    -SourceViewCount 0 -TargetViewCount 1 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.WatchStatusDiff'
            }
        }

        It 'Should handle movie without year' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Unknown Year Movie' `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 111 -TargetRatingKey 222

                $result.Year | Should -BeNullOrEmpty
                $result.Title | Should -Be 'Unknown Year Movie'
            }
        }

        It 'Should handle movie with year 0' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test' -Year 0 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.Year | Should -Be 0
            }
        }
    }

    Context 'Episode Diff Creation' {
        It 'Should create correct episode diff object' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'episode' `
                    -Title 'Pilot' -ShowName 'Breaking Bad' -Season 1 -Episode 1 `
                    -SourceWatched $false -TargetWatched $true `
                    -SourceViewCount 0 -TargetViewCount 1 `
                    -SourceRatingKey 789 -TargetRatingKey 101

                $result.Title | Should -Be 'Pilot'
                $result.Type | Should -Be 'episode'
                $result.Year | Should -BeNullOrEmpty
                $result.ShowName | Should -Be 'Breaking Bad'
                $result.Season | Should -Be 1
                $result.Episode | Should -Be 1
                $result.SourceWatched | Should -Be $false
                $result.TargetWatched | Should -Be $true
                $result.SourceViewCount | Should -Be 0
                $result.TargetViewCount | Should -Be 1
                $result.SourceRatingKey | Should -Be 789
                $result.TargetRatingKey | Should -Be 101
            }
        }

        It 'Should set correct PSTypeName for episode' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'episode' `
                    -Title 'Test Episode' -ShowName 'Test Show' -Season 1 -Episode 1 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.WatchStatusDiff'
            }
        }

        It 'Should handle episode with high season and episode numbers' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'episode' `
                    -Title 'Long Episode' -ShowName 'The Simpsons' -Season 35 -Episode 22 `
                    -SourceWatched $true -TargetWatched $true `
                    -SourceViewCount 5 -TargetViewCount 3 `
                    -SourceRatingKey 999 -TargetRatingKey 888

                $result.Season | Should -Be 35
                $result.Episode | Should -Be 22
            }
        }

        It 'Should handle special episode (season 0)' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'episode' `
                    -Title 'Behind the Scenes' -ShowName 'Some Show' -Season 0 -Episode 1 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.Season | Should -Be 0
            }
        }
    }

    Context 'Watch Status Combinations' {
        It 'Should handle watched on source only' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Source Only' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.SourceWatched | Should -Be $true
                $result.TargetWatched | Should -Be $false
            }
        }

        It 'Should handle watched on target only' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Target Only' -Year 2020 `
                    -SourceWatched $false -TargetWatched $true `
                    -SourceViewCount 0 -TargetViewCount 1 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.SourceWatched | Should -Be $false
                $result.TargetWatched | Should -Be $true
            }
        }

        It 'Should handle different view counts when both watched' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Different Counts' -Year 2020 `
                    -SourceWatched $true -TargetWatched $true `
                    -SourceViewCount 5 -TargetViewCount 2 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.SourceViewCount | Should -Be 5
                $result.TargetViewCount | Should -Be 2
            }
        }

        It 'Should handle zero view counts' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Zero Counts' -Year 2020 `
                    -SourceWatched $false -TargetWatched $false `
                    -SourceViewCount 0 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.SourceViewCount | Should -Be 0
                $result.TargetViewCount | Should -Be 0
            }
        }
    }

    Context 'Rating Key Handling' {
        It 'Should preserve different rating keys' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 12345 -TargetRatingKey 67890

                $result.SourceRatingKey | Should -Be 12345
                $result.TargetRatingKey | Should -Be 67890
            }
        }

        It 'Should handle large rating keys' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Large Keys' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 2147483647 -TargetRatingKey 2147483646

                $result.SourceRatingKey | Should -Be 2147483647
                $result.TargetRatingKey | Should -Be 2147483646
            }
        }
    }

    Context 'Output Type and Structure' {
        It 'Should return PSCustomObject' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Should have all expected properties' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.PSObject.Properties.Name | Should -Contain 'Title'
                $result.PSObject.Properties.Name | Should -Contain 'Type'
                $result.PSObject.Properties.Name | Should -Contain 'Year'
                $result.PSObject.Properties.Name | Should -Contain 'ShowName'
                $result.PSObject.Properties.Name | Should -Contain 'Season'
                $result.PSObject.Properties.Name | Should -Contain 'Episode'
                $result.PSObject.Properties.Name | Should -Contain 'SourceWatched'
                $result.PSObject.Properties.Name | Should -Contain 'TargetWatched'
                $result.PSObject.Properties.Name | Should -Contain 'SourceViewCount'
                $result.PSObject.Properties.Name | Should -Contain 'TargetViewCount'
                $result.PSObject.Properties.Name | Should -Contain 'SourceRatingKey'
                $result.PSObject.Properties.Name | Should -Contain 'TargetRatingKey'
            }
        }

        It 'Should have exactly 12 properties' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Test' -Year 2020 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.PSObject.Properties.Name | Should -HaveCount 12
            }
        }
    }

    Context 'Special Characters in Titles' {
        It 'Should handle title with special characters' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title "Ocean's Eleven: The Heist!" -Year 2001 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.Title | Should -Be "Ocean's Eleven: The Heist!"
            }
        }

        It 'Should handle show name with special characters' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'episode' `
                    -Title 'Test Ep' -ShowName "Grey's Anatomy: New Beginnings" -Season 1 -Episode 1 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.ShowName | Should -Be "Grey's Anatomy: New Beginnings"
            }
        }

        It 'Should handle unicode characters' {
            InModuleScope PlexAutomationToolkit {
                $result = ConvertTo-PatWatchStatusDiff -Type 'movie' `
                    -Title 'Amélie' -Year 2001 `
                    -SourceWatched $true -TargetWatched $false `
                    -SourceViewCount 1 -TargetViewCount 0 `
                    -SourceRatingKey 1 -TargetRatingKey 2

                $result.Title | Should -Be 'Amélie'
            }
        }
    }
}
