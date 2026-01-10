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
        If specified, returns the updated playlist object.

    .EXAMPLE
        Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890

        Adds the media item with rating key 67890 to playlist 12345.

    .EXAMPLE
        Add-PatPlaylistItem -PlaylistName 'My Playlist' -RatingKey 67890 -ServerName 'Home'

        Adds an item to a playlist on the stored server named 'Home'.

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

        # Get machine identifier for URI construction
        $machineIdentifier = $null
        try {
            $serverInformationUri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'
            $serverInformation = Invoke-PatApi -Uri $serverInformationUri -Headers $headers -ErrorAction 'Stop'
            $machineIdentifier = $serverInformation.machineIdentifier
            Write-Verbose "Server machine identifier: $machineIdentifier"
        }
        catch {
            throw "Failed to retrieve server machine identifier: $($_.Exception.Message)"
        }

        # Resolve playlist ID if using name
        $resolvedId = $PlaylistId
        $playlistInformation = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            # Only pass ServerUri if explicitly specified
            $getParameters = @{ PlaylistName = $PlaylistName; ErrorAction = 'Stop' }
            if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
            $playlist = Get-PatPlaylist @getParameters
            if (-not $playlist) {
                throw "No playlist found with name '$PlaylistName'"
            }
            $resolvedId = $playlist.PlaylistId
            $playlistInformation = $playlist
        }
        else {
            try {
                # Only pass ServerUri if explicitly specified
                $getParameters = @{ PlaylistId = $PlaylistId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                $playlistInformation = Get-PatPlaylist @getParameters
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
        $playlistDesc = if ($playlistInformation) {
            "'$($playlistInformation.Title)'"
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
                $getParameters = @{ PlaylistId = $resolvedId; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                Get-PatPlaylist @getParameters
            }
        }
        catch {
            throw "Failed to add items to playlist: $($_.Exception.Message)"
        }
    }
}
