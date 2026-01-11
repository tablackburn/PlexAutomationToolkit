function Get-PatCollectionItem {
    <#
    .SYNOPSIS
        Retrieves items from a Plex collection.

    .DESCRIPTION
        Internal helper function that fetches the items belonging to a collection
        and transforms them into typed CollectionItem objects.

    .PARAMETER CollectionId
        The unique identifier of the collection.

    .PARAMETER CollectionTitle
        The title of the collection (used for warning messages).

    .PARAMETER ServerUri
        The base URI of the Plex server.

    .PARAMETER Headers
        The authentication headers for API requests.

    .OUTPUTS
        PlexAutomationToolkit.CollectionItem[]
        An array of collection item objects.

    .EXAMPLE
        $items = Get-PatCollectionItem -CollectionId 12345 -CollectionTitle 'Marvel' -ServerUri 'http://plex:32400' -Headers $headers

        Retrieves all items from the specified collection.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $CollectionId,

        [Parameter(Mandatory = $false)]
        [string]
        $CollectionTitle,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Headers
    )

    process {
        $itemsEndpoint = "/library/collections/$CollectionId/children"
        $itemsUri = Join-PatUri -BaseUri $ServerUri -Endpoint $itemsEndpoint

        try {
            $itemsResult = Invoke-PatApi -Uri $itemsUri -Headers $Headers -ErrorAction 'Stop'

            if (-not $itemsResult -or -not $itemsResult.Metadata) {
                return @()
            }

            $items = foreach ($item in $itemsResult.Metadata) {
                [PSCustomObject]@{
                    PSTypeName   = 'PlexAutomationToolkit.CollectionItem'
                    RatingKey    = [int]$item.ratingKey
                    Title        = $item.title
                    Type         = $item.type
                    Year         = if ($item.year) { [int]$item.year } else { $null }
                    Thumb        = $item.thumb
                    AddedAt      = if ($item.addedAt) {
                        [DateTimeOffset]::FromUnixTimeSeconds([long]$item.addedAt).LocalDateTime
                    } else { $null }
                    CollectionId = $CollectionId
                    ServerUri    = $ServerUri
                }
            }

            return $items
        }
        catch {
            $title = if ($CollectionTitle) { $CollectionTitle } else { "ID $CollectionId" }
            Write-Warning "Failed to retrieve items for collection '$title': $($_.Exception.Message)"
            return @()
        }
    }
}
