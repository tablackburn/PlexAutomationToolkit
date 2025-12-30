function ConvertFrom-PatCompleterInput {
    <#
    .SYNOPSIS
        Parses ArgumentCompleter input, extracting quote characters and the stripped word.

    .DESCRIPTION
        ArgumentCompleters receive $wordToComplete which may include leading quote characters
        (single or double). This function extracts the quote character (if present) and
        returns the stripped word for matching, along with the quote char for proper result formatting.

    .PARAMETER WordToComplete
        The word being completed, as passed to the ArgumentCompleter.

    .OUTPUTS
        PSCustomObject with properties:
        - QuoteChar: The leading quote character (empty string if none)
        - StrippedWord: The word with leading quote removed

    .EXAMPLE
        ConvertFrom-PatCompleterInput -WordToComplete "Movies"
        # Returns: @{ QuoteChar = ''; StrippedWord = 'Movies' }

    .EXAMPLE
        ConvertFrom-PatCompleterInput -WordToComplete "'My Library"
        # Returns: @{ QuoteChar = "'"; StrippedWord = 'My Library' }

    .EXAMPLE
        ConvertFrom-PatCompleterInput -WordToComplete '"Action Movies'
        # Returns: @{ QuoteChar = '"'; StrippedWord = 'Action Movies' }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $WordToComplete = ''
    )

    $quoteChar = ''
    $strippedWord = $WordToComplete

    if ($WordToComplete -match "^([`"'])(.*)$") {
        $quoteChar = $Matches[1]
        $strippedWord = $Matches[2]
    }

    [PSCustomObject]@{
        QuoteChar    = $quoteChar
        StrippedWord = $strippedWord
    }
}
