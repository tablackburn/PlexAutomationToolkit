function Remove-PatWatchedPlaylistItem {
    <#
    .SYNOPSIS
        Removes watched items from a Plex playlist based on watch status differences.

    .DESCRIPTION
        Internal helper function that removes items from a playlist that have been
        watched on another server. Takes watch status differences (from Compare-PatWatchStatus)
        and removes matching items from the specified playlist. Shows progress during
        removal and handles errors gracefully.

    .PARAMETER WatchDiff
        Array of watch status differences from Compare-PatWatchStatus. Each object
        should have a TargetRatingKey property to match against playlist items.

    .PARAMETER PlaylistId
        The unique identifier of the playlist to remove items from.

    .PARAMETER PlaylistName
        The name of the playlist to remove items from. Used when PlaylistId is not specified.

    .PARAMETER ServerUri
        The base URI of the Plex server.

    .PARAMETER Token
        The Plex authentication token for API requests.

    .PARAMETER ServerName
        The name of a stored server to use. Alternative to ServerUri/Token.

    .OUTPUTS
        System.Int32
        Returns the count of items successfully removed from the playlist.

    .EXAMPLE
        $diffs = Compare-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WatchedOnSourceOnly
        Remove-PatWatchedPlaylistItem -WatchDiff $diffs -PlaylistName 'Travel' -ServerName 'Home'

        Removes watched items from the Travel playlist.

    .EXAMPLE
        $removed = Remove-PatWatchedPlaylistItem -WatchDiff $diffs -PlaylistId 100 -ServerUri 'http://plex:32400' -Token $token
        Write-Host "Removed $removed items"

        Removes watched items and returns the count.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PSObject[]]
        $WatchDiff,

        [Parameter(Mandatory = $false)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $false)]
        [string]
        $PlaylistName,

        [Parameter(Mandatory = $false)]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [string]
        $ServerName
    )

    process {
        # Return early if no watch differences
        if (-not $WatchDiff -or $WatchDiff.Count -eq 0) {
            Write-Verbose "No watch differences provided"
            return 0
        }

        # Build parameters for Get-PatPlaylist
        $getPlaylistParameters = @{
            IncludeItems = $true
            ErrorAction  = 'Stop'
        }

        if ($PlaylistId) {
            $getPlaylistParameters['PlaylistId'] = $PlaylistId
        }
        elseif ($PlaylistName) {
            $getPlaylistParameters['PlaylistName'] = $PlaylistName
        }
        else {
            Write-Warning "Either PlaylistId or PlaylistName must be specified"
            return 0
        }

        if ($ServerName) {
            $getPlaylistParameters['ServerName'] = $ServerName
        }
        elseif ($ServerUri) {
            $getPlaylistParameters['ServerUri'] = $ServerUri
            if ($Token) {
                $getPlaylistParameters['Token'] = $Token
            }
        }

        # Get playlist with items
        try {
            $playlist = Get-PatPlaylist @getPlaylistParameters
        }
        catch {
            Write-Warning "Failed to get playlist: $($_.Exception.Message)"
            return 0
        }

        if (-not $playlist.Items -or $playlist.Items.Count -eq 0) {
            Write-Verbose "Playlist '$($playlist.Title)' has no items"
            return 0
        }

        # Build lookup from RatingKey to PlaylistItem
        $ratingKeyToItem = @{}
        foreach ($item in $playlist.Items) {
            $ratingKeyToItem[[string]$item.RatingKey] = $item
        }

        # Find watched items that are in the playlist
        # Use TargetRatingKey which corresponds to the source (home) server's keys
        $itemsToRemove = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($diff in $WatchDiff) {
            $key = [string]$diff.TargetRatingKey
            if ($ratingKeyToItem.ContainsKey($key)) {
                $itemsToRemove.Add(@{
                    PlaylistItem = $ratingKeyToItem[$key]
                    WatchDiff    = $diff
                })
            }
        }

        if ($itemsToRemove.Count -eq 0) {
            Write-Verbose "No watched items found in playlist to remove"
            return 0
        }

        Write-Verbose "Found $($itemsToRemove.Count) watched items in playlist '$($playlist.Title)'"

        # Remove items from playlist
        $removedCount = 0
        $totalToRemove = $itemsToRemove.Count
        $currentItem = 0

        foreach ($itemToRemove in $itemsToRemove) {
            $currentItem++
            $playlistItem = $itemToRemove.PlaylistItem
            $itemDisplay = Format-PatMediaItemName -Item $playlistItem

            $percentComplete = [int](($currentItem / $totalToRemove) * 100)
            Write-Progress -Activity "Removing watched items from playlist" `
                -Status "Removing $currentItem of $totalToRemove`: $itemDisplay" `
                -PercentComplete $percentComplete `
                -Id 1

            try {
                $removeParams = @{
                    PlaylistId     = $playlist.PlaylistId
                    PlaylistItemId = $playlistItem.PlaylistItemId
                    Confirm        = $false
                    ErrorAction    = 'Stop'
                }
                if ($ServerName) {
                    $removeParams['ServerName'] = $ServerName
                }
                elseif ($ServerUri) {
                    $removeParams['ServerUri'] = $ServerUri
                    if ($Token) {
                        $removeParams['Token'] = $Token
                    }
                }
                Remove-PatPlaylistItem @removeParams

                $removedCount++
                Write-Verbose "Removed '$itemDisplay' from playlist"
            }
            catch {
                Write-Warning "Failed to remove '$itemDisplay': $($_.Exception.Message)"
            }
        }

        Write-Progress -Activity "Removing watched items from playlist" -Completed -Id 1
        Write-Verbose "Removed $removedCount watched items from playlist"

        return $removedCount
    }
}
