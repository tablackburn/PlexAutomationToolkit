---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatLibrary

## SYNOPSIS
Retrieves Plex library information.

## SYNTAX

```
Get-PatLibrary [[-ServerUri] <String>] [[-SectionId] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Gets information about all Plex library sections or a specific library section.

## EXAMPLES

### EXAMPLE 1
```
Get-PatLibrary -ServerUri "http://plex.example.com:32400"
Retrieves all library sections from the server
```

Use this to list every available section before refreshing or filtering by ID.

### EXAMPLE 2
```
Get-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2
Retrieves information for library section 2
```

Use this to inspect a single library section when you already know its numeric ID.

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

### -SectionId
Optional ID of a specific library section to retrieve.
If omitted, returns all sections.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
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
