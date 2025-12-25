BeforeAll {
    $ModuleName = 'PlexAutomationToolkit'
    $ModuleManifestPath = "$PSScriptRoot/../../../Output/$ModuleName/$((Test-ModuleManifest "$PSScriptRoot/../../../$ModuleName/$ModuleName.psd1").Version)/$ModuleName.psd1"

    if (Get-Module -Name $ModuleName) {
        Remove-Module -Name $ModuleName -Force
    }
    Import-Module $ModuleManifestPath -Force
}

Describe 'Get-PatClientIdentifier' {
    BeforeEach {
        # Mock the config functions
        $script:mockConfig = [PSCustomObject]@{
            version = '1.0'
            servers = @()
        }

        Mock Get-PatServerConfig {
            return $script:mockConfig
        }

        Mock Set-PatServerConfig {
            param($Config)
            $script:mockConfig = $Config
        }
    }

    Context 'When client identifier does not exist' {
        It 'Should generate a new GUID-based identifier' {
            $result = Get-PatClientIdentifier
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        }

        It 'Should add identifier to config' {
            $result = Get-PatClientIdentifier
            Should -Invoke Set-PatServerConfig -Times 1
        }

        It 'Should save the identifier for future use' {
            $result = Get-PatClientIdentifier
            $script:mockConfig.clientIdentifier | Should -Be $result
        }
    }

    Context 'When client identifier already exists' {
        BeforeEach {
            $script:mockConfig | Add-Member -MemberType NoteProperty -Name 'clientIdentifier' -Value 'existing-id-123' -Force
        }

        It 'Should return existing identifier' {
            $result = Get-PatClientIdentifier
            $result | Should -Be 'existing-id-123'
        }

        It 'Should not generate new identifier' {
            $result = Get-PatClientIdentifier
            Should -Invoke Set-PatServerConfig -Times 0
        }

        It 'Should return same identifier on multiple calls' {
            $result1 = Get-PatClientIdentifier
            $result2 = Get-PatClientIdentifier
            $result1 | Should -Be $result2
        }
    }

    Context 'Error Handling' {
        It 'Should throw when Get-PatServerConfig fails' {
            Mock Get-PatServerConfig {
                throw 'Config read failed'
            }
            { Get-PatClientIdentifier } | Should -Throw '*Failed to get client identifier*'
        }

        It 'Should throw when Set-PatServerConfig fails' {
            Mock Set-PatServerConfig {
                throw 'Config write failed'
            }
            { Get-PatClientIdentifier } | Should -Throw '*Failed to get client identifier*'
        }
    }
}
