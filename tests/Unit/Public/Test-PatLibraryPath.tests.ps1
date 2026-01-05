BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Test-PatLibraryPath' {

    BeforeAll {
        # Mock library paths response
        $script:mockLibraryPaths = @(
            [PSCustomObject]@{
                id          = 1
                path        = '/mnt/media/Movies'
                section     = 'Movies'
                sectionId   = '2'
                sectionType = 'movie'
            }
            [PSCustomObject]@{
                id          = 2
                path        = '/mnt/media/4K Movies'
                section     = 'Movies'
                sectionId   = '2'
                sectionType = 'movie'
            }
        )

        # Mock browse items response (Plex browse API returns 'path' for filesystem path)
        $script:mockBrowseItems = @(
            [PSCustomObject]@{
                path  = '/mnt/media/Movies/Action'
                title = 'Action'
            }
            [PSCustomObject]@{
                path  = '/mnt/media/Movies/Comedy'
                title = 'Comedy'
            }
            [PSCustomObject]@{
                path  = '/mnt/media/Movies/NewMovie'
                title = 'NewMovie'
            }
        )
    }

    Context 'When validating a path without section constraint' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return $script:mockBrowseItems
            }
        }

        It 'Returns true when path exists' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Calls Get-PatLibraryChildItem to check path' {
            Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem
        }
    }

    Context 'When validating a path that does not exist' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @()
            }
        }

        It 'Returns false when path does not exist' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NonExistent' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }
    }

    Context 'When validating path with section constraint' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return $script:mockLibraryPaths
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return $script:mockBrowseItems
            }
        }

        It 'Returns true when path is under library root' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionId 2 -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Returns false when path is outside library root' {
            $result = Test-PatLibraryPath -Path '/mnt/other/path' -SectionId 2 -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }

        It 'Validates against section paths by SectionName' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionName 'Movies' -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryPath -ParameterFilter {
                $SectionName -eq 'Movies'
            }
        }
    }

    Context 'When browsing fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                throw 'Path not accessible'
            }
        }

        It 'Returns false when browsing fails' {
            $result = Test-PatLibraryPath -Path '/mnt/inaccessible/path' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }
    }

    Context 'Parameter validation' {
        It 'Requires Path parameter' {
            { Test-PatLibraryPath -ServerUri 'http://plex.local:32400' } | Should -Throw
        }

        It 'Validates ServerUri format' {
            { Test-PatLibraryPath -Path '/mnt/media' -ServerUri 'not-a-url' } | Should -Throw
        }
    }

    Context 'Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return $script:mockBrowseItems
            }
        }

        It 'Passes Token to Get-PatLibraryChildItem' {
            Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'When no library paths configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return $null
            }
        }

        It 'Returns false when library has no configured paths' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionId 2 -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }
    }

    Context 'When library path lookup fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                throw 'Library not found'
            }
        }

        It 'Returns false when library path lookup throws' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionName 'Unknown' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }
    }

    Context 'Root path testing' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @(
                    [PSCustomObject]@{ key = '/Movies'; title = 'Movies' }
                )
            }
        }

        It 'Returns true for root path when accessible' {
            $result = Test-PatLibraryPath -Path '/' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }
    }

    Context 'Path matching by title only' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @(
                    [PSCustomObject]@{ title = 'TargetFolder' }
                )
            }
        }

        It 'Matches by title when path property is not available' {
            $result = Test-PatLibraryPath -Path '/mnt/media/TargetFolder' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }
    }

    Context 'Path equals library root exactly' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return @(
                    [PSCustomObject]@{
                        id   = 1
                        path = '/mnt/media/Movies'
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @()
            }
        }

        It 'Returns true when path equals library root' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies' -SectionId 2 -ServerUri 'http://plex.local:32400'
            # Path equals root, but browsing returns empty, so false for non-existent content
            $result | Should -Be $false
        }
    }

    Context 'Using SectionId parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return $script:mockLibraryPaths
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return $script:mockBrowseItems
            }
        }

        It 'Passes SectionId to Get-PatLibraryPath' {
            Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionId 5 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryPath -ParameterFilter {
                $SectionId -eq 5
            }
        }
    }

    Context 'Case-insensitive path matching' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryPath {
                return @(
                    [PSCustomObject]@{
                        id   = 1
                        path = '/mnt/rar2fs/NAS5/Movies/TV'
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @(
                    [PSCustomObject]@{
                        path  = '/mnt/rar2fs/nas5/movies/TV/The.Simpsons/S37'
                        title = 'S37'
                    }
                )
            }
        }

        It 'Returns true when path differs only in case from library root' {
            # Library root is /mnt/rar2fs/NAS5/Movies/TV but user provides lowercase
            $result = Test-PatLibraryPath -Path '/mnt/rar2fs/nas5/movies/TV/The.Simpsons/S37' -SectionId 2 -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }
    }

    Context 'When API returns both key and path properties' {
        # Regression test: Plex browse API returns 'key' (API endpoint) and 'path' (filesystem path)
        # We must use 'path' for matching, not 'key'
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryChildItem {
                return @(
                    [PSCustomObject]@{
                        key   = '/services/browse/L21udC9tZWRpYS9Nb3ZpZXMvQWN0aW9u'  # API endpoint (wrong to match against)
                        path  = '/mnt/media/Movies/Action'  # Filesystem path (correct to match against)
                        title = 'Action'
                    }
                    [PSCustomObject]@{
                        key   = '/services/browse/L21udC9tZWRpYS9Nb3ZpZXMvQ29tZWR5'
                        path  = '/mnt/media/Movies/Comedy'
                        title = 'Comedy'
                    }
                )
            }
        }

        It 'Uses path property not key property for matching' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/Action' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Does not match against key property (API endpoint)' {
            # This path matches the 'key' value but not 'path' - should return false
            $result = Test-PatLibraryPath -Path '/services/browse/L21udC9tZWRpYS9Nb3ZpZXMvQWN0aW9u' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $false
        }
    }
}
