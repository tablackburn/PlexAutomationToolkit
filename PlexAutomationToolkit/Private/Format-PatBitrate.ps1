function Format-PatBitrate {
    <#
    .SYNOPSIS
        Formats a bitrate value as a human-readable string.

    .DESCRIPTION
        Internal helper function that converts a bitrate in kilobits per second (kbps)
        to a human-readable string with appropriate units (kbps or Mbps).

    .PARAMETER Kbps
        The bitrate in kilobits per second.

    .OUTPUTS
        System.String
        Returns a formatted string representing the bitrate (e.g., "25.5 Mbps", "800 kbps").
        Returns $null if input is $null or 0.

    .EXAMPLE
        Format-PatBitrate -Kbps 25500
        Returns: "25.5 Mbps"

    .EXAMPLE
        Format-PatBitrate -Kbps 800
        Returns: "800 kbps"

    .EXAMPLE
        25500, 800, 5000 | Format-PatBitrate
        Returns: "25.5 Mbps", "800 kbps", "5.0 Mbps"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        [long]
        $Kbps
    )

    process {
        if ($null -eq $Kbps -or $Kbps -eq 0) {
            return $null
        }

        if ($Kbps -ge 1000) {
            return '{0:N1} Mbps' -f ($Kbps / 1000)
        }
        else {
            return '{0:N0} kbps' -f $Kbps
        }
    }
}
