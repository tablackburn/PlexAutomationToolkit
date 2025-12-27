function ConvertTo-PsCustomObjectFromHashtable {
    <#
    .SYNOPSIS
        Converts a hashtable to a PSCustomObject recursively.

    .DESCRIPTION
        Internal function that converts hashtables (including nested ones) to PSCustomObjects.
        This is needed when using ConvertFrom-Json -AsHashtable to handle Plex API responses
        that contain case-sensitive keys (e.g., both "guid" and "Guid"), then converting back
        to PSCustomObject for consistent property access patterns throughout the codebase.

    .PARAMETER Hashtable
        The hashtable to convert.

    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Hashtable
    )

    if ($null -eq $Hashtable) {
        return $null
    }

    # Handle arrays
    if ($Hashtable -is [System.Collections.IList] -and $Hashtable -isnot [string]) {
        $result = @()
        foreach ($item in $Hashtable) {
            if ($item -is [System.Collections.IDictionary]) {
                $result += ConvertTo-PsCustomObjectFromHashtable -Hashtable $item
            }
            elseif ($item -is [System.Collections.IList] -and $item -isnot [string]) {
                $result += , (ConvertTo-PsCustomObjectFromHashtable -Hashtable $item)
            }
            else {
                $result += $item
            }
        }
        return $result
    }

    # Handle hashtables/dictionaries
    if ($Hashtable -is [System.Collections.IDictionary]) {
        $obj = [ordered]@{}
        foreach ($key in $Hashtable.Keys) {
            $value = $Hashtable[$key]
            if ($value -is [System.Collections.IDictionary]) {
                $obj[$key] = ConvertTo-PsCustomObjectFromHashtable -Hashtable $value
            }
            elseif ($value -is [System.Collections.IList] -and $value -isnot [string]) {
                $obj[$key] = ConvertTo-PsCustomObjectFromHashtable -Hashtable $value
            }
            else {
                $obj[$key] = $value
            }
        }
        return [PSCustomObject]$obj
    }

    # Return primitives as-is
    return $Hashtable
}
