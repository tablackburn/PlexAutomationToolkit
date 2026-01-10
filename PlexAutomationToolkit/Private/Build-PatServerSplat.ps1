function Build-PatServerSplat {
    <#
    .SYNOPSIS
        Builds a hashtable of server connection parameters for splatting.

    .DESCRIPTION
        Internal helper function that creates a hashtable containing the appropriate
        server connection parameters (ServerUri/Token or ServerName) based on the
        connection context. This eliminates repeated conditional parameter building
        throughout the codebase.

    .PARAMETER WasExplicitUri
        Indicates whether an explicit ServerUri was provided by the user.
        When true, ServerUri and Token parameters are used.
        When false, ServerName is used if provided.

    .PARAMETER ServerUri
        The explicit server URI to include when WasExplicitUri is true.

    .PARAMETER Token
        The authentication token to include when WasExplicitUri is true and Token is provided.

    .PARAMETER ServerName
        The stored server name to include when WasExplicitUri is false.

    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable with either:
        - ServerUri and optionally Token (when WasExplicitUri is true)
        - ServerName (when WasExplicitUri is false and ServerName is provided)
        - Empty hashtable (when neither condition is met)

    .EXAMPLE
        $splat = Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400' -Token 'abc123'
        Get-PatLibrary @splat

        Returns @{ ServerUri = 'http://plex:32400'; Token = 'abc123' }

    .EXAMPLE
        $splat = Build-PatServerSplat -WasExplicitUri $false -ServerName 'HomeServer'
        Get-PatLibrary @splat

        Returns @{ ServerName = 'HomeServer' }

    .EXAMPLE
        $context = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        $splat = Build-PatServerSplat -WasExplicitUri $context.WasExplicitUri -ServerUri $ServerUri -Token $Token -ServerName $ServerName
        Get-PatPlaylist @splat

        Builds server parameters from a resolved server context.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [bool]
        $WasExplicitUri,

        [Parameter()]
        [string]
        $ServerUri,

        [Parameter()]
        [string]
        $Token,

        [Parameter()]
        [string]
        $ServerName
    )

    process {
        $result = @{}

        if ($WasExplicitUri) {
            if ($ServerUri) {
                $result['ServerUri'] = $ServerUri
            }
            if ($Token) {
                $result['Token'] = $Token
            }
        }
        elseif ($ServerName) {
            $result['ServerName'] = $ServerName
        }

        $result
    }
}
