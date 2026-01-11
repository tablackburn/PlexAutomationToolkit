function Get-PatDestinationFreeSpace {
    <#
    .SYNOPSIS
        Gets the available free space at a destination path.

    .DESCRIPTION
        Internal helper function that determines the available free space at a destination
        path. Handles both standard drive letters (e.g., C:\) and UNC paths. Returns 0
        if the free space cannot be determined.

    .PARAMETER Path
        The destination path to check for free space. Can be a drive letter path or UNC path.

    .OUTPUTS
        System.Int64
        Returns the available free space in bytes, or 0 if it cannot be determined.

    .EXAMPLE
        Get-PatDestinationFreeSpace -Path 'E:\'

        Returns the free space on drive E:.

    .EXAMPLE
        Get-PatDestinationFreeSpace -Path '\\server\share\folder'

        Returns the free space on the UNC path.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process {
        [long]$destinationFree = 0

        try {
            # Handle drive letters (e.g., C:\, E:\path\to\folder) - case-insensitive match
            if ($Path -match '^([A-Za-z]):') {
                $driveLetter = $Matches[1]
                $drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
                $destinationFree = $drive.Free
            }
            else {
                # For UNC paths or when drive info isn't available, try filesystem info
                $driveInformation = [System.IO.DriveInfo]::GetDrives() |
                    Where-Object { $Path.StartsWith($_.Name, [StringComparison]::OrdinalIgnoreCase) } |
                    Select-Object -First 1
                if ($driveInformation) {
                    $destinationFree = $driveInformation.AvailableFreeSpace
                }
            }
        }
        catch {
            Write-Warning "Could not determine free space at destination: $($_.Exception.Message)"
        }

        return $destinationFree
    }
}
