---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Compare-PatWatchStatus

## SYNOPSIS
Compares watch status between two Plex servers.

## SYNTAX

```
Compare-PatWatchStatus [-SourceServerName] <String> [-TargetServerName] <String> [[-SectionId] <Int32[]>]
 [-WatchedOnSourceOnly] [-WatchedOnTargetOnly] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries both source and target Plex servers and identifies items with different
watch status.
Matches items by title and year for movies, and by show name,
season, and episode number for TV episodes.

## EXAMPLES

### EXAMPLE 1
```
Compare-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home'
```

Compares watch status between the Travel and Home servers.

### EXAMPLE 2
```
Compare-PatWatchStatus -SourceServerName 'Travel' -TargetServerName 'Home' -WatchedOnSourceOnly
```

Shows items watched on Travel server but not on Home server.

## PARAMETERS

### -SourceServerName
The name of the source server (as stored with Add-PatServer).

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

### -TargetServerName
The name of the target server (as stored with Add-PatServer).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SectionId
Optional array of library section IDs to compare.
If not specified, compares all sections.

```yaml
Type: Int32[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WatchedOnSourceOnly
When specified, only returns items that are watched on source but not on target.

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

### -WatchedOnTargetOnly
When specified, only returns items that are watched on target but not on source.

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

### PlexAutomationToolkit.WatchStatusDiff
### Objects with properties:
### - Title: Item title
### - Type: 'movie' or 'episode'
### - Year: Release year (movies)
### - ShowName: Series name (episodes)
### - Season: Season number (episodes)
### - Episode: Episode number (episodes)
### - SourceWatched: Whether watched on source server
### - TargetWatched: Whether watched on target server
### - SourceViewCount: View count on source
### - TargetViewCount: View count on target
### - SourceRatingKey: Rating key on source server
### - TargetRatingKey: Rating key on target server
## NOTES

## RELATED LINKS
