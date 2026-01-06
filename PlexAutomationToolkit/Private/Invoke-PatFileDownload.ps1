function Invoke-PatFileDownload {
    <#
    .SYNOPSIS
        Downloads a file from a Plex server.

    .DESCRIPTION
        Internal helper function that downloads binary files (media, subtitles) from
        a Plex server with progress reporting. Handles large files and supports
        resuming interrupted downloads. Shows per-file download progress when
        ExpectedSize is provided.

    .PARAMETER Uri
        The URI to download from (without authentication token in query string).

    .PARAMETER OutFile
        The destination file path.

    .PARAMETER Token
        Optional Plex authentication token. Passed via X-Plex-Token header for security.
        Prefer this over including token in Uri query string.

    .PARAMETER ExpectedSize
        Optional expected file size in bytes. Used for progress calculation and
        resume detection. When provided, enables per-file progress reporting.

    .PARAMETER Resume
        When specified, attempts to resume a partial download if the destination
        file already exists and is smaller than expected.

    .PARAMETER ProgressId
        The progress bar ID for Write-Progress. Defaults to 2 (nested under parent).
        Use different IDs to avoid conflicts with other progress bars.

    .PARAMETER ProgressParentId
        The parent progress bar ID for nested progress display. Defaults to 1.
        Set to -1 to disable nested progress.

    .PARAMETER ProgressActivity
        The activity description for Write-Progress. Defaults to 'Downloading file'.

    .OUTPUTS
        System.IO.FileInfo
        Returns the downloaded file information.

    .EXAMPLE
        Invoke-PatFileDownload -Uri "http://plex:32400/library/parts/123?download=1" -Token $token -OutFile "C:\movie.mkv"

        Downloads the file using header-based authentication (recommended).

    .EXAMPLE
        Invoke-PatFileDownload -Uri $uri -OutFile $path -Token $token -ExpectedSize 4000000000 -Resume

        Attempts to resume a partial download with authentication and progress reporting.

    .EXAMPLE
        Invoke-PatFileDownload -Uri $uri -OutFile $path -ExpectedSize 1GB -ProgressActivity 'Downloading Movie'

        Downloads with a custom progress activity description.
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
        $Resume,

        [Parameter(Mandatory = $false)]
        [int]
        $ProgressId = 2,

        [Parameter(Mandatory = $false)]
        [int]
        $ProgressParentId = 1,

        [Parameter(Mandatory = $false)]
        [string]
        $ProgressActivity = 'Downloading file'
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

    # Helper function to format bytes for display
    function Format-ByteSize {
        param([long]$Bytes)
        if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
        elseif ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
        elseif ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
        else { return '{0} bytes' -f $Bytes }
    }

    try {
        Write-Verbose "Downloading file from: $Uri"
        Write-Verbose "Destination: $OutFile"

        # Determine if we should show progress with streaming
        # Only use streaming for files > 1MB where progress reporting is meaningful
        # Smaller files download quickly and don't benefit from streaming progress
        $streamingThreshold = 1MB
        $useStreaming = $ExpectedSize -gt $streamingThreshold

        # For resume with range header, use Invoke-WebRequest (simpler for partial content)
        if ($existingSize -gt 0 -and $headers.ContainsKey('Range')) {
            $webRequestParameters = @{
                Uri             = $Uri
                Headers         = $headers
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }

            $response = Invoke-WebRequest @webRequestParameters

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
        elseif ($useStreaming) {
            # Use streaming download with progress reporting for large files
            $httpClient = $null
            $response = $null
            $contentStream = $null
            $fileStream = $null

            try {
                $httpClient = [System.Net.Http.HttpClient]::new()
                $httpClient.Timeout = [System.TimeSpan]::FromMinutes(30)

                # Add token header if provided
                if ($Token) {
                    $httpClient.DefaultRequestHeaders.Add('X-Plex-Token', $Token)
                }

                # Start the download
                $response = $httpClient.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null

                $contentStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()

                # Get content length from response headers (may differ from ExpectedSize)
                $contentLength = $response.Content.Headers.ContentLength
                $totalSize = if ($contentLength) { $contentLength } else { $ExpectedSize }

                # Open file for writing
                $fileStream = [System.IO.FileStream]::new($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 81920)

                $buffer = [byte[]]::new(81920)  # 80KB buffer
                $bytesRead = 0
                $totalBytesRead = 0
                $lastProgressUpdate = [DateTime]::MinValue
                $progressUpdateInterval = [TimeSpan]::FromMilliseconds(250)  # Update every 250ms
                $downloadStartTime = [DateTime]::UtcNow

                # Build progress parameters
                $progressParams = @{
                    Activity = $ProgressActivity
                    Id       = $ProgressId
                }
                if ($ProgressParentId -ge 0) {
                    $progressParams['ParentId'] = $ProgressParentId
                }

                while (($bytesRead = $contentStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fileStream.Write($buffer, 0, $bytesRead)
                    $totalBytesRead += $bytesRead

                    # Throttle progress updates to avoid performance impact
                    $now = [DateTime]::UtcNow
                    if (($now - $lastProgressUpdate) -ge $progressUpdateInterval) {
                        $lastProgressUpdate = $now

                        $percentComplete = [int](($totalBytesRead / $totalSize) * 100)
                        $percentComplete = [Math]::Min($percentComplete, 100)

                        # Calculate download speed
                        $elapsedSeconds = ($now - $downloadStartTime).TotalSeconds
                        $bytesPerSecond = if ($elapsedSeconds -gt 0) { $totalBytesRead / $elapsedSeconds } else { 0 }
                        $speedDisplay = Format-ByteSize -Bytes ([long]$bytesPerSecond)

                        # Estimate remaining time
                        $remainingBytes = $totalSize - $totalBytesRead
                        $secondsRemaining = if ($bytesPerSecond -gt 0) { [int]($remainingBytes / $bytesPerSecond) } else { -1 }

                        $statusMessage = "$(Format-ByteSize $totalBytesRead) / $(Format-ByteSize $totalSize) @ $speedDisplay/s"

                        Write-Progress @progressParams `
                            -Status $statusMessage `
                            -PercentComplete $percentComplete `
                            -SecondsRemaining $secondsRemaining
                    }
                }

            }
            finally {
                if ($progressParams) {
                    Write-Progress @progressParams -Completed
                }
                if ($fileStream) { $fileStream.Dispose() }
                if ($contentStream) { $contentStream.Dispose() }
                if ($response) { $response.Dispose() }
                if ($httpClient) { $httpClient.Dispose() }
            }
        }
        else {
            # No expected size - use simple Invoke-WebRequest without progress
            $webRequestParameters = @{
                Uri             = $Uri
                Headers         = $headers
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @webRequestParameters -OutFile $OutFile
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
