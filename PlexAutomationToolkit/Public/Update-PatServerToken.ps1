function Update-PatServerToken {
    <#
    .SYNOPSIS
        Refreshes the authentication token for a stored Plex server.

    .DESCRIPTION
        Updates the Plex authentication token for a stored server configuration.
        This is the recommended way to fix expired or invalid tokens without
        removing and re-adding the server.

        When called without -Token, performs interactive PIN authentication via
        Connect-PatAccount. When -Token is provided, uses the supplied token
        directly (useful for automation or CI scenarios).

        After storing the new token, verifies it by calling the Plex API root
        endpoint and reports the result.

    .PARAMETER Name
        The name of the stored server to update. If not specified, uses the
        default server configured via Add-PatServer -Default.

    .PARAMETER Token
        A Plex authentication token to use directly. When provided, skips the
        interactive PIN authentication flow. Obtain a token via Connect-PatAccount
        or from Plex account settings.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for interactive PIN authorization in seconds
        (default: 300 / 5 minutes). Only applies when -Token is not provided.

    .PARAMETER Force
        Suppresses interactive prompts during PIN authentication. When specified,
        automatically opens the browser to the Plex authentication page.

    .EXAMPLE
        Update-PatServerToken

        Refreshes the token for the default server using interactive PIN
        authentication. Opens a browser to plex.tv/link for authorization.

    .EXAMPLE
        Update-PatServerToken -Name 'MyServer'

        Refreshes the token for the server named 'MyServer' using interactive
        PIN authentication.

    .EXAMPLE
        Update-PatServerToken -Name 'MyServer' -Token $newToken

        Updates the token for 'MyServer' using a pre-obtained token, skipping
        the interactive authentication flow.

    .EXAMPLE
        Update-PatServerToken -Force

        Refreshes the default server token non-interactively, automatically
        opening the browser for PIN authorization.

    .OUTPUTS
        PSCustomObject
        Returns an object with the following properties:
        - ServerName: The name of the updated server
        - TokenUpdated: Whether the token was successfully stored
        - Verified: Whether the new token was verified against the Plex API
        - StorageType: Where the token is stored ('Vault' or 'Inline')

    .NOTES
        If Microsoft.PowerShell.SecretManagement is installed with a registered
        vault, the new token is stored securely in the vault. Otherwise, the
        token is stored in plaintext in servers.json.

    .LINK
        Connect-PatAccount

    .LINK
        Test-PatServer

    .LINK
        Add-PatServer
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1800)]
        [int]
        $TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )

    try {
        # Resolve target server
        if ($Name) {
            $server = Get-PatStoredServer -Name $Name -ErrorAction 'Stop'
        }
        else {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
        }

        $serverName = $server.name
        Write-Verbose "Updating token for server '$serverName'"

        # Obtain token
        $newToken = $Token
        if (-not $newToken) {
            Write-Verbose "No token provided, starting interactive PIN authentication"
            $newToken = Connect-PatAccount -TimeoutSeconds $TimeoutSeconds -Force:$Force
        }

        if ($PSCmdlet.ShouldProcess($serverName, 'Update authentication token')) {
            # Store the new token
            $storageResult = Set-PatServerToken -ServerName $serverName -Token $newToken

            # Update the server configuration entry
            $configuration = Get-PatServerConfiguration -ErrorAction 'Stop'
            $serverEntry = $configuration.servers | Where-Object { $_.name -eq $serverName }

            if ($storageResult.StorageType -eq 'Vault') {
                # Remove inline token if present, set vault flag
                if ($serverEntry.PSObject.Properties['token']) {
                    $serverEntry.PSObject.Properties.Remove('token')
                }
                if ($serverEntry.PSObject.Properties['tokenInVault']) {
                    $serverEntry.tokenInVault = $true
                }
                else {
                    $serverEntry | Add-Member -NotePropertyName 'tokenInVault' -NotePropertyValue $true
                }
            }
            else {
                # Store inline token, remove vault flag if present
                if ($serverEntry.PSObject.Properties['token']) {
                    $serverEntry.token = $storageResult.Token
                }
                else {
                    $serverEntry | Add-Member -NotePropertyName 'token' -NotePropertyValue $storageResult.Token
                }
                if ($serverEntry.PSObject.Properties['tokenInVault']) {
                    $serverEntry.PSObject.Properties.Remove('tokenInVault')
                }
            }

            Set-PatServerConfiguration -Configuration $configuration -ErrorAction 'Stop'
            Write-Verbose "Token stored successfully (StorageType: $($storageResult.StorageType))"

            # Verify the new token works
            $verified = $false
            try {
                $verificationUri = Join-PatUri -BaseUri $server.uri -Endpoint '/'
                $verificationHeaders = @{ Accept = 'application/json' }
                $verificationHeaders['X-Plex-Token'] = $newToken
                $null = Invoke-PatApi -Uri $verificationUri -Headers $verificationHeaders -ErrorAction 'Stop'
                $verified = $true
                Write-Verbose "Token verification successful for server '$serverName'"
            }
            catch {
                Write-Warning "Token was stored but verification failed: $($_.Exception.Message)"
            }

            [PSCustomObject]@{
                ServerName   = $serverName
                TokenUpdated = $true
                Verified     = $verified
                StorageType  = $storageResult.StorageType
            }
        }
    }
    catch {
        throw "Failed to update server token: $($_.Exception.Message)"
    }
}
