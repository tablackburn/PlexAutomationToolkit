function Get-PatToken {
    <#
    .SYNOPSIS
        Displays instructions for obtaining a Plex authentication token.

    .DESCRIPTION
        Provides guidance on how to retrieve your Plex authentication token (X-Plex-Token)
        from your Plex account. This token is required for authenticated API access to
        Plex servers that require authentication.

        Note: Local network access may work without authentication if your server is
        configured to allow it. See https://support.plex.tv/articles/200890058 for details.

    .PARAMETER ShowInstructions
        If specified, displays detailed step-by-step instructions

    .EXAMPLE
        Get-PatToken
        Displays quick instructions for finding your Plex token

    .EXAMPLE
        Get-PatToken -ShowInstructions
        Displays detailed step-by-step instructions with multiple methods

    .NOTES
        Security Warning: Plex tokens provide full access to your Plex account.
        - Never share your token publicly
        - PlexAutomationToolkit stores tokens in PLAINTEXT in servers.json
        - Only use on trusted systems with appropriate file permissions

    .LINK
        https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $ShowInstructions
    )

    $quickInstructions = @"

HOW TO FIND YOUR PLEX TOKEN
============================

Method 1 - Via Plex Web App (Recommended):
1. Open Plex Web App at https://app.plex.tv
2. Open any media item (movie, show, etc.)
3. Click the three-dot menu (...) and select "Get Info"
4. Click "View XML" at the bottom
5. Look for "X-Plex-Token" in the URL
6. Copy the value after X-Plex-Token= (this is your token)

Method 2 - Via Server Settings:
1. Open Plex Web App
2. Go to Settings > Account
3. Right-click the page and select "View Page Source"
4. Search for "X-Plex-Token" in the source
5. Copy the token value

USING YOUR TOKEN
=================

Add server with authentication:

    Add-PatServer -Name "MyServer" -ServerUri "http://plex.local:32400" ``
                  -Token "YOUR_TOKEN_HERE" -Default

SECURITY WARNING
================

Your Plex token provides FULL ACCESS to your Plex account.

- PlexAutomationToolkit stores tokens in PLAINTEXT in servers.json
- Never share your token or commit it to source control
- Only use on trusted systems
- If compromised, change your Plex password to invalidate all tokens

For detailed instructions, run: Get-PatToken -ShowInstructions
Official guide: https://support.plex.tv/articles/204059436

"@

    $detailedInstructions = @"

HOW TO OBTAIN YOUR PLEX AUTHENTICATION TOKEN
=============================================

METHOD 1: WEB APP (RECOMMENDED)
--------------------------------

1. Navigate to https://app.plex.tv in your web browser
2. Sign in to your Plex account if not already signed in
3. Click on any library (Movies, TV Shows, etc.)
4. Select any media item (movie, episode, album, etc.)
5. Click the three-dot menu (...) button
6. Select "Get Info"
7. Scroll to the bottom and click "View XML"
8. The browser will navigate to an XML page
9. Look at the URL in the address bar
10. Find the parameter "X-Plex-Token=..." in the URL
11. Copy the value after the equals sign (this is your token)

Example URL:
https://app.plex.tv/...&X-Plex-Token=ABC123xyz456

Your token would be: ABC123xyz456


METHOD 2: BROWSER DEVELOPER TOOLS
----------------------------------

1. Navigate to https://app.plex.tv
2. Sign in to your Plex account
3. Open browser Developer Tools (press F12)
4. Go to the "Network" tab
5. Click on any library or media item
6. Look at the network requests
7. Find requests to plex.tv or your Plex server
8. Check request headers for "X-Plex-Token"
9. Copy the token value


METHOD 3: SERVER LOGS (If you have server access)
--------------------------------------------------

1. Locate Plex Media Server logs directory:
   - Windows: %LOCALAPPDATA%\Plex Media Server\Logs
   - Linux: /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Logs
   - macOS: ~/Library/Logs/Plex Media Server

2. Open the most recent "Plex Media Server.log" file
3. Search for "X-Plex-Token"
4. Copy the token value from log entries


USING YOUR TOKEN
================

Once you have your token, add it to a server configuration:

    Add-PatServer -Name "MyServer" -ServerUri "http://plex.local:32400" ``
                  -Token "YOUR_TOKEN_HERE" -Default

Or update an existing server:

    # Remove old server
    Remove-PatServer -Name "MyServer"

    # Re-add with token
    Add-PatServer -Name "MyServer" -ServerUri "http://plex.local:32400" ``
                  -Token "YOUR_TOKEN_HERE" -Default


WHEN IS AUTHENTICATION REQUIRED?
=================================

Plex servers can be configured to allow unauthenticated access from the local network.
If your server allows this, you may not need a token for local access.

See: https://support.plex.tv/articles/200890058

However, tokens are required for:
- Remote access (outside your local network)
- Servers configured to require authentication
- Accessing shared servers


SECURITY CONSIDERATIONS
=======================

IMPORTANT SECURITY WARNINGS:

[PLAINTEXT STORAGE]
PlexAutomationToolkit stores your token in PLAINTEXT in:
- Windows: %USERPROFILE%\Documents\PlexAutomationToolkit\servers.json
- Or: %OneDrive%\Documents\PlexAutomationToolkit\servers.json

[FULL ACCOUNT ACCESS]
Your Plex token grants COMPLETE access to your Plex account, including:
- All libraries and media
- Server settings and configuration
- User management
- Sharing and permissions

[BEST PRACTICES]
- Only use tokens on systems you trust
- Ensure servers.json has appropriate file permissions
- Never commit servers.json to source control
- Never share your token in support requests or public forums
- Regenerate your token if you suspect it's been compromised

[TOKEN REVOCATION]
To revoke a token:
1. Sign in to https://app.plex.tv
2. Go to Settings > Authorized Devices
3. Remove devices you no longer recognize
4. Or change your Plex account password (invalidates all tokens)


ADDITIONAL RESOURCES
====================

Official Plex Documentation:
https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/

Local Network Authentication:
https://support.plex.tv/articles/200890058-authentication-for-local-network-access/

"@

    if ($ShowInstructions) {
        Write-Output $detailedInstructions
    }
    else {
        Write-Output $quickInstructions
    }
}
