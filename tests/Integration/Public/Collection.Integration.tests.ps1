BeforeDiscovery {
    # Check if integration tests should run
    $script:integrationEnabled = $false
    $script:mutationTestsEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true
        Write-Host "Collection integration tests ENABLED - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green

        if ($env:PLEX_ALLOW_MUTATIONS -eq 'true') {
            $script:mutationTestsEnabled = $true
            Write-Host "Mutation tests ENABLED - Collections will be created/modified" -ForegroundColor Yellow
        }
        else {
            Write-Host "Mutation tests DISABLED - Set PLEX_ALLOW_MUTATIONS=true to enable" -ForegroundColor Yellow
        }
    }
    else {
        $missingVars = @()
        if (-not $env:PLEX_SERVER_URI) { $missingVars += 'PLEX_SERVER_URI' }
        if (-not $env:PLEX_TOKEN) { $missingVars += 'PLEX_TOKEN' }

        Write-Host "Collection integration tests SKIPPED - Missing: $($missingVars -join ', ')" -ForegroundColor Yellow
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

Describe 'Get-PatCollection Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-Collection' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Find a library to use for testing
        $script:testLibrary = $null
        try {
            $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
            if ($libraries -and $libraries.Directory) {
                $script:testLibrary = $libraries.Directory | Select-Object -First 1
            }
        }
        catch {
            Write-Warning "Could not find test library: $($_.Exception.Message)"
        }
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Collection retrieval' {

        It 'Successfully queries collections endpoint' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            { Get-PatCollection -LibraryId $script:testLibrary.key } | Should -Not -Throw
        }

        It 'Returns array or null (depending on existing collections)' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            $result = Get-PatCollection -LibraryId $script:testLibrary.key
            # Result can be null/empty or an array of collections
            if ($result) {
                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Collection objects have expected properties when collections exist' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            $result = Get-PatCollection -LibraryId $script:testLibrary.key
            if ($result) {
                $result[0].PSObject.Properties.Name | Should -Contain 'CollectionId'
                $result[0].PSObject.Properties.Name | Should -Contain 'Title'
                $result[0].PSObject.Properties.Name | Should -Contain 'LibraryId'
                $result[0].PSObject.Properties.Name | Should -Contain 'ItemCount'
            }
            else {
                Set-ItResult -Skipped -Because 'No collections exist to test properties'
            }
        }

        It 'Collection objects have correct PSTypeName' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            $result = Get-PatCollection -LibraryId $script:testLibrary.key
            if ($result) {
                $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
            }
            else {
                Set-ItResult -Skipped -Because 'No collections exist to test type'
            }
        }

        It 'Accepts explicit ServerUri parameter' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            { Get-PatCollection -LibraryId $script:testLibrary.key -ServerUri $env:PLEX_SERVER_URI -Token $env:PLEX_TOKEN } | Should -Not -Throw
        }
    }

    Context 'Collection retrieval with items' {

        It 'IncludeItems parameter does not throw' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            { Get-PatCollection -LibraryId $script:testLibrary.key -IncludeItems } | Should -Not -Throw
        }

        It 'Collections have Items property when IncludeItems specified' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }
            $result = Get-PatCollection -LibraryId $script:testLibrary.key -IncludeItems
            if ($result) {
                $result[0].PSObject.Properties.Name | Should -Contain 'Items'
            }
            else {
                Set-ItResult -Skipped -Because 'No collections exist to test Items property'
            }
        }
    }
}

Describe 'Collection CRUD Integration Tests' -Skip:(-not $script:mutationTestsEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-CollectionCRUD' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Track created collections for cleanup
        $script:createdCollectionIds = [System.Collections.ArrayList]::new()

        # Find a library and media item to use for testing
        $script:testLibrary = $null
        $script:testMediaItem = $null
        try {
            $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
            if ($libraries -and $libraries.Directory) {
                foreach ($lib in $libraries.Directory) {
                    $items = Get-PatLibraryItem -SectionId $lib.key -ErrorAction SilentlyContinue | Select-Object -First 2
                    if ($items -and $items.Count -ge 1) {
                        $script:testLibrary = $lib
                        $script:testMediaItem = $items[0]
                        $script:testMediaItem2 = if ($items.Count -ge 2) { $items[1] } else { $null }
                        break
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not find test library/items: $($_.Exception.Message)"
        }
    }

    AfterAll {
        # Clean up any created test collections
        foreach ($collectionId in $script:createdCollectionIds) {
            try {
                Remove-PatCollection -CollectionId $collectionId -Confirm:$false -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Failed to clean up collection $collectionId`: $($_.Exception.Message)"
            }
        }

        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Create collection' {
        It 'Creates a new collection with New-PatCollection' {
            if (-not $script:testLibrary -or -not $script:testMediaItem) {
                Set-ItResult -Skipped -Because 'No library or media item available for testing'
                return
            }

            $testTitle = "IntegrationTest-Collection-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $ratingKey = [int]$script:testMediaItem.ratingKey

            $result = New-PatCollection -Title $testTitle -LibraryId $script:testLibrary.key -RatingKey $ratingKey -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Title | Should -Be $testTitle
            $result.CollectionId | Should -BeGreaterThan 0

            # Track for cleanup
            $null = $script:createdCollectionIds.Add($result.CollectionId)
        }

        It 'Created collection is retrievable via Get-PatCollection' {
            if (-not $script:testLibrary -or -not $script:testMediaItem) {
                Set-ItResult -Skipped -Because 'No library or media item available for testing'
                return
            }

            $testTitle = "IntegrationTest-Collection-Get-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $ratingKey = [int]$script:testMediaItem.ratingKey

            $created = New-PatCollection -Title $testTitle -LibraryId $script:testLibrary.key -RatingKey $ratingKey -PassThru -Confirm:$false
            $null = $script:createdCollectionIds.Add($created.CollectionId)

            $retrieved = Get-PatCollection -CollectionId $created.CollectionId

            $retrieved | Should -Not -BeNullOrEmpty
            $retrieved.Title | Should -Be $testTitle
        }
    }

    Context 'Delete collection' {
        It 'Removes a collection with Remove-PatCollection' {
            if (-not $script:testLibrary -or -not $script:testMediaItem) {
                Set-ItResult -Skipped -Because 'No library or media item available for testing'
                return
            }

            $testTitle = "IntegrationTest-Collection-Delete-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $ratingKey = [int]$script:testMediaItem.ratingKey

            # Create a collection to delete
            $created = New-PatCollection -Title $testTitle -LibraryId $script:testLibrary.key -RatingKey $ratingKey -PassThru -Confirm:$false

            # Delete it
            { Remove-PatCollection -CollectionId $created.CollectionId -Confirm:$false } | Should -Not -Throw

            # Verify it's gone
            { Get-PatCollection -CollectionId $created.CollectionId } | Should -Throw
        }

        It 'PassThru returns removed collection info' {
            if (-not $script:testLibrary -or -not $script:testMediaItem) {
                Set-ItResult -Skipped -Because 'No library or media item available for testing'
                return
            }

            $testTitle = "IntegrationTest-Collection-PassThru-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $ratingKey = [int]$script:testMediaItem.ratingKey

            $created = New-PatCollection -Title $testTitle -LibraryId $script:testLibrary.key -RatingKey $ratingKey -PassThru -Confirm:$false

            $removed = Remove-PatCollection -CollectionId $created.CollectionId -PassThru -Confirm:$false

            $removed | Should -Not -BeNullOrEmpty
            $removed.Title | Should -Be $testTitle
        }
    }

    Context 'Add and remove collection items' {
        BeforeAll {
            # Create a test collection for item operations
            if ($script:testLibrary -and $script:testMediaItem) {
                $testTitle = "IntegrationTest-Collection-Items-$(Get-Date -Format 'yyyyMMddHHmmss')"
                $ratingKey = [int]$script:testMediaItem.ratingKey
                $script:itemTestCollection = New-PatCollection -Title $testTitle -LibraryId $script:testLibrary.key -RatingKey $ratingKey -PassThru -Confirm:$false
                $null = $script:createdCollectionIds.Add($script:itemTestCollection.CollectionId)
            }
        }

        It 'Adds item to collection with Add-PatCollectionItem' {
            if (-not $script:testMediaItem2 -or -not $script:itemTestCollection) {
                Set-ItResult -Skipped -Because 'Not enough media items available for testing'
                return
            }

            $ratingKey = [int]$script:testMediaItem2.ratingKey
            $initialCount = $script:itemTestCollection.ItemCount

            { Add-PatCollectionItem -CollectionId $script:itemTestCollection.CollectionId -RatingKey $ratingKey -Confirm:$false } |
                Should -Not -Throw

            # Verify item was added
            $collection = Get-PatCollection -CollectionId $script:itemTestCollection.CollectionId
            $collection.ItemCount | Should -BeGreaterThan $initialCount
        }

        It 'Removes item from collection with Remove-PatCollectionItem' {
            if (-not $script:itemTestCollection) {
                Set-ItResult -Skipped -Because 'No test collection available'
                return
            }

            # Get current collection items
            $collection = Get-PatCollection -CollectionId $script:itemTestCollection.CollectionId -IncludeItems

            if ($collection.Items.Count -eq 0) {
                Set-ItResult -Skipped -Because 'Collection has no items to remove'
                return
            }

            $itemToRemove = $collection.Items[0]
            $initialCount = $collection.ItemCount

            { Remove-PatCollectionItem -CollectionId $script:itemTestCollection.CollectionId -RatingKey $itemToRemove.RatingKey -Confirm:$false } |
                Should -Not -Throw

            # Verify item was removed
            $updatedCollection = Get-PatCollection -CollectionId $script:itemTestCollection.CollectionId
            $updatedCollection.ItemCount | Should -BeLessThan $initialCount
        }
    }
}

Describe 'Collection WhatIf Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-CollectionWhatIf' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Find a library and media item for testing
        $script:testLibrary = $null
        $script:testMediaItem = $null
        try {
            $libraries = Get-PatLibrary -ErrorAction SilentlyContinue
            if ($libraries -and $libraries.Directory) {
                foreach ($lib in $libraries.Directory) {
                    $items = Get-PatLibraryItem -SectionId $lib.key -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($items) {
                        $script:testLibrary = $lib
                        $script:testMediaItem = $items
                        break
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not find test library/items: $($_.Exception.Message)"
        }
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'WhatIf behavior (safe to run)' {

        It 'New-PatCollection WhatIf does not create collection' {
            if (-not $script:testLibrary -or -not $script:testMediaItem) {
                Set-ItResult -Skipped -Because 'No library or media item available for testing'
                return
            }

            $countBefore = (Get-PatCollection -LibraryId $script:testLibrary.key).Count
            $ratingKey = [int]$script:testMediaItem.ratingKey

            New-PatCollection -Title 'WhatIf-Test-Collection' -LibraryId $script:testLibrary.key -RatingKey $ratingKey -WhatIf

            $countAfter = (Get-PatCollection -LibraryId $script:testLibrary.key).Count
            $countAfter | Should -Be $countBefore
        }

        It 'Remove-PatCollection WhatIf does not delete collection' {
            if (-not $script:testLibrary) {
                Set-ItResult -Skipped -Because 'No library available for testing'
                return
            }

            $collections = Get-PatCollection -LibraryId $script:testLibrary.key
            if ($collections) {
                $countBefore = $collections.Count

                Remove-PatCollection -CollectionId $collections[0].CollectionId -WhatIf

                $countAfter = (Get-PatCollection -LibraryId $script:testLibrary.key).Count
                $countAfter | Should -Be $countBefore
            }
            else {
                Set-ItResult -Skipped -Because 'No collections exist to test WhatIf'
            }
        }
    }
}
