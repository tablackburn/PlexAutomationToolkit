BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:FormatPatMediaItemName = & (Get-Module PlexAutomationToolkit) { Get-Command Format-PatMediaItemName }
}

Describe 'Format-PatMediaItemName' {
    Context 'Movie formatting' {
        It 'Formats movie with title and year' {
            $movie = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Inception'
                Year  = 2010
            }

            $result = & $script:FormatPatMediaItemName -Item $movie

            $result | Should -Be 'Inception (2010)'
        }

        It 'Handles movie with special characters in title' {
            $movie = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Scott Pilgrim vs. the World'
                Year  = 2010
            }

            $result = & $script:FormatPatMediaItemName -Item $movie

            $result | Should -Be 'Scott Pilgrim vs. the World (2010)'
        }

        It 'Handles movie with colon in title' {
            $movie = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Star Wars: Episode IV - A New Hope'
                Year  = 1977
            }

            $result = & $script:FormatPatMediaItemName -Item $movie

            $result | Should -Be 'Star Wars: Episode IV - A New Hope (1977)'
        }

        It 'Handles older movies' {
            $movie = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Casablanca'
                Year  = 1942
            }

            $result = & $script:FormatPatMediaItemName -Item $movie

            $result | Should -Be 'Casablanca (1942)'
        }
    }

    Context 'Episode formatting' {
        It 'Formats episode with show name, season, and episode' {
            $episode = [PSCustomObject]@{
                Type             = 'episode'
                GrandparentTitle = 'Breaking Bad'
                ParentIndex      = 1
                Index            = 5
            }

            $result = & $script:FormatPatMediaItemName -Item $episode

            $result | Should -Be 'Breaking Bad - S01E05'
        }

        It 'Zero-pads single digit season numbers' {
            $episode = [PSCustomObject]@{
                Type             = 'episode'
                GrandparentTitle = 'The Office'
                ParentIndex      = 3
                Index            = 7
            }

            $result = & $script:FormatPatMediaItemName -Item $episode

            $result | Should -Be 'The Office - S03E07'
        }

        It 'Zero-pads single digit episode numbers' {
            $episode = [PSCustomObject]@{
                Type             = 'episode'
                GrandparentTitle = 'Friends'
                ParentIndex      = 10
                Index            = 1
            }

            $result = & $script:FormatPatMediaItemName -Item $episode

            $result | Should -Be 'Friends - S10E01'
        }

        It 'Handles double digit season and episode numbers' {
            $episode = [PSCustomObject]@{
                Type             = 'episode'
                GrandparentTitle = 'The Simpsons'
                ParentIndex      = 35
                Index            = 22
            }

            $result = & $script:FormatPatMediaItemName -Item $episode

            $result | Should -Be 'The Simpsons - S35E22'
        }

        It 'Handles show name with special characters' {
            $episode = [PSCustomObject]@{
                Type             = 'episode'
                GrandparentTitle = "Grey's Anatomy"
                ParentIndex      = 5
                Index            = 10
            }

            $result = & $script:FormatPatMediaItemName -Item $episode

            $result | Should -Be "Grey's Anatomy - S05E10"
        }
    }

    Context 'Default type handling' {
        It 'Uses movie format for unknown types' {
            $item = [PSCustomObject]@{
                Type  = 'track'
                Title = 'Some Song'
                Year  = 2020
            }

            $result = & $script:FormatPatMediaItemName -Item $item

            $result | Should -Be 'Some Song (2020)'
        }

        It 'Uses movie format when Type is null' {
            $item = [PSCustomObject]@{
                Type  = $null
                Title = 'Unknown Item'
                Year  = 2023
            }

            $result = & $script:FormatPatMediaItemName -Item $item

            $result | Should -Be 'Unknown Item (2023)'
        }
    }

    Context 'Pipeline support' {
        It 'Accepts pipeline input' {
            $movie = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'The Matrix'
                Year  = 1999
            }

            $result = $movie | & $script:FormatPatMediaItemName

            $result | Should -Be 'The Matrix (1999)'
        }

        It 'Processes multiple pipeline items' {
            $items = @(
                [PSCustomObject]@{ Type = 'movie'; Title = 'Movie One'; Year = 2020 }
                [PSCustomObject]@{ Type = 'episode'; GrandparentTitle = 'Show'; ParentIndex = 1; Index = 1 }
                [PSCustomObject]@{ Type = 'movie'; Title = 'Movie Two'; Year = 2021 }
            )

            $results = $items | & $script:FormatPatMediaItemName

            $results | Should -HaveCount 3
            $results[0] | Should -Be 'Movie One (2020)'
            $results[1] | Should -Be 'Show - S01E01'
            $results[2] | Should -Be 'Movie Two (2021)'
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory Item parameter' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Format-PatMediaItemName }
            $parameter = $command.Parameters['Item']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Accepts ValueFromPipeline' {
            $command = & (Get-Module PlexAutomationToolkit) { Get-Command Format-PatMediaItemName }
            $parameter = $command.Parameters['Item']

            $parameter.Attributes.ValueFromPipeline | Should -Contain $true
        }
    }

    Context 'Real-world Plex data structures' {
        It 'Formats typical movie from AddOperations' {
            # Simulates structure from Get-PatSyncPlan AddOperations
            $addOp = [PSCustomObject]@{
                RatingKey        = 1001
                Title            = 'Dune: Part Two'
                Type             = 'movie'
                Year             = 2024
                GrandparentTitle = $null
                ParentIndex      = $null
                Index            = $null
                DestinationPath  = 'E:\Movies\Dune Part Two (2024)\Dune Part Two (2024).mkv'
                MediaSize        = 15000000000
                SubtitleCount    = 2
                PartKey          = '/library/parts/3001/file.mkv'
                Container        = 'mkv'
            }

            $result = & $script:FormatPatMediaItemName -Item $addOp

            $result | Should -Be 'Dune: Part Two (2024)'
        }

        It 'Formats typical episode from AddOperations' {
            # Simulates structure from Get-PatSyncPlan AddOperations
            $addOp = [PSCustomObject]@{
                RatingKey        = 2001
                Title            = 'Ozymandias'
                Type             = 'episode'
                Year             = 2013
                GrandparentTitle = 'Breaking Bad'
                ParentIndex      = 5
                Index            = 14
                DestinationPath  = 'E:\TV\Breaking Bad\Season 05\Breaking Bad - S05E14 - Ozymandias.mkv'
                MediaSize        = 2000000000
                SubtitleCount    = 1
                PartKey          = '/library/parts/4001/file.mkv'
                Container        = 'mkv'
            }

            $result = & $script:FormatPatMediaItemName -Item $addOp

            $result | Should -Be 'Breaking Bad - S05E14'
        }

        It 'Formats playlist item structure' {
            # Simulates structure from Get-PatPlaylist Items
            $playlistItem = [PSCustomObject]@{
                RatingKey        = 1001
                PlaylistItemId   = 5001
                Title            = 'Pilot'
                Type             = 'episode'
                Year             = 2008
                GrandparentTitle = 'Breaking Bad'
                ParentIndex      = 1
                Index            = 1
            }

            $result = & $script:FormatPatMediaItemName -Item $playlistItem

            $result | Should -Be 'Breaking Bad - S01E01'
        }
    }
}
