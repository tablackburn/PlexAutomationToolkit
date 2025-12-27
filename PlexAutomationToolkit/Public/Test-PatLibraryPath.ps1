function Test-PatLibraryPath {
    <#
    .SYNOPSIS
        Tests whether a path exists on the Plex server's filesystem.

    .DESCRIPTION
        Validates that a specified filesystem path exists and is accessible
        to the Plex server. Optionally validates that the path falls within
        a library section's configured root paths.

        This cmdlet is useful for pre-validating paths before calling
        Update-PatLibrary to ensure the path exists and will be scanned.

    .PARAMETER Path
        The absolute filesystem path to test (e.g., /mnt/media/Movies/NewMovie).

    .PARAMETER SectionId
        Optional library section ID. When provided, also validates that the
        path is under one of the section's configured root paths.

    .PARAMETER SectionName
        Optional library section name (e.g., "Movies"). When provided, also
        validates that the path is under one of the section's configured root paths.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400)
        If not specified, uses the default stored server.

    .EXAMPLE
        Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie'

        Tests whether the path exists on the Plex server.

    .EXAMPLE
        Test-PatLibraryPath -Path '/mnt/media/Movies/NewMovie' -SectionName 'Movies'

        Tests whether the path exists AND is under one of the Movies library's
        configured root paths.

    .EXAMPLE
        if (Test-PatLibraryPath -Path $path -SectionName 'Movies') {
            Update-PatLibrary -SectionName 'Movies' -Path $path -SkipPathValidation
        }

        Pre-validates a path before triggering a library scan.

    .OUTPUTS
        System.Boolean

    .NOTES
        Always returns $true or $false, never throws errors.
        Returns $true if the path exists (and optionally is within library bounds).
        Returns $false if the path doesn't exist, is outside library bounds, or
        if there's an error communicating with the server.
        Use -Verbose to see diagnostic information about why validation failed.
    #>
    [CmdletBinding(DefaultParameterSetName = 'PathOnly')]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
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
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri
    )

    # Build parameters for internal calls
    $serverParams = @{}
    if ($ServerUri) {
        $serverParams['ServerUri'] = $ServerUri
    }

    # If section is specified, validate path is under a configured root
    if ($SectionName -or $SectionId) {
        try {
            $pathParams = $serverParams.Clone()
            if ($SectionName) {
                $pathParams['SectionName'] = $SectionName
            }
            else {
                $pathParams['SectionId'] = $SectionId
            }

            $libraryPaths = Get-PatLibraryPath @pathParams -ErrorAction 'Stop'

            if (-not $libraryPaths) {
                Write-Verbose "No configured paths found for the specified library section"
                return $false
            }

            # Check if Path is under any of the library's root paths
            $isUnderRoot = $false
            foreach ($libPath in $libraryPaths) {
                # Normalize paths for comparison (handle both / and \ separators)
                $normalizedPath = $Path -replace '\\', '/'
                $normalizedRoot = $libPath.path -replace '\\', '/'

                # Ensure root path ends with / for proper prefix matching
                if (-not $normalizedRoot.EndsWith('/')) {
                    $normalizedRoot += '/'
                }

                # Check if path equals root or is under root
                if ($normalizedPath -eq ($normalizedRoot.TrimEnd('/')) -or $normalizedPath.StartsWith($normalizedRoot)) {
                    $isUnderRoot = $true
                    Write-Verbose "Path '$Path' is under library root '$($libPath.path)'"
                    break
                }
            }

            if (-not $isUnderRoot) {
                $sectionIdentifier = if ($SectionName) { "'$SectionName'" } else { "ID $SectionId" }
                Write-Verbose "Path '$Path' is not under any configured root path for section $sectionIdentifier"
                return $false
            }
        }
        catch {
            Write-Verbose "Could not validate library paths: $($_.Exception.Message)"
            return $false
        }
    }

    # Test if the path exists on the Plex server
    try {
        # Get parent directory to check if path exists
        # We check the parent because the path itself might be a file
        $parentPath = $Path
        $lastSlash = [Math]::Max($Path.LastIndexOf('/'), $Path.LastIndexOf('\'))
        if ($lastSlash -gt 0) {
            $parentPath = $Path.Substring(0, $lastSlash)
            $targetName = $Path.Substring($lastSlash + 1)
        }
        else {
            # Root path - check directly
            $targetName = $null
        }

        $browseParams = $serverParams.Clone()
        $browseParams['Path'] = $parentPath

        $items = Get-PatLibraryChildItem @browseParams -ErrorAction 'Stop'

        if ($targetName) {
            # Check if the target exists in the parent directory
            $found = $items | Where-Object {
                $itemPath = if ($_.PSObject.Properties['path']) { $_.path } elseif ($_.PSObject.Properties['Path']) { $_.Path } else { $null }
                $itemTitle = if ($_.PSObject.Properties['title']) { $_.title } elseif ($_.PSObject.Properties['Title']) { $_.Title } else { $null }

                # Match by path ending or title
                if ($itemPath) {
                    $normalizedItemPath = $itemPath -replace '\\', '/'
                    $normalizedTargetPath = $Path -replace '\\', '/'
                    $normalizedItemPath -eq $normalizedTargetPath
                }
                elseif ($itemTitle) {
                    $itemTitle -eq $targetName
                }
                else {
                    $false
                }
            }

            if ($found) {
                Write-Verbose "Path '$Path' exists on the Plex server"
                return $true
            }
            else {
                Write-Verbose "Path '$Path' was not found in parent directory '$parentPath'"
                return $false
            }
        }
        else {
            # Just checking if we can browse the path (root level)
            Write-Verbose "Path '$Path' is accessible on the Plex server"
            return $true
        }
    }
    catch {
        # If browsing fails, the path likely doesn't exist or isn't accessible
        Write-Verbose "Path '$Path' is not accessible: $($_.Exception.Message)"
        return $false
    }
}
