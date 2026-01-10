function Get-PatLibraryChildItem {
    <#
    .SYNOPSIS
        Lists directories and files at a given path on the Plex server.

    .DESCRIPTION
        Browses the filesystem on the Plex server, listing subdirectories and files
        at a specified path. Uses the Plex internal browse service endpoint.

    .PARAMETER ServerName
        The name of a stored server to use. Use Get-PatStoredServer to see available servers.
        This is more convenient than ServerUri as you don't need to remember the URI or token.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER Path
        The absolute filesystem path to browse (e.g., /mnt/media, /var/lib/plexmediaserver)
        If omitted, lists root-level accessible paths.

    .PARAMETER SectionId
        Optional library section ID. When provided, the command browses each path configured for that
        section. Cannot be combined with SectionName.

    .PARAMETER SectionName
        Optional library section name (e.g., "Movies"). When provided, the command browses each path
        configured for that section. Cannot be combined with SectionId.

    .EXAMPLE
        Get-PatLibraryChildItem -ServerUri "http://plex.example.com:32400" -Path "/mnt/media"

        Lists directories and files under /mnt/media.

    .EXAMPLE
        Get-PatLibraryChildItem

        Lists root-level paths from the default stored server.

    .EXAMPLE
        Get-PatLibraryChildItem -Path "/mnt/smb/nas5/movies"

        Lists all items (directories and files) under the movies path.

    .EXAMPLE
        Get-PatLibraryChildItem -SectionName "Movies"

        Lists items from every path configured for the Movies section.

    .OUTPUTS
        PSCustomObject
    #>
    [OutputType([PSCustomObject], [object[]])]
    [CmdletBinding(DefaultParameterSetName = 'PathOnly')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'PathOnly')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $SectionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
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

    try {
        $serverContext = Resolve-PatServerContext -ServerName $ServerName -ServerUri $ServerUri -Token $Token
    }
    catch {
        throw "Failed to resolve server: $($_.Exception.Message)"
    }

    $effectiveUri = $serverContext.Uri
    $headers = $serverContext.Headers

    try {
        $pathsToBrowse = @()

        # If section parameters provided, collect all section locations
        if ($SectionName -or $SectionId) {
            # Build params for Get-PatLibrary
            $libParams = @{ ErrorAction = 'Stop' }
            if ($serverContext.WasExplicitUri) {
                $libParams['ServerUri'] = $effectiveUri
                if ($Token) { $libParams['Token'] = $Token }
            }
            elseif ($ServerName) {
                $libParams['ServerName'] = $ServerName
            }
            $sections = Get-PatLibrary @libParams

            $matchingSection = $null
            if ($SectionName) {
                $matchingSection = $sections.Directory | Where-Object { $_.title -eq $SectionName }
                if (-not $matchingSection) {
                    throw "Library section '$SectionName' not found"
                }
            }
            else {
                $matchingSection = $sections.Directory | Where-Object {
                    ($_.key -replace '.*/(\d+)$', '$1') -eq $SectionId.ToString()
                }
                if (-not $matchingSection) {
                    throw "Library section with ID $SectionId not found"
                }
            }

            if ($matchingSection.Location) {
                # Handle both single location and array of locations
                $locations = @($matchingSection.Location)
                foreach ($location in $locations) {
                    if ($location.path) {
                        $pathsToBrowse += $location.path
                    }
                }
            }
        }

        if ($Path) {
            # Explicit path overrides any section-derived paths
            $pathsToBrowse = @($Path)
        }

        if (-not $pathsToBrowse -or $pathsToBrowse.Count -eq 0) {
            # No path specified, no section provided -> browse root
            $pathsToBrowse = @($null)
        }

        $results = @()

        foreach ($p in $pathsToBrowse) {
            $endpoint = '/services/browse'

            if ($p) {
                $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($p)
                $pathB64 = [Convert]::ToBase64String($pathBytes)
                $endpoint += "/$pathB64"
            }

            $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint -QueryString 'includeFiles=1'
            $result = Invoke-PatApi -Uri $uri -Headers $headers -ErrorAction 'Stop'

            if ($result.Path) { $results += $result.Path }
            if ($result.File) { $results += $result.File }

            if (-not $result.Path -and -not $result.File) {
                Write-Verbose "No items found at path: $p"
            }
        }

        $results
    }
    catch {
        $errPath = if ($Path) { $Path } elseif ($SectionName) { $SectionName } elseif ($SectionId) { $SectionId } else { '<root>' }
        throw "Failed to list items for ${errPath}: $($_.Exception.Message)"
    }
}
