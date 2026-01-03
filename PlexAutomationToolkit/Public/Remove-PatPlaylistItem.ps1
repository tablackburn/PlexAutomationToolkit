function Remove-PatPlaylistItem {
    <#
    .SYNOPSIS
        Removes an item from a playlist on a Plex server.

    .DESCRIPTION
        Removes a single item from a playlist. The item is identified by its
        playlist-specific item ID (playlistItemId), not the media's rating key.
        Use Get-PatPlaylist -IncludeItems to retrieve the PlaylistItemId values.

    .PARAMETER PlaylistId
        The unique identifier of the playlist containing the item.

    .PARAMETER PlaylistItemId
        The playlist-specific item ID of the item to remove. This is different
        from the media's rating key - it identifies the item's position in this
        specific playlist. Obtain this value from Get-PatPlaylist -IncludeItems.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the updated playlist object.

    .EXAMPLE
        Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 67890

        Removes the item with playlist item ID 67890 from playlist 12345.

    .EXAMPLE
        Get-PatPlaylist -PlaylistName 'My List' -IncludeItems |
            Select-Object -ExpandProperty Items |
            Where-Object { $_.Title -eq 'Unwanted Movie' } |
            Remove-PatPlaylistItem

        Removes a specific movie from the playlist by title.

    .EXAMPLE
        $playlist = Get-PatPlaylist -PlaylistName 'Watch Later' -IncludeItems
        $playlist.Items | Select-Object -First 1 | Remove-PatPlaylistItem -PassThru

        Removes the first item from a playlist and returns the updated playlist.

    .EXAMPLE
        Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 67890 -WhatIf

        Shows what would be removed without actually removing it.

    .OUTPUTS
        PlexAutomationToolkit.Playlist (when -PassThru is specified)

        Returns the updated playlist object showing the new item count.

    .NOTES
        The PlaylistItemId is specific to the playlist and represents the item's
        position/association within that playlist. It is not the same as the media's
        rating key (ratingKey). Always use Get-PatPlaylist -IncludeItems to get the
        correct PlaylistItemId values.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistItemId,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        # Cache for server context (will be set per-item in process block if ServerUri varies)
        $script:cachedServerContext = $null
        $script:cachedServerUri = $null
        $script:cachedToken = $null
    }

    process {
        try {
            # Resolve server context (cache if ServerUri and Token are the same)
            if ($ServerUri -ne $script:cachedServerUri -or $Token -ne $script:cachedToken) {
                try {
                    $script:cachedServerContext = Resolve-PatServerContext -ServerUri $ServerUri -Token $Token
                    $script:cachedServerUri = $ServerUri
                    $script:cachedToken = $Token
                }
                catch {
                    throw "Failed to resolve server: $($_.Exception.Message)"
                }
            }

            $effectiveUri = $script:cachedServerContext.Uri
            $headers = $script:cachedServerContext.Headers

            # Get item info for ShouldProcess message
            $itemTitle = "Item $PlaylistItemId"
            try {
                # Only pass ServerUri if explicitly specified
                $getParameters = @{ PlaylistId = $PlaylistId; IncludeItems = $true; ErrorAction = 'SilentlyContinue' }
                if ($script:cachedServerContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                $playlist = Get-PatPlaylist @getParameters
                if ($playlist -and $playlist.Items) {
                    $item = $playlist.Items | Where-Object { $_.PlaylistItemId -eq $PlaylistItemId }
                    if ($item) {
                        $itemTitle = "'$($item.Title)'"
                    }
                }
            }
            catch {
                Write-Verbose "Could not retrieve item info"
            }

            $target = "$itemTitle from playlist $PlaylistId"

            if ($PSCmdlet.ShouldProcess($target, 'Remove from playlist')) {
                $endpoint = "/playlists/$PlaylistId/items/$PlaylistItemId"
                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

                Write-Verbose "Removing item $PlaylistItemId from playlist $PlaylistId"

                $null = Invoke-PatApi -Uri $uri -Method 'DELETE' -Headers $headers -ErrorAction 'Stop'

                if ($PassThru) {
                    # Only pass ServerUri if explicitly specified
                    $getParameters = @{ PlaylistId = $PlaylistId; ErrorAction = 'Stop' }
                    if ($script:cachedServerContext.WasExplicitUri) { $getParameters['ServerUri'] = $effectiveUri }
                    Get-PatPlaylist @getParameters
                }
            }
        }
        catch {
            throw "Failed to remove item from playlist: $($_.Exception.Message)"
        }
    }
}
