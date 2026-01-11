function Search-PatMedia {
    <#
    .SYNOPSIS
        Searches for media items across Plex libraries.

    .DESCRIPTION
        Searches for media items (movies, TV shows, music, etc.) across all or specific
        Plex library sections using the Plex search API. Returns flattened results
        with type information for easy filtering and pipeline operations.

    .PARAMETER Query
        The search term to find matching media items.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER SectionName
        Limit search to a specific library section by name (e.g., "Movies", "TV Shows").

    .PARAMETER SectionId
        Limit search to a specific library section by ID.

    .PARAMETER Type
        Filter results by media type(s). Valid values: movie, show, season, episode,
        artist, album, track, photo, collection.

    .PARAMETER Limit
        Maximum number of results to return per media type. Defaults to 10.

    .EXAMPLE
        Search-PatMedia -Query "matrix"

        Searches for "matrix" across all libraries on the default server.

    .EXAMPLE
        Search-PatMedia -Query "action" -SectionName "Movies"

        Searches for "action" only in the Movies library.

    .EXAMPLE
        Search-PatMedia -Query "beatles" -Type artist,album

        Searches for "beatles" and returns only artist and album results.

    .EXAMPLE
        Search-PatMedia -Query "star" -Limit 5

        Searches for "star" with a maximum of 5 results per type.

    .EXAMPLE
        Search-PatMedia -Query "favorites" -Type movie | Get-PatMediaInfo

        Searches for movies matching "favorites" and gets detailed media info.

    .OUTPUTS
        PSCustomObject[]
        Returns an array of search result objects with properties:
        - Type: The media type (movie, show, episode, artist, etc.)
        - RatingKey: Unique identifier for the media item
        - Title: Title of the media item
        - Year: Release year (if applicable)
        - Summary: Description of the media item
        - Thumb: Thumbnail image path
        - LibraryId: ID of the library section containing this item
        - LibraryName: Name of the library section
        - ServerUri: URI of the Plex server
        - Duration: Duration in milliseconds (if applicable)
        - DurationFormatted: Human-readable duration (e.g., "2h 16m")
        - ContentRating: Age rating (e.g., "PG-13", "R", "TV-MA")
        - Rating: Critic/Plex rating (0-10)
        - AudienceRating: Audience rating (0-10)
        - Studio: Production company/studio
        - ViewCount: Number of times watched
        - OriginallyAvailableAt: Original release date
        - ShowName: TV show name (for episodes only)
        - Season: Season number (for episodes only)
        - Episode: Episode number (for episodes only)
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter(Mandatory = $false)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('movie', 'show', 'season', 'episode', 'artist', 'album', 'track', 'photo', 'collection')]
        [string[]]
        $Type,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]
        $Limit = 10
    )

    begin {
        $script:serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers
    }

    process {
        try {
            # Resolve SectionName to SectionId if needed
            $resolvedSectionId = $null
            $resolvedSectionName = $null

            if ($SectionId) {
                $resolvedSectionId = $SectionId
                # Get section name for output
                if ($script:serverContext.WasExplicitUri) {
                    $sections = Get-PatLibrary -ServerUri $effectiveUri -ErrorAction 'SilentlyContinue'
                }
                else {
                    $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                }
                $matchingSection = $sections.Directory | Where-Object { ($_.key -replace '.*/(\d+)$', '$1') -eq $resolvedSectionId.ToString() }
                $resolvedSectionName = $matchingSection.title
            }
            elseif ($SectionName) {
                if ($script:serverContext.WasExplicitUri) {
                    $sections = Get-PatLibrary -ServerUri $effectiveUri -ErrorAction 'Stop'
                }
                else {
                    $sections = Get-PatLibrary -ErrorAction 'Stop'
                }
                $matchingSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
                if (-not $matchingSection) {
                    throw "Library section '$SectionName' not found"
                }
                $resolvedSectionId = [int]($matchingSection.key -replace '.*/(\d+)$', '$1')
                $resolvedSectionName = $SectionName
                Write-Verbose "Resolved section name '$SectionName' to ID $resolvedSectionId"
            }

            # Build query string
            $queryParameters = @(
                "query=$([System.Uri]::EscapeDataString($Query))"
                "limit=$Limit"
            )
            if ($resolvedSectionId) {
                $queryParameters += "sectionId=$resolvedSectionId"
            }
            $queryString = $queryParameters -join '&'

            $endpoint = '/hubs/search'
            Write-Verbose "Searching for '$Query' (limit: $Limit)"

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryString
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Process and flatten hub results
            if ($result.Hub) {
                foreach ($hub in $result.Hub) {
                    # Skip if type filter is specified and this hub doesn't match
                    if ($Type -and $hub.type -notin $Type) {
                        continue
                    }

                    # Skip empty hubs
                    if (-not $hub.Metadata) {
                        continue
                    }

                    foreach ($item in $hub.Metadata) {
                        # Extract library info from the item if available
                        $itemLibraryId = if ($item.librarySectionID) { [int]$item.librarySectionID } elseif ($resolvedSectionId) { $resolvedSectionId } else { $null }
                        $itemLibraryName = if ($item.librarySectionTitle) { $item.librarySectionTitle } elseif ($resolvedSectionName) { $resolvedSectionName } else { $null }

                        [PSCustomObject]@{
                            PSTypeName            = 'PlexAutomationToolkit.SearchResult'
                            Type                  = $hub.type
                            RatingKey             = if ($item.ratingKey) { [int]$item.ratingKey } else { $null }
                            Title                 = $item.title
                            Year                  = if ($item.year) { [int]$item.year } else { $null }
                            Summary               = $item.summary
                            Thumb                 = $item.thumb
                            LibraryId             = $itemLibraryId
                            LibraryName           = $itemLibraryName
                            ServerUri             = $effectiveUri
                            Duration              = if ($item.duration) { [long]$item.duration } else { $null }
                            DurationFormatted     = Format-PatDuration -Milliseconds $item.duration
                            ContentRating         = $item.contentRating
                            Rating                = if ($item.rating) { [decimal]$item.rating } else { $null }
                            AudienceRating        = if ($item.audienceRating) { [decimal]$item.audienceRating } else { $null }
                            Studio                = $item.studio
                            ViewCount             = if ($item.viewCount) { [int]$item.viewCount } else { 0 }
                            OriginallyAvailableAt = if ($item.originallyAvailableAt) { [datetime]$item.originallyAvailableAt } else { $null }
                            ShowName              = $item.grandparentTitle
                            Season                = if ($item.parentIndex) { [int]$item.parentIndex } else { $null }
                            Episode               = if ($item.index) { [int]$item.index } else { $null }
                        }
                    }
                }
            }
            else {
                Write-Verbose "No search results found for '$Query'"
            }
        }
        catch {
            throw "Search failed: $($_.Exception.Message)"
        }
    }
}
