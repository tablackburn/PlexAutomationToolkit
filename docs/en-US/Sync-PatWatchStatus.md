---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Sync-PatWatchStatus

## SYNOPSIS
Syncs watch status from one Plex server to another.

## SYNTAX

```
Sync-PatWatchStatus [-SourceServerName] <String> [-TargetServerName] <String> [[-Direction] <String>]
 [[-SectionId] <Int32[]>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Compares watch status between source and target Plex servers and marks items
as watched on the target server that are watched on the source.
Uses the Plex
scrobble endpoint to mark items as watched.

## EXAMPLES

### EXAMPLE 1
```
Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home'
```

Syncs all watched status from Travel server to Home server.

### EXAMPLE 2
```
Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -SectionId 1, 2
```

Syncs watched status only for library sections 1 and 2.

### EXAMPLE 3
```
Sync-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WhatIf
```

Shows what would be synced without making changes.

## PARAMETERS

### -SourceServerName
The name of the source server (as stored with Add-PatServer).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetServerName
The name of the target server (as stored with Add-PatServer).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Direction
The direction of the sync:
- SourceToTarget (default): Sync watched items from source to target
- TargetToSource: Sync watched items from target to source
- Bidirectional: Sync watched items in both directions

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: SourceToTarget
Accept pipeline input: False
Accept wildcard characters: False
```

### -SectionId
Optional array of library section IDs to sync.
If not specified, syncs all sections.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the sync results after completion.

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

### PlexAutomationToolkit.WatchStatusSyncResult (with -PassThru)
### Objects with properties:
### - Title: Item title
### - Type: 'movie' or 'episode'
### - ShowName: Series name (episodes only)
### - Season: Season number (episodes only)
### - Episode: Episode number (episodes only)
### - RatingKey: Target server rating key
### - Status: 'Success' or 'Failed'
### - Error: Error message if failed
## NOTES

## RELATED LINKS
