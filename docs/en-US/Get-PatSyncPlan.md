---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatSyncPlan

## SYNOPSIS
Generates a sync plan for transferring media from a Plex playlist to a destination.

## SYNTAX

### ByName (Default)
```
Get-PatSyncPlan [-PlaylistName <String>] -Destination <String> [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Get-PatSyncPlan -PlaylistId <Int32> -Destination <String> [-ServerUri <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Analyzes a Plex playlist and compares it against the destination folder to determine
what files need to be added or removed.
Calculates space requirements and verifies
available disk space.

## EXAMPLES

### EXAMPLE 1
```
Get-PatSyncPlan -PlaylistName 'Travel' -Destination 'E:\'
```

Shows what files would be synced from the 'Travel' playlist to drive E:.

### EXAMPLE 2
```
Get-PatSyncPlan -PlaylistId 12345 -Destination 'D:\PlexMedia'
```

Shows the sync plan for playlist 12345.

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

### PlexAutomationToolkit.SyncPlan
### Object with properties:
### - PlaylistName: Name of the playlist
### - PlaylistId: ID of the playlist
### - Destination: Target path
### - TotalItems: Total items in playlist
### - ItemsToAdd: Number of items to download
### - ItemsToRemove: Number of items to delete
### - ItemsUnchanged: Number of items already synced
### - BytesToDownload: Total bytes to download
### - BytesToRemove: Total bytes to free by removal
### - DestinationFree: Current free space at destination
### - DestinationAfter: Projected free space after sync
### - SpaceSufficient: Whether there's enough space
### - AddOperations: Array of items to add
### - RemoveOperations: Array of items to remove
## NOTES

## RELATED LINKS
