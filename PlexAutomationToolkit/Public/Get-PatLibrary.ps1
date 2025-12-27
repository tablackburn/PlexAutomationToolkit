function Get-PatLibrary {
    <#
    .SYNOPSIS
        Retrieves Plex library information.

    .DESCRIPTION
        Gets information about all Plex library sections or a specific library section.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER SectionId
        Optional ID of a specific library section to retrieve. If omitted, returns all sections.

    .EXAMPLE
        Get-PatLibrary -ServerUri "http://plex.example.com:32400"

        Retrieves all library sections from the server.

    .EXAMPLE
        Get-PatLibrary

        Retrieves all library sections from the default stored server.

    .EXAMPLE
        Get-PatLibrary -ServerUri "http://plex.example.com:32400" -SectionId 2

        Retrieves information for library section 2.

    .EXAMPLE
        Get-PatLibrary -SectionId 2

        Retrieves information for library section 2 from the default stored server.

    .EXAMPLE
        1, 2, 3 | Get-PatLibrary

        Retrieves library sections 1, 2, and 3 via pipeline input.

    .OUTPUTS
        PSCustomObject (MediaContainer)
        Returns the MediaContainer object from the Plex API. When retrieving all libraries,
        each Directory object is enhanced with the PSTypeName 'PlexAutomationToolkit.Library'
        for better type discovery and custom formatting
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId
    )

    begin {
        # Use default server if ServerUri not specified
        $server = $null
        if (-not $ServerUri) {
            try {
                $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
                if (-not $server) {
                    throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
                }
                $ServerUri = $server.uri
                Write-Verbose "Using default server: $ServerUri"
            }
            catch {
                throw "Failed to get default server: $($_.Exception.Message)"
            }
        }
        else {
            Write-Verbose "Using specified server: $ServerUri"
        }

        # Build headers with authentication if we have server object
        $headers = if ($server) {
            Get-PatAuthHeader -Server $server
        }
        else {
            @{ Accept = 'application/json' }
        }
    }

    process {
        if ($SectionId) {
            $endpoint = "/library/sections/$SectionId"
            Write-Verbose "Retrieving library section $SectionId from $ServerUri"
        }
        else {
            $endpoint = '/library/sections'
            Write-Verbose "Retrieving all library sections from $ServerUri"
        }
        $uri = Join-PatUri -BaseUri $ServerUri -Endpoint $endpoint

        try {
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Add PSTypeName to Directory objects for better type discovery
            if ($result.Directory) {
                foreach ($section in $result.Directory) {
                    $section.PSObject.TypeNames.Insert(0, 'PlexAutomationToolkit.Library')
                }
            }

            # Return the MediaContainer (preserves compatibility with existing code)
            $result
        }
        catch {
            throw "Failed to get Plex library information: $($_.Exception.Message)"
        }
    }
}
