function Test-IntegrationPrerequisites {
    <#
    .SYNOPSIS
        Checks if integration test prerequisites are met

    .DESCRIPTION
        Verifies that required environment variables (PLEX_SERVER_URI and PLEX_TOKEN)
        are set for integration testing.

    .OUTPUTS
        Boolean
        Returns $true if prerequisites are met, $false otherwise
    #>
    [CmdletBinding()]
    param()

    $hasUri = -not [string]::IsNullOrWhiteSpace($env:PLEX_SERVER_URI)
    $hasToken = -not [string]::IsNullOrWhiteSpace($env:PLEX_TOKEN)

    return ($hasUri -and $hasToken)
}

function Get-IntegrationTestContext {
    <#
    .SYNOPSIS
        Returns integration test configuration context

    .DESCRIPTION
        Retrieves the current integration test configuration from environment variables
        and returns it as a structured object.

    .OUTPUTS
        PSCustomObject
        Returns an object with integration test configuration
    #>
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        ServerUri       = $env:PLEX_SERVER_URI
        Token           = $env:PLEX_TOKEN
        TestSectionId   = $env:PLEX_TEST_SECTION_ID
        TestSectionName = $env:PLEX_TEST_SECTION_NAME
        AllowMutations  = ($env:PLEX_ALLOW_MUTATIONS -eq 'true')
    }
}

function Invoke-IntegrationTestWithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic for transient failures

    .DESCRIPTION
        Wraps a script block with retry logic to handle transient network failures
        or temporary server unavailability during integration testing.

    .PARAMETER ScriptBlock
        The script block to execute

    .PARAMETER MaxAttempts
        Maximum number of retry attempts (default: 3)

    .PARAMETER DelaySeconds
        Delay in seconds between retry attempts (default: 2)

    .OUTPUTS
        Object
        Returns the output of the script block

    .EXAMPLE
        Invoke-IntegrationTestWithRetry {
            Get-PatServer -ServerUri $env:PLEX_SERVER_URI
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$MaxAttempts = 3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 30)]
        [int]$DelaySeconds = 2
    )

    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Write-Verbose "Attempt $attempt failed, retrying in $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Get-IntegrationConfigPath {
    <#
    .SYNOPSIS
        Gets the configuration file path for integration tests

    .DESCRIPTION
        Determines the configuration file path using the same logic as Get-PatConfigPath.
        This is a helper to avoid calling private module functions.

    .OUTPUTS
        String
        Returns the path to the servers.json configuration file
    #>
    [CmdletBinding()]
    param()

    # Try OneDrive location first
    if ($env:OneDrive) {
        $configPath = Join-Path $env:OneDrive 'Documents\PlexAutomationToolkit\servers.json'
        $configDir = Split-Path $configPath -Parent

        if ((Test-Path $configDir) -or (Test-Path $configPath)) {
            return $configPath
        }
    }

    # Fallback to user Documents
    $configPath = Join-Path $env:USERPROFILE 'Documents\PlexAutomationToolkit\servers.json'
    $configDir = Split-Path $configPath -Parent

    if ((Test-Path $configDir) -or (Test-Path $configPath)) {
        return $configPath
    }

    # Last resort: LocalAppData
    $configPath = Join-Path $env:LOCALAPPDATA 'PlexAutomationToolkit\servers.json'
    return $configPath
}

function Backup-ServerConfiguration {
    <#
    .SYNOPSIS
        Backs up current server configuration before integration tests

    .DESCRIPTION
        Creates a backup copy of the servers.json configuration file.
        Returns the path to the backup file for later restoration.

    .OUTPUTS
        String
        Returns the path to the backup file, or $null if no config exists
    #>
    [CmdletBinding()]
    param()

    $configPath = Get-IntegrationConfigPath

    if (Test-Path $configPath) {
        $backupPath = "$configPath.integration-backup"
        Copy-Item -Path $configPath -Destination $backupPath -Force
        Write-Verbose "Server configuration backed up to: $backupPath"
        return $backupPath
    }

    Write-Verbose "No server configuration found to backup"
    return $null
}

function Restore-ServerConfiguration {
    <#
    .SYNOPSIS
        Restores server configuration after integration tests

    .DESCRIPTION
        Restores the servers.json configuration file from a backup and removes the backup.

    .PARAMETER BackupPath
        Path to the backup file to restore from

    .EXAMPLE
        Restore-ServerConfiguration -BackupPath $backupPath
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BackupPath
    )

    if ($BackupPath -and (Test-Path $BackupPath)) {
        $configPath = Get-IntegrationConfigPath
        Copy-Item -Path $BackupPath -Destination $configPath -Force
        Remove-Item -Path $BackupPath -Force
        Write-Verbose "Server configuration restored from: $BackupPath"
    }
    else {
        Write-Verbose "No backup file to restore"
    }
}

function Remove-IntegrationTestServers {
    <#
    .SYNOPSIS
        Removes all integration test servers from configuration

    .DESCRIPTION
        Removes any server entries with "IntegrationTest-" prefix from the configuration.
        This is used in AfterAll blocks to ensure cleanup even if tests fail.

    .EXAMPLE
        Remove-IntegrationTestServers
    #>
    [CmdletBinding()]
    param()

    try {
        $servers = Get-PatStoredServer -ErrorAction SilentlyContinue
        if ($servers) {
            $testServers = $servers | Where-Object { $_.name -like 'IntegrationTest-*' }
            foreach ($server in $testServers) {
                Remove-PatServer -Name $server.name -Confirm:$false -ErrorAction SilentlyContinue
                Write-Verbose "Removed integration test server: $($server.name)"
            }
        }
    }
    catch {
        Write-Warning "Failed to clean up integration test servers: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Test-IntegrationPrerequisites, Get-IntegrationTestContext, `
    Get-IntegrationConfigPath, Invoke-IntegrationTestWithRetry, Backup-ServerConfiguration, `
    Restore-ServerConfiguration, Remove-IntegrationTestServers
