function New-PatCollection {
    <#
    .SYNOPSIS
        Creates a new collection in a Plex library.

    .DESCRIPTION
        Creates a new regular (non-smart) collection in the specified Plex library.
        You must provide at least one item to create the collection, as Plex does not
        support creating empty collections via the API.

    .PARAMETER Title
        The title/name of the new collection.

    .PARAMETER LibraryName
        The name of the library where the collection will be created. Supports tab completion.
        This is the preferred way to specify a library.

    .PARAMETER LibraryId
        The library section ID where the collection will be created.
        Use Get-PatLibrary to find library IDs.

    .PARAMETER RatingKey
        One or more media item rating keys to add to the collection upon creation.
        At least one item is required. Rating keys can be obtained from library
        browsing commands like Get-PatLibraryItem.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER PassThru
        If specified, returns the created collection object.

    .EXAMPLE
        New-PatCollection -Title 'Marvel Movies' -LibraryName 'Movies' -RatingKey 12345

        Creates a new collection named 'Marvel Movies' in the Movies library with one item.

    .EXAMPLE
        New-PatCollection -Title 'Horror Classics' -LibraryName 'Movies' -RatingKey 111, 222, 333 -PassThru

        Creates a collection with three items and returns the created collection object.

    .EXAMPLE
        Get-PatLibraryItem -LibraryId 1 -Title '*Batman*' |
            ForEach-Object { $_.ratingKey } |
            New-PatCollection -Title 'Batman Collection' -LibraryName 'Movies' -PassThru

        Creates a collection from all items matching 'Batman' in the Movies library.

    .OUTPUTS
        PlexAutomationToolkit.Collection (when -PassThru is specified)

        Returns the created collection object with properties:
        - CollectionId: Unique collection identifier
        - Title: Name of the collection
        - LibraryId: The library section ID
        - LibraryName: The name of the library
        - ItemCount: Number of items in the collection
        - ServerUri: The Plex server URI
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
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low', DefaultParameterSetName = 'ByLibraryName')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Title,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByLibraryName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $quoteChar = ''
            $strippedWord = $wordToComplete
            if ($wordToComplete -match "^([`"'])(.*)$") {
                $quoteChar = $Matches[1]
                $strippedWord = $Matches[2]
            }

            $getParams = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParams['ServerUri'] = $fakeBoundParameters['ServerUri']
            }

            $libraries = Get-PatLibrary @getParams

            foreach ($lib in $libraries.Directory) {
                if ($lib.title -ilike "$strippedWord*") {
                    $title = $lib.title
                    if ($quoteChar) {
                        $text = "$quoteChar$title$quoteChar"
                    }
                    elseif ($title -match '\s') {
                        $text = "'$title'"
                    }
                    else {
                        $text = $title
                    }

                    [System.Management.Automation.CompletionResult]::new(
                        $text,
                        $title,
                        'ParameterValue',
                        $title
                    )
                }
            }
        })]
        [string]
        $LibraryName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByLibraryId')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $LibraryId,

        [Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int[]]
        $RatingKey,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerUri $ServerUri
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers

        # Resolve LibraryName to LibraryId if needed
        $resolvedLibraryId = $LibraryId
        $resolvedLibraryName = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByLibraryName') {
            $libParams = @{ ErrorAction = 'Stop' }
            if ($script:serverContext.WasExplicitUri) { $libParams['ServerUri'] = $effectiveUri }
            $libraries = Get-PatLibrary @libParams
            $matchedLib = $libraries.Directory | Where-Object { $_.title -eq $LibraryName }
            if (-not $matchedLib) {
                throw "No library found with name '$LibraryName'"
            }
            $resolvedLibraryId = [int]$matchedLib.key
            $resolvedLibraryName = $matchedLib.title
            Write-Verbose "Resolved library '$LibraryName' to ID $resolvedLibraryId"
        }
        else {
            $libParams = @{ ErrorAction = 'SilentlyContinue' }
            if ($script:serverContext.WasExplicitUri) { $libParams['ServerUri'] = $effectiveUri }
            $libraries = Get-PatLibrary @libParams
            if ($libraries -and $libraries.Directory) {
                $matchedLib = $libraries.Directory | Where-Object { [int]$_.key -eq $LibraryId }
                if ($matchedLib) {
                    $resolvedLibraryName = $matchedLib.title
                }
            }
        }

        $allRatingKeys = [System.Collections.ArrayList]::new()
    }

    process {
        if ($RatingKey) {
            foreach ($key in $RatingKey) {
                $null = $allRatingKeys.Add($key)
            }
        }
    }

    end {
        if ($allRatingKeys.Count -eq 0) {
            throw "At least one RatingKey is required to create a collection."
        }

        if (-not $PSCmdlet.ShouldProcess($Title, 'Create collection')) {
            return
        }

        try {
            # Get the library type for the type parameter
            $libraryUri = Join-PatUri -BaseUri $effectiveUri -Endpoint "/library/sections/$resolvedLibraryId"
            $libraryInfo = Invoke-PatApi -Uri $libraryUri -Headers $headers -ErrorAction 'Stop'

            $libraryType = $libraryInfo.type
            Write-Verbose "Library type: $libraryType"

            # Map library type to collection type number
            # movie = 1, show = 2, artist = 8, photo = 13
            $typeMap = @{
                'movie'  = 1
                'show'   = 2
                'artist' = 8
                'photo'  = 13
            }
            $collectionType = if ($typeMap.ContainsKey($libraryType)) {
                $typeMap[$libraryType]
            }
            else {
                1
            }

            # Build the URI parameter for items
            # Format: /library/metadata/ratingKey1,ratingKey2,...
            $ratingKeyList = $allRatingKeys -join ','
            $itemUri = "/library/metadata/$ratingKeyList"

            # Build query string
            $queryParts = @(
                "type=$collectionType",
                "title=$([System.Uri]::EscapeDataString($Title))",
                'smart=0',
                "sectionId=$resolvedLibraryId",
                "uri=$([System.Uri]::EscapeDataString($itemUri))"
            )
            $queryString = $queryParts -join '&'

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/library/collections' -QueryString $queryString

            Write-Verbose "Creating collection '$Title' in library '$resolvedLibraryName' (ID: $resolvedLibraryId) with $($allRatingKeys.Count) items"

            $result = Invoke-PatApi -Uri $uri -Method 'POST' -Headers $headers -ErrorAction 'Stop'

            if ($PassThru -and $result) {
                $collection = if ($result.Metadata) {
                    $result.Metadata | Select-Object -First 1
                }
                else {
                    $result
                }

                [PSCustomObject]@{
                    PSTypeName   = 'PlexAutomationToolkit.Collection'
                    CollectionId = [int]$collection.ratingKey
                    Title        = $collection.title
                    LibraryId    = $resolvedLibraryId
                    LibraryName  = $resolvedLibraryName
                    ItemCount    = [int]$collection.childCount
                    Thumb        = $collection.thumb
                    AddedAt      = if ($collection.addedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$collection.addedAt).LocalDateTime
                    } else { $null }
                    UpdatedAt    = if ($collection.updatedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$collection.updatedAt).LocalDateTime
                    } else { $null }
                    ServerUri    = $effectiveUri
                }
            }
        }
        catch {
            throw "Failed to create collection '$Title': $($_.Exception.Message)"
        }
    }
}
