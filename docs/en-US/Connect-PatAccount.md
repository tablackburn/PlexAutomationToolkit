---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Connect-PatAccount

## SYNOPSIS
Authenticates with Plex and retrieves an authentication token.

## SYNTAX

```
Connect-PatAccount [[-TimeoutSeconds] <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Performs interactive authentication with Plex using the PIN/OAuth flow.
This cmdlet guides you through the authentication process and returns
a token that can be used with Add-PatServer.

The PIN flow works by:
1.
Requesting a PIN code from Plex
2.
Displaying the code and URL (plex.tv/link)
3.
Waiting for you to authorize the PIN in your browser
4.
Returning your authentication token

This is the same secure flow used by Plex apps on TVs and streaming devices.

## EXAMPLES

### EXAMPLE 1
```
Connect-PatAccount
```

Starts PIN authentication with default 5-minute timeout.
Displays a PIN code
that you enter at plex.tv/link to authenticate.

### EXAMPLE 2
```
$token = Connect-PatAccount
Add-PatServer -Name "Main" -ServerUri "http://plex:32400" -Token $token
```

Authenticates and uses the returned token to add a server configuration.

### EXAMPLE 3
```
Connect-PatAccount -TimeoutSeconds 600
```

Starts PIN authentication with 10-minute timeout for slower authentication.

## PARAMETERS

### -TimeoutSeconds
Maximum time to wait for authorization in seconds (default: 300 / 5 minutes).
If you don't authorize the PIN within this time, authentication will fail.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 300
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

### System.String
### Returns the Plex authentication token (X-Plex-Token)
## NOTES
This cmdlet requires internet connectivity to communicate with plex.tv.
You must be able to access plex.tv in a web browser to complete authentication.

The returned token provides full access to your Plex account.
Store it securely
and only use it on trusted systems.

## RELATED LINKS

[Add-PatServer]()

