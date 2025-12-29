---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Update-PatLibrary

## SYNOPSIS
Refreshes a Plex library section.

## SYNTAX

### ByName (Default)
```
Update-PatLibrary -SectionName <String> [-Path <String>] [-PassThru] [-SkipPathValidation] [-Wait]
 [-Timeout <Int32>] [-ReportChanges] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```
Update-PatLibrary -SectionId <Int32> [-Path <String>] [-PassThru] [-SkipPathValidation] [-Wait]
 [-Timeout <Int32>] [-ReportChanges] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Triggers a refresh scan on a specified Plex library section.
Optionally scans a specific path within the library.
You can specify the section by ID or by friendly name.
If ServerUri is not specified, uses the default stored server.

## EXAMPLES

### EXAMPLE 1
```
Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2
Refreshes the entire library section 2
```

Use this after adding or removing media so Plex rescans the whole section.

### EXAMPLE 2
```
Update-PatLibrary -SectionName "Movies"
Refreshes the "Movies" library section on the default stored server
```

Simplest form when you have a default server configured.

### EXAMPLE 3
```
Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies"
Refreshes the library section named "Movies"
```

Specify sections by friendly name instead of looking up the ID.

### EXAMPLE 4
```
Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -Path "/mnt/media/Movies"
Refreshes only the specified path within library section 2
```

Target a subfolder when you know exactly where new files were added.

### EXAMPLE 5
```
Update-PatLibrary -SectionId 2 -Path "/mnt/media/Movies"
Refreshes only the specified path within library section 2 on the default stored server
```

Combine default server with path targeting.

### EXAMPLE 6
```
Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionName "Movies" -Path "/mnt/media/Movies/Action"
Refreshes only the specified path within the "Movies" library section
```

Combine section name with path targeting for readable commands.

### EXAMPLE 7
```
Update-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2 -WhatIf
Shows what would happen if the command runs without actually refreshing the library
```

Combine with -Verbose to inspect the request without triggering a scan.

## PARAMETERS

### -SectionName
The friendly name of the library section to refresh (e.g., "Movies", "TV Shows")

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

### -SectionId
The ID of the library section to refresh

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

### -Path
Optional path within the library to scan.
If omitted, the entire section is scanned.

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
If specified, returns the library section object after refreshing.

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

### -SkipPathValidation
{{ Fill SkipPathValidation Description }}

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

### -Wait
{{ Fill Wait Description }}

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

### -Timeout
{{ Fill Timeout Description }}

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

### -ReportChanges
{{ Fill ReportChanges Description }}

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

## NOTES

## RELATED LINKS
