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

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

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

            $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
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
        })]
        [string]
        $SectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
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
        })]
        [int]
        $SectionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
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

        # Build headers with authentication if we have server object or token
        $headers = if ($server) {
            Get-PatAuthenticationHeader -Server $server
        }
        else {
            $h = @{ Accept = 'application/json' }
            if (-not [string]::IsNullOrWhiteSpace($Token)) {
                $h['X-Plex-Token'] = $Token
                Write-Debug "Adding X-Plex-Token header for authenticated request"
            }
            $h
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
