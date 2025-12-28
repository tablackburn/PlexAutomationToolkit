function Get-PatSecretManagementAvailable {
    <#
    .SYNOPSIS
        Checks if SecretManagement module is available and configured.

    .DESCRIPTION
        Internal helper function that determines whether the Microsoft.PowerShell.SecretManagement
        module is installed and at least one secret vault is registered. Used to determine
        whether tokens can be stored securely.

    .OUTPUTS
        Boolean
        Returns $true if SecretManagement is available with a registered vault, $false otherwise.

    .EXAMPLE
        if (Get-PatSecretManagementAvailable) {
            # Store token in vault
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    try {
        # Check if module is available
        $module = Get-Module -ListAvailable -Name 'Microsoft.PowerShell.SecretManagement' -ErrorAction SilentlyContinue
        if (-not $module) {
            Write-Debug "SecretManagement module not installed"
            return $false
        }

        # Import module if not already loaded
        if (-not (Get-Module -Name 'Microsoft.PowerShell.SecretManagement')) {
            Import-Module -Name 'Microsoft.PowerShell.SecretManagement' -ErrorAction Stop
        }

        # Check if any vault is registered
        $vaults = Get-SecretVault -ErrorAction SilentlyContinue
        if (-not $vaults -or $vaults.Count -eq 0) {
            Write-Debug "No secret vaults registered"
            return $false
        }

        Write-Debug "SecretManagement available with $($vaults.Count) vault(s)"
        return $true
    }
    catch {
        Write-Debug "SecretManagement check failed: $($_.Exception.Message)"
        return $false
    }
}
