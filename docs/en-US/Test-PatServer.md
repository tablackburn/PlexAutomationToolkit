---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Test-PatServer

## SYNOPSIS
Tests connectivity to a stored Plex server.

## SYNTAX

```
Test-PatServer [-Name] <String> [-Quiet] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Validates that a stored server configuration works by attempting to connect
and authenticate with the Plex server.
Returns connection status information
including whether the server is reachable, authenticated, and basic server details.

## EXAMPLES

### EXAMPLE 1
```
Test-PatServer -Name 'Home'
```

Tests connectivity to the stored server named 'Home' and returns detailed status.

### EXAMPLE 2
```
Test-PatServer -Name 'Home' -Quiet
```

Tests connectivity and returns $true if successful, $false otherwise.

### EXAMPLE 3
```
Get-PatStoredServer | ForEach-Object { Test-PatServer -Name $_.name }
```

Tests all stored servers and returns their connection status.

### EXAMPLE 4
```
if (Test-PatServer -Name 'Home' -Quiet) {
    Get-PatLibrary -ServerName 'Home'
}
```

Checks server connectivity before attempting operations.

## PARAMETERS

### -Name
The name of the stored server to test.
Use Get-PatStoredServer to see available servers.

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

### -Quiet
If specified, returns only a boolean indicating success/failure instead of
detailed connection information.

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

### -ProgressAction
Determines how the cmdlet responds to progress updates. This is a common parameter.

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

### PlexAutomationToolkit.ServerTestResult (default)
### Returns an object with properties:
### - Name: Server name from configuration
### - Uri: The URI used for connection
### - IsConnected: Whether the server responded
### - IsAuthenticated: Whether authentication succeeded
### - FriendlyName: Server's friendly name (if connected)
### - Version: Plex server version (if connected)
### - Error: Error message (if connection failed)
### System.Boolean (with -Quiet)
### Returns $true if connection succeeded, $false otherwise.
## NOTES

## RELATED LINKS
