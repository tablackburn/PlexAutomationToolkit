---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatSession

## SYNOPSIS
Retrieves active playback sessions from a Plex server.

## SYNTAX

```
Get-PatSession [[-Username] <String>] [[-Player] <String>] [[-ServerUri] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets a list of current streaming sessions on the Plex server, including
information about what is being played, who is watching, and which device
is being used.
This is useful for monitoring server usage and managing
active streams.

## EXAMPLES

### EXAMPLE 1
```
Get-PatSession
```

Retrieves all active playback sessions from the default Plex server.

### EXAMPLE 2
```
Get-PatSession -Username 'john'
```

Retrieves only sessions where user 'john' is watching.

### EXAMPLE 3
```
Get-PatSession -Player 'Living Room TV'
```

Retrieves sessions from the device named 'Living Room TV'.

### EXAMPLE 4
```
Get-PatSession | Where-Object { $_.Progress -gt 90 }
```

Retrieves sessions that are more than 90% complete.

### EXAMPLE 5
```
Get-PatSession | Format-Table Username, MediaTitle, PlayerName, Progress
```

Displays a formatted table of who is watching what.

## PARAMETERS

### -Username
Optional filter to show only sessions for a specific username.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Player
Optional filter to show only sessions from a specific player/device name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
Position: 3
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

### PlexAutomationToolkit.Session
### Objects with properties:
### - SessionId: Unique session identifier (use with Stop-PatSession)
### - MediaTitle: Title of the media being played
### - MediaType: Type of media (movie, episode, track, etc.)
### - MediaKey: Plex library key for the media item
### - Username: Name of the user watching
### - UserId: Plex user ID
### - PlayerName: Name of the playback device
### - PlayerAddress: IP address of the player
### - PlayerPlatform: Platform/OS of the player
### - PlayerMachineId: Unique identifier of the player device
### - IsLocal: Whether the player is on the local network
### - Bandwidth: Current streaming bandwidth in kbps
### - ViewOffset: Current playback position in milliseconds
### - Duration: Total media duration in milliseconds
### - Progress: Playback progress as percentage (0-100)
### - ServerUri: The Plex server URI
## NOTES

## RELATED LINKS
