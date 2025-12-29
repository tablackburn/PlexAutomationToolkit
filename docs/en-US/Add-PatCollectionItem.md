---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Add-PatCollectionItem

## SYNOPSIS
Adds items to an existing collection on a Plex server.

## SYNTAX

### ById (Default)
```
Add-PatCollectionItem -CollectionId <Int32> -RatingKey <Int32[]> [-ServerUri <String>] [-Token <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameWithLibraryId
```
Add-PatCollectionItem -CollectionName <String> -LibraryId <Int32> -RatingKey <Int32[]> [-ServerUri <String>]
 [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameWithLibraryName
```
Add-PatCollectionItem -CollectionName <String> -LibraryName <String> -RatingKey <Int32[]> [-ServerUri <String>]
 [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Adds one or more media items to an existing collection.
Items are specified by
their rating keys (unique identifiers in the Plex library).

## EXAMPLES

### EXAMPLE 1
```
Add-PatCollectionItem -CollectionId 12345 -RatingKey 67890
```

Adds the media item with rating key 67890 to collection 12345.

### EXAMPLE 2
```
Add-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryId 1 -RatingKey 111, 222, 333
```

Adds three items to the collection named 'Marvel Movies' in library 1.

### EXAMPLE 3
```
Get-PatLibraryItem -LibraryId 1 -Title '*Avengers*' |
    ForEach-Object { $_.ratingKey } |
    Add-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryId 1
```

Adds all items matching 'Avengers' from library 1 to the 'Marvel Movies' collection.

### EXAMPLE 4
```
Add-PatCollectionItem -CollectionId 12345 -RatingKey 67890 -PassThru
```

Adds an item and returns the updated collection object.

## PARAMETERS

### -CollectionId
The unique identifier of the collection to add items to.

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

### -CollectionName
The name of the collection to add items to.
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
The name of the library containing the collection. Supports tab completion.
Required when using -CollectionName. This is the preferred way to specify a library.

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
The library section ID containing the collection.
Required when using -CollectionName.
Use Get-PatLibrary to find library IDs.

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

### -RatingKey
One or more media item rating keys to add to the collection.
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
If specified, returns the updated collection object.

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

### PlexAutomationToolkit.Collection (when -PassThru is specified)
### Returns the updated collection object showing the new item count.
## NOTES

## RELATED LINKS
