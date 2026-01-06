BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get reference to private function
    $script:SelectPatServerUri = & (Get-Module PlexAutomationToolkit) { Get-Command Select-PatServerUri }
}

Describe 'Select-PatServerUri' {

    Context 'Basic Server without LocalUri' {
        BeforeAll {
            $script:basicServer = [PSCustomObject]@{
                name    = 'Test Server'
                uri     = 'https://plex.example.com:32400'
                default = $true
            }
        }

        It 'Returns primary URI when no local URI configured' {
            $result = & $script:SelectPatServerUri -Server $script:basicServer
            $result.Uri | Should -Be 'https://plex.example.com:32400'
            $result.IsLocal | Should -Be $false
            $result.SelectionReason | Should -Be 'No local URI configured'
        }

        It 'Returns primary URI when ForceRemote specified' {
            $result = & $script:SelectPatServerUri -Server $script:basicServer -ForceRemote
            $result.Uri | Should -Be 'https://plex.example.com:32400'
            $result.IsLocal | Should -Be $false
            $result.SelectionReason | Should -Be 'ForceRemote parameter specified'
        }
    }

    Context 'Server with LocalUri but PreferLocal disabled' {
        BeforeAll {
            $script:serverWithLocal = [PSCustomObject]@{
                name        = 'Test Server'
                uri         = 'https://plex.example.com:32400'
                localUri    = 'http://192.168.1.100:32400'
                preferLocal = $false
                default     = $true
            }
        }

        It 'Returns primary URI when PreferLocal is disabled' {
            $result = & $script:SelectPatServerUri -Server $script:serverWithLocal
            $result.Uri | Should -Be 'https://plex.example.com:32400'
            $result.IsLocal | Should -Be $false
            $result.SelectionReason | Should -Be 'PreferLocal is disabled'
        }

        It 'Returns local URI when ForceLocal specified even if PreferLocal disabled' {
            $result = & $script:SelectPatServerUri -Server $script:serverWithLocal -ForceLocal
            $result.Uri | Should -Be 'http://192.168.1.100:32400'
            $result.IsLocal | Should -Be $true
            $result.SelectionReason | Should -Be 'ForceLocal parameter specified'
        }
    }

    Context 'Server with LocalUri and PreferLocal enabled' {
        BeforeAll {
            $script:serverPreferLocal = [PSCustomObject]@{
                name        = 'Test Server'
                uri         = 'https://plex.example.com:32400'
                localUri    = 'http://192.168.1.100:32400'
                preferLocal = $true
                default     = $true
            }
        }

        It 'Returns primary URI when ForceRemote specified' {
            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal -ForceRemote
            $result.Uri | Should -Be 'https://plex.example.com:32400'
            $result.IsLocal | Should -Be $false
            $result.SelectionReason | Should -Be 'ForceRemote parameter specified'
        }

        It 'Returns local URI when ForceLocal specified' {
            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal -ForceLocal
            $result.Uri | Should -Be 'http://192.168.1.100:32400'
            $result.IsLocal | Should -Be $true
            $result.SelectionReason | Should -Be 'ForceLocal parameter specified'
        }
    }

    Context 'Reachability-based selection with PreferLocal enabled' {
        BeforeAll {
            $script:serverPreferLocal = [PSCustomObject]@{
                name        = 'Test Server'
                uri         = 'https://plex.example.com:32400'
                localUri    = 'http://192.168.1.100:32400'
                preferLocal = $true
                default     = $true
            }
        }

        It 'Returns local URI when local server is reachable' {
            # Mock Test-PatServerReachable within module scope
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    return [PSCustomObject]@{
                        Reachable      = $true
                        ResponseTimeMs = 15
                        Error          = $null
                    }
                }
            }

            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal
            $result.Uri | Should -Be 'http://192.168.1.100:32400'
            $result.IsLocal | Should -Be $true
            $result.SelectionReason | Should -Match 'Local URI reachable'
        }

        It 'Returns primary URI when local server is not reachable' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    return [PSCustomObject]@{
                        Reachable      = $false
                        ResponseTimeMs = $null
                        Error          = 'Connection refused'
                    }
                }
            }

            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal
            $result.Uri | Should -Be 'https://plex.example.com:32400'
            $result.IsLocal | Should -Be $false
            $result.SelectionReason | Should -Match 'Local URI not reachable'
        }

        It 'Includes response time in selection reason when reachable' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    return [PSCustomObject]@{
                        Reachable      = $true
                        ResponseTimeMs = 42
                        Error          = $null
                    }
                }
            }

            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal
            $result.SelectionReason | Should -Match '42ms'
        }

        It 'Includes error message in selection reason when not reachable' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    return [PSCustomObject]@{
                        Reachable      = $false
                        ResponseTimeMs = $null
                        Error          = 'Connection timed out'
                    }
                }
            }

            $result = & $script:SelectPatServerUri -Server $script:serverPreferLocal
            $result.SelectionReason | Should -Match 'Connection timed out'
        }
    }

    Context 'Error Handling' {
        It 'Throws when server has no URI' {
            $invalidServer = [PSCustomObject]@{
                name    = 'Invalid Server'
                default = $true
            }
            { & $script:SelectPatServerUri -Server $invalidServer } | Should -Throw "*missing required 'uri' property*"
        }

        It 'Throws when server URI is empty' {
            $invalidServer = [PSCustomObject]@{
                name    = 'Invalid Server'
                uri     = ''
                default = $true
            }
            { & $script:SelectPatServerUri -Server $invalidServer } | Should -Throw "*missing required 'uri' property*"
        }
    }

    Context 'Selection Reason Messages' {
        BeforeAll {
            $script:serverWithAll = [PSCustomObject]@{
                name        = 'Test Server'
                uri         = 'https://plex.example.com:32400'
                localUri    = 'http://192.168.1.100:32400'
                preferLocal = $true
                default     = $true
            }
        }

        It 'Provides clear selection reason for ForceRemote' {
            $result = & $script:SelectPatServerUri -Server $script:serverWithAll -ForceRemote
            $result.SelectionReason | Should -Be 'ForceRemote parameter specified'
        }

        It 'Provides clear selection reason for ForceLocal' {
            $result = & $script:SelectPatServerUri -Server $script:serverWithAll -ForceLocal
            $result.SelectionReason | Should -Be 'ForceLocal parameter specified'
        }

        It 'Returns all expected properties' {
            $result = & $script:SelectPatServerUri -Server $script:serverWithAll -ForceLocal
            $result.PSObject.Properties.Name | Should -Contain 'Uri'
            $result.PSObject.Properties.Name | Should -Contain 'IsLocal'
            $result.PSObject.Properties.Name | Should -Contain 'SelectionReason'
        }
    }

    Context 'Token passthrough for reachability testing' {
        BeforeAll {
            $script:serverPreferLocal = [PSCustomObject]@{
                name        = 'Test Server'
                uri         = 'https://plex.example.com:32400'
                localUri    = 'http://192.168.1.100:32400'
                preferLocal = $true
                default     = $true
            }
        }

        It 'Passes token to reachability test' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    param($ServerUri, $Token, $TimeoutSeconds)
                    # Verify token was passed
                    if ($Token -ne 'test-auth-token') {
                        throw "Expected token 'test-auth-token' but got '$Token'"
                    }
                    return [PSCustomObject]@{
                        Reachable      = $true
                        ResponseTimeMs = 10
                        Error          = $null
                    }
                }
            }

            # Should not throw if token is passed correctly
            { & $script:SelectPatServerUri -Server $script:serverPreferLocal -Token 'test-auth-token' } |
                Should -Not -Throw
        }

        It 'Passes SkipCertificateCheck to reachability test' {
            & (Get-Module PlexAutomationToolkit) {
                Mock Test-PatServerReachable {
                    param($ServerUri, $Token, $TimeoutSeconds, $SkipCertificateCheck)
                    # Verify SkipCertificateCheck was passed
                    if (-not $SkipCertificateCheck) {
                        throw "Expected SkipCertificateCheck to be true"
                    }
                    return [PSCustomObject]@{
                        Reachable      = $true
                        ResponseTimeMs = 10
                        Error          = $null
                    }
                }
            }

            # Should not throw if SkipCertificateCheck is passed correctly
            { & $script:SelectPatServerUri -Server $script:serverPreferLocal -SkipCertificateCheck } |
                Should -Not -Throw
        }
    }
}
