function Get-PatToken {
    <#
    .SYNOPSIS
        Displays instructions for manually obtaining a Plex authentication token.

    .DESCRIPTION
        Provides guidance on how to manually retrieve your Plex authentication token
        (X-Plex-Token) from your Plex account.

        For most users, Connect-PatAccount is the recommended way to obtain a token
        using Plex's secure PIN authentication flow. Use Get-PatToken only when the
        PIN flow is not available (e.g., network restrictions, automation scenarios).

    .EXAMPLE
        Get-PatToken

        Displays instructions for manually finding your Plex token.

    .EXAMPLE
        $token = Connect-PatAccount
        Add-PatServer -Name "Main" -ServerUri "http://plex:32400" -Token $token

        Recommended: Use Connect-PatAccount for interactive token retrieval.

    .NOTES
        Security Warning: Plex tokens provide full access to your Plex account.
        - Never share your token publicly
        - PlexAutomationToolkit stores tokens in PLAINTEXT in servers.json
        - Only use on trusted systems with appropriate file permissions

    .LINK
        Connect-PatAccount

    .LINK
        https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
    #>
    [CmdletBinding()]
    param ()

    $instructions = @"

PLEX TOKEN RETRIEVAL
====================

RECOMMENDED: Use Connect-PatAccount for automatic token retrieval:

    `$token = Connect-PatAccount
    Add-PatServer -Name "MyServer" -ServerUri "http://plex:32400" -Token `$token


MANUAL METHOD (if Connect-PatAccount is not available)
------------------------------------------------------

1. Open https://app.plex.tv in your browser
2. Sign in to your Plex account
3. Navigate to any library and select a media item
4. Click the three-dot menu (...) and select "Get Info"
5. Click "View XML" at the bottom
6. Find "X-Plex-Token=" in the URL and copy the value after it


SECURITY WARNING
================

Your Plex token provides FULL ACCESS to your Plex account.

- Never share your token or commit it to source control
- PlexAutomationToolkit stores tokens in PLAINTEXT in servers.json
- If compromised, change your Plex password to invalidate all tokens

Official guide: https://support.plex.tv/articles/204059436

"@

    Write-Output $instructions
}
