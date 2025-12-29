---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Remove-PatPlaylist

## SYNOPSIS
Removes a playlist from a Plex server.

## SYNTAX

### ById (Default)
```
Remove-PatPlaylist -PlaylistId <Int32> [-ServerUri <String>] [-Token <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByName
```
Remove-PatPlaylist -PlaylistName <String> [-ServerUri <String>] [-Token <String>] [-PassThru]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes a playlist from the Plex server.
Can identify the playlist by ID or name.
This action is irreversible - the playlist and its item associations will be
permanently deleted.

## EXAMPLES

### EXAMPLE 1
```
Remove-PatPlaylist -PlaylistId 12345
```

Removes the playlist with ID 12345 after confirmation.

### EXAMPLE 2
```
Remove-PatPlaylist -PlaylistName 'Old Playlist' -Confirm:$false
```

Removes the playlist named 'Old Playlist' without confirmation prompt.

### EXAMPLE 3
```
Get-PatPlaylist -PlaylistName 'Temp*' | Remove-PatPlaylist
```

Removes all playlists starting with 'Temp' via pipeline.

### EXAMPLE 4
```
Remove-PatPlaylist -PlaylistName 'Test Playlist' -WhatIf
```

Shows what would be removed without actually removing it.

### EXAMPLE 5
```
Remove-PatPlaylist -PlaylistId 12345 -PassThru
```

Removes the playlist and returns the removed playlist object for logging.

## PARAMETERS

### -PlaylistId
The unique identifier of the playlist to remove.

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

### -PlaylistName
The name of the playlist to remove.
Supports tab completion.

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
If specified, returns the playlist object that was removed.

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

### PlexAutomationToolkit.Playlist (when -PassThru is specified)
### Returns the removed playlist object for auditing purposes.
## NOTES

## RELATED LINKS
