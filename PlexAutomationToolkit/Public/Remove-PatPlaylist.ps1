function Remove-PatPlaylist {
    <#
    .SYNOPSIS
        Removes a playlist from a Plex server.

    .DESCRIPTION
        Deletes a playlist from the Plex server. Can identify the playlist by ID or name.
        This action is irreversible - the playlist and its item associations will be
        permanently deleted.

    .PARAMETER PlaylistId
        The unique identifier of the playlist to remove.

    .PARAMETER PlaylistName
        The name of the playlist to remove. Supports tab completion.

    .PARAMETER ServerUri
        The base URI of the Plex server (e.g., http://plex.example.com:32400).
        If not specified, uses the default stored server.

    .PARAMETER Token
        The Plex authentication token. Required when using -ServerUri to authenticate
        with the server. If not specified with -ServerUri, requests may fail with 401.

    .PARAMETER PassThru
        If specified, returns the playlist object that was removed.

    .EXAMPLE
        Remove-PatPlaylist -PlaylistId 12345

        Removes the playlist with ID 12345 after confirmation.

    .EXAMPLE
        Remove-PatPlaylist -PlaylistName 'Old Playlist' -Confirm:$false

        Removes the playlist named 'Old Playlist' without confirmation prompt.

    .EXAMPLE
        Get-PatPlaylist -PlaylistName 'Temp*' | Remove-PatPlaylist

        Removes all playlists starting with 'Temp' via pipeline.

    .EXAMPLE
        Remove-PatPlaylist -PlaylistName 'Test Playlist' -WhatIf

        Shows what would be removed without actually removing it.

    .EXAMPLE
        Remove-PatPlaylist -PlaylistId 12345 -PassThru

        Removes the playlist and returns the removed playlist object for logging.

    .OUTPUTS
        PlexAutomationToolkit.Playlist (when -PassThru is specified)

        Returns the removed playlist object for auditing purposes.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'parameterName',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'commandAst',
        Justification = 'Standard ArgumentCompleter parameter, not always used'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $PlaylistId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $completerInput = ConvertFrom-PatCompleterInput -WordToComplete $wordToComplete

            $getParameters = @{ ErrorAction = 'SilentlyContinue' }
            if ($fakeBoundParameters.ContainsKey('ServerUri')) {
                $getParameters['ServerUri'] = $fakeBoundParameters['ServerUri']
            }

            $playlists = Get-PatPlaylist @getParameters

            foreach ($playlist in $playlists) {
                if ($playlist.Title -ilike "$($completerInput.StrippedWord)*") {
                    New-PatCompletionResult -Value $playlist.Title -QuoteChar $completerInput.QuoteChar
                }
            }
        })]
        [string]
        $PlaylistName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-PatServerUri -Uri $_ })]
        [string]
        $ServerUri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token,

        [Parameter(Mandatory = $false)]
        [switch]
        $PassThru
    )

    begin {
        try {
            $script:serverContext = Resolve-PatServerContext -ServerUri $ServerUri -Token $Token
        }
        catch {
            throw "Failed to resolve server: $($_.Exception.Message)"
        }

        $effectiveUri = $script:serverContext.Uri
        $headers = $script:serverContext.Headers
    }

    process {
        try {
            # Resolve playlist ID if using name
            $resolvedId = $PlaylistId
            $playlistInfo = $null

            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                # Only pass ServerUri if explicitly specified
                $getParams = @{ PlaylistName = $PlaylistName; ErrorAction = 'Stop' }
                if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                $playlist = Get-PatPlaylist @getParams
                if (-not $playlist) {
                    throw "No playlist found with name '$PlaylistName'"
                }
                $resolvedId = $playlist.PlaylistId
                $playlistInfo = $playlist
            }
            else {
                # Get playlist info for ShouldProcess message and PassThru
                try {
                    # Only pass ServerUri if explicitly specified
                    $getParams = @{ PlaylistId = $PlaylistId; ErrorAction = 'Stop' }
                    if ($script:serverContext.WasExplicitUri) { $getParams['ServerUri'] = $effectiveUri }
                    $playlistInfo = Get-PatPlaylist @getParams
                }
                catch {
                    Write-Verbose "Could not retrieve playlist info for ID $PlaylistId"
                }
            }

            # Build descriptive target for confirmation
            $target = if ($playlistInfo) {
                "'$($playlistInfo.Title)' (ID: $resolvedId, $($playlistInfo.ItemCount) items)"
            }
            else {
                "Playlist ID $resolvedId"
            }

            if ($PSCmdlet.ShouldProcess($target, 'Delete playlist')) {
                $endpoint = "/playlists/$resolvedId"
                $uri = Join-PatUri -BaseUri $effectiveUri -Endpoint $endpoint

                Write-Verbose "Deleting playlist $resolvedId from $effectiveUri"

                $null = Invoke-PatApi -Uri $uri -Method 'DELETE' -Headers $headers -ErrorAction 'Stop'

                if ($PassThru -and $playlistInfo) {
                    $playlistInfo
                }
            }
        }
        catch {
            throw "Failed to remove playlist: $($_.Exception.Message)"
        }
    }
}
