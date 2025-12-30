function New-PatCompletionResult {
    <#
    .SYNOPSIS
        Creates a CompletionResult with proper quoting for values containing spaces.

    .DESCRIPTION
        Builds a System.Management.Automation.CompletionResult object with intelligent quoting.
        If the original input had a quote character, the result preserves that quoting style.
        If the value contains spaces and no quote was specified, single quotes are added.

    .PARAMETER Value
        The completion value (e.g., library name, collection title).

    .PARAMETER QuoteChar
        Optional quote character from the original input. If provided, the completion
        text will be wrapped with this character.

    .PARAMETER ToolTip
        Optional tooltip to display. Defaults to the Value if not specified.

    .PARAMETER ListItemText
        Optional text to display in the completion list. Defaults to the Value if not specified.

    .OUTPUTS
        System.Management.Automation.CompletionResult

    .EXAMPLE
        New-PatCompletionResult -Value 'Movies'
        # Creates completion with text 'Movies' (no quotes needed)

    .EXAMPLE
        New-PatCompletionResult -Value 'Action Movies'
        # Creates completion with text "'Action Movies'" (auto-quoted for spaces)

    .EXAMPLE
        New-PatCompletionResult -Value 'Action Movies' -QuoteChar '"'
        # Creates completion with text '"Action Movies"' (preserves double quotes)

    .EXAMPLE
        New-PatCompletionResult -Value '12345' -ToolTip 'Movies (ID: 12345)'
        # Creates completion with custom tooltip
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $QuoteChar = '',

        [Parameter(Mandatory = $false)]
        [string]
        $ToolTip,

        [Parameter(Mandatory = $false)]
        [string]
        $ListItemText
    )

    $tooltip = if ($ToolTip) { $ToolTip } else { $Value }
    $listItem = if ($ListItemText) { $ListItemText } else { $Value }

    # Determine completion text with proper quoting
    if ($QuoteChar) {
        $text = "$QuoteChar$Value$QuoteChar"
    }
    elseif ($Value -match '\s') {
        $text = "'$Value'"
    }
    else {
        $text = $Value
    }

    [System.Management.Automation.CompletionResult]::new(
        $text,
        $listItem,
        'ParameterValue',
        $tooltip
    )
}
