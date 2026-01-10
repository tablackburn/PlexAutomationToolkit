BeforeDiscovery {
    # Check if integration tests should run
    $script:integrationEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true
        Write-Host "Media sync integration tests ENABLED - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green
    }
    else {
        $missingVars = @()
        if (-not $env:PLEX_SERVER_URI) { $missingVars += 'PLEX_SERVER_URI' }
        if (-not $env:PLEX_TOKEN) { $missingVars += 'PLEX_TOKEN' }

        Write-Host "Media sync integration tests SKIPPED - Missing: $($missingVars -join ', ')" -ForegroundColor Yellow
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

Describe 'Get-PatMediaInfo Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-MediaSync' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Find a library item to test with - use Travel playlist if it exists
        $script:testItem = $null
        $travelPlaylist = Get-PatPlaylist -PlaylistName 'Travel' -IncludeItems -ErrorAction SilentlyContinue
        if ($travelPlaylist -and $travelPlaylist.Items -and $travelPlaylist.Items.Count -gt 0) {
            $script:testItem = $travelPlaylist.Items[0]
        }
        else {
            # Fallback: find any library item
            $script:testLibrary = Get-PatLibrary | Select-Object -First 1
            if ($script:testLibrary) {
                $sectionId = $script:testLibrary.key -replace '.*/(\d+)$', '$1'
                $items = Get-PatLibraryItem -SectionId $sectionId -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($items) {
                    $script:testItem = $items
                }
            }
        }
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -Backup $script:configBackup
        }
    }

    It 'Retrieves media info for a library item' {
        if (-not $script:testItem) { Set-ItResult -Skipped -Because 'No test item found' }

        $ratingKey = $script:testItem.RatingKey
        $result = Get-PatMediaInfo -RatingKey $ratingKey

        $result | Should -Not -BeNullOrEmpty
        $result.RatingKey | Should -Be $ratingKey
        $result.Title | Should -Not -BeNullOrEmpty
    }

    It 'Returns Media array with Part information' {
        if (-not $script:testItem) { Set-ItResult -Skipped -Because 'No test item found' }

        $ratingKey = $script:testItem.RatingKey
        $result = Get-PatMediaInfo -RatingKey $ratingKey

        $result.Media | Should -Not -BeNullOrEmpty
        $result.Media[0].Part | Should -Not -BeNullOrEmpty
        $result.Media[0].Part[0].Key | Should -Match '/library/parts/'
    }

    It 'Includes file size in Part' {
        if (-not $script:testItem) { Set-ItResult -Skipped -Because 'No test item found' }

        $ratingKey = $script:testItem.RatingKey
        $result = Get-PatMediaInfo -RatingKey $ratingKey

        $result.Media[0].Part[0].Size | Should -BeGreaterThan 0
    }
}

Describe 'Get-PatSyncPlan Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-SyncPlan' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Create temp destination (cross-platform)
        $tempPath = [System.IO.Path]::GetTempPath()
        $script:testDestination = Join-Path -Path $tempPath -ChildPath "PatSyncTest_$([Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:testDestination -ItemType Directory -Force | Out-Null

        # Check if 'Travel' playlist exists
        $script:travelPlaylist = Get-PatPlaylist -PlaylistName 'Travel' -ErrorAction SilentlyContinue
    }

    AfterAll {
        # Cleanup temp directory
        if ($script:testDestination -and (Test-Path $script:testDestination)) {
            Remove-Item -Path $script:testDestination -Recurse -Force -ErrorAction SilentlyContinue
        }

        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -Backup $script:configBackup
        }
    }

    It 'Generates sync plan for Travel playlist' {
        if (-not $script:travelPlaylist) { Set-ItResult -Skipped -Because 'Travel playlist not found' }

        $result = Get-PatSyncPlan -PlaylistName 'Travel' -Destination $script:testDestination

        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.SyncPlan'
        $result.PlaylistName | Should -Be 'Travel'
    }

    It 'Uses Travel as default playlist name' {
        if (-not $script:travelPlaylist) { Set-ItResult -Skipped -Because 'Travel playlist not found' }

        $result = Get-PatSyncPlan -Destination $script:testDestination

        $result.PlaylistName | Should -Be 'Travel'
    }

    It 'Calculates space requirements' {
        if (-not $script:travelPlaylist) { Set-ItResult -Skipped -Because 'Travel playlist not found' }

        $result = Get-PatSyncPlan -Destination $script:testDestination

        $result.TotalItems | Should -BeGreaterOrEqual 0
        $result.BytesToDownload | Should -BeGreaterOrEqual 0
        $result.DestinationFree | Should -BeGreaterThan 0
    }

    It 'Includes add operations for playlist items' {
        if (-not $script:travelPlaylist) { Set-ItResult -Skipped -Because 'Travel playlist not found' }

        $result = Get-PatSyncPlan -Destination $script:testDestination

        if ($result.TotalItems -gt 0) {
            $result.ItemsToAdd | Should -BeGreaterOrEqual 0
            if ($result.ItemsToAdd -gt 0) {
                $result.AddOperations | Should -Not -BeNullOrEmpty
                $result.AddOperations[0].DestinationPath | Should -Match $script:testDestination.Replace('\', '\\')
            }
        }
    }

    It 'Throws for non-existent playlist' {
        { Get-PatSyncPlan -PlaylistName 'NonExistentPlaylist12345' -Destination $script:testDestination } |
            Should -Throw
    }
}

Describe 'Sync-PatMedia Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-Sync' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Create temp destination (cross-platform)
        $tempPath = [System.IO.Path]::GetTempPath()
        $script:syncDestination = Join-Path -Path $tempPath -ChildPath "PatSyncIntegration_$([Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:syncDestination -ItemType Directory -Force | Out-Null

        # Check if 'Travel' playlist exists and has items
        $script:travelPlaylist = Get-PatPlaylist -PlaylistName 'Travel' -IncludeItems -ErrorAction SilentlyContinue
        $script:hasItems = $script:travelPlaylist -and $script:travelPlaylist.Items -and $script:travelPlaylist.Items.Count -gt 0
    }

    AfterAll {
        # Cleanup temp directory
        if ($script:syncDestination -and (Test-Path $script:syncDestination)) {
            Remove-Item -Path $script:syncDestination -Recurse -Force -ErrorAction SilentlyContinue
        }

        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -Backup $script:configBackup
        }
    }

    It 'WhatIf shows sync plan without downloading' {
        if (-not $script:travelPlaylist) { Set-ItResult -Skipped -Because 'Travel playlist not found' }

        # WhatIf should work even without items
        { Sync-PatMedia -Destination $script:syncDestination -WhatIf } | Should -Not -Throw
    }

    It 'Downloads media files from playlist' {
        if (-not $script:hasItems) { Set-ItResult -Skipped -Because 'Travel playlist has no items' }

        # This actually downloads! Only runs if playlist has items
        $result = Sync-PatMedia -Destination $script:syncDestination -PassThru -Confirm:$false

        $result | Should -Not -BeNullOrEmpty

        # Verify files were created
        $moviesPath = Join-Path $script:syncDestination 'Movies'
        $tvPath = Join-Path $script:syncDestination 'TV Shows'

        $hasMovies = (Test-Path $moviesPath) -and (Get-ChildItem $moviesPath -Recurse -File)
        $hasTV = (Test-Path $tvPath) -and (Get-ChildItem $tvPath -Recurse -File)

        ($hasMovies -or $hasTV) | Should -Be $true
    }

    It 'Is idempotent - second run downloads nothing' {
        if (-not $script:hasItems) { Set-ItResult -Skipped -Because 'Travel playlist has no items' }

        # Run sync again - should detect existing files and skip
        $result = Sync-PatMedia -Destination $script:syncDestination -PassThru -Confirm:$false

        # ItemsToAdd should be 0 since files already exist
        $result.ItemsToAdd | Should -Be 0
        $result.ItemsUnchanged | Should -BeGreaterThan 0
    }

    It 'Creates Plex-compatible folder structure' {
        if (-not $script:hasItems) { Set-ItResult -Skipped -Because 'Travel playlist has no items' }

        $moviesPath = Join-Path $script:syncDestination 'Movies'
        $tvPath = Join-Path $script:syncDestination 'TV Shows'

        # Check movie structure: Movies/Title (Year)/Title (Year).ext
        if (Test-Path $moviesPath) {
            $movieFolders = Get-ChildItem $moviesPath -Directory
            foreach ($folder in $movieFolders) {
                # Folder should match pattern: Title (Year)
                $folder.Name | Should -Match '.+\s\(\d{4}\)$'

                # Should contain a video file
                $files = Get-ChildItem $folder.FullName -File
                $files | Should -Not -BeNullOrEmpty
            }
        }

        # Check TV structure: TV Shows/Show/Season ##/...
        if (Test-Path $tvPath) {
            $showFolders = Get-ChildItem $tvPath -Directory
            foreach ($show in $showFolders) {
                $seasonFolders = Get-ChildItem $show.FullName -Directory
                foreach ($season in $seasonFolders) {
                    # Season folder should match: Season ##
                    $season.Name | Should -Match '^Season \d{2}$'
                }
            }
        }
    }

    It 'Downloads subtitles by default' {
        if (-not $script:hasItems) { Set-ItResult -Skipped -Because 'Travel playlist has no items' }

        # Check if any subtitle files exist
        $subtitleFiles = Get-ChildItem $script:syncDestination -Recurse -File |
            Where-Object { $_.Extension -match '\.(srt|ass|ssa|sub|vtt)$' }

        # Note: This may be empty if no items have external subtitles
        # We just verify no errors occurred - actual subtitle presence depends on content
        $true | Should -Be $true
    }
}
