function Get-PatSyncAddOperation {
    <#
    .SYNOPSIS
        Determines if a media item needs to be downloaded and returns an add operation.

    .DESCRIPTION
        Internal helper function that analyzes a media item to determine if it needs
        to be downloaded. Checks if the file exists at the destination with the correct
        size, and if not, returns an add operation with all necessary download details.

    .PARAMETER MediaInfo
        The media information object from Get-PatMediaInfo.

    .PARAMETER BasePath
        The base destination path where media files will be synced.

    .OUTPUTS
        PSCustomObject or $null
        Returns an add operation object if download is needed, or $null if the file
        already exists with the correct size.

    .EXAMPLE
        $mediaInfo = Get-PatMediaInfo -RatingKey 1234
        $addOp = Get-PatSyncAddOperation -MediaInfo $mediaInfo -BasePath 'E:\'

        Returns an add operation if the media needs to be downloaded.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]
        $MediaInfo,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BasePath
    )

    process {
        # Validate media info has required data
        if (-not $MediaInfo.Media -or $MediaInfo.Media.Count -eq 0) {
            Write-Verbose "No media files found for '$($MediaInfo.Title)'"
            return $null
        }

        # Use the first media version (default behavior)
        $media = $MediaInfo.Media[0]
        if (-not $media.Part -or $media.Part.Count -eq 0) {
            Write-Verbose "No media parts found for '$($MediaInfo.Title)'"
            return $null
        }

        $part = $media.Part[0]

        # Determine destination path
        $extension = if ($part.Container) { $part.Container } else { 'mkv' }
        $destPath = Get-PatMediaPath -MediaInfo $MediaInfo -BasePath $BasePath -Extension $extension

        # Check if file already exists with correct size
        if (Test-Path -Path $destPath) {
            $existingFile = Get-Item -Path $destPath
            if ($existingFile.Length -eq $part.Size) {
                Write-Verbose "File already exists with correct size: $destPath"
                return $null
            }
            else {
                Write-Verbose "File exists but size mismatch: $destPath (expected $($part.Size), got $($existingFile.Length))"
            }
        }

        # Count external subtitles
        $subtitleCount = 0
        if ($part.Streams) {
            $subtitleCount = @($part.Streams | Where-Object { $_.StreamType -eq 3 -and $_.External }).Count
        }

        # Return add operation
        return [PSCustomObject]@{
            PSTypeName       = 'PlexAutomationToolkit.SyncAddOperation'
            RatingKey        = $MediaInfo.RatingKey
            Title            = $MediaInfo.Title
            Type             = $MediaInfo.Type
            Year             = $MediaInfo.Year
            GrandparentTitle = $MediaInfo.GrandparentTitle
            ParentIndex      = $MediaInfo.ParentIndex
            Index            = $MediaInfo.Index
            DestinationPath  = $destPath
            MediaSize        = $part.Size
            SubtitleCount    = $subtitleCount
            PartKey          = $part.Key
            Container        = $part.Container
        }
    }
}
