BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Create temp directory for test files
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncRemoveTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PatSyncRemoveOperation' {
    BeforeEach {
        # Clean up test directory before each test
        Get-ChildItem -Path $script:TestDir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Finding orphaned files' {
        It 'Returns orphaned files not in expected paths' {
            # Setup - create files
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $moviesDir -ChildPath 'Keep.mkv'
            $file2 = Join-Path -Path $moviesDir -ChildPath 'Remove.mkv'
            [System.IO.File]::WriteAllBytes($file1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($file2, [byte[]](4, 5, 6))

            $expectedPaths = @{ $file1 = $true }
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Be $file2
        }

        It 'Returns empty operations when all files are expected' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $moviesDir -ChildPath 'Expected1.mkv'
            $file2 = Join-Path -Path $moviesDir -ChildPath 'Expected2.mkv'
            [System.IO.File]::WriteAllBytes($file1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($file2, [byte[]](4, 5, 6))

            $expectedPaths = @{ $file1 = $true; $file2 = $true }
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.Operations | Should -HaveCount 0
            $result.TotalBytes | Should -Be 0
        }

        It 'Returns all files when expected paths is empty' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $moviesDir -ChildPath 'Orphan1.mkv'
            $file2 = Join-Path -Path $moviesDir -ChildPath 'Orphan2.mp4'
            [System.IO.File]::WriteAllBytes($file1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($file2, [byte[]](4, 5, 6, 7))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.Operations | Should -HaveCount 2
        }

        It 'Calculates total bytes correctly' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $moviesDir -ChildPath 'Orphan1.mkv'
            $file2 = Join-Path -Path $moviesDir -ChildPath 'Orphan2.mkv'

            # Create files with known sizes
            $bytes1 = [byte[]]::new(1000)
            $bytes2 = [byte[]]::new(2000)
            [System.IO.File]::WriteAllBytes($file1, $bytes1)
            [System.IO.File]::WriteAllBytes($file2, $bytes2)

            $expectedPaths = @{}
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.TotalBytes | Should -Be 3000
        }
    }

    Context 'Excluding expected paths' {
        It 'Excludes files in expected paths hashtable' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $expectedFile = Join-Path -Path $moviesDir -ChildPath 'Expected.mkv'
            $orphanFile = Join-Path -Path $moviesDir -ChildPath 'Orphan.mkv'
            [System.IO.File]::WriteAllBytes($expectedFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($orphanFile, [byte[]](4, 5, 6))

            $expectedPaths = @{ $expectedFile = $true }
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Be $orphanFile
        }

        It 'Matches exact paths in expected paths hashtable' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $moviesDir -ChildPath 'Movie.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            # Use exact path in expected paths
            $expectedPaths = @{ $file = $true }
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert - Exact match means no orphans
            $result.Operations | Should -HaveCount 0
        }
    }

    Context 'Different media types' {
        It 'Sets Type to movie for movie media type' {
            # Setup
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $moviesDir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $moviesDir -ChildPath 'Movie.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Assert
            $result.Operations[0].Type | Should -Be 'movie'
        }

        It 'Sets Type to episode for episode media type' {
            # Setup
            $tvDir = Join-Path -Path $script:TestDir -ChildPath 'TV Shows'
            New-Item -Path $tvDir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $tvDir -ChildPath 'Episode.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            # Act
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'episode'
            }

            # Assert
            $result.Operations[0].Type | Should -Be 'episode'
        }

        It 'Throws on invalid media type' {
            $testDir = $script:TestDir
            $expectedPaths = @{}

            {
                InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                    Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'invalid'
                }
            } | Should -Throw
        }
    }

    Context 'Non-existent folder handling' {
        It 'Returns empty operations for non-existent folder' {
            $nonExistentPath = Join-Path -Path $script:TestDir -ChildPath 'NonExistent'
            $expectedPaths = @{}

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ nonExistentPath = $nonExistentPath; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $nonExistentPath -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 0
            $result.TotalBytes | Should -Be 0
        }

        It 'Returns hashtable with Operations and TotalBytes keys for non-existent folder' {
            $nonExistentPath = Join-Path -Path $script:TestDir -ChildPath 'DoesNotExist'
            $expectedPaths = @{}

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ nonExistentPath = $nonExistentPath; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $nonExistentPath -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Keys | Should -Contain 'Operations'
            $result.Keys | Should -Contain 'TotalBytes'
        }
    }

    Context 'Various media file extensions' {
        It 'Finds MKV files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.mkv$'
        }

        It 'Finds MP4 files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.mp4'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.mp4$'
        }

        It 'Finds AVI files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.avi'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.avi$'
        }

        It 'Finds M4V files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.m4v'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.m4v$'
        }

        It 'Finds MOV files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.mov'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.mov$'
        }

        It 'Finds TS files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.ts'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.ts$'
        }

        It 'Finds WMV files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Video.wmv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.wmv$'
        }

        It 'Ignores non-media files' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $mediaFile = Join-Path -Path $dir -ChildPath 'Video.mkv'
            $textFile = Join-Path -Path $dir -ChildPath 'readme.txt'
            $subtitleFile = Join-Path -Path $dir -ChildPath 'Video.srt'
            $imageFile = Join-Path -Path $dir -ChildPath 'poster.jpg'

            [System.IO.File]::WriteAllBytes($mediaFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($textFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($subtitleFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($imageFile, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            # Should only find the MKV file
            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Match '\.mkv$'
        }

        It 'Finds all supported extensions in one scan' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Media'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $extensions = @('mkv', 'mp4', 'avi', 'm4v', 'mov', 'ts', 'wmv')
            foreach ($ext in $extensions) {
                $file = Join-Path -Path $dir -ChildPath "Video.$ext"
                [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))
            }

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 7
        }
    }

    Context 'Recursive scanning' {
        It 'Finds files in subdirectories' {
            # Setup nested structure
            $rootDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            $subDir1 = Join-Path -Path $rootDir -ChildPath 'Action'
            $subDir2 = Join-Path -Path $rootDir -ChildPath 'Comedy\2020'
            New-Item -Path $subDir1 -ItemType Directory -Force | Out-Null
            New-Item -Path $subDir2 -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $rootDir -ChildPath 'Root.mkv'
            $file2 = Join-Path -Path $subDir1 -ChildPath 'Action.mkv'
            $file3 = Join-Path -Path $subDir2 -ChildPath 'Comedy.mkv'

            [System.IO.File]::WriteAllBytes($file1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($file2, [byte[]](4, 5, 6))
            [System.IO.File]::WriteAllBytes($file3, [byte[]](7, 8, 9))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 3
        }
    }

    Context 'Operation object structure' {
        It 'Returns operations with correct PSTypeName' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Movie.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations[0].PSObject.TypeNames | Should -Contain 'PlexAutomationToolkit.SyncRemoveOperation'
        }

        It 'Returns operations with Path property' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Movie.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations[0].Path | Should -Be $file
        }

        It 'Returns operations with Size property' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Movie.mkv'
            $bytes = [byte[]]::new(500)
            [System.IO.File]::WriteAllBytes($file, $bytes)

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations[0].Size | Should -Be 500
        }

        It 'Returns operations with Type property' {
            $dir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $dir -ItemType Directory -Force | Out-Null

            $file = Join-Path -Path $dir -ChildPath 'Movie.mkv'
            [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))

            $expectedPaths = @{}
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations[0].Type | Should -Be 'movie'
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory FolderPath parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncRemoveOperation
                $parameter = $command.Parameters['FolderPath']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory ExpectedPaths parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncRemoveOperation
                $parameter = $command.Parameters['ExpectedPaths']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory MediaType parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncRemoveOperation
                $parameter = $command.Parameters['MediaType']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'MediaType parameter has ValidateSet for movie and episode' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncRemoveOperation
                $parameter = $command.Parameters['MediaType']

                $validateSet = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet | Should -Not -BeNullOrEmpty
                $validateSet.ValidValues | Should -Contain 'movie'
                $validateSet.ValidValues | Should -Contain 'episode'
            }
        }

        It 'FolderPath validates not null or empty' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncRemoveOperation
                $parameter = $command.Parameters['FolderPath']

                $validateAttribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] }
                $validateAttribute | Should -Not -BeNullOrEmpty
            }
        }

        It 'Throws on empty FolderPath' {
            $expectedPaths = @{}

            {
                InModuleScope PlexAutomationToolkit -Parameters @{ expectedPaths = $expectedPaths } {
                    Get-PatSyncRemoveOperation -FolderPath '' -ExpectedPaths $expectedPaths -MediaType 'movie'
                }
            } | Should -Throw
        }
    }

    Context 'Real-world sync scenarios' {
        It 'Handles typical movie library structure' {
            # Setup Plex-style movie structure
            $moviesRoot = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            $movie1Dir = Join-Path -Path $moviesRoot -ChildPath 'The Matrix (1999)'
            $movie2Dir = Join-Path -Path $moviesRoot -ChildPath 'Inception (2010)'
            $movie3Dir = Join-Path -Path $moviesRoot -ChildPath 'Old Movie (2000)'

            New-Item -Path $movie1Dir -ItemType Directory -Force | Out-Null
            New-Item -Path $movie2Dir -ItemType Directory -Force | Out-Null
            New-Item -Path $movie3Dir -ItemType Directory -Force | Out-Null

            $matrix = Join-Path -Path $movie1Dir -ChildPath 'The Matrix (1999).mkv'
            $inception = Join-Path -Path $movie2Dir -ChildPath 'Inception (2010).mkv'
            $oldMovie = Join-Path -Path $movie3Dir -ChildPath 'Old Movie (2000).mkv'

            [System.IO.File]::WriteAllBytes($matrix, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($inception, [byte[]](4, 5, 6))
            [System.IO.File]::WriteAllBytes($oldMovie, [byte[]](7, 8, 9))

            # Only keep Matrix and Inception
            $expectedPaths = @{
                $matrix    = $true
                $inception = $true
            }
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'movie'
            }

            $result.Operations | Should -HaveCount 1
            $result.Operations[0].Path | Should -Be $oldMovie
        }

        It 'Handles typical TV show structure' {
            # Setup Plex-style TV structure
            $tvRoot = Join-Path -Path $script:TestDir -ChildPath 'TV Shows'
            $showDir = Join-Path -Path $tvRoot -ChildPath 'Breaking Bad'
            $season1 = Join-Path -Path $showDir -ChildPath 'Season 01'
            $season2 = Join-Path -Path $showDir -ChildPath 'Season 02'

            New-Item -Path $season1 -ItemType Directory -Force | Out-Null
            New-Item -Path $season2 -ItemType Directory -Force | Out-Null

            $ep1 = Join-Path -Path $season1 -ChildPath 'Breaking Bad - S01E01 - Pilot.mkv'
            $ep2 = Join-Path -Path $season1 -ChildPath 'Breaking Bad - S01E02 - Cat.mkv'
            $ep3 = Join-Path -Path $season2 -ChildPath 'Breaking Bad - S02E01 - Seven Thirty-Seven.mkv'

            [System.IO.File]::WriteAllBytes($ep1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($ep2, [byte[]](4, 5, 6))
            [System.IO.File]::WriteAllBytes($ep3, [byte[]](7, 8, 9))

            # Only keep S01E01
            $expectedPaths = @{ $ep1 = $true }
            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir; expectedPaths = $expectedPaths } {
                Get-PatSyncRemoveOperation -FolderPath $testDir -ExpectedPaths $expectedPaths -MediaType 'episode'
            }

            $result.Operations | Should -HaveCount 2
            $result.Operations.Path | Should -Contain $ep2
            $result.Operations.Path | Should -Contain $ep3
        }
    }
}
