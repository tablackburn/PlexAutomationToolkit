function Format-PatDuration {
    <#
    .SYNOPSIS
        Formats a duration in milliseconds as a human-readable string.

    .DESCRIPTION
        Internal helper function that converts a duration in milliseconds to a human-readable
        string showing hours and minutes (e.g., "2h 16m") or just minutes for shorter durations.

    .PARAMETER Milliseconds
        The duration in milliseconds to format.

    .OUTPUTS
        System.String
        Returns a formatted string representing the duration (e.g., "2h 16m", "45m", "0m").
        Returns $null if input is $null or 0.

    .EXAMPLE
        Format-PatDuration -Milliseconds 8160000
        Returns: "2h 16m"

    .EXAMPLE
        Format-PatDuration -Milliseconds 2700000
        Returns: "45m"

    .EXAMPLE
        Format-PatDuration -Milliseconds 0
        Returns: $null

    .EXAMPLE
        8160000, 2700000, 5400000 | Format-PatDuration
        Returns: "2h 16m", "45m", "1h 30m"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        [long]
        $Milliseconds
    )

    process {
        if ($null -eq $Milliseconds -or $Milliseconds -eq 0) {
            return $null
        }

        $totalMinutes = [math]::Floor($Milliseconds / 60000)
        $hours = [math]::Floor($totalMinutes / 60)
        $minutes = $totalMinutes % 60

        if ($hours -gt 0) {
            return "${hours}h ${minutes}m"
        }
        else {
            return "${minutes}m"
        }
    }
}
