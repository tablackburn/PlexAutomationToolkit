---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatLibraryChildItem

## SYNOPSIS
Lists directories and files at a given path on the Plex server.

## SYNTAX

### PathOnly (Default)
```
Get-PatLibraryChildItem [-ServerUri <String>] [-Path <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### ByName
```
Get-PatLibraryChildItem [-ServerUri <String>] [-Path <String>] [-SectionName <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Get-PatLibraryChildItem [-ServerUri <String>] [-Path <String>] [-SectionId <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Browses the filesystem on the Plex server, listing subdirectories and files
at a specified path.
Uses the Plex internal browse service endpoint.

## EXAMPLES

### EXAMPLE 1
```
Get-PatLibraryChildItem -ServerUri "http://plex.example.com:32400" -Path "/mnt/media"
```

Lists directories and files under /mnt/media

### EXAMPLE 2
```
Get-PatLibraryChildItem
```

Lists root-level paths from the default stored server

### EXAMPLE 3
```
Get-PatLibraryChildItem -Path "/mnt/smb/nas5/movies"
```

Lists all items (directories and files) under the movies path

## PARAMETERS

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

### -Path
The absolute filesystem path to browse (e.g., /mnt/media, /var/lib/plexmediaserver)
If omitted, lists root-level accessible paths.

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

### -SectionId
{{ Fill SectionId Description }}

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

### -SectionName
{{ Fill SectionName Description }}

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
