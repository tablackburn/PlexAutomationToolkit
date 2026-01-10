function Get-PatMediaSubtitle {
    <#
    .SYNOPSIS
        Downloads external subtitles for a media item.

    .DESCRIPTION
        Internal helper function that downloads all external subtitle files associated
        with a Plex media item. Retrieves media information to find external subtitle
        streams, then downloads each subtitle file to the same directory as the media
        file with appropriate language code and format extension.

    .PARAMETER RatingKey
        The Plex rating key of the media item to get subtitles for.

    .PARAMETER MediaDestinationPath
        The full path where the media file is saved. Subtitle files will be saved
        in the same directory with the same base name plus language and format.

    .PARAMETER ServerUri
        The base URI of the Plex server for downloading subtitle files.

    .PARAMETER Token
        The Plex authentication token for API requests.

    .PARAMETER ServerName
        The name of a stored server to use. Alternative to ServerUri/Token.

    .PARAMETER ItemDisplayName
        A display name for the media item, used in warning messages when
        subtitle downloads fail.

    .OUTPUTS
        None. Writes warnings for download failures.

    .EXAMPLE
        Get-PatMediaSubtitle -RatingKey 1001 -MediaDestinationPath 'E:\Movies\Movie (2020)\Movie (2020).mkv' `
            -ServerUri 'http://plex:32400' -Token 'abc123' -ItemDisplayName 'Movie (2020)'

        Downloads all external subtitles for the media item.

    .EXAMPLE
        Get-PatMediaSubtitle -RatingKey 1001 -MediaDestinationPath 'E:\Movies\Movie (2020)\Movie (2020).mkv' `
            -ServerName 'HomeServer' -ItemDisplayName 'Movie (2020)'

        Downloads subtitles using a stored server configuration.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $RatingKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MediaDestinationPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter()]
        [string]
        $Token,

        [Parameter()]
        [string]
        $ServerName,

        [Parameter()]
        [string]
        $ItemDisplayName
    )

    process {
        # Build parameters for Get-PatMediaInfo
        $mediaInfoParameters = @{
            RatingKey   = $RatingKey
            ErrorAction = 'Stop'
        }

        if ($ServerName) {
            $mediaInfoParameters['ServerName'] = $ServerName
        }
        else {
            $mediaInfoParameters['ServerUri'] = $ServerUri
            if ($Token) {
                $mediaInfoParameters['Token'] = $Token
            }
        }

        try {
            $mediaInformation = Get-PatMediaInfo @mediaInfoParameters
        }
        catch {
            Write-Warning "Failed to get media info for subtitle download: $($_.Exception.Message)"
            return
        }

        # Check if media has parts with streams
        if (-not $mediaInformation.Media -or -not $mediaInformation.Media[0].Part) {
            Write-Verbose "No media parts found for RatingKey $RatingKey"
            return
        }

        # Filter for external subtitle streams (StreamType 3 = subtitle, External = true, has Key for download)
        $subtitleStreams = $mediaInformation.Media[0].Part[0].Streams |
            Where-Object { $_.StreamType -eq 3 -and $_.External -and $_.Key }

        if (-not $subtitleStreams) {
            Write-Verbose "No external subtitles found for RatingKey $RatingKey"
            return
        }

        # Get base path for subtitle files (media path without extension)
        $basePath = [System.IO.Path]::ChangeExtension($MediaDestinationPath, $null).TrimEnd('.')

        foreach ($sub in $subtitleStreams) {
            $lang = if ($sub.LanguageCode) { $sub.LanguageCode } else { 'und' }
            $format = if ($sub.Format) { $sub.Format } else { 'srt' }

            $subtitlePath = "$basePath.$lang.$format"

            # Build download URL (token passed via header, not URL for security)
            $subtitleUrl = "$ServerUri$($sub.Key)?download=1"

            Write-Verbose "Downloading subtitle: $subtitlePath"

            try {
                $downloadParameters = @{
                    Uri         = $subtitleUrl
                    OutFile     = $subtitlePath
                    ErrorAction = 'Stop'
                }

                if ($Token) {
                    $downloadParameters['Token'] = $Token
                }

                Invoke-PatFileDownload @downloadParameters | Out-Null
            }
            catch {
                $displayName = if ($ItemDisplayName) { $ItemDisplayName } else { "RatingKey $RatingKey" }
                Write-Warning "Failed to download subtitle for '$displayName': $($_.Exception.Message)"
            }
        }
    }
}
