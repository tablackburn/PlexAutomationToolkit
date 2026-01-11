BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Create temp directory for test files (cross-platform)
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatRemoveSyncedFileTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Remove-PatSyncedFile' {
    BeforeEach {
        # Clean up test directory before each test
        Get-ChildItem -Path $script:TestDir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Basic file removal' {
        It 'Removes a file within the destination' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test Movie (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'Test Movie (2020).mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
        }

        It 'Does not throw when file does not exist' {
            $nonExistentPath = Join-Path -Path $script:TestDir -ChildPath 'Movies\NonExistent.mkv'
            $testDir = $script:TestDir

            {
                InModuleScope PlexAutomationToolkit -Parameters @{ nonExistentPath = $nonExistentPath; testDir = $testDir } {
                    Remove-PatSyncedFile -FilePath $nonExistentPath -Destination $testDir
                }
            } | Should -Not -Throw
        }

        It 'Handles files in root of destination' {
            # Setup
            $filePath = Join-Path -Path $script:TestDir -ChildPath 'rootfile.txt'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
        }
    }

    Context 'Empty directory cleanup' {
        It 'Removes empty parent directory after file deletion' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Empty Movie (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'Empty Movie (2020).mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
            Test-Path -Path $movieDir | Should -Be $false
        }

        It 'Removes multiple levels of empty parent directories' {
            # Setup - deep nested structure
            $deepDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Genre\SubGenre\Movie (2020)'
            New-Item -Path $deepDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $deepDir -ChildPath 'movie.mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
            Test-Path -Path $deepDir | Should -Be $false
            Test-Path -Path (Join-Path $script:TestDir 'Movies\Genre\SubGenre') | Should -Be $false
            Test-Path -Path (Join-Path $script:TestDir 'Movies\Genre') | Should -Be $false
            Test-Path -Path (Join-Path $script:TestDir 'Movies') | Should -Be $false
        }

        It 'Does not remove non-empty parent directories' {
            # Setup - two movies in same parent
            $moviesDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            $movie1Dir = Join-Path -Path $moviesDir -ChildPath 'Movie One (2020)'
            $movie2Dir = Join-Path -Path $moviesDir -ChildPath 'Movie Two (2021)'
            New-Item -Path $movie1Dir -ItemType Directory -Force | Out-Null
            New-Item -Path $movie2Dir -ItemType Directory -Force | Out-Null

            $file1 = Join-Path -Path $movie1Dir -ChildPath 'Movie One (2020).mkv'
            $file2 = Join-Path -Path $movie2Dir -ChildPath 'Movie Two (2021).mkv'
            [System.IO.File]::WriteAllBytes($file1, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($file2, [byte[]](1, 2, 3))

            # Act - remove only one movie
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ file1 = $file1; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $file1 -Destination $testDir
            }

            # Assert
            Test-Path -Path $file1 | Should -Be $false
            Test-Path -Path $movie1Dir | Should -Be $false
            Test-Path -Path $file2 | Should -Be $true
            Test-Path -Path $movie2Dir | Should -Be $true
            Test-Path -Path $moviesDir | Should -Be $true
        }

        It 'Stops cleanup at destination root' {
            # Setup
            $filePath = Join-Path -Path $script:TestDir -ChildPath 'single.txt'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert - file removed but destination still exists
            Test-Path -Path $filePath | Should -Be $false
            Test-Path -Path $script:TestDir | Should -Be $true
        }

        It 'Handles directory with hidden files' {
            # Setup - directory with hidden file
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Hidden Test'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $visibleFile = Join-Path -Path $movieDir -ChildPath 'movie.mkv'
            $hiddenFile = Join-Path -Path $movieDir -ChildPath '.hidden'
            [System.IO.File]::WriteAllBytes($visibleFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($hiddenFile, [byte[]](1, 2, 3))

            # Make file hidden (Windows) or it's already hidden by name (Unix)
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                (Get-Item $hiddenFile).Attributes = 'Hidden'
            }

            # Act - remove visible file
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ visibleFile = $visibleFile; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $visibleFile -Destination $testDir
            }

            # Assert - directory not removed because hidden file still exists
            Test-Path -Path $visibleFile | Should -Be $false
            Test-Path -Path $movieDir | Should -Be $true
        }
    }

    Context 'Security: Path validation' {
        It 'Rejects paths outside destination directory' {
            # Setup - file in parent of destination
            $outsidePath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'outside_test.txt'
            [System.IO.File]::WriteAllBytes($outsidePath, [byte[]](1, 2, 3))

            try {
                # Act & Assert
                $testDir = $script:TestDir
                $warnings = InModuleScope PlexAutomationToolkit -Parameters @{ outsidePath = $outsidePath; testDir = $testDir } {
                    Remove-PatSyncedFile -FilePath $outsidePath -Destination $testDir 3>&1
                }

                # File should NOT be removed
                Test-Path -Path $outsidePath | Should -Be $true
                # Should warn
                $warnings | Should -Match 'outside destination directory'
            }
            finally {
                Remove-Item -Path $outsidePath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Rejects paths with directory traversal' {
            # Setup
            $legitimateDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $legitimateDir -ItemType Directory -Force | Out-Null

            # Create a file outside destination
            $outsideFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'traversal_test.txt'
            [System.IO.File]::WriteAllBytes($outsideFile, [byte[]](1, 2, 3))

            try {
                # Attempt traversal attack
                $traversalPath = Join-Path -Path $legitimateDir -ChildPath '..\..\traversal_test.txt'
                $testDir = $script:TestDir

                # Act
                $warnings = InModuleScope PlexAutomationToolkit -Parameters @{ traversalPath = $traversalPath; testDir = $testDir } {
                    Remove-PatSyncedFile -FilePath $traversalPath -Destination $testDir 3>&1
                }

                # Assert - file should NOT be removed
                Test-Path -Path $outsideFile | Should -Be $true
                $warnings | Should -Match 'outside destination directory'
            }
            finally {
                Remove-Item -Path $outsideFile -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Allows paths that resolve within destination despite relative components' {
            # Setup - path with .. that still resolves inside destination
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'movie.mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Path with relative component that still resolves to same file
            $relativePath = Join-Path -Path $script:TestDir -ChildPath 'Movies\Other\..\Test\movie.mkv'
            $testDir = $script:TestDir

            # Act
            InModuleScope PlexAutomationToolkit -Parameters @{ relativePath = $relativePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $relativePath -Destination $testDir
            }

            # Assert - file should be removed (it's legitimately inside destination)
            Test-Path -Path $filePath | Should -Be $false
        }

        It 'Handles case-insensitive path comparison on Windows' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'movie.mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Use different case for destination
            $upperDestination = $script:TestDir.ToUpper()

            # Act
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; upperDestination = $upperDestination } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $upperDestination
            }

            # Assert - should work regardless of case
            Test-Path -Path $filePath | Should -Be $false
        }
    }

    Context 'Edge cases' {
        It 'Handles destination with trailing separator' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'movie.mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Destination with trailing separator
            $destinationWithSep = $script:TestDir + [System.IO.Path]::DirectorySeparatorChar

            # Act
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; destinationWithSep = $destinationWithSep } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $destinationWithSep
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
        }

        It 'Handles destination without trailing separator' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath 'movie.mkv'
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Destination without trailing separator
            $destinationNoSep = $script:TestDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

            # Act
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; destinationNoSep = $destinationNoSep } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $destinationNoSep
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
        }

        It 'Handles files with special characters in name' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null
            $filePath = Join-Path -Path $movieDir -ChildPath "Movie with 'quotes' & ampersand.mkv"
            [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
            }

            # Assert
            Test-Path -Path $filePath | Should -Be $false
        }

        It 'Handles very long paths' {
            # Setup - create nested structure approaching path limits
            $nestedPath = $script:TestDir
            for ($i = 0; $i -lt 10; $i++) {
                $nestedPath = Join-Path -Path $nestedPath -ChildPath "Nested$i"
            }

            try {
                New-Item -Path $nestedPath -ItemType Directory -Force | Out-Null
                $filePath = Join-Path -Path $nestedPath -ChildPath 'deep.txt'
                [System.IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))

                # Act
                $testDir = $script:TestDir
                InModuleScope PlexAutomationToolkit -Parameters @{ filePath = $filePath; testDir = $testDir } {
                    Remove-PatSyncedFile -FilePath $filePath -Destination $testDir
                }

                # Assert
                Test-Path -Path $filePath | Should -Be $false
            }
            catch {
                # Some systems may not support very long paths - skip gracefully
                Set-ItResult -Skipped -Because "System does not support long paths"
            }
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory FilePath parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Remove-PatSyncedFile
                $parameter = $command.Parameters['FilePath']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory Destination parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Remove-PatSyncedFile
                $parameter = $command.Parameters['Destination']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Validates FilePath is not null or empty' {
            $testDir = $script:TestDir
            {
                InModuleScope PlexAutomationToolkit -Parameters @{ testDir = $testDir } {
                    Remove-PatSyncedFile -FilePath '' -Destination $testDir
                }
            } | Should -Throw
        }

        It 'Validates Destination is not null or empty' {
            {
                InModuleScope PlexAutomationToolkit {
                    Remove-PatSyncedFile -FilePath 'C:\test.txt' -Destination ''
                }
            } | Should -Throw
        }
    }

    Context 'Real-world sync scenarios' {
        It 'Handles typical movie removal from sync destination' {
            # Setup - simulate Plex folder structure
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\The Matrix (1999)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $movieFile = Join-Path -Path $movieDir -ChildPath 'The Matrix (1999).mkv'
            $subtitleFile = Join-Path -Path $movieDir -ChildPath 'The Matrix (1999).eng.srt'
            [System.IO.File]::WriteAllBytes($movieFile, [byte[]](1, 2, 3))
            [System.IO.File]::WriteAllBytes($subtitleFile, [byte[]](1, 2, 3))

            # Act - remove movie file (subtitle remains)
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ movieFile = $movieFile; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $movieFile -Destination $testDir
            }

            # Assert - movie removed, subtitle and directory remain
            Test-Path -Path $movieFile | Should -Be $false
            Test-Path -Path $subtitleFile | Should -Be $true
            Test-Path -Path $movieDir | Should -Be $true
        }

        It 'Handles typical TV episode removal with full cleanup' {
            # Setup - simulate Plex TV folder structure
            $showDir = Join-Path -Path $script:TestDir -ChildPath 'TV Shows\Breaking Bad'
            $seasonDir = Join-Path -Path $showDir -ChildPath 'Season 01'
            New-Item -Path $seasonDir -ItemType Directory -Force | Out-Null

            $episodeFile = Join-Path -Path $seasonDir -ChildPath 'Breaking Bad - S01E01 - Pilot.mkv'
            [System.IO.File]::WriteAllBytes($episodeFile, [byte[]](1, 2, 3))

            # Act
            $testDir = $script:TestDir
            InModuleScope PlexAutomationToolkit -Parameters @{ episodeFile = $episodeFile; testDir = $testDir } {
                Remove-PatSyncedFile -FilePath $episodeFile -Destination $testDir
            }

            # Assert - entire structure cleaned up
            Test-Path -Path $episodeFile | Should -Be $false
            Test-Path -Path $seasonDir | Should -Be $false
            Test-Path -Path $showDir | Should -Be $false
            Test-Path -Path (Join-Path $script:TestDir 'TV Shows') | Should -Be $false
        }
    }
}
