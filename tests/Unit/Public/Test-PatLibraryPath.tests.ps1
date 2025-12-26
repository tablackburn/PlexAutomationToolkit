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

        # Mock browse items response
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
}
