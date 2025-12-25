---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Get-PatToken

## SYNOPSIS
Displays instructions for obtaining a Plex authentication token.

## SYNTAX

```
Get-PatToken [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Provides guidance on how to retrieve your Plex authentication token (X-Plex-Token) from your Plex account.
This token is required for authenticated API access to Plex servers that require authentication.

Note: Local network access may work without authentication if your server is configured to allow it.
See https://support.plex.tv/articles/200890058 for details.

## EXAMPLES

### EXAMPLE 1
```
Get-PatToken
```

Displays quick instructions for finding your Plex token

### EXAMPLE 2
```
Get-PatToken -ShowInstructions
```

Displays detailed step-by-step instructions with multiple methods

## PARAMETERS

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

### None
## OUTPUTS

### System.String
## NOTES
Security Warning: Plex tokens provide full access to your Plex account.
- Never share your token publicly
- PlexAutomationToolkit stores tokens in PLAINTEXT in servers.json
- Only use on trusted systems with appropriate file permissions

## RELATED LINKS

[https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)
