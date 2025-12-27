function Get-PatSafeFilename {
    <#
    .SYNOPSIS
        Converts a string to a safe filename by removing invalid characters.

    .DESCRIPTION
        Internal helper function that sanitizes strings for use as filenames on Windows
        and other filesystems. Removes or replaces characters that are not allowed in
        filenames, trims trailing periods and spaces, and limits the length.

    .PARAMETER Name
        The string to convert to a safe filename.

    .PARAMETER MaxLength
        Maximum length for the resulting filename. Default is 200 characters to leave
        room for path components and extensions.

    .OUTPUTS
        System.String
        Returns a sanitized string safe for use as a filename.

    .EXAMPLE
        Get-PatSafeFilename -Name "Movie: The Sequel?"
        Returns: "Movie - The Sequel"

    .EXAMPLE
        Get-PatSafeFilename -Name "Test<>File"
        Returns: "TestFile"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 255)]
        [int]
        $MaxLength = 200
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return ''
        }

        $result = $Name

        # Replace colons with dashes (common in titles like "Movie: The Sequel")
        $result = $result -replace ':', ' - '

        # Remove characters that are invalid in Windows filenames: < > : " / \ | ? *
        # Note: colon already handled above
        $result = $result -replace '[<>"/\\|?*]', ''

        # Replace multiple spaces with single space
        $result = $result -replace '\s+', ' '

        # Trim leading and trailing whitespace
        $result = $result.Trim()

        # Remove trailing periods (Windows restriction)
        $result = $result.TrimEnd('.')

        # Remove leading/trailing dashes that may result from colon replacement with no content
        $result = $result.Trim('-').Trim()

        # Limit length
        if ($result.Length -gt $MaxLength) {
            $result = $result.Substring(0, $MaxLength).TrimEnd()
        }

        # Final safety check - if result is empty or only whitespace, return placeholder
        if ([string]::IsNullOrWhiteSpace($result)) {
            return 'Untitled'
        }

        return $result
    }
}
