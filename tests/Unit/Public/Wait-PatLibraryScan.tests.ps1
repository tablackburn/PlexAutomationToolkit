BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Wait-PatLibraryScan' {

    BeforeAll {
        # Mock library paths response (for resolving section name)
        $script:mockLibraryPaths = @(
            [PSCustomObject]@{
                id          = 1
                path        = '/mnt/media/Movies'
                section     = 'Movies'
                sectionId   = '2'
                sectionType = 'movie'
            }
        )

        # Mock activity response (scan in progress)
        $script:mockScanActivity = [PSCustomObject]@{
            PSTypeName  = 'PlexAutomationToolkit.Activity'
            ActivityId  = 'abc-123'
            Type        = 'library.update.section'
            Title       = 'Scanning Movies'
            Subtitle    = 'Processing files'
            Progress    = 50
            SectionId   = 2
            Cancellable = $true
            UserStopped = $false
        }
    }

    Context 'When scan completes immediately' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatActivity {
                return $null  # No activity = scan complete
            }
        }

        It 'Returns immediately when no scan activity' {
            { Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' } | Should -Not -Throw
        }

        It 'Checks for scan activity' {
            Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatActivity -ParameterFilter {
                $Type -eq 'library.update.section' -and $SectionId -eq 2
            }
        }
    }

    Context 'When scan is in progress then completes' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Get-PatActivity {
                $script:callCount++
                if ($script:callCount -lt 3) {
                    return $script:mockScanActivity
                }
                return $null  # Scan complete after 3 calls
            }
        }

        BeforeEach {
            $script:callCount = 0
        }

        It 'Polls until scan completes' {
            Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' -PollingInterval 1
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatActivity -Times 3
        }
    }

    Context 'When using SectionName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return $script:mockLibraryPaths
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatActivity {
                return $null
            }
        }

        It 'Resolves section name to ID' {
            Wait-PatLibraryScan -SectionName 'Movies' -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryPath -ParameterFilter {
                $SectionName -eq 'Movies'
            }
        }
    }

    Context 'When using -PassThru' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Get-PatActivity {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    return $script:mockScanActivity
                }
                return $null
            }
        }

        BeforeEach {
            $script:callCount = 0
        }

        It 'Returns the last activity status' {
            $result = Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' -PassThru -PollingInterval 1
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'library.update.section'
        }
    }

    Context 'When timeout is exceeded' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatActivity {
                return $script:mockScanActivity  # Always return activity (never complete)
            }
        }

        It 'Throws timeout error' {
            { Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' -Timeout 1 -PollingInterval 1 } | Should -Throw '*Timeout*'
        }
    }

    Context 'Parameter validation' {
        It 'Requires SectionId or SectionName' {
            { Wait-PatLibraryScan -ServerUri 'http://plex.local:32400' } | Should -Throw
        }

        It 'Validates timeout range' {
            { Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' -Timeout 0 } | Should -Throw
        }

        It 'Validates polling interval range' {
            { Wait-PatLibraryScan -SectionId 2 -ServerUri 'http://plex.local:32400' -PollingInterval 0 } | Should -Throw
        }
    }
}
