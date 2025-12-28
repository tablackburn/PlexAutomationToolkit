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

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

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
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'parameterName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandAst',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Query,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Strip leading quotes for matching (case-insensitive)
            $quoteChar = ''
            $strippedWord = $wordToComplete
            if ($wordToComplete -match "^([`"'])(.*)$") {
                $quoteChar = $Matches[1]
                $strippedWord = $Matches[2]
            }

            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                try {
                    $sections = Get-PatLibrary -ServerUri $fakeBoundParameters['ServerUri'] -ErrorAction 'SilentlyContinue'
                    foreach ($sectionTitle in $sections.Directory.title) {
                        if ($sectionTitle -ilike "$strippedWord*") {
                            if ($quoteChar) { $completionText = "$quoteChar$sectionTitle$quoteChar" }
                            elseif ($sectionTitle -match '\s') { $completionText = "'$sectionTitle'" }
                            else { $completionText = $sectionTitle }
                            [System.Management.Automation.CompletionResult]::new($completionText, $sectionTitle, 'ParameterValue', $sectionTitle)
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionName: $($_.Exception.Message)"
                }
            }
            else {
                try {
                    $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                    foreach ($sectionTitle in $sections.Directory.title) {
                        if ($sectionTitle -ilike "$strippedWord*") {
                            if ($quoteChar) { $completionText = "$quoteChar$sectionTitle$quoteChar" }
                            elseif ($sectionTitle -match '\s') { $completionText = "'$sectionTitle'" }
                            else { $completionText = $sectionTitle }
                            [System.Management.Automation.CompletionResult]::new($completionText, $sectionTitle, 'ParameterValue', $sectionTitle)
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionName (default server): $($_.Exception.Message)"
                }
            }
        })]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Strip leading quotes for matching
            $strippedWord = $wordToComplete -replace "^[`"']", ''

            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                try {
                    $sections = Get-PatLibrary -ServerUri $fakeBoundParameters['ServerUri'] -ErrorAction 'SilentlyContinue'
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -ilike "$strippedWord*") {
                            [System.Management.Automation.CompletionResult]::new($sectionId, "$sectionId - $($_.title)", 'ParameterValue', "$($_.title) (ID: $sectionId)")
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId: $($_.Exception.Message)"
                }
            }
            else {
                try {
                    $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -ilike "$strippedWord*") {
                            [System.Management.Automation.CompletionResult]::new($sectionId, "$sectionId - $($_.title)", 'ParameterValue', "$($_.title) (ID: $sectionId)")
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId (default server): $($_.Exception.Message)"
                }
            }
        })]
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
        $script:serverContext = Resolve-PatServerContext -ServerUri $ServerUri
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
            $queryParams = @(
                "query=$([System.Uri]::EscapeDataString($Query))"
                "limit=$Limit"
            )
            if ($resolvedSectionId) {
                $queryParams += "sectionId=$resolvedSectionId"
            }
            $queryString = $queryParams -join '&'

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
                            PSTypeName  = 'PlexAutomationToolkit.SearchResult'
                            Type        = $hub.type
                            RatingKey   = if ($item.ratingKey) { [int]$item.ratingKey } else { $null }
                            Title       = $item.title
                            Year        = if ($item.year) { [int]$item.year } else { $null }
                            Summary     = $item.summary
                            Thumb       = $item.thumb
                            LibraryId   = $itemLibraryId
                            LibraryName = $itemLibraryName
                            ServerUri   = $effectiveUri
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
