function Format-ByteSize {
    <#
    .SYNOPSIS
        Formats a byte count as a human-readable string.

    .DESCRIPTION
        Internal helper function that converts a byte count to a human-readable string
        with appropriate units (bytes, KB, MB, GB, TB). Uses binary units (1024) for
        consistency with file system displays.

    .PARAMETER Bytes
        The number of bytes to format.

    .OUTPUTS
        System.String
        Returns a formatted string representing the byte size (e.g., "1.50 GB", "256 KB").

    .EXAMPLE
        Format-ByteSize -Bytes 1073741824
        Returns: "1.00 GB"

    .EXAMPLE
        Format-ByteSize -Bytes 5242880
        Returns: "5.0 MB"

    .EXAMPLE
        Format-ByteSize -Bytes 1024
        Returns: "1 KB"

    .EXAMPLE
        Format-ByteSize -Bytes 500
        Returns: "500 bytes"

    .EXAMPLE
        1GB, 500MB, 1KB | Format-ByteSize
        Returns: "1.00 GB", "500.0 MB", "1 KB"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateRange(0, [long]::MaxValue)]
        [long]
        $Bytes
    )

    process {
        if ($Bytes -ge 1TB) {
            return '{0:N2} TB' -f ($Bytes / 1TB)
        }
        elseif ($Bytes -ge 1GB) {
            return '{0:N2} GB' -f ($Bytes / 1GB)
        }
        elseif ($Bytes -ge 1MB) {
            return '{0:N1} MB' -f ($Bytes / 1MB)
        }
        elseif ($Bytes -ge 1KB) {
            return '{0:N0} KB' -f ($Bytes / 1KB)
        }
        else {
            return '{0} bytes' -f $Bytes
        }
    }
}
