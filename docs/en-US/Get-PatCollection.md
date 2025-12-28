---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatCollection

## SYNOPSIS
Retrieves collections from a Plex server library.

## SYNTAX

### All (Default)
```
Get-PatCollection [-LibraryName <String>] [-LibraryId <Int32>] [-IncludeItems] [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Get-PatCollection -CollectionId <Int32> [-IncludeItems] [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByNameWithLibraryId
```
Get-PatCollection -CollectionName <String> -LibraryId <Int32> [-IncludeItems] [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByNameWithLibraryName
```
Get-PatCollection -CollectionName <String> -LibraryName <String> [-IncludeItems] [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets a list of collections from a Plex library.
Can retrieve all collections
in a library, filter by ID or name, and optionally include the items within
each collection.
Collections are library-scoped, so a LibraryId is required
when listing all collections or searching by name.

## EXAMPLES

### EXAMPLE 1
```
Get-PatCollection -LibraryId 1
```

Retrieves all collections from the library with ID 1.

### EXAMPLE 2
```
Get-PatCollection -CollectionId 12345
```

Retrieves the collection with the specified ID.

### EXAMPLE 3
```
Get-PatCollection -CollectionName 'Marvel Movies' -LibraryId 1
```

Retrieves the collection named 'Marvel Movies' from library 1.

### EXAMPLE 4
```
Get-PatCollection -LibraryId 1 -IncludeItems
```

Retrieves all collections from library 1 with their items included.

### EXAMPLE 5
```
Get-PatCollection -CollectionName 'Horror' -LibraryId 1 -IncludeItems | Select-Object -ExpandProperty Items
```

Retrieves only the items from the 'Horror' collection.

## PARAMETERS

### -CollectionId
The unique identifier of a specific collection to retrieve.

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

### -CollectionName
The name of a specific collection to retrieve.
Supports tab completion.
Requires LibraryId to be specified.

```yaml
Type: String
Parameter Sets: ByNameWithLibraryId, ByNameWithLibraryName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LibraryName
The name of the library to retrieve collections from. Supports tab completion.
This is the preferred way to specify a library.

```yaml
Type: String
Parameter Sets: All
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: ByNameWithLibraryName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LibraryId
The library section ID to retrieve collections from.
Required when listing
all collections or searching by name.
Use Get-PatLibrary to find library IDs.

```yaml
Type: Int32
Parameter Sets: All
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: Int32
Parameter Sets: ByNameWithLibraryId
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeItems
When specified, also retrieves the items within each collection.
Items are returned in a nested 'Items' property on each collection object.

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

### PlexAutomationToolkit.Collection
### Objects with properties:
### - CollectionId: Unique collection identifier (ratingKey)
### - Title: Name of the collection
### - LibraryId: The library section ID this collection belongs to
### - ItemCount: Number of items in the collection
### - AddedAt: When the collection was created
### - UpdatedAt: When the collection was last modified
### - Thumb: URI of the collection thumbnail
### - ServerUri: The Plex server URI
### - Items: (Only with -IncludeItems) Array of collection items
## NOTES

## RELATED LINKS
