---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Stop-PatSession

## SYNOPSIS
Terminates an active playback session on a Plex server.

## SYNTAX

```
Stop-PatSession [-SessionId] <String> [[-Reason] <String>] [[-ServerName] <String>] [[-ServerUri] <String>]
 [[-Token] <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Stops an active streaming session, disconnecting the user from playback.
This is useful for server management, freeing up resources, or enforcing
usage policies.
The session owner will see playback stop on their device.

Use Get-PatSession to find active sessions and their SessionId values.

## EXAMPLES

### EXAMPLE 1
```
Stop-PatSession -SessionId 'abc123def456'
```

Terminates the session with the specified ID (prompts for confirmation).

### EXAMPLE 2
```
Stop-PatSession -SessionId 'abc123def456' -Reason 'Server maintenance'
```

Terminates the session and displays a maintenance message to the user.

### EXAMPLE 3
```
Get-PatSession -Username 'guest' | Stop-PatSession
```

Terminates all sessions for the user 'guest'.

### EXAMPLE 4
```
Get-PatSession | Where-Object { $_.IsLocal -eq $false } | Stop-PatSession -Reason 'Remote access disabled'
```

Terminates all remote (non-local) sessions.

### EXAMPLE 5
```
Stop-PatSession -SessionId 'abc123' -WhatIf
```

Shows what would happen without actually terminating the session.

### EXAMPLE 6
```
Stop-PatSession -SessionId 'abc123' -Confirm:$false
```

Terminates the session without prompting for confirmation.

## PARAMETERS

### -SessionId
The unique identifier of the session to terminate.
This can be obtained
from Get-PatSession output (the SessionId property).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Reason
Optional message to display to the user whose session is being terminated.
For example: "Server maintenance in progress" or "Bandwidth limit exceeded".

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

### -ServerName
The name of a stored server to use. Use Get-PatStoredServer to see available servers.
This is more convenient than ServerUri as you don't need to remember the URI or token.

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

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400).
If not specified, uses the default stored server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns the session information before termination.

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

### None by default. With -PassThru, returns PlexAutomationToolkit.Session object.
## NOTES
This cmdlet has a ConfirmImpact of High, so it will prompt for confirmation
by default.
Use -Confirm:$false to bypass the prompt, or -WhatIf to preview
the action without executing it.

## RELATED LINKS
