---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Clear-PatDefaultServer

## SYNOPSIS
Clears the default Plex server designation.

## SYNTAX

```
Clear-PatDefaultServer [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Removes the default flag from all configured servers.
After clearing the default server, cmdlets will require an explicit -ServerUri parameter.

This is useful when you want to ensure explicit server selection in scripts or when managing multiple servers where no single default is appropriate.

## EXAMPLES

### EXAMPLE 1
```
Clear-PatDefaultServer
```

Clears the default server designation.
All cmdlets will now require -ServerUri.

### EXAMPLE 2
```
Clear-PatDefaultServer -PassThru
```

Clears the default server and returns all server configurations.

### EXAMPLE 3
```
Clear-PatDefaultServer -WhatIf
```

Shows what would happen if the default server was cleared without actually clearing it.

## PARAMETERS

### -PassThru
If specified, returns the updated server configuration objects after clearing the default.

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

### None

## OUTPUTS

### None
Or PlexAutomationToolkit.ServerConfig[] if -PassThru is specified

## NOTES

## RELATED LINKS

[Set-PatDefaultServer]()

[Get-PatStoredServer]()

[Add-PatServer]()
