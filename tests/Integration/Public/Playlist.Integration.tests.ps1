BeforeDiscovery {
    # Check if integration tests should run
    $script:integrationEnabled = $false
    $script:mutationTestsEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true
        Write-Host "Playlist integration tests ENABLED - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green

        if ($env:PLEX_ALLOW_MUTATIONS -eq 'true') {
            $script:mutationTestsEnabled = $true
            Write-Host "Mutation tests ENABLED - Playlists will be created/modified" -ForegroundColor Yellow
        }
        else {
            Write-Host "Mutation tests DISABLED - Set PLEX_ALLOW_MUTATIONS=true to enable" -ForegroundColor Yellow
        }
    }
    else {
        $missingVars = @()
        if (-not $env:PLEX_SERVER_URI) { $missingVars += 'PLEX_SERVER_URI' }
        if (-not $env:PLEX_TOKEN) { $missingVars += 'PLEX_TOKEN' }

        Write-Host "Playlist integration tests SKIPPED - Missing: $($missingVars -join ', ')" -ForegroundColor Yellow
        Write-Host "To enable: Copy tests/local.settings.example.ps1 to tests/local.settings.ps1 and configure" -ForegroundColor Yellow
    }
}

BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Import helpers
    $helpersPath = Join-Path -Path $PSScriptRoot -ChildPath '..\IntegrationTestHelpers.psm1'
    if (Test-Path $helpersPath) {
        Import-Module -Name $helpersPath -Force -Verbose:$false
    }
}

Describe 'Get-PatPlaylist Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-Playlist' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Playlist retrieval' {

        It 'Successfully queries playlists endpoint' {
            { Get-PatPlaylist } | Should -Not -Throw
        }

        It 'Returns array or null (depending on existing playlists)' {
            $result = Get-PatPlaylist
            # Result can be null/empty or an array of playlists
            if ($result) {
                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Playlist objects have expected properties when playlists exist' {
            $result = Get-PatPlaylist
            if ($result) {
                $result[0].PSObject.Properties.Name | Should -Contain 'PlaylistId'
                $result[0].PSObject.Properties.Name | Should -Contain 'Title'
                $result[0].PSObject.Properties.Name | Should -Contain 'Type'
                $result[0].PSObject.Properties.Name | Should -Contain 'ItemCount'
            }
            else {
                Set-ItResult -Skipped -Because 'No playlists exist to test properties'
            }
        }

        It 'Playlist objects have correct PSTypeName' {
            $result = Get-PatPlaylist
            if ($result) {
                $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Playlist'
            }
            else {
                Set-ItResult -Skipped -Because 'No playlists exist to test type'
            }
        }

        It 'Accepts explicit ServerUri parameter' {
            { Get-PatPlaylist -ServerUri $env:PLEX_SERVER_URI -Token $env:PLEX_TOKEN } | Should -Not -Throw
        }
    }

    Context 'Playlist retrieval with items' {

        It 'IncludeItems parameter does not throw' {
            { Get-PatPlaylist -IncludeItems } | Should -Not -Throw
        }

        It 'Playlists have Items property when IncludeItems specified' {
            $result = Get-PatPlaylist -IncludeItems
            if ($result) {
                $result[0].PSObject.Properties.Name | Should -Contain 'Items'
            }
            else {
                Set-ItResult -Skipped -Because 'No playlists exist to test Items property'
            }
        }
    }
}

Describe 'Playlist CRUD Integration Tests' -Skip:(-not $script:mutationTestsEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-PlaylistCRUD' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Track created playlists for cleanup
        $script:createdPlaylistIds = [System.Collections.ArrayList]::new()

        # Discover a test media item for creating playlists (required by Plex API)
        $script:testRatingKey = $null
        try {
            $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
            if ($libraries -and $libraries.Directory) {
                foreach ($lib in $libraries.Directory) {
                    $items = Get-PatLibraryItem -SectionId $lib.key -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($items -and $items.ratingKey) {
                        $script:testRatingKey = [int]$items.ratingKey
                        Write-Verbose "Using test rating key: $($script:testRatingKey)"
                        break
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not find test media item: $($_.Exception.Message)"
        }

        if (-not $script:testRatingKey) {
            throw "No media items available for playlist integration tests"
        }
    }

    AfterAll {
        # Clean up any created test playlists
        foreach ($playlistId in $script:createdPlaylistIds) {
            try {
                Remove-PatPlaylist -PlaylistId $playlistId -Confirm:$false -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Failed to clean up playlist $playlistId`: $($_.Exception.Message)"
            }
        }

        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Create playlist' {
        It 'Creates a new playlist with New-PatPlaylist' {
            $testTitle = "IntegrationTest-Playlist-$(Get-Date -Format 'yyyyMMddHHmmss')"

            $result = New-PatPlaylist -Title $testTitle -RatingKey $script:testRatingKey -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Title | Should -Be $testTitle
            $result.PlaylistId | Should -BeGreaterThan 0
            $result.ItemCount | Should -Be 1

            # Track for cleanup
            $null = $script:createdPlaylistIds.Add($result.PlaylistId)
        }

        It 'Created playlist is retrievable via Get-PatPlaylist' {
            $testTitle = "IntegrationTest-Playlist-Get-$(Get-Date -Format 'yyyyMMddHHmmss')"

            $created = New-PatPlaylist -Title $testTitle -RatingKey $script:testRatingKey -PassThru -Confirm:$false
            $null = $script:createdPlaylistIds.Add($created.PlaylistId)

            $retrieved = Get-PatPlaylist -PlaylistId $created.PlaylistId

            $retrieved | Should -Not -BeNullOrEmpty
            $retrieved.Title | Should -Be $testTitle
        }

        It 'Creates playlist with specified type' {
            $testTitle = "IntegrationTest-Playlist-Video-$(Get-Date -Format 'yyyyMMddHHmmss')"

            $result = New-PatPlaylist -Title $testTitle -Type 'video' -RatingKey $script:testRatingKey -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'video'

            $null = $script:createdPlaylistIds.Add($result.PlaylistId)
        }
    }

    Context 'Delete playlist' {
        It 'Removes a playlist with Remove-PatPlaylist' {
            $testTitle = "IntegrationTest-Playlist-Delete-$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Create a playlist to delete
            $created = New-PatPlaylist -Title $testTitle -RatingKey $script:testRatingKey -PassThru -Confirm:$false

            # Delete it
            { Remove-PatPlaylist -PlaylistId $created.PlaylistId -Confirm:$false } | Should -Not -Throw

            # Verify it's gone
            { Get-PatPlaylist -PlaylistId $created.PlaylistId } | Should -Throw
        }

        It 'PassThru returns removed playlist info' {
            $testTitle = "IntegrationTest-Playlist-PassThru-$(Get-Date -Format 'yyyyMMddHHmmss')"

            $created = New-PatPlaylist -Title $testTitle -RatingKey $script:testRatingKey -PassThru -Confirm:$false

            $removed = Remove-PatPlaylist -PlaylistId $created.PlaylistId -PassThru -Confirm:$false

            $removed | Should -Not -BeNullOrEmpty
            $removed.Title | Should -Be $testTitle
        }
    }

    Context 'Add and remove playlist items' {
        BeforeAll {
            # Create a test playlist for item operations (using the testRatingKey discovered at parent level)
            $testTitle = "IntegrationTest-Playlist-Items-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $script:itemTestPlaylist = New-PatPlaylist -Title $testTitle -RatingKey $script:testRatingKey -PassThru -Confirm:$false
            $null = $script:createdPlaylistIds.Add($script:itemTestPlaylist.PlaylistId)

            # Get a different media item to add (to avoid duplicates)
            $script:additionalRatingKey = $null
            try {
                $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
                if ($libraries -and $libraries.Directory) {
                    foreach ($lib in $libraries.Directory) {
                        $items = Get-PatLibraryItem -SectionId $lib.key -ErrorAction SilentlyContinue | Select-Object -First 2
                        if ($items -and $items.Count -ge 2) {
                            $script:additionalRatingKey = [int]$items[1].ratingKey
                            break
                        }
                    }
                }
            }
            catch {
                Write-Warning "Could not find additional test media item: $($_.Exception.Message)"
            }
        }

        It 'Adds item to playlist with Add-PatPlaylistItem' {
            if (-not $script:additionalRatingKey) {
                Set-ItResult -Skipped -Because 'No additional media items available for testing'
                return
            }

            { Add-PatPlaylistItem -PlaylistId $script:itemTestPlaylist.PlaylistId -RatingKey $script:additionalRatingKey -Confirm:$false } |
                Should -Not -Throw

            # Verify item was added (should have 2 items now: initial + added)
            $playlist = Get-PatPlaylist -PlaylistId $script:itemTestPlaylist.PlaylistId -IncludeItems
            $playlist.ItemCount | Should -Be 2
        }

        It 'Removes item from playlist with Remove-PatPlaylistItem' {
            # Get current playlist items
            $playlist = Get-PatPlaylist -PlaylistId $script:itemTestPlaylist.PlaylistId -IncludeItems

            if ($playlist.Items.Count -eq 0) {
                Set-ItResult -Skipped -Because 'Playlist has no items to remove'
                return
            }

            $itemToRemove = $playlist.Items[0]
            $initialCount = $playlist.ItemCount

            { Remove-PatPlaylistItem -PlaylistId $script:itemTestPlaylist.PlaylistId -PlaylistItemId $itemToRemove.PlaylistItemId -Confirm:$false } |
                Should -Not -Throw

            # Verify item was removed
            $updatedPlaylist = Get-PatPlaylist -PlaylistId $script:itemTestPlaylist.PlaylistId
            $updatedPlaylist.ItemCount | Should -BeLessThan $initialCount
        }
    }
}

Describe 'Playlist WhatIf Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-PlaylistWhatIf' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Discover a test media item for creating playlists (required by Plex API)
        $script:whatIfRatingKey = $null
        try {
            $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
            if ($libraries -and $libraries.Directory) {
                foreach ($lib in $libraries.Directory) {
                    $items = Get-PatLibraryItem -SectionId $lib.key -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($items -and $items.ratingKey) {
                        $script:whatIfRatingKey = [int]$items.ratingKey
                        break
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not find test media item for WhatIf tests: $($_.Exception.Message)"
        }
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'WhatIf behavior (safe to run)' {

        It 'New-PatPlaylist WhatIf does not create playlist' {
            if (-not $script:whatIfRatingKey) {
                Set-ItResult -Skipped -Because 'No media items available for testing'
                return
            }

            $countBefore = (Get-PatPlaylist).Count

            New-PatPlaylist -Title 'WhatIf-Test-Playlist' -RatingKey $script:whatIfRatingKey -WhatIf

            $countAfter = (Get-PatPlaylist).Count
            $countAfter | Should -Be $countBefore
        }

        It 'Remove-PatPlaylist WhatIf does not delete playlist' {
            $playlists = Get-PatPlaylist
            if ($playlists) {
                $countBefore = $playlists.Count

                Remove-PatPlaylist -PlaylistId $playlists[0].PlaylistId -WhatIf

                $countAfter = (Get-PatPlaylist).Count
                $countAfter | Should -Be $countBefore
            }
            else {
                Set-ItResult -Skipped -Because 'No playlists exist to test WhatIf'
            }
        }
    }
}
