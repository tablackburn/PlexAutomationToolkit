BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatServer' {
    BeforeEach {
        # Mock config functions with test data
        $script:mockConfig = [PSCustomObject]@{
            version = '1.0'
            servers = @(
                [PSCustomObject]@{ name = 'Server1'; uri = 'http://s1:32400'; default = $true }
                [PSCustomObject]@{ name = 'Server2'; uri = 'http://s2:32400'; default = $false }
                [PSCustomObject]@{ name = 'Server3'; uri = 'http://s3:32400'; default = $false }
            )
        }

        Mock -CommandName Get-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockConfig
        }

        Mock -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
            param($Config)
            $script:mockConfig = $Config
        }
    }

    Context 'Basic removal' {
        It 'Should remove server by name' {
            Remove-PatServer -Name 'Server2' -Confirm:$false

            $script:mockConfig.servers.Count | Should -Be 2
            $script:mockConfig.servers.name | Should -Not -Contain 'Server2'
        }

        It 'Should remove default server' {
            Remove-PatServer -Name 'Server1' -Confirm:$false

            $script:mockConfig.servers.Count | Should -Be 2
            $script:mockConfig.servers.name | Should -Not -Contain 'Server1'
        }

        It 'Should handle removing last server' {
            Remove-PatServer -Name 'Server1' -Confirm:$false
            Remove-PatServer -Name 'Server2' -Confirm:$false
            Remove-PatServer -Name 'Server3' -Confirm:$false

            $script:mockConfig.servers.Count | Should -Be 0
        }
    }

    Context 'Error handling' {
        It 'Should throw when server not found' {
            { Remove-PatServer -Name 'NonExistent' -Confirm:$false } | Should -Throw "*No server found*"
        }

        It 'Should throw when Get-PatServerConfig fails' {
            Mock -CommandName Get-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Config error'
            }

            { Remove-PatServer -Name 'Server1' -Confirm:$false } | Should -Throw
        }

        It 'Should throw when Set-PatServerConfig fails' {
            Mock -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Write error'
            }

            { Remove-PatServer -Name 'Server1' -Confirm:$false } | Should -Throw
        }
    }

    Context 'PassThru parameter' {
        It 'Should return removed server when PassThru is specified' {
            $result = Remove-PatServer -Name 'Server2' -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Server2'
            $result.uri | Should -Be 'http://s2:32400'
        }

        It 'Should not return object when PassThru is not specified' {
            $result = Remove-PatServer -Name 'Server2' -Confirm:$false

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Remove-PatServer -Name 'Server2' -WhatIf

            $script:mockConfig.servers.Count | Should -Be 3
            $script:mockConfig.servers.name | Should -Contain 'Server2'
        }

        It 'Should have ConfirmImpact of High' {
            $command = Get-Command Remove-PatServer
            $confirmImpact = ($command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }).ConfirmImpact
            $confirmImpact | Should -Be 'High'
        }
    }
}
