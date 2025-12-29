---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatMediaInfo

## SYNOPSIS
Retrieves detailed media information from a Plex server.

## SYNTAX

```
Get-PatMediaInfo [-RatingKey] <Int32> [[-ServerUri] <String>] [[-Token] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets comprehensive metadata for a media item including file paths, sizes, codecs,
and subtitle streams.
This information is essential for downloading media files
and their associated subtitles.

## EXAMPLES

### EXAMPLE 1
```
Get-PatMediaInfo -RatingKey 12345
```

Retrieves detailed media information for the item with ratingKey 12345.

### EXAMPLE 2
```
Get-PatPlaylist -PlaylistName 'Travel' -IncludeItems | Select-Object -ExpandProperty Items | Get-PatMediaInfo
```

Retrieves media info for all items in the 'Travel' playlist.

### EXAMPLE 3
```
12345, 67890 | Get-PatMediaInfo
```

Retrieves media info for multiple items via pipeline.

## PARAMETERS

### -RatingKey
The unique identifier (ratingKey) of the media item to retrieve.
This is the Plex internal ID for movies, episodes, or other media.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: 0
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
Position: 2
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
Position: 3
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

### PlexAutomationToolkit.MediaInfo
### Objects with properties:
### - RatingKey: Unique media identifier
### - Title: Media title
### - Type: 'movie' or 'episode'
### - Year: Release year (movies)
### - GrandparentTitle: Show name (episodes)
### - ParentIndex: Season number (episodes)
### - Index: Episode number (episodes)
### - Duration: Duration in milliseconds
### - ViewCount: Number of times watched
### - LastViewedAt: Last watched timestamp
### - Media: Array of media versions with file info
### - ServerUri: The Plex server URI
## NOTES

## RELATED LINKS
