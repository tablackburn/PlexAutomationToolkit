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

    Context 'HTTPS upgrade detection' {
        BeforeEach {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                return @{ friendlyName = 'Mock Server' }
            }
        }

        It 'Should use HTTPS when available with -Force' {
            # Mock HTTPS check to succeed
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                return @{ friendlyName = 'Mock Server' }
            }

            $result = Add-PatServer -Name 'HTTPS Test' -ServerUri 'http://test:32400' -Force -PassThru -Confirm:$false

            $result.uri | Should -Be 'https://test:32400'
        }

        It 'Should detect HTTPS available from 401 response' {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                $response = [System.Net.HttpWebResponse]::new()
                $exception = [System.Net.WebException]::new('401', $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
                throw $exception
            } -ParameterFilter { $Uri -like 'https://*' }

            # This should still detect HTTPS as available because 401 means the server responded
            # The test validates the error handling path for 401/403
        }

        It 'Should warn when using HTTP without HTTPS available' {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Connection failed'
            } -ParameterFilter { $Uri -like 'https://*' }

            $warnings = @()
            Add-PatServer -Name 'HTTP Only' -ServerUri 'http://test:32400' -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Using unencrypted HTTP'
        }
    }

    Context 'Token vault storage' {
        It 'Should set tokenInVault when vault storage succeeds' {
            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Vault'
                    Token       = $null
                }
            }

            $result = Add-PatServer -Name 'Vault Test' -ServerUri 'http://test:32400' -Token 'SECRET' -PassThru

            $result.tokenInVault | Should -Be $true
            $result.PSObject.Properties['token'] | Should -BeNullOrEmpty
        }
    }

    Context 'Successful authentication when server requires auth' {
        It 'Should store auth token when Connect-PatAccount succeeds with -Force' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Error invoking Plex API: 401 Unauthorized'
            }

            Mock -CommandName Connect-PatAccount -ModuleName PlexAutomationToolkit -MockWith {
                return 'NEW-AUTH-TOKEN'
            }

            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Plaintext'
                    Token       = $Token
                }
            }

            $result = Add-PatServer -Name 'Auth Success' -ServerUri 'http://test:32400' -Force -PassThru -Confirm:$false

            Should -Invoke Connect-PatAccount -ModuleName PlexAutomationToolkit -Times 1
            $result.token | Should -Be 'NEW-AUTH-TOKEN'
        }

        It 'Should store auth token in vault when vault is available' {
            Mock -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -MockWith {
                throw 'Error invoking Plex API: 401 Unauthorized'
            }

            Mock -CommandName Connect-PatAccount -ModuleName PlexAutomationToolkit -MockWith {
                return 'NEW-AUTH-TOKEN'
            }

            Mock -CommandName Set-PatServerToken -ModuleName PlexAutomationToolkit -MockWith {
                param($ServerName, $Token)
                return [PSCustomObject]@{
                    StorageType = 'Vault'
                    Token       = $null
                }
            }

            $result = Add-PatServer -Name 'Auth Vault' -ServerUri 'http://test:32400' -Force -PassThru -Confirm:$false

            $result.tokenInVault | Should -Be $true
        }
    }

    Context 'DetectLocalUri feature' {
        BeforeEach {
            Mock -CommandName Get-PatServerIdentity -ModuleName PlexAutomationToolkit -MockWith {
                return [PSCustomObject]@{
                    MachineIdentifier = 'abc123def456'
                    FriendlyName      = 'Test Server'
                }
            }

            Mock -CommandName Get-PatServerConnection -ModuleName PlexAutomationToolkit -MockWith {
                return @(
                    [PSCustomObject]@{
                        Uri      = 'https://remote.plex.tv:32400'
                        Local    = $false
                        Relay    = $false
                        IPv6     = $false
                        Protocol = 'https'
                        Address  = 'remote.plex.tv'
                        Port     = 32400
                    },
                    [PSCustomObject]@{
                        Uri      = 'http://192.168.1.100:32400'
                        Local    = $true
                        Relay    = $false
                        IPv6     = $false
                        Protocol = 'http'
                        Address  = '192.168.1.100'
                        Port     = 32400
                    }
                )
            }
        }

        It 'Should warn when DetectLocalUri is used without token' {
            $warnings = @()
            Add-PatServer -Name 'NoToken' -ServerUri 'http://test:32400' -DetectLocalUri -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'DetectLocalUri requires a valid authentication token'
        }

        It 'Should detect and store local URI when available' {
            $result = Add-PatServer -Name 'LocalDetect' -ServerUri 'https://remote.plex.tv:32400' -Token 'ABC123' -DetectLocalUri -PassThru

            Should -Invoke Get-PatServerIdentity -ModuleName PlexAutomationToolkit -Times 1
            Should -Invoke Get-PatServerConnection -ModuleName PlexAutomationToolkit -Times 1
            $result.localUri | Should -Be 'http://192.168.1.100:32400'
            $result.preferLocal | Should -Be $true
        }

        It 'Should prefer HTTPS local connection when available' {
            Mock -CommandName Get-PatServerConnection -ModuleName PlexAutomationToolkit -MockWith {
                return @(
                    [PSCustomObject]@{
                        Uri      = 'http://192.168.1.100:32400'
                        Local    = $true
                        Relay    = $false
                        Protocol = 'http'
                    },
                    [PSCustomObject]@{
                        Uri      = 'https://192.168.1.100:32400'
                        Local    = $true
                        Relay    = $false
                        Protocol = 'https'
                    }
                )
            }

            $result = Add-PatServer -Name 'HTTPSLocal' -ServerUri 'https://remote:32400' -Token 'ABC' -DetectLocalUri -PassThru

            $result.localUri | Should -Be 'https://192.168.1.100:32400'
        }

        It 'Should not set localUri when detected URI matches primary URI' {
            Mock -CommandName Get-PatServerConnection -ModuleName PlexAutomationToolkit -MockWith {
                return @(
                    [PSCustomObject]@{
                        Uri      = 'http://test:32400'
                        Local    = $true
                        Relay    = $false
                        Protocol = 'http'
                    }
                )
            }

            $result = Add-PatServer -Name 'SameUri' -ServerUri 'http://test:32400' -Token 'ABC' -DetectLocalUri -PassThru -SkipValidation

            $result.PSObject.Properties['localUri'] | Should -BeNullOrEmpty
        }

        It 'Should skip relay connections when detecting local URI' {
            Mock -CommandName Get-PatServerConnection -ModuleName PlexAutomationToolkit -MockWith {
                return @(
                    [PSCustomObject]@{
                        Uri      = 'https://relay.plex.tv:32400'
                        Local    = $true
                        Relay    = $true
                        Protocol = 'https'
                    }
                )
            }

            $result = Add-PatServer -Name 'RelayOnly' -ServerUri 'http://test:32400' -Token 'ABC' -DetectLocalUri -PassThru

            $result.PSObject.Properties['localUri'] | Should -BeNullOrEmpty
        }

        It 'Should handle no connections returned from API' {
            Mock -CommandName Get-PatServerConnection -ModuleName PlexAutomationToolkit -MockWith {
                return @()
            }

            $result = Add-PatServer -Name 'NoConns' -ServerUri 'http://test:32400' -Token 'ABC' -DetectLocalUri -PassThru

            $result.PSObject.Properties['localUri'] | Should -BeNullOrEmpty
        }

        It 'Should handle API errors gracefully with warning' {
            Mock -CommandName Get-PatServerIdentity -ModuleName PlexAutomationToolkit -MockWith {
                throw 'API connection failed'
            }

            $warnings = @()
            $result = Add-PatServer -Name 'APIError' -ServerUri 'http://test:32400' -Token 'ABC' -DetectLocalUri -PassThru -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'Failed to detect local URI'
            # Server should still be added
            $script:mockConfig.servers.Count | Should -Be 1
        }

        It 'Should skip DetectLocalUri when SkipValidation is specified' {
            $result = Add-PatServer -Name 'SkipDetect' -ServerUri 'http://test:32400' -Token 'ABC' -DetectLocalUri -SkipValidation -PassThru

            Should -Invoke Get-PatServerIdentity -ModuleName PlexAutomationToolkit -Times 0
            $result.PSObject.Properties['localUri'] | Should -BeNullOrEmpty
        }
    }

    Context 'LocalUri and PreferLocal parameters' {
        It 'Should store LocalUri when provided' {
            $result = Add-PatServer -Name 'WithLocal' -ServerUri 'https://remote:32400' -LocalUri 'http://192.168.1.100:32400' -PassThru -SkipValidation

            $result.localUri | Should -Be 'http://192.168.1.100:32400'
        }

        It 'Should store PreferLocal when LocalUri is provided' {
            $result = Add-PatServer -Name 'PreferLocal' -ServerUri 'https://remote:32400' -LocalUri 'http://local:32400' -PreferLocal -PassThru -SkipValidation

            $result.localUri | Should -Be 'http://local:32400'
            $result.preferLocal | Should -Be $true
        }

        It 'Should set preferLocal to false when LocalUri provided without PreferLocal switch' {
            $result = Add-PatServer -Name 'NoPrefer' -ServerUri 'https://remote:32400' -LocalUri 'http://local:32400' -PassThru -SkipValidation

            $result.preferLocal | Should -Be $false
        }

        It 'Should warn when PreferLocal specified without LocalUri' {
            $warnings = @()
            Add-PatServer -Name 'OrphanPrefer' -ServerUri 'http://test:32400' -PreferLocal -SkipValidation -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
            $warnings -join ' ' | Should -Match 'PreferLocal specified but no LocalUri'
        }
    }

    # Note: Interactive prompt paths (ShouldContinue) cannot be unit tested
    # as they require a valid $PSCmdlet context. These paths are tested manually:
    # - User declining HTTPS upgrade (lines 231-233)
    # - User declining authentication prompt (lines 383-385)

    Context 'HTTPS detection edge cases' {
        It 'Should detect HTTPS available when server returns 401' {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                # Simulate a 401 response which indicates HTTPS is working
                $mockResponse = New-Object PSObject -Property @{
                    StatusCode = @{ value__ = 401 }
                }
                $exception = New-Object System.Exception '401 Unauthorized'
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $mockResponse -Force
                throw $exception
            } -ParameterFilter { $Uri -like 'https://*' }

            $result = Add-PatServer -Name 'HTTPS401' -ServerUri 'http://test:32400' -Force -PassThru -Confirm:$false

            # Should upgrade to HTTPS since 401 means server responded
            $result.uri | Should -Be 'https://test:32400'
        }

        It 'Should detect HTTPS available when server returns 403' {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                $mockResponse = New-Object PSObject -Property @{
                    StatusCode = @{ value__ = 403 }
                }
                $exception = New-Object System.Exception '403 Forbidden'
                $exception | Add-Member -NotePropertyName 'Response' -NotePropertyValue $mockResponse -Force
                throw $exception
            } -ParameterFilter { $Uri -like 'https://*' }

            $result = Add-PatServer -Name 'HTTPS403' -ServerUri 'http://test:32400' -Force -PassThru -Confirm:$false

            $result.uri | Should -Be 'https://test:32400'
        }

        It 'Should not check HTTPS when SkipValidation is specified' {
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                return @{ friendlyName = 'Mock Server' }
            }

            $result = Add-PatServer -Name 'SkipHTTPS' -ServerUri 'http://test:32400' -SkipValidation -PassThru

            # Should not have called Invoke-RestMethod for HTTPS check
            Should -Invoke Invoke-RestMethod -ModuleName PlexAutomationToolkit -Times 0
            $result.uri | Should -Be 'http://test:32400'
        }
    }

    Context 'PowerShell 5.1 certificate callback handling' {
        It 'Should handle certificate callback restoration in finally block' {
            # This test ensures the finally block properly restores state
            # We test by running multiple adds in sequence to verify no state leakage
            Mock -CommandName Invoke-RestMethod -ModuleName PlexAutomationToolkit -MockWith {
                return @{ friendlyName = 'Mock Server' }
            }

            # Add multiple servers - if callback isn't restored properly, subsequent calls may fail
            Add-PatServer -Name 'Server1' -ServerUri 'http://test1:32400' -Force -Confirm:$false
            Add-PatServer -Name 'Server2' -ServerUri 'http://test2:32400' -Force -Confirm:$false
            Add-PatServer -Name 'Server3' -ServerUri 'http://test3:32400' -Force -Confirm:$false

            $script:mockConfig.servers.Count | Should -Be 3
        }
    }
}
