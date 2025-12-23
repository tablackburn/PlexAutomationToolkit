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

    .OUTPUTS
        PSCustomObject
        Returns the MediaContainer object from the Plex API response
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId
    )

    # Use default server if ServerUri not specified
    $server = $null
    if (-not $ServerUri) {
        try {
            $server = Get-PatStoredServer -Default -ErrorAction 'Stop'
            if (-not $server) {
                throw "No default server configured. Use Add-PatServer with -Default or specify -ServerUri."
            }
            $ServerUri = $server.uri
        }
        catch {
            throw "Failed to get default server: $($_.Exception.Message)"
        }
    }

    if ($SectionId) {
        $endpoint = "/library/sections/$SectionId"
    }
    else {
        $endpoint = '/library/sections'
    }
    $uri = Join-PatUri -BaseUri $ServerUri -Endpoint $endpoint

    # Build headers with authentication if we have server object
    $headers = if ($server) {
        Get-PatAuthHeaders -Server $server
    }
    else {
        @{ Accept = 'application/json' }
    }

    try {
        Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to get Plex library information: $($_.Exception.Message)"
    }
}
