function Connect-PatAccount {
    <#
    .SYNOPSIS
        Authenticates with Plex and retrieves an authentication token.

    .DESCRIPTION
        Performs interactive authentication with Plex using the PIN/OAuth flow.
        This cmdlet guides you through the authentication process and returns
        a token that can be used with Add-PatServer.

        The PIN flow works by:
        1. Requesting a PIN code from Plex
        2. Displaying the code and URL (plex.tv/link)
        3. Waiting for you to authorize the PIN in your browser
        4. Returning your authentication token

        This is the same secure flow used by Plex apps on TVs and streaming devices.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for authorization in seconds (default: 300 / 5 minutes).
        If you don't authorize the PIN within this time, authentication will fail.

    .EXAMPLE
        Connect-PatAccount

        Starts PIN authentication with default 5-minute timeout. Displays a PIN code
        that you enter at plex.tv/link to authenticate.

    .EXAMPLE
        $token = Connect-PatAccount
        Add-PatServer -Name "Main" -ServerUri "http://plex:32400" -Token $token

        Authenticates and uses the returned token to add a server configuration.

    .EXAMPLE
        Connect-PatAccount -TimeoutSeconds 600

        Starts PIN authentication with 10-minute timeout for slower authentication.

    .OUTPUTS
        System.String
        Returns the Plex authentication token (X-Plex-Token)

    .NOTES
        This cmdlet requires internet connectivity to communicate with plex.tv.
        You must be able to access plex.tv in a web browser to complete authentication.

        The returned token provides full access to your Plex account. Store it securely
        and only use it on trusted systems.

    .LINK
        Add-PatServer
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1800)]
        [int]
        $TimeoutSeconds = 300
    )

    try {
        $token = Invoke-PatPinAuthentication -TimeoutSeconds $TimeoutSeconds
        return $token
    }
    catch {
        throw "Failed to authenticate with Plex: $($_.Exception.Message)"
    }
}
