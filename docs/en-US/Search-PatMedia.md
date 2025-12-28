---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Search-PatMedia

## SYNOPSIS
Searches for media items across Plex libraries.

## SYNTAX

### All (Default)
```
Search-PatMedia [-Query] <String> [-ServerUri <String>] [-Type <String[]>] [-Limit <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByName
```
Search-PatMedia [-Query] <String> [-ServerUri <String>] [-SectionName <String>] [-Type <String[]>]
 [-Limit <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Search-PatMedia [-Query] <String> [-ServerUri <String>] [-SectionId <Int32>] [-Type <String[]>]
 [-Limit <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Searches for media items (movies, TV shows, music, etc.) across all or specific
Plex library sections using the Plex search API. Returns flattened results
with type information for easy filtering and pipeline operations.

## EXAMPLES

### EXAMPLE 1
```
Search-PatMedia -Query "matrix"
```

Searches for "matrix" across all libraries on the default server.

### EXAMPLE 2
```
Search-PatMedia -Query "action" -SectionName "Movies"
```

Searches for "action" only in the Movies library.

### EXAMPLE 3
```
Search-PatMedia -Query "beatles" -Type artist,album
```

Searches for "beatles" and returns only artist and album results.

### EXAMPLE 4
```
Search-PatMedia -Query "star" -Limit 5
```

Searches for "star" with a maximum of 5 results per type.

### EXAMPLE 5
```
Search-PatMedia -Query "favorites" -Type movie | Get-PatMediaInfo
```

Searches for movies matching "favorites" and gets detailed media info.

## PARAMETERS

### -Query
The search term to find matching media items.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
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

### -SectionName
Limit search to a specific library section by name (e.g., "Movies", "TV Shows").

```yaml
Type: String
Parameter Sets: ByName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SectionId
Limit search to a specific library section by ID.

```yaml
Type: Int32
Parameter Sets: ById
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Type
Filter results by media type(s). Valid values: movie, show, season, episode,
artist, album, track, photo, collection.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
Maximum number of results to return per media type. Defaults to 10.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 10
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

### System.String
### You can pipe a search query string to this cmdlet.

## OUTPUTS

### PSCustomObject[]
### Returns an array of search result objects with properties:
### - Type: The media type (movie, show, episode, artist, etc.)
### - RatingKey: Unique identifier for the media item
### - Title: Title of the media item
### - Year: Release year (if applicable)
### - Summary: Description of the media item
### - Thumb: Thumbnail image path
### - LibraryId: ID of the library section containing this item
### - LibraryName: Name of the library section
### - ServerUri: URI of the Plex server

## NOTES

## RELATED LINKS
