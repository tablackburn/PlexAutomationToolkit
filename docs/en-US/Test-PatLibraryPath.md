---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Test-PatLibraryPath

## SYNOPSIS
Tests whether a path exists on the Plex server's filesystem.

## SYNTAX

### PathOnly (Default)
```
Test-PatLibraryPath [-Path] <String> [-ServerName <String>] [-ServerUri <String>] [-Token <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByName
```
Test-PatLibraryPath [-Path] <String> [-SectionName <String>] [-ServerName <String>] [-ServerUri <String>]
 [-Token <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ById
```
Test-PatLibraryPath [-Path] <String> [-SectionId <Int32>] [-ServerName <String>] [-ServerUri <String>]
 [-Token <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Validates that a specified filesystem path exists and is accessible
to the Plex server.
Optionally validates that the path falls within
a library section's configured root paths.

This cmdlet is useful for pre-validating paths before calling
Update-PatLibrary to ensure the path exists and will be scanned.

## EXAMPLES

### EXAMPLE 1
```
Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie'
```

Tests whether the path exists on the Plex server.

### EXAMPLE 2
```
Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionName 'Movies'
```

Tests whether the path exists AND is under one of the Movies library's
configured root paths.

### EXAMPLE 3
```
if (Test-PatLibraryPath -Path $path -SectionName 'Movies') {
    Update-PatLibrary -SectionName 'Movies' -Path $path
}
```

Pre-validates a path before triggering a library scan.

### EXAMPLE 4
```
Test-PatLibraryPath -Path '/mnt/wrong/path' -ErrorAction Stop
```

Throws an error if the path doesn't exist, useful in scripts.

## PARAMETERS

### -Path
The absolute filesystem path to test (e.g., /mnt/media/Movies/NewMovie).

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

### -SectionName
Optional library section name (e.g., "Movies").
When provided, also
validates that the path is under one of the section's configured root paths.

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
Optional library section ID.
When provided, also validates that the
path is under one of the section's configured root paths.

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

### System.Boolean
## NOTES
Returns $true if the path exists (and optionally is within library bounds).
Returns $false if the path doesn't exist or is outside library bounds.
Use -ErrorAction Stop to throw on validation failure instead of returning $false.

## RELATED LINKS
