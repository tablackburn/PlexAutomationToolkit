BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Stop-PatSession' {

    BeforeAll {
        # Mock session for PassThru and ShouldProcess message
        $script:mockSession = [PSCustomObject]@{
            PSTypeName      = 'PlexAutomationToolkit.Session'
            SessionId       = 'session-001'
            MediaTitle      = 'The Matrix'
            MediaType       = 'movie'
            MediaKey        = '/library/metadata/123'
            Username        = 'john'
            UserId          = '1'
            PlayerName      = 'Living Room TV'
            PlayerAddress   = '192.168.1.100'
            PlayerPlatform  = 'Roku'
            PlayerMachineId = 'roku-abc123'
            IsLocal         = $true
            Bandwidth       = 20000
            ViewOffset      = 4080000
            Duration        = 8160000
            Progress        = 50
            ServerUri       = 'http://plex.local:32400'
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When terminating a session with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Calls the terminate endpoint' {
            Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/status/sessions/terminate'
            }
        }

        It 'Includes session ID in query string' {
            Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'sessionId=session-001'
            }
        }

        It 'Is silent by default (no output)' {
            $result = Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When using -Reason parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Includes reason in query string' {
            Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Reason 'Server maintenance' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'reason='
            }
        }

        It 'URL-encodes the reason parameter' {
            Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Reason 'Server maintenance in progress' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'reason=.*%20.*'
            }
        }
    }

    Context 'When using -PassThru parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Returns session information' {
            $result = Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.SessionId | Should -Be 'session-001'
            $result.MediaTitle | Should -Be 'The Matrix'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions/terminate'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Does not call Invoke-PatApi' {
            Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 0
        }
    }

    Context 'When accepting pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint`?$QueryString"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Accepts SessionId from pipeline by property name' {
            $script:mockSession | Stop-PatSession -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'sessionId=session-001'
            }
        }

        It 'Processes multiple sessions from pipeline' {
            $sessions = @(
                [PSCustomObject]@{ SessionId = 'session-001' }
                [PSCustomObject]@{ SessionId = 'session-002' }
            )

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $null
            }

            $sessions | Stop-PatSession -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 2
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/status/sessions/terminate'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Stop-PatSession -SessionId 'session-001' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Stop-PatSession -SessionId 'session-001' -Confirm:$false } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Session not found'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex.local:32400/status/sessions/terminate'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatSession {
                return $script:mockSession
            }
        }

        It 'Throws an error with context' {
            { Stop-PatSession -SessionId 'session-001' -ServerUri 'http://plex.local:32400' -Confirm:$false } | Should -Throw '*Failed to terminate session*'
        }
    }

    Context 'CmdletBinding attributes' {
        It 'Has SupportsShouldProcess attribute' {
            $command = Get-Command Stop-PatSession
            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $command.Parameters.Keys | Should -Contain 'Confirm'
        }

        It 'Has ConfirmImpact of High' {
            $command = Get-Command Stop-PatSession
            $attribute = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attribute.ConfirmImpact | Should -Be 'High'
        }
    }

    Context 'Parameter validation' {
        It 'Requires SessionId parameter' {
            $command = Get-Command Stop-PatSession
            $param = $command.Parameters['SessionId']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | ForEach-Object {
                $_.Mandatory | Should -Be $true
            }
        }

        It 'SessionId accepts pipeline input' {
            $command = Get-Command Stop-PatSession
            $param = $command.Parameters['SessionId']
            $paramAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $paramAttr.ValueFromPipeline | Should -Be $true
            $paramAttr.ValueFromPipelineByPropertyName | Should -Be $true
        }
    }
}
