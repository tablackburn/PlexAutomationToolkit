function Get-WatchStatusMatchKey {
    <#
    .SYNOPSIS
        Generates a normalized match key for comparing watch status across servers.

    .DESCRIPTION
        Internal helper function that creates a consistent key for matching media items
        between different Plex servers. Normalizes titles by converting to lowercase,
        trimming whitespace, and removing special characters to improve matching accuracy.

    .PARAMETER Type
        The type of media item: 'movie' or 'episode'.

    .PARAMETER Title
        The title of the item (used for movies).

    .PARAMETER Year
        The release year (used for movies).

    .PARAMETER ShowName
        The name of the TV show (used for episodes).

    .PARAMETER Season
        The season number (used for episodes).

    .PARAMETER Episode
        The episode number (used for episodes).

    .OUTPUTS
        System.String
        A normalized match key in the format:
        - Movies: "movie|<normalized_title>|<year>"
        - Episodes: "episode|<normalized_show>|S<season>E<episode>"

    .EXAMPLE
        Get-WatchStatusMatchKey -Type 'movie' -Title 'The Matrix' -Year 1999

        Returns: "movie|the matrix|1999"

    .EXAMPLE
        Get-WatchStatusMatchKey -Type 'episode' -ShowName 'Breaking Bad' -Season 1 -Episode 1

        Returns: "episode|breaking bad|S1E1"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('movie', 'episode')]
        [string]
        $Type,

        [Parameter(Mandatory = $false)]
        [string]
        $Title,

        [Parameter(Mandatory = $false)]
        [int]
        $Year,

        [Parameter(Mandatory = $false)]
        [string]
        $ShowName,

        [Parameter(Mandatory = $false)]
        [int]
        $Season,

        [Parameter(Mandatory = $false)]
        [int]
        $Episode
    )

    process {
        # Normalize title for comparison
        $normalizedTitle = if ($Title) {
            $Title.ToLowerInvariant().Trim() -replace '[^\w\s]', ''
        }
        else { '' }

        if ($Type -eq 'movie') {
            return "movie|$normalizedTitle|$Year"
        }
        else {
            # Type is 'episode' (guaranteed by ValidateSet)
            $normalizedShow = if ($ShowName) {
                $ShowName.ToLowerInvariant().Trim() -replace '[^\w\s]', ''
            }
            else { '' }
            return "episode|$normalizedShow|S${Season}E${Episode}"
        }
    }
}
