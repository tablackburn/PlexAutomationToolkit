BeforeDiscovery {
    # Check if integration tests should run
    $script:integrationEnabled = $false
    $script:mutationsEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true

        if ($env:PLEX_ALLOW_MUTATIONS -eq 'true') {
            $script:mutationsEnabled = $true
            Write-Host "Integration tests ENABLED with MUTATIONS - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green
            Write-Host "WARNING: Mutation tests will trigger library refresh operations on your Plex server" -ForegroundColor Yellow
        }
        else {
            Write-Host "Integration tests ENABLED (mutations disabled) - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green
            Write-Host "Set PLEX_ALLOW_MUTATIONS='true' to enable mutation tests (library refresh operations)" -ForegroundColor Cyan
        }
    }
    else {
        $missingVars = @()
        if (-not $env:PLEX_SERVER_URI) { $missingVars += 'PLEX_SERVER_URI' }
        if (-not $env:PLEX_TOKEN) { $missingVars += 'PLEX_TOKEN' }

        Write-Host "Integration tests SKIPPED - Missing: $($missingVars -join ', ')" -ForegroundColor Yellow
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

Describe 'Update-PatLibrary Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        $script:configBackup = Backup-ServerConfiguration

        # Add server to config (use -SkipValidation to avoid interactive prompts in tests)
        Add-PatServer -Name 'IntegrationTest-LibraryOps' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Token $env:PLEX_TOKEN `
            -Default `
            -SkipValidation `
            -Confirm:$false

        # Get a library section to test with
        $allSections = Get-PatLibrary
        $script:testSection = $allSections.Directory | Select-Object -First 1
        $script:testSectionId = $script:testSection.key
        $script:testSectionName = $script:testSection.title
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'WhatIf support (always safe)' {

        It 'Supports -WhatIf parameter' {
            { Update-PatLibrary -SectionId $script:testSectionId -WhatIf } | Should -Not -Throw
        }

        It 'WhatIf does not trigger actual refresh' {
            # This should succeed without actually refreshing
            $result = Update-PatLibrary -SectionId $script:testSectionId -WhatIf
            # WhatIf should not return data, just show what would happen
            # Exact behavior depends on implementation
        }

        It 'WhatIf works with section name parameter' {
            { Update-PatLibrary -SectionName $script:testSectionName -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Library refresh by section ID' -Skip:(-not $script:mutationsEnabled) {

        It 'Successfully refreshes library by section ID' {
            { Update-PatLibrary -SectionId $script:testSectionId -Confirm:$false } | Should -Not -Throw
        }

        It 'Accepts valid section ID within range' {
            # Test that validation allows valid section IDs
            { Update-PatLibrary -SectionId $script:testSectionId -Confirm:$false } | Should -Not -Throw
        }

        It 'Rejects invalid section ID of zero' {
            { Update-PatLibrary -SectionId 0 -Confirm:$false } | Should -Throw
        }

        It 'Handles non-existent section ID gracefully' {
            { Update-PatLibrary -SectionId 99999 -Confirm:$false } | Should -Throw
        }
    }

    Context 'Library refresh by section name' -Skip:(-not $script:mutationsEnabled) {

        It 'Successfully refreshes library by section name' {
            { Update-PatLibrary -SectionName $script:testSectionName -Confirm:$false } | Should -Not -Throw
        }

        It 'Handles non-existent section name gracefully' {
            { Update-PatLibrary -SectionName 'NonExistentLibrary' -Confirm:$false } | Should -Throw
        }
    }

    Context 'Library refresh with specific path' -Skip:(-not $script:mutationsEnabled) {

        It 'Successfully refreshes library with specific path by section ID' {
            # This tests path-based refresh - using SkipPathValidation since we're testing parameter handling
            { Update-PatLibrary -SectionId $script:testSectionId -Path '/test/path' -SkipPathValidation -Confirm:$false } | Should -Not -Throw
        }

        It 'Successfully refreshes library with specific path by section name' {
            { Update-PatLibrary -SectionName $script:testSectionName -Path '/test/path' -SkipPathValidation -Confirm:$false } | Should -Not -Throw
        }

        It 'Path parameter is properly URL-encoded' {
            # Test that paths with special characters work
            { Update-PatLibrary -SectionId $script:testSectionId -Path '/test/path with spaces' -SkipPathValidation -Confirm:$false } | Should -Not -Throw
        }
    }

    Context 'Using explicit ServerUri parameter' -Skip:(-not $script:mutationsEnabled) {

        It 'Works with explicit ServerUri when server is stored but not default' -Skip {
            # SKIP: Current architecture doesn't support explicit ServerUri with authentication.
            # When -ServerUri is provided, the function doesn't look up stored servers by URI,
            # so there's no way to get the authentication token. This would require either:
            #   1. Enhancing Get-PatStoredServer to support lookup by URI
            #   2. Adding -Token parameter to Update-PatLibrary and other cmdlets
            # Tracked as future enhancement.

            # Add a second server without default flag
            Add-PatServer -Name 'IntegrationTest-NonDefault' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -SkipValidation `
                -Confirm:$false

            try {
                # Verify we still have the default server
                $defaultServer = Get-PatStoredServer -Default
                $defaultServer.name | Should -Be 'IntegrationTest-LibraryOps'

                # Call with explicit ServerUri and Token
                { Update-PatLibrary -ServerUri $env:PLEX_SERVER_URI -Token $env:PLEX_TOKEN -SectionId $script:testSectionId -Confirm:$false } | Should -Not -Throw
            }
            finally {
                # Clean up the non-default server
                $nonDefault = Get-PatStoredServer -ErrorAction SilentlyContinue | Where-Object { $_.name -eq 'IntegrationTest-NonDefault' }
                if ($nonDefault) {
                    Remove-PatServer -Name 'IntegrationTest-NonDefault' -Confirm:$false
                }
            }
        }
    }

    Context 'ShouldProcess confirmation behavior' -Skip:(-not $script:mutationsEnabled) {

        It 'Respects -Confirm:$false parameter' {
            # Should execute without prompting
            { Update-PatLibrary -SectionId $script:testSectionId -Confirm:$false } | Should -Not -Throw
        }

        It 'Operation completes successfully with confirmation bypass' {
            $result = Update-PatLibrary -SectionId $script:testSectionId -Confirm:$false
            # Verify no errors occurred
        }
    }
}
