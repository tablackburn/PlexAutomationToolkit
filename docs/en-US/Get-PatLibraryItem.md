---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatLibraryItem

## SYNOPSIS
Retrieves media items from a Plex library.

## SYNTAX

### ById (Default)
```
Get-PatLibraryItem [-ServerUri <String>] -SectionId <Int32> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByName
```
Get-PatLibraryItem [-ServerUri <String>] -SectionName <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Gets all media items (movies, TV shows, music, etc.) from a specified Plex library section.
Returns metadata for each item including title, year, rating, and other properties.

## EXAMPLES

### EXAMPLE 1
```
Get-PatLibraryItem -SectionId 1
```

Retrieves all items from library section 1.

### EXAMPLE 2
```
Get-PatLibraryItem -SectionName "Movies"
```

Retrieves all items from the Movies library.

### EXAMPLE 3
```
Get-PatLibrary | Where-Object { $_.Directory.title -eq 'Movies' } | ForEach-Object { Get-PatLibraryItem -SectionId ($_.Directory.key -replace '.*/(\d+)$', '$1') }
```

Gets the Movies library and retrieves all items from it.

## PARAMETERS

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400)
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

### -SectionId
The ID of the library section to retrieve items from.

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

### -SectionName
The name of the library section to retrieve items from (e.g., "Movies", "TV Shows").

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

### PSCustomObject[]
### Returns an array of media item metadata objects from the Plex API.
## NOTES

## RELATED LINKS
