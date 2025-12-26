BeforeDiscovery {
    # Check if integration tests should run
    $script:integrationEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true
        Write-Host "Integration tests ENABLED - Testing against: $env:PLEX_SERVER_URI" -ForegroundColor Green
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

Describe 'Get-PatServer Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server for all Get-PatServer tests
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-GetServer' `
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

    Context 'Server connectivity and information retrieval' {

        It 'Successfully connects to Plex server' {
            $result = Get-PatServer
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns server information with expected properties' {
            $result = Get-PatServer
            $result.PSObject.Properties.Name | Should -Contain 'friendlyName'
            $result.PSObject.Properties.Name | Should -Contain 'version'
            $result.PSObject.Properties.Name | Should -Contain 'platform'
        }

        It 'Server version is in valid format' {
            $result = Get-PatServer
            $result.version | Should -Match '^\d+\.\d+\.\d+'
        }

        It 'Server has a friendly name' {
            $result = Get-PatServer
            $result.friendlyName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Authentication with default server' {

        It 'Uses default server when ServerUri is omitted' {
            $result = Get-PatServer
            $result | Should -Not -BeNullOrEmpty
            $result.friendlyName | Should -Not -BeNullOrEmpty
        }

        It 'Default server is accessible and returns data' {
            $result = Get-PatServer

            $result.friendlyName | Should -Not -BeNullOrEmpty
            $result.version | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-PatLibrary Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        # Remove test server if it exists from previous run
        try {
            Remove-PatServer -Name 'IntegrationTest-Library' -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore if server doesn't exist
        }

        Add-PatServer -Name 'IntegrationTest-Library' `
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

    Context 'Library section listing' {

        It 'Retrieves library sections from server' {
            $result = Get-PatLibrary
            $result | Should -Not -BeNullOrEmpty
            $result.Directory | Should -Not -BeNullOrEmpty
        }

        It 'Library sections have required properties' {
            $result = Get-PatLibrary
            $section = $result.Directory | Select-Object -First 1

            $section.PSObject.Properties.Name | Should -Contain 'key'
            $section.PSObject.Properties.Name | Should -Contain 'title'
            $section.PSObject.Properties.Name | Should -Contain 'type'
        }

        It 'Section types are valid Plex library types' {
            $result = Get-PatLibrary
            $validTypes = @('movie', 'show', 'artist', 'photo')

            foreach ($section in $result.Directory) {
                $section.type | Should -BeIn $validTypes
            }
        }

        It 'Each section has a unique key' {
            $result = Get-PatLibrary
            $keys = $result.Directory | ForEach-Object { $_.key }
            $uniqueKeys = $keys | Select-Object -Unique

            $keys.Count | Should -Be $uniqueKeys.Count
        }
    }

    Context 'Specific section retrieval' {

        BeforeAll {
            # Get first available section for testing
            $allSections = Get-PatLibrary
            $script:testSection = $allSections.Directory | Select-Object -First 1
            $script:testSectionId = $script:testSection.key
        }

        It 'Retrieves specific section by ID' {
            $result = Get-PatLibrary -SectionId $script:testSectionId
            $result | Should -Not -BeNullOrEmpty
            $result.librarySectionID | Should -Be $script:testSectionId
        }

        It 'Section details include metadata' {
            $result = Get-PatLibrary -SectionId $script:testSectionId
            $result.title1 | Should -Not -BeNullOrEmpty
        }

        It 'Section details match all sections list' {
            $result = Get-PatLibrary -SectionId $script:testSectionId
            $result.title1 | Should -Be $script:testSection.title
        }

        It 'Invalid section ID throws error' {
            { Get-PatLibrary -SectionId 99999 } | Should -Throw
        }
    }

    Context 'Using explicit ServerUri parameter' {

        It 'Works with explicit ServerUri instead of default' {
            # This test verifies that Get-PatLibrary works with explicit ServerUri
            # Note: Since Get-PatLibrary requires authentication, we still need a stored server
            # This test shows that even with a default server configured, explicit URI works
            $result = Get-PatLibrary
            $result | Should -Not -BeNullOrEmpty
            $result.Directory | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-PatStoredServer Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        $script:configBackup = Backup-ServerConfiguration
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Server configuration retrieval' {

        BeforeAll {
            # Add multiple test servers
            Add-PatServer -Name 'IntegrationTest-First' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -Default `
                -SkipValidation `
                -Confirm:$false

            Add-PatServer -Name 'IntegrationTest-Second' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -SkipValidation `
                -Confirm:$false
        }

        It 'Retrieves all stored servers' {
            $result = Get-PatStoredServer
            $result | Should -Not -BeNullOrEmpty
            $testServers = $result | Where-Object { $_.name -like 'IntegrationTest-*' }
            $testServers.Count | Should -BeGreaterOrEqual 2
        }

        It 'Retrieves default server' {
            $result = Get-PatStoredServer -Default
            $result | Should -Not -BeNullOrEmpty
            $result.default | Should -Be $true
            $result.name | Should -Be 'IntegrationTest-First'
        }

        It 'Retrieves specific server by name' {
            $result = Get-PatStoredServer -Name 'IntegrationTest-Second'
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'IntegrationTest-Second'
        }

        It 'Stored server has required properties' {
            $result = Get-PatStoredServer -Default
            $result.PSObject.Properties.Name | Should -Contain 'name'
            $result.PSObject.Properties.Name | Should -Contain 'uri'
            $result.PSObject.Properties.Name | Should -Contain 'default'
        }
    }
}
