BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Update-PatServerToken' {
    BeforeEach {
        # Mock configuration with a default server
        $script:mockConfiguration = [PSCustomObject]@{
            version = '1.0'
            servers = @(
                [PSCustomObject]@{
                    name    = 'DefaultServer'
                    uri     = 'http://plex:32400'
                    default = $true
                    token   = 'old-token-123'
                },
                [PSCustomObject]@{
                    name    = 'SecondServer'
                    uri     = 'http://plex2:32400'
                    default = $false
                    token   = 'old-token-456'
                }
            )
        }

        Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
            param($Name, $Default)
            if ($Default) {
                return $script:mockConfiguration.servers | Where-Object { $_.default -eq $true }
            }
            $server = $script:mockConfiguration.servers | Where-Object { $_.name -eq $Name }
            if (-not $server) {
                throw "No server found with name '$Name'"
            }
            return $server
        }

        Mock -CommandName Get-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockConfiguration
        }

        Mock -CommandName Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
            param($Configuration)
            $script:mockConfiguration = $Configuration
        }

        Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
            param($ServerName, $Token)
            return [PSCustomObject]@{
                StorageType = 'Inline'
                Token       = $Token
            }
        }

        Mock -CommandName Join-PatUri -ModuleName PlexAutomationToolkit -MockWith {
            param($BaseUri, $Endpoint)
            return "$BaseUri$Endpoint"
        }

        Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
            return @{ friendlyName = 'Mock Server' }
        }

        Mock -CommandName Connect-PatAccount -ModuleName PlexAutomationToolkit -MockWith {
            return 'new-interactive-token'
        }
    }

    Context 'Named server token update' {
        It 'Should update token for a named server' {
            $result = Update-PatServerToken -Name 'SecondServer' -Token 'new-token-789' -Confirm:$false

            $result.ServerName | Should -Be 'SecondServer'
            $result.TokenUpdated | Should -Be $true
            Should -Invoke Set-PatServerToken -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $ServerName -eq 'SecondServer' -and $Token -eq 'new-token-789'
            }
        }

        It 'Should throw when server name not found' {
            { Update-PatServerToken -Name 'NonExistent' -Token 'token' -Confirm:$false } | Should -Throw '*NonExistent*'
        }
    }

    Context 'Default server token update' {
        It 'Should update token for default server when no name specified' {
            $result = Update-PatServerToken -Token 'new-default-token' -Confirm:$false

            $result.ServerName | Should -Be 'DefaultServer'
            $result.TokenUpdated | Should -Be $true
            Should -Invoke Get-PatStoredServer -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Should throw when no default server exists and no name specified' {
            Mock -CommandName Get-PatStoredServer -ModuleName PlexAutomationToolkit -MockWith {
                param($Name, $Default)
                if ($Default) {
                    throw "No default server configured"
                }
            }

            { Update-PatServerToken -Token 'token' -Confirm:$false } | Should -Throw '*default server*'
        }
    }

    Context 'Interactive authentication' {
        It 'Should call Connect-PatAccount when no Token provided' {
            $result = Update-PatServerToken -Name 'DefaultServer' -Confirm:$false

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 1
            $result.TokenUpdated | Should -Be $true
        }

        It 'Should pass TimeoutSeconds to Connect-PatAccount' {
            Update-PatServerToken -Name 'DefaultServer' -TimeoutSeconds 600 -Confirm:$false

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $TimeoutSeconds -eq 600
            }
        }

        It 'Should pass Force to Connect-PatAccount' {
            Update-PatServerToken -Name 'DefaultServer' -Force -Confirm:$false

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }
    }

    Context 'Direct token supply' {
        It 'Should use provided Token and skip interactive flow' {
            Update-PatServerToken -Name 'DefaultServer' -Token 'direct-token' -Confirm:$false

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 0
            Should -Invoke Set-PatServerToken -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Token -eq 'direct-token'
            }
        }
    }

    Context 'Token storage' {
        It 'Should store token via Set-PatServerToken' {
            Update-PatServerToken -Name 'DefaultServer' -Token 'store-test' -Confirm:$false

            Should -Invoke Set-PatServerToken -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $ServerName -eq 'DefaultServer' -and $Token -eq 'store-test'
            }
        }

        It 'Should update inline token in configuration' {
            Update-PatServerToken -Name 'DefaultServer' -Token 'updated-inline' -Confirm:$false

            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 1
            $serverEntry = $script:mockConfiguration.servers | Where-Object { $_.name -eq 'DefaultServer' }
            $serverEntry.token | Should -Be 'updated-inline'
        }

        It 'Should set tokenInVault when vault storage succeeds' {
            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Vault'
                    Token       = $null
                }
            }

            Update-PatServerToken -Name 'DefaultServer' -Token 'vault-token' -Confirm:$false

            $serverEntry = $script:mockConfiguration.servers | Where-Object { $_.name -eq 'DefaultServer' }
            $serverEntry.tokenInVault | Should -Be $true
            $serverEntry.PSObject.Properties['token'] | Should -BeNullOrEmpty
        }

        It 'Should update existing tokenInVault property when vault storage succeeds again' {
            # Set up a server that already uses vault storage
            $script:mockConfiguration.servers[0] | Add-Member -NotePropertyName 'tokenInVault' -NotePropertyValue $true -Force
            $script:mockConfiguration.servers[0].PSObject.Properties.Remove('token')

            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Vault'
                    Token       = $null
                }
            }

            Update-PatServerToken -Name 'DefaultServer' -Token 'vault-again' -Confirm:$false

            $serverEntry = $script:mockConfiguration.servers | Where-Object { $_.name -eq 'DefaultServer' }
            $serverEntry.tokenInVault | Should -Be $true
            $serverEntry.PSObject.Properties['token'] | Should -BeNullOrEmpty
        }

        It 'Should remove tokenInVault when falling back to inline storage' {
            # Set up a server that previously used vault storage
            $script:mockConfiguration.servers[0] | Add-Member -NotePropertyName 'tokenInVault' -NotePropertyValue $true -Force
            $script:mockConfiguration.servers[0].PSObject.Properties.Remove('token')

            Update-PatServerToken -Name 'DefaultServer' -Token 'inline-fallback' -Confirm:$false

            $serverEntry = $script:mockConfiguration.servers | Where-Object { $_.name -eq 'DefaultServer' }
            $serverEntry.token | Should -Be 'inline-fallback'
            $serverEntry.PSObject.Properties['tokenInVault'] | Should -BeNullOrEmpty
        }
    }

    Context 'Token verification' {
        It 'Should verify new token by calling API' {
            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'verify-test' -Confirm:$false

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
            $result.Verified | Should -Be $true
        }

        It 'Should report success when verification succeeds' {
            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'good-token' -Confirm:$false

            $result.Verified | Should -Be $true
            $result.TokenUpdated | Should -Be $true
        }

        It 'Should report failure when verification fails' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Error invoking Plex API: 401 Unauthorized'
            }

            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'bad-token' -Confirm:$false -WarningVariable verificationWarning

            $result.Verified | Should -Be $false
            $result.TokenUpdated | Should -Be $true
            $verificationWarning | Should -Not -BeNullOrEmpty
            $verificationWarning[0] | Should -BeLike '*verification failed*'
        }

        It 'Should use localUri for verification when preferLocal is configured' {
            # Set up a server with preferLocal and localUri
            $script:mockConfiguration.servers[0] |
                Add-Member -NotePropertyName 'preferLocal' -NotePropertyValue $true -Force
            $script:mockConfiguration.servers[0] |
                Add-Member -NotePropertyName 'localUri' -NotePropertyValue 'http://192.168.1.10:32400' -Force

            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'local-token' -Confirm:$false

            $result.Verified | Should -Be $true
            Should -Invoke Join-PatUri -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.10:32400'
            }
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf with direct token' {
            Update-PatServerToken -Name 'DefaultServer' -Token 'whatif-token' -WhatIf

            Should -Invoke Set-PatServerToken -ModuleName PlexAutomationToolkit -Times 0
            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Should not invoke interactive auth when WhatIf is used without Token' {
            Update-PatServerToken -Name 'DefaultServer' -WhatIf

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 0
            Should -Invoke Set-PatServerToken -ModuleName PlexAutomationToolkit -Times 0
            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Should return no output when WhatIf is used' {
            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'whatif-token' -WhatIf

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when Get-PatServerConfiguration fails' {
            Mock -CommandName Get-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Configuration error'
            }

            { Update-PatServerToken -Name 'DefaultServer' -Token 'token' -Confirm:$false } | Should -Throw
        }

        It 'Should throw when Set-PatServerConfiguration fails' {
            Mock -CommandName Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Write error'
            }

            { Update-PatServerToken -Name 'DefaultServer' -Token 'token' -Confirm:$false } | Should -Throw
        }

        It 'Should throw when Connect-PatAccount fails' {
            Mock -CommandName Connect-PatAccount -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Authentication failed'
            }

            { Update-PatServerToken -Name 'DefaultServer' -Confirm:$false } | Should -Throw '*Authentication failed*'
        }

        It 'Should throw when server entry is missing from configuration' {
            # Get-PatStoredServer succeeds but the config returned by Get-PatServerConfiguration
            # has no matching server entry (simulates a race or corrupt config)
            Mock -CommandName Get-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    version = '1.0'
                    servers = @(
                        [PSCustomObject]@{
                            name  = 'OtherServer'
                            uri   = 'http://other:32400'
                            token = 'some-token'
                        }
                    )
                }
            }

            { Update-PatServerToken -Name 'DefaultServer' -Token 'token' -Confirm:$false } |
                Should -Throw '*DefaultServer*was not found*'
        }
    }

    Context 'Output object' {
        It 'Should return object with correct properties' {
            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'output-test' -Confirm:$false

            $result.PSObject.Properties['ServerName'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['TokenUpdated'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['Verified'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['StorageType'] | Should -Not -BeNullOrEmpty
            $result.StorageType | Should -Be 'Inline'
        }

        It 'Should report Vault storage type when vault is used' {
            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Vault'
                    Token       = $null
                }
            }

            $result = Update-PatServerToken -Name 'DefaultServer' -Token 'vault-test' -Confirm:$false

            $result.StorageType | Should -Be 'Vault'
        }
    }
}
