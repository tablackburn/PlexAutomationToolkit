function New-PatPlaylist {
    <#
    .SYNOPSIS
        Creates a new playlist on a Plex server.

    .DESCRIPTION
        Creates a new regular (non-smart) playlist on the Plex server. You can specify
        the playlist title, type (video, audio, or photo), and optionally add initial
        items during creation.

    .PARAMETER Title
        The title/name of the new playlist. Must be unique on the server.

    .PARAMETER Type
        The type of content the playlist will contain. Valid values are:
        - video (default): Movies, TV shows, or other video content
        - audio: Music tracks
        - photo: Photos

    .PARAMETER RatingKey
        One or more media item rating keys to add to the playlist upon creation.
        Rating keys can be obtained from library browsing commands.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER PassThru
        If specified, returns the created playlist object.

    .EXAMPLE
        New-PatPlaylist -Title 'My Favorites'

        Creates a new empty video playlist named 'My Favorites'.

    .EXAMPLE
        New-PatPlaylist -Title 'Road Trip Music' -Type audio

        Creates a new empty audio playlist named 'Road Trip Music'.

    .EXAMPLE
        New-PatPlaylist -Title 'Weekend Watchlist' -RatingKey 12345, 67890 -PassThru

        Creates a playlist with two initial items and returns the created playlist object.

    .EXAMPLE
        Get-PatLibraryItem -SectionId 1 | Select-Object -First 5 -ExpandProperty ratingKey |
            ForEach-Object { New-PatPlaylist -Title 'Top 5' -RatingKey $_ }

        Creates a playlist from the first 5 items in library section 1.

    .OUTPUTS
        PlexAutomationToolkit.Playlist (when -PassThru is specified)

        Returns the created playlist object with properties:
        - PlaylistId: Unique playlist identifier
        - Title: Name of the playlist
        - Type: Playlist type (video, audio, photo)
        - ItemCount: Number of items in the playlist
        - ServerUri: The Plex server URI
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Title,

        [Parameter(Mandatory = $false)]
        [ValidateSet('video', 'audio', 'photo')]
        [string]
        $Type = 'video',

        [Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int[]]
        $RatingKey,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        # Use default server if ServerUri not specified
        $server = $null
        $effectiveUri = $ServerUri
        $machineIdentifier = $null

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

        # Build headers with authentication
        $headers = if ($server) {
            Get-PatAuthHeaders -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }

        # Get machine identifier for URI construction (needed for adding items)
        try {
            $serverInfoUri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'
            $serverInfo = Invoke-PatApi -Uri $serverInfoUri -Headers $headers -ErrorAction 'Stop'
            $machineIdentifier = $serverInfo.machineIdentifier
            Write-Verbose "Server machine identifier: $machineIdentifier"
        }
        catch {
            Write-Warning "Could not retrieve server machine identifier. Adding items during creation may fail."
        }

        # Collect all rating keys from pipeline
        $allRatingKeys = [System.Collections.ArrayList]::new()
    }

    process {
        # Collect rating keys from pipeline
        if ($RatingKey) {
            foreach ($key in $RatingKey) {
                $null = $allRatingKeys.Add($key)
            }
        }
    }

    end {
        if (-not $PSCmdlet.ShouldProcess($Title, 'Create playlist')) {
            return
        }

        try {
            # Build the creation URI with query parameters
            $queryParts = @(
                "type=$Type",
                "title=$([System.Uri]::EscapeDataString($Title))",
                'smart=0'
            )

            # Add items URI if we have rating keys and a machine identifier
            if ($allRatingKeys.Count -gt 0 -and $machineIdentifier) {
                # Build the library URI format Plex expects
                # Format: server://machineIdentifier/com.plexapp.plugins.library/library/metadata/ratingKey
                $itemUris = foreach ($key in $allRatingKeys) {
                    "server://$machineIdentifier/com.plexapp.plugins.library/library/metadata/$key"
                }
                $uriParam = $itemUris -join ','
                $queryParts += "uri=$([System.Uri]::EscapeDataString($uriParam))"
            }
            elseif ($allRatingKeys.Count -gt 0 -and -not $machineIdentifier) {
                Write-Warning "Cannot add items during creation: server machine identifier not available. Use Add-PatPlaylistItem after creation."
            }

            $queryString = $queryParts -join '&'
            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/playlists' -QueryString $queryString

            Write-Verbose "Creating playlist '$Title' of type '$Type'"

            $result = Invoke-PatApi -Uri $uri -Method 'POST' -Headers $headers -ErrorAction 'Stop'

            if ($PassThru -and $result) {
                # The API returns the created playlist in Metadata array
                $playlist = if ($result.Metadata) {
                    $result.Metadata | Select-Object -First 1
                }
                else {
                    $result
                }

                [PSCustomObject]@{
                    PSTypeName  = 'PlexAutomationToolkit.Playlist'
                    PlaylistId  = [int]$playlist.ratingKey
                    Title       = $playlist.title
                    Type        = $playlist.playlistType
                    ItemCount   = [int]$playlist.leafCount
                    Duration    = [long]$playlist.duration
                    Smart       = ($playlist.smart -eq '1' -or $playlist.smart -eq 1)
                    Composite   = $playlist.composite
                    AddedAt     = if ($playlist.addedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$playlist.addedAt).LocalDateTime
                    } else { $null }
                    UpdatedAt   = if ($playlist.updatedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$playlist.updatedAt).LocalDateTime
                    } else { $null }
                    ServerUri   = $effectiveUri
                }
            }
        }
        catch {
            throw "Failed to create playlist '$Title': $($_.Exception.Message)"
        }
    }
}
