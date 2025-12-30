function Get-PatLibraryChildItem {
    <#
    .SYNOPSIS
        Lists directories and files at a given path on the Plex server.

    .DESCRIPTION
        Browses the filesystem on the Plex server, listing subdirectories and files
        at a specified path. Uses the Plex internal browse service endpoint.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER Path
        The absolute filesystem path to browse (e.g., /mnt/media, /var/lib/plexmediaserver)
        If omitted, lists root-level accessible paths.

    .PARAMETER SectionId
        Optional library section ID. When provided, the command browses each path configured for that
        section. Cannot be combined with SectionName.

    .PARAMETER SectionName
        Optional library section name (e.g., "Movies"). When provided, the command browses each path
        configured for that section. Cannot be combined with SectionId.

    .EXAMPLE
        Get-PatLibraryChildItem -ServerUri "http://plex.example.com:32400" -Path "/mnt/media"

        Lists directories and files under /mnt/media.

    .EXAMPLE
        Get-PatLibraryChildItem

        Lists root-level paths from the default stored server.

    .EXAMPLE
        Get-PatLibraryChildItem -Path "/mnt/smb/nas5/movies"

        Lists all items (directories and files) under the movies path.

    .EXAMPLE
        Get-PatLibraryChildItem -SectionName "Movies"

        Lists items from every path configured for the Movies section.

    .OUTPUTS
        PSCustomObject
    #>
    [OutputType([PSCustomObject], [object[]])]
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
    [CmdletBinding(DefaultParameterSetName = 'PathOnly')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'PathOnly')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
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
        })]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [ArgumentCompleter({
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

    try {
        $pathsToBrowse = @()

        # If section parameters provided, collect all section locations
        if ($SectionName -or $SectionId) {
            # If using default server, don't pass ServerUri so Get-PatLibrary can retrieve server object with token
            if ($usingDefaultServer) {
                $sections = Get-PatLibrary -ErrorAction 'Stop'
            }
            else {
                $libParams = @{ ServerUri = $effectiveUri; ErrorAction = 'Stop' }
                if ($Token) { $libParams['Token'] = $Token }
                $sections = Get-PatLibrary @libParams
            }

            $matchingSection = $null
            if ($SectionName) {
                $matchingSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
                if (-not $matchingSection) {
                    throw "Library section '$SectionName' not found"
                }
            }
            else {
                $matchingSection = $sections.Directory | Where-Object {
                    ($_.key -replace '.*/(\d+)$', '$1') -eq $SectionId.ToString()
                }
                if (-not $matchingSection) {
                    throw "Library section with ID $SectionId not found"
                }
            }

            if ($matchingSection.Location) {
                # Handle both single location and array of locations
                $locations = @($matchingSection.Location)
                foreach ($location in $locations) {
                    if ($location.path) {
                        $pathsToBrowse += $location.path
                    }
                }
            }
        }

        if ($Path) {
            # Explicit path overrides any section-derived paths
            $pathsToBrowse = @($Path)
        }

        if (-not $pathsToBrowse -or $pathsToBrowse.Count -eq 0) {
            # No path specified, no section provided -> browse root
            $pathsToBrowse = @($null)
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

        $results = @()

        foreach ($p in $pathsToBrowse) {
            $endpoint = '/services/browse'

            if ($p) {
                $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($p)
                $pathB64 = [Convert]::ToBase64String($pathBytes)
                $endpoint += "/$pathB64"
            }

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString 'includeFiles=1'
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            if ($result.Path) { $results += $result.Path }
            if ($result.File) { $results += $result.File }

            if (-not $result.Path -and -not $result.File) {
                Write-Verbose "No items found at path: $p"
            }
        }

        $results
    }
    catch {
        $errPath = if ($Path) { $Path } elseif ($SectionName) { $SectionName } elseif ($SectionId) { $SectionId } else { '<root>' }
        throw "Failed to list items for ${errPath}: $($_.Exception.Message)"
    }
}
