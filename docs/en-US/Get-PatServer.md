---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatServer

## SYNOPSIS
Retrieves Plex server information.

## SYNTAX

```
Get-PatServer [[-ServerUri] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets information about a Plex server including version, platform, and capabilities.
If ServerUri is not specified, uses the default stored server.

## EXAMPLES

### EXAMPLE 1
```
Get-PatServer -ServerUri "http://plex.example.com:32400"
Retrieves server information from the specified Plex server
```

### EXAMPLE 2
```
Get-PatServer
Retrieves server information from the default stored server
```

Handy for quickly confirming server version and platform details are reachable.

## PARAMETERS

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400)
If not specified, uses the default stored server.

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

### PSCustomObject
### Returns the MediaContainer object from the Plex API response
## NOTES

## RELATED LINKS
