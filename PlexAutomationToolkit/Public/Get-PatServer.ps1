function Get-PatServer {
    <#
    .SYNOPSIS
        Retrieves Plex server information.

    .DESCRIPTION
        Gets information about a Plex server including version, platform, and capabilities.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .EXAMPLE
        Get-PatServer -ServerName 'Home'

        Retrieves server information from the stored server named 'Home'.

    .EXAMPLE
        Get-PatServer -ServerUri "http://plex.example.com:32400"

        Retrieves server information from the specified Plex server.

    .EXAMPLE
        Get-PatServer

        Retrieves server information from the default stored server.

    .EXAMPLE
        "http://plex1.local:32400", "http://plex2.local:32400" | Get-PatServer

        Retrieves server information from multiple servers via pipeline input.

    .OUTPUTS
        PlexAutomationToolkit.ServerInfo
        Returns structured server information with properties: FriendlyName, Version,
        Platform, PlatformVersion, MachineIdentifier, and various server capabilities
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ServerName,

        [Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
    )

    begin {
        # Cache for server context when using ServerName or default
        $script:cachedContext = $null
        if ($ServerName -or (-not $ServerUri -and -not $Token)) {
            try {
                $script:cachedContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
            }
            catch {
                throw "Failed to resolve server: $($_.Exception.Message)"
            }
        }
    }

    process {
        # Use cached context or resolve for pipeline input
        $serverContext = $script:cachedContext
        if (-not $serverContext) {
            try {
                $serverContext = Resolve-PatServerContext -ServerUri $ServerUri -Token $Token
            }
            catch {
                throw "Failed to resolve server: $($_.Exception.Message)"
            }
        }

        $effectiveUri = $serverContext.Uri
        $headers = $serverContext.Headers

        Write-Verbose "Retrieving server information from $effectiveUri"
        $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'

        try {
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Return structured server information object
            [PSCustomObject]@{
                PSTypeName           = 'PlexAutomationToolkit.ServerInfo'
                FriendlyName         = $result.friendlyName
                Version              = $result.version
                Platform             = $result.platform
                PlatformVersion      = $result.platformVersion
                MachineIdentifier    = $result.machineIdentifier
                MyPlex               = $result.myPlex
                MyPlexSigninState    = $result.myPlexSigninState
                MyPlexUsername       = $result.myPlexUsername
                Transcoders          = $result.transcoderActiveVideoSessions
                Size                 = $result.size
                AllowCameraUpload    = $result.allowCameraUpload
                AllowChannelAccess   = $result.allowChannelAccess
                AllowSync            = $result.allowSync
                AllowTuners          = $result.allowTuners
                BackgroundProcessing = $result.backgroundProcessing
                Certificate          = $result.certificate
                CompanionProxy       = $result.companionProxy
                ServerUri            = $effectiveUri
            }
        }
        catch {
            throw "Failed to get Plex server information: $($_.Exception.Message)"
        }
    }
}
