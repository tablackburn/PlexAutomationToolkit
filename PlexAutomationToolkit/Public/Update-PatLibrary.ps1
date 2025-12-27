function Update-PatLibrary {
    <#
    .SYNOPSIS
        Refreshes a Plex library section.

    .DESCRIPTION
        Triggers a refresh scan on a specified Plex library section.
        Optionally scans a specific path within the library.
        You can specify the section by ID or by friendly name.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER SectionId
        The ID of the library section to refresh

    .PARAMETER SectionName
        The friendly name of the library section to refresh (e.g., "Movies", "TV Shows")

    .PARAMETER Path
        Optional path within the library to scan. If omitted, the entire section is scanned.

    .PARAMETER PassThru
        If specified, returns the library section object after refreshing.

    .PARAMETER SkipPathValidation
        If specified, skips validation that the path exists before triggering the refresh.
        Use when you know the path is valid or want to scan a path that may not be browsable.

    .PARAMETER Wait
        If specified, waits for the library scan to complete before returning.

    .PARAMETER Timeout
        Maximum time in seconds to wait for the scan to complete when using -Wait.
        Default is 300 seconds (5 minutes).

    .PARAMETER ReportChanges
        If specified, returns a report of changes detected during the scan.
        Automatically enables -Wait behavior.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2

        Refreshes the entire library section 2.

    .EXAMPLE
        Update-PatLibrary -SectionName "Movies"

        Refreshes the "Movies" library section on the default stored server.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies"

        Refreshes the library section named "Movies".

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -Path "/mnt/media/Movies"

        Refreshes only the specified path within library section 2.

    .EXAMPLE
        Update-PatLibrary -SectionId 2 -Path "/mnt/media/Movies"

        Refreshes only the specified path within library section 2 on the default stored server.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies" -Path "/mnt/media/Movies/Action"

        Refreshes only the specified path within the "Movies" library section.

    .EXAMPLE
        Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -WhatIf

        Shows what would happen if the command runs without actually refreshing the library.

    .EXAMPLE
        Update-PatLibrary -SectionId 2 -PassThru

        Refreshes library section 2 and returns the library object.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'

        Validates that the path exists (default behavior), then triggers the refresh.
        Throws an error if the path is invalid or not within the library's configured paths.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -SkipPathValidation

        Skips path validation and triggers the refresh directly. Use when you know the
        path is valid or want to scan a path that may not be browsable.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -Wait

        Validates the path, triggers the refresh, and waits for the scan to complete.

    .EXAMPLE
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -Wait -Timeout 60

        Validates the path, triggers the refresh, and waits up to 60 seconds for completion.

    .EXAMPLE
        $changes = Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -ReportChanges
        $changes | Where-Object ChangeType -eq 'Added'

        Returns a list of items that were added or removed by the scan.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'parameterName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandAst',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Strip leading quotes for matching (case-insensitive)
            $quoteChar = ''
            $strippedWord = $wordToComplete
            if ($wordToComplete -match "^([`"'])(.*)$") {
                $quoteChar = $Matches[1]
                $strippedWord = $Matches[2]
            }

            # Use provided ServerUri if available, otherwise use default server
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                try {
                    $sections = Get-PatLibrary -ServerUri $fakeBoundParameters['ServerUri'] -ErrorAction 'SilentlyContinue'
                    foreach ($sectionTitle in $sections.Directory.title) {
                        if ($sectionTitle -ilike "$strippedWord*") {
                            if ($quoteChar) { $completionText = "$quoteChar$sectionTitle$quoteChar" }
                            elseif ($sectionTitle -match '\s') { $completionText = "'$sectionTitle'" }
                            else { $completionText = $sectionTitle }
                            [System.Management.Automation.CompletionResult]::new($completionText, $sectionTitle, 'ParameterValue', $sectionTitle)
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionName: $($_.Exception.Message)"
                }
            }
            else {
                # Fall back to default server - don't pass ServerUri so Get-PatLibrary retrieves server object with token
                try {
                    $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                    foreach ($sectionTitle in $sections.Directory.title) {
                        if ($sectionTitle -ilike "$strippedWord*") {
                            if ($quoteChar) { $completionText = "$quoteChar$sectionTitle$quoteChar" }
                            elseif ($sectionTitle -match '\s') { $completionText = "'$sectionTitle'" }
                            else { $completionText = $sectionTitle }
                            [System.Management.Automation.CompletionResult]::new($completionText, $sectionTitle, 'ParameterValue', $sectionTitle)
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionName (default server): $($_.Exception.Message)"
                }
            }
        })]
        [string]
        $SectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Strip leading quotes for matching (supports 'value and "value)
            $quoteChar = ''
            $strippedWord = $wordToComplete
            if ($wordToComplete -match "^([`"'])(.*)$") {
                $quoteChar = $Matches[1]
                $strippedWord = $Matches[2]
            }

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
                    if ($usingDefaultServer) {
                        $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                    }
                    else {
                        $sections = Get-PatLibrary -ServerUri $fakeBoundParameters['ServerUri'] -ErrorAction 'SilentlyContinue'
                    }
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
                if ($usingDefaultServer) {
                    $rootPaths = Get-PatLibraryPath -SectionId $sectionId -ErrorAction 'SilentlyContinue'
                }
                else {
                    $rootPaths = Get-PatLibraryPath -ServerUri $fakeBoundParameters['ServerUri'] -SectionId $sectionId -ErrorAction 'SilentlyContinue'
                }

                # Helper to create completion result with proper quoting
                $createCompletion = {
                    param($value)
                    if ($value -ilike "$strippedWord*") {
                        if ($quoteChar) { $text = "$quoteChar$value$quoteChar" }
                        elseif ($value -match '\s') { $text = "'$value'" }
                        else { $text = $value }
                        [System.Management.Automation.CompletionResult]::new($text, $value, 'ParameterValue', $value)
                    }
                }

                if (-not $strippedWord) {
                    # No input yet - show root paths
                    foreach ($rootPath in $rootPaths) {
                        $result = & $createCompletion $rootPath.path
                        if ($result) { $result }
                    }
                }
                else {
                    # Determine the path to browse
                    # If strippedWord exactly matches a root path, browse that path
                    # Otherwise, get the parent directory manually (preserve Unix paths)
                    $exactRoot = $rootPaths | Where-Object { $_.path -ieq $strippedWord }
                    $pathToBrowse = if ($exactRoot) {
                        $strippedWord
                    } else {
                        # Manual parent path extraction to preserve forward slashes
                        # Split-Path on Windows converts /foo/bar to \foo\bar which breaks Linux paths
                        $lastSlash = [Math]::Max($strippedWord.LastIndexOf('/'), $strippedWord.LastIndexOf('\'))
                        if ($lastSlash -gt 0) { $strippedWord.Substring(0, $lastSlash) } else { $null }
                    }

                    $browsedItems = $false
                    if ($pathToBrowse) {
                        try {
                            if ($usingDefaultServer) {
                                $items = Get-PatLibraryChildItem -Path $pathToBrowse -ErrorAction 'SilentlyContinue'
                            }
                            else {
                                $items = Get-PatLibraryChildItem -ServerUri $fakeBoundParameters['ServerUri'] -Path $pathToBrowse -ErrorAction 'SilentlyContinue'
                            }

                            if ($items) {
                                $browsedItems = $true
                                foreach ($item in $items) {
                                    # Get the path property (handle both 'path' and 'Path' casing)
                                    $itemPath = if ($item.PSObject.Properties['path']) { $item.path } elseif ($item.PSObject.Properties['Path']) { $item.Path } else { $null }
                                    if ($itemPath) {
                                        $result = & $createCompletion $itemPath
                                        if ($result) { $result }
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
                        $matchingRoots = $rootPaths | Where-Object { $_.path -ilike "$strippedWord*" }
                        foreach ($rootPath in $matchingRoots) {
                            $result = & $createCompletion $rootPath.path
                            if ($result) { $result }
                        }
                    }
                }
            }
            catch {
                Write-Debug "Tab completion failed: Could not retrieve library paths: $($_.Exception.Message)"
            }
        })]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $PassThru,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $SkipPathValidation,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $Wait,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateRange(1, 3600)]
        [int]
        $Timeout = 300,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [switch]
        $ReportChanges,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri
    )

    # Use default server if ServerUri not specified
    $server = $null
    $effectiveUri = $ServerUri
    $usingDefaultServer = $false
    if (-not $ServerUri) {
        try {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
            if (-not $server) {
                throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
            }
            $effectiveUri = $server.uri
            $usingDefaultServer = $true
        }
        catch {
            throw "Failed to get default server: $($_.Exception.Message)"
        }
    }

    # If using section name, resolve it to section ID
    $resolvedSectionId = $SectionId
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        try {
            # If using default server, don't pass ServerUri so Get-PatLibrary can retrieve server object with token
            if ($usingDefaultServer) {
                $sections = Get-PatLibrary -ErrorAction 'Stop'
            }
            else {
                $sections = Get-PatLibrary -ServerUri $effectiveUri -ErrorAction 'Stop'
            }
            $matchedSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }

            if (-not $matchedSection) {
                throw "No library section found with name '$SectionName'"
            }

            if ($matchedSection -is [array]) {
                throw "Multiple library sections found with name '$SectionName'. Please use -SectionId instead."
            }

            $resolvedSectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
        }
        catch {
            throw "Failed to resolve section name: $($_.Exception.Message)"
        }
    }

    # Pre-validation: Check if path exists (default behavior, skip with -SkipPathValidation)
    if ($Path -and -not $SkipPathValidation) {
        Write-Verbose "Validating path: $Path"
        $testParams = @{ Path = $Path }
        if ($effectiveUri) { $testParams['ServerUri'] = $effectiveUri }
        if ($resolvedSectionId) { $testParams['SectionId'] = $resolvedSectionId }

        $pathValid = Test-PatLibraryPath @testParams
        if (-not $pathValid) {
            throw "Path validation failed: '$Path' does not exist or is not within the library's configured paths. Use -SkipPathValidation to bypass this check."
        }
        Write-Verbose "Path validation passed"
    }

    # Capture before state if we need to report changes
    $beforeItems = $null
    if ($ReportChanges) {
        Write-Verbose "Capturing library state before scan"
        $getItemParams = @{ SectionId = $resolvedSectionId }
        if ($effectiveUri) { $getItemParams['ServerUri'] = $effectiveUri }
        $beforeItems = @(Get-PatLibraryItem @getItemParams -ErrorAction 'SilentlyContinue')
        Write-Verbose "Captured $($beforeItems.Count) items before scan"
    }

    $endpoint = "/library/sections/$resolvedSectionId/refresh"
    $queryString = $null

    if ($Path) {
        $queryString = "path=$([System.Uri]::EscapeDataString($Path))"
    }

    $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryString

    if ($Path) {
        $target = "section $resolvedSectionId path '$Path'"
    }
    else {
        $target = "section $resolvedSectionId"
    }

    # Build headers with authentication if we have server object
    $headers = if ($server) {
        Get-PatAuthHeaders -Server $server
    }
    else {
        @{ Accept = 'application/json' }
    }

    if ($PSCmdlet.ShouldProcess($target, 'Refresh library')) {
        try {
            Invoke-PatApi -Uri $uri -Method 'Post' -Headers $headers -ErrorAction 'Stop'

            # Wait for scan to complete if requested
            if ($Wait -or $ReportChanges) {
                Write-Verbose "Waiting for scan to complete (timeout: ${Timeout}s)"
                $waitParams = @{
                    SectionId       = $resolvedSectionId
                    Timeout         = $Timeout
                    PollingInterval = 2
                }
                if ($effectiveUri) { $waitParams['ServerUri'] = $effectiveUri }

                Wait-PatLibraryScan @waitParams
                Write-Verbose "Scan completed"
            }

            # Report changes if requested
            if ($ReportChanges) {
                Write-Verbose "Capturing library state after scan"
                $getItemParams = @{ SectionId = $resolvedSectionId }
                if ($effectiveUri) { $getItemParams['ServerUri'] = $effectiveUri }
                $afterItems = @(Get-PatLibraryItem @getItemParams -ErrorAction 'SilentlyContinue')
                Write-Verbose "Captured $($afterItems.Count) items after scan"

                $changes = Compare-PatLibraryContent -Before $beforeItems -After $afterItems
                $changes
            }
            elseif ($PassThru) {
                # Return the refreshed library section
                if ($usingDefaultServer) {
                    Get-PatLibrary -SectionId $resolvedSectionId -ErrorAction 'Stop'
                }
                else {
                    Get-PatLibrary -ServerUri $effectiveUri -SectionId $resolvedSectionId -ErrorAction 'Stop'
                }
            }
        }
        catch {
            throw "Failed to refresh Plex library: $($_.Exception.Message)"
        }
    }
}
