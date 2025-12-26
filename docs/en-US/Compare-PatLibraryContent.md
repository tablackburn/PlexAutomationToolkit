---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Compare-PatLibraryContent

## SYNOPSIS
Compares library content before and after a scan to identify changes.

## SYNTAX

```
Compare-PatLibraryContent [-Before] <Object[]> [-After] <Object[]> [[-KeyProperty] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Takes two collections of library items (typically from Get-PatLibraryItem)
and identifies what was added, removed, or modified between them.
Useful for validating that a library scan actually had the expected effect.

## EXAMPLES

### EXAMPLE 1
```
$before = Get-PatLibraryItem -SectionName 'Movies'
Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'
Wait-PatLibraryScan -SectionName 'Movies'
$after = Get-PatLibraryItem -SectionName 'Movies'
```

Compare-PatLibraryContent -Before $before -After $after

Captures library state, triggers scan, waits, and compares to find changes.

### EXAMPLE 2
```
$changes = Compare-PatLibraryContent -Before $before -After $after
$changes | Where-Object ChangeType -eq 'Added'
```

Filters to show only newly added items.

### EXAMPLE 3
```
$changes = Compare-PatLibraryContent -Before $before -After $after
$changes | Where-Object ChangeType -eq 'Removed'
```

Filters to show items that were removed (e.g., after deleting files and rescanning).

### EXAMPLE 4
```
$changes = Compare-PatLibraryContent -Before $before -After $after -KeyProperty 'title'
```

Uses title instead of ratingKey for comparison (useful for testing).

## PARAMETERS

### -Before
The collection of library items before the scan.
Typically captured with: $before = Get-PatLibraryItem -SectionName 'Movies'

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -After
The collection of library items after the scan.

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeyProperty
The property to use as the unique identifier for items.
Default: 'ratingKey' (Plex's unique item ID).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: RatingKey
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

### PSCustomObject[] with properties:
### - ChangeType: 'Added', 'Removed', or 'Unchanged'
### - Item: The library item object
### - Title: The item's title (for convenience)
### - RatingKey: The item's unique ID
## NOTES

## RELATED LINKS
