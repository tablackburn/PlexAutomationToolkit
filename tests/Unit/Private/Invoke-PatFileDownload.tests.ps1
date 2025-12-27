BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:InvokePatFileDownload = & (Get-Module PlexAutomationToolkit) { Get-Command Invoke-PatFileDownload }

    # Create temp directory for test files
    $script:TestDir = Join-Path -Path $env:TEMP -ChildPath "PatFileDownloadTests_$([Guid]::NewGuid().ToString('N'))"
    New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Cleanup temp directory
    if ($script:TestDir -and (Test-Path -Path $script:TestDir)) {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-PatFileDownload' {
    BeforeEach {
        # Clean up test directory between tests
        Get-ChildItem -Path $script:TestDir -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Context 'Basic download functionality' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)

                if ($OutFile) {
                    # Simulate file download
                    $testContent = [byte[]](0x48, 0x65, 0x6C, 0x6C, 0x6F)  # "Hello" in bytes
                    [System.IO.File]::WriteAllBytes($OutFile, $testContent)
                }

                return [PSCustomObject]@{
                    StatusCode = 200
                    Content    = [byte[]](0x48, 0x65, 0x6C, 0x6C, 0x6F)
                }
            }
        }

        It 'Downloads file to specified path' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'test.txt'

            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile

            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $outFile | Should -Be $true
        }

        It 'Returns FileInfo object' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'test2.txt'

            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile | Select-Object -Last 1

            $result.GetType().Name | Should -Be 'FileInfo'
            $result.FullName | Should -Be $outFile
        }

        It 'Creates destination directory if it does not exist' {
            $nestedDir = Join-Path -Path $script:TestDir -ChildPath 'nested\subdir'
            $outFile = Join-Path -Path $nestedDir -ChildPath 'test.txt'

            & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile

            Test-Path -Path $nestedDir | Should -Be $true
            Test-Path -Path $outFile | Should -Be $true
        }
    }

    Context 'Resume functionality' {
        It 'Skips download when file exists with correct size' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'complete.txt'
            $testContent = [byte[]](1, 2, 3, 4, 5)
            [System.IO.File]::WriteAllBytes($outFile, $testContent)

            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest { }

            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile -ExpectedSize 5 -Resume

            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be 5
            Should -Invoke -CommandName Invoke-WebRequest -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Removes existing file when not resuming' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'overwrite.txt'
            $oldContent = [byte[]](1, 1, 1, 1, 1, 1, 1, 1, 1, 1)  # 10 bytes
            [System.IO.File]::WriteAllBytes($outFile, $oldContent)

            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)
                if ($OutFile) {
                    $newContent = [byte[]](2, 2, 2, 2, 2)  # 5 bytes
                    [System.IO.File]::WriteAllBytes($OutFile, $newContent)
                }
            }

            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile

            $result.Length | Should -Be 5
        }

        It 'Sends Range header when resuming partial download' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'partial.txt'
            $partialContent = [byte[]](1, 2, 3)  # 3 bytes partial
            [System.IO.File]::WriteAllBytes($outFile, $partialContent)

            $capturedHeaders = $null
            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)
                $script:capturedHeaders = $Headers

                return [PSCustomObject]@{
                    StatusCode = 206  # Partial Content
                    Content    = [byte[]](4, 5)  # Remaining 2 bytes
                }
            }

            & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile -ExpectedSize 5 -Resume

            $script:capturedHeaders | Should -Not -BeNullOrEmpty
            $script:capturedHeaders['Range'] | Should -Be 'bytes=3-'
        }
    }

    Context 'Error handling' {
        It 'Throws on download failure' {
            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                throw "Connection refused"
            }

            $outFile = Join-Path -Path $script:TestDir -ChildPath 'error.txt'

            { & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile } |
                Should -Throw "*Failed to download*"
        }

        It 'Cleans up partial file on error when not resuming' {
            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)
                if ($OutFile) {
                    # Create partial file before error
                    [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3))
                }
                throw "Connection reset"
            }

            $outFile = Join-Path -Path $script:TestDir -ChildPath 'cleanup.txt'

            { & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile } |
                Should -Throw

            Test-Path -Path $outFile | Should -Be $false
        }
    }

    Context 'Size verification' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)
                if ($OutFile) {
                    $content = [byte[]](1, 2, 3, 4, 5)
                    [System.IO.File]::WriteAllBytes($OutFile, $content)
                }
            }
        }

        It 'Warns when downloaded size does not match expected size' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'sizemismatch.txt'

            # Capture warnings using WarningVariable
            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile -ExpectedSize 10 -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match "does not match expected size"
        }

        It 'Does not warn when sizes match' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'sizematch.txt'

            # Download produces 5 bytes, we expect 5
            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile -ExpectedSize 5 -WarningVariable warnings 3>$null

            $warnings | Should -BeNullOrEmpty
        }
    }

    Context 'Parameter validation' {
        It 'Throws on empty Uri' {
            { & $script:InvokePatFileDownload -Uri '' -OutFile 'C:\test.txt' } |
                Should -Throw
        }

        It 'Throws on empty OutFile' {
            { & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile '' } |
                Should -Throw
        }
    }

    Context 'Server resume support' {
        It 'Falls back to full download when server does not support resume' {
            $outFile = Join-Path -Path $script:TestDir -ChildPath 'noresume.txt'
            $partialContent = [byte[]](1, 2, 3)
            [System.IO.File]::WriteAllBytes($outFile, $partialContent)

            Mock -ModuleName PlexAutomationToolkit Invoke-WebRequest {
                param($Uri, $OutFile, $Headers, $UseBasicParsing, $ErrorAction)

                # Server returns 200 (full content) instead of 206 (partial)
                return [PSCustomObject]@{
                    StatusCode = 200
                    Content    = [byte[]](1, 2, 3, 4, 5)  # Full file
                }
            }

            $result = & $script:InvokePatFileDownload -Uri 'http://test/file' -OutFile $outFile -ExpectedSize 5 -Resume

            $result.Length | Should -Be 5
        }
    }
}
