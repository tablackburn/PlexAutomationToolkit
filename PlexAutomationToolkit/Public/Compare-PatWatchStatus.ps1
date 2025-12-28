function Compare-PatWatchStatus {
    <#
    .SYNOPSIS
        Compares watch status between two Plex servers.

    .DESCRIPTION
        Queries both source and target Plex servers and identifies items with different
        watch status. Matches items by title and year for movies, and by show name,
        season, and episode number for TV episodes.

    .PARAMETER SourceServerName
        The name of the source server (as stored with Add-PatServer).

    .PARAMETER TargetServerName
        The name of the target server (as stored with Add-PatServer).

    .PARAMETER SectionId
        Optional array of library section IDs to compare. If not specified, compares all sections.

    .PARAMETER WatchedOnSourceOnly
        When specified, only returns items that are watched on source but not on target.

    .PARAMETER WatchedOnTargetOnly
        When specified, only returns items that are watched on target but not on source.

    .EXAMPLE
        Compare-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home'

        Compares watch status between the Travel and Home servers.

    .EXAMPLE
        Compare-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WatchedOnSourceOnly

        Shows items watched on Travel server but not on Home server.

    .OUTPUTS
        PlexAutomationToolkit.WatchStatusDiff

        Objects with properties:
        - Title: Item title
        - Type: 'movie' or 'episode'
        - Year: Release year (movies)
        - ShowName: Series name (episodes)
        - Season: Season number (episodes)
        - Episode: Episode number (episodes)
        - SourceWatched: Whether watched on source server
        - TargetWatched: Whether watched on target server
        - SourceViewCount: View count on source
        - TargetViewCount: View count on target
        - SourceRatingKey: Rating key on source server
        - TargetRatingKey: Rating key on target server
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourceServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetServerName,

        [Parameter(Mandatory = $false)]
        [int[]]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [switch]
        $WatchedOnSourceOnly,

        [Parameter(Mandatory = $false)]
        [switch]
        $WatchedOnTargetOnly
    )

    begin {
        # Get server configurations
        try {
            $sourceServer = Get-PatStoredServer -Name $SourceServerName -ErrorAction Stop
            if (-not $sourceServer) {
                throw "Source server '$SourceServerName' not found. Use Add-PatServer to configure it."
            }

            $targetServer = Get-PatStoredServer -Name $TargetServerName -ErrorAction Stop
            if (-not $targetServer) {
                throw "Target server '$TargetServerName' not found. Use Add-PatServer to configure it."
            }
        }
        catch {
            throw "Failed to get server configuration: $($_.Exception.Message)"
        }

        Write-Verbose "Comparing watch status between '$SourceServerName' and '$TargetServerName'"
    }

    process {
        try {
            # Get library sections from both servers
            $sourceSections = Get-PatLibrary -ServerUri $sourceServer.uri -ErrorAction Stop
            $targetSections = Get-PatLibrary -ServerUri $targetServer.uri -ErrorAction Stop

            if (-not $sourceSections.Directory) {
                throw "No library sections found on source server"
            }
            if (-not $targetSections.Directory) {
                throw "No library sections found on target server"
            }

            # Filter sections if specified
            $sourceSectionsToCompare = $sourceSections.Directory
            $targetSectionsToCompare = $targetSections.Directory

            if ($SectionId) {
                $sourceSectionsToCompare = $sourceSectionsToCompare | Where-Object {
                    ($_.key -replace '.*/(\d+)$', '$1') -in $SectionId
                }
                $targetSectionsToCompare = $targetSectionsToCompare | Where-Object {
                    ($_.key -replace '.*/(\d+)$', '$1') -in $SectionId
                }
            }

            # Only compare movie and show sections
            $sourceSectionsToCompare = $sourceSectionsToCompare | Where-Object { $_.type -in 'movie', 'show' }
            $targetSectionsToCompare = $targetSectionsToCompare | Where-Object { $_.type -in 'movie', 'show' }

            # Build lookup of target items by match key
            $targetItems = @{}

            foreach ($section in $targetSectionsToCompare) {
                $currentSectionId = [int]($section.key -replace '.*/(\d+)$', '$1')
                Write-Verbose "Scanning target section: $($section.title) (ID: $currentSectionId)"

                $items = Get-PatLibraryItem -SectionId $currentSectionId -ServerUri $targetServer.uri -ErrorAction SilentlyContinue

                if ($section.type -eq 'movie') {
                    foreach ($item in $items) {
                        $matchKey = Get-WatchStatusMatchKey -Type 'movie' -Title $item.title -Year $item.year
                        $targetItems[$matchKey] = @{
                            RatingKey = [int]$item.ratingKey
                            Title     = $item.title
                            Year      = $item.year
                            ViewCount = if ($item.viewCount) { [int]$item.viewCount } else { 0 }
                            Watched   = ($item.viewCount -gt 0)
                        }
                    }
                }
                elseif ($section.type -eq 'show') {
                    # For TV shows, we need to get episodes
                    foreach ($show in $items) {
                        $showRatingKey = $show.ratingKey
                        $showTitle = $show.title

                        # Get all episodes for this show
                        $episodesUri = Join-PatUri -BaseUri $targetServer.uri -Endpoint "/library/metadata/$showRatingKey/allLeaves"
                        $headers = Get-PatAuthenticationHeader -Server $targetServer
                        $episodesResult = Invoke-PatApi -Uri $episodesUri -Headers $headers -ErrorAction SilentlyContinue

                        if ($episodesResult.Metadata) {
                            foreach ($ep in $episodesResult.Metadata) {
                                $matchKey = Get-WatchStatusMatchKey -Type 'episode' -ShowName $showTitle `
                                    -Season $ep.parentIndex -Episode $ep.index

                                $targetItems[$matchKey] = @{
                                    RatingKey = [int]$ep.ratingKey
                                    Title     = $ep.title
                                    ShowName  = $showTitle
                                    Season    = [int]$ep.parentIndex
                                    Episode   = [int]$ep.index
                                    ViewCount = if ($ep.viewCount) { [int]$ep.viewCount } else { 0 }
                                    Watched   = ($ep.viewCount -gt 0)
                                }
                            }
                        }
                    }
                }
            }

            Write-Verbose "Found $($targetItems.Count) items on target server"

            # Compare source items against target
            $differences = @()

            foreach ($section in $sourceSectionsToCompare) {
                $currentSectionId = [int]($section.key -replace '.*/(\d+)$', '$1')
                Write-Verbose "Scanning source section: $($section.title) (ID: $currentSectionId)"

                $items = Get-PatLibraryItem -SectionId $currentSectionId -ServerUri $sourceServer.uri -ErrorAction SilentlyContinue

                if ($section.type -eq 'movie') {
                    foreach ($item in $items) {
                        $matchKey = Get-WatchStatusMatchKey -Type 'movie' -Title $item.title -Year $item.year
                        $sourceWatched = ($item.viewCount -gt 0)
                        $sourceViewCount = if ($item.viewCount) { [int]$item.viewCount } else { 0 }

                        if ($targetItems.ContainsKey($matchKey)) {
                            $target = $targetItems[$matchKey]

                            # Check if watch status differs
                            if ($sourceWatched -ne $target.Watched) {
                                # Apply filters
                                if ($WatchedOnSourceOnly -and -not ($sourceWatched -and -not $target.Watched)) {
                                    continue
                                }
                                if ($WatchedOnTargetOnly -and -not (-not $sourceWatched -and $target.Watched)) {
                                    continue
                                }

                                $differences += [PSCustomObject]@{
                                    PSTypeName       = 'PlexAutomationToolkit.WatchStatusDiff'
                                    Title            = $item.title
                                    Type             = 'movie'
                                    Year             = $item.year
                                    ShowName         = $null
                                    Season           = $null
                                    Episode          = $null
                                    SourceWatched    = $sourceWatched
                                    TargetWatched    = $target.Watched
                                    SourceViewCount  = $sourceViewCount
                                    TargetViewCount  = $target.ViewCount
                                    SourceRatingKey  = [int]$item.ratingKey
                                    TargetRatingKey  = $target.RatingKey
                                }
                            }
                        }
                    }
                }
                elseif ($section.type -eq 'show') {
                    foreach ($show in $items) {
                        $showRatingKey = $show.ratingKey
                        $showTitle = $show.title

                        # Get all episodes for this show
                        $episodesUri = Join-PatUri -BaseUri $sourceServer.uri -Endpoint "/library/metadata/$showRatingKey/allLeaves"
                        $headers = Get-PatAuthenticationHeader -Server $sourceServer
                        $episodesResult = Invoke-PatApi -Uri $episodesUri -Headers $headers -ErrorAction SilentlyContinue

                        if ($episodesResult.Metadata) {
                            foreach ($ep in $episodesResult.Metadata) {
                                $matchKey = Get-WatchStatusMatchKey -Type 'episode' -ShowName $showTitle `
                                    -Season $ep.parentIndex -Episode $ep.index

                                $sourceWatched = ($ep.viewCount -gt 0)
                                $sourceViewCount = if ($ep.viewCount) { [int]$ep.viewCount } else { 0 }

                                if ($targetItems.ContainsKey($matchKey)) {
                                    $target = $targetItems[$matchKey]

                                    if ($sourceWatched -ne $target.Watched) {
                                        # Apply filters
                                        if ($WatchedOnSourceOnly -and -not ($sourceWatched -and -not $target.Watched)) {
                                            continue
                                        }
                                        if ($WatchedOnTargetOnly -and -not (-not $sourceWatched -and $target.Watched)) {
                                            continue
                                        }

                                        $differences += [PSCustomObject]@{
                                            PSTypeName       = 'PlexAutomationToolkit.WatchStatusDiff'
                                            Title            = $ep.title
                                            Type             = 'episode'
                                            Year             = $null
                                            ShowName         = $showTitle
                                            Season           = [int]$ep.parentIndex
                                            Episode          = [int]$ep.index
                                            SourceWatched    = $sourceWatched
                                            TargetWatched    = $target.Watched
                                            SourceViewCount  = $sourceViewCount
                                            TargetViewCount  = $target.ViewCount
                                            SourceRatingKey  = [int]$ep.ratingKey
                                            TargetRatingKey  = $target.RatingKey
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Write-Verbose "Found $($differences.Count) items with different watch status"

            if ($differences.Count -eq 0) {
                $filterMsg = if ($WatchedOnSourceOnly) { " (filtered: watched on source only)" }
                             elseif ($WatchedOnTargetOnly) { " (filtered: watched on target only)" }
                             else { "" }
                Write-Information "Watch status is in sync between '$SourceServerName' and '$TargetServerName'$filterMsg" -InformationAction Continue
            }
            else {
                Write-Information "Found $($differences.Count) items with different watch status" -InformationAction Continue
            }

            $differences
        }
        catch {
            throw "Failed to compare watch status: $($_.Exception.Message)"
        }
    }
}

# Private helper function for generating match keys
function Get-WatchStatusMatchKey {
    param (
        [string]$Type,
        [string]$Title,
        [int]$Year,
        [string]$ShowName,
        [int]$Season,
        [int]$Episode
    )

    # Normalize title for comparison
    $normalizedTitle = if ($Title) {
        $Title.ToLowerInvariant().Trim() -replace '[^\w\s]', ''
    } else { '' }

    if ($Type -eq 'movie') {
        return "movie|$normalizedTitle|$Year"
    }
    elseif ($Type -eq 'episode') {
        $normalizedShow = if ($ShowName) {
            $ShowName.ToLowerInvariant().Trim() -replace '[^\w\s]', ''
        } else { '' }
        return "episode|$normalizedShow|S${Season}E${Episode}"
    }

    return "unknown|$normalizedTitle"
}
