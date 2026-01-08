function Get-PatCollection {
    <#
    .SYNOPSIS
        Retrieves collections from a Plex server library.

    .DESCRIPTION
        Gets a list of collections from a Plex library. Can retrieve all collections
        across all libraries, filter by library, or get a specific collection by ID or name.
        Optionally include the items within each collection.

    .PARAMETER CollectionId
        The unique identifier of a specific collection to retrieve.

    .PARAMETER CollectionName
        The name of a specific collection to retrieve. Supports tab completion.
        Requires LibraryName or LibraryId to be specified.

    .PARAMETER LibraryName
        The name of the library to retrieve collections from. Supports tab completion.
        This is the preferred way to specify a library.

    .PARAMETER LibraryId
        The library section ID to retrieve collections from.
        Use Get-PatLibrary to find library IDs.

    .PARAMETER IncludeItems
        When specified, also retrieves the items within each collection.
        Items are returned in a nested 'Items' property on each collection object.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests will fail.

    .EXAMPLE
        Get-PatCollection

        Retrieves all collections from all libraries on the default server.

    .EXAMPLE
        Get-PatCollection -ServerName 'Home' -LibraryName 'Movies'

        Retrieves all collections from the 'Movies' library on the 'Home' server.

    .EXAMPLE
        Get-PatCollection -LibraryName 'Movies'

        Retrieves all collections from the 'Movies' library.

    .EXAMPLE
        Get-PatCollection -CollectionId 12345

        Retrieves the collection with the specified ID.

    .EXAMPLE
        Get-PatCollection -CollectionName 'Marvel Movies' -LibraryName 'Movies'

        Retrieves the collection named 'Marvel Movies' from the Movies library.

    .EXAMPLE
        Get-PatCollection -LibraryName 'Movies' -IncludeItems

        Retrieves all collections from Movies library with their items included.

    .EXAMPLE
        Get-PatCollection -CollectionName 'Horror' -LibraryName 'Movies' -IncludeItems |
            Select-Object -ExpandProperty Items

        Retrieves only the items from the 'Horror' collection.

    .OUTPUTS
        PlexAutomationToolkit.Collection

        Objects with properties:
        - CollectionId: Unique collection identifier (ratingKey)
        - Title: Name of the collection
        - LibraryId: The library section ID this collection belongs to
        - LibraryName: The name of the library this collection belongs to
        - ItemCount: Number of items in the collection
        - AddedAt: When the collection was created
        - UpdatedAt: When the collection was last modified
        - Thumb: URI of the collection thumbnail
        - ServerUri: The Plex server URI
        - Items: (Only with -IncludeItems) Array of collection items
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
        [ValidateNotNullOrEmpty()]
        [string]
        $CollectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LibraryName,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByNameWithLibraryId')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $LibraryId,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeItems,

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
        $Token
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

        # Cache library info for name resolution
        $script:libraryCache = $null
    }

    process {
        try {
            # Handle getting a specific collection by ID
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $endpoint = "/library/collections/$CollectionId"
                Write-Verbose "Retrieving collection $CollectionId from $effectiveUri"

                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
                $apiResult = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

                if (-not $apiResult -or -not $apiResult.Metadata) {
                    Write-Verbose "No collection found with ID $CollectionId"
                    return
                }

                # Extract collection from Metadata array
                $result = $apiResult.Metadata | Select-Object -First 1

                # Get library name for output
                $libName = $null
                $libId = [int]$apiResult.librarySectionID
                if (-not $script:libraryCache) {
                    $libraryParameters = @{ ErrorAction = 'SilentlyContinue' }
                    if ($script:serverContext.WasExplicitUri) {
                        $libraryParameters['ServerUri'] = $effectiveUri
                        if ($script:serverContext.Token) { $libraryParameters['Token'] = $script:serverContext.Token }
                    }
                    $script:libraryCache = Get-PatLibrary @libraryParameters
                }
                if ($script:libraryCache -and $script:libraryCache.Directory) {
                    $lib = $script:libraryCache.Directory | Where-Object { [int]$_.key -eq $libId }
                    if ($lib) { $libName = $lib.title }
                }

                $collectionObj = [PSCustomObject]@{
                    PSTypeName   = 'PlexAutomationToolkit.Collection'
                    CollectionId = [int]$result.ratingKey
                    Title        = $result.title
                    LibraryId    = $libId
                    LibraryName  = $libName
                    ItemCount    = [int]$result.childCount
                    Thumb        = $result.thumb
                    AddedAt      = if ($result.addedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$result.addedAt).LocalDateTime
                    } else { $null }
                    UpdatedAt    = if ($result.updatedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$result.updatedAt).LocalDateTime
                    } else { $null }
                    ServerUri    = $effectiveUri
                }

                if ($IncludeItems) {
                    $itemsEndpoint = "/library/collections/$($result.ratingKey)/children"
                    $itemsUri = Join-PatUri -BaseUri $effectiveUri -Endpoint $itemsEndpoint

                    try {
                        $itemsResult = Invoke-PatApi -Uri $itemsUri -Headers $headers -ErrorAction 'Stop'

                        $items = @()
                        if ($itemsResult -and $itemsResult.Metadata) {
                            $items = foreach ($item in $itemsResult.Metadata) {
                                [PSCustomObject]@{
                                    PSTypeName   = 'PlexAutomationToolkit.CollectionItem'
                                    RatingKey    = [int]$item.ratingKey
                                    Title        = $item.title
                                    Type         = $item.type
                                    Year         = if ($item.year) { [int]$item.year } else { $null }
                                    Thumb        = $item.thumb
                                    AddedAt      = if ($item.addedAt) {
                                        [DateTimeOffset]::FromUnixTimeSeconds([long]$item.addedAt).LocalDateTime
                                    } else { $null }
                                    CollectionId = [int]$result.ratingKey
                                    ServerUri    = $effectiveUri
                                }
                            }
                        }

                        Add-Member -InputObject $collectionObj -MemberType NoteProperty -Name 'Items' -Value $items
                    }
                    catch {
                        Write-Warning "Failed to retrieve items for collection '$($result.title)': $($_.Exception.Message)"
                        Add-Member -InputObject $collectionObj -MemberType NoteProperty -Name 'Items' -Value @()
                    }
                }

                return $collectionObj
            }

            # Resolve LibraryName to LibraryId if needed
            $targetLibraryIds = @()
            $libraryLookup = @{}

            if ($LibraryName -or $LibraryId) {
                if (-not $script:libraryCache) {
                    $libraryParameters = @{ ErrorAction = 'Stop' }
                    if ($script:serverContext.WasExplicitUri) {
                        $libraryParameters['ServerUri'] = $effectiveUri
                        if ($script:serverContext.Token) { $libraryParameters['Token'] = $script:serverContext.Token }
                    }
                    $script:libraryCache = Get-PatLibrary @libraryParameters
                }

                if ($LibraryName) {
                    $matchedLib = $script:libraryCache.Directory | Where-Object { $_.title -eq $LibraryName }
                    if (-not $matchedLib) {
                        throw "No library found with name '$LibraryName'"
                    }
                    $targetLibraryIds = @([int]$matchedLib.key)
                    $libraryLookup[[int]$matchedLib.key] = $matchedLib.title
                }
                else {
                    $targetLibraryIds = @($LibraryId)
                    $matchedLib = $script:libraryCache.Directory | Where-Object { [int]$_.key -eq $LibraryId }
                    if ($matchedLib) {
                        $libraryLookup[$LibraryId] = $matchedLib.title
                    }
                }
            }
            else {
                # No library specified - get all libraries
                if (-not $script:libraryCache) {
                    $libraryParameters = @{ ErrorAction = 'Stop' }
                    if ($script:serverContext.WasExplicitUri) {
                        $libraryParameters['ServerUri'] = $effectiveUri
                        if ($script:serverContext.Token) { $libraryParameters['Token'] = $script:serverContext.Token }
                    }
                    $script:libraryCache = Get-PatLibrary @libraryParameters
                }

                if ($script:libraryCache -and $script:libraryCache.Directory) {
                    foreach ($lib in $script:libraryCache.Directory) {
                        $targetLibraryIds += [int]$lib.key
                        $libraryLookup[[int]$lib.key] = $lib.title
                    }
                }

                if ($targetLibraryIds.Count -eq 0) {
                    Write-Verbose "No libraries found on server"
                    return
                }

                Write-Verbose "Retrieving collections from all $($targetLibraryIds.Count) libraries"
            }

            # Get collections from each target library
            foreach ($libId in $targetLibraryIds) {
                $libName = $libraryLookup[$libId]
                $endpoint = "/library/sections/$libId/collections"
                Write-Verbose "Retrieving collections from library '$libName' (ID: $libId)"

                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
                $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'SilentlyContinue'

                if (-not $result -or -not $result.Metadata) {
                    Write-Verbose "No collections found in library '$libName'"
                    continue
                }

                $collectionData = $result.Metadata

                # Filter by name if specified
                if ($CollectionName) {
                    $collectionData = $collectionData | Where-Object { $_.title -eq $CollectionName }
                    if (-not $collectionData) {
                        throw "No collection found with name '$CollectionName' in library '$libName'"
                    }
                }

                foreach ($collection in $collectionData) {
                    $collectionObj = [PSCustomObject]@{
                        PSTypeName   = 'PlexAutomationToolkit.Collection'
                        CollectionId = [int]$collection.ratingKey
                        Title        = $collection.title
                        LibraryId    = $libId
                        LibraryName  = $libName
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

                    if ($IncludeItems) {
                        $itemsEndpoint = "/library/collections/$($collection.ratingKey)/children"
                        $itemsUri = Join-PatUri -BaseUri $effectiveUri -Endpoint $itemsEndpoint

                        try {
                            $itemsResult = Invoke-PatApi -Uri $itemsUri -Headers $headers -ErrorAction 'Stop'

                            $items = @()
                            if ($itemsResult -and $itemsResult.Metadata) {
                                $items = foreach ($item in $itemsResult.Metadata) {
                                    [PSCustomObject]@{
                                        PSTypeName   = 'PlexAutomationToolkit.CollectionItem'
                                        RatingKey    = [int]$item.ratingKey
                                        Title        = $item.title
                                        Type         = $item.type
                                        Year         = if ($item.year) { [int]$item.year } else { $null }
                                        Thumb        = $item.thumb
                                        AddedAt      = if ($item.addedAt) {
                                            [DateTimeOffset]::FromUnixTimeSeconds([long]$item.addedAt).LocalDateTime
                                        } else { $null }
                                        CollectionId = [int]$collection.ratingKey
                                        ServerUri    = $effectiveUri
                                    }
                                }
                            }

                            Add-Member -InputObject $collectionObj -MemberType NoteProperty -Name 'Items' -Value $items
                        }
                        catch {
                            Write-Warning "Failed to retrieve items for collection '$($collection.title)': $($_.Exception.Message)"
                            Add-Member -InputObject $collectionObj -MemberType NoteProperty -Name 'Items' -Value @()
                        }
                    }

                    $collectionObj
                }
            }
        }
        catch {
            throw "Failed to retrieve collections: $($_.Exception.Message)"
        }
    }
}
