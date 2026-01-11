function Get-PatShowEpisodes {
    <#
    .SYNOPSIS
        Retrieves all episodes for a TV show from a Plex server.

    .DESCRIPTION
        Internal helper function that fetches all episodes (leaves) for a given TV show
        using the Plex API's allLeaves endpoint. Returns the raw episode metadata from
        the API response.

    .PARAMETER Server
        The server configuration object containing uri and authentication details.

    .PARAMETER ShowRatingKey
        The rating key (unique identifier) of the TV show.

    .OUTPUTS
        PSObject[]
        An array of episode metadata objects from the Plex API, or an empty array if
        no episodes are found or an error occurs.

    .EXAMPLE
        $episodes = Get-PatShowEpisodes -Server $serverConfig -ShowRatingKey 12345

        Retrieves all episodes for the show with rating key 12345.
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]
        $Server,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $ShowRatingKey
    )

    process {
        $episodesUri = Join-PatUri -BaseUri $Server.uri -Endpoint "/library/metadata/$ShowRatingKey/allLeaves"
        $headers = Get-PatAuthenticationHeader -Server $Server

        try {
            $episodesResult = Invoke-PatApi -Uri $episodesUri -Headers $headers -ErrorAction Stop

            if ($episodesResult -and $episodesResult.Metadata) {
                return $episodesResult.Metadata
            }

            return @()
        }
        catch {
            Write-Verbose "Failed to retrieve episodes for show $ShowRatingKey : $($_.Exception.Message)"
            return @()
        }
    }
}
