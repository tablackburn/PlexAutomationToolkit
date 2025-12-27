function Get-PatMediaPath {
    <#
    .SYNOPSIS
        Generates a Plex-compatible destination path for media files.

    .DESCRIPTION
        Internal helper function that creates a properly structured file path for media
        files that Plex can automatically recognize. Follows Plex naming conventions:
        - Movies: Movies/{Title} ({Year})/{Title} ({Year}).{ext}
        - TV Episodes: TV Shows/{Show Name}/Season {NN}/{Show Name} - S{NN}E{NN} - {Episode Title}.{ext}

    .PARAMETER MediaInfo
        A media info object containing title, type, year, and TV show metadata.
        Required properties vary by type:
        - Movies: Title, Year, Type='movie'
        - Episodes: Title, Type='episode', GrandparentTitle (show name),
                    ParentIndex (season), Index (episode number)

    .PARAMETER BasePath
        The base destination path (e.g., 'E:\' or 'D:\Media').

    .PARAMETER Extension
        The file extension to use (e.g., 'mkv', 'mp4'). Do not include the leading dot.

    .OUTPUTS
        System.String
        Returns the full destination file path.

    .EXAMPLE
        $movieInfo = [PSCustomObject]@{ Type = 'movie'; Title = 'The Matrix'; Year = 1999 }
        Get-PatMediaPath -MediaInfo $movieInfo -BasePath 'E:\' -Extension 'mkv'
        Returns: E:\Movies\The Matrix (1999)\The Matrix (1999).mkv

    .EXAMPLE
        $episodeInfo = [PSCustomObject]@{
            Type = 'episode'
            Title = 'Pilot'
            GrandparentTitle = 'Breaking Bad'
            ParentIndex = 1
            Index = 1
        }
        Get-PatMediaPath -MediaInfo $episodeInfo -BasePath 'E:\' -Extension 'mkv'
        Returns: E:\TV Shows\Breaking Bad\Season 01\Breaking Bad - S01E01 - Pilot.mkv
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]
        $MediaInfo,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BasePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension
    )

    # Normalize extension (remove leading dot if present)
    $Extension = $Extension.TrimStart('.')

    # Get safe versions of titles
    $safeTitle = Get-PatSafeFilename -Name $MediaInfo.Title

    switch ($MediaInfo.Type) {
        'movie' {
            # Movies: Movies/{Title} ({Year})/{Title} ({Year}).{ext}
            $year = if ($MediaInfo.Year) { $MediaInfo.Year } else { 'Unknown' }
            $folderName = Get-PatSafeFilename -Name "$($MediaInfo.Title) ($year)"
            $fileName = "$folderName.$Extension"

            # Use [IO.Path]::Combine to avoid drive existence check that Join-Path performs
            $path = [System.IO.Path]::Combine($BasePath, 'Movies', $folderName, $fileName)

            return $path
        }

        'episode' {
            # TV Shows: TV Shows/{Show Name}/Season {NN}/{Show Name} - S{NN}E{NN} - {Episode Title}.{ext}
            $showName = Get-PatSafeFilename -Name $MediaInfo.GrandparentTitle
            $seasonNumber = [int]$MediaInfo.ParentIndex
            $episodeNumber = [int]$MediaInfo.Index
            $episodeTitle = $safeTitle

            # Format season and episode numbers with leading zeros
            $seasonFolder = "Season {0:D2}" -f $seasonNumber
            $episodeCode = "S{0:D2}E{1:D2}" -f $seasonNumber, $episodeNumber

            # Build filename: Show Name - S01E01 - Episode Title.ext
            $fileName = "$showName - $episodeCode - $episodeTitle.$Extension"

            # Use [IO.Path]::Combine to avoid drive existence check that Join-Path performs
            $path = [System.IO.Path]::Combine($BasePath, 'TV Shows', $showName, $seasonFolder, $fileName)

            return $path
        }

        default {
            throw "Unsupported media type: $($MediaInfo.Type). Only 'movie' and 'episode' are supported."
        }
    }
}
