BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
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
            Mock -ModuleName $Env:BHProjectName Get-PatLibraryChildItem {
                return $script:mockBrowseItems
            }
        }

        It 'Returns true when path exists' {
            $result = Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -ServerUri 'http://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Calls Get-PatLibraryChildItem to check path' {
            Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatLibraryChildItem
        }
    }

    Context 'When validating a path that does not exist' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatLibraryChildItem {
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
            Mock -ModuleName $Env:BHProjectName Get-PatLibraryPath {
                return $script:mockLibraryPaths
            }

            Mock -ModuleName $Env:BHProjectName Get-PatLibraryChildItem {
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
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatLibraryPath -ParameterFilter {
                $SectionName -eq 'Movies'
            }
        }
    }

    Context 'When browsing fails' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatLibraryChildItem {
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
