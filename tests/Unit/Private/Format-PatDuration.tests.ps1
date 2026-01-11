BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Format-PatDuration' {
    Context 'Hours and minutes formatting' {
        It 'Should format duration with hours and minutes' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 8160000
                $result | Should -Be '2h 16m'
            }
        }

        It 'Should format 1 hour duration' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 3600000
                $result | Should -Be '1h 0m'
            }
        }

        It 'Should format 1 hour 30 minutes' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 5400000
                $result | Should -Be '1h 30m'
            }
        }

        It 'Should format long duration (3+ hours)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 12600000
                $result | Should -Be '3h 30m'
            }
        }
    }

    Context 'Minutes only formatting' {
        It 'Should format duration less than 1 hour' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 2700000
                $result | Should -Be '45m'
            }
        }

        It 'Should format 30 minutes' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 1800000
                $result | Should -Be '30m'
            }
        }

        It 'Should format 1 minute' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 60000
                $result | Should -Be '1m'
            }
        }

        It 'Should format short duration (seconds only) as 0m' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 30000
                $result | Should -Be '0m'
            }
        }
    }

    Context 'Null and zero handling' {
        It 'Should return null for zero milliseconds' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 0
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Should return null for null input' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds $null
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Pipeline support' {
        It 'Should accept value from pipeline' {
            InModuleScope PlexAutomationToolkit {
                $result = 7200000 | Format-PatDuration
                $result | Should -Be '2h 0m'
            }
        }

        It 'Should process multiple values from pipeline' {
            InModuleScope PlexAutomationToolkit {
                $results = @(8160000, 2700000, 5400000) | Format-PatDuration
                $results | Should -HaveCount 3
                $results[0] | Should -Be '2h 16m'
                $results[1] | Should -Be '45m'
                $results[2] | Should -Be '1h 30m'
            }
        }
    }

    Context 'Output type' {
        It 'Should return a string' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatDuration -Milliseconds 3600000
                $result | Should -BeOfType [string]
            }
        }
    }

    Context 'Real-world media durations' {
        It 'Should format typical movie duration (2h 16m)' {
            InModuleScope PlexAutomationToolkit {
                # The Matrix: 136 minutes = 8160000ms
                $result = Format-PatDuration -Milliseconds 8160000
                $result | Should -Be '2h 16m'
            }
        }

        It 'Should format typical TV episode duration (45m)' {
            InModuleScope PlexAutomationToolkit {
                # 45 minute episode = 2700000ms
                $result = Format-PatDuration -Milliseconds 2700000
                $result | Should -Be '45m'
            }
        }

        It 'Should format typical sitcom duration (22m)' {
            InModuleScope PlexAutomationToolkit {
                # 22 minute sitcom = 1320000ms
                $result = Format-PatDuration -Milliseconds 1320000
                $result | Should -Be '22m'
            }
        }

        It 'Should format extended edition movie (3h 21m)' {
            InModuleScope PlexAutomationToolkit {
                # LOTR Extended: 201 minutes = 12060000ms
                $result = Format-PatDuration -Milliseconds 12060000
                $result | Should -Be '3h 21m'
            }
        }
    }
}
