function Invoke-PatFileDownload {
    <#
    .SYNOPSIS
        Downloads a file from a Plex server.

    .DESCRIPTION
        Internal helper function that downloads binary files (media, subtitles) from
        a Plex server with progress reporting. Handles large files and supports
        resuming interrupted downloads.

    .PARAMETER Uri
        The URI to download from (without authentication token in query string).

    .PARAMETER OutFile
        The destination file path.

    .PARAMETER Token
        Optional Plex authentication token. Passed via X-Plex-Token header for security.
        Prefer this over including token in Uri query string.

    .PARAMETER ExpectedSize
        Optional expected file size in bytes. Used for progress calculation and
        resume detection.

    .PARAMETER Resume
        When specified, attempts to resume a partial download if the destination
        file already exists and is smaller than expected.

    .OUTPUTS
        System.IO.FileInfo
        Returns the downloaded file information.

    .EXAMPLE
        Invoke-PatFileDownload -Uri "http://plex:32400/library/parts/123?download=1" -Token $token -OutFile "C:\movie.mkv"

        Downloads the file using header-based authentication (recommended).

    .EXAMPLE
        Invoke-PatFileDownload -Uri $uri -OutFile $path -Token $token -ExpectedSize 4000000000 -Resume

        Attempts to resume a partial download with authentication.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutFile,

        [Parameter(Mandatory = $false)]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [long]
        $ExpectedSize = 0,

        [Parameter(Mandatory = $false)]
        [switch]
        $Resume
    )

    # Ensure destination directory exists
    $destinationDir = Split-Path -Path $OutFile -Parent
    if ($destinationDir -and -not (Test-Path -Path $destinationDir)) {
        Write-Verbose "Creating destination directory: $destinationDir"
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
    }

    # Check for existing partial download
    $existingSize = 0
    $headers = @{}

    # Add authentication token to headers if provided (more secure than URL query string)
    if ($Token) {
        $headers['X-Plex-Token'] = $Token
    }

    if ($Resume -and (Test-Path -Path $OutFile)) {
        $existingFile = Get-Item -Path $OutFile
        $existingSize = $existingFile.Length

        # If we have expected size and existing file matches, skip download
        if ($ExpectedSize -gt 0 -and $existingSize -eq $ExpectedSize) {
            Write-Verbose "File already exists with correct size, skipping download"
            return $existingFile
        }

        # If existing file is smaller than expected, attempt resume
        if ($ExpectedSize -gt 0 -and $existingSize -lt $ExpectedSize) {
            Write-Verbose "Resuming download from byte $existingSize"
            $headers['Range'] = "bytes=$existingSize-"
        }
        elseif ($existingSize -gt 0) {
            # Existing file is larger or we don't know expected size - start fresh
            Write-Verbose "Existing file size mismatch, starting fresh download"
            Remove-Item -Path $OutFile -Force
            $existingSize = 0
        }
    }
    elseif (Test-Path -Path $OutFile) {
        # Not resuming, remove existing file
        Remove-Item -Path $OutFile -Force
    }

    try {
        Write-Verbose "Downloading file from: $Uri"
        Write-Verbose "Destination: $OutFile"

        $webRequestParams = @{
            Uri                = $Uri
            Headers            = $headers
            UseBasicParsing    = $true
            ErrorAction        = 'Stop'
        }

        # For resume, we need to handle the response differently
        if ($existingSize -gt 0 -and $headers.ContainsKey('Range')) {
            # Resuming - append to existing file
            $response = Invoke-WebRequest @webRequestParams

            # Check if server supports range requests (206 Partial Content)
            if ($response.StatusCode -eq 206) {
                # Append to existing file using proper resource disposal
                $fileStream = $null
                try {
                    $fileStream = [System.IO.FileStream]::new($OutFile, [System.IO.FileMode]::Append)
                    $fileStream.Write($response.Content, 0, $response.Content.Length)
                    Write-Verbose "Appended $($response.Content.Length) bytes to existing file"
                }
                finally {
                    if ($fileStream) {
                        $fileStream.Dispose()
                    }
                }
            }
            else {
                # Server doesn't support range requests, save full response
                Write-Verbose "Server does not support resume, downloading full file"
                [System.IO.File]::WriteAllBytes($OutFile, $response.Content)
            }
        }
        else {
            # Fresh download - use -OutFile for efficient streaming
            Invoke-WebRequest @webRequestParams -OutFile $OutFile
        }

        # Verify download
        if (-not (Test-Path -Path $OutFile)) {
            throw "Download completed but file not found at: $OutFile"
        }

        $downloadedFile = Get-Item -Path $OutFile

        # Verify size if expected size was provided
        if ($ExpectedSize -gt 0 -and $downloadedFile.Length -ne $ExpectedSize) {
            Write-Warning "Downloaded file size ($($downloadedFile.Length)) does not match expected size ($ExpectedSize)"
        }

        Write-Verbose "Download completed: $($downloadedFile.Length) bytes"
        return $downloadedFile
    }
    catch {
        # Clean up partial download on error (unless resuming)
        if (-not $Resume -and (Test-Path -Path $OutFile)) {
            Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue
        }

        throw "Failed to download file: $($_.Exception.Message)"
    }
}
