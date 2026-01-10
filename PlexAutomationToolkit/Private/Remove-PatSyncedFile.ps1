function Remove-PatSyncedFile {
    <#
    .SYNOPSIS
        Removes a synced media file and cleans up empty parent directories.

    .DESCRIPTION
        Internal helper function that safely removes a file from a sync destination.
        Validates that the file is within the destination directory before deletion
        (security check to prevent path traversal attacks). After removing the file,
        cleans up any empty parent directories up to the destination root.

    .PARAMETER FilePath
        The full path to the file to remove.

    .PARAMETER Destination
        The root destination directory. Files outside this directory will not be removed.

    .OUTPUTS
        None. Writes warnings for security violations or errors.

    .EXAMPLE
        Remove-PatSyncedFile -FilePath 'E:\Movies\Old Movie (2020)\Old Movie (2020).mkv' -Destination 'E:\'

        Removes the file and cleans up empty parent directories.

    .EXAMPLE
        $syncPlan.RemoveOperations | ForEach-Object { Remove-PatSyncedFile -FilePath $_.Path -Destination 'E:\' }

        Removes multiple files from remove operations.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination
    )

    process {
        # Resolve destination to absolute path for validation
        $resolvedDestination = [System.IO.Path]::GetFullPath($Destination)
        # Ensure destination path ends with separator for proper prefix matching
        if (-not $resolvedDestination.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $resolvedDestination += [System.IO.Path]::DirectorySeparatorChar
        }

        # Security: Validate file is within destination directory before deletion
        $resolvedFilePath = [System.IO.Path]::GetFullPath($FilePath)
        if (-not $resolvedFilePath.StartsWith($resolvedDestination, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Skipping removal of '$FilePath' - path is outside destination directory"
            return
        }

        Write-Verbose "Removing: $FilePath"
        Remove-Item -Path $resolvedFilePath -Force -ErrorAction SilentlyContinue

        # Clean up empty parent directories (but stay within destination)
        $parent = Split-Path -Path $resolvedFilePath -Parent
        $maxIterations = 100  # Prevent infinite loop
        $iterations = 0

        while ($parent -and (Test-Path -Path $parent) -and $iterations -lt $maxIterations) {
            $iterations++

            # Stop if we've reached the destination root
            $resolvedParent = [System.IO.Path]::GetFullPath($parent)
            if (-not $resolvedParent.StartsWith($resolvedDestination, [System.StringComparison]::OrdinalIgnoreCase)) {
                break
            }

            $items = Get-ChildItem -Path $parent -Force -ErrorAction SilentlyContinue
            if (-not $items) {
                Remove-Item -Path $parent -Force -ErrorAction SilentlyContinue
                $newParent = Split-Path -Path $parent -Parent

                # Ensure we're actually moving up the directory tree
                if ($newParent -eq $parent) {
                    break
                }
                $parent = $newParent
            }
            else {
                break
            }
        }
    }
}
