function Remove-PatServerToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Internal helper called by public functions that implement ShouldProcess'
    )]
    <#
    .SYNOPSIS
        Removes an authentication token for a server from the vault.

    .DESCRIPTION
        Internal helper function that removes a Plex authentication token from the
        SecretManagement vault. Called when removing a server configuration to clean
        up any stored secrets.

    .PARAMETER ServerName
        The name of the server whose token should be removed.

    .EXAMPLE
        Remove-PatServerToken -ServerName 'Home'
        Removes the token for 'Home' server from the vault if it exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerName
    )

    $secretName = "PlexAutomationToolkit/$ServerName"

    if (Get-PatSecretManagementAvailable) {
        try {
            # Check if secret exists using Get-SecretInfo (doesn't expose the actual secret)
            $secretInformation = Get-SecretInfo -Name $secretName -ErrorAction SilentlyContinue
            if ($secretInformation) {
                Remove-Secret -Name $secretName -ErrorAction Stop
                Write-Debug "Removed token from vault for server '$ServerName'"
            }
            else {
                Write-Debug "No token in vault for server '$ServerName'"
            }
        }
        catch {
            Write-Warning "Failed to remove token from vault: $($_.Exception.Message)"
        }
    }
    else {
        Write-Debug "SecretManagement not available - no vault token to remove for '$ServerName'"
    }
}
