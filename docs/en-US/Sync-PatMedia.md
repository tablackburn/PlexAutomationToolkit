---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Sync-PatMedia

## SYNOPSIS
Syncs media from a Plex playlist to a destination folder.

## SYNTAX

### ByName (Default)
```
Sync-PatMedia [-PlaylistName <String>] -Destination <String> [-SkipSubtitles] [-SkipRemoval] [-Force]
 [-PassThru] [-ServerUri <String>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### ById
```
Sync-PatMedia -PlaylistId <Int32> -Destination <String> [-SkipSubtitles] [-SkipRemoval] [-Force] [-PassThru]
 [-ServerUri <String>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Downloads media files from a Plex playlist to a destination folder with Plex-compatible
folder structure.
Optionally removes files at the destination that are not in the playlist.
Supports subtitle downloads and progress reporting.

## EXAMPLES

### EXAMPLE 1
```
Sync-PatMedia -PlaylistName 'Travel' -Destination 'E:\'
```

Syncs the 'Travel' playlist to drive E:.

### EXAMPLE 2
```
Sync-PatMedia -PlaylistName 'Travel' -Destination 'E:\' -IncludeSubtitles
```

Syncs the playlist including all external subtitles.

### EXAMPLE 3
```
Sync-PatMedia -PlaylistName 'Travel' -Destination 'E:\' -WhatIf
```

Shows what would be synced without making any changes.

## PARAMETERS

### -PlaylistName
The name of the playlist to sync.
Supports tab completion.

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

### -PlaylistId
The unique identifier of the playlist to sync.

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

### -Destination
The destination path where media files will be synced (e.g., 'E:\' for a USB drive).

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

### -SkipSubtitles
When specified, does not download external subtitle files. By default, subtitles
are included in the sync.

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

### -SkipRemoval
When specified, does not remove files at the destination that are not in the playlist.

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

### -Force
Skip the space sufficiency check and proceed even if there may not be enough space.

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

### -PassThru
Returns the sync plan after completion.

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
The base URI of the Plex server.
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

### PlexAutomationToolkit.SyncPlan (with -PassThru)
### Returns the sync plan with operation results.
## NOTES

## RELATED LINKS
