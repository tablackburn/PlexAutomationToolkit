---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Wait-PatLibraryScan

## SYNOPSIS
Waits for a Plex library scan to complete.

## SYNTAX

### ByName (Default)
```
Wait-PatLibraryScan -SectionName <String> [-Timeout <Int32>] [-PollingInterval <Int32>] [-PassThru]
 [-ServerName <String>] [-ServerUri <String>] [-Token <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ById
```
Wait-PatLibraryScan -SectionId <Int32> [-Timeout <Int32>] [-PollingInterval <Int32>] [-PassThru]
 [-ServerName <String>] [-ServerUri <String>] [-Token <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Blocks execution until a library scan completes for the specified section.
Polls the Plex server's activities endpoint and displays progress.
Useful after calling Update-PatLibrary to ensure the scan finishes
before proceeding.

## EXAMPLES

### EXAMPLE 1
```
Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'
Wait-PatLibraryScan -SectionName 'Movies'
```

Triggers a library scan and waits for it to complete.

### EXAMPLE 2
```
Wait-PatLibraryScan -SectionId 2 -Timeout 60
```

Waits up to 60 seconds for section 2 to finish scanning.

### EXAMPLE 3
```
$status = Wait-PatLibraryScan -SectionName 'Movies' -PassThru
```

Waits for scan completion and returns the final activity status.

### EXAMPLE 4
```
Update-PatLibrary -SectionId 2
Wait-PatLibraryScan -SectionId 2 -PollingInterval 5
```

Waits for scan, checking every 5 seconds instead of the default 2.

## PARAMETERS

### -SectionId
The ID of the library section to monitor.

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

### -SectionName
The friendly name of the library section to monitor (e.g., "Movies").

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

### -Timeout
Maximum time to wait in seconds.
Throws an error if exceeded.
Default: 300 seconds (5 minutes).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 300
Accept pipeline input: False
Accept wildcard characters: False
```

### -PollingInterval
Time between status checks in seconds.
Default: 2 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 2
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns the final activity status when complete.

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

### -ServerName
The name of a stored server to use. Use Get-PatStoredServer to see available servers.
This is more convenient than ServerUri as you don't need to remember the URI or token.

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

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400)
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

### None by default. With -PassThru, returns PlexAutomationToolkit.Activity object
### or $null if no scan was in progress.
## NOTES

## RELATED LINKS
