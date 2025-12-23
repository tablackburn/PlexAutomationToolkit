---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatStoredServer

## SYNOPSIS
Gets stored Plex server configurations.

## SYNTAX

### All (Default)
```
Get-PatStoredServer [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByName
```
Get-PatStoredServer [-Name <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Default
```
Get-PatStoredServer [-Default] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves Plex server configurations from the config file.
Can retrieve all servers, the default server, or a specific server by name.

## EXAMPLES

### EXAMPLE 1
```
Get-PatStoredServer
```

Returns all stored servers

### EXAMPLE 2
```
Get-PatStoredServer -Default
```

Returns the default server

### EXAMPLE 3
```
Get-PatStoredServer -Name "Main Server"
```

Returns the server named "Main Server"

## PARAMETERS

### -Name
Optional name of a specific server to retrieve

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

### -Default
If specified, returns only the default server

```yaml
Type: SwitchParameter
Parameter Sets: Default
Aliases:

Required: False
Position: Named
Default value: False
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
### Returns server configuration objects with name, uri, and default properties
## NOTES

## RELATED LINKS
