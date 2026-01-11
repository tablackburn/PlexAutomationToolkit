function ConvertTo-PatCollectionObject {
    <#
    .SYNOPSIS
        Converts raw Plex API collection metadata to a typed collection object.

    .DESCRIPTION
        Internal helper function that transforms raw collection metadata from the Plex API
        into a standardized PlexAutomationToolkit.Collection object.

    .PARAMETER CollectionData
        The raw collection metadata from the Plex API.

    .PARAMETER LibraryId
        The library section ID this collection belongs to.

    .PARAMETER LibraryName
        The name of the library this collection belongs to.

    .PARAMETER ServerUri
        The Plex server URI.

    .OUTPUTS
        PlexAutomationToolkit.Collection
        A typed collection object with standardized properties.

    .EXAMPLE
        $collectionObj = ConvertTo-PatCollectionObject -CollectionData $apiResult -LibraryId 1 -LibraryName 'Movies' -ServerUri 'http://plex:32400'

        Converts raw API data to a collection object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]
        $CollectionData,

        [Parameter(Mandatory = $true)]
        [int]
        $LibraryId,

        [Parameter(Mandatory = $false)]
        [string]
        $LibraryName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri
    )

    process {
        [PSCustomObject]@{
            PSTypeName   = 'PlexAutomationToolkit.Collection'
            CollectionId = [int]$CollectionData.ratingKey
            Title        = $CollectionData.title
            LibraryId    = $LibraryId
            LibraryName  = $LibraryName
            ItemCount    = [int]$CollectionData.childCount
            Thumb        = $CollectionData.thumb
            AddedAt      = if ($CollectionData.addedAt) {
                [DateTimeOffset]::FromUnixTimeSeconds([long]$CollectionData.addedAt).LocalDateTime
            } else { $null }
            UpdatedAt    = if ($CollectionData.updatedAt) {
                [DateTimeOffset]::FromUnixTimeSeconds([long]$CollectionData.updatedAt).LocalDateTime
            } else { $null }
            ServerUri    = $ServerUri
        }
    }
}
