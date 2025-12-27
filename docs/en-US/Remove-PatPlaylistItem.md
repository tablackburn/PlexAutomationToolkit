---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Remove-PatPlaylistItem

## SYNOPSIS
Removes an item from a playlist on a Plex server.

## SYNTAX

```
Remove-PatPlaylistItem [-PlaylistId] <Int32> [-PlaylistItemId] <Int32> [[-ServerUri] <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes a single item from a playlist.
The item is identified by its
playlist-specific item ID (playlistItemId), not the media's rating key.
Use Get-PatPlaylist -IncludeItems to retrieve the PlaylistItemId values.

## EXAMPLES

### EXAMPLE 1
```
Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 67890
```

Removes the item with playlist item ID 67890 from playlist 12345.

### EXAMPLE 2
```
Get-PatPlaylist -PlaylistName 'My List' -IncludeItems |
    Select-Object -ExpandProperty Items |
    Where-Object { $_.Title -eq 'Unwanted Movie' } |
    Remove-PatPlaylistItem
```

Removes a specific movie from the playlist by title.

### EXAMPLE 3
```
$playlist = Get-PatPlaylist -PlaylistName 'Watch Later' -IncludeItems
$playlist.Items | Select-Object -First 1 | Remove-PatPlaylistItem -PassThru
```

Removes the first item from a playlist and returns the updated playlist.

### EXAMPLE 4
```
Remove-PatPlaylistItem -PlaylistId 12345 -PlaylistItemId 67890 -WhatIf
```

Shows what would be removed without actually removing it.

## PARAMETERS

### -PlaylistId
The unique identifier of the playlist containing the item.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PlaylistItemId
The playlist-specific item ID of the item to remove.
This is different
from the media's rating key - it identifies the item's position in this
specific playlist.
Obtain this value from Get-PatPlaylist -IncludeItems.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400).
If not specified, uses the default stored server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PassThru
If specified, returns the updated playlist object.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PlexAutomationToolkit.Playlist (when -PassThru is specified)
### Returns the updated playlist object showing the new item count.
## NOTES
The PlaylistItemId is specific to the playlist and represents the item's
position/association within that playlist.
It is not the same as the media's
rating key (ratingKey).
Always use Get-PatPlaylist -IncludeItems to get the
correct PlaylistItemId values.

## RELATED LINKS
