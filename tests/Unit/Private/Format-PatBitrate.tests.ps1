BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Format-PatBitrate' {
    Context 'Megabit formatting' {
        It 'Should format bitrate >= 1000 kbps as Mbps' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 25500
                $result | Should -Be '25.5 Mbps'
            }
        }

        It 'Should format exactly 1000 kbps as 1.0 Mbps' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 1000
                $result | Should -Be '1.0 Mbps'
            }
        }

        It 'Should format high bitrate (50+ Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 50000
                $result | Should -Be '50.0 Mbps'
            }
        }

        It 'Should format typical 4K bitrate (~25 Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 25000
                $result | Should -Be '25.0 Mbps'
            }
        }
    }

    Context 'Kilobit formatting' {
        It 'Should format bitrate < 1000 kbps as kbps' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 800
                $result | Should -Be '800 kbps'
            }
        }

        It 'Should format low bitrate (128 kbps audio)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 128
                $result | Should -Be '128 kbps'
            }
        }

        It 'Should format 999 kbps as kbps (boundary)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 999
                $result | Should -Be '999 kbps'
            }
        }
    }

    Context 'Null and zero handling' {
        It 'Should return null for zero kbps' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 0
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Should return null for null input' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps $null
                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Pipeline support' {
        It 'Should accept value from pipeline' {
            InModuleScope PlexAutomationToolkit {
                $result = 5000 | Format-PatBitrate
                $result | Should -Be '5.0 Mbps'
            }
        }

        It 'Should process multiple values from pipeline' {
            InModuleScope PlexAutomationToolkit {
                $results = @(25500, 800, 5000) | Format-PatBitrate
                $results | Should -HaveCount 3
                $results[0] | Should -Be '25.5 Mbps'
                $results[1] | Should -Be '800 kbps'
                $results[2] | Should -Be '5.0 Mbps'
            }
        }
    }

    Context 'Output type' {
        It 'Should return a string' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 5000
                $result | Should -BeOfType [string]
            }
        }
    }

    Context 'Real-world media bitrates' {
        It 'Should format typical Blu-ray bitrate (~40 Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 40000
                $result | Should -Be '40.0 Mbps'
            }
        }

        It 'Should format typical 1080p streaming bitrate (~8 Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 8000
                $result | Should -Be '8.0 Mbps'
            }
        }

        It 'Should format typical 720p streaming bitrate (~5 Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 5000
                $result | Should -Be '5.0 Mbps'
            }
        }

        It 'Should format typical SD bitrate (~2.5 Mbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 2500
                $result | Should -Be '2.5 Mbps'
            }
        }

        It 'Should format typical AAC audio bitrate (256 kbps)' {
            InModuleScope PlexAutomationToolkit {
                $result = Format-PatBitrate -Kbps 256
                $result | Should -Be '256 kbps'
            }
        }
    }
}
