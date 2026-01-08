function Set-PatServerToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Internal helper called by public functions that implement ShouldProcess'
    )]
    <#
    .SYNOPSIS
        Stores an authentication token for a server.

    .DESCRIPTION
        Internal helper function that stores a Plex authentication token for a server.
        Attempts to store in SecretManagement vault if available, otherwise falls back
        to inline storage with a warning about plaintext storage.

    .PARAMETER ServerName
        The name of the server.

    .PARAMETER Token
        The authentication token to store.

    .PARAMETER Force
        Force inline storage even if vault is available.

    .OUTPUTS
        PSCustomObject
        Returns an object with StorageType ('Vault' or 'Inline') and Token properties.
        Token is $null for vault storage, contains the token for inline storage.

    .EXAMPLE
        $result = Set-PatServerToken -ServerName 'Home' -Token 'abc123'
        if ($result.StorageType -eq 'Vault') {
            # Token stored securely
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    $secretName = "PlexAutomationToolkit/$ServerName"

    if (-not $Force -and (Get-PatSecretManagementAvailable)) {
        try {
            Set-Secret -Name $secretName -Secret $Token -ErrorAction Stop
            Write-Debug "Stored token in vault for server '$ServerName'"
            return [PSCustomObject]@{
                StorageType = 'Vault'
                Token       = $null
            }
        }
        catch {
            Write-Warning "Failed to store token in vault: $($_.Exception.Message). Falling back to plaintext storage."
        }
    }

    # Vault not available or failed - warn about plaintext
    if (-not $Force) {
        Write-Warning "SecretManagement not available or vault storage failed. Token will be stored in PLAINTEXT in servers.json. Install Microsoft.PowerShell.SecretManagement and register a vault for secure storage."
    }

    return [PSCustomObject]@{
        StorageType = 'Inline'
        Token       = $Token
    }
}
