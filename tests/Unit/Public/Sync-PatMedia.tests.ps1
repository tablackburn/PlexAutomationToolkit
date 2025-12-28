BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Create temp directory for test files (cross-platform)
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncMediaTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Sync-PatMedia' {
    BeforeAll {
        # Mock the private functions
        Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
            return [PSCustomObject]@{
                name    = 'TestServer'
                uri     = 'http://plex.test:32400'
                token   = 'test-token'
                default = $true
            }
        }

        Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
            return @{
                Accept         = 'application/json'
                'X-Plex-Token' = 'test-token'
            }
        }

        Mock -ModuleName PlexAutomationToolkit Test-PatServerUri { return $true }
    }

    Context 'Basic sync operation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                return [PSCustomObject]@{
                    PSTypeName       = 'PlexAutomationToolkit.SyncPlan'
                    PlaylistName     = 'Travel'
                    PlaylistId       = 100
                    Destination      = $script:TestDir
                    TotalItems       = 1
                    ItemsToAdd       = 1
                    ItemsToRemove    = 0
                    ItemsUnchanged   = 0
                    BytesToDownload  = 1000
                    BytesToRemove    = 0
                    DestinationFree  = 1000000000
                    DestinationAfter = 999999000
                    SpaceSufficient  = $true
                    AddOperations    = @(
                        [PSCustomObject]@{
                            RatingKey       = 1001
                            Title           = 'Test Movie'
                            Type            = 'movie'
                            Year            = 2023
                            GrandparentTitle = $null
                            ParentIndex     = $null
                            Index           = $null
                            DestinationPath = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Test Movie (2023)', 'Test Movie (2023).mkv')
                            MediaSize       = 1000
                            SubtitleCount   = 0
                            PartKey         = '/library/parts/3001/file.mkv'
                            Container       = 'mkv'
                        }
                    )
                    RemoveOperations = @()
                    ServerUri        = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($Uri, $OutFile, $ExpectedSize, $Resume)

                # Create the file
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3))

                return Get-Item -Path $OutFile
            }
        }

        It 'Downloads media files' {
            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -Confirm:$false

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Creates destination directory structure' {
            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -Confirm:$false

            $movieDir = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Test Movie (2023)')
            Test-Path -Path $movieDir | Should -Be $true
        }

        It 'Returns sync plan with PassThru' {
            $result = Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.PlaylistName | Should -Be 'Travel'
        }
    }

    Context 'WhatIf support' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                return [PSCustomObject]@{
                    PlaylistName     = 'Travel'
                    PlaylistId       = 100
                    TotalItems       = 1
                    ItemsToAdd       = 1
                    ItemsToRemove    = 0
                    ItemsUnchanged   = 0
                    BytesToDownload  = 1000
                    BytesToRemove    = 0
                    DestinationFree  = 1000000000
                    DestinationAfter = 999999000
                    SpaceSufficient  = $true
                    AddOperations    = @(
                        [PSCustomObject]@{
                            RatingKey       = 1001
                            Title           = 'WhatIf Movie'
                            Type            = 'movie'
                            Year            = 2023
                            DestinationPath = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'WhatIf Movie (2023)', 'WhatIf Movie (2023).mkv')
                            MediaSize       = 1000
                            SubtitleCount   = 0
                            PartKey         = '/library/parts/3001/file.mkv'
                        }
                    )
                    RemoveOperations = @()
                    ServerUri        = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload { }
        }

        It 'Does not download files with WhatIf' {
            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -WhatIf

            Should -Invoke -CommandName Invoke-PatFileDownload -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'File removal' {
        BeforeAll {
            # Create an orphan file to be removed
            $orphanDir = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Orphan (2020)')
            New-Item -Path $orphanDir -ItemType Directory -Force | Out-Null
            $orphanFile = Join-Path -Path $orphanDir -ChildPath 'Orphan (2020).mkv'
            [System.IO.File]::WriteAllBytes($orphanFile, [byte[]](1, 2, 3))

            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                param($Destination)
                return [PSCustomObject]@{
                    PlaylistName     = 'Travel'
                    PlaylistId       = 100
                    TotalItems       = 0
                    ItemsToAdd       = 0
                    ItemsToRemove    = 1
                    ItemsUnchanged   = 0
                    BytesToDownload  = 0
                    BytesToRemove    = 3
                    DestinationFree  = 1000000000
                    DestinationAfter = 1000000003
                    SpaceSufficient  = $true
                    AddOperations    = @()
                    RemoveOperations = @(
                        [PSCustomObject]@{
                            Path = $orphanFile
                            Size = 3
                            Type = 'movie'
                        }
                    )
                    ServerUri        = 'http://plex.test:32400'
                }
            }
        }

        It 'Removes files not in playlist' {
            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -Confirm:$false

            Test-Path -Path $orphanFile | Should -Be $false
        }

        It 'Skips removal with SkipRemoval switch' {
            # Recreate the orphan file
            $orphanDir = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Orphan (2020)')
            New-Item -Path $orphanDir -ItemType Directory -Force | Out-Null
            $orphanFile = Join-Path -Path $orphanDir -ChildPath 'Orphan (2020).mkv'
            [System.IO.File]::WriteAllBytes($orphanFile, [byte[]](1, 2, 3))

            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -SkipRemoval -Confirm:$false

            Test-Path -Path $orphanFile | Should -Be $true
        }
    }

    Context 'Space check' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                return [PSCustomObject]@{
                    PlaylistName     = 'Large'
                    PlaylistId       = 100
                    TotalItems       = 1
                    ItemsToAdd       = 1
                    ItemsToRemove    = 0
                    ItemsUnchanged   = 0
                    BytesToDownload  = 100000000000  # 100 GB
                    BytesToRemove    = 0
                    DestinationFree  = 1000000000    # 1 GB
                    DestinationAfter = -99000000000
                    SpaceSufficient  = $false
                    AddOperations    = @(
                        [PSCustomObject]@{
                            RatingKey       = 1001
                            Title           = 'Large Movie'
                            Type            = 'movie'
                            Year            = 2023
                            DestinationPath = 'C:\temp\test.mkv'
                            MediaSize       = 100000000000
                            SubtitleCount   = 0
                            PartKey         = '/library/parts/3001/file.mkv'
                        }
                    )
                    RemoveOperations = @()
                    ServerUri        = 'http://plex.test:32400'
                }
            }
        }

        It 'Throws when insufficient space without Force' {
            { Sync-PatMedia -PlaylistName 'Large' -Destination $script:TestDir -Confirm:$false } |
                Should -Throw "*Insufficient space*"
        }

        It 'Proceeds with Force despite insufficient space' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($Uri, $OutFile)
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1))
                return Get-Item -Path $OutFile
            }

            { Sync-PatMedia -PlaylistName 'Large' -Destination $script:TestDir -Force -Confirm:$false } |
                Should -Not -Throw
        }
    }

    Context 'Subtitle download' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                return [PSCustomObject]@{
                    PlaylistName     = 'Travel'
                    PlaylistId       = 100
                    TotalItems       = 1
                    ItemsToAdd       = 1
                    ItemsToRemove    = 0
                    ItemsUnchanged   = 0
                    BytesToDownload  = 1000
                    BytesToRemove    = 0
                    DestinationFree  = 1000000000
                    DestinationAfter = 999999000
                    SpaceSufficient  = $true
                    AddOperations    = @(
                        [PSCustomObject]@{
                            RatingKey       = 1001
                            Title           = 'Subbed Movie'
                            Type            = 'movie'
                            Year            = 2023
                            GrandparentTitle = $null
                            DestinationPath = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Subbed Movie (2023)', 'Subbed Movie (2023).mkv')
                            MediaSize       = 1000
                            SubtitleCount   = 1
                            PartKey         = '/library/parts/3001/file.mkv'
                            Container       = 'mkv'
                        }
                    )
                    RemoveOperations = @()
                    ServerUri        = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey = 1001
                    Title     = 'Subbed Movie'
                    Type      = 'movie'
                    Year      = 2023
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

            $script:downloadCalls = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatFileDownload {
                param($Uri, $OutFile)
                $script:downloadCalls++
                $dir = Split-Path -Path $OutFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3))
                return Get-Item -Path $OutFile
            }
        }

        It 'Downloads subtitles by default' {
            $script:downloadCalls = 0

            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -Confirm:$false

            # Should be 2: one for media, one for subtitle
            $script:downloadCalls | Should -Be 2
        }

        It 'Skips subtitles with SkipSubtitles switch' {
            $script:downloadCalls = 0

            Sync-PatMedia -PlaylistName 'Travel' -Destination $script:TestDir -SkipSubtitles -Confirm:$false

            # Should be 1: only media, no subtitle
            $script:downloadCalls | Should -Be 1
        }
    }

    Context 'ByPlaylistId parameter set' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatSyncPlan {
                return [PSCustomObject]@{
                    PlaylistName     = 'ById Playlist'
                    PlaylistId       = 999
                    TotalItems       = 0
                    ItemsToAdd       = 0
                    ItemsToRemove    = 0
                    ItemsUnchanged   = 0
                    BytesToDownload  = 0
                    BytesToRemove    = 0
                    DestinationFree  = 1000000000
                    DestinationAfter = 1000000000
                    SpaceSufficient  = $true
                    AddOperations    = @()
                    RemoveOperations = @()
                    ServerUri        = 'http://plex.test:32400'
                }
            }
        }

        It 'Accepts PlaylistId parameter' {
            { Sync-PatMedia -PlaylistId 999 -Destination $script:TestDir -Confirm:$false } |
                Should -Not -Throw
        }
    }
}
