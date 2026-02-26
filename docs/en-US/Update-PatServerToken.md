---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Update-PatServerToken

## SYNOPSIS
Refreshes the authentication token for a stored Plex server.

## SYNTAX

```
Update-PatServerToken [[-Name] <String>] [-Token <String>] [-TimeoutSeconds <Int32>] [-Force]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Updates the Plex authentication token for a stored server configuration.
This is the recommended way to fix expired or invalid tokens without
removing and re-adding the server.

When called without -Token, performs interactive PIN authentication via
Connect-PatAccount.
When -Token is provided, uses the supplied token
directly (useful for automation or CI scenarios).

After storing the new token, verifies it by calling the Plex API root
endpoint and reports the result.

## EXAMPLES

### EXAMPLE 1
```
Update-PatServerToken
```

Refreshes the token for the default server using interactive PIN
authentication.
Opens a browser to plex.tv/link for authorization.

### EXAMPLE 2
```
Update-PatServerToken -Name 'MyServer'
```

Refreshes the token for the server named 'MyServer' using interactive
PIN authentication.

### EXAMPLE 3
```
Update-PatServerToken -Name 'MyServer' -Token $newToken
```

Updates the token for 'MyServer' using a pre-obtained token, skipping
the interactive authentication flow.

### EXAMPLE 4
```
Update-PatServerToken -Force
```

Refreshes the default server token non-interactively, automatically
opening the browser for PIN authorization.

## PARAMETERS

### -Name
The name of the stored server to update.
If not specified, uses the
default server configured via Add-PatServer -Default.

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

### -Token
A Plex authentication token to use directly.
When provided, skips the
interactive PIN authentication flow.
Obtain a token via Connect-PatAccount
or from Plex account settings.

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

### -TimeoutSeconds
Maximum time to wait for interactive PIN authorization in seconds
(default: 300 / 5 minutes).
Only applies when -Token is not provided.

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

### -Force
Suppresses interactive prompts during PIN authentication.
When specified,
automatically opens the browser to the Plex authentication page.

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

### PSCustomObject
### Returns an object with the following properties:
### - ServerName: The name of the updated server
### - TokenUpdated: Whether the token was successfully stored
### - Verified: Whether the new token was verified against the Plex API
### - StorageType: Where the token is stored ('Vault' or 'Inline')
## NOTES
If Microsoft.PowerShell.SecretManagement is installed with a registered
vault, the new token is stored securely in the vault.
Otherwise, the
token is stored in plaintext in servers.json.

## RELATED LINKS

[Connect-PatAccount]()

[Test-PatServer]()

[Add-PatServer]()

