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

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

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
        Remove-PatCollectionItem -CollectionName 'Marvel' -LibraryName 'Movies' -RatingKey 67890 -ServerName 'Home'

        Removes an item from a collection on the stored server named 'Home'.

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
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
        [ValidateNotNullOrEmpty()]
        [string]
        $CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [ValidateNotNullOrEmpty()]
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
        [string]
        $ServerName,

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
            $script:serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers

        $resolvedId = $CollectionId
        $collectionInformation = $null

        if ($PSCmdlet.ParameterSetName -like 'ByName*') {
            # Only pass ServerUri if explicitly specified, otherwise let Get-PatCollection use default server with auth
            $getParameters = @{
                CollectionName = $CollectionName
                ErrorAction    = 'Stop'
            }
            if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
            if ($LibraryName) {
                $getParameters['LibraryName'] = $LibraryName
            }
            else {
                $getParameters['LibraryId'] = $LibraryId
            }

            $collection = Get-PatCollection @getParameters
            if (-not $collection) {
                $libDesc = if ($LibraryName) { "library '$LibraryName'" } else { "library $LibraryId" }
                throw "No collection found with name '$CollectionName' in $libDesc"
            }
            $resolvedId = $collection.CollectionId
            $collectionInformation = $collection
        }
        else {
            try {
                # Only pass ServerUri if explicitly specified, otherwise let Get-PatCollection use default server with auth
                $getParameters = @{ CollectionId = $CollectionId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                $collectionInformation = Get-PatCollection @getParameters
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

        $collectionDesc = if ($collectionInformation) {
            "'$($collectionInformation.Title)'"
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
                $getParameters = @{ CollectionId = $resolvedId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                Get-PatCollection @getParameters
            }
        }
        catch {
            throw "Failed to remove items from collection: $($_.Exception.Message)"
        }
    }
}
