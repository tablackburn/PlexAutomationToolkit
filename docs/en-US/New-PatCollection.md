---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# New-PatCollection

## SYNOPSIS
Creates a new collection in a Plex library.

## SYNTAX

### ByLibraryName (Default)
```
New-PatCollection -Title <String> -LibraryName <String> -RatingKey <Int32[]> [-ServerName <String>]
 [-ServerUri <String>] [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### ByLibraryId
```
New-PatCollection -Title <String> -LibraryId <Int32> -RatingKey <Int32[]> [-ServerName <String>]
 [-ServerUri <String>] [-Token <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Creates a new regular (non-smart) collection in the specified Plex library.
You must provide at least one item to create the collection, as Plex does not
support creating empty collections via the API.

## EXAMPLES

### EXAMPLE 1
```
New-PatCollection -Title 'Marvel Movies' -LibraryId 1 -RatingKey 12345
```

Creates a new collection named 'Marvel Movies' in library 1 with one item.

### EXAMPLE 2
```
New-PatCollection -Title 'Horror Classics' -LibraryId 1 -RatingKey 111, 222, 333 -PassThru
```

Creates a collection with three items and returns the created collection object.

### EXAMPLE 3
```
Get-PatLibraryItem -LibraryId 1 -Title '*Batman*' |
    ForEach-Object { $_.ratingKey } |
    New-PatCollection -Title 'Batman Collection' -LibraryId 1 -PassThru
```

Creates a collection from all items matching 'Batman' in library 1.

## PARAMETERS

### -Title
The title/name of the new collection.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LibraryName
The name of the library where the collection will be created. Supports tab completion.
This is the preferred way to specify a library.

```yaml
Type: String
Parameter Sets: ByLibraryName
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LibraryId
The library section ID where the collection will be created.
Use Get-PatLibrary to find library IDs.

```yaml
Type: Int32
Parameter Sets: ByLibraryId
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -RatingKey
One or more media item rating keys to add to the collection upon creation.
At least one item is required.
Rating keys can be obtained from library
browsing commands like Get-PatLibraryItem.

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

### -ServerName
The name of a stored server to use. Use Get-PatStoredServer to see available servers.
This is more convenient than ServerUri as you don't need to remember the URI or token.

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
If specified, returns the created collection object.

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
### Returns the created collection object with properties:
### - CollectionId: Unique collection identifier
### - Title: Name of the collection
### - LibraryId: The library section ID
### - ItemCount: Number of items in the collection
### - ServerUri: The Plex server URI
## NOTES

## RELATED LINKS
