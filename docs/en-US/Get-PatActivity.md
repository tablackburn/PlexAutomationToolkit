---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatActivity

## SYNOPSIS
Retrieves current activities from a Plex server.

## SYNTAX

```
Get-PatActivity [[-Type] <String>] [[-SectionId] <Int32>] [[-ServerUri] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets a list of ongoing activities on the Plex server, such as library
scans, media optimization, and other background tasks.
This is useful
for monitoring the progress of operations like library refreshes.

## EXAMPLES

### EXAMPLE 1
```
Get-PatActivity
```

Retrieves all current activities from the default Plex server.

### EXAMPLE 2
```
Get-PatActivity -Type 'library.update.section'
```

Retrieves only library scan activities.

### EXAMPLE 3
```
Get-PatActivity -SectionId 2
```

Retrieves activities for library section 2.

### EXAMPLE 4
```
Get-PatActivity -Type 'library.update.section' -SectionId 2
```

Retrieves library scan activities for section 2 only.

### EXAMPLE 5
```
while ($scan = Get-PatActivity -SectionId 2 -Type 'library.update.section') {
    Write-Progress -Activity $scan.Title -PercentComplete $scan.Progress
    Start-Sleep -Seconds 2
}
Write-Host "Scan complete!"
```

Monitors a library scan until it completes.

## PARAMETERS

### -Type
Optional filter for activity type.
Common types include:
- library.update.section (library scanning)
- media.optimize (media optimization)

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
Optional filter to show only activities for a specific library section.
Only applies to library-related activities.

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

### -ServerUri
The base URI of the Plex server (e.g., http://plex.example.com:32400)
If not specified, uses the default stored server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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

### PSCustomObject with properties:
### - ActivityId: Unique identifier for the activity
### - Type: Activity type (e.g., library.update.section)
### - Title: Human-readable title
### - Subtitle: Current item being processed
### - Progress: Completion percentage (0-100)
### - SectionId: Library section ID (for library activities)
### - Cancellable: Whether the activity can be cancelled
### - UserStopped: Whether a user requested cancellation
## NOTES

## RELATED LINKS
