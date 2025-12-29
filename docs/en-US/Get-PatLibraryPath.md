---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatLibraryPath

## SYNOPSIS
Retrieves library section paths from a Plex server.

## SYNTAX

### All (Default)
```
Get-PatLibraryPath [-ServerUri <String>] [-Token <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByName
```
Get-PatLibraryPath [-SectionName <String>] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Get-PatLibraryPath [-SectionId <Int32>] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets the configured filesystem paths for a specific Plex library section.
Returns the primary and any secondary paths configured for the section.

## EXAMPLES

### EXAMPLE 1
```
Get-PatLibraryPath -ServerUri "http://plex.example.com:32400" -SectionId 1
```

Retrieves all configured paths for library section 1

### EXAMPLE 2
```
Get-PatLibraryPath -SectionId 2
```

Retrieves all configured paths for library section 2 from the default stored server

## PARAMETERS

### -SectionName
The friendly name of the library section (e.g., "Movies", "TV Shows")

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

### -SectionId
The ID of the library section.
Mandatory.

```yaml
Type: Int32
Parameter Sets: ById
Aliases:

Required: False
Position: Named
Default value: 0
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

### PSCustomObject
## NOTES

## RELATED LINKS
