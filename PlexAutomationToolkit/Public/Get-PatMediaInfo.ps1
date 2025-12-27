function Get-PatMediaInfo {
    <#
    .SYNOPSIS
        Retrieves detailed media information from a Plex server.

    .DESCRIPTION
        Gets comprehensive metadata for a media item including file paths, sizes, codecs,
        and subtitle streams. This information is essential for downloading media files
        and their associated subtitles.

    .PARAMETER RatingKey
        The unique identifier (ratingKey) of the media item to retrieve.
        This is the Plex internal ID for movies, episodes, or other media.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .EXAMPLE
        Get-PatMediaInfo -RatingKey 12345

        Retrieves detailed media information for the item with ratingKey 12345.

    .EXAMPLE
        Get-PatPlaylist -PlaylistName 'Travel' -IncludeItems | Select-Object -ExpandProperty Items | Get-PatMediaInfo

        Retrieves media info for all items in the 'Travel' playlist.

    .EXAMPLE
        12345, 67890 | Get-PatMediaInfo

        Retrieves media info for multiple items via pipeline.

    .OUTPUTS
        PlexAutomationToolkit.MediaInfo

        Objects with properties:
        - RatingKey: Unique media identifier
        - Title: Media title
        - Type: 'movie' or 'episode'
        - Year: Release year (movies)
        - GrandparentTitle: Show name (episodes)
        - ParentIndex: Season number (episodes)
        - Index: Episode number (episodes)
        - Duration: Duration in milliseconds
        - ViewCount: Number of times watched
        - LastViewedAt: Last watched timestamp
        - Media: Array of media versions with file info
        - ServerUri: The Plex server URI
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $RatingKey,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri
    )

    begin {
        # Use default server if ServerUri not specified
        $server = $null
        $effectiveUri = $ServerUri
        if (-not $ServerUri) {
            try {
                $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
                if (-not $server) {
                    throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
                }
                $effectiveUri = $server.uri
                Write-Verbose "Using default server: $effectiveUri"
            }
            catch {
                throw "Failed to get default server: $($_.Exception.Message)"
            }
        }
        else {
            Write-Verbose "Using specified server: $effectiveUri"
        }

        # Build headers with authentication if we have server object
        $headers = if ($server) {
            Get-PatAuthHeaders -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }
    }

    process {
        try {
            $endpoint = "/library/metadata/$RatingKey"
            Write-Verbose "Retrieving media info for ratingKey $RatingKey from $effectiveUri"

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Handle response - API returns Metadata array even for single item
            $metadata = if ($result.Metadata) {
                $result.Metadata | Select-Object -First 1
            }
            else {
                $result
            }

            if (-not $metadata) {
                Write-Warning "No metadata found for ratingKey $RatingKey"
                return
            }

            # Parse Media array with nested Part and Stream objects
            $mediaVersions = @()
            if ($metadata.Media) {
                foreach ($media in $metadata.Media) {
                    $parts = @()
                    if ($media.Part) {
                        foreach ($part in $media.Part) {
                            # Parse streams (video, audio, subtitles)
                            $streams = @()
                            if ($part.Stream) {
                                foreach ($stream in $part.Stream) {
                                    $streamObj = [PSCustomObject]@{
                                        PSTypeName   = 'PlexAutomationToolkit.MediaStream'
                                        StreamId     = [int]$stream.id
                                        StreamType   = [int]$stream.streamType
                                        StreamTypeId = [int]$stream.streamType
                                        Codec        = $stream.codec
                                        Language     = $stream.language
                                        LanguageCode = $stream.languageCode
                                        LanguageTag  = $stream.languageTag
                                        Title        = $stream.title
                                        DisplayTitle = $stream.displayTitle
                                        Key          = $stream.key  # For external subtitles
                                        External     = ($stream.streamType -eq 3 -and $null -ne $stream.key)
                                        Default      = ($stream.default -eq 1 -or $stream.default -eq '1')
                                        Forced       = ($stream.forced -eq 1 -or $stream.forced -eq '1')
                                        Format       = $stream.format
                                    }
                                    $streams += $streamObj
                                }
                            }

                            $partObj = [PSCustomObject]@{
                                PSTypeName = 'PlexAutomationToolkit.MediaPart'
                                PartId     = [int]$part.id
                                Key        = $part.key  # Download path: /library/parts/{id}/...
                                File       = $part.file  # Original file path on server
                                Size       = [long]$part.size
                                Container  = $part.container
                                Duration   = [long]$part.duration
                                Streams    = $streams
                            }
                            $parts += $partObj
                        }
                    }

                    $mediaObj = [PSCustomObject]@{
                        PSTypeName  = 'PlexAutomationToolkit.MediaVersion'
                        MediaId     = [int]$media.id
                        Container   = $media.container
                        VideoCodec  = $media.videoCodec
                        AudioCodec  = $media.audioCodec
                        Width       = [int]$media.width
                        Height      = [int]$media.height
                        Bitrate     = [long]$media.bitrate
                        VideoResolution = $media.videoResolution
                        AspectRatio = $media.aspectRatio
                        Part        = $parts
                    }
                    $mediaVersions += $mediaObj
                }
            }

            # Build the final MediaInfo object
            $mediaInfo = [PSCustomObject]@{
                PSTypeName       = 'PlexAutomationToolkit.MediaInfo'
                RatingKey        = [int]$metadata.ratingKey
                Key              = $metadata.key
                Guid             = $metadata.guid
                Title            = $metadata.title
                OriginalTitle    = $metadata.originalTitle
                Type             = $metadata.type
                Year             = if ($metadata.year) { [int]$metadata.year } else { $null }
                GrandparentTitle = $metadata.grandparentTitle  # Show name for episodes
                GrandparentKey   = $metadata.grandparentKey
                ParentTitle      = $metadata.parentTitle  # Season title for episodes
                ParentIndex      = if ($metadata.parentIndex) { [int]$metadata.parentIndex } else { $null }  # Season number
                Index            = if ($metadata.index) { [int]$metadata.index } else { $null }  # Episode number
                Duration         = if ($metadata.duration) { [long]$metadata.duration } else { 0 }
                Summary          = $metadata.summary
                ViewCount        = if ($metadata.viewCount) { [int]$metadata.viewCount } else { 0 }
                LastViewedAt     = if ($metadata.lastViewedAt) {
                    [DateTimeOffset]::FromUnixTimeSeconds([long]$metadata.lastViewedAt).LocalDateTime
                } else { $null }
                AddedAt          = if ($metadata.addedAt) {
                    [DateTimeOffset]::FromUnixTimeSeconds([long]$metadata.addedAt).LocalDateTime
                } else { $null }
                UpdatedAt        = if ($metadata.updatedAt) {
                    [DateTimeOffset]::FromUnixTimeSeconds([long]$metadata.updatedAt).LocalDateTime
                } else { $null }
                Media            = $mediaVersions
                ServerUri        = $effectiveUri
            }

            $mediaInfo
        }
        catch {
            throw "Failed to get media info for ratingKey $RatingKey`: $($_.Exception.Message)"
        }
    }
}
