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
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $serverUri = $null

            # Use provided ServerUri if available
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $serverUri = $fakeBoundParameters['ServerUri']
            }
            else {
                # Fall back to default server
                try {
                    $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                    if ($defaultServer) {
                        $serverUri = $defaultServer.uri
                    }
                }
                catch {
                    # Silently fail if default server retrieval fails
                }
            }

            if ($serverUri) {
                try {
                    $sections = Get-PatLibrary -ServerUri $serverUri -ErrorAction 'SilentlyContinue'
                    $sections.Directory.title | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                        $sectionTitle = $_
                        # Quote section names that contain spaces
                        if ($sectionTitle -match '\s') {
                            $completionText = "'$sectionTitle'"
                        }
                        else {
                            $completionText = $sectionTitle
                        }
                        [System.Management.Automation.CompletionResult]::new($completionText, $sectionTitle, 'ParameterValue', $sectionTitle)
                    }
                }
                catch {
                    # Silently fail if server is unavailable
                }
            }
        })]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Get ServerUri
            $serverUri = $null
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $serverUri = $fakeBoundParameters['ServerUri']
            }
            else {
                try {
                    $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                    if ($defaultServer) {
                        $serverUri = $defaultServer.uri
                    }
                }
                catch {
                    # Silently fail if default server retrieval fails
                }
            }

            if (-not $serverUri) { return }

            # Get SectionId - could be direct or via SectionName
            $sectionId = $null
            if ($fakeBoundParameters.ContainsKey('SectionId')) {
                $sectionId = $fakeBoundParameters['SectionId']
            }
            elseif ($fakeBoundParameters.ContainsKey('SectionName')) {
                try {
                    $sections = Get-PatLibrary -ServerUri $serverUri -ErrorAction 'SilentlyContinue'
                    $matchedSection = $sections.Directory | Where-Object { $_.title -eq $fakeBoundParameters['SectionName'] }
                    if ($matchedSection) {
                        $sectionId = [int]($matchedSection.key -replace '.*/(\d+)$', '$1')
                    }
                }
                catch {
                    # Silently fail if section lookup fails
                }
            }

            if (-not $sectionId) { return }

            # Get root paths for this section
            try {
                $rootPaths = Get-PatLibraryPath -ServerUri $serverUri -SectionId $sectionId -ErrorAction 'SilentlyContinue'

                if (-not $wordToComplete) {
                    # No input yet - show root paths
                    foreach ($rootPath in $rootPaths) {
                        $path = $rootPath.path
                        if ($path -match '\s') {
                            $completionText = "'$path'"
                        }
                        else {
                            $completionText = $path
                        }
                        [System.Management.Automation.CompletionResult]::new($completionText, $path, 'ParameterValue', $path)
                    }
                }
                else {
                    # User has started typing - check if it matches any root paths
                    $matchingRoots = $rootPaths | Where-Object { $_.path -like "$wordToComplete*" }

                    if ($matchingRoots) {
                        # Show matching root paths
                        foreach ($rootPath in $matchingRoots) {
                            $path = $rootPath.path
                            if ($path -match '\s') {
                                $completionText = "'$path'"
                            }
                            else {
                                $completionText = $path
                            }
                            [System.Management.Automation.CompletionResult]::new($completionText, $path, 'ParameterValue', $path)
                        }
                    }
                    else {
                        # Try to browse subdirectories
                        $parentPath = Split-Path -Path $wordToComplete -Parent

                        if ($parentPath) {
                            try {
                                $items = Get-PatLibraryChildItem -ServerUri $serverUri -Path $parentPath -ErrorAction 'SilentlyContinue'
                                # Filter to directories only (items with 'path' property that aren't files)
                                $directories = $items | Where-Object {
                                    $_.PSObject.Properties.Name -contains 'path' -and
                                    $_.PSObject.TypeNames[0] -notlike '*File*'
                                }

                                foreach ($dir in $directories) {
                                    $dirPath = $dir.path
                                    if ($dirPath -like "$wordToComplete*") {
                                        if ($dirPath -match '\s') {
                                            $completionText = "'$dirPath'"
                                        }
                                        else {
                                            $completionText = $dirPath
                                        }
                                        [System.Management.Automation.CompletionResult]::new($completionText, $dirPath, 'ParameterValue', $dirPath)
                                    }
                                }
                            }
                            catch {
                                # Silently fail if browse fails
                            }
                        }
                    }
                }
            }
            catch {
                # Silently fail if path retrieval fails
            }
        })]
        [string]
        $Path
    )

    # Use default server if ServerUri not specified
    $server = $null
    $usingDefaultServer = $false
    if (-not $ServerUri) {
        try {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
            if (-not $server) {
                throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
            }
            $ServerUri = $server.uri
            $usingDefaultServer = $true
        }
        catch {
            throw "Failed to get default server: $($_.Exception.Message)"
        }
    }

    # If using section name, resolve it to section ID
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        try {
            # If using default server, don't pass ServerUri so Get-PatLibrary can retrieve server object with token
            if ($usingDefaultServer) {
                $sections = Get-PatLibrary -ErrorAction 'Stop'
            }
            else {
                $sections = Get-PatLibrary -ServerUri $ServerUri -ErrorAction 'Stop'
            }
            $matchedSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }

            if (-not $matchedSection) {
                throw "No library section found with name '$SectionName'"
            }

            if ($matchedSection -is [array]) {
                throw "Multiple library sections found with name '$SectionName'. Please use -SectionId instead."
            }

            $SectionId = [int]$matchedSection.key
        }
        catch {
            throw "Failed to resolve section name: $($_.Exception.Message)"
        }
    }

    $endpoint = "/library/sections/$SectionId/refresh"
    $queryString = $null

    if ($Path) {
        $queryString = "path=$([System.Uri]::EscapeDataString($Path))"
    }

    $uri = Join-PatUri -BaseUri $ServerUri -Endpoint $endpoint -QueryString $queryString

    if ($Path) {
        $target = "section $SectionId path '$Path'"
    }
    else {
        $target = "section $SectionId"
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
        }
        catch {
            throw "Failed to refresh Plex library: $($_.Exception.Message)"
        }
    }
}
