function Get-PatLibraryItem {
    <#
    .SYNOPSIS
        Retrieves media items from a Plex library.

    .DESCRIPTION
        Gets all media items (movies, TV shows, music, etc.) from a specified Plex library section.
        Returns metadata for each item including title, year, rating, and other properties.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER SectionId
        The ID of the library section to retrieve items from.

    .PARAMETER SectionName
        The name of the library section to retrieve items from (e.g., "Movies", "TV Shows").

    .EXAMPLE
        Get-PatLibraryItem -SectionId 1

        Retrieves all items from library section 1.

    .EXAMPLE
        Get-PatLibraryItem -SectionName "Movies"

        Retrieves all items from the Movies library.

    .EXAMPLE
        Get-PatLibrary | Where-Object { $_.Directory.title -eq 'Movies' } | ForEach-Object { Get-PatLibraryItem -SectionId ($_.Directory.key -replace '.*/(\d+)$', '$1') }

        Gets the Movies library and retrieves all items from it.

    .OUTPUTS
        PSCustomObject[]
        Returns an array of media item metadata objects from the Plex API.
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
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Strip leading quotes for matching
            $strippedWord = $wordToComplete -replace "^[`"']", ''

            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                try {
                    $sections = Get-PatLibrary -ServerUri $fakeBoundParameters['ServerUri'] -ErrorAction 'SilentlyContinue'
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -ilike "$strippedWord*") {
                            [System.Management.Automation.CompletionResult]::new($sectionId, "$sectionId - $($_.title)", 'ParameterValue', "$($_.title) (ID: $sectionId)")
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId: $($_.Exception.Message)"
                }
            }
            else {
                try {
                    $sections = Get-PatLibrary -ErrorAction 'SilentlyContinue'
                    $sections.Directory | ForEach-Object {
                        $sectionId = ($_.key -replace '.*/(\d+)$', '$1')
                        if ($sectionId -ilike "$strippedWord*") {
                            [System.Management.Automation.CompletionResult]::new($sectionId, "$sectionId - $($_.title)", 'ParameterValue', "$($_.title) (ID: $sectionId)")
                        }
                    }
                }
                catch {
                    Write-Debug "Tab completion failed for SectionId (default server): $($_.Exception.Message)"
                }
            }
        })]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri
    )

    begin {
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
                Write-Verbose "Using default server: $effectiveUri"
            }
            catch {
                throw "Failed to get default server: $($_.Exception.Message)"
            }
        }
        else {
            Write-Verbose "Using specified server: $ServerUri"
        }

        # Build headers with authentication if we have server object
        $headers = if ($server) {
            Get-PatAuthHeader -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }
    }

    process {
        try {
            # Resolve SectionName to SectionId if needed
            $resolvedSectionId = $SectionId
            if ($SectionName) {
                # If using default server, don't pass ServerUri so Get-PatLibrary can use token
                if ($usingDefaultServer) {
                    $sections = Get-PatLibrary -ErrorAction 'Stop'
                }
                else {
                    $sections = Get-PatLibrary -ServerUri $effectiveUri -ErrorAction 'Stop'
                }
                $matchingSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
                if (-not $matchingSection) {
                    throw "Library section '$SectionName' not found"
                }
                $resolvedSectionId = [int]($matchingSection.key -replace '.*/(\d+)$', '$1')
                Write-Verbose "Resolved section name '$SectionName' to ID $resolvedSectionId"
            }

            $endpoint = "/library/sections/$resolvedSectionId/all"
            Write-Verbose "Retrieving all items from library section $resolvedSectionId"

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Return the Metadata array
            if ($result.Metadata) {
                $result.Metadata
            }
            else {
                Write-Verbose "No items found in library section $resolvedSectionId"
            }
        }
        catch {
            throw "Failed to get library items: $($_.Exception.Message)"
        }
    }
}
