BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:FormatByteSize = & (Get-Module PlexAutomationToolkit) { Get-Command Format-ByteSize }
}

Describe 'Format-ByteSize' {
    Context 'Bytes range (0 - 1023)' {
        It 'Returns "0 bytes" for zero' {
            $result = & $script:FormatByteSize -Bytes 0
            $result | Should -Be '0 bytes'
        }

        It 'Returns "1 bytes" for 1 byte' {
            $result = & $script:FormatByteSize -Bytes 1
            $result | Should -Be '1 bytes'
        }

        It 'Returns "500 bytes" for 500 bytes' {
            $result = & $script:FormatByteSize -Bytes 500
            $result | Should -Be '500 bytes'
        }

        It 'Returns "1023 bytes" for 1023 bytes' {
            $result = & $script:FormatByteSize -Bytes 1023
            $result | Should -Be '1023 bytes'
        }
    }

    Context 'Kilobytes range (1KB - 1023KB)' {
        It 'Returns "1 KB" for exactly 1KB' {
            $result = & $script:FormatByteSize -Bytes 1KB
            $result | Should -Be '1 KB'
        }

        It 'Returns "256 KB" for 256KB' {
            $result = & $script:FormatByteSize -Bytes (256 * 1KB)
            $result | Should -Be '256 KB'
        }

        It 'Returns "1,023 KB" for 1023KB' {
            $result = & $script:FormatByteSize -Bytes (1023 * 1KB)
            $result | Should -Be '1,023 KB'
        }
    }

    Context 'Megabytes range (1MB - 1023MB)' {
        It 'Returns "1.0 MB" for exactly 1MB' {
            $result = & $script:FormatByteSize -Bytes 1MB
            $result | Should -Be '1.0 MB'
        }

        It 'Returns "5.0 MB" for 5MB' {
            $result = & $script:FormatByteSize -Bytes (5 * 1MB)
            $result | Should -Be '5.0 MB'
        }

        It 'Returns "500.0 MB" for 500MB' {
            $result = & $script:FormatByteSize -Bytes (500 * 1MB)
            $result | Should -Be '500.0 MB'
        }

        It 'Includes decimal for fractional MB' {
            $result = & $script:FormatByteSize -Bytes (1.5 * 1MB)
            $result | Should -Be '1.5 MB'
        }
    }

    Context 'Gigabytes range (1GB - 1023GB)' {
        It 'Returns "1.00 GB" for exactly 1GB' {
            $result = & $script:FormatByteSize -Bytes 1GB
            $result | Should -Be '1.00 GB'
        }

        It 'Returns "4.00 GB" for 4GB' {
            $result = & $script:FormatByteSize -Bytes (4 * 1GB)
            $result | Should -Be '4.00 GB'
        }

        It 'Returns "500.00 GB" for 500GB' {
            $result = & $script:FormatByteSize -Bytes (500 * 1GB)
            $result | Should -Be '500.00 GB'
        }

        It 'Includes two decimals for fractional GB' {
            $result = & $script:FormatByteSize -Bytes (1.75 * 1GB)
            $result | Should -Be '1.75 GB'
        }
    }

    Context 'Terabytes range (1TB+)' {
        It 'Returns "1.00 TB" for exactly 1TB' {
            $result = & $script:FormatByteSize -Bytes 1TB
            $result | Should -Be '1.00 TB'
        }

        It 'Returns "2.50 TB" for 2.5TB' {
            $result = & $script:FormatByteSize -Bytes (2.5 * 1TB)
            $result | Should -Be '2.50 TB'
        }

        It 'Handles very large sizes' {
            $result = & $script:FormatByteSize -Bytes (100 * 1TB)
            $result | Should -Be '100.00 TB'
        }

        It 'Handles maximum long value without overflow' {
            # [long]::MaxValue = 9223372036854775807 bytes ≈ 8388608 TB
            $result = & $script:FormatByteSize -Bytes ([long]::MaxValue)
            $result | Should -Match '^\d{1,3}(,\d{3})*(\.\d{2})? TB$'
            # Verify the numeric value is reasonable (should be ~8.39 million TB)
            $numericPart = [decimal]($result -replace '[^\d.]', '')
            $numericPart | Should -BeGreaterThan 8000000
            $numericPart | Should -BeLessThan 9000000
        }
    }

    Context 'Boundary values' {
        It 'Returns KB at exactly 1024 bytes' {
            $result = & $script:FormatByteSize -Bytes 1024
            $result | Should -Be '1 KB'
        }

        It 'Returns MB at exactly 1MB' {
            $result = & $script:FormatByteSize -Bytes (1024 * 1024)
            $result | Should -Be '1.0 MB'
        }

        It 'Returns GB at exactly 1GB' {
            $result = & $script:FormatByteSize -Bytes (1024 * 1024 * 1024)
            $result | Should -Be '1.00 GB'
        }

        It 'Returns TB at exactly 1TB' {
            $result = & $script:FormatByteSize -Bytes (1024 * 1024 * 1024 * 1024)
            $result | Should -Be '1.00 TB'
        }
    }

    Context 'Pipeline support' {
        It 'Accepts pipeline input' {
            $result = 1GB | & $script:FormatByteSize
            $result | Should -Be '1.00 GB'
        }

        It 'Processes multiple pipeline items' {
            $results = @(1KB, 1MB, 1GB) | & $script:FormatByteSize
            $results | Should -HaveCount 3
            $results[0] | Should -Be '1 KB'
            $results[1] | Should -Be '1.0 MB'
            $results[2] | Should -Be '1.00 GB'
        }
    }

    Context 'Real-world file sizes' {
        It 'Formats typical document size' {
            # 2.5 MB document
            $result = & $script:FormatByteSize -Bytes 2621440
            $result | Should -Be '2.5 MB'
        }

        It 'Formats typical video file size' {
            # 4.7 GB DVD
            $result = & $script:FormatByteSize -Bytes 5046586573
            $result | Should -Be '4.70 GB'
        }

        It 'Formats typical music file size' {
            # 8 MB MP3
            $result = & $script:FormatByteSize -Bytes 8388608
            $result | Should -Be '8.0 MB'
        }

        It 'Formats typical 4K movie size' {
            # 50 GB Blu-ray
            $result = & $script:FormatByteSize -Bytes (50 * 1GB)
            $result | Should -Be '50.00 GB'
        }
    }

    Context 'Parameter validation' {
        It 'Throws for negative bytes' {
            { & $script:FormatByteSize -Bytes -1 } | Should -Throw
        }

        It 'Accepts zero as valid input' {
            { & $script:FormatByteSize -Bytes 0 } | Should -Not -Throw
        }

        It 'Has mandatory Bytes parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Format-ByteSize }
            $parameter = $command.Parameters['Bytes']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }
    }
}
