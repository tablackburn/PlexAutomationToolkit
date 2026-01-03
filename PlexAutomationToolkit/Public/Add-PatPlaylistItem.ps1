function Add-PatPlaylistItem {
    <#
    .SYNOPSIS
        Adds items to an existing playlist on a Plex server.

    .DESCRIPTION
        Adds one or more media items to an existing playlist. Items are specified by
        their rating keys (unique identifiers in the Plex library). Items are added
        to the end of the playlist.

    .PARAMETER PlaylistId
        The unique identifier of the playlist to add items to.

    .PARAMETER PlaylistName
        The name of the playlist to add items to. Supports tab completion.

    .PARAMETER RatingKey
        One or more media item rating keys to add to the playlist.
        Rating keys can be obtained from library browsing commands like Get-PatLibraryItem.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the updated playlist object.

    .EXAMPLE
        Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890

        Adds the media item with rating key 67890 to playlist 12345.

    .EXAMPLE
        Add-PatPlaylistItem -PlaylistName 'My Favorites' -RatingKey 111, 222, 333

        Adds three items to the playlist named 'My Favorites'.

    .EXAMPLE
        Get-PatLibraryItem -SectionId 1 -Filter 'year=2024' |
            ForEach-Object { $_.ratingKey } |
            Add-PatPlaylistItem -PlaylistName 'New Releases'

        Adds all 2024 items from library section 1 to the 'New Releases' playlist.

    .EXAMPLE
        Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890 -PassThru

        Adds an item and returns the updated playlist object.

    .OUTPUTS
        PlexAutomationToolkit.Playlist (when -PassThru is specified)

        Returns the updated playlist object showing the new item count.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $PlaylistName,

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
        $machineIdentifier = $null
        try {
            $serverInfoUri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'
            $serverInfo = Invoke-PatApi -Uri $serverInfoUri -Headers $headers -ErrorAction 'Stop'
            $machineIdentifier = $serverInfo.machineIdentifier
            Write-Verbose "Server machine identifier: $machineIdentifier"
        }
        catch {
            throw "Failed to retrieve server machine identifier: $($_.Exception.Message)"
        }

        # Resolve playlist ID if using name
        $resolvedId = $PlaylistId
        $playlistInfo = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            # Only pass ServerUri if explicitly specified
            $getParams = @{ PlaylistName = $PlaylistName; ErrorAction = 'Stop' }
            if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
            $playlist = Get-PatPlaylist @getParams
            if (-not $playlist) {
                throw "No playlist found with name '$PlaylistName'"
            }
            $resolvedId = $playlist.PlaylistId
            $playlistInfo = $playlist
        }
        else {
            try {
                # Only pass ServerUri if explicitly specified
                $getParams = @{ PlaylistId = $PlaylistId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                $playlistInfo = Get-PatPlaylist @getParams
            }
            catch {
                Write-Verbose "Could not retrieve playlist info for ID $PlaylistId"
            }
        }

        # Collect all rating keys from pipeline
        $allRatingKeys = [System.Collections.ArrayList]::new()
    }

    process {
        # Collect rating keys from pipeline
        foreach ($key in $RatingKey) {
            $null = $allRatingKeys.Add($key)
        }
    }

    end {
        if ($allRatingKeys.Count -eq 0) {
            Write-Verbose "No rating keys provided, nothing to add"
            return
        }

        # Build descriptive target for confirmation
        $playlistDesc = if ($playlistInfo) {
            "'$($playlistInfo.Title)'"
        }
        else {
            "Playlist $resolvedId"
        }
        $target = "$($allRatingKeys.Count) item(s) to $playlistDesc"

        if (-not $PSCmdlet.ShouldProcess($target, 'Add to playlist')) {
            return
        }

        try {
            # Build the URI with items
            # Format: server://machineIdentifier/com.plexapp.plugins.library/library/metadata/ratingKey
            $itemUris = foreach ($key in $allRatingKeys) {
                "server://$machineIdentifier/com.plexapp.plugins.library/library/metadata/$key"
            }
            $uriParam = $itemUris -join ','

            $queryString = "uri=$([System.Uri]::EscapeDataString($uriParam))"
            $endpoint = "/playlists/$resolvedId/items"
            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString $queryString

            Write-Verbose "Adding $($allRatingKeys.Count) item(s) to playlist $resolvedId"

            $null = Invoke-PatApi -Uri $uri -Method 'PUT' -Headers $headers -ErrorAction 'Stop'

            if ($PassThru) {
                # Only pass ServerUri if explicitly specified
                $getParams = @{ PlaylistId = $resolvedId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                Get-PatPlaylist @getParams
            }
        }
        catch {
            throw "Failed to add items to playlist: $($_.Exception.Message)"
        }
    }
}
