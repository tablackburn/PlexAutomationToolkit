function Get-PatSyncRemoveOperation {
    <#
    .SYNOPSIS
        Finds media files in a folder that should be removed during sync.

    .DESCRIPTION
        Internal helper function that scans a folder for media files and identifies
        those that are not in the expected paths list. Returns remove operation objects
        for files that should be deleted.

    .PARAMETER FolderPath
        The folder path to scan for media files.

    .PARAMETER ExpectedPaths
        A hashtable of expected file paths. Files not in this hashtable will be
        marked for removal.

    .PARAMETER MediaType
        The type of media being scanned ('movie' or 'episode').

    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable with Operations (array of SyncRemoveOperation objects) and TotalBytes (total size of files to remove).

    .EXAMPLE
        $expected = @{ 'E:\Movies\Movie.mkv' = $true }
        Get-PatSyncRemoveOperation -FolderPath 'E:\Movies' -ExpectedPaths $expected -MediaType 'movie'

        Returns remove operations for any movie files not in the expected paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FolderPath,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $ExpectedPaths,

        [Parameter(Mandatory = $true)]
        [ValidateSet('movie', 'episode')]
        [string]
        $MediaType
    )

    process {
        $removeOperations = [System.Collections.Generic.List[PSCustomObject]]::new()
        $totalBytes = 0

        if (-not (Test-Path -Path $FolderPath)) {
            return @{
                Operations = @()
                TotalBytes = 0
            }
        }

        $mediaFiles = Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '\.(mkv|mp4|avi|m4v|mov|ts|wmv)$' }

        foreach ($file in $mediaFiles) {
            if (-not $ExpectedPaths.ContainsKey($file.FullName)) {
                $removeOperations.Add([PSCustomObject]@{
                    PSTypeName = 'PlexAutomationToolkit.SyncRemoveOperation'
                    Path       = $file.FullName
                    Size       = $file.Length
                    Type       = $MediaType
                })
                $totalBytes += $file.Length
            }
        }

        return @{
            Operations = $removeOperations.ToArray()
            TotalBytes = $totalBytes
        }
    }
}
