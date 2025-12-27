BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force

    # Get the private function using module scope
    $script:GetPatMediaPath = & (Get-Module PlexAutomationToolkit) { Get-Command Get-PatMediaPath }
}

Describe 'Get-PatMediaPath' {
    Context 'Movie path generation' {
        It 'Generates correct path for a movie' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'The Matrix'
                Year  = 1999
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\Movies\The Matrix (1999)\The Matrix (1999).mkv'
        }

        It 'Handles movie without year' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Unknown Movie'
                Year  = $null
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mp4'

            $result | Should -Be 'E:\Movies\Unknown Movie (Unknown)\Unknown Movie (Unknown).mp4'
        }

        It 'Sanitizes movie title with special characters' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'What If...?'
                Year  = 2021
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'D:\Media' -Extension 'mkv'

            $result | Should -Be 'D:\Media\Movies\What If... (2021)\What If... (2021).mkv'
        }

        It 'Handles movie title with colons' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Star Wars: Episode IV'
                Year  = 1977
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\Movies\Star Wars - Episode IV (1977)\Star Wars - Episode IV (1977).mkv'
        }
    }

    Context 'TV episode path generation' {
        It 'Generates correct path for a TV episode' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'Pilot'
                GrandparentTitle = 'Breaking Bad'
                ParentIndex      = 1
                Index            = 1
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\Breaking Bad\Season 01\Breaking Bad - S01E01 - Pilot.mkv'
        }

        It 'Formats double-digit season and episode numbers' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'The One Where They All Turn Thirty'
                GrandparentTitle = 'Friends'
                ParentIndex      = 10
                Index            = 12
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\Friends\Season 10\Friends - S10E12 - The One Where They All Turn Thirty.mkv'
        }

        It 'Handles show name with special characters' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'Episode 1'
                GrandparentTitle = 'The Boys: Gen V'
                ParentIndex      = 1
                Index            = 1
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\The Boys - Gen V\Season 01\The Boys - Gen V - S01E01 - Episode 1.mkv'
        }

        It 'Handles episode title with special characters' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'Who Are You?'
                GrandparentTitle = 'Lost'
                ParentIndex      = 2
                Index            = 5
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\Lost\Season 02\Lost - S02E05 - Who Are You.mkv'
        }

        It 'Handles high episode numbers' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'Late Episode'
                GrandparentTitle = 'The Simpsons'
                ParentIndex      = 35
                Index            = 99
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\The Simpsons\Season 35\The Simpsons - S35E99 - Late Episode.mkv'
        }
    }

    Context 'Extension handling' {
        It 'Handles extension with leading dot' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test Movie'
                Year  = 2020
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension '.mkv'

            $result | Should -Be 'E:\Movies\Test Movie (2020)\Test Movie (2020).mkv'
        }

        It 'Supports various video extensions' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            $extensions = @('mp4', 'avi', 'mov', 'm4v', 'ts')

            foreach ($ext in $extensions) {
                $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension $ext
                $result | Should -Match "\.$ext$"
            }
        }
    }

    Context 'Base path handling' {
        It 'Works with drive root' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Match '^E:\\'
        }

        It 'Works with nested base path' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'D:\Plex\Media' -Extension 'mkv'

            $result | Should -Be 'D:\Plex\Media\Movies\Test (2020)\Test (2020).mkv'
        }

        It 'Works with UNC path' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath '\\NAS\Media' -Extension 'mkv'

            $result | Should -Be '\\NAS\Media\Movies\Test (2020)\Test (2020).mkv'
        }
    }

    Context 'Error handling' {
        It 'Throws on unsupported media type' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'music'
                Title = 'Test Song'
            }

            { & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mp3' } |
                Should -Throw "*Unsupported media type*"
        }

        It 'Throws on null MediaInfo' {
            { & $script:GetPatMediaPath -MediaInfo $null -BasePath 'E:\' -Extension 'mkv' } |
                Should -Throw
        }

        It 'Throws on empty BasePath' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            { & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath '' -Extension 'mkv' } |
                Should -Throw
        }

        It 'Throws on empty Extension' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Test'
                Year  = 2020
            }

            { & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension '' } |
                Should -Throw
        }
    }

    Context 'Real-world examples' {
        It 'Handles Inception correctly' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Inception'
                Year  = 2010
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\Movies\Inception (2010)\Inception (2010).mkv'
        }

        It 'Handles Game of Thrones episode correctly' {
            $mediaInfo = [PSCustomObject]@{
                Type             = 'episode'
                Title            = 'Winter Is Coming'
                GrandparentTitle = 'Game of Thrones'
                ParentIndex      = 1
                Index            = 1
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\TV Shows\Game of Thrones\Season 01\Game of Thrones - S01E01 - Winter Is Coming.mkv'
        }

        It 'Handles Avatar sequel correctly' {
            $mediaInfo = [PSCustomObject]@{
                Type  = 'movie'
                Title = 'Avatar: The Way of Water'
                Year  = 2022
            }

            $result = & $script:GetPatMediaPath -MediaInfo $mediaInfo -BasePath 'E:\' -Extension 'mkv'

            $result | Should -Be 'E:\Movies\Avatar - The Way of Water (2022)\Avatar - The Way of Water (2022).mkv'
        }
    }
}
