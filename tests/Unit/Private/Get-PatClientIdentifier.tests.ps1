BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatClientIdentifier' {
    BeforeEach {
        # Mock the config functions
        $script:mockConfig = [PSCustomObject]@{
            version = '1.0'
            servers = @()
        }

        Mock Get-PatServerConfiguration -ModuleName PlexAutomationToolkit {
            return $script:mockConfig
        }

        Mock Set-PatServerConfiguration -ModuleName PlexAutomationToolkit {
            param($configuration)
            $script:mockConfig = $configuration
        }
    }

    Context 'When client identifier does not exist' {
        It 'Should generate a new GUID-based identifier' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        }

        It 'Should add identifier to config' {
            InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Should save the identifier for future use' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            $script:mockConfig.clientIdentifier | Should -Be $result
        }
    }

    Context 'When client identifier already exists' {
        BeforeEach {
            $script:mockConfig | Add-Member -MemberType NoteProperty -Name 'clientIdentifier' -Value 'existing-id-123' -Force
        }

        It 'Should return existing identifier' {
            $result = InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            $result | Should -Be 'existing-id-123'
        }

        It 'Should not generate new identifier' {
            InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Should return same identifier on multiple calls' {
            $result1 = InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            $result2 = InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier }
            $result1 | Should -Be $result2
        }
    }

    Context 'Error Handling' {
        It 'Should throw when Get-PatServerConfiguration fails' {
            Mock Get-PatServerConfiguration -ModuleName PlexAutomationToolkit {
                throw 'Config read failed'
            }
            { InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier } } | Should -Throw '*Failed to get client identifier*'
        }

        It 'Should throw when Set-PatServerConfiguration fails' {
            Mock Set-PatServerConfiguration -ModuleName PlexAutomationToolkit {
                throw 'Config write failed'
            }
            { InModuleScope PlexAutomationToolkit { Get-PatClientIdentifier } } | Should -Throw '*Failed to get client identifier*'
        }
    }
}
