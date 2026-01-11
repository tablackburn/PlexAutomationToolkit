BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Get-WatchStatusMatchKey' {
    Context 'Parameter Validation' {
        It 'Should throw when Type is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    Get-WatchStatusMatchKey -Title 'Test' -Year 2000
                }
            } | Should -Throw
        }

        It 'Should throw for invalid Type value' {
            {
                InModuleScope PlexAutomationToolkit {
                    Get-WatchStatusMatchKey -Type 'invalid' -Title 'Test' -Year 2000
                }
            } | Should -Throw
        }

        It 'Should accept movie as Type' {
            InModuleScope PlexAutomationToolkit {
                { Get-WatchStatusMatchKey -Type 'movie' -Title 'Test' -Year 2000 } | Should -Not -Throw
            }
        }

        It 'Should accept episode as Type' {
            InModuleScope PlexAutomationToolkit {
                { Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Test' -Season 1 -Episode 1 } | Should -Not -Throw
            }
        }
    }

    Context 'Movie Match Key Generation' {
        It 'Should generate correct key for movie with title and year' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title 'The Matrix' -Year 1999
                $result | Should -Be 'movie|the matrix|1999'
            }
        }

        It 'Should normalize title to lowercase' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title 'THE MATRIX' -Year 1999
                $result | Should -Be 'movie|the matrix|1999'
            }
        }

        It 'Should trim whitespace from title' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title '  The Matrix  ' -Year 1999
                $result | Should -Be 'movie|the matrix|1999'
            }
        }

        It 'Should remove special characters from title' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title "The Matrix: Reloaded!" -Year 2003
                $result | Should -Be 'movie|the matrix reloaded|2003'
            }
        }

        It 'Should handle title with apostrophe' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title "Ocean's Eleven" -Year 2001
                $result | Should -Be 'movie|oceans eleven|2001'
            }
        }

        It 'Should handle empty title' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title '' -Year 2000
                $result | Should -Be 'movie||2000'
            }
        }

        It 'Should handle null title' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title $null -Year 2000
                $result | Should -Be 'movie||2000'
            }
        }

        It 'Should handle year as 0' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title 'Test' -Year 0
                $result | Should -Be 'movie|test|0'
            }
        }

        It 'Should preserve numbers in title' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title '2001: A Space Odyssey' -Year 1968
                $result | Should -Be 'movie|2001 a space odyssey|1968'
            }
        }
    }

    Context 'Episode Match Key Generation' {
        It 'Should generate correct key for episode' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 1
                $result | Should -Be 'episode|breaking bad|S1E1'
            }
        }

        It 'Should normalize show name to lowercase' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'BREAKING BAD' -Season 1 -Episode 1
                $result | Should -Be 'episode|breaking bad|S1E1'
            }
        }

        It 'Should trim whitespace from show name' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName '  Breaking Bad  ' -Season 1 -Episode 1
                $result | Should -Be 'episode|breaking bad|S1E1'
            }
        }

        It 'Should remove special characters from show name' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName "Grey's Anatomy" -Season 5 -Episode 10
                $result | Should -Be 'episode|greys anatomy|S5E10'
            }
        }

        It 'Should handle double-digit season and episode numbers' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'The Simpsons' -Season 35 -Episode 22
                $result | Should -Be 'episode|the simpsons|S35E22'
            }
        }

        It 'Should handle empty show name' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName '' -Season 1 -Episode 1
                $result | Should -Be 'episode||S1E1'
            }
        }

        It 'Should handle null show name' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName $null -Season 1 -Episode 1
                $result | Should -Be 'episode||S1E1'
            }
        }

        It 'Should handle season 0 (specials)' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Test Show' -Season 0 -Episode 1
                $result | Should -Be 'episode|test show|S0E1'
            }
        }

        It 'Should handle episode 0' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Test Show' -Season 1 -Episode 0
                $result | Should -Be 'episode|test show|S1E0'
            }
        }

        It 'Should preserve numbers in show name' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'episode' -ShowName '24' -Season 1 -Episode 1
                $result | Should -Be 'episode|24|S1E1'
            }
        }
    }

    Context 'Output Type' {
        It 'Should return a string' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-WatchStatusMatchKey -Type 'movie' -Title 'Test' -Year 2000
                $result | Should -BeOfType [string]
            }
        }
    }

    Context 'Cross-Server Matching Scenarios' {
        It 'Should generate identical keys for same movie with different casing' {
            InModuleScope PlexAutomationToolkit {
                $key1 = Get-WatchStatusMatchKey -Type 'movie' -Title 'the matrix' -Year 1999
                $key2 = Get-WatchStatusMatchKey -Type 'movie' -Title 'The Matrix' -Year 1999
                $key3 = Get-WatchStatusMatchKey -Type 'movie' -Title 'THE MATRIX' -Year 1999
                $key1 | Should -Be $key2
                $key2 | Should -Be $key3
            }
        }

        It 'Should generate identical keys for same episode with different show name casing' {
            InModuleScope PlexAutomationToolkit {
                $key1 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'breaking bad' -Season 1 -Episode 1
                $key2 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 1
                $key1 | Should -Be $key2
            }
        }

        It 'Should generate different keys for different years' {
            InModuleScope PlexAutomationToolkit {
                $key1 = Get-WatchStatusMatchKey -Type 'movie' -Title 'Dune' -Year 1984
                $key2 = Get-WatchStatusMatchKey -Type 'movie' -Title 'Dune' -Year 2021
                $key1 | Should -Not -Be $key2
            }
        }

        It 'Should generate different keys for different episodes' {
            InModuleScope PlexAutomationToolkit {
                $key1 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 1
                $key2 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 2
                $key1 | Should -Not -Be $key2
            }
        }

        It 'Should generate different keys for different seasons' {
            InModuleScope PlexAutomationToolkit {
                $key1 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 1
                $key2 = Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 2 -Episode 1
                $key1 | Should -Not -Be $key2
            }
        }
    }
}
