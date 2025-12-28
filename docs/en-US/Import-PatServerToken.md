---
external help file: PlexAutomationToolkit-help.xml
Module Name: PlexAutomationToolkit
online version:
schema: 2.0.0
---

# Import-PatServerToken

## SYNOPSIS
Migrates plaintext tokens to SecretManagement vault.

## SYNTAX

```
Import-PatServerToken [[-ServerName] <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Scans server configurations for plaintext tokens stored in servers.json and migrates
them to a SecretManagement vault for secure storage.
After successful migration,
removes the plaintext token from the configuration file.

Requires Microsoft.PowerShell.SecretManagement module to be installed and at least
one vault to be registered.

## EXAMPLES

### EXAMPLE 1
```
Import-PatServerToken
```

Migrates all plaintext tokens to the vault.

### EXAMPLE 2
```
Import-PatServerToken -ServerName 'Home'
```

Migrates only the 'Home' server's token to the vault.

### EXAMPLE 3
```
Import-PatServerToken -PassThru
```

Migrates all tokens and returns status objects for each server.

### EXAMPLE 4
```
Import-PatServerToken -WhatIf
```

Shows which tokens would be migrated without making changes.

## PARAMETERS

### -ServerName
Optional name of a specific server to migrate.
If not specified, migrates all servers
with plaintext tokens.

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

### -PassThru
Returns migration result objects showing the status of each server.

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

### PlexAutomationToolkit.TokenMigrationResult (with -PassThru)
### Objects with properties:
### - ServerName: Name of the server
### - Status: 'Migrated', 'Skipped', or 'Failed'
### - Message: Description of the result
## NOTES
Before running this command, ensure you have:
1.
Installed Microsoft.PowerShell.SecretManagement: Install-Module Microsoft.PowerShell.SecretManagement
2.
Installed a vault extension (e.g., SecretStore): Install-Module Microsoft.PowerShell.SecretStore
3.
Registered the vault: Register-SecretVault -Name 'SecretStore' -ModuleName Microsoft.PowerShell.SecretStore

## RELATED LINKS
