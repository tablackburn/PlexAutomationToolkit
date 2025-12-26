BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Clear-PatDefaultServer' {
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

    Context 'Clearing default server' {
        It 'Should clear the default server designation' {
            Clear-PatDefaultServer

            $defaultServers = $script:mockConfig.servers | Where-Object { $_.default -eq $true }
            $defaultServers.Count | Should -Be 0
        }

        It 'Should clear default from all servers' {
            Clear-PatDefaultServer

            foreach ($server in $script:mockConfig.servers) {
                $server.default | Should -Be $false
            }
        }

        It 'Should call Set-PatServerConfig with updated config' {
            Clear-PatDefaultServer

            Should -Invoke -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -Times 1 -Exactly
        }

        It 'Should preserve all server configurations' {
            $originalCount = $script:mockConfig.servers.Count

            Clear-PatDefaultServer

            $script:mockConfig.servers.Count | Should -Be $originalCount
        }
    }

    Context 'When no default is set' {
        BeforeEach {
            # Mock config with no default server
            $script:mockConfig = [PSCustomObject]@{
                version = '1.0'
                servers = @(
                    [PSCustomObject]@{ name = 'Server1'; uri = 'http://s1:32400'; default = $false }
                    [PSCustomObject]@{ name = 'Server2'; uri = 'http://s2:32400'; default = $false }
                )
            }
        }

        It 'Should complete without error when no default exists' {
            { Clear-PatDefaultServer } | Should -Not -Throw
        }

        It 'Should not call Set-PatServerConfig when no default exists' {
            Clear-PatDefaultServer

            Should -Invoke -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -Times 0 -Exactly
        }
    }

    Context 'When no servers are configured' {
        BeforeEach {
            # Mock empty config
            $script:mockConfig = [PSCustomObject]@{
                version = '1.0'
                servers = @()
            }
        }

        It 'Should complete without error when no servers exist' {
            { Clear-PatDefaultServer -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should write a warning when no servers exist' {
            $warningMessages = @()
            Clear-PatDefaultServer -WarningAction SilentlyContinue -WarningVariable warningMessages

            $warningMessages.Count | Should -BeGreaterThan 0
        }

        It 'Should not call Set-PatServerConfig when no servers exist' {
            Clear-PatDefaultServer -WarningAction SilentlyContinue

            Should -Invoke -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -Times 0 -Exactly
        }
    }

    Context 'Error handling' {
        It 'Should throw when Get-PatServerConfig fails' {
            Mock -CommandName Get-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Config error'
            }

            { Clear-PatDefaultServer } | Should -Throw
        }

        It 'Should throw when Set-PatServerConfig fails' {
            Mock -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Write error'
            }

            { Clear-PatDefaultServer } | Should -Throw
        }

        It 'Should include error message in exception' {
            Mock -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Disk full'
            }

            { Clear-PatDefaultServer } | Should -Throw "*Disk full*"
        }
    }

    Context 'PassThru parameter' {
        It 'Should return all servers when PassThru is specified' {
            $result = Clear-PatDefaultServer -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
        }

        It 'Should return servers with default cleared when PassThru is specified' {
            $result = Clear-PatDefaultServer -PassThru

            foreach ($server in $result) {
                $server.default | Should -Be $false
            }
        }

        It 'Should not return object when PassThru is not specified' {
            $result = Clear-PatDefaultServer

            $result | Should -BeNullOrEmpty
        }

        It 'Should return servers even when no default was set' {
            $script:mockConfig.servers[0].default = $false

            $result = Clear-PatDefaultServer -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Clear-PatDefaultServer -WhatIf

            # Config should not be modified
            $server1 = $script:mockConfig.servers | Where-Object { $_.name -eq 'Server1' }
            $server1.default | Should -Be $true
        }

        It 'Should not call Set-PatServerConfig with WhatIf' {
            Clear-PatDefaultServer -WhatIf

            Should -Invoke -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -Times 0 -Exactly
        }

        It 'Should have ConfirmImpact of Low' {
            $command = Get-Command Clear-PatDefaultServer
            $confirmImpact = ($command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }).ConfirmImpact
            $confirmImpact | Should -Be 'Low'
        }

        It 'Should have SupportsShouldProcess' {
            $command = Get-Command Clear-PatDefaultServer
            $supportsShouldProcess = ($command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }).SupportsShouldProcess
            $supportsShouldProcess | Should -Be $true
        }
    }
}
