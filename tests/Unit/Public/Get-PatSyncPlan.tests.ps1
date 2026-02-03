BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Create temp directory for test files (cross-platform)
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncPlanTests_$([Guid]::NewGuid().ToString('N'))"
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

        Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
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

            # Mock the internal helper directly for cross-platform compatibility
            Mock -ModuleName PlexAutomationToolkit Get-PatDestinationFreeSpace {
                return 10000000000  # Only 10 GB free
            }
        }

        It 'Detects insufficient space' {
            # Use a fresh temp directory for this test (cross-platform)
            $freshDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncPlanSpace_$([Guid]::NewGuid().ToString('N'))"
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

    Context 'Relative path resolution' -Skip:(-not ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop')) {
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

    Context 'File size scenarios' {
        BeforeAll {
            # Create temp directory for this context
            $script:SizeTestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncPlanSizeTests_$([Guid]::NewGuid().ToString('N'))"
            New-Item -Path $script:SizeTestDir -ItemType Directory -Force | Out-Null

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Size Test Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Size Test Movie'
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

        AfterAll {
            if ($script:SizeTestDir -and (Test-Path -Path $script:SizeTestDir)) {
                Remove-Item -Path $script:SizeTestDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Marks file for download when size differs' {
            # Create movie directory and file with wrong size
            $movieDir = [System.IO.Path]::Combine($script:SizeTestDir, 'Movies', 'Size Test Movie (2023)')
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $movieFile = Join-Path -Path $movieDir -ChildPath 'Size Test Movie (2023).mkv'
            [System.IO.File]::WriteAllBytes($movieFile, [byte[]](1, 2, 3))  # Wrong size (3 bytes vs 1GB)

            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:SizeTestDir

            $result.ItemsToAdd | Should -Be 1
            $result.BytesToDownload | Should -Be 1000000000
        }

        It 'Skips file when size matches exactly' {
            # Create movie directory and file with correct size
            $movieDir = [System.IO.Path]::Combine($script:SizeTestDir, 'Movies', 'Size Test Movie (2023)')
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $movieFile = Join-Path -Path $movieDir -ChildPath 'Size Test Movie (2023).mkv'
            $fs = [System.IO.File]::Create($movieFile)
            $fs.SetLength(1000000000)  # Correct size
            $fs.Close()

            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:SizeTestDir

            $result.ItemsToAdd | Should -Be 0
            $result.ItemsUnchanged | Should -Be 1
        }
    }

    Context 'Media container types' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Handles .mp4 container' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'MP4 Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'MP4 Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'mp4'
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file.mp4'
                                    Size      = 1000000000
                                    Container = 'mp4'
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.AddOperations[0].Container | Should -Be 'mp4'
            $result.AddOperations[0].DestinationPath | Should -Match '\.mp4$'
        }

        It 'Handles .avi container' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'AVI Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'AVI Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'avi'
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file.avi'
                                    Size      = 1000000000
                                    Container = 'avi'
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.AddOperations[0].Container | Should -Be 'avi'
            $result.AddOperations[0].DestinationPath | Should -Match '\.avi$'
        }

        It 'Defaults to mkv when container is null' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'No Container Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'No Container Movie'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = $null
                            Part      = @(
                                [PSCustomObject]@{
                                    PartId    = 3001
                                    Key       = '/library/parts/3001/file'
                                    Size      = 1000000000
                                    Container = $null
                                    Streams   = @()
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir

            $result.AddOperations[0].DestinationPath | Should -Match '\.mkv$'
        }
    }

    Context 'Playlist edge cases' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Returns empty plan for empty playlist' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Empty'
                    ItemCount  = 0
                    Items      = @()
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Empty' -Destination $script:TestDir

            $result.TotalItems | Should -Be 0
            $result.ItemsToAdd | Should -Be 0
            $result.BytesToDownload | Should -Be 0
            $result.AddOperations | Should -BeNullOrEmpty
        }

        It 'Handles playlist with single item' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Single'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Single Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Single Movie'
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

            $result = Get-PatSyncPlan -PlaylistName 'Single' -Destination $script:TestDir

            $result.TotalItems | Should -Be 1
            $result.ItemsToAdd | Should -Be 1
            $result.AddOperations | Should -HaveCount 1
        }

        It 'Handles items with no media files' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'NoMedia'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'No Media Item'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'No Media Item'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @()  # No media
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'NoMedia' -Destination $script:TestDir

            # Should skip item with no media
            $result.ItemsToAdd | Should -Be 0
            $result.AddOperations | Should -BeNullOrEmpty
        }

        It 'Handles items with no media parts' {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'NoParts'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'No Parts Item'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'No Parts Item'
                    Type             = 'movie'
                    Year             = 2023
                    GrandparentTitle = $null
                    ParentIndex      = $null
                    Index            = $null
                    Media            = @(
                        [PSCustomObject]@{
                            MediaId   = 2001
                            Container = 'mkv'
                            Part      = @()  # No parts
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'NoParts' -Destination $script:TestDir

            # Should skip item with no parts
            $result.ItemsToAdd | Should -Be 0
            $result.AddOperations | Should -BeNullOrEmpty
        }
    }

    Context 'No default server configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws when no default server and no ServerUri provided' {
            { Get-PatSyncPlan -Destination $script:TestDir } |
                Should -Throw "*No default server configured*"
        }
    }

    Context 'Failed to get default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                throw "Configuration file corrupted"
            }
        }

        It 'Throws with context when Get-PatStoredServer fails' {
            { Get-PatSyncPlan -Destination $script:TestDir } |
                Should -Throw "*Failed to resolve server*"
        }
    }

    Context 'ServerUri with Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 0
                    Items      = @()
                    ServerUri  = 'http://explicit.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Passes ServerUri and Token to Get-PatPlaylist' {
            Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerUri 'http://explicit.test:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                $ServerUri -eq 'http://explicit.test:32400' -and $Token -eq 'my-token'
            }
        }

        It 'Does not call Get-PatStoredServer when ServerUri specified' {
            Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerUri 'http://explicit.test:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -Times 0
        }
    }

    Context 'ServerName parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name, $Default)
                if ($Name -eq 'HomeServer') {
                    return [PSCustomObject]@{
                        name    = 'HomeServer'
                        uri     = 'http://home.test:32400'
                        token   = 'home-token'
                        default = $false
                    }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{
                    Accept         = 'application/json'
                    'X-Plex-Token' = 'home-token'
                }
            }

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
                    ServerUri  = 'http://home.test:32400'
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
                    ServerUri = 'http://home.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }
        }

        It 'Passes ServerName to Get-PatPlaylist' {
            Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerName 'HomeServer'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                $ServerName -eq 'HomeServer'
            }
        }

        It 'Passes ServerName to Get-PatMediaInfo' {
            Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerName 'HomeServer'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatMediaInfo -ParameterFilter {
                $ServerName -eq 'HomeServer'
            }
        }

        It 'Returns valid sync plan when using ServerName' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerName 'HomeServer'

            $result | Should -Not -BeNullOrEmpty
            $result.PlaylistName | Should -Be 'Travel'
            $result.ServerUri | Should -Be 'http://home.test:32400'
        }

        It 'Does not pass ServerUri when using ServerName' {
            Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -ServerName 'HomeServer'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatPlaylist -ParameterFilter {
                -not $ServerUri -and $ServerName -eq 'HomeServer'
            }
        }
    }

    Context 'TV Shows folder file removal' {
        BeforeAll {
            # Create temp directory for this context
            $script:TVTestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncPlanTVTests_$([Guid]::NewGuid().ToString('N'))"
            New-Item -Path $script:TVTestDir -ItemType Directory -Force | Out-Null

            # Create an orphan TV episode that's not in the playlist
            $orphanDir = [System.IO.Path]::Combine($script:TVTestDir, 'TV Shows', 'Orphan Show', 'Season 01')
            New-Item -Path $orphanDir -ItemType Directory -Force | Out-Null
            $orphanFile = Join-Path -Path $orphanDir -ChildPath 'Orphan Show - S01E01.mkv'
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

        AfterAll {
            if ($script:TVTestDir -and (Test-Path -Path $script:TVTestDir)) {
                Remove-Item -Path $script:TVTestDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Identifies TV Show files to remove that are not in playlist' {
            $result = Get-PatSyncPlan -PlaylistName 'Empty' -Destination $script:TVTestDir

            $result.ItemsToRemove | Should -BeGreaterThan 0
            $orphanOp = $result.RemoveOperations | Where-Object { $_.Path -match 'Orphan Show' }
            $orphanOp | Should -Not -BeNullOrEmpty
            $orphanOp.Type | Should -Be 'episode'
        }
    }

    Context 'Drive space detection failure' -Skip:(-not $IsWindows) {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Travel'
                    ItemCount  = 0
                    Items      = @()
                    ServerUri  = 'http://plex.test:32400'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                throw "Drive not found"
            }
        }

        It 'Continues with zero free space when drive info fails' {
            $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:TestDir -WarningVariable warnings 3>$null

            $result | Should -Not -BeNullOrEmpty
            $result.DestinationFree | Should -Be 0
        }
    }

    Context 'Subtitle count detection' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PSDrive {
                return [PSCustomObject]@{
                    Free = 100000000000
                }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatPlaylist {
                return [PSCustomObject]@{
                    PlaylistId = 100
                    Title      = 'Subtitles'
                    ItemCount  = 1
                    Items      = @(
                        [PSCustomObject]@{
                            RatingKey = 1001
                            Title     = 'Subtitle Movie'
                            Type      = 'movie'
                        }
                    )
                    ServerUri  = 'http://plex.test:32400'
                }
            }
        }

        It 'Counts zero subtitles when none exist' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Subtitle Movie'
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
                                    Streams   = @()  # No streams
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Subtitles' -Destination $script:TestDir

            $result.AddOperations[0].SubtitleCount | Should -Be 0
        }

        It 'Counts multiple external subtitles' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaInfo {
                return [PSCustomObject]@{
                    RatingKey        = 1001
                    Title            = 'Subtitle Movie'
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
                                    Streams   = @(
                                        [PSCustomObject]@{
                                            StreamType = 3
                                            External   = $true
                                            Key        = '/library/streams/4001'
                                        },
                                        [PSCustomObject]@{
                                            StreamType = 3
                                            External   = $true
                                            Key        = '/library/streams/4002'
                                        },
                                        [PSCustomObject]@{
                                            StreamType = 3
                                            External   = $false  # Not external, should not count
                                            Key        = $null
                                        }
                                    )
                                }
                            )
                        }
                    )
                    ServerUri = 'http://plex.test:32400'
                }
            }

            $result = Get-PatSyncPlan -PlaylistName 'Subtitles' -Destination $script:TestDir

            $result.AddOperations[0].SubtitleCount | Should -Be 2
        }
    }
}
