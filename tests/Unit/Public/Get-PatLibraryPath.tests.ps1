BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatLibraryPath' {
    BeforeAll {
        # Mock library data with locations
        $script:mockLibrariesWithPaths = [PSCustomObject]@{
            Directory = @(
                [PSCustomObject]@{
                    key   = '/library/sections/1'
                    title = 'Movies'
                    type  = 'movie'
                    Location = @(
                        [PSCustomObject]@{ id = '101'; path = '/mnt/media/movies' }
                        [PSCustomObject]@{ id = '102'; path = '/mnt/media/movies2' }
                    )
                }
                [PSCustomObject]@{
                    key   = '/library/sections/2'
                    title = 'TV Shows'
                    type  = 'show'
                    Location = @(
                        [PSCustomObject]@{ id = '201'; path = '/mnt/media/tvshows' }
                    )
                }
                [PSCustomObject]@{
                    key   = '/library/sections/3'
                    title = 'Music'
                    type  = 'artist'
                    Location = @(
                        [PSCustomObject]@{ id = '301'; path = '/mnt/media/music' }
                    )
                }
            )
        }

        # Mock library without locations
        $script:mockLibraryNoLocations = [PSCustomObject]@{
            Directory = @(
                [PSCustomObject]@{
                    key   = '/library/sections/99'
                    title = 'Empty'
                    type  = 'photo'
                    Location = $null
                }
            )
        }
    }

    BeforeEach {
        Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockLibrariesWithPaths
        }

        Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
            return [PSCustomObject]@{
                name = 'Default Server'
                uri = 'http://default:32400'
                token = 'test-token'
                default = $true
            }
        }
    }

    Context 'Using default server' {
        It 'Should retrieve paths from all sections' {
            $result = Get-PatLibraryPath

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 4  # 2 movies + 1 tv + 1 music
        }

        It 'Should enrich location objects with section context' {
            $result = Get-PatLibraryPath

            $firstPath = $result | Select-Object -First 1
            $firstPath.PSObject.Properties.Name | Should -Contain 'id'
            $firstPath.PSObject.Properties.Name | Should -Contain 'path'
            $firstPath.PSObject.Properties.Name | Should -Contain 'section'
            $firstPath.PSObject.Properties.Name | Should -Contain 'sectionId'
            $firstPath.PSObject.Properties.Name | Should -Contain 'sectionType'
        }

        It 'Should return correct path data for Movies section' {
            $result = Get-PatLibraryPath

            $moviePaths = $result | Where-Object { $_.section -eq 'Movies' }
            $moviePaths.Count | Should -Be 2
            $moviePaths[0].path | Should -Be '/mnt/media/movies'
            $moviePaths[0].sectionId | Should -Be '1'
            $moviePaths[0].sectionType | Should -Be 'movie'
        }

        It 'Should call Get-PatStoredServer when no ServerUri specified' {
            Get-PatLibraryPath

            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter { $Default -eq $true }
        }

        It 'Should call Get-PatLibrary without ServerUri when using default server' {
            Get-PatLibraryPath

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter { -not $PSBoundParameters.ContainsKey('ServerUri') }
        }
    }

    Context 'Filter by SectionId' {
        It 'Should retrieve paths for specific section ID' {
            $result = Get-PatLibraryPath -SectionId 1

            $result.Count | Should -Be 2
            $result[0].section | Should -Be 'Movies'
            $result[0].sectionId | Should -Be '1'
        }

        It 'Should retrieve single path for section with one location' {
            $result = Get-PatLibraryPath -SectionId 2

            @($result).Count | Should -Be 1
            $result.section | Should -Be 'TV Shows'
            $result.path | Should -Be '/mnt/media/tvshows'
        }

        It 'Should throw when section ID not found' {
            { Get-PatLibraryPath -SectionId 999 } | Should -Throw "*Library section with ID 999 not found*"
        }

        It 'Should validate SectionId is greater than 0' {
            { Get-PatLibraryPath -SectionId 0 } | Should -Throw
        }
    }

    Context 'Filter by SectionName' {
        It 'Should retrieve paths for specific section name' {
            $result = Get-PatLibraryPath -SectionName 'Movies'

            $result.Count | Should -Be 2
            $result[0].section | Should -Be 'Movies'
        }

        It 'Should retrieve paths for TV Shows section' {
            $result = Get-PatLibraryPath -SectionName 'TV Shows'

            @($result).Count | Should -Be 1
            $result.section | Should -Be 'TV Shows'
            $result.path | Should -Be '/mnt/media/tvshows'
        }

        It 'Should throw when section name not found' {
            { Get-PatLibraryPath -SectionName 'NonExistent' } | Should -Throw "*Library section 'NonExistent' not found*"
        }

        It 'Should handle section names with spaces' {
            $result = Get-PatLibraryPath -SectionName 'TV Shows'

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Using explicit ServerUri' {
        It 'Should use provided ServerUri' {
            Get-PatLibraryPath -ServerUri 'http://explicit:32400'

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $ServerUri -eq 'http://explicit:32400'
            }
        }

        It 'Should not call Get-PatStoredServer when ServerUri provided' {
            Get-PatLibraryPath -ServerUri 'http://explicit:32400'

            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Sections with no locations' {
        BeforeEach {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockLibraryNoLocations
            }
        }

        It 'Should return nothing for section with no locations' {
            $result = Get-PatLibraryPath -SectionId 99

            $result | Should -BeNullOrEmpty
        }

        It 'Should return nothing when no sections have locations' {
            $result = Get-PatLibraryPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when Get-PatLibrary fails' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryPath } | Should -Throw "*Failed to retrieve library paths*"
        }

        It 'Should propagate Get-PatLibrary error messages' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Connection refused'
            }

            { Get-PatLibraryPath } | Should -Throw "*Connection refused*"
        }

        It 'Should throw when no default server configured' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                return $null
            }

            { Get-PatLibraryPath } | Should -Throw "*No default server configured*"
        }

        It 'Should include section name in error message when filtering by name fails' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryPath -SectionName 'Movies' } | Should -Throw "*Failed to retrieve library paths for section 'Movies'*"
        }

        It 'Should include section ID in error message when filtering by ID fails' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryPath -SectionId 1 } | Should -Throw "*Failed to retrieve library paths for section 1*"
        }
    }

    Context 'Empty library scenarios' {
        BeforeEach {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    Directory = @()
                }
            }
        }

        It 'Should return nothing when no library sections exist' {
            $result = Get-PatLibraryPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When Directory is null' {
        BeforeEach {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    Directory = $null
                }
            }
        }

        It 'Should return nothing when Directory is null' {
            $result = Get-PatLibraryPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Token parameter' {
        It 'Passes Token to Get-PatLibrary when using explicit ServerUri' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockLibrariesWithPaths
            }

            Get-PatLibraryPath -ServerUri 'http://explicit:32400' -Token 'my-token'

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }
}
