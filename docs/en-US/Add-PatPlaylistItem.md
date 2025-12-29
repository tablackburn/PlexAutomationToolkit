---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Add-PatPlaylistItem

## SYNOPSIS
Adds items to an existing playlist on a Plex server.

## SYNTAX

### ById (Default)
```
Add-PatPlaylistItem -PlaylistId <Int32> -RatingKey <Int32[]> [-ServerUri <String>] [-Token <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByName
```
Add-PatPlaylistItem -PlaylistName <String> -RatingKey <Int32[]> [-ServerUri <String>] [-Token <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Adds one or more media items to an existing playlist.
Items are specified by
their rating keys (unique identifiers in the Plex library).
Items are added
to the end of the playlist.

## EXAMPLES

### EXAMPLE 1
```
Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890
```

Adds the media item with rating key 67890 to playlist 12345.

### EXAMPLE 2
```
Add-PatPlaylistItem -PlaylistName 'My Favorites' -RatingKey 111, 222, 333
```

Adds three items to the playlist named 'My Favorites'.

### EXAMPLE 3
```
Get-PatLibraryItem -SectionId 1 -Filter 'year=2024' |
    ForEach-Object { $_.ratingKey } |
    Add-PatPlaylistItem -PlaylistName 'New Releases'
```

Adds all 2024 items from library section 1 to the 'New Releases' playlist.

### EXAMPLE 4
```
Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890 -PassThru
```

Adds an item and returns the updated playlist object.

## PARAMETERS

### -PlaylistId
The unique identifier of the playlist to add items to.

```yaml
Type: Int32
Parameter Sets: ById
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -PlaylistName
The name of the playlist to add items to.
Supports tab completion.

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RatingKey
One or more media item rating keys to add to the playlist.
Rating keys can be obtained from library browsing commands like Get-PatLibraryItem.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
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
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Token
The Plex authentication token. Required when using -ServerUri to authenticate
with the server. If not specified with -ServerUri, requests may fail with 401.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
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

## RELATED LINKS
