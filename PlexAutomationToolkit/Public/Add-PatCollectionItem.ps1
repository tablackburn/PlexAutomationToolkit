function Add-PatCollectionItem {
    <#
    .SYNOPSIS
        Adds items to an existing collection on a Plex server.

    .DESCRIPTION
        Adds one or more media items to an existing collection. Items are specified by
        their rating keys (unique identifiers in the Plex library).

    .PARAMETER CollectionId
        The unique identifier of the collection to add items to.

    .PARAMETER CollectionName
        The name of the collection to add items to. Supports tab completion.
        Requires LibraryName or LibraryId to be specified.

    .PARAMETER LibraryName
        The name of the library containing the collection. Supports tab completion.
        Required when using -CollectionName. This is the preferred way to specify a library.

    .PARAMETER LibraryId
        The library section ID containing the collection. Required when using -CollectionName.
        Use Get-PatLibrary to find library IDs.

    .PARAMETER RatingKey
        One or more media item rating keys to add to the collection.
        Rating keys can be obtained from library browsing commands like Get-PatLibraryItem.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the updated collection object.

    .EXAMPLE
        Add-PatCollectionItem -CollectionId 12345 -RatingKey 67890

        Adds the media item with rating key 67890 to collection 12345.

    .EXAMPLE
        Add-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryName 'Movies' -RatingKey 111, 222, 333

        Adds three items to the collection named 'Marvel Movies' in the Movies library.

    .EXAMPLE
        Get-PatLibraryItem -LibraryName 'Movies' -Title '*Avengers*' |
            ForEach-Object { $_.ratingKey } |
            Add-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryName 'Movies'

        Adds all items matching 'Avengers' from the Movies library to the 'Marvel Movies' collection.

    .EXAMPLE
        Add-PatCollectionItem -CollectionId 12345 -RatingKey 67890 -PassThru

        Adds an item and returns the updated collection object.

    .OUTPUTS
        PlexAutomationToolkit.Collection (when -PassThru is specified)

        Returns the updated collection object showing the new item count.
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
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
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
            if ($fakeBoundParameters.ContainsKey('LibraryName')) {
                $getParams['LibraryName'] = $fakeBoundParameters['LibraryName']
            }
            elseif ($fakeBoundParameters.ContainsKey('LibraryId')) {
                $getParams['LibraryId'] = $fakeBoundParameters['LibraryId']
            }
            else {
                return
            }

            $collections = Get-PatCollection @getParams

            foreach ($collection in $collections) {
                if ($collection.Title -ilike "$strippedWord*") {
                    $title = $collection.Title
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
        $CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
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

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
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
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers

        # Get machine identifier for URI construction
        try {
            $serverInfoUri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'
            $serverInfo = Invoke-PatApi -Uri $serverInfoUri -Headers $headers -ErrorAction 'Stop'
            $machineIdentifier = $serverInfo.machineIdentifier
            Write-Verbose "Server machine identifier: $machineIdentifier"
        }
        catch {
            throw "Failed to retrieve server machine identifier: $($_.Exception.Message)"
        }

        $resolvedId = $CollectionId
        $collectionInfo = $null

        if ($PSCmdlet.ParameterSetName -like 'ByName*') {
            # Only pass ServerUri if explicitly specified, otherwise let Get-PatCollection use default server with auth
            $getParams = @{
                CollectionName = $CollectionName
                ErrorAction    = 'Stop'
            }
            if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
            if ($LibraryName) {
                $getParams['LibraryName'] = $LibraryName
            }
            else {
                $getParams['LibraryId'] = $LibraryId
            }

            $collection = Get-PatCollection @getParams
            if (-not $collection) {
                $libDesc = if ($LibraryName) { "library '$LibraryName'" } else { "library $LibraryId" }
                throw "No collection found with name '$CollectionName' in $libDesc"
            }
            $resolvedId = $collection.CollectionId
            $collectionInfo = $collection
        }
        else {
            try {
                # Only pass ServerUri if explicitly specified, otherwise let Get-PatCollection use default server with auth
                $getParams = @{ CollectionId = $CollectionId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                $collectionInfo = Get-PatCollection @getParams
            }
            catch {
                Write-Verbose "Could not retrieve collection info for ID $CollectionId"
            }
        }

        $allRatingKeys = [System.Collections.ArrayList]::new()
    }

    process {
        foreach ($key in $RatingKey) {
            $null = $allRatingKeys.Add($key)
        }
    }

    end {
        if ($allRatingKeys.Count -eq 0) {
            Write-Verbose "No rating keys provided, nothing to add"
            return
        }

        $collectionDesc = if ($collectionInfo) {
            "'$($collectionInfo.Title)'"
        }
        else {
            "Collection $resolvedId"
        }
        $target = "$($allRatingKeys.Count) item(s) to $collectionDesc"

        if (-not $PSCmdlet.ShouldProcess($target, 'Add to collection')) {
            return
        }

        try {
            # Add each item individually (collections require separate API calls per item)
            # Format: server://machineIdentifier/com.plexapp.plugins.library/library/metadata/ratingKey
            $endpoint = "/library/collections/$resolvedId/items"

            Write-Verbose "Adding $($allRatingKeys.Count) item(s) to collection $resolvedId"

            foreach ($key in $allRatingKeys) {
                $itemUri = "server://$machineIdentifier/com.plexapp.plugins.library/library/metadata/$key"
                $queryString = "uri=$([System.Uri]::EscapeDataString($itemUri))"
                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryString

                Write-Verbose "Adding item $key to collection $resolvedId"
                $null = Invoke-PatApi -Uri $uri -Method 'PUT' -Headers $headers -ErrorAction 'Stop'
            }

            if ($PassThru) {
                # Only pass ServerUri if explicitly specified
                $getParams = @{ CollectionId = $resolvedId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                Get-PatCollection @getParams
            }
        }
        catch {
            throw "Failed to add items to collection: $($_.Exception.Message)"
        }
    }
}
