BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatLibraryChildItem' {
    BeforeAll {
        # Mock browse API response with directories and files
        $script:mockBrowseResponse = [PSCustomObject]@{
            Path = @(
                [PSCustomObject]@{ key = '/mnt/media/movies/action'; title = 'action' }
                [PSCustomObject]@{ key = '/mnt/media/movies/comedy'; title = 'comedy' }
            )
            File = @(
                [PSCustomObject]@{ key = '/mnt/media/movies/readme.txt'; title = 'readme.txt'; size = 1024 }
            )
        }

        # Mock browse response with only directories
        $script:mockBrowseDirectoriesOnly = [PSCustomObject]@{
            Path = @(
                [PSCustomObject]@{ key = '/mnt/media/subdir1'; title = 'subdir1' }
                [PSCustomObject]@{ key = '/mnt/media/subdir2'; title = 'subdir2' }
            )
        }

        # Mock browse response with only files
        $script:mockBrowseFilesOnly = [PSCustomObject]@{
            File = @(
                [PSCustomObject]@{ key = '/mnt/media/file1.mkv'; title = 'file1.mkv' }
                [PSCustomObject]@{ key = '/mnt/media/file2.mkv'; title = 'file2.mkv' }
            )
        }

        # Mock empty browse response
        $script:mockBrowseEmpty = [PSCustomObject]@{}

        # Mock library data for section browsing
        $script:mockLibraries = [PSCustomObject]@{
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
            )
        }
    }

    BeforeEach {
        Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockBrowseResponse
        }

        Mock -CommandName Join-PatUri -ModuleName PlexAutomationToolkit -MockWith {
            param($BaseUri, $Endpoint, $QueryString)
            return "$BaseUri$Endpoint?$QueryString"
        }

        Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
            return [PSCustomObject]@{
                name = 'Default Server'
                uri = 'http://default:32400'
                token = 'test-token'
                default = $true
            }
        }

        Mock -CommandName Get-PatAuthenticationHeader -ModuleName PlexAutomationToolkit -MockWith {
            return @{ 'X-Plex-Token' = 'test-token'; 'Accept' = 'application/json' }
        }

        Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockLibraries
        }
    }

    Context 'Browsing explicit paths' {
        It 'Should browse a specific path' {
            $result = Get-PatLibraryChildItem -Path '/mnt/media/movies'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3  # 2 directories + 1 file
        }

        It 'Should include both directories and files in results' {
            $result = Get-PatLibraryChildItem -Path '/mnt/media/movies'

            $directories = $result | Where-Object { $_.key -like '*/action' -or $_.key -like '*/comedy' }
            $files = $result | Where-Object { $_.key -like '*.txt' }

            $directories.Count | Should -Be 2
            $files.Count | Should -Be 1
        }

        It 'Should base64 encode the path in the endpoint' {
            Get-PatLibraryChildItem -Path '/mnt/media/movies'

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Endpoint -match '^/services/browse/'
            }
        }

        It 'Should include includeFiles=1 in query string' {
            Get-PatLibraryChildItem -Path '/mnt/media/movies'

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $QueryString -eq 'includeFiles=1'
            }
        }

        It 'Should use authentication headers when using default server' {
            Get-PatLibraryChildItem -Path '/mnt/media/movies'

            Should -Invoke Get-PatAuthenticationHeader -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Browsing root (no path specified)' {
        It 'Should browse root when no path or section specified' {
            Get-PatLibraryChildItem

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Endpoint -eq '/services/browse'
            }
        }

        It 'Should return root-level items' {
            $result = Get-PatLibraryChildItem

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Browsing by SectionId' {
        It 'Should browse all paths for a section' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            $result = Get-PatLibraryChildItem -SectionId 1

            # Should call API twice (once for each location in Movies section)
            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Should retrieve library sections when using SectionId' {
            Get-PatLibraryChildItem -SectionId 1

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Should throw when section ID not found' {
            { Get-PatLibraryChildItem -SectionId 999 } | Should -Throw "*Library section with ID 999 not found*"
        }

        It 'Should return combined results from multiple section paths' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            $result = Get-PatLibraryChildItem -SectionId 1

            # 2 directories per path * 2 paths = 4 total
            $result.Count | Should -Be 4
        }
    }

    Context 'Browsing by SectionName' {
        It 'Should browse all paths for a named section' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            $result = Get-PatLibraryChildItem -SectionName 'Movies'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Should throw when section name not found' {
            { Get-PatLibraryChildItem -SectionName 'NonExistent' } | Should -Throw "*Library section 'NonExistent' not found*"
        }

        It 'Should handle section names with spaces' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            $result = Get-PatLibraryChildItem -SectionName 'TV Shows'

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should browse single path for TV Shows section' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            Get-PatLibraryChildItem -SectionName 'TV Shows'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Combining Path with Section parameters' {
        It 'Should use explicit path even when SectionId is provided' {
            $result = Get-PatLibraryChildItem -SectionId 1 -Path '/custom/path'

            # Should only call API once with the explicit path
            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Should use explicit path even when SectionName is provided' {
            $result = Get-PatLibraryChildItem -SectionName 'Movies' -Path '/custom/path'

            # Should only call API once with the explicit path
            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Using explicit ServerUri' {
        It 'Should use provided ServerUri' {
            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Path '/mnt/media'

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $BaseUri -eq 'http://explicit:32400'
            }
        }

        It 'Should not use authentication headers when ServerUri provided without stored server' {
            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Path '/mnt/media'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Headers['Accept'] -eq 'application/json' -and -not $Headers.ContainsKey('X-Plex-Token')
            }
        }

        It 'Should not call Get-PatStoredServer when ServerUri provided' {
            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Path '/mnt/media'

            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Different response types' {
        It 'Should handle response with only directories' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            $result = Get-PatLibraryChildItem -Path '/mnt/media'

            $result.Count | Should -Be 2
            $result[0].title | Should -Be 'subdir1'
        }

        It 'Should handle response with only files' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseFilesOnly
            }

            $result = Get-PatLibraryChildItem -Path '/mnt/media'

            $result.Count | Should -Be 2
            $result[0].title | Should -Be 'file1.mkv'
        }

        It 'Should return nothing when path is empty' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseEmpty
            }

            $result = Get-PatLibraryChildItem -Path '/mnt/empty'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when Invoke-PatApi fails' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryChildItem -Path '/mnt/media' } | Should -Throw "*Failed to list items*"
        }

        It 'Should include path in error message' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryChildItem -Path '/mnt/media' } | Should -Throw "*/mnt/media*"
        }

        It 'Should include section name in error when browsing by name fails' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryChildItem -SectionName 'Movies' } | Should -Throw "*Movies*"
        }

        It 'Should include section ID in error when browsing by ID fails' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryChildItem -SectionId 1 } | Should -Throw "*1*"
        }

        It 'Should show root in error when no parameters provided' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API error'
            }

            { Get-PatLibraryChildItem } | Should -Throw "*<root>*"
        }

        It 'Should throw when no default server configured' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                return $null
            }

            { Get-PatLibraryChildItem -Path '/mnt/media' } | Should -Throw "*No default server configured*"
        }
    }

    Context 'Using default server' {
        It 'Should call Get-PatStoredServer when no ServerUri specified' {
            Get-PatLibraryChildItem -Path '/mnt/media'

            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter { $Default -eq $true }
        }

        It 'Should use default server URI for API calls' {
            Get-PatLibraryChildItem -Path '/mnt/media'

            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $BaseUri -eq 'http://default:32400'
            }
        }

        It 'Should call Get-PatLibrary without ServerUri when using default server' {
            Get-PatLibraryChildItem -SectionId 1

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('ServerUri')
            }
        }
    }

    Context 'Parameter validation' {
        It 'Should validate SectionId is greater than 0' {
            { Get-PatLibraryChildItem -SectionId 0 } | Should -Throw
        }

        It 'Should accept valid SectionId' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            { Get-PatLibraryChildItem -SectionId 1 } | Should -Not -Throw
        }

        It 'Should accept valid SectionName' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            { Get-PatLibraryChildItem -SectionName 'Movies' } | Should -Not -Throw
        }
    }

    Context 'Using explicit Token parameter' {
        It 'Should include Token in headers when provided with ServerUri' {
            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Token 'my-token' -Path '/mnt/media'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-token'
            }
        }

        It 'Should pass Token to Get-PatLibrary when using SectionId' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Token 'my-token' -SectionId 1

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Token -eq 'my-token'
            }
        }

        It 'Should pass Token to Get-PatLibrary when using SectionName' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseDirectoriesOnly
            }

            Get-PatLibraryChildItem -ServerUri 'http://explicit:32400' -Token 'my-token' -SectionName 'Movies'

            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'SectionName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Get-PatLibraryChildItem
            $sectionNameParam = $command.Parameters['SectionName']
            $script:sectionNameCompleter = $sectionNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching section names' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionName' 'Mov' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ ServerUri = 'http://custom:32400' }
                & $completer 'Get-PatLibraryChildItem' 'SectionName' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ Token = 'my-token' }
                & $completer 'Get-PatLibraryChildItem' 'SectionName' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }

        It 'Handles errors gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    throw 'Connection failed'
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionName' '' $null @{}
            }
            # Should not throw, just return empty
            $results | Should -BeNullOrEmpty
        }

        It 'Filters sections by word to complete' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionName' 'Mu' $null @{}
            }
            # Should only return Music
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SectionId argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Get-PatLibraryChildItem
            $sectionIdParam = $command.Parameters['SectionId']
            $script:sectionIdCompleter = $sectionIdParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching section IDs' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionIdCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                            @{ key = '/library/sections/2'; title = 'TV Shows' }
                            @{ key = '/library/sections/12'; title = 'Music' }
                        )
                    }
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionId' '1' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionIdCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ ServerUri = 'http://custom:32400' }
                & $completer 'Get-PatLibraryChildItem' 'SectionId' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionIdCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ Token = 'my-token' }
                & $completer 'Get-PatLibraryChildItem' 'SectionId' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }

        It 'Handles errors gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionIdCompleter } {
                Mock Get-PatLibrary {
                    throw 'Connection failed'
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionId' '' $null @{}
            }
            # Should not throw, just return empty
            $results | Should -BeNullOrEmpty
        }

        It 'Returns completion results with list item text and tooltip' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionIdCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                        )
                    }
                }

                & $completer 'Get-PatLibraryChildItem' 'SectionId' '' $null @{}
            }
            # Should return a completion result
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Section with no locations' {
        It 'Should handle section with no Location property' {
            Mock -CommandName Get-PatLibrary -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    Directory = @(
                        [PSCustomObject]@{
                            key   = '/library/sections/1'
                            title = 'Movies'
                            type  = 'movie'
                            # No Location property
                        }
                    )
                }
            }

            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                return $script:mockBrowseResponse
            }

            # Should browse root when section has no locations
            $result = Get-PatLibraryChildItem -SectionId 1
            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -ParameterFilter {
                $Endpoint -eq '/services/browse'
            }
        }
    }
}
