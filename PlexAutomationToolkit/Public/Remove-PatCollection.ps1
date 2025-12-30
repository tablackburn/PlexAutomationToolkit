function Remove-PatCollection {
    <#
    .SYNOPSIS
        Removes a collection from a Plex library.

    .DESCRIPTION
        Deletes a collection from the Plex library. Can identify the collection by ID or name.
        This action is irreversible - the collection and its item associations will be
        permanently deleted. The media items themselves are not affected.

    .PARAMETER CollectionId
        The unique identifier of the collection to remove.

    .PARAMETER CollectionName
        The name of the collection to remove. Supports tab completion.
        Requires LibraryName or LibraryId to be specified.

    .PARAMETER LibraryName
        The name of the library containing the collection. Supports tab completion.
        Required when using -CollectionName. This is the preferred way to specify a library.

    .PARAMETER LibraryId
        The library section ID containing the collection. Required when using -CollectionName.
        Use Get-PatLibrary to find library IDs.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the collection object that was removed.

    .EXAMPLE
        Remove-PatCollection -CollectionId 12345

        Removes the collection with ID 12345 after confirmation.

    .EXAMPLE
        Remove-PatCollection -CollectionName 'Old Collection' -LibraryName 'Movies' -Confirm:$false

        Removes the collection named 'Old Collection' from Movies library without confirmation.

    .EXAMPLE
        Get-PatCollection -LibraryName 'Movies' | Where-Object Title -like 'Temp*' | Remove-PatCollection

        Removes collections starting with 'Temp' from Movies library via pipeline.

    .EXAMPLE
        Remove-PatCollection -CollectionName 'Test Collection' -LibraryName 'Movies' -WhatIf

        Shows what would be removed without actually removing it.

    .EXAMPLE
        Remove-PatCollection -CollectionId 12345 -PassThru

        Removes the collection and returns the removed collection object for logging.

    .OUTPUTS
        PlexAutomationToolkit.Collection (when -PassThru is specified)

        Returns the removed collection object for auditing purposes.
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
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
            }
            if ($fakeBoundParameters.ContainsKey('LibraryName')) {
                $getParameters['LibraryName'] = $fakeBoundParameters['LibraryName']
            }
            elseif ($fakeBoundParameters.ContainsKey('LibraryId')) {
                $getParameters['LibraryId'] = $fakeBoundParameters['LibraryId']
            }
            else {
                return
            }

            $collections = Get-PatCollection @getParameters

            foreach ($collection in $collections) {
                if ($collection.Title -ilike "$($completerInput.StrippedWord)*") {
                    New-PatCompletionResult -Value $collection.Title -QuoteChar $completerInput.QuoteChar
                }
            }
        })]
        [string]
        $CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
            }

            $libraries = Get-PatLibrary @getParameters

            foreach ($lib in $libraries.Directory) {
                if ($lib.title -ilike "$($completerInput.StrippedWord)*") {
                    New-PatCompletionResult -Value $lib.title -QuoteChar $completerInput.QuoteChar
                }
            }
        })]
        [string]
        $LibraryName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $LibraryId,

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
    }

    process {
        try {
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

            $target = if ($collectionInfo) {
                "'$($collectionInfo.Title)' (ID: $resolvedId, $($collectionInfo.ItemCount) items)"
            }
            else {
                "Collection ID $resolvedId"
            }

            if ($PSCmdlet.ShouldProcess($target, 'Delete collection')) {
                $endpoint = "/library/collections/$resolvedId"
                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

                Write-Verbose "Deleting collection $resolvedId from $effectiveUri"

                $null = Invoke-PatApi -Uri $uri -Method 'DELETE' -Headers $headers -ErrorAction 'Stop'

                if ($PassThru -and $collectionInfo) {
                    $collectionInfo
                }
            }
        }
        catch {
            throw "Failed to remove collection: $($_.Exception.Message)"
        }
    }
}
