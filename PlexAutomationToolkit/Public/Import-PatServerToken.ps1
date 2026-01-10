function Import-PatServerToken {
    <#
    .SYNOPSIS
        Migrates plaintext tokens to SecretManagement vault.

    .DESCRIPTION
        Scans server configurations for plaintext tokens stored in servers.json and migrates
        them to a SecretManagement vault for secure storage. After successful migration,
        removes the plaintext token from the configuration file.

        Requires Microsoft.PowerShell.SecretManagement module to be installed and at least
        one vault to be registered.

    .PARAMETER ServerName
        Optional name of a specific server to migrate. If not specified, migrates all servers
        with plaintext tokens.

    .PARAMETER PassThru
        Returns migration result objects showing the status of each server.

    .EXAMPLE
        Import-PatServerToken

        Migrates all plaintext tokens to the vault.

    .EXAMPLE
        Import-PatServerToken -ServerName 'Home'

        Migrates only the 'Home' server's token to the vault.

    .EXAMPLE
        Import-PatServerToken -PassThru

        Migrates all tokens and returns status objects for each server.

    .EXAMPLE
        Import-PatServerToken -WhatIf

        Shows which tokens would be migrated without making changes.

    .OUTPUTS
        PlexAutomationToolkit.TokenMigrationResult (with -PassThru)

        Objects with properties:
        - ServerName: Name of the server
        - Status: 'Migrated', 'Skipped', or 'Failed'
        - Message: Description of the result

    .NOTES
        Before running this command, ensure you have:
        1. Installed Microsoft.PowerShell.SecretManagement: Install-Module Microsoft.PowerShell.SecretManagement
        2. Installed a vault extension (e.g., SecretStore): Install-Module Microsoft.PowerShell.SecretStore
        3. Registered the vault: Register-SecretVault -Name 'SecretStore' -ModuleName Microsoft.PowerShell.SecretStore
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        # Check vault availability
        if (-not (Get-PatSecretManagementAvailable)) {
            throw "SecretManagement is not available. Install Microsoft.PowerShell.SecretManagement and register a vault first. See help for Import-PatServerToken for setup instructions."
        }
    }

    process {
        try {
            $configuration = Get-PatServerConfiguration -ErrorAction Stop
            $results = @()
            $modified = $false

            # Determine which servers to process
            $serversToMigrate = if ($ServerName) {
                $server = $configuration.servers | Where-Object { $_.name -eq $ServerName }
                if (-not $server) {
                    throw "Server '$ServerName' not found in configuration"
                }
                @($server)
            }
            else {
                @($configuration.servers)
            }

            foreach ($server in $serversToMigrate) {
                # Check if server has a plaintext token
                if (-not ($server.PSObject.Properties['token'] -and
                        -not [string]::IsNullOrWhiteSpace($server.token))) {

                    # Check if already in vault
                    if ($server.PSObject.Properties['tokenInVault'] -and $server.tokenInVault) {
                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.TokenMigrationResult'
                            ServerName = $server.name
                            Status     = 'Skipped'
                            Message    = 'Token already stored in vault'
                        }
                    }
                    else {
                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.TokenMigrationResult'
                            ServerName = $server.name
                            Status     = 'Skipped'
                            Message    = 'No plaintext token to migrate'
                        }
                    }
                    continue
                }

                if ($PSCmdlet.ShouldProcess($server.name, 'Migrate token to vault')) {
                    try {
                        $secretName = "PlexAutomationToolkit/$($server.name)"
                        Set-Secret -Name $secretName -Secret $server.token -ErrorAction Stop

                        # Remove inline token and add vault flag
                        $server.PSObject.Properties.Remove('token')
                        if (-not $server.PSObject.Properties['tokenInVault']) {
                            $server | Add-Member -NotePropertyName 'tokenInVault' -NotePropertyValue $true
                        }
                        else {
                            $server.tokenInVault = $true
                        }
                        $modified = $true

                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.TokenMigrationResult'
                            ServerName = $server.name
                            Status     = 'Migrated'
                            Message    = 'Token successfully moved to vault'
                        }

                        Write-Verbose "Migrated token for '$($server.name)' to vault"
                    }
                    catch {
                        $results += [PSCustomObject]@{
                            PSTypeName = 'PlexAutomationToolkit.TokenMigrationResult'
                            ServerName = $server.name
                            Status     = 'Failed'
                            Message    = $_.Exception.Message
                        }
                        Write-Warning "Failed to migrate '$($server.name)': $($_.Exception.Message)"
                    }
                }
            }

            # Save configuration if modified
            if ($modified) {
                Set-PatServerConfiguration -Configuration $configuration -ErrorAction Stop
                Write-Verbose "Updated configuration file to remove migrated plaintext tokens"
            }

            if ($PassThru) {
                $results
            }

            # Summary
            $migratedCount = ($results | Where-Object { $_.Status -eq 'Migrated' }).Count
            $skippedCount = ($results | Where-Object { $_.Status -eq 'Skipped' }).Count
            $failedCount = ($results | Where-Object { $_.Status -eq 'Failed' }).Count

            if ($migratedCount -gt 0) {
                Write-Verbose "Migration complete: $migratedCount migrated, $skippedCount skipped, $failedCount failed"
            }
        }
        catch {
            throw "Failed to migrate tokens: $($_.Exception.Message)"
        }
    }
}
