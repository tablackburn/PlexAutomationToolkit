function Compare-PatLibraryContent {
    <#
    .SYNOPSIS
        Compares library content before and after a scan to identify changes.

    .DESCRIPTION
        Takes two collections of library items (typically from Get-PatLibraryItem)
        and identifies what was added, removed, or modified between them.
        Useful for validating that a library scan actually had the expected effect.

    .PARAMETER Before
        The collection of library items before the scan.
        Typically captured with: $before = Get-PatLibraryItem -SectionName 'Movies'

    .PARAMETER After
        The collection of library items after the scan.

    .PARAMETER KeyProperty
        The property to use as the unique identifier for items.
        Default: 'ratingKey' (Plex's unique item ID).

    .EXAMPLE
        $before = Get-PatLibraryItem -SectionName 'Movies'
        Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie'
        Wait-PatLibraryScan -SectionName 'Movies'
        $after = Get-PatLibraryItem -SectionName 'Movies'

        Compare-PatLibraryContent -Before $before -After $after

        Captures library state, triggers scan, waits, and compares to find changes.

    .EXAMPLE
        $changes = Compare-PatLibraryContent -Before $before -After $after
        $changes | Where-Object ChangeType -eq 'Added'

        Filters to show only newly added items.

    .EXAMPLE
        $changes = Compare-PatLibraryContent -Before $before -After $after
        $changes | Where-Object ChangeType -eq 'Removed'

        Filters to show items that were removed (e.g., after deleting files and rescanning).

    .EXAMPLE
        $changes = Compare-PatLibraryContent -Before $before -After $after -KeyProperty 'title'

        Uses title instead of ratingKey for comparison (useful for testing).

    .OUTPUTS
        PSCustomObject[] with properties:
        - ChangeType: 'Added', 'Removed', or 'Unchanged'
        - Item: The library item object
        - Title: The item's title (for convenience)
        - RatingKey: The item's unique ID
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $Before,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]
        $After,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $KeyProperty = 'ratingKey'
    )

    # Handle null/empty inputs
    $beforeItems = if ($Before) { @($Before) } else { @() }
    $afterItems = if ($After) { @($After) } else { @() }

    Write-Verbose "Comparing $($beforeItems.Count) items (before) with $($afterItems.Count) items (after)"

    # Build lookup hashtables for efficient comparison
    $beforeLookup = @{}
    foreach ($item in $beforeItems) {
        $key = $item.$KeyProperty
        if ($key) {
            $beforeLookup[$key.ToString()] = $item
        }
    }

    $afterLookup = @{}
    foreach ($item in $afterItems) {
        $key = $item.$KeyProperty
        if ($key) {
            $afterLookup[$key.ToString()] = $item
        }
    }

    $results = @()

    # Find added items (in After but not in Before)
    foreach ($key in $afterLookup.Keys) {
        if (-not $beforeLookup.ContainsKey($key)) {
            $item = $afterLookup[$key]
            $results += [PSCustomObject]@{
                PSTypeName = 'PlexAutomationToolkit.LibraryChange'
                ChangeType = 'Added'
                Item       = $item
                Title      = $item.title
                RatingKey  = $item.ratingKey
            }
        }
    }

    # Find removed items (in Before but not in After)
    foreach ($key in $beforeLookup.Keys) {
        if (-not $afterLookup.ContainsKey($key)) {
            $item = $beforeLookup[$key]
            $results += [PSCustomObject]@{
                PSTypeName = 'PlexAutomationToolkit.LibraryChange'
                ChangeType = 'Removed'
                Item       = $item
                Title      = $item.title
                RatingKey  = $item.ratingKey
            }
        }
    }

    # Log summary
    $added = ($results | Where-Object ChangeType -eq 'Added').Count
    $removed = ($results | Where-Object ChangeType -eq 'Removed').Count
    Write-Verbose "Found $added added items and $removed removed items"

    if ($results.Count -eq 0) {
        Write-Information "Libraries are in sync - no differences found" -InformationAction Continue
    }
    else {
        Write-Information "Found $added added and $removed removed items" -InformationAction Continue
    }

    # Return results (may be empty if no changes)
    $results
}
