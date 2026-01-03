function Get-PatSectionNameCompletion {
    <#
    .SYNOPSIS
        Gets section name completions for tab completion.
    .DESCRIPTION
        Helper function that retrieves section names from the Plex server
        and returns matching completion results. This function is called
        by the SectionName argument completer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WordToComplete,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [string]$Token
    )

    $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $WordToComplete

    $getParameters = @{ ErrorAction = 'SilentlyContinue' }
    if ($ServerUri) {
        $getParameters['ServerUri'] = $ServerUri
    }
    if ($Token) {
        $getParameters['Token'] = $Token
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

function Get-PatSectionIdCompletion {
    <#
    .SYNOPSIS
        Gets section ID completions for tab completion.
    .DESCRIPTION
        Helper function that retrieves section IDs from the Plex server
        and returns matching completion results. This function is called
        by the SectionId argument completer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WordToComplete,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [string]$Token
    )

    $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $WordToComplete

    $getParameters = @{ ErrorAction = 'SilentlyContinue' }
    if ($ServerUri) {
        $getParameters['ServerUri'] = $ServerUri
    }
    if ($Token) {
        $getParameters['Token'] = $Token
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

function Get-PatLibraryPathCompletion {
    <#
    .SYNOPSIS
        Gets library path completions for tab completion.
    .DESCRIPTION
        Helper function that browses the Plex server filesystem
        and returns matching path completion results. This function is called
        by the Path argument completer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WordToComplete,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [int]$SectionId,

        [Parameter()]
        [string]$SectionName
    )

    $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $WordToComplete

    # Check if ServerUri was explicitly provided
    $usingDefaultServer = -not $ServerUri

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
    $resolvedSectionId = $null
    if ($SectionId) {
        $resolvedSectionId = $SectionId
    }
    elseif ($SectionName) {
        try {
            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if (-not $usingDefaultServer) {
                $getParameters['ServerUri'] = $ServerUri
            }
            $sections = Get-PatLibrary @getParameters
            $matchedSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
            if ($matchedSection) {
                $resolvedSectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
            }
        }
        catch {
            Write-Debug "Tab completion failed: Could not resolve section name to ID: $($_.Exception.Message)"
        }
    }

    if (-not $resolvedSectionId) { return }

    # Get root paths for this section
    try {
        $pathParameters = @{ SectionId = $resolvedSectionId; ErrorAction = 'SilentlyContinue' }
        if (-not $usingDefaultServer) {
            $pathParameters['ServerUri'] = $ServerUri
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
                        $browseParameters['ServerUri'] = $ServerUri
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

function Get-PatCollectionTitleCompletion {
    <#
    .SYNOPSIS
        Gets collection title completions for tab completion.
    .DESCRIPTION
        Helper function that retrieves collection titles from the Plex server
        and returns matching completion results. This function is called
        by the Collection Title argument completer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WordToComplete,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [int]$SectionId,

        [Parameter()]
        [string]$SectionName
    )

    $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $WordToComplete

    $getParameters = @{ ErrorAction = 'SilentlyContinue' }
    if ($ServerUri) {
        $getParameters['ServerUri'] = $ServerUri
    }
    if ($Token) {
        $getParameters['Token'] = $Token
    }
    if ($SectionId) {
        $getParameters['SectionId'] = $SectionId
    }
    if ($SectionName) {
        $getParameters['SectionName'] = $SectionName
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

function Get-PatPlaylistTitleCompletion {
    <#
    .SYNOPSIS
        Gets playlist title completions for tab completion.
    .DESCRIPTION
        Helper function that retrieves playlist titles from the Plex server
        and returns matching completion results. This function is called
        by the Playlist Title argument completer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WordToComplete,

        [Parameter()]
        [string]$ServerUri,

        [Parameter()]
        [string]$Token
    )

    $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $WordToComplete

    $getParameters = @{ ErrorAction = 'SilentlyContinue' }
    if ($ServerUri) {
        $getParameters['ServerUri'] = $ServerUri
    }
    if ($Token) {
        $getParameters['Token'] = $Token
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
