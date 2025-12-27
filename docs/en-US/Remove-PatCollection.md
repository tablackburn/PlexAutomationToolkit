---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Remove-PatCollection

## SYNOPSIS
Removes a collection from a Plex library.

## SYNTAX

### ById (Default)
```
Remove-PatCollection -CollectionId <Int32> [-ServerUri <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByName
```
Remove-PatCollection -CollectionName <String> -LibraryId <Int32> [-ServerUri <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes a collection from the Plex library.
Can identify the collection by ID or name.
This action is irreversible - the collection and its item associations will be
permanently deleted.
The media items themselves are not affected.

## EXAMPLES

### EXAMPLE 1
```
Remove-PatCollection -CollectionId 12345
```

Removes the collection with ID 12345 after confirmation.

### EXAMPLE 2
```
Remove-PatCollection -CollectionName 'Old Collection' -LibraryId 1 -Confirm:$false
```

Removes the collection named 'Old Collection' from library 1 without confirmation.

### EXAMPLE 3
```
Get-PatCollection -LibraryId 1 -CollectionName 'Temp*' | Remove-PatCollection
```

Removes collections starting with 'Temp' from library 1 via pipeline.

### EXAMPLE 4
```
Remove-PatCollection -CollectionName 'Test Collection' -LibraryId 1 -WhatIf
```

Shows what would be removed without actually removing it.

### EXAMPLE 5
```
Remove-PatCollection -CollectionId 12345 -PassThru
```

Removes the collection and returns the removed collection object for logging.

## PARAMETERS

### -CollectionId
The unique identifier of the collection to remove.

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
The name of the collection to remove.
Supports tab completion.
Requires LibraryId to be specified.

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

### -LibraryId
The library section ID containing the collection.
Required when using -CollectionName.
Use Get-PatLibrary to find library IDs.

```yaml
Type: Int32
Parameter Sets: ByName
Aliases:

Required: True
Position: Named
Default value: 0
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

### -PassThru
If specified, returns the collection object that was removed.

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
### Returns the removed collection object for auditing purposes.
## NOTES

## RELATED LINKS
