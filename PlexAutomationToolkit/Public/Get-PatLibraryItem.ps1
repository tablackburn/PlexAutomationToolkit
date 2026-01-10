function Get-PatLibraryItem {
    <#
    .SYNOPSIS
        Retrieves media items from a Plex library.

    .DESCRIPTION
        Gets all media items (movies, TV shows, music, etc.) from a specified Plex library section.
        Returns metadata for each item including title, year, rating, and other properties.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER SectionId
        The ID of the library section to retrieve items from.

    .PARAMETER SectionName
        The name of the library section to retrieve items from (e.g., "Movies", "TV Shows").

    .EXAMPLE
        Get-PatLibraryItem -SectionId 1

        Retrieves all items from library section 1.

    .EXAMPLE
        Get-PatLibraryItem -SectionName 'Movies' -ServerName 'Home'

        Retrieves all items from the Movies library on the stored server named 'Home'.

    .EXAMPLE
        Get-PatLibraryItem -SectionName "Movies"

        Retrieves all items from the Movies library.

    .EXAMPLE
        Get-PatLibrary | Where-Object { $_.Directory.title -eq 'Movies' } | ForEach-Object { Get-PatLibraryItem -SectionId ($_.Directory.key -replace '.*/(\d+)$', '$1') }

        Gets the Movies library and retrieves all items from it.

    .OUTPUTS
        PSCustomObject[]
        Returns an array of media item metadata objects from the Plex API.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $SectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $SectionId,

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
        $Token
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers
    }

    process {
        try {
            # Resolve SectionName to SectionId if needed
            $resolvedSectionId = $SectionId
            if ($SectionName) {
                # Build params for Get-PatLibrary
                $libParams = @{ ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) {
                    $libParams['ServerUri'] = $effectiveUri
                    if ($Token) { $libParams['Token'] = $Token }
                }
                elseif ($ServerName) {
                    $libParams['ServerName'] = $ServerName
                }
                $sections = Get-PatLibrary @libParams
                $matchingSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
                if (-not $matchingSection) {
                    throw "Library section '$SectionName' not found"
                }
                $resolvedSectionId = [int]($matchingSection.key -replace '.*/(\d+)$', '$1')
                Write-Verbose "Resolved section name '$SectionName' to ID $resolvedSectionId"
            }

            $endpoint = "/library/sections/$resolvedSectionId/all"
            Write-Verbose "Retrieving all items from library section $resolvedSectionId"

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            # Return the Metadata array
            if ($result.Metadata) {
                $result.Metadata
            }
            else {
                Write-Verbose "No items found in library section $resolvedSectionId"
            }
        }
        catch {
            throw "Failed to get library items: $($_.Exception.Message)"
        }
    }
}
