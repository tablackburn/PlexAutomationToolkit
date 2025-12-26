BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Set-PatDefaultServer' {
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

    Context 'Setting default server' {
        It 'Should set specified server as default' {
            Set-PatDefaultServer -Name 'Server2'

            $server2 = $script:mockConfig.servers | Where-Object { $_.name -eq 'Server2' }
            $server2.default | Should -Be $true
        }

        It 'Should unset previous default' {
            Set-PatDefaultServer -Name 'Server2'

            $server1 = $script:mockConfig.servers | Where-Object { $_.name -eq 'Server1' }
            $server1.default | Should -Be $false
        }

        It 'Should ensure only one server is default' {
            Set-PatDefaultServer -Name 'Server3'

            $defaultCount = ($script:mockConfig.servers | Where-Object { $_.default -eq $true }).Count
            $defaultCount | Should -Be 1
        }

        It 'Should handle changing default multiple times' {
            Set-PatDefaultServer -Name 'Server2'
            Set-PatDefaultServer -Name 'Server3'
            Set-PatDefaultServer -Name 'Server1'

            $server1 = $script:mockConfig.servers | Where-Object { $_.name -eq 'Server1' }
            $server1.default | Should -Be $true

            $defaultCount = ($script:mockConfig.servers | Where-Object { $_.default -eq $true }).Count
            $defaultCount | Should -Be 1
        }
    }

    Context 'Error handling' {
        It 'Should throw when server not found' {
            { Set-PatDefaultServer -Name 'NonExistent' } | Should -Throw "*No server found*"
        }

        It 'Should throw when Get-PatServerConfig fails' {
            Mock -CommandName Get-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Config error'
            }

            { Set-PatDefaultServer -Name 'Server1' } | Should -Throw
        }

        It 'Should throw when Set-PatServerConfig fails' {
            Mock -CommandName Set-PatServerConfig -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Write error'
            }

            { Set-PatDefaultServer -Name 'Server2' } | Should -Throw
        }
    }

    Context 'PassThru parameter' {
        It 'Should return server when PassThru is specified' {
            $result = Set-PatDefaultServer -Name 'Server2' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Server2'
            $result.default | Should -Be $true
        }

        It 'Should not return object when PassThru is not specified' {
            $result = Set-PatDefaultServer -Name 'Server2'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Set-PatDefaultServer -Name 'Server2' -WhatIf

            $server1 = $script:mockConfig.servers | Where-Object { $_.name -eq 'Server1' }
            $server1.default | Should -Be $true
        }

        It 'Should have ConfirmImpact of Low' {
            $command = Get-Command Set-PatDefaultServer
            $confirmImpact = ($command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }).ConfirmImpact
            $confirmImpact | Should -Be 'Low'
        }
    }
}
