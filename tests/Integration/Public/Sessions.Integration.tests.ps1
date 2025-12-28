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

Describe 'Get-PatSession Integration Tests' -Skip:(-not $script:integrationEnabled) {

    BeforeAll {
        # Backup and setup test server for all session tests
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-Sessions' `
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

    Context 'Session retrieval' {

        It 'Successfully queries sessions endpoint' {
            # This should not throw - even if no sessions are active
            { Get-PatSession } | Should -Not -Throw
        }

        It 'Returns array or null (depending on active sessions)' {
            $result = Get-PatSession
            # Result can be null/empty or an array of sessions
            if ($result) {
                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Session objects have expected properties when sessions exist' {
            $result = Get-PatSession
            if ($result) {
                $result[0].PSObject.Properties.Name | Should -Contain 'SessionId'
                $result[0].PSObject.Properties.Name | Should -Contain 'MediaTitle'
                $result[0].PSObject.Properties.Name | Should -Contain 'Username'
                $result[0].PSObject.Properties.Name | Should -Contain 'PlayerName'
                $result[0].PSObject.Properties.Name | Should -Contain 'Progress'
            }
            else {
                Set-ItResult -Skipped -Because 'No active sessions to test properties'
            }
        }

        It 'Session objects have correct PSTypeName' {
            $result = Get-PatSession
            if ($result) {
                $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Session'
            }
            else {
                Set-ItResult -Skipped -Because 'No active sessions to test type'
            }
        }

        It 'Accepts explicit ServerUri parameter' {
            { Get-PatSession -ServerUri $env:PLEX_SERVER_URI -Token $env:PLEX_TOKEN } | Should -Not -Throw
        }
    }

    Context 'Session filtering' {

        It 'Username filter does not throw' {
            { Get-PatSession -Username 'nonexistent-user-12345' } | Should -Not -Throw
        }

        It 'Player filter does not throw' {
            { Get-PatSession -Player 'nonexistent-player-12345' } | Should -Not -Throw
        }

        It 'Combined filters do not throw' {
            { Get-PatSession -Username 'test' -Player 'test' } | Should -Not -Throw
        }
    }
}

Describe 'Stop-PatSession Integration Tests' -Skip:(-not $script:integrationEnabled) {
    # NOTE: We intentionally do NOT test Stop-PatSession with real sessions
    # as that would disrupt actual users watching content.
    # These tests verify parameter handling and WhatIf behavior only.

    BeforeAll {
        # Backup and setup test server
        $script:configBackup = Backup-ServerConfiguration

        Add-PatServer -Name 'IntegrationTest-StopSession' `
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

    Context 'WhatIf behavior (safe to run)' {

        It 'WhatIf does not actually terminate session' {
            # Using a fake session ID with -WhatIf - should not make API call
            { Stop-PatSession -SessionId 'fake-session-id-12345' -WhatIf } | Should -Not -Throw
        }

        It 'WhatIf with Reason parameter works' {
            { Stop-PatSession -SessionId 'fake-session-id-12345' -Reason 'Test reason' -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Parameter validation' {

        It 'Requires SessionId parameter' {
            { Stop-PatSession -Confirm:$false } | Should -Throw
        }

        It 'Accepts SessionId from pipeline' {
            # This may fail at the API level (session not found) but should not fail at parameter binding
            $pipelineInput = [PSCustomObject]@{ SessionId = 'test-session-id' }
            # Using -WhatIf to avoid actual API call
            { $pipelineInput | Stop-PatSession -WhatIf } | Should -Not -Throw
        }
    }
}
