BeforeDiscovery {
    # These tests don't require Plex credentials - they test downloading from public URLs
    $script:integrationEnabled = $true
    Write-Host "File download integration tests ENABLED" -ForegroundColor Green
}

BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Create test directory
    $script:TestDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PatDownloadTests_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null

    # Get reference to private function
    $script:InvokePatFileDownload = & (Get-Module PlexAutomationToolkit) { Get-Command Invoke-PatFileDownload }

    # Pre-generate test data buffers to reduce memory churn
    # Use deterministic seed for reproducible tests
    $script:TestData2MB = [byte[]]::new(2MB)
    [System.Random]::new(42).NextBytes($script:TestData2MB)

    $script:TestData1MBPlus = [byte[]]::new(1MB + 1024)
    [System.Random]::new(43).NextBytes($script:TestData1MBPlus)

    $script:TestData500KB = [byte[]]::new(500KB)
    [System.Random]::new(44).NextBytes($script:TestData500KB)

    $script:TestData1KB = [byte[]]::new(1024)
    [System.Random]::new(45).NextBytes($script:TestData1KB)

    # Helper function to find an available port dynamically
    function Get-AvailablePort {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
        return $port
    }

    # Helper function to wait for server to be ready with polling
    function Wait-ServerReady {
        param(
            [int]$Port,
            [int]$TimeoutMs = 5000,
            [int]$PollIntervalMs = 50
        )

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($stopwatch.ElapsedMilliseconds -lt $TimeoutMs) {
            try {
                $client = [System.Net.Sockets.TcpClient]::new()
                $result = $client.BeginConnect('localhost', $Port, $null, $null)
                $success = $result.AsyncWaitHandle.WaitOne(100)
                if ($success) {
                    $client.EndConnect($result)
                    $client.Close()
                    return $true
                }
                $client.Close()
            }
            catch {
                # Server not ready yet
            }
            Start-Sleep -Milliseconds $PollIntervalMs
        }
        return $false
    }

    # Helper function to start a test HTTP server as a background job
    # Returns job and captured request info
    function Start-TestHttpServerJob {
        param(
            [int]$Port,
            [byte[]]$ResponseData,
            [int]$StatusCode = 200,
            [switch]$CaptureHeaders
        )

        $job = Start-Job -ScriptBlock {
            param($port, $data, $statusCode, $captureHeaders)

            $result = @{
                ReceivedHeaders = @{}
                Success = $false
            }

            $listener = [System.Net.HttpListener]::new()
            $listener.Prefixes.Add("http://localhost:$port/")

            try {
                $listener.Start()

                # Use async with timeout to prevent hanging
                $contextTask = $listener.GetContextAsync()
                if (-not $contextTask.Wait(30000)) {
                    throw "Timeout waiting for request"
                }

                $context = $contextTask.Result
                $request = $context.Request
                $response = $context.Response

                # Capture headers if requested
                if ($captureHeaders) {
                    foreach ($key in $request.Headers.AllKeys) {
                        $result.ReceivedHeaders[$key] = $request.Headers[$key]
                    }
                }

                $response.StatusCode = $statusCode

                if ($statusCode -eq 200 -and $data -and $data.Length -gt 0) {
                    $response.ContentLength64 = $data.Length
                    $response.OutputStream.Write($data, 0, $data.Length)
                }

                $response.Close()
                $result.Success = $true
            }
            catch {
                $result.Error = $_.Exception.Message
            }
            finally {
                $listener.Stop()
                $listener.Close()
            }

            return $result
        } -ArgumentList $Port, $ResponseData, $StatusCode, $CaptureHeaders.IsPresent

        # Wait for server to be ready with polling
        $ready = Wait-ServerReady -Port $Port -TimeoutMs 5000
        if (-not $ready) {
            Write-Warning "Server may not be ready on port $Port"
        }

        return $job
    }
}

AfterAll {
    # Clean up test directory
    if ($script:TestDir -and (Test-Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-PatFileDownload Streaming Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeEach {
        # Get a fresh port for each test to avoid conflicts
        $script:TestPort = Get-AvailablePort
    }

    AfterEach {
        # Clean up downloaded files after each test
        Get-ChildItem -Path $script:TestDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Context 'Streaming download with large files' {
        # These tests verify the HttpClient streaming path which triggers when ExpectedSize > 1MB

        It 'Downloads a 2MB file using streaming path' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData2MB
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'streaming-2mb.bin'

            try {
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true
                $fileInfo = Get-Item -Path $outFile
                $fileInfo.Length | Should -Be 2MB
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Downloads a file just over the 1MB threshold using streaming' {
            $testSize = 1MB + 1024
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData1MBPlus
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'streaming-1mb-plus.bin'

            try {
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize $testSize

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true
                $fileInfo = Get-Item -Path $outFile
                $fileInfo.Length | Should -Be $testSize
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Verifies downloaded content integrity for streaming download' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData2MB
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'streaming-verify.bin'

            try {
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB

                $result.Length | Should -Be 2MB

                # Verify content matches the pre-generated test data
                $downloadedData = [System.IO.File]::ReadAllBytes($outFile)
                $downloadedData.Length | Should -Be 2MB

                # Compare first and last bytes to verify integrity
                $downloadedData[0] | Should -Be $script:TestData2MB[0]
                $downloadedData[1000] | Should -Be $script:TestData2MB[1000]
                $downloadedData[-1] | Should -Be $script:TestData2MB[-1]
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Measures download performance for streaming path' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData2MB
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'streaming-perf.bin'

            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB
                $stopwatch.Stop()

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true
                # Download should complete in reasonable time (under 30 seconds for local)
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Non-streaming download for small files' {

        # Skip on PS 5.1: Invoke-WebRequest has connection issues with HttpListener in jobs for larger payloads
        It 'Downloads a small file using Invoke-WebRequest path' -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
            $testSize = 500KB
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData500KB
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'small-file.bin'

            try {
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize $testSize

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true
                $fileInfo = Get-Item -Path $outFile
                $fileInfo.Length | Should -Be $testSize
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Downloads without ExpectedSize using Invoke-WebRequest path' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData1KB
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'no-size.bin'

            try {
                # No ExpectedSize means streaming won't be used
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true
                $fileInfo = Get-Item -Path $outFile
                $fileInfo.Length | Should -Be 1024
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Error handling in streaming downloads' {

        It 'Throws on HTTP 404 error during streaming download' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData @() -StatusCode 404
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'error-404.bin'

            try {
                { & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB } |
                    Should -Throw '*Failed to download*'

                # Verify partial file was cleaned up or not created
                Test-Path -Path $outFile | Should -Be $false
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Throws on HTTP 500 error during streaming download' {
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData @() -StatusCode 500
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'error-500.bin'

            try {
                { & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB } |
                    Should -Throw '*Failed to download*'

                # Verify partial file was cleaned up or not created
                Test-Path -Path $outFile | Should -Be $false
            }
            finally {
                $job | Wait-Job -Timeout 10 | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Streaming with authentication token' {

        It 'Includes X-Plex-Token header in streaming request' {
            $testToken = 'test-token-12345'
            $job = Start-TestHttpServerJob -Port $script:TestPort -ResponseData $script:TestData2MB -CaptureHeaders
            $uri = "http://localhost:$($script:TestPort)/"
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'streaming-auth.bin'

            try {
                $result = & $script:InvokePatFileDownload -Uri $uri -OutFile $outFile -ExpectedSize 2MB -Token $testToken

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $outFile | Should -Be $true

                # Wait for job to complete and verify headers were captured
                $jobResult = $job | Wait-Job -Timeout 10 | Receive-Job
                $jobResult.Success | Should -Be $true
                $jobResult.ReceivedHeaders['X-Plex-Token'] | Should -Be $testToken
            }
            finally {
                $job | Remove-Job -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
