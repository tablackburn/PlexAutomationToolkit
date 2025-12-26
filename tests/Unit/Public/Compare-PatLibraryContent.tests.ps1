BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Compare-PatLibraryContent' {

    BeforeAll {
        # Mock library items
        $script:beforeItems = @(
            [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
            [PSCustomObject]@{ ratingKey = '2'; title = 'Movie B' }
            [PSCustomObject]@{ ratingKey = '3'; title = 'Movie C' }
        )

        $script:afterItemsWithAddition = @(
            [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
            [PSCustomObject]@{ ratingKey = '2'; title = 'Movie B' }
            [PSCustomObject]@{ ratingKey = '3'; title = 'Movie C' }
            [PSCustomObject]@{ ratingKey = '4'; title = 'Movie D' }  # New
        )

        $script:afterItemsWithRemoval = @(
            [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
            [PSCustomObject]@{ ratingKey = '3'; title = 'Movie C' }
            # Movie B removed
        )

        $script:afterItemsNoChanges = @(
            [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
            [PSCustomObject]@{ ratingKey = '2'; title = 'Movie B' }
            [PSCustomObject]@{ ratingKey = '3'; title = 'Movie C' }
        )
    }

    Context 'When items are added' {
        It 'Detects added items' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithAddition
            $added = $result | Where-Object ChangeType -eq 'Added'
            $added.Count | Should -Be 1
            $added[0].Title | Should -Be 'Movie D'
        }

        It 'Returns correct ratingKey for added items' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithAddition
            $added = $result | Where-Object ChangeType -eq 'Added'
            $added[0].RatingKey | Should -Be '4'
        }
    }

    Context 'When items are removed' {
        It 'Detects removed items' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithRemoval
            $removed = $result | Where-Object ChangeType -eq 'Removed'
            $removed.Count | Should -Be 1
            $removed[0].Title | Should -Be 'Movie B'
        }

        It 'Returns correct ratingKey for removed items' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithRemoval
            $removed = $result | Where-Object ChangeType -eq 'Removed'
            $removed[0].RatingKey | Should -Be '2'
        }
    }

    Context 'When no changes' {
        It 'Returns empty collection' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsNoChanges
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When before is empty' {
        It 'Treats all items as added' {
            $result = Compare-PatLibraryContent -Before @() -After $script:beforeItems
            $added = $result | Where-Object ChangeType -eq 'Added'
            $added.Count | Should -Be 3
        }
    }

    Context 'When after is empty' {
        It 'Treats all items as removed' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After @()
            $removed = $result | Where-Object ChangeType -eq 'Removed'
            $removed.Count | Should -Be 3
        }
    }

    Context 'When both are empty' {
        It 'Returns empty collection' {
            $result = Compare-PatLibraryContent -Before @() -After @()
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using custom key property' {
        BeforeAll {
            $script:itemsByTitle1 = @(
                [PSCustomObject]@{ ratingKey = '1'; title = 'Alpha' }
                [PSCustomObject]@{ ratingKey = '2'; title = 'Beta' }
            )

            $script:itemsByTitle2 = @(
                [PSCustomObject]@{ ratingKey = '99'; title = 'Alpha' }  # Same title, different key
                [PSCustomObject]@{ ratingKey = '100'; title = 'Gamma' }  # New title
            )
        }

        It 'Uses specified key property for comparison' {
            $result = Compare-PatLibraryContent -Before $script:itemsByTitle1 -After $script:itemsByTitle2 -KeyProperty 'title'
            $added = $result | Where-Object ChangeType -eq 'Added'
            $removed = $result | Where-Object ChangeType -eq 'Removed'

            $added.Count | Should -Be 1
            $added[0].Title | Should -Be 'Gamma'

            $removed.Count | Should -Be 1
            $removed[0].Title | Should -Be 'Beta'
        }
    }

    Context 'When null inputs are provided' {
        It 'Handles null before' {
            $result = Compare-PatLibraryContent -Before $null -After $script:beforeItems
            $added = $result | Where-Object ChangeType -eq 'Added'
            $added.Count | Should -Be 3
        }

        It 'Handles null after' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $null
            $removed = $result | Where-Object ChangeType -eq 'Removed'
            $removed.Count | Should -Be 3
        }
    }

    Context 'Output object structure' {
        It 'Returns objects with PSTypeName' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithAddition
            $result[0].PSTypeNames | Should -Contain 'PlexAutomationToolkit.LibraryChange'
        }

        It 'Includes original Item object' {
            $result = Compare-PatLibraryContent -Before $script:beforeItems -After $script:afterItemsWithAddition
            $result[0].Item | Should -Not -BeNullOrEmpty
        }
    }
}
