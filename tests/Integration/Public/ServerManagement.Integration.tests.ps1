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

Describe 'Add-PatServer Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        $script:configBackup = Backup-ServerConfiguration
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Adding servers to configuration' {

        It 'Successfully adds a server with minimal parameters' {
            Add-PatServer -Name 'IntegrationTest-Minimal' `
                -ServerUri $env:PLEX_SERVER_URI `
                -SkipValidation `
                -Confirm:$false

            $result = Get-PatStoredServer -Name 'IntegrationTest-Minimal'
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'IntegrationTest-Minimal'
            $result.uri | Should -Be $env:PLEX_SERVER_URI
        }

        It 'Successfully adds a server with token' {
            Add-PatServer -Name 'IntegrationTest-WithToken' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -SkipValidation `
                -Confirm:$false

            $result = Get-PatStoredServer -Name 'IntegrationTest-WithToken'
            $result | Should -Not -BeNullOrEmpty
            $result.token | Should -Be $env:PLEX_TOKEN
        }

        It 'Successfully adds a server as default' {
            Add-PatServer -Name 'IntegrationTest-Default' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -Default `
                -SkipValidation `
                -Confirm:$false

            $result = Get-PatStoredServer -Default
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'IntegrationTest-Default'
            $result.default | Should -Be $true
        }

        It 'Only one server is marked as default' {
            # Add multiple servers with different default settings
            Add-PatServer -Name 'IntegrationTest-First' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Default `
                -SkipValidation `
                -Confirm:$false

            Add-PatServer -Name 'IntegrationTest-Second' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Default `
                -SkipValidation `
                -Confirm:$false

            $allServers = Get-PatStoredServer
            $defaultServers = $allServers | Where-Object { $_.default -eq $true }
            $defaultServers.Count | Should -Be 1
            $defaultServers[0].name | Should -Be 'IntegrationTest-Second'
        }

        It 'Rejects duplicate server names' {
            Add-PatServer -Name 'IntegrationTest-Duplicate' `
                -ServerUri $env:PLEX_SERVER_URI `
                -SkipValidation `
                -Confirm:$false

            { Add-PatServer -Name 'IntegrationTest-Duplicate' `
                    -ServerUri $env:PLEX_SERVER_URI `
                    -SkipValidation `
                    -Confirm:$false } | Should -Throw '*already exists*'
        }
    }

    Context 'Server persistence' {

        It 'Server persists after adding' {
            Add-PatServer -Name 'IntegrationTest-Persist' `
                -ServerUri $env:PLEX_SERVER_URI `
                -Token $env:PLEX_TOKEN `
                -SkipValidation `
                -Confirm:$false

            # Re-import module to simulate new session
            $moduleName = $Env:BHProjectName
            if (-not $moduleName) { $moduleName = 'PlexAutomationToolkit' }
            Get-Module $moduleName | Remove-Module -Force

            # Find the built module manifest
            $moduleManifest = Get-ChildItem -Path 'Output' -Filter '*.psd1' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($moduleManifest) {
                Import-Module -Name $moduleManifest.FullName -Verbose:$false -Force
            } else {
                # Fallback to source module
                Import-Module -Name "$PSScriptRoot/../../../PlexAutomationToolkit/PlexAutomationToolkit.psd1" -Verbose:$false -Force
            }

            $result = Get-PatStoredServer -Name 'IntegrationTest-Persist'
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Remove-PatServer Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        $script:configBackup = Backup-ServerConfiguration
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Removing servers from configuration' {

        BeforeAll {
            # Add test servers
            Add-PatServer -Name 'IntegrationTest-ToRemove' `
                -ServerUri $env:PLEX_SERVER_URI `
                -SkipValidation `
                -Confirm:$false
        }

        It 'Successfully removes an existing server' {
            Remove-PatServer -Name 'IntegrationTest-ToRemove' -Confirm:$false

            # Should throw when trying to get removed server
            { Get-PatStoredServer -Name 'IntegrationTest-ToRemove' } | Should -Throw '*No server found*'
        }

        It 'Handles non-existent server gracefully' {
            { Remove-PatServer -Name 'IntegrationTest-DoesNotExist' -Confirm:$false } | Should -Throw '*No server found*'
        }

        It 'Removal persists to configuration file' {
            Add-PatServer -Name 'IntegrationTest-RemovePersist' `
                -ServerUri $env:PLEX_SERVER_URI `
                -SkipValidation `
                -Confirm:$false

            Remove-PatServer -Name 'IntegrationTest-RemovePersist' -Confirm:$false

            # Re-import module to simulate new session
            $moduleName = $Env:BHProjectName
            if (-not $moduleName) { $moduleName = 'PlexAutomationToolkit' }
            Get-Module $moduleName | Remove-Module -Force

            $moduleManifest = Get-ChildItem -Path 'Output' -Filter '*.psd1' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($moduleManifest) {
                Import-Module -Name $moduleManifest.FullName -Verbose:$false -Force
            } else {
                Import-Module -Name "$PSScriptRoot/../../../PlexAutomationToolkit/PlexAutomationToolkit.psd1" -Verbose:$false -Force
            }

            # Should throw when trying to get removed server
            { Get-PatStoredServer -Name 'IntegrationTest-RemovePersist' } | Should -Throw '*No server found*'
        }
    }
}

Describe 'Set-PatDefaultServer Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        $script:configBackup = Backup-ServerConfiguration

        # Add multiple test servers
        Add-PatServer -Name 'IntegrationTest-Server1' `
            -ServerUri $env:PLEX_SERVER_URI `
            -Default `
            -SkipValidation `
            -Confirm:$false

        Add-PatServer -Name 'IntegrationTest-Server2' `
            -ServerUri $env:PLEX_SERVER_URI `
            -SkipValidation `
            -Confirm:$false
    }

    AfterAll {
        Remove-IntegrationTestServers
        if ($script:configBackup) {
            Restore-ServerConfiguration -BackupPath $script:configBackup
        }
    }

    Context 'Changing default server' {

        It 'Successfully changes default server' {
            Set-PatDefaultServer -Name 'IntegrationTest-Server2' -Confirm:$false

            $result = Get-PatStoredServer -Default
            $result.name | Should -Be 'IntegrationTest-Server2'
        }

        It 'Only one server is marked as default after change' {
            Set-PatDefaultServer -Name 'IntegrationTest-Server1' -Confirm:$false

            $allServers = Get-PatStoredServer
            $defaultServers = $allServers | Where-Object { $_.default -eq $true }
            $defaultServers.Count | Should -Be 1
        }

        It 'Previous default server is no longer default' {
            Set-PatDefaultServer -Name 'IntegrationTest-Server2' -Confirm:$false

            $server1 = Get-PatStoredServer -Name 'IntegrationTest-Server1'
            $server1.default | Should -Not -Be $true
        }

        It 'Handles non-existent server name' {
            { Set-PatDefaultServer -Name 'IntegrationTest-DoesNotExist' -Confirm:$false } | Should -Throw '*No server found*'
        }

        It 'Default change persists to configuration file' {
            Set-PatDefaultServer -Name 'IntegrationTest-Server1' -Confirm:$false

            # Re-import module to simulate new session
            $moduleName = $Env:BHProjectName
            if (-not $moduleName) { $moduleName = 'PlexAutomationToolkit' }
            Get-Module $moduleName | Remove-Module -Force

            $moduleManifest = Get-ChildItem -Path 'Output' -Filter '*.psd1' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($moduleManifest) {
                Import-Module -Name $moduleManifest.FullName -Verbose:$false -Force
            } else {
                Import-Module -Name "$PSScriptRoot/../../../PlexAutomationToolkit/PlexAutomationToolkit.psd1" -Verbose:$false -Force
            }

            $result = Get-PatStoredServer -Default
            $result.name | Should -Be 'IntegrationTest-Server1'
        }
    }
}
