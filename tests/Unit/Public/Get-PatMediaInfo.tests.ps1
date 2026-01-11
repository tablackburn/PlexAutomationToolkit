BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Get-PatMediaInfo' {
    BeforeAll {
        # Mock the private functions used by Get-PatMediaInfo
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

    Context 'Movie metadata retrieval' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey     = '12345'
                            key           = '/library/metadata/12345'
                            guid          = 'plex://movie/abc123'
                            title         = 'The Matrix'
                            type          = 'movie'
                            year          = 1999
                            duration      = 8160000
                            contentRating = 'R'
                            rating        = 7.7
                            summary       = 'A computer hacker learns about the true nature of reality.'
                            viewCount     = 5
                            lastViewedAt  = 1703548800
                            addedAt       = 1700000000
                            updatedAt     = 1700100000
                            Media         = @(
                                @{
                                    id              = '5001'
                                    container       = 'mkv'
                                    videoCodec      = 'h264'
                                    audioCodec      = 'aac'
                                    width           = 1920
                                    height          = 1080
                                    bitrate         = 8000
                                    videoResolution = '1080'
                                    aspectRatio     = '1.78'
                                    Part            = @(
                                        @{
                                            id        = '6001'
                                            key       = '/library/parts/6001/1389985872/file.mkv'
                                            file      = '/media/movies/The Matrix (1999)/The Matrix (1999).mkv'
                                            size      = 4521234567
                                            container = 'mkv'
                                            duration  = 8160000
                                            Stream    = @(
                                                @{
                                                    id           = '7001'
                                                    streamType   = 1
                                                    codec        = 'h264'
                                                    language     = 'English'
                                                    languageCode = 'eng'
                                                    default      = 1
                                                },
                                                @{
                                                    id           = '7002'
                                                    streamType   = 2
                                                    codec        = 'aac'
                                                    language     = 'English'
                                                    languageCode = 'eng'
                                                    default      = 1
                                                },
                                                @{
                                                    id           = '7003'
                                                    streamType   = 3
                                                    codec        = 'srt'
                                                    language     = 'English'
                                                    languageCode = 'eng'
                                                    displayTitle = 'English (SRT)'
                                                    key          = '/library/streams/7003'
                                                    default      = 0
                                                    forced       = 0
                                                }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }

        It 'Returns correct movie metadata' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result | Should -Not -BeNullOrEmpty
            $result.RatingKey | Should -Be 12345
            $result.Title | Should -Be 'The Matrix'
            $result.Type | Should -Be 'movie'
            $result.Year | Should -Be 1999
        }

        It 'Returns correct Media structure' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.Media | Should -HaveCount 1
            $result.Media[0].MediaId | Should -Be 5001
            $result.Media[0].Container | Should -Be 'mkv'
            $result.Media[0].VideoCodec | Should -Be 'h264'
            $result.Media[0].Width | Should -Be 1920
            $result.Media[0].Height | Should -Be 1080
        }

        It 'Returns correct Part structure' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.Media[0].Part | Should -HaveCount 1
            $result.Media[0].Part[0].PartId | Should -Be 6001
            $result.Media[0].Part[0].Key | Should -Be '/library/parts/6001/1389985872/file.mkv'
            $result.Media[0].Part[0].Size | Should -Be 4521234567
        }

        It 'Returns correct Stream structure including subtitles' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $streams = $result.Media[0].Part[0].Streams
            $streams | Should -HaveCount 3

            # Video stream
            $videoStream = $streams | Where-Object { $_.StreamType -eq 1 }
            $videoStream | Should -Not -BeNullOrEmpty
            $videoStream.Codec | Should -Be 'h264'

            # Audio stream
            $audioStream = $streams | Where-Object { $_.StreamType -eq 2 }
            $audioStream | Should -Not -BeNullOrEmpty
            $audioStream.Codec | Should -Be 'aac'

            # Subtitle stream
            $subtitleStream = $streams | Where-Object { $_.StreamType -eq 3 }
            $subtitleStream | Should -Not -BeNullOrEmpty
            $subtitleStream.Key | Should -Be '/library/streams/7003'
            $subtitleStream.External | Should -Be $true
        }

        It 'Converts timestamps to DateTime' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.LastViewedAt | Should -BeOfType [DateTime]
            $result.AddedAt | Should -BeOfType [DateTime]
        }

        It 'Returns ServerUri in output' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.ServerUri | Should -Be 'http://plex.test:32400'
        }

        It 'Returns formatted duration' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.Duration | Should -Be 8160000
            $result.DurationFormatted | Should -Be '2h 16m'
        }

        It 'Returns content rating and rating' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.ContentRating | Should -Be 'R'
            $result.Rating | Should -Be 7.7
        }

        It 'Returns formatted bitrate on MediaVersion' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.Media[0].Bitrate | Should -Be 8000
            $result.Media[0].BitrateFormatted | Should -Be '8.0 Mbps'
        }

        It 'Returns formatted size on MediaPart' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $result.Media[0].Part[0].Size | Should -Be 4521234567
            $result.Media[0].Part[0].SizeFormatted | Should -Be '4.21 GB'
        }

        It 'Returns stream type name on MediaStream' {
            $result = Get-PatMediaInfo -RatingKey 12345

            $streams = $result.Media[0].Part[0].Streams

            # Video stream
            $videoStream = $streams | Where-Object { $_.StreamType -eq 1 }
            $videoStream.StreamTypeName | Should -Be 'Video'

            # Audio stream
            $audioStream = $streams | Where-Object { $_.StreamType -eq 2 }
            $audioStream.StreamTypeName | Should -Be 'Audio'

            # Subtitle stream
            $subtitleStream = $streams | Where-Object { $_.StreamType -eq 3 }
            $subtitleStream.StreamTypeName | Should -Be 'Subtitle'
        }
    }

    Context 'TV Episode metadata retrieval' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey        = '54321'
                            key              = '/library/metadata/54321'
                            guid             = 'plex://episode/xyz789'
                            title            = 'Pilot'
                            type             = 'episode'
                            grandparentTitle = 'Breaking Bad'
                            grandparentKey   = '/library/metadata/50000'
                            parentTitle      = 'Season 1'
                            parentIndex      = 1
                            index            = 1
                            duration         = 3480000
                            viewCount        = 2
                            Media            = @(
                                @{
                                    id         = '5002'
                                    container  = 'mkv'
                                    videoCodec = 'h264'
                                    audioCodec = 'ac3'
                                    width      = 1920
                                    height     = 1080
                                    Part       = @(
                                        @{
                                            id        = '6002'
                                            key       = '/library/parts/6002/file.mkv'
                                            file      = '/media/tv/Breaking Bad/Season 01/S01E01.mkv'
                                            size      = 1234567890
                                            container = 'mkv'
                                            Stream    = @()
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }

        It 'Returns correct episode metadata' {
            $result = Get-PatMediaInfo -RatingKey 54321

            $result.Title | Should -Be 'Pilot'
            $result.Type | Should -Be 'episode'
            $result.GrandparentTitle | Should -Be 'Breaking Bad'
            $result.ParentIndex | Should -Be 1
            $result.Index | Should -Be 1
        }

        It 'Returns show and season information' {
            $result = Get-PatMediaInfo -RatingKey 54321

            $result.GrandparentTitle | Should -Be 'Breaking Bad'
            $result.ParentTitle | Should -Be 'Season 1'
        }
    }

    Context 'Pipeline support' {
        BeforeAll {
            $script:callCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $script:callCount++
                return @{
                    Metadata = @(
                        @{
                            ratingKey = $script:callCount.ToString()
                            title     = "Movie $script:callCount"
                            type      = 'movie'
                            year      = 2020
                            Media     = @()
                        }
                    )
                }
            }
        }

        It 'Accepts RatingKey from pipeline' {
            $result = 1 | Get-PatMediaInfo

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Processes multiple items from pipeline' {
            $script:callCount = 0
            $results = @(1, 2, 3) | Get-PatMediaInfo

            $results | Should -HaveCount 3
        }
    }

    Context 'Parameter validation' {
        It 'Throws on invalid RatingKey (zero)' {
            { Get-PatMediaInfo -RatingKey 0 } | Should -Throw
        }

        It 'Throws on invalid RatingKey (negative)' {
            { Get-PatMediaInfo -RatingKey -1 } | Should -Throw
        }
    }

    Context 'Default server handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey = '99999'
                            title     = 'Test'
                            type      = 'movie'
                            Media     = @()
                        }
                    )
                }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            $result = Get-PatMediaInfo -RatingKey 99999

            $result.ServerUri | Should -Be 'http://plex.test:32400'
            Should -Invoke -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Media with multiple versions' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey = '11111'
                            title     = 'Multi-Version Movie'
                            type      = 'movie'
                            year      = 2022
                            Media     = @(
                                @{
                                    id              = '1001'
                                    videoResolution = '1080'
                                    width           = 1920
                                    height          = 1080
                                    Part            = @(
                                        @{
                                            id   = '2001'
                                            key  = '/library/parts/2001/file.mkv'
                                            size = 5000000000
                                        }
                                    )
                                },
                                @{
                                    id              = '1002'
                                    videoResolution = '4k'
                                    width           = 3840
                                    height          = 2160
                                    Part            = @(
                                        @{
                                            id   = '2002'
                                            key  = '/library/parts/2002/file.mkv'
                                            size = 15000000000
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }

        It 'Returns all media versions' {
            $result = Get-PatMediaInfo -RatingKey 11111

            $result.Media | Should -HaveCount 2
        }

        It 'Distinguishes between resolution versions' {
            $result = Get-PatMediaInfo -RatingKey 11111

            $result.Media[0].VideoResolution | Should -Be '1080'
            $result.Media[0].Width | Should -Be 1920

            $result.Media[1].VideoResolution | Should -Be '4k'
            $result.Media[1].Width | Should -Be 3840
        }

        It 'Returns correct file sizes for each version' {
            $result = Get-PatMediaInfo -RatingKey 11111

            $result.Media[0].Part[0].Size | Should -Be 5000000000
            $result.Media[1].Part[0].Size | Should -Be 15000000000
        }
    }

    Context 'Error handling' {
        It 'Throws descriptive error when API call fails' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "Connection refused"
            }

            { Get-PatMediaInfo -RatingKey 12345 } | Should -Throw "*Failed to get media info*"
        }
    }

    Context 'Null handling for optional fields' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey = '88888'
                            title     = 'Media Without Optional Fields'
                            type      = 'movie'
                            # No duration, contentRating, rating
                            Media     = @(
                                @{
                                    id   = '8001'
                                    # No bitrate
                                    Part = @(
                                        @{
                                            id     = '9001'
                                            size   = 0
                                            Stream = @(
                                                @{
                                                    id         = '10001'
                                                    streamType = 99  # Unknown type
                                                }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }

        It 'Returns null for missing DurationFormatted' {
            $result = Get-PatMediaInfo -RatingKey 88888

            $result.Duration | Should -Be 0
            $result.DurationFormatted | Should -BeNullOrEmpty
        }

        It 'Returns null for missing ContentRating and Rating' {
            $result = Get-PatMediaInfo -RatingKey 88888

            $result.ContentRating | Should -BeNullOrEmpty
            $result.Rating | Should -BeNullOrEmpty
        }

        It 'Returns null for missing BitrateFormatted' {
            $result = Get-PatMediaInfo -RatingKey 88888

            $result.Media[0].Bitrate | Should -Be 0
            $result.Media[0].BitrateFormatted | Should -BeNullOrEmpty
        }

        It 'Handles zero size with SizeFormatted' {
            $result = Get-PatMediaInfo -RatingKey 88888

            $result.Media[0].Part[0].Size | Should -Be 0
            $result.Media[0].Part[0].SizeFormatted | Should -Be '0 bytes'
        }

        It 'Returns Unknown for unrecognized stream type' {
            $result = Get-PatMediaInfo -RatingKey 88888

            $result.Media[0].Part[0].Streams[0].StreamType | Should -Be 99
            $result.Media[0].Part[0].Streams[0].StreamTypeName | Should -Be 'Unknown'
        }
    }

    Context 'PSTypeName assignment' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return @{
                    Metadata = @(
                        @{
                            ratingKey = '77777'
                            title     = 'Typed Movie'
                            type      = 'movie'
                            Media     = @(
                                @{
                                    id   = '8001'
                                    Part = @(
                                        @{
                                            id     = '9001'
                                            Stream = @(
                                                @{
                                                    id         = '10001'
                                                    streamType = 3
                                                    key        = '/library/streams/10001'
                                                }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    )
                }
            }
        }

        It 'Assigns correct PSTypeName to MediaInfo' {
            $result = Get-PatMediaInfo -RatingKey 77777

            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.MediaInfo'
        }

        It 'Assigns correct PSTypeName to MediaVersion' {
            $result = Get-PatMediaInfo -RatingKey 77777

            $result.Media[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.MediaVersion'
        }

        It 'Assigns correct PSTypeName to MediaPart' {
            $result = Get-PatMediaInfo -RatingKey 77777

            $result.Media[0].Part[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.MediaPart'
        }

        It 'Assigns correct PSTypeName to MediaStream' {
            $result = Get-PatMediaInfo -RatingKey 77777

            $result.Media[0].Part[0].Streams[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.MediaStream'
        }
    }
}
