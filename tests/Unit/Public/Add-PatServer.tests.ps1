BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Add-PatServer' {
    BeforeEach {
        # Mock config functions to use in-memory config
        $script:mockConfig = [PSCustomObject]@{
            version = '1.0'
            servers = @()
        }

        Mock -CommandName Get-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
            return $script:mockConfig
        }

        Mock -CommandName Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
            param($configuration)
            $script:mockConfig = $configuration
        }

        # Mock validation functions - default to success
        Mock -CommandName Join-PatUri -ModuleName PlexAutomationToolkit -MockWith {
            param($BaseUri, $Endpoint)
            return "$BaseUri$Endpoint"
        }

        Mock -CommandName Get-PatAuthenticationHeader -ModuleName PlexAutomationToolkit -MockWith {
            param($Server)
            $headers = @{ Accept = 'application/json' }
            if ($Server.PSObject.Properties['token']) {
                $headers['X-Plex-Token'] = $Server.token
            }
            return $headers
        }

        Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
            # Default to successful validation
            return @{ friendlyName = 'Mock Server' }
        }

        # Mock Set-PatServerToken to simulate plaintext storage (no vault)
        Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
            param($ServerName, $Token)
            return [PSCustomObject]@{
                StorageType = 'Plaintext'
                Token       = $Token
            }
        }
    }

    Context 'Adding a basic server' {
        It 'Should add server to empty configuration' {
            Add-PatServer -Name 'Test Server' -ServerUri 'http://test:32400'

            $script:mockConfig.servers.Count | Should -Be 1
            $script:mockConfig.servers[0].name | Should -Be 'Test Server'
            $script:mockConfig.servers[0].uri | Should -Be 'http://test:32400'
            $script:mockConfig.servers[0].default | Should -Be $false
        }

        It 'Should add server and mark as default' {
            Add-PatServer -Name 'Main Server' -ServerUri 'http://main:32400' -Default

            $script:mockConfig.servers[0].default | Should -Be $true
        }

        It 'Should add multiple servers' {
            Add-PatServer -Name 'Server1' -ServerUri 'http://server1:32400'
            Add-PatServer -Name 'Server2' -ServerUri 'http://server2:32400'
            Add-PatServer -Name 'Server3' -ServerUri 'http://server3:32400'

            $script:mockConfig.servers.Count | Should -Be 3
        }

        It 'Should add server with authentication token' {
            Add-PatServer -Name 'Auth Server' -ServerUri 'http://auth:32400' -Token 'ABC123xyz'

            $script:mockConfig.servers[0].token | Should -Be 'ABC123xyz'
        }

        It 'Should not add token property when token is not provided' {
            Add-PatServer -Name 'No Auth' -ServerUri 'http://noauth:32400'

            $script:mockConfig.servers[0].PSObject.Properties['token'] | Should -BeNullOrEmpty
        }
    }

    Context 'Default server handling' {
        It 'Should unset other defaults when adding new default server' {
            Add-PatServer -Name 'Server1' -ServerUri 'http://server1:32400' -Default
            Add-PatServer -Name 'Server2' -ServerUri 'http://server2:32400' -Default

            $script:mockConfig.servers.Count | Should -Be 2
            $script:mockConfig.servers[0].default | Should -Be $false
            $script:mockConfig.servers[1].default | Should -Be $true
        }

        It 'Should preserve non-default servers when adding default' {
            Add-PatServer -Name 'NonDefault' -ServerUri 'http://nd:32400'
            Add-PatServer -Name 'Default' -ServerUri 'http://def:32400' -Default

            $script:mockConfig.servers[0].default | Should -Be $false
            $script:mockConfig.servers[1].default | Should -Be $true
        }
    }

    Context 'Duplicate handling' {
        It 'Should throw on duplicate server name' {
            Add-PatServer -Name 'Duplicate' -ServerUri 'http://dup1:32400'

            { Add-PatServer -Name 'Duplicate' -ServerUri 'http://dup2:32400' } | Should -Throw "*already exists*"
        }

        It 'Should allow same URI with different names' {
            Add-PatServer -Name 'Server1' -ServerUri 'http://same:32400'
            Add-PatServer -Name 'Server2' -ServerUri 'http://same:32400'

            $script:mockConfig.servers.Count | Should -Be 2
        }
    }

    Context 'PassThru parameter' {
        It 'Should return server object when PassThru is specified' {
            $result = Add-PatServer -Name 'Test' -ServerUri 'http://test:32400' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Test'
            $result.uri | Should -Be 'http://test:32400'
        }

        It 'Should not return object when PassThru is not specified' {
            $result = Add-PatServer -Name 'Test' -ServerUri 'http://test:32400'

            $result | Should -BeNullOrEmpty
        }

        It 'Should return server with token when provided' {
            $result = Add-PatServer -Name 'Auth' -ServerUri 'http://auth:32400' -Token 'ABC' -PassThru

            $result.token | Should -Be 'ABC'
        }
    }

    Context 'ShouldProcess support' {
        It 'Should support WhatIf' {
            Add-PatServer -Name 'WhatIf Test' -ServerUri 'http://test:32400' -WhatIf

            # WhatIf should prevent Set-PatServerConfiguration from being called
            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Should call ShouldProcess with correct target' {
            Add-PatServer -Name 'Test' -ServerUri 'http://test:32400' -Confirm:$false

            Should -Invoke Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -Times 1
        }
    }

    Context 'Error handling' {
        It 'Should throw when Get-PatServerConfiguration fails' {
            Mock -CommandName Get-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Config error'
            }

            { Add-PatServer -Name 'Test' -ServerUri 'http://test:32400' } | Should -Throw
        }

        It 'Should throw when Set-PatServerConfiguration fails' {
            Mock -CommandName Set-PatServerConfiguration -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Write error'
            }

            { Add-PatServer -Name 'Test' -ServerUri 'http://test:32400' } | Should -Throw
        }
    }

    Context 'Server validation' {
        It 'Should validate server connectivity by default' {
            Add-PatServer -Name 'Test' -ServerUri 'http://test:32400'

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Should skip validation when SkipValidation is specified' {
            Add-PatServer -Name 'Test' -ServerUri 'http://test:32400' -SkipValidation

            Should -Invoke Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 0
        }

        It 'Should include token in validation headers when token is provided' {
            Add-PatServer -Name 'Auth' -ServerUri 'http://auth:32400' -Token 'ABC123'

            Should -Invoke Get-PatAuthenticationHeader -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $Server.token -eq 'ABC123'
            }
        }

        It 'Should warn on connection failure but still save configuration' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Unable to connect to the remote server'
            }

            $warnings = @()
            Add-PatServer -Name 'Offline' -ServerUri 'http://offline:32400' -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Unable to connect'
            $script:mockConfig.servers.Count | Should -Be 1
        }

        It 'Should warn on authentication failure with token' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Error invoking Plex API: 401 Unauthorized'
            }

            $warnings = @()
            Add-PatServer -Name 'BadToken' -ServerUri 'http://test:32400' -Token 'INVALID' -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Authentication with provided token failed'
            $script:mockConfig.servers.Count | Should -Be 1
        }

        It 'Should attempt authentication with -Force when server requires auth' {
            # When server requires auth (401) and -Force is specified,
            # automatically attempts Connect-PatAccount.
            # Mock Connect-PatAccount to simulate failed auth (since we can't actually auth in tests)
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Error invoking Plex API: 401 Unauthorized'
            }
            Mock -CommandName Connect-PatAccount -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Authentication failed in test'
            }

            $warnings = @()
            Add-PatServer -Name 'NeedsAuth' -ServerUri 'http://auth:32400' -Force -WarningVariable warnings -Confirm:$false 3>$null

            # With -Force, Connect-PatAccount is called automatically
            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 1
            # Since auth failed, server saved without token with warning
            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Authentication failed'
            $script:mockConfig.servers.Count | Should -Be 1
        }

        It 'Should warn on generic validation errors' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Some unexpected error'
            }

            $warnings = @()
            Add-PatServer -Name 'Error' -ServerUri 'http://test:32400' -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Failed to validate server'
            $script:mockConfig.servers.Count | Should -Be 1
        }
    }
}
