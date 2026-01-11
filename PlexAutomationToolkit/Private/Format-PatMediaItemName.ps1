function Format-PatMediaItemName {
    <#
    .SYNOPSIS
        Formats a media item as a human-readable display name.

    .DESCRIPTION
        Internal helper function that converts a media item object to a human-readable
        string for display in progress bars, logs, and user messages. Handles both
        movies and TV episodes with appropriate formatting.

    .PARAMETER Item
        The media item object to format. Must have a Type property, and either:
        - For movies: Title and Year properties
        - For episodes: GrandparentTitle (show name), ParentIndex (season), and Index (episode)

    .OUTPUTS
        System.String
        Returns a formatted string representing the media item.
        - Movies: "Title (Year)" e.g., "The Matrix (1999)"
        - Episodes: "Show - S01E05" e.g., "Breaking Bad - S01E05"

    .EXAMPLE
        $movie = [PSCustomObject]@{ Type = 'movie'; Title = 'Inception'; Year = 2010 }
        Format-PatMediaItemName -Item $movie
        Returns: "Inception (2010)"

    .EXAMPLE
        $episode = [PSCustomObject]@{ Type = 'episode'; GrandparentTitle = 'The Office'; ParentIndex = 3; Index = 12 }
        Format-PatMediaItemName -Item $episode
        Returns: "The Office - S03E12"

    .EXAMPLE
        $items | Format-PatMediaItemName
        Formats multiple items via pipeline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        $Item
    )

    process {
        if ($Item.Type -eq 'episode') {
            $show = if ($Item.GrandparentTitle) { $Item.GrandparentTitle } else { 'Unknown Show' }
            $season = if ($null -ne $Item.ParentIndex) { $Item.ParentIndex.ToString('D2') } else { '00' }
            $episode = if ($null -ne $Item.Index) { $Item.Index.ToString('D2') } else { '00' }
            "$show - S${season}E${episode}"
        }
        else {
            $title = if ($Item.Title) { $Item.Title } else { 'Unknown' }
            $year = if ($Item.Year) { $Item.Year } else { '?' }
            "$title ($year)"
        }
    }
}
