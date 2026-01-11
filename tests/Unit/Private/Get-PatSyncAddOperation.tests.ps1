BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Create temp directory for test files
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatSyncAddTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PatSyncAddOperation' {
    BeforeEach {
        # Clean up test directory before each test
        Get-ChildItem -Path $script:TestDir -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'File does not exist (needs download)' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "Movies\$($MediaInfo.Title) ($($MediaInfo.Year))\$($MediaInfo.Title) ($($MediaInfo.Year)).$Extension"
            }
        }

        It 'Returns add operation when file does not exist' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'The Matrix'
                Type             = 'movie'
                Year             = 1999
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 5GB
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -Not -BeNullOrEmpty
            $result.RatingKey | Should -Be 1001
            $result.Title | Should -Be 'The Matrix'
        }

        It 'Returns operation with correct destination path' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Inception'
                Type             = 'movie'
                Year             = 2010
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 4GB
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.DestinationPath | Should -Match 'Inception \(2010\)'
            $result.DestinationPath | Should -Match '\.mkv$'
        }

        It 'Returns operation with correct media size' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1234567890
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.MediaSize | Should -Be 1234567890
        }
    }

    Context 'File exists with correct size (no download needed)' {
        It 'Returns null when file exists with matching size' {
            # Setup - create directory structure and file
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Test Movie (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $filePath = Join-Path -Path $movieDir -ChildPath 'Test Movie (2020).mkv'
            $bytes = [byte[]]::new(1000)
            [System.IO.File]::WriteAllBytes($filePath, $bytes)

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                $movieDir = Join-Path -Path $BasePath -ChildPath 'Movies\Test Movie (2020)'
                return Join-Path -Path $movieDir -ChildPath 'Test Movie (2020).mkv'
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test Movie'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000  # Same as file size
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Correctly identifies existing file with matching size' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Existing (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $filePath = Join-Path -Path $movieDir -ChildPath 'Existing (2020).mkv'
            $bytes = [byte[]]::new(500)
            [System.IO.File]::WriteAllBytes($filePath, $bytes)

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                $movieDir = Join-Path -Path $BasePath -ChildPath 'Movies\Existing (2020)'
                return Join-Path -Path $movieDir -ChildPath 'Existing (2020).mkv'
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Existing'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 500
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            # When file exists with correct size, function returns null (no download needed)
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'File exists with wrong size (needs download)' {
        It 'Returns add operation when file size does not match' {
            # Setup - create file with different size
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\Mismatch (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $filePath = Join-Path -Path $movieDir -ChildPath 'Mismatch (2020).mkv'
            $bytes = [byte[]]::new(500)  # File is 500 bytes
            [System.IO.File]::WriteAllBytes($filePath, $bytes)

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                $movieDir = Join-Path -Path $BasePath -ChildPath 'Movies\Mismatch (2020)'
                return Join-Path -Path $movieDir -ChildPath 'Mismatch (2020).mkv'
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Mismatch'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000  # Expected size is 1000
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -Not -BeNullOrEmpty
            $result.MediaSize | Should -Be 1000
        }

        It 'Returns operation with expected size when local file has different size' {
            # Setup
            $movieDir = Join-Path -Path $script:TestDir -ChildPath 'Movies\SizeMismatch (2020)'
            New-Item -Path $movieDir -ItemType Directory -Force | Out-Null

            $filePath = Join-Path -Path $movieDir -ChildPath 'SizeMismatch (2020).mkv'
            $bytes = [byte[]]::new(100)  # Local file is 100 bytes
            [System.IO.File]::WriteAllBytes($filePath, $bytes)

            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                $movieDir = Join-Path -Path $BasePath -ChildPath 'Movies\SizeMismatch (2020)'
                return Join-Path -Path $movieDir -ChildPath 'SizeMismatch (2020).mkv'
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'SizeMismatch'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 200  # Server reports 200 bytes
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            # Size mismatch triggers download, so operation is returned
            $result | Should -Not -BeNullOrEmpty
            $result.MediaSize | Should -Be 200
        }
    }

    Context 'Null/missing media info handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                return 'C:\test\movie.mkv'
            }
        }

        It 'Returns null when Media array is null' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'No Media'
                Type      = 'movie'
                Year      = 2020
                Media     = $null
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when Media array is empty' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'Empty Media'
                Type      = 'movie'
                Year      = 2020
                Media     = @()
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when Part array is null' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'No Parts'
                Type      = 'movie'
                Year      = 2020
                Media     = @(
                    [PSCustomObject]@{
                        Part = $null
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Returns null when Part array is empty' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'Empty Parts'
                Type      = 'movie'
                Year      = 2020
                Media     = @(
                    [PSCustomObject]@{
                        Part = @()
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Handles missing media files gracefully' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'Missing Media'
                Type      = 'movie'
                Year      = 2020
                Media     = @()
            }

            $testDir = $script:TestDir

            # Function returns null when no media files are found
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }

        It 'Handles missing media parts gracefully' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'Missing Parts'
                Type      = 'movie'
                Year      = 2020
                Media     = @(
                    [PSCustomObject]@{
                        Part = @()
                    }
                )
            }

            $testDir = $script:TestDir

            # Function returns null when no media parts are found
            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Subtitle counting' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "Movies\Test\Test.$Extension"
            }
        }

        It 'Counts external subtitles correctly' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'With Subtitles'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @(
                                    [PSCustomObject]@{ StreamType = 3; External = $true },
                                    [PSCustomObject]@{ StreamType = 3; External = $true },
                                    [PSCustomObject]@{ StreamType = 3; External = $true }
                                )
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.SubtitleCount | Should -Be 3
        }

        It 'Does not count embedded subtitles' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Embedded Subs'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @(
                                    [PSCustomObject]@{ StreamType = 3; External = $false },  # Embedded
                                    [PSCustomObject]@{ StreamType = 3; External = $true }    # External
                                )
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.SubtitleCount | Should -Be 1
        }

        It 'Does not count non-subtitle streams' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Mixed Streams'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @(
                                    [PSCustomObject]@{ StreamType = 1; External = $false },  # Video
                                    [PSCustomObject]@{ StreamType = 2; External = $false },  # Audio
                                    [PSCustomObject]@{ StreamType = 3; External = $true },   # Subtitle
                                    [PSCustomObject]@{ StreamType = 4; External = $false }   # Other
                                )
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.SubtitleCount | Should -Be 1
        }

        It 'Returns 0 when no streams exist' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'No Streams'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = $null
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.SubtitleCount | Should -Be 0
        }

        It 'Returns 0 when streams array is empty' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Empty Streams'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.SubtitleCount | Should -Be 0
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory MediaInfo parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncAddOperation
                $parameter = $command.Parameters['MediaInfo']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Has mandatory BasePath parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncAddOperation
                $parameter = $command.Parameters['BasePath']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'BasePath validates not null or empty' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatSyncAddOperation
                $parameter = $command.Parameters['BasePath']

                $validateAttribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] }
                $validateAttribute | Should -Not -BeNullOrEmpty
            }
        }

        It 'Throws on empty BasePath' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey = 1001
                Title     = 'Test'
                Media     = @()
            }

            {
                InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo } {
                    Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath ''
                }
            } | Should -Throw
        }
    }

    Context 'Operation object structure' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "Movies\Test (2020)\Test (2020).$Extension"
            }
        }

        It 'Returns operation with correct PSTypeName' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.PSObject.TypeNames | Should -Contain 'PlexAutomationToolkit.SyncAddOperation'
        }

        It 'Returns operation with all required properties' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Full Movie'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/5678'
                                Size      = 5000000000
                                Container = 'mp4'
                                Streams   = @(
                                    [PSCustomObject]@{ StreamType = 3; External = $true }
                                )
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.RatingKey | Should -Be 1001
            $result.Title | Should -Be 'Full Movie'
            $result.Type | Should -Be 'movie'
            $result.Year | Should -Be 2020
            $result.DestinationPath | Should -Not -BeNullOrEmpty
            $result.MediaSize | Should -Be 5000000000
            $result.SubtitleCount | Should -Be 1
            $result.PartKey | Should -Be '/library/parts/5678'
            $result.Container | Should -Be 'mp4'
        }

        It 'Includes TV show metadata for episodes' {
            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 2001
                Title            = 'Pilot'
                Type             = 'episode'
                Year             = $null
                GrandparentTitle = 'Breaking Bad'
                ParentIndex      = 1
                Index            = 1
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/9999'
                                Size      = 1GB
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.GrandparentTitle | Should -Be 'Breaking Bad'
            $result.ParentIndex | Should -Be 1
            $result.Index | Should -Be 1
        }
    }

    Context 'Container/extension handling' {
        It 'Uses Container from part when available' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "test.$Extension"
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = 'mp4'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.Container | Should -Be 'mp4'
            $result.DestinationPath | Should -Match '\.mp4$'
        }

        It 'Defaults to mkv when Container is null' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "test.$Extension"
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = $null
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.DestinationPath | Should -Match '\.mkv$'
        }

        It 'Defaults to mkv when Container is empty string' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "test.$Extension"
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Test'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/1234'
                                Size      = 1000
                                Container = ''
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.DestinationPath | Should -Match '\.mkv$'
        }
    }

    Context 'First media version selection' {
        It 'Uses first media version when multiple versions exist' {
            Mock -ModuleName PlexAutomationToolkit Get-PatMediaPath {
                param($MediaInfo, $BasePath, $Extension)
                return Join-Path -Path $BasePath -ChildPath "test.$Extension"
            }

            $mediaInfo = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Multi Version'
                Type             = 'movie'
                Year             = 2020
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                Media            = @(
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/first'
                                Size      = 1000
                                Container = 'mkv'
                                Streams   = @()
                            }
                        )
                    },
                    [PSCustomObject]@{
                        Part = @(
                            [PSCustomObject]@{
                                Key       = '/library/parts/second'
                                Size      = 2000
                                Container = 'mp4'
                                Streams   = @()
                            }
                        )
                    }
                )
            }

            $testDir = $script:TestDir

            $result = InModuleScope PlexAutomationToolkit -Parameters @{ mediaInfo = $mediaInfo; testDir = $testDir } {
                Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath $testDir
            }

            $result.PartKey | Should -Be '/library/parts/first'
            $result.MediaSize | Should -Be 1000
        }
    }
}
