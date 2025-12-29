---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Remove-PatCollectionItem

## SYNOPSIS
Removes an item from a collection on a Plex server.

## SYNTAX

### ById (Default)
```
Remove-PatCollectionItem -CollectionId <Int32> -RatingKey <Int32[]> [-ServerUri <String>] [-Token <String>]
 [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameWithLibraryId
```
Remove-PatCollectionItem -CollectionName <String> -LibraryId <Int32> -RatingKey <Int32[]> [-ServerUri <String>]
 [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameWithLibraryName
```
Remove-PatCollectionItem -CollectionName <String> -LibraryName <String> -RatingKey <Int32[]>
 [-ServerUri <String>] [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Removes one or more media items from a collection.
Items are identified by their
rating keys.
Use Get-PatCollection -IncludeItems to retrieve the RatingKey values
of items in a collection.

## EXAMPLES

### EXAMPLE 1
```
Remove-PatCollectionItem -CollectionId 12345 -RatingKey 67890
```

Removes the item with rating key 67890 from collection 12345.

### EXAMPLE 2
```
Remove-PatCollectionItem -CollectionName 'Marvel Movies' -LibraryId 1 -RatingKey 111, 222
```

Removes two items from the 'Marvel Movies' collection.

### EXAMPLE 3
```
Get-PatCollection -CollectionName 'Horror' -LibraryId 1 -IncludeItems |
    Select-Object -ExpandProperty Items |
    Where-Object { $_.Title -like '*Remake*' } |
    Remove-PatCollectionItem -CollectionId 12345
```

Removes items matching 'Remake' from the collection by piping item objects.

### EXAMPLE 4
```
$collection = Get-PatCollection -CollectionId 12345 -IncludeItems
$collection.Items | Select-Object -First 1 | Remove-PatCollectionItem -PassThru
```

Removes the first item from a collection and returns the updated collection.

### EXAMPLE 5
```
Remove-PatCollectionItem -CollectionId 12345 -RatingKey 67890 -WhatIf
```

Shows what would be removed without actually removing it.

## PARAMETERS

### -CollectionId
The unique identifier of the collection containing the item.

```yaml
Type: Int32
Parameter Sets: ById
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -CollectionName
The name of the collection to remove items from.
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
One or more rating keys of the items to remove from the collection.
Obtain these values from Get-PatCollection -IncludeItems.

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
