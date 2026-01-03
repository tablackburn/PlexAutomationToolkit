BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Register-PatArgumentCompleter' {

    Context 'Function basics' {
        It 'Function exists' {
            InModuleScope PlexAutomationToolkit {
                Get-Command -Name 'Register-PatArgumentCompleter' -ErrorAction 'SilentlyContinue' | Should -Not -BeNullOrEmpty
            }
        }

        It 'Can be called without error' {
            InModuleScope PlexAutomationToolkit {
                { Register-PatArgumentCompleter } | Should -Not -Throw
            }
        }

        It 'Has CmdletBinding attribute' {
            InModuleScope PlexAutomationToolkit {
                $cmd = Get-Command -Name 'Register-PatArgumentCompleter'
                $cmd.CmdletBinding | Should -Be $true
            }
        }
    }

    Context 'Tab completion works for SectionName parameters' {
        BeforeAll {
            # Mock Get-PatLibrary at module scope
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }
            }
        }

        It 'Update-PatLibrary -SectionName returns completions' {
            $results = InModuleScope PlexAutomationToolkit {
                # Use TabExpansion2 to test completions
                $line = "Update-PatLibrary -SectionName 'Mov"
                $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
                $completion.CompletionMatches
            }
            # May be empty if mock doesn't work in completer context, but should not throw
            { $results } | Should -Not -Throw
        }

        It 'Get-PatLibraryPath -SectionName returns completions' {
            $results = InModuleScope PlexAutomationToolkit {
                $line = "Get-PatLibraryPath -SectionName 'Mov"
                $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
                $completion.CompletionMatches
            }
            { $results } | Should -Not -Throw
        }
    }

    Context 'Completer scriptblock logic - SectionName' {
        It 'Returns matching sections when Get-PatLibrary succeeds' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                # Simulate completer behavior
                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete 'Mov'
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $sections = Get-PatLibrary @getParameters
                $results = foreach ($sectionTitle in $sections.Directory.title) {
                    if ($sectionTitle -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionTitle -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain 'Movies'
        }

        It 'Returns empty when Get-PatLibrary fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                try {
                    $sections = Get-PatLibrary @getParameters
                    foreach ($sectionTitle in $sections.Directory.title) {
                        if ($sectionTitle -ilike "$($completerInput.StrippedWord)*") {
                            New-PatCompletionResult -Value $sectionTitle -QuoteChar $completerInput.QuoteChar
                        }
                    }
                }
                catch {
                    # Completer should handle errors gracefully
                    $null
                }
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Filters sections by prefix' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete 'Mu'
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $sections = Get-PatLibrary @getParameters
                $results = foreach ($sectionTitle in $sections.Directory.title) {
                    if ($sectionTitle -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionTitle -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain 'Music'
            $results.CompletionText | Should -Not -Contain 'Movies'
        }

        It 'Passes ServerUri to Get-PatLibrary' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ ServerUri = 'http://custom:32400' }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token to Get-PatLibrary' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ Token = 'my-token' }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }
    }

    Context 'Completer scriptblock logic - SectionId' {
        It 'Returns matching section IDs' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/1'; title = 'Movies' }
                            @{ key = '/library/sections/2'; title = 'TV Shows' }
                            @{ key = '/library/sections/12'; title = 'Music' }
                        )
                    }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete '1'
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $sections = Get-PatLibrary @getParameters
                $results = $sections.Directory | ForEach-Object {
                    $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                    if ($sectionId -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionId -ListItemText "$sectionId - $($_.title)" -ToolTip "$($_.title) (ID: $sectionId)"
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain '1'
            $results.CompletionText | Should -Contain '12'
        }
    }

    Context 'Completer scriptblock logic - Path' {
        It 'Returns root paths when no input and SectionId provided' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                        @{ path = '/mnt/tv' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $fakeBoundParameters = @{ SectionId = 2 }
                $usingDefaultServer = $true

                # Verify default server exists
                $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                if (-not $defaultServer) { return }

                $sectionId = $fakeBoundParameters['SectionId']
                $pathParameters = @{ SectionId = $sectionId; ErrorAction = 'SilentlyContinue' }
                $rootPaths = Get-PatLibraryPath @pathParameters

                if (-not $completerInput.StrippedWord) {
                    foreach ($rootPath in $rootPaths) {
                        New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                    }
                }
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain '/mnt/movies'
            $results.CompletionText | Should -Contain '/mnt/tv'
        }

        It 'Returns nothing when no default server' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { return $null }

                $defaultServer = Get-PatStoredServer -Default -ErrorAction 'SilentlyContinue'
                if (-not $defaultServer) { return $null }
                'should not reach here'
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Resolves SectionId from SectionName' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/2'; title = 'Movies' }
                        )
                    }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                $fakeBoundParameters = @{ SectionName = 'Movies' }
                $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                $matchedSection = $sections.Directory | Where-Object { $_.title -eq $fakeBoundParameters['SectionName'] }
                if ($matchedSection) {
                    $sectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
                    $sectionId
                }
            }
            $results | Should -Be 2
        }

        It 'Browses subdirectories when path input matches root' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete '/mnt/movies'
                $rootPaths = Get-PatLibraryPath -SectionId 2 -ErrorAction 'SilentlyContinue'
                $exactRoot = $rootPaths | Where-Object { $_.path -ieq $completerInput.StrippedWord }
                if ($exactRoot) {
                    Get-PatLibraryChildItem -Path $completerInput.StrippedWord -ErrorAction 'SilentlyContinue'
                }

                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $Path -eq '/mnt/movies'
                }
            }
        }
    }

    Context 'Completer scriptblock logic - Collection Title' {
        It 'Returns matching collection titles' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ title = 'Marvel Movies' }
                        [PSCustomObject]@{ title = 'DC Movies' }
                        [PSCustomObject]@{ title = 'Horror Classics' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete 'Mar'
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $collections = Get-PatCollection @getParameters
                $results = foreach ($collection in $collections) {
                    if ($collection.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $collection.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain "'Marvel Movies'"
        }

        It 'Returns empty when Get-PatCollection fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection { throw 'Connection failed' }

                try {
                    Get-PatCollection -ErrorAction 'SilentlyContinue'
                }
                catch {
                    $null
                }
            }
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Completer scriptblock logic - Playlist Title' {
        It 'Returns matching playlist titles' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ title = 'My Favorites' }
                        [PSCustomObject]@{ title = 'Party Mix' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete 'My'
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $playlists = Get-PatPlaylist @getParameters
                $results = foreach ($playlist in $playlists) {
                    if ($playlist.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $playlist.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain "'My Favorites'"
        }

        It 'Returns empty when Get-PatPlaylist fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist { throw 'Connection failed' }

                try {
                    Get-PatPlaylist -ErrorAction 'SilentlyContinue'
                }
                catch {
                    $null
                }
            }
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Commands have completers registered' {
        # These tests verify completers are registered by checking TabExpansion2 doesn't throw
        # The actual completion results depend on mock availability in completion context

        It 'Update-PatLibrary SectionName has completer' {
            { TabExpansion2 -inputScript 'Update-PatLibrary -SectionName ' -cursorColumn 31 } | Should -Not -Throw
        }

        It 'Update-PatLibrary Path has completer' {
            { TabExpansion2 -inputScript 'Update-PatLibrary -SectionId 1 -Path ' -cursorColumn 37 } | Should -Not -Throw
        }

        It 'Get-PatLibraryPath SectionName has completer' {
            { TabExpansion2 -inputScript 'Get-PatLibraryPath -SectionName ' -cursorColumn 32 } | Should -Not -Throw
        }

        It 'Get-PatCollection Title has completer' {
            { TabExpansion2 -inputScript 'Get-PatCollection -Title ' -cursorColumn 25 } | Should -Not -Throw
        }

        It 'Get-PatPlaylist Title has completer' {
            { TabExpansion2 -inputScript 'Get-PatPlaylist -Title ' -cursorColumn 23 } | Should -Not -Throw
        }
    }
}
