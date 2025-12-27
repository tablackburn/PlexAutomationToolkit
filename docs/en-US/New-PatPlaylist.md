---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# New-PatPlaylist

## SYNOPSIS
Creates a new playlist on a Plex server.

## SYNTAX

```
New-PatPlaylist [-Title] <String> [[-Type] <String>] [[-RatingKey] <Int32[]>] [[-ServerUri] <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Creates a new regular (non-smart) playlist on the Plex server.
You can specify
the playlist title, type (video, audio, or photo), and optionally add initial
items during creation.

## EXAMPLES

### EXAMPLE 1
```
New-PatPlaylist -Title 'My Favorites'
```

Creates a new empty video playlist named 'My Favorites'.

### EXAMPLE 2
```
New-PatPlaylist -Title 'Road Trip Music' -Type audio
```

Creates a new empty audio playlist named 'Road Trip Music'.

### EXAMPLE 3
```
New-PatPlaylist -Title 'Weekend Watchlist' -RatingKey 12345, 67890 -PassThru
```

Creates a playlist with two initial items and returns the created playlist object.

### EXAMPLE 4
```
Get-PatLibraryItem -SectionId 1 | Select-Object -First 5 -ExpandProperty ratingKey |
    ForEach-Object { New-PatPlaylist -Title 'Top 5' -RatingKey $_ }
```

Creates a playlist from the first 5 items in library section 1.

## PARAMETERS

### -Title
The title/name of the new playlist.
Must be unique on the server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Type
The type of content the playlist will contain.
Valid values are:
- video (default): Movies, TV shows, or other video content
- audio: Music tracks
- photo: Photos

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Video
Accept pipeline input: False
Accept wildcard characters: False
```

### -RatingKey
One or more media item rating keys to add to the playlist upon creation.
Rating keys can be obtained from library browsing commands.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
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
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns the created playlist object.

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
### Returns the created playlist object with properties:
### - PlaylistId: Unique playlist identifier
### - Title: Name of the playlist
### - Type: Playlist type (video, audio, photo)
### - ItemCount: Number of items in the playlist
### - ServerUri: The Plex server URI
## NOTES

## RELATED LINKS
