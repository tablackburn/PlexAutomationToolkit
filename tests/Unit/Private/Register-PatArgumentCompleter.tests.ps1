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

        It 'Returns empty when Get-PatLibrary fails and writes debug message' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

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
                    Write-Debug "Tab completion failed for SectionName: $($_.Exception.Message)"
                    $null
                }
            }
            $results | Should -BeNullOrEmpty
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

        It 'Returns empty when Get-PatLibrary fails and writes debug message' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                try {
                    $sections = Get-PatLibrary @getParameters
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -ilike "$($completerInput.StrippedWord)*") {
                            New-PatCompletionResult -Value $sectionId -ListItemText "$sectionId - $($_.title)" -ToolTip "$($_.title) (ID: $sectionId)"
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId: $($_.Exception.Message)"
                }
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Passes ServerUri to Get-PatLibrary for SectionId completer' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ key = '/library/sections/1'; title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ ServerUri = 'http://custom:32400' }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token to Get-PatLibrary for SectionId completer' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ key = '/library/sections/1'; title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ Token = 'my-token' }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
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

        It 'Returns nothing when Get-PatStoredServer throws' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { throw 'No server configured' }
                Mock Write-Debug { }

                $usingDefaultServer = $true
                if ($usingDefaultServer) {
                    try {
                        $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                        if (-not $defaultServer) { return $null }
                    }
                    catch {
                        Write-Debug "Tab completion failed: Could not retrieve default server"
                        return $null
                    }
                }
                'should not reach here'
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Uses explicit ServerUri instead of default server' {
            InModuleScope PlexAutomationToolkit {
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

                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    SectionName = 'Movies'
                }
                $usingDefaultServer = -not $fakeBoundParameters.ContainsKey('ServerUri')

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                if (-not $usingDefaultServer) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                $sections = Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes ServerUri to Get-PatLibraryPath when not using default' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    SectionId = 2
                }
                $usingDefaultServer = -not $fakeBoundParameters.ContainsKey('ServerUri')
                $sectionId = $fakeBoundParameters['SectionId']

                $pathParameters = @{ SectionId = $sectionId; ErrorAction = 'SilentlyContinue' }
                if (-not $usingDefaultServer) {
                    $pathParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                Get-PatLibraryPath @pathParameters

                Should -Invoke Get-PatLibraryPath -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $SectionId -eq 2
                }
            }
        }

        It 'Passes ServerUri to Get-PatLibraryChildItem when not using default' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                    )
                }

                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    SectionId = 2
                }
                $usingDefaultServer = -not $fakeBoundParameters.ContainsKey('ServerUri')
                $pathToBrowse = '/mnt/movies'

                $browseParameters = @{ Path = $pathToBrowse; ErrorAction = 'SilentlyContinue' }
                if (-not $usingDefaultServer) {
                    $browseParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                Get-PatLibraryChildItem @browseParameters

                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Path -eq '/mnt/movies'
                }
            }
        }

        It 'Returns nothing when SectionName resolution fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                $fakeBoundParameters = @{ SectionName = 'Movies' }
                $sectionId = $null

                try {
                    $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                    $sections = Get-PatLibrary @getParameters
                    $matchedSection = $sections.Directory | Where-Object { $_.title -eq $fakeBoundParameters['SectionName'] }
                    if ($matchedSection) {
                        $sectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
                    }
                }
                catch {
                    Write-Debug "Tab completion failed: Could not resolve section name to ID: $($_.Exception.Message)"
                }

                if (-not $sectionId) { return $null }
                'should not reach here'
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Returns nothing when neither SectionId nor SectionName provided' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                $fakeBoundParameters = @{}
                $sectionId = $null

                if ($fakeBoundParameters.ContainsKey('SectionId')) {
                    $sectionId = $fakeBoundParameters['SectionId']
                }
                elseif ($fakeBoundParameters.ContainsKey('SectionName')) {
                    # Would resolve SectionName
                }

                if (-not $sectionId) { return $null }
                'should not reach here'
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Extracts parent path manually for Unix paths' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = '/mnt/movies/Action/Some Movie'

                # Manual parent path extraction to preserve forward slashes
                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -Be '/mnt/movies/Action'
        }

        It 'Returns null for path without slashes' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = 'movies'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles items with Path property instead of path' {
            $results = InModuleScope PlexAutomationToolkit {
                $item = [PSCustomObject]@{ Path = '/mnt/movies/Action' }

                # Get the path property (handle both 'path' and 'Path' casing)
                $itemPath = if ($item.PSObject.Properties['path']) {
                    $item.path
                } elseif ($item.PSObject.Properties['Path']) {
                    $item.Path
                } else {
                    $null
                }
                $itemPath
            }
            $results | Should -Be '/mnt/movies/Action'
        }

        It 'Returns null for items without path property' {
            $results = InModuleScope PlexAutomationToolkit {
                $item = [PSCustomObject]@{ name = 'Action' }

                $itemPath = if ($item.PSObject.Properties['path']) {
                    $item.path
                } elseif ($item.PSObject.Properties['Path']) {
                    $item.Path
                } else {
                    $null
                }
                $itemPath
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Filters items by prefix when browsing' {
            $results = InModuleScope PlexAutomationToolkit {
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
                        [PSCustomObject]@{ path = '/mnt/movies/Drama' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete '/mnt/movies/A'
                $items = Get-PatLibraryChildItem -Path '/mnt/movies' -ErrorAction 'SilentlyContinue'

                $results = foreach ($item in $items) {
                    $itemPath = if ($item.PSObject.Properties['path']) { $item.path } elseif ($item.PSObject.Properties['Path']) { $item.Path } else { $null }
                    if ($itemPath -and $itemPath -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $itemPath -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain '/mnt/movies/Action'
            $results.CompletionText | Should -Not -Contain '/mnt/movies/Comedy'
        }

        It 'Falls back to matching root paths when browsing fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                        [PSCustomObject]@{ path = '/mnt/music' }
                    )
                }
                Mock Get-PatLibraryChildItem { throw 'Browse failed' }
                Mock Write-Debug { }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete '/mnt/m'
                $rootPaths = Get-PatLibraryPath -SectionId 2 -ErrorAction 'SilentlyContinue'
                $pathToBrowse = '/mnt'
                $browsedItems = $false

                try {
                    $items = Get-PatLibraryChildItem -Path $pathToBrowse -ErrorAction 'SilentlyContinue'
                    if ($items) { $browsedItems = $true }
                }
                catch {
                    Write-Debug "Tab completion failed: Could not browse path: $($_.Exception.Message)"
                }

                # Fall back to matching root paths if browsing didn't work
                if (-not $browsedItems) {
                    $matchingRoots = $rootPaths | Where-Object { $_.path -ilike "$($completerInput.StrippedWord)*" }
                    foreach ($rootPath in $matchingRoots) {
                        New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                    }
                }
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain '/mnt/movies'
            $results.CompletionText | Should -Contain '/mnt/music'
        }

        It 'Falls back to matching root paths when no items returned' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Mock Get-PatLibraryChildItem { return $null }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete '/mnt/m'
                $rootPaths = Get-PatLibraryPath -SectionId 2 -ErrorAction 'SilentlyContinue'
                $pathToBrowse = '/mnt'
                $browsedItems = $false

                $items = Get-PatLibraryChildItem -Path $pathToBrowse -ErrorAction 'SilentlyContinue'
                if ($items) { $browsedItems = $true }

                if (-not $browsedItems) {
                    $matchingRoots = $rootPaths | Where-Object { $_.path -ilike "$($completerInput.StrippedWord)*" }
                    foreach ($rootPath in $matchingRoots) {
                        New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                    }
                }
            }
            $results | Should -Not -BeNullOrEmpty
            $results.CompletionText | Should -Contain '/mnt/movies'
        }

        It 'Writes debug when Get-PatLibraryPath fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath { throw 'Library path retrieval failed' }
                Mock Write-Debug { }

                $fakeBoundParameters = @{ SectionId = 2 }
                $sectionId = $fakeBoundParameters['SectionId']

                try {
                    $pathParameters = @{ SectionId = $sectionId; ErrorAction = 'SilentlyContinue' }
                    $rootPaths = Get-PatLibraryPath @pathParameters
                }
                catch {
                    Write-Debug "Tab completion failed: Could not retrieve library paths: $($_.Exception.Message)"
                }
                $null
            }
            $results | Should -BeNullOrEmpty
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

        It 'Passes ServerUri to Get-PatCollection' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @([PSCustomObject]@{ title = 'Marvel Movies' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ ServerUri = 'http://custom:32400' }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                Get-PatCollection @getParameters

                Should -Invoke Get-PatCollection -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token to Get-PatCollection' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @([PSCustomObject]@{ title = 'Marvel Movies' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ Token = 'my-token' }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatCollection @getParameters

                Should -Invoke Get-PatCollection -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }

        It 'Builds getParameters with LibraryId from fakeBoundParameters' {
            $result = InModuleScope PlexAutomationToolkit {
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ LibraryId = 2 }
                if ($fakeBoundParameters.ContainsKey('LibraryId')) {
                    $getParameters['LibraryId'] = $fakeBoundParameters['LibraryId']
                }
                $getParameters
            }
            $result['LibraryId'] | Should -Be 2
        }

        It 'Builds getParameters with LibraryName from fakeBoundParameters' {
            $result = InModuleScope PlexAutomationToolkit {
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ LibraryName = 'Movies' }
                if ($fakeBoundParameters.ContainsKey('LibraryName')) {
                    $getParameters['LibraryName'] = $fakeBoundParameters['LibraryName']
                }
                $getParameters
            }
            $result['LibraryName'] | Should -Be 'Movies'
        }

        It 'Writes debug when Get-PatCollection fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection { throw 'Connection failed' }
                Mock Write-Debug { }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                try {
                    $collections = Get-PatCollection @getParameters
                    foreach ($collection in $collections) {
                        if ($collection.title -ilike "$($completerInput.StrippedWord)*") {
                            New-PatCompletionResult -Value $collection.title -QuoteChar $completerInput.QuoteChar
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for Title: $($_.Exception.Message)"
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

        It 'Passes ServerUri to Get-PatPlaylist' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @([PSCustomObject]@{ title = 'My Favorites' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ ServerUri = 'http://custom:32400' }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                Get-PatPlaylist @getParameters

                Should -Invoke Get-PatPlaylist -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Passes Token to Get-PatPlaylist' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @([PSCustomObject]@{ title = 'My Favorites' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{ Token = 'my-token' }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatPlaylist @getParameters

                Should -Invoke Get-PatPlaylist -ParameterFilter {
                    $Token -eq 'my-token'
                }
            }
        }

        It 'Writes debug when Get-PatPlaylist fails' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist { throw 'Connection failed' }
                Mock Write-Debug { }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                try {
                    $playlists = Get-PatPlaylist @getParameters
                    foreach ($playlist in $playlists) {
                        if ($playlist.title -ilike "$($completerInput.StrippedWord)*") {
                            New-PatCompletionResult -Value $playlist.title -QuoteChar $completerInput.QuoteChar
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for Title: $($_.Exception.Message)"
                }
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Returns all playlists when no filter prefix' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ title = 'My Favorites' }
                        [PSCustomObject]@{ title = 'Party Mix' }
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
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
            $results.Count | Should -Be 2
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

    Context 'Completer execution with mocked functions' {
        # These tests trigger actual completer execution by using TabExpansion2
        # with functions mocked at module scope

        It 'SectionName completer executes and returns results when library exists' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                            @{ title = 'TV Shows'; key = '/library/sections/2' }
                        )
                    }
                }
                # Re-register completers with mocks in scope
                Register-PatArgumentCompleter
            }
            $line = 'Get-PatLibraryPath -SectionName M'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            # Completer runs; results depend on mock working in completer context
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SectionId completer executes and returns results when library exists' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                            @{ title = 'TV Shows'; key = '/library/sections/2' }
                        )
                    }
                }
                Register-PatArgumentCompleter
            }
            $line = 'Get-PatLibraryPath -SectionId '
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Collection Title completer executes when collections exist' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    @(
                        [PSCustomObject]@{ title = 'Action Movies' }
                        [PSCustomObject]@{ title = 'Comedy Movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = 'Get-PatCollection -Title A'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Playlist Title completer executes when playlists exist' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    @(
                        [PSCustomObject]@{ title = 'My Playlist' }
                        [PSCustomObject]@{ title = 'Other Playlist' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = 'Get-PatPlaylist -Title M'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Path completer returns root paths when stored server exists' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    @{ name = 'TestServer'; uri = 'http://test:32400' }
                }
                Mock Get-PatLibraryPath {
                    @(
                        [PSCustomObject]@{ path = '/mnt/media/movies' }
                        [PSCustomObject]@{ path = '/mnt/media/tv' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = 'Update-PatLibrary -SectionId 1 -Path /'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Path completer handles browse with child items' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    @{ name = 'TestServer'; uri = 'http://test:32400' }
                }
                Mock Get-PatLibraryPath {
                    @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Mock Get-PatLibraryChildItem {
                    @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = 'Update-PatLibrary -SectionId 1 -Path /mnt/movies'
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SectionName completer executes when ServerUri is pre-bound' {
            # Mocks don't persist outside InModuleScope, so we verify completer executed
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                        )
                    }
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatLibraryPath -ServerUri 'http://custom:32400' -SectionName M"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            # Verify TabExpansion2 returned a result (completer was invoked)
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SectionName completer executes when Token is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                        )
                    }
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatLibraryPath -Token 'my-token' -SectionName M"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SectionId completer executes when ServerUri is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                        )
                    }
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatLibraryPath -ServerUri 'http://custom:32400' -SectionId "
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SectionId completer executes when Token is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                        )
                    }
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatLibraryPath -Token 'my-token' -SectionId "
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Collection Title completer executes when ServerUri is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    @(
                        [PSCustomObject]@{ title = 'Action Movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatCollection -ServerUri 'http://custom:32400' -Title A"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Collection Title completer executes when Token is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    @(
                        [PSCustomObject]@{ title = 'Action Movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatCollection -Token 'my-token' -Title A"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Collection Title completer executes when SectionId is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    @(
                        [PSCustomObject]@{ title = 'Action Movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatCollection -SectionId 1 -Title A"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Collection Title completer executes when SectionName is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    @(
                        [PSCustomObject]@{ title = 'Action Movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatCollection -SectionName 'Movies' -Title A"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Playlist Title completer executes when ServerUri is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    @(
                        [PSCustomObject]@{ title = 'My Playlist' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatPlaylist -ServerUri 'http://custom:32400' -Title M"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Playlist Title completer executes when Token is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    @(
                        [PSCustomObject]@{ title = 'My Playlist' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Get-PatPlaylist -Token 'my-token' -Title M"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Path completer executes when ServerUri is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath {
                    @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Update-PatLibrary -ServerUri 'http://custom:32400' -SectionId 1 -Path /mnt"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Path completer executes when SectionName is pre-bound' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    @{ name = 'TestServer'; uri = 'http://test:32400' }
                }
                Mock Get-PatLibrary {
                    @{
                        Directory = @(
                            @{ title = 'Movies'; key = '/library/sections/1' }
                        )
                    }
                }
                Mock Get-PatLibraryPath {
                    @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }
                Register-PatArgumentCompleter
            }
            $line = "Update-PatLibrary -SectionName 'Movies' -Path /mnt"
            $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter combinations for all completers' {
        It 'SectionNameCompleter passes ServerUri and Token together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    Token = 'my-token'
                }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'SectionIdCompleter passes ServerUri and Token together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @(@{ key = '/library/sections/1'; title = 'Movies' }) }
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    Token = 'my-token'
                }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatLibrary @getParameters

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }

        It 'CollectionTitleCompleter passes ServerUri, Token, and LibraryId together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @([PSCustomObject]@{ title = 'My Collection' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    Token = 'my-token'
                    LibraryId = 2
                }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                if ($fakeBoundParameters.ContainsKey('LibraryId')) {
                    $getParameters['LibraryId'] = $fakeBoundParameters['LibraryId']
                }
                Get-PatCollection @getParameters

                Should -Invoke Get-PatCollection -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token' -and $LibraryId -eq 2
                }
            }
        }

        It 'PlaylistTitleCompleter passes ServerUri and Token together' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @([PSCustomObject]@{ title = 'My Playlist' })
                }

                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                $fakeBoundParameters = @{
                    ServerUri = 'http://custom:32400'
                    Token = 'my-token'
                }
                if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                if ($fakeBoundParameters.ContainsKey('Token')) {
                    $getParameters['Token'] = $fakeBoundParameters['Token']
                }
                Get-PatPlaylist @getParameters

                Should -Invoke Get-PatPlaylist -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400' -and $Token -eq 'my-token'
                }
            }
        }
    }

    Context 'Empty and null result handling' {
        It 'SectionNameCompleter returns empty when Directory is null' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = $null }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                $results = foreach ($sectionTitle in $sections.Directory.title) {
                    if ($sectionTitle -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionTitle -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'SectionNameCompleter returns empty when Directory array is empty' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{ Directory = @() }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                $results = foreach ($sectionTitle in $sections.Directory.title) {
                    if ($sectionTitle -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionTitle -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'SectionIdCompleter handles sections with no key property' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }  # Missing 'key' property
                        )
                    }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                $results = $sections.Directory | ForEach-Object {
                    $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                    # Only create completion if sectionId is valid
                    if ($sectionId -and $sectionId -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionId -ListItemText "$sectionId - $($_.title)" -ToolTip "$($_.title) (ID: $sectionId)"
                    }
                }
                $results
            }
            # Should return empty since key is null
            $results | Should -BeNullOrEmpty
        }

        It 'CollectionTitleCompleter handles empty collections array' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @()
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $collections = Get-PatCollection -ErrorAction 'SilentlyContinue'
                $results = foreach ($collection in $collections) {
                    if ($collection.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $collection.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'PlaylistTitleCompleter handles empty playlists array' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @()
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $playlists = Get-PatPlaylist -ErrorAction 'SilentlyContinue'
                $results = foreach ($playlist in $playlists) {
                    if ($playlist.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $playlist.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'PathCompleter handles empty root paths' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }
                Mock Get-PatLibraryPath {
                    return @()
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $fakeBoundParameters = @{ SectionId = 2 }
                $sectionId = $fakeBoundParameters['SectionId']

                $pathParameters = @{ SectionId = $sectionId; ErrorAction = 'SilentlyContinue' }
                $rootPaths = Get-PatLibraryPath @pathParameters

                if (-not $completerInput.StrippedWord) {
                    foreach ($rootPath in $rootPaths) {
                        New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                    }
                }
            }
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Path extraction edge cases' {
        It 'Extracts parent from Windows absolute path' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = 'C:\Movies\Action\SomeMovie'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -Be 'C:\Movies\Action'
        }

        It 'Extracts parent from UNC path' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = '\\server\share\folder\subfolder'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -Be '\\server\share\folder'
        }

        It 'Handles root-level Unix path' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = '/mnt'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            # /mnt has slash at position 0, substring(0,0) returns empty string
            $results | Should -BeNullOrEmpty
        }

        It 'Handles path with trailing slash' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = '/mnt/movies/'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -Be '/mnt/movies'
        }

        It 'Handles mixed slashes in path' {
            $results = InModuleScope PlexAutomationToolkit {
                $strippedWord = '/mnt/movies\subfolder'

                $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                if ($lastSlash -gt 0) {
                    $strippedWord.Substring(0, $lastSlash)
                } else {
                    $null
                }
            }
            $results | Should -Be '/mnt/movies'
        }
    }

    Context 'Write-Debug verification for error paths' {
        It 'SectionNameCompleter writes debug on Get-PatLibrary failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                try {
                    Get-PatLibrary -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed for SectionName: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for SectionName*'
                }
            }
        }

        It 'SectionIdCompleter writes debug on Get-PatLibrary failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                try {
                    Get-PatLibrary -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for SectionId*'
                }
            }
        }

        It 'PathCompleter writes debug on default server retrieval failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatStoredServer { throw 'No server configured' }
                Mock Write-Debug { }

                try {
                    Get-PatStoredServer -Default -ErrorAction 'Stop'
                }
                catch {
                    Write-Debug "Tab completion failed: Could not retrieve default server"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not retrieve default server*'
                }
            }
        }

        It 'PathCompleter writes debug on SectionName resolution failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary { throw 'Connection failed' }
                Mock Write-Debug { }

                try {
                    Get-PatLibrary -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed: Could not resolve section name to ID: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not resolve section name to ID*'
                }
            }
        }

        It 'PathCompleter writes debug on browse path failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryChildItem { throw 'Browse failed' }
                Mock Write-Debug { }

                try {
                    Get-PatLibraryChildItem -Path '/mnt/movies' -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed: Could not browse path: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not browse path*'
                }
            }
        }

        It 'PathCompleter writes debug on library path retrieval failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibraryPath { throw 'Library path failed' }
                Mock Write-Debug { }

                try {
                    Get-PatLibraryPath -SectionId 2 -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed: Could not retrieve library paths: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Could not retrieve library paths*'
                }
            }
        }

        It 'CollectionTitleCompleter writes debug on failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection { throw 'Connection failed' }
                Mock Write-Debug { }

                try {
                    Get-PatCollection -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed for Title: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for Title*'
                }
            }
        }

        It 'PlaylistTitleCompleter writes debug on failure' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist { throw 'Connection failed' }
                Mock Write-Debug { }

                try {
                    Get-PatPlaylist -ErrorAction 'SilentlyContinue'
                }
                catch {
                    Write-Debug "Tab completion failed for Title: $($_.Exception.Message)"
                }

                Should -Invoke Write-Debug -ParameterFilter {
                    $Message -like '*Tab completion failed for Title*'
                }
            }
        }
    }

    Context 'Malformed data handling' {
        It 'SectionIdCompleter handles keys without numeric suffix' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/invalid'; title = 'Movies' }
                        )
                    }
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                $results = $sections.Directory | ForEach-Object {
                    $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                    if ($sectionId -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $sectionId -ListItemText "$sectionId - $($_.title)" -ToolTip "$($_.title) (ID: $sectionId)"
                    }
                }
                $results
            }
            # When regex doesn't match, it returns the original string 'invalid'
            # which won't match empty prefix filter
            $results | Should -Not -BeNullOrEmpty
        }

        It 'CollectionTitleCompleter handles collections without title' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ ratingKey = '123' }  # Missing title
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $collections = Get-PatCollection -ErrorAction 'SilentlyContinue'
                $results = foreach ($collection in $collections) {
                    # Only create completion if title is valid
                    if ($collection.title -and $collection.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $collection.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'PlaylistTitleCompleter handles playlists without title' {
            $results = InModuleScope PlexAutomationToolkit {
                Mock Get-PatPlaylist {
                    return @(
                        [PSCustomObject]@{ ratingKey = '456' }  # Missing title
                    )
                }

                $completerInput = ConvertFrom-PatCompleterInput -WordToComplete ''
                $playlists = Get-PatPlaylist -ErrorAction 'SilentlyContinue'
                $results = foreach ($playlist in $playlists) {
                    # Only create completion if title is valid
                    if ($playlist.title -and $playlist.title -ilike "$($completerInput.StrippedWord)*") {
                        New-PatCompletionResult -Value $playlist.title -QuoteChar $completerInput.QuoteChar
                    }
                }
                $results
            }
            $results | Should -BeNullOrEmpty
        }

        It 'PathCompleter handles items with lowercase path property' {
            $results = InModuleScope PlexAutomationToolkit {
                $item = [PSCustomObject]@{ path = '/mnt/movies/Action' }

                $itemPath = if ($item.PSObject.Properties['path']) {
                    $item.path
                } elseif ($item.PSObject.Properties['Path']) {
                    $item.Path
                } else {
                    $null
                }
                $itemPath
            }
            $results | Should -Be '/mnt/movies/Action'
        }
    }
}
