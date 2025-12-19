---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Add-PatServer

## SYNOPSIS
Adds a Plex server to the configuration.

## SYNTAX

```
Add-PatServer [-Name] <String> [-ServerUri] <String> [-Default] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Adds a new Plex server entry to the server configuration file.
Optionally marks the server as default.

## EXAMPLES

### EXAMPLE 1
```
Add-PatServer -Name "Main Server" -ServerUri "http://plex.local:32400" -Default
```

Adds a new server and marks it as default

### EXAMPLE 2
```
Add-PatServer -Name "Remote Server" -ServerUri "http://remote.plex.com:32400"
```

Adds a new server without marking it as default

## PARAMETERS

### -Name
Friendly name for the server (e.g., "Main Plex Server")

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

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400)

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

### -Default
If specified, marks this server as the default server

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
