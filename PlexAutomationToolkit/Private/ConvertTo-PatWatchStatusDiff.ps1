function ConvertTo-PatWatchStatusDiff {
    <#
    .SYNOPSIS
        Creates a watch status difference object.

    .DESCRIPTION
        Internal helper function that creates a standardized WatchStatusDiff object
        representing the difference in watch status between source and target servers.

    .PARAMETER Type
        The type of media item: 'movie' or 'episode'.

    .PARAMETER Title
        The title of the item.

    .PARAMETER Year
        The release year (for movies, null for episodes).

    .PARAMETER ShowName
        The TV show name (for episodes, null for movies).

    .PARAMETER Season
        The season number (for episodes, null for movies).

    .PARAMETER Episode
        The episode number (for episodes, null for movies).

    .PARAMETER SourceWatched
        Whether the item is watched on the source server.

    .PARAMETER TargetWatched
        Whether the item is watched on the target server.

    .PARAMETER SourceViewCount
        The view count on the source server.

    .PARAMETER TargetViewCount
        The view count on the target server.

    .PARAMETER SourceRatingKey
        The rating key on the source server.

    .PARAMETER TargetRatingKey
        The rating key on the target server.

    .OUTPUTS
        PlexAutomationToolkit.WatchStatusDiff
        A typed object representing the watch status difference.

    .EXAMPLE
        ConvertTo-PatWatchStatusDiff -Type 'movie' -Title 'The Matrix' -Year 1999 `
            -SourceWatched $true -TargetWatched $false `
            -SourceViewCount 2 -TargetViewCount 0 `
            -SourceRatingKey 123 -TargetRatingKey 456

        Creates a diff object for a movie that is watched on source but not target.

    .EXAMPLE
        ConvertTo-PatWatchStatusDiff -Type 'episode' -Title 'Pilot' `
            -ShowName 'Breaking Bad' -Season 1 -Episode 1 `
            -SourceWatched $false -TargetWatched $true `
            -SourceViewCount 0 -TargetViewCount 1 `
            -SourceRatingKey 789 -TargetRatingKey 101

        Creates a diff object for an episode that is watched on target but not source.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('movie', 'episode')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Title,

        [Parameter(Mandatory = $false)]
        [Nullable[int]]
        $Year,

        [Parameter(Mandatory = $false)]
        [string]
        $ShowName,

        [Parameter(Mandatory = $false)]
        [Nullable[int]]
        $Season,

        [Parameter(Mandatory = $false)]
        [Nullable[int]]
        $Episode,

        [Parameter(Mandatory = $true)]
        [bool]
        $SourceWatched,

        [Parameter(Mandatory = $true)]
        [bool]
        $TargetWatched,

        [Parameter(Mandatory = $true)]
        [int]
        $SourceViewCount,

        [Parameter(Mandatory = $true)]
        [int]
        $TargetViewCount,

        [Parameter(Mandatory = $true)]
        [int]
        $SourceRatingKey,

        [Parameter(Mandatory = $true)]
        [int]
        $TargetRatingKey
    )

    process {
        [PSCustomObject]@{
            PSTypeName      = 'PlexAutomationToolkit.WatchStatusDiff'
            Title           = $Title
            Type            = $Type
            Year            = $Year
            ShowName        = $ShowName
            Season          = $Season
            Episode         = $Episode
            SourceWatched   = $SourceWatched
            TargetWatched   = $TargetWatched
            SourceViewCount = $SourceViewCount
            TargetViewCount = $TargetViewCount
            SourceRatingKey = $SourceRatingKey
            TargetRatingKey = $TargetRatingKey
        }
    }
}
