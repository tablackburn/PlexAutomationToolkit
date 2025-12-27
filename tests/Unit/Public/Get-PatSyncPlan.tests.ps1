BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Create temp directory for test files
    $script:TestDir = Join-Path -Path $env:TEMP -ChildPath "PatSyncPlanTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PatSyncPlan' {
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

        Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeader {
            return @{
                Accept         = 'application/json'
                'X-Plex-Token' = 'test-token'
            }
        }

        Mock -ModuleName PlexAutomationToolkit Test-PatServerUri { return $true }
    }

    Context 'Basic sync plan generation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PSTypeName  = 'PlexAutomationToolkit.Playlist'
                    PlaylistId  = 100
                    Title       = 'Travel'
                    Type        = 'video'
                    ItemCount   = 2
                    Items       = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Test Movie'
                            Type      = 'movie'
                        },
                        [PSCustomObject]@{
                            RatingKey = 1002
                            Title     = 'Pilot'
                            Type      = 'episode'
                        }
                    )
                    ServerUri   = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                param($RatingKey)

                if ($RatingKey -eq 1001) {
                    return [PSCustomObject]@{
                        PSTypeName       = 'PlexAutomationToolkit.MediaInfo'
                        RatingKey        = 1001
                        Title            = 'Test Movie'
                        Type             = 'movie'
                        Year             = 2023
                        GrandparentTitle = $null
                        ParentIndex      = $null
                        Index            = $null
                        Media            = @(
                            [PSCustomObject]@{
                                MediaId   = 2001
                                Container = 'mkv'
                                Part      = @(
                                    [PSCustomObject]@{
                                        PartId    = 3001
                                        Key       = '/library/parts/3001/file.mkv'
                                        Size      = 5000000000
                                        Container = 'mkv'
                                        Streams   = @()
                                    }
                                )
                            }
                        )
                        ServerUri = 'http://plex.test:32400'
                    }
                }
                elseif ($RatingKey -eq 1002) {
                    return [PSCustomObject]@{
                        PSTypeName       = 'PlexAutomationToolkit.MediaInfo'
                        RatingKey        = 1002
                        Title            = 'Pilot'
                        Type             = 'episode'
                        Year             = $null
                        GrandparentTitle = 'Test Show'
                        ParentIndex      = 1
                        Index            = 1
                        Media            = @(
                            [PSCustomObject]@{
                                MediaId   = 2002
                                Container = 'mkv'
                                Part      = @(
                                    [PSCustomObject]@{
                                        PartId    = 3002
                                        Key       = '/library/parts/3002/file.mkv'
                                        Size      = 1000000000
                                        Container = 'mkv'
                                        Streams   = @(
                                            [PSCustomObject]@{
                                                StreamType = 3
                                                External   = $true
                                                Key        = '/library/streams/4001'
                                            }
                                        )
                                    }
                                )
                            }
                        )
                        ServerUri = 'http://plex.test:32400'
                    }
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000  # 100 GB
                }
            }
        }

        It 'Returns a SyncPlan object' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.SyncPlan'
        }

        It 'Includes playlist information' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.PlaylistName | Should -Be 'Travel'
            $result.PlaylistId | Should -Be 100
            $result.TotalItems | Should -Be 2
        }

        It 'Calculates items to add' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.ItemsToAdd | Should -Be 2
            $result.AddOperations | Should -HaveCount 2
        }

        It 'Calculates bytes to download' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            # 5GB movie + 1GB episode = 6GB
            $result.BytesToDownload | Should -Be 6000000000
        }

        It 'Includes correct add operation details' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $movieOp = $result.AddOperations | Where-Object { $_.Type -eq 'movie' }
            $movieOp | Should -Not -BeNullOrEmpty
            $movieOp.Title | Should -Be 'Test Movie'
            $movieOp.MediaSize | Should -Be 5000000000
            $movieOp.DestinationPath | Should -Match 'Test Movie \(2023\)'
        }

        It 'Detects external subtitles' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $episodeOp = $result.AddOperations | Where-Object { $_.Type -eq 'episode' }
            $episodeOp.SubtitleCount | Should -Be 1
        }

        It 'Determines space sufficiency' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            # 100GB free, 6GB needed - should be sufficient
            $result.SpaceSufficient | Should -Be $true
        }
    }

    Context 'Existing files detection' {
        BeforeAll {
            # Create a movie folder that already exists
            $movieDir = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Test Movie (2023)')
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            # Create a file with the correct size
            $movieFile = Join-Path -Path $movieDir -ChildPath 'Test Movie (2023).mkv'
            $fs = [System.IO.File]::Create($movieFile)
            $fs.SetLength(5000000000)  # 5GB (matching expected size)
            $fs.Close()

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Test Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Test Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'mkv'
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file.mkv'
                                    Size      = 5000000000
                                    Container = 'mkv'
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Skips files that already exist with correct size' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.ItemsToAdd | Should -Be 0
            $result.ItemsUnchanged | Should -Be 1
            $result.BytesToDownload | Should -Be 0
        }
    }

    Context 'Files to remove detection' {
        BeforeAll {
            # Create an orphan movie that's not in the playlist
            $orphanDir = [System.IO.Path]::Combine($script:TestDir, 'Movies', 'Orphan Movie (2020)')
            New-Item -Path $orphanDir -ItemType Directory -Force | Out-Null
            $orphanFile = Join-Path -Path $orphanDir -ChildPath 'Orphan Movie (2020).mkv'
            [System.IO.File]::WriteAllBytes($orphanFile, [byte[]](1, 2, 3))

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Empty'
                    ItemCount  = 0
                    Items      = @()
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Identifies files to remove that are not in playlist' {
            $result = Get-PatSyncPlan -PlaylistName 'Empty' -Destination $script:TestDir

            $result.ItemsToRemove | Should -BeGreaterThan 0
            $result.RemoveOperations | Should -Not -BeNullOrEmpty

            $orphanOp = $result.RemoveOperations | Where-Object { $_.Path -match 'Orphan Movie' }
            $orphanOp | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Space calculation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Large'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Large Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Large Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'mkv'
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file.mkv'
                                    Size      = 50000000000  # 50 GB
                                    Container = 'mkv'
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 10000000000  # Only 10 GB free
                }
            }
        }

        It 'Detects insufficient space' {
            # Use a fresh temp directory for this test
            $freshDir = Join-Path -Path $env:TEMP -ChildPath "PatSyncPlanSpace_$([Guid]::NewGuid().ToString('N'))"
            New-Item -Path $freshDir -ItemType Directory -Force | Out-Null

            try {
                $result = Get-PatSyncPlan -PlaylistName 'Large' -Destination $freshDir

                $result.SpaceSufficient | Should -Be $false
            }
            finally {
                Remove-Item -Path $freshDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Parameter validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                throw "Playlist not found"
            }
        }

        It 'Throws on non-existent playlist' {
            { Get-PatSyncPlan -PlaylistName 'NonExistent' -Destination $script:TestDir } |
                Should -Throw "*Playlist not found*"
        }
    }

    Context 'ByPlaylistId parameter set' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 999
                    Title      = 'ById Test'
                    ItemCount  = 0
                    Items      = @()
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Accepts PlaylistId parameter' {
            $result = Get-PatSyncPlan -PlaylistId 999 -Destination $script:TestDir

            $result.PlaylistId | Should -Be 999
        }
    }

    Context 'Relative path resolution' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Test Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Test Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'mkv'
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file.mkv'
                                    Size      = 1000000000
                                    Container = 'mkv'
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Resolves relative destination path to absolute path' {
            # Use relative path with current directory prefix
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination '.\SyncTest'

            # Destination should be resolved to absolute path (not start with .)
            $result.Destination | Should -Not -Match '^\.\\'
            $result.Destination | Should -Match '^[A-Z]:\\'
            # Should end with the folder name
            $result.Destination | Should -Match 'SyncTest$'
        }

        It 'Resolves add operation paths to absolute paths' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination '.\SyncTest'

            # Add operation paths should be absolute
            $result.AddOperations | ForEach-Object {
                $_.DestinationPath | Should -Not -Match '^\.\\'
                $_.DestinationPath | Should -Match '^[A-Z]:\\'
            }
        }
    }
}
