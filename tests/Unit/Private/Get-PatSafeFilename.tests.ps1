BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:GetPatSafeFilename = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatSafeFilename }
}

Describe 'Get-PatSafeFilename' {
    Context 'Basic functionality' {
        It 'Returns the same string when no invalid characters are present' {
            $result = & $script:GetPatSafeFilename -Name 'Valid Filename'
            $result | Should -Be 'Valid Filename'
        }

        It 'Handles empty string input' {
            $result = & $script:GetPatSafeFilename -Name ''
            $result | Should -Be ''
        }

        It 'Handles whitespace-only input' {
            $result = & $script:GetPatSafeFilename -Name '   '
            $result | Should -Be ''
        }

        It 'Handles null-equivalent input' {
            $result = & $script:GetPatSafeFilename -Name $null
            $result | Should -Be ''
        }
    }

    Context 'Invalid character removal' {
        It 'Replaces colons with dashes' {
            $result = & $script:GetPatSafeFilename -Name 'Movie: The Sequel'
            $result | Should -Be 'Movie - The Sequel'
        }

        It 'Removes less-than and greater-than symbols' {
            $result = & $script:GetPatSafeFilename -Name 'Test<>File'
            $result | Should -Be 'TestFile'
        }

        It 'Removes double quotes' {
            $result = & $script:GetPatSafeFilename -Name 'The "Best" Movie'
            $result | Should -Be 'The Best Movie'
        }

        It 'Removes forward slashes' {
            $result = & $script:GetPatSafeFilename -Name 'AC/DC Greatest Hits'
            $result | Should -Be 'ACDC Greatest Hits'
        }

        It 'Removes backslashes' {
            $result = & $script:GetPatSafeFilename -Name 'Path\To\File'
            $result | Should -Be 'PathToFile'
        }

        It 'Removes pipe characters' {
            $result = & $script:GetPatSafeFilename -Name 'Option|Choice'
            $result | Should -Be 'OptionChoice'
        }

        It 'Removes question marks' {
            $result = & $script:GetPatSafeFilename -Name 'Who Am I?'
            $result | Should -Be 'Who Am I'
        }

        It 'Removes asterisks' {
            $result = & $script:GetPatSafeFilename -Name 'Star*Wars'
            $result | Should -Be 'StarWars'
        }

        It 'Removes multiple invalid characters at once' {
            $result = & $script:GetPatSafeFilename -Name 'Movie: Part 1 "Extended" <Special>'
            $result | Should -Be 'Movie - Part 1 Extended Special'
        }
    }

    Context 'Whitespace handling' {
        It 'Trims leading whitespace' {
            $result = & $script:GetPatSafeFilename -Name '   Leading Spaces'
            $result | Should -Be 'Leading Spaces'
        }

        It 'Trims trailing whitespace' {
            $result = & $script:GetPatSafeFilename -Name 'Trailing Spaces   '
            $result | Should -Be 'Trailing Spaces'
        }

        It 'Collapses multiple spaces to single space' {
            $result = & $script:GetPatSafeFilename -Name 'Multiple    Spaces    Here'
            $result | Should -Be 'Multiple Spaces Here'
        }

        It 'Removes trailing periods' {
            $result = & $script:GetPatSafeFilename -Name 'Filename...'
            $result | Should -Be 'Filename'
        }
    }

    Context 'Length limiting' {
        It 'Limits filename to default MaxLength of 200' {
            $longName = 'A' * 250
            $result = & $script:GetPatSafeFilename -Name $longName
            $result.Length | Should -Be 200
        }

        It 'Respects custom MaxLength parameter' {
            $longName = 'A' * 100
            $result = & $script:GetPatSafeFilename -Name $longName -MaxLength 50
            $result.Length | Should -Be 50
        }

        It 'Does not truncate short names' {
            $result = & $script:GetPatSafeFilename -Name 'Short Name'
            $result | Should -Be 'Short Name'
        }

        It 'Trims trailing whitespace after truncation' {
            $longName = 'Word ' * 50  # Creates string with spaces
            $result = & $script:GetPatSafeFilename -Name $longName -MaxLength 50
            $result | Should -Not -Match '\s$'
        }
    }

    Context 'Real-world movie/TV titles' {
        It 'Handles typical movie title with year' {
            $result = & $script:GetPatSafeFilename -Name 'The Matrix (1999)'
            $result | Should -Be 'The Matrix (1999)'
        }

        It 'Handles TV episode format' {
            $result = & $script:GetPatSafeFilename -Name 'Breaking Bad - S01E01 - Pilot'
            $result | Should -Be 'Breaking Bad - S01E01 - Pilot'
        }

        It 'Handles title with colon' {
            $result = & $script:GetPatSafeFilename -Name 'Star Wars: Episode IV - A New Hope'
            $result | Should -Be 'Star Wars - Episode IV - A New Hope'
        }

        It 'Handles title with special characters' {
            $result = & $script:GetPatSafeFilename -Name 'Schindler''s List (1993)'
            $result | Should -Be 'Schindler''s List (1993)'
        }

        It 'Handles foreign characters' {
            $result = & $script:GetPatSafeFilename -Name 'Amelie (2001)'
            $result | Should -Be 'Amelie (2001)'
        }
    }

    Context 'Pipeline support' {
        It 'Accepts pipeline input' {
            $result = 'Test:File' | & $script:GetPatSafeFilename
            $result | Should -Be 'Test - File'
        }

        It 'Processes multiple pipeline items' {
            $results = @('File:One', 'File<Two>') | & $script:GetPatSafeFilename
            $results[0] | Should -Be 'File - One'
            $results[1] | Should -Be 'FileTwo'
        }
    }

    Context 'Edge cases' {
        It 'Returns Untitled when all characters are invalid' {
            $result = & $script:GetPatSafeFilename -Name ':<>|?*'
            $result | Should -Be 'Untitled'
        }

        It 'Returns Untitled when result would be only periods' {
            $result = & $script:GetPatSafeFilename -Name '...'
            $result | Should -Be 'Untitled'
        }

        It 'Handles single character input' {
            $result = & $script:GetPatSafeFilename -Name 'A'
            $result | Should -Be 'A'
        }

        It 'Handles numeric-only input' {
            $result = & $script:GetPatSafeFilename -Name '12345'
            $result | Should -Be '12345'
        }
    }
}
