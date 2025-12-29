function Remove-PatCollectionItem {
    <#
    .SYNOPSIS
        Removes an item from a collection on a Plex server.

    .DESCRIPTION
        Removes one or more media items from a collection. Items are identified by their
        rating keys. Use Get-PatCollection -IncludeItems to retrieve the RatingKey values
        of items in a collection.

    .PARAMETER CollectionId
        The unique identifier of the collection containing the item.

    .PARAMETER CollectionName
        The name of the collection to remove items from. Supports tab completion.
        Requires LibraryName or LibraryId to be specified.

    .PARAMETER LibraryName
        The name of the library containing the collection. Supports tab completion.
        Required when using -CollectionName. This is the preferred way to specify a library.

    .PARAMETER LibraryId
        The library section ID containing the collection. Required when using -CollectionName.
        Use Get-PatLibrary to find library IDs.

    .PARAMETER RatingKey
        One or more rating keys of the items to remove from the collection.
        Obtain these values from Get-PatCollection -IncludeItems.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the updated collection object.

    .EXAMPLE
        Remove-PatCollectionItem -CollectionId 12345 -RatingKey 67890

        Removes the item with rating key 67890 from collection 12345.

    .EXAMPLE
        Remove-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryName 'Movies' -RatingKey 111, 222

        Removes two items from the 'Marvel Movies' collection in the Movies library.

    .EXAMPLE
        Get-PatCollection -CollectionName 'Horror' -LibraryName 'Movies' -IncludeItems |
            Select-Object -ExpandProperty Items |
            Where-Object { $_.Title -like '*Remake*' } |
            Remove-PatCollectionItem -CollectionId 12345

        Removes items matching 'Remake' from the collection by piping item objects.

    .EXAMPLE
        $collection = Get-PatCollection -CollectionId 12345 -IncludeItems
        $collection.Items | Select-Object -First 1 | Remove-PatCollectionItem -PassThru

        Removes the first item from a collection and returns the updated collection.

    .EXAMPLE
        Remove-PatCollectionItem -CollectionId 12345 -RatingKey 67890 -WhatIf

        Shows what would be removed without actually removing it.

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
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
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
            Write-Verbose "No rating keys provided, nothing to remove"
            return
        }

        $collectionDesc = if ($collectionInfo) {
            "'$($collectionInfo.Title)'"
        }
        else {
            "Collection $resolvedId"
        }
        $target = "$($allRatingKeys.Count) item(s) from $collectionDesc"

        if (-not $PSCmdlet.ShouldProcess($target, 'Remove from collection')) {
            return
        }

        try {
            # Remove each item individually (API requires separate DELETE calls per item)
            foreach ($key in $allRatingKeys) {
                $endpoint = "/library/collections/$resolvedId/items/$key"
                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

                Write-Verbose "Removing item $key from collection $resolvedId"

                $null = Invoke-PatApi -Uri $uri -Method 'DELETE' -Headers $headers -ErrorAction 'Stop'
            }

            if ($PassThru) {
                # Only pass ServerUri if explicitly specified
                $getParams = @{ CollectionId = $resolvedId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                Get-PatCollection @getParams
            }
        }
        catch {
            throw "Failed to remove items from collection: $($_.Exception.Message)"
        }
    }
}
