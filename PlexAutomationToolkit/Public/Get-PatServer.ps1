function Get-PatServer {
    <#
    .SYNOPSIS
        Retrieves Plex server information.

    .DESCRIPTION
        Gets information about a Plex server including version, platform, and capabilities.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

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
        [Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri
    )

    begin {
        # Will store server for default case
        $defaultServer = $null
    }

    process {
        # Use default server if ServerUri not specified
        $server = $null
        $effectiveUri = $ServerUri
        if (-not $ServerUri) {
            # Cache default server lookup
            if (-not $defaultServer) {
                try {
                    $defaultServer = Get-PatStoredServer -Default -ErrorAction 'Stop'
                    if (-not $defaultServer) {
                        throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
                    }
                    Write-Verbose "Using default server: $($defaultServer.uri)"
                }
                catch {
                    throw "Failed to get default server: $($_.Exception.Message)"
                }
            }
            $server = $defaultServer
            $effectiveUri = $server.uri
        }
        else {
            Write-Verbose "Using specified server: $ServerUri"
        }

        Write-Verbose "Retrieving server information from $effectiveUri"
        $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint '/'

        # Build headers with authentication if we have server object
        $headers = if ($server) {
            Get-PatAuthHeader -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }

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
