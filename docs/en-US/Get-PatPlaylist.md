---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatPlaylist

## SYNOPSIS
Retrieves playlists from a Plex server.

## SYNTAX

### All (Default)
```
Get-PatPlaylist [-IncludeItems] [-ServerUri <String>] [-Token <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ById
```
Get-PatPlaylist -PlaylistId <Int32> [-IncludeItems] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByName
```
Get-PatPlaylist -PlaylistName <String> [-IncludeItems] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets a list of playlists from the Plex server.
Can retrieve all playlists,
filter by ID or name, and optionally include the items within each playlist.
Only returns regular (non-smart) playlists by default.

## EXAMPLES

### EXAMPLE 1
```
Get-PatPlaylist
```

Retrieves all playlists from the default Plex server.

### EXAMPLE 2
```
Get-PatPlaylist -PlaylistId 12345
```

Retrieves the playlist with the specified ID.

### EXAMPLE 3
```
Get-PatPlaylist -PlaylistName 'My Favorites'
```

Retrieves the playlist named 'My Favorites'.

### EXAMPLE 4
```
Get-PatPlaylist -IncludeItems
```

Retrieves all playlists with their items included.

### EXAMPLE 5
```
Get-PatPlaylist -PlaylistName 'Watch Later' -IncludeItems | Select-Object -ExpandProperty Items
```

Retrieves only the items from the 'Watch Later' playlist.

## PARAMETERS

### -PlaylistId
The unique identifier of a specific playlist to retrieve.

```yaml
Type: Int32
Parameter Sets: ById
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PlaylistName
The name of a specific playlist to retrieve.
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

### -IncludeItems
When specified, also retrieves the items within each playlist.
Items are returned in a nested 'Items' property on each playlist object.

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
with the server. If not specified with -ServerUri, requests will fail.

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

### PlexAutomationToolkit.Playlist
### Objects with properties:
### - PlaylistId: Unique playlist identifier (ratingKey)
### - Title: Name of the playlist
### - Type: Playlist type (video, audio, photo)
### - ItemCount: Number of items in the playlist
### - Duration: Total duration in milliseconds
### - Smart: Whether this is a smart playlist
### - Composite: URI of the playlist composite image
### - ServerUri: The Plex server URI
### - Items: (Only with -IncludeItems) Array of playlist items
## NOTES

## RELATED LINKS
