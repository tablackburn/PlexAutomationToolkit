BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Build-PatServerSplat' {
    Context 'Explicit URI mode (WasExplicitUri = $true)' {
        It 'Returns ServerUri when provided' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400'
            }

            $result | Should -BeOfType [hashtable]
            $result.ServerUri | Should -Be 'http://plex:32400'
        }

        It 'Returns ServerUri and Token when both provided' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400' -Token 'my-token'
            }

            $result.ServerUri | Should -Be 'http://plex:32400'
            $result.Token | Should -Be 'my-token'
        }

        It 'Does not include Token when not provided' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400'
            }

            $result.ContainsKey('Token') | Should -Be $false
        }

        It 'Does not include Token when empty string' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400' -Token ''
            }

            $result.ContainsKey('Token') | Should -Be $false
        }

        It 'Ignores ServerName when WasExplicitUri is true' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400' -ServerName 'HomeServer'
            }

            $result.ContainsKey('ServerName') | Should -Be $false
            $result.ServerUri | Should -Be 'http://plex:32400'
        }
    }

    Context 'Server name mode (WasExplicitUri = $false)' {
        It 'Returns ServerName when provided' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerName 'HomeServer'
            }

            $result | Should -BeOfType [hashtable]
            $result.ServerName | Should -Be 'HomeServer'
        }

        It 'Does not include ServerUri or Token' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerName 'HomeServer' -ServerUri 'http://ignored:32400' -Token 'ignored'
            }

            $result.ContainsKey('ServerUri') | Should -Be $false
            $result.ContainsKey('Token') | Should -Be $false
            $result.ServerName | Should -Be 'HomeServer'
        }

        It 'Returns empty hashtable when ServerName not provided' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false
            }

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It 'Returns empty hashtable when ServerName is empty' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerName ''
            }

            $result.Count | Should -Be 0
        }
    }

    Context 'Edge cases' {
        It 'Returns empty hashtable when WasExplicitUri true but no ServerUri' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true
            }

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It 'Handles all parameters being empty' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerUri '' -Token '' -ServerName ''
            }

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }

    Context 'Splatting compatibility' {
        It 'Returns hashtable that can be used for splatting' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerName 'TestServer'
            }

            # Verify it's a proper hashtable for splatting
            $result.GetType().Name | Should -Be 'Hashtable'
            $result.Keys | Should -Contain 'ServerName'
        }

        It 'Can be merged with other parameters' {
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true -ServerUri 'http://plex:32400' -Token 'abc'
            }

            # Add additional parameters
            $result['RatingKey'] = 1001
            $result['ErrorAction'] = 'Stop'

            $result.Count | Should -Be 4
            $result.ServerUri | Should -Be 'http://plex:32400'
            $result.Token | Should -Be 'abc'
            $result.RatingKey | Should -Be 1001
        }
    }

    Context 'Real-world usage patterns' {
        It 'Matches pattern for Get-PatSyncPlan call' {
            # Simulating: WasExplicitUri = false, using ServerName
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false -ServerName 'HomeServer'
            }

            $result.ServerName | Should -Be 'HomeServer'
            $result.ContainsKey('ServerUri') | Should -Be $false
        }

        It 'Matches pattern for explicit URI with token' {
            # Simulating: WasExplicitUri = true, explicit URI and token
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $true `
                    -ServerUri 'http://192.168.1.100:32400' `
                    -Token 'xxxxxxxxxxxxxxxxxxxx'
            }

            $result.ServerUri | Should -Be 'http://192.168.1.100:32400'
            $result.Token | Should -Be 'xxxxxxxxxxxxxxxxxxxx'
        }

        It 'Matches pattern for default server (no explicit params)' {
            # Simulating: WasExplicitUri = false, no ServerName (uses default)
            $result = InModuleScope PlexAutomationToolkit {
                Build-PatServerSplat -WasExplicitUri $false
            }

            $result.Count | Should -Be 0
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory WasExplicitUri parameter' {
            $command = InModuleScope PlexAutomationToolkit {
                Get-Command Build-PatServerSplat
            }
            $parameter = $command.Parameters['WasExplicitUri']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Contain $true
        }

        It 'Has optional ServerUri parameter' {
            $command = InModuleScope PlexAutomationToolkit {
                Get-Command Build-PatServerSplat
            }
            $parameter = $command.Parameters['ServerUri']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Not -Contain $true
        }

        It 'Has optional Token parameter' {
            $command = InModuleScope PlexAutomationToolkit {
                Get-Command Build-PatServerSplat
            }
            $parameter = $command.Parameters['Token']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Not -Contain $true
        }

        It 'Has optional ServerName parameter' {
            $command = InModuleScope PlexAutomationToolkit {
                Get-Command Build-PatServerSplat
            }
            $parameter = $command.Parameters['ServerName']

            $parameter | Should -Not -BeNullOrEmpty
            $parameter.Attributes.Mandatory | Should -Not -Contain $true
        }

        It 'Returns hashtable type' {
            $command = InModuleScope PlexAutomationToolkit {
                Get-Command Build-PatServerSplat
            }
            $outputType = $command.OutputType

            $outputType.Type.Name | Should -Contain 'Hashtable'
        }
    }
}
