function Get-PatPlaylist {
    <#
    .SYNOPSIS
        Retrieves playlists from a Plex server.

    .DESCRIPTION
        Gets a list of playlists from the Plex server. Can retrieve all playlists,
        filter by ID or name, and optionally include the items within each playlist.
        Only returns regular (non-smart) playlists by default.

    .PARAMETER PlaylistId
        The unique identifier of a specific playlist to retrieve.

    .PARAMETER PlaylistName
        The name of a specific playlist to retrieve. Supports tab completion.

    .PARAMETER IncludeItems
        When specified, also retrieves the items within each playlist.
        Items are returned in a nested 'Items' property on each playlist object.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests will fail.

    .EXAMPLE
        Get-PatPlaylist

        Retrieves all playlists from the default Plex server.

    .EXAMPLE
        Get-PatPlaylist -PlaylistId 12345

        Retrieves the playlist with the specified ID.

    .EXAMPLE
        Get-PatPlaylist -PlaylistName 'My Favorites'

        Retrieves the playlist named 'My Favorites'.

    .EXAMPLE
        Get-PatPlaylist -IncludeItems

        Retrieves all playlists with their items included.

    .EXAMPLE
        Get-PatPlaylist -PlaylistName 'Watch Later' -IncludeItems | Select-Object -ExpandProperty Items

        Retrieves only the items from the 'Watch Later' playlist.

    .OUTPUTS
        PlexAutomationToolkit.Playlist

        Objects with properties:
        - PlaylistId: Unique playlist identifier (ratingKey)
        - Title: Name of the playlist
        - Type: Playlist type (video, audio, photo)
        - ItemCount: Number of items in the playlist
        - Duration: Total duration in milliseconds
        - Smart: Whether this is a smart playlist
        - Composite: URI of the playlist composite image
        - ServerUri: The Plex server URI
        - Items: (Only with -IncludeItems) Array of playlist items
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
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
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

            $playlists = Get-PatPlaylist @getParams

            foreach ($playlist in $playlists) {
                if ($playlist.Title -ilike "$strippedWord*") {
                    $title = $playlist.Title
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
        $PlaylistName,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeItems,

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
            # Determine endpoint based on parameter set
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $endpoint = "/playlists/$PlaylistId"
                Write-Verbose "Retrieving playlist $PlaylistId from $effectiveUri"
            }
            else {
                $endpoint = '/playlists'
                Write-Verbose "Retrieving all playlists from $effectiveUri"
            }

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Handle empty response
            if (-not $result) {
                Write-Verbose "No playlists found"
                return
            }

            # Extract playlist data from Metadata array (both single and multiple queries return this structure)
            $playlistData = if ($result.Metadata) {
                $result.Metadata
            }
            else {
                @()
            }

            # Filter by name if specified
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                $playlistData = $playlistData | Where-Object { $_.title -eq $PlaylistName }
                if (-not $playlistData) {
                    throw "No playlist found with name '$PlaylistName'"
                }
            }

            # Filter out smart playlists (we only support dumb playlists)
            $playlistData = $playlistData | Where-Object { $_.smart -ne '1' -and $_.smart -ne 1 }

            # Transform each playlist into a structured object
            foreach ($playlist in $playlistData) {
                $playlistObj = [PSCustomObject]@{
                    PSTypeName  = 'PlexAutomationToolkit.Playlist'
                    PlaylistId  = [int]$playlist.ratingKey
                    Title       = $playlist.title
                    Type        = $playlist.playlistType
                    ItemCount   = [int]$playlist.leafCount
                    Duration    = [long]$playlist.duration
                    Smart       = ($playlist.smart -eq '1' -or $playlist.smart -eq 1)
                    Composite   = $playlist.composite
                    AddedAt     = if ($playlist.addedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$playlist.addedAt).LocalDateTime
                    } else { $null }
                    UpdatedAt   = if ($playlist.updatedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$playlist.updatedAt).LocalDateTime
                    } else { $null }
                    ServerUri   = $effectiveUri
                }

                # Fetch items if requested
                if ($IncludeItems) {
                    $itemsEndpoint = "/playlists/$($playlist.ratingKey)/items"
                    $itemsUri = Join-PatUri -BaseUri $effectiveUri -Endpoint $itemsEndpoint

                    try {
                        $itemsResult = Invoke-PatApi -Uri $itemsUri -Headers $headers -ErrorAction 'Stop'

                        $items = @()
                        if ($itemsResult -and $itemsResult.Metadata) {
                            $items = foreach ($item in $itemsResult.Metadata) {
                                [PSCustomObject]@{
                                    PSTypeName      = 'PlexAutomationToolkit.PlaylistItem'
                                    PlaylistItemId  = [int]$item.playlistItemID
                                    RatingKey       = [int]$item.ratingKey
                                    Title           = $item.title
                                    Type            = $item.type
                                    Duration        = [long]$item.duration
                                    AddedAt         = if ($item.addedAt) {
                                        [DateTimeOffset]::FromUnixTimeSeconds([long]$item.addedAt).LocalDateTime
                                    } else { $null }
                                    PlaylistId      = [int]$playlist.ratingKey
                                    ServerUri       = $effectiveUri
                                }
                            }
                        }

                        Add-Member -InputObject $playlistObj -MemberType NoteProperty -Name 'Items' -Value $items
                    }
                    catch {
                        Write-Warning "Failed to retrieve items for playlist '$($playlist.title)': $($_.Exception.Message)"
                        Add-Member -InputObject $playlistObj -MemberType NoteProperty -Name 'Items' -Value @()
                    }
                }

                $playlistObj
            }
        }
        catch {
            throw "Failed to retrieve playlists: $($_.Exception.Message)"
        }
    }
}
