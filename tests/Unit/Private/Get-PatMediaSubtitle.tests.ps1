BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:GetPatMediaSubtitle = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }

    # Create temp directory for test files
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatMediaSubtitleTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PatMediaSubtitle' {
    BeforeEach {
        # Clean up test directory before each test
        Get-ChildItem -Path $script:TestDir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Basic subtitle download' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Title     = 'Test Movie'
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($Uri, $OutFile, $Token)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE CONTENT")
                return Get-Item -Path $OutFile
            }
        }

        It 'Downloads subtitle file' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie (2020).mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            $expectedSubPath = Join-Path -Path $script:TestDir -ChildPath 'Movie (2020).eng.srt'
            Test-Path -Path $expectedSubPath | Should -Be $true
        }

        It 'Calls Get-PatMediaInfo with correct RatingKey' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Should -Invoke -CommandName Get-PatMediaInfo -ModuleName PlexAutomationToolkit -ParameterFilter {
                $RatingKey -eq 1001
            }
        }

        It 'Calls Invoke-PatFileDownload with correct URL' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Uri -eq 'http://plex:32400/library/streams/5001?download=1'
            }
        }

        It 'Passes token to Invoke-PatFileDownload' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'my-secret-token'

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Token -eq 'my-secret-token'
            }
        }
    }

    Context 'Multiple subtitles' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        },
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5002'
                                            LanguageCode = 'spa'
                                            Format       = 'srt'
                                        },
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5003'
                                            LanguageCode = 'fra'
                                            Format       = 'ass'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($Uri, $OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
                return Get-Item -Path $OutFile
            }
        }

        It 'Downloads all external subtitles' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 3
        }

        It 'Creates correct file names for each language' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Test-Path (Join-Path $script:TestDir 'Movie.eng.srt') | Should -Be $true
            Test-Path (Join-Path $script:TestDir 'Movie.spa.srt') | Should -Be $true
            Test-Path (Join-Path $script:TestDir 'Movie.fra.ass') | Should -Be $true
        }
    }

    Context 'Filtering streams' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        # Video stream (StreamType 1) - should be ignored
                                        [PSCustomObject]@{
                                            StreamType = 1
                                            External   = $false
                                        },
                                        # Audio stream (StreamType 2) - should be ignored
                                        [PSCustomObject]@{
                                            StreamType = 2
                                            External   = $false
                                        },
                                        # Embedded subtitle (External = false) - should be ignored
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $false
                                            LanguageCode = 'eng'
                                        },
                                        # External subtitle without Key - should be ignored
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = $null
                                            LanguageCode = 'deu'
                                        },
                                        # Valid external subtitle - should be downloaded
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'jpn'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
            }
        }

        It 'Only downloads external subtitles with keys' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            # Should only call once for the valid Japanese subtitle
            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Downloads only the valid subtitle' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -Token 'test-token'

            Test-Path (Join-Path $script:TestDir 'Movie.jpn.srt') | Should -Be $true
        }
    }

    Context 'Default values for missing metadata' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = $null  # Missing language
                                            Format       = $null  # Missing format
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
            }
        }

        It 'Uses "und" for missing language code' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400'

            Test-Path (Join-Path $script:TestDir 'Movie.und.srt') | Should -Be $true
        }

        It 'Uses "srt" for missing format' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400'

            $subPath = Join-Path $script:TestDir 'Movie.und.srt'
            Test-Path $subPath | Should -Be $true
        }
    }

    Context 'No subtitles available' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload { }
        }

        It 'Handles media with no streams gracefully' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @()
                                }
                            )
                        }
                    )
                }
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            { & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' } | Should -Not -Throw

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Handles media with no parts gracefully' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = $null
                        }
                    )
                }
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            { & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' } | Should -Not -Throw

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Handles media with no Media array gracefully' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = $null
                }
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            { & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' } | Should -Not -Throw

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Error handling' {
        It 'Warns when Get-PatMediaInfo fails' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                throw "API Error: 401 Unauthorized"
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            $warnings = & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' 3>&1

            $warnings | Should -Match 'Failed to get media info'
        }

        It 'Warns when subtitle download fails' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                throw "Network error"
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            $warnings = & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -ItemDisplayName 'Test Movie (2020)' 3>&1

            $warnings | Should -Match 'Failed to download subtitle'
            $warnings | Should -Match 'Test Movie \(2020\)'
        }

        It 'Continues downloading other subtitles after one fails' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        },
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5002'
                                            LanguageCode = 'spa'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            $script:downloadCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                $script:downloadCount++
                if ($script:downloadCount -eq 1) {
                    throw "First download fails"
                }
                # Second download succeeds
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
            }

            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'
            $script:downloadCount = 0

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' 3>&1 | Out-Null

            # Both downloads should be attempted
            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 2
        }
    }

    Context 'ServerName parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
            }
        }

        It 'Passes ServerName to Get-PatMediaInfo' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -ServerName 'HomeServer'

            Should -Invoke -CommandName Get-PatMediaInfo -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerName -eq 'HomeServer'
            }
        }

        It 'Prefers ServerName over ServerUri for Get-PatMediaInfo' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400' -ServerName 'HomeServer' -Token 'test-token'

            Should -Invoke -CommandName Get-PatMediaInfo -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerName -eq 'HomeServer' -and -not $ServerUri
            }
        }
    }

    Context 'Path handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Media     = @(
                        [PSCustomObject]@{
                            Part = @(
                                [PSCustomObject]@{
                                    Streams = @(
                                        [PSCustomObject]@{
                                            StreamType   = 3
                                            External     = $true
                                            Key          = '/library/streams/5001'
                                            LanguageCode = 'eng'
                                            Format       = 'srt'
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($OutFile, "SUBTITLE")
            }
        }

        It 'Handles media path with multiple extensions correctly' {
            $mediaPath = Join-Path -Path $script:TestDir -ChildPath 'Movie.2020.1080p.mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400'

            # Should only remove the last extension
            Test-Path (Join-Path $script:TestDir 'Movie.2020.1080p.eng.srt') | Should -Be $true
        }

        It 'Handles media path in subdirectory' {
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test Movie (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $mediaPath = Join-Path -Path $movieDir -ChildPath 'Test Movie (2020).mkv'

            & $script:GetPatMediaSubtitle -RatingKey 1001 -MediaDestinationPath $mediaPath `
                -ServerUri 'http://plex:32400'

            Test-Path (Join-Path $movieDir 'Test Movie (2020).eng.srt') | Should -Be $true
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory RatingKey parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }
            $parameter = $command.Parameters['RatingKey']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Has mandatory MediaDestinationPath parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }
            $parameter = $command.Parameters['MediaDestinationPath']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Has mandatory ServerUri parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }
            $parameter = $command.Parameters['ServerUri']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Has optional Token parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }
            $parameter = $command.Parameters['Token']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Not -Contain $true
        }

        It 'Has optional ServerName parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaSubtitle }
            $parameter = $command.Parameters['ServerName']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Not -Contain $true
        }
    }
}
