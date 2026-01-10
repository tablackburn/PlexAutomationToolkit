function Get-PatLibraryPath {
    <#
    .SYNOPSIS
        Retrieves library section paths from a Plex server.

    .DESCRIPTION
        Gets the configured filesystem paths for Plex library sections.
        Returns paths for all sections, a specific section by ID, or a specific section by name.

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
        The ID of the library section. If omitted, returns paths for all sections.

    .PARAMETER SectionName
        The friendly name of the library section (e.g., "Movies", "TV Shows")

    .EXAMPLE
        Get-PatLibraryPath

        Retrieves all configured paths for all library sections from the default stored server.

    .EXAMPLE
        Get-PatLibraryPath -ServerUri "http://plex.example.com:32400" -SectionId 1

        Retrieves all configured paths for library section 1.

    .EXAMPLE
        Get-PatLibraryPath -SectionId 2

        Retrieves all configured paths for library section 2 from the default stored server.

    .EXAMPLE
        Get-PatLibraryPath -SectionName "Movies"

        Retrieves all configured paths for the "Movies" library section.

    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
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

    try {
        # Get all sections first - use appropriate server parameters
        $libParams = @{ ErrorAction = 'Stop' }
        if ($serverContext.WasExplicitUri) {
            $libParams['ServerUri'] = $serverContext.Uri
            if ($Token) { $libParams['Token'] = $Token }
        }
        elseif ($ServerName) {
            $libParams['ServerName'] = $ServerName
        }
        $allSections = Get-PatLibrary @libParams

        # If SectionName is provided, filter to that section
        if ($SectionName) {
            $matchingSection = $allSections.Directory | Where-Object { $_.title -eq $SectionName }

            if (-not $matchingSection) {
                throw "Library section '$SectionName' not found"
            }

            # Return Location objects enriched with section context
            if ($matchingSection.Location) {
                foreach ($location in $matchingSection.Location) {
                    [PSCustomObject]@{
                        id      = $location.id
                        path    = $location.path
                        section = $matchingSection.title
                        sectionId = ($matchingSection.key -replace '.*/(\d+)$', '$1')
                        sectionType = $matchingSection.type
                    }
                }
            }
            else {
                Write-Verbose "No paths configured for section '$SectionName'"
            }
        }
        elseif ($SectionId) {
            # Filter to specific section by ID
            $matchingSection = $allSections.Directory | Where-Object {
                ($_.key -replace '.*/(\d+)$', '$1') -eq $SectionId.ToString()
            }

            if (-not $matchingSection) {
                throw "Library section with ID $SectionId not found"
            }

            # Return Location objects enriched with section context
            if ($matchingSection.Location) {
                foreach ($location in $matchingSection.Location) {
                    [PSCustomObject]@{
                        id      = $location.id
                        path    = $location.path
                        section = $matchingSection.title
                        sectionId = ($matchingSection.key -replace '.*/(\d+)$', '$1')
                        sectionType = $matchingSection.type
                    }
                }
            }
            else {
                Write-Verbose "No paths configured for section $SectionId"
            }
        }
        else {
            # Return all locations from all sections with context
            if ($allSections.Directory) {
                foreach ($section in $allSections.Directory) {
                    if ($section.Location) {
                        $sectionId = ($section.key -replace '.*/(\d+)$', '$1')
                        foreach ($location in $section.Location) {
                            [PSCustomObject]@{
                                id      = $location.id
                                path    = $location.path
                                section = $section.title
                                sectionId = $sectionId
                                sectionType = $section.type
                            }
                        }
                    }
                }
            }
            else {
                Write-Verbose "No library sections found"
            }
        }
    }
    catch {
        $errorMessage = if ($SectionName) {
            "Failed to retrieve library paths for section '$SectionName': $($_.Exception.Message)"
        }
        elseif ($SectionId) {
            "Failed to retrieve library paths for section $SectionId : $($_.Exception.Message)"
        }
        else {
            "Failed to retrieve library paths: $($_.Exception.Message)"
        }
        throw $errorMessage
    }
}
