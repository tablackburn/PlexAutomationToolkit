function Register-PatArgumentCompleters {
    <#
    .SYNOPSIS
        Registers argument completers for PlexAutomationToolkit commands.

    .DESCRIPTION
        This function registers all argument completers used by the module.
        It is called from the module's psm1 file after all functions are loaded.
        Using Register-ArgumentCompleter ensures the scriptblocks run in the
        module's scope, giving them access to private helper functions.
    #>
    # Suppress plural noun warning - function intentionally registers multiple completers
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    # Suppress unused parameter warnings - completer scriptblocks require these parameters by signature
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'commandName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'parameterName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'commandAst')]
    [CmdletBinding()]
    param()

    # ============================================================
    # Shared Completer Scriptblocks
    # ============================================================

    # SectionName completer - used by multiple commands
    $SectionNameCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

        $getParameters = @{ ErrorAction = 'SilentlyContinue' }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $getParameters['Token'] = $fakeBoundParameters['Token']
        }

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
        }
    }

    # SectionId completer - used by multiple commands
    $SectionIdCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

        $getParameters = @{ ErrorAction = 'SilentlyContinue' }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $getParameters['Token'] = $fakeBoundParameters['Token']
        }

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

    # Path completer for Update-PatLibrary - browses Plex server filesystem
    $LibraryPathCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

        # Check if ServerUri was explicitly provided
        $usingDefaultServer = -not $fakeBoundParameters.ContainsKey('ServerUri')

        # If using default server, verify it exists
        if ($usingDefaultServer) {
            try {
                $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                if (-not $defaultServer) { return }
            }
            catch {
                Write-Debug "Tab completion failed: Could not retrieve default server"
                return
            }
        }

        # Get SectionId - could be direct or via SectionName
        $sectionId = $null
        if ($fakeBoundParameters.ContainsKey('SectionId')) {
            $sectionId = $fakeBoundParameters['SectionId']
        }
        elseif ($fakeBoundParameters.ContainsKey('SectionName')) {
            try {
                $getParameters = @{ ErrorAction = 'SilentlyContinue' }
                if (-not $usingDefaultServer) {
                    $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                }
                $sections = Get-PatLibrary @getParameters
                $matchedSection = $sections.Directory | Where-Object { $_.title -eq $fakeBoundParameters['SectionName'] }
                if ($matchedSection) {
                    $sectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
                }
            }
            catch {
                Write-Debug "Tab completion failed: Could not resolve section name to ID: $($_.Exception.Message)"
            }
        }

        if (-not $sectionId) { return }

        # Get root paths for this section
        try {
            $pathParameters = @{ SectionId = $sectionId; ErrorAction = 'SilentlyContinue' }
            if (-not $usingDefaultServer) {
                $pathParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
            }
            $rootPaths = Get-PatLibraryPath @pathParameters

            if (-not $completerInput.StrippedWord) {
                # No input yet - show root paths
                foreach ($rootPath in $rootPaths) {
                    New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                }
            }
            else {
                # Determine the path to browse
                # If strippedWord exactly matches a root path, browse that path
                # Otherwise, get the parent directory manually (preserve Unix paths)
                $exactRoot = $rootPaths | Where-Object { $_.path -ieq $completerInput.StrippedWord }
                $pathToBrowse = if ($exactRoot) {
                    $completerInput.StrippedWord
                } else {
                    # Manual parent path extraction to preserve forward slashes
                    # Split-Path on Windows converts /foo/bar to \foo\bar which breaks Linux paths
                    $lastSlash = [Math]::Max($completerInput.StrippedWord.LastIndexOf('/'), $completerInput.StrippedWord.LastIndexOf('\'))
                    if ($lastSlash -gt 0) { $completerInput.StrippedWord.Substring(0, $lastSlash) } else { $null }
                }

                $browsedItems = $false
                if ($pathToBrowse) {
                    try {
                        $browseParameters = @{ Path = $pathToBrowse; ErrorAction = 'SilentlyContinue' }
                        if (-not $usingDefaultServer) {
                            $browseParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
                        }
                        $items = Get-PatLibraryChildItem @browseParameters

                        if ($items) {
                            $browsedItems = $true
                            foreach ($item in $items) {
                                # Get the path property (handle both 'path' and 'Path' casing)
                                $itemPath = if ($item.PSObject.Properties['path']) { $item.path } elseif ($item.PSObject.Properties['Path']) { $item.Path } else { $null }
                                if ($itemPath -and $itemPath -ilike "$($completerInput.StrippedWord)*") {
                                    New-PatCompletionResult -Value $itemPath -QuoteChar $completerInput.QuoteChar
                                }
                            }
                        }
                    }
                    catch {
                        Write-Debug "Tab completion failed: Could not browse path: $($_.Exception.Message)"
                    }
                }

                # Fall back to matching root paths if browsing didn't work
                if (-not $browsedItems) {
                    $matchingRoots = $rootPaths | Where-Object { $_.path -ilike "$($completerInput.StrippedWord)*" }
                    foreach ($rootPath in $matchingRoots) {
                        New-PatCompletionResult -Value $rootPath.path -QuoteChar $completerInput.QuoteChar
                    }
                }
            }
        }
        catch {
            Write-Debug "Tab completion failed: Could not retrieve library paths: $($_.Exception.Message)"
        }
    }

    # Collection name completer
    $CollectionTitleCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

        $getParameters = @{ ErrorAction = 'SilentlyContinue' }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $getParameters['Token'] = $fakeBoundParameters['Token']
        }
        if ($fakeBoundParameters.ContainsKey('SectionId')) {
            $getParameters['SectionId'] = $fakeBoundParameters['SectionId']
        }
        if ($fakeBoundParameters.ContainsKey('SectionName')) {
            $getParameters['SectionName'] = $fakeBoundParameters['SectionName']
        }

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

    # Playlist title completer
    $PlaylistTitleCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

        $getParameters = @{ ErrorAction = 'SilentlyContinue' }
        if ($fakeBoundParameters.ContainsKey('ServerUri')) {
            $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
        }
        if ($fakeBoundParameters.ContainsKey('Token')) {
            $getParameters['Token'] = $fakeBoundParameters['Token']
        }

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

    # ============================================================
    # Register Completers for Each Command
    # ============================================================

    # Update-PatLibrary
    Register-ArgumentCompleter -CommandName 'Update-PatLibrary' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Update-PatLibrary' -ParameterName 'Path' -ScriptBlock $LibraryPathCompleter

    # Get-PatLibrary - no completers needed (just retrieves all sections)

    # Get-PatLibraryPath
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryPath' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryPath' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatLibraryChildItem
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryChildItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryChildItem' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatLibraryItem
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatLibraryItem' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Search-PatMedia
    Register-ArgumentCompleter -CommandName 'Search-PatMedia' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Search-PatMedia' -ParameterName 'SectionId' -ScriptBlock $SectionIdCompleter

    # Get-PatCollection
    Register-ArgumentCompleter -CommandName 'Get-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Get-PatCollection' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # New-PatCollection
    Register-ArgumentCompleter -CommandName 'New-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter

    # Remove-PatCollection
    Register-ArgumentCompleter -CommandName 'Remove-PatCollection' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Remove-PatCollection' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Add-PatCollectionItem
    Register-ArgumentCompleter -CommandName 'Add-PatCollectionItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Add-PatCollectionItem' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Remove-PatCollectionItem
    Register-ArgumentCompleter -CommandName 'Remove-PatCollectionItem' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
    Register-ArgumentCompleter -CommandName 'Remove-PatCollectionItem' -ParameterName 'Title' -ScriptBlock $CollectionTitleCompleter

    # Get-PatPlaylist
    Register-ArgumentCompleter -CommandName 'Get-PatPlaylist' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Remove-PatPlaylist
    Register-ArgumentCompleter -CommandName 'Remove-PatPlaylist' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Add-PatPlaylistItem
    Register-ArgumentCompleter -CommandName 'Add-PatPlaylistItem' -ParameterName 'Title' -ScriptBlock $PlaylistTitleCompleter

    # Sync-PatMedia
    Register-ArgumentCompleter -CommandName 'Sync-PatMedia' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter

    # Get-PatSyncPlan
    Register-ArgumentCompleter -CommandName 'Get-PatSyncPlan' -ParameterName 'SectionName' -ScriptBlock $SectionNameCompleter
}
