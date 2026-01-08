function Get-PatLibrary {
    <#
    .SYNOPSIS
        Retrieves Plex library information.

    .DESCRIPTION
        Gets information about all Plex library sections or a specific library section.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests will fail.

    .PARAMETER SectionId
        Optional ID of a specific library section to retrieve. If omitted, returns all sections.

    .EXAMPLE
        Get-PatLibrary -ServerName 'Home'

        Retrieves all library sections from the stored server named 'Home'.

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
        [string]
        $ServerName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId
    )

    begin {
        try {
            $serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $serverContext.Uri
        $headers = $serverContext.Headers
    }

    process {
        if ($SectionId) {
            $endpoint = "/library/sections/$SectionId"
            Write-Verbose "Retrieving library section $SectionId from $effectiveUri"
        }
        else {
            $endpoint = '/library/sections'
            Write-Verbose "Retrieving all library sections from $effectiveUri"
        }
        $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

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
