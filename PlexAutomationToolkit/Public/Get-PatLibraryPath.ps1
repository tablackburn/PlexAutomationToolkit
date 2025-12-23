function Get-PatLibraryPath {
    <#
    .SYNOPSIS
        Retrieves library section paths from a Plex server.

    .DESCRIPTION
        Gets the configured filesystem paths for Plex library sections.
        Returns paths for all sections, a specific section by ID, or a specific section by name.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER SectionId
        The ID of the library section. If omitted, returns paths for all sections.

    .PARAMETER SectionName
        The friendly name of the library section (e.g., "Movies", "TV Shows")

    .EXAMPLE
        Get-PatLibraryPath

        Retrieves all configured paths for all library sections from the default stored server.

    .EXAMPLE
        Get-PatLibraryPath -ServerUri "http://plex.example.com:32400" -SectionId 1

        Retrieves all configured paths for library section 1.

    .EXAMPLE
        Get-PatLibraryPath -SectionId 2

        Retrieves all configured paths for library section 2 from the default stored server.

    .EXAMPLE
        Get-PatLibraryPath -SectionName "Movies"

        Retrieves all configured paths for the "Movies" library section.

    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
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
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -like "$wordToComplete*") {
                            [System.Management.Automation.CompletionResult]::new($sectionId, "$sectionId - $($_.title)", 'ParameterValue', "$($_.title) (ID: $sectionId)")
                        }
                    }
                }
                catch {
                    # Silently fail if server is unavailable
                }
            }
        })]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
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
        $SectionName
    )

    # Use default server if ServerUri not specified
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

    try {
        # Get all sections first
        # If using default server, don't pass ServerUri so Get-PatLibrary can retrieve server object with token
        if ($usingDefaultServer) {
            $allSections = Get-PatLibrary -ErrorAction 'Stop'
        }
        else {
            $allSections = Get-PatLibrary -ServerUri $ServerUri -ErrorAction 'Stop'
        }

        # If SectionName is provided, filter to that section
        if ($SectionName) {
            $matchingSection = $allSections.Directory | Where-Object { $_.title -eq $SectionName }

            if (-not $matchingSection) {
                throw "Library section '$SectionName' not found"
            }

            # Return Location objects enriched with section context
            if ($matchingSection.Location) {
                foreach ($location in $matchingSection.Location) {
                    [PSCustomObject]@{
                        id      = $location.id
                        path    = $location.path
                        section = $matchingSection.title
                        sectionId = ($matchingSection.key -replace '.*/(\d+)$', '$1')
                        sectionType = $matchingSection.type
                    }
                }
            }
            else {
                Write-Verbose "No paths configured for section '$SectionName'"
            }
        }
        elseif ($SectionId) {
            # Filter to specific section by ID
            $matchingSection = $allSections.Directory | Where-Object {
                ($_.key -replace '.*/(\d+)$', '$1') -eq $SectionId.ToString()
            }

            if (-not $matchingSection) {
                throw "Library section with ID $SectionId not found"
            }

            # Return Location objects enriched with section context
            if ($matchingSection.Location) {
                foreach ($location in $matchingSection.Location) {
                    [PSCustomObject]@{
                        id      = $location.id
                        path    = $location.path
                        section = $matchingSection.title
                        sectionId = ($matchingSection.key -replace '.*/(\d+)$', '$1')
                        sectionType = $matchingSection.type
                    }
                }
            }
            else {
                Write-Verbose "No paths configured for section $SectionId"
            }
        }
        else {
            # Return all locations from all sections with context
            if ($allSections.Directory) {
                foreach ($section in $allSections.Directory) {
                    if ($section.Location) {
                        $sectionId = ($section.key -replace '.*/(\d+)$', '$1')
                        foreach ($location in $section.Location) {
                            [PSCustomObject]@{
                                id      = $location.id
                                path    = $location.path
                                section = $section.title
                                sectionId = $sectionId
                                sectionType = $section.type
                            }
                        }
                    }
                }
            }
            else {
                Write-Verbose "No library sections found"
            }
        }
    }
    catch {
        $errorMsg = if ($SectionName) {
            "Failed to retrieve library paths for section '$SectionName': $($_.Exception.Message)"
        }
        elseif ($SectionId) {
            "Failed to retrieve library paths for section $SectionId : $($_.Exception.Message)"
        }
        else {
            "Failed to retrieve library paths: $($_.Exception.Message)"
        }
        throw $errorMsg
    }
}
