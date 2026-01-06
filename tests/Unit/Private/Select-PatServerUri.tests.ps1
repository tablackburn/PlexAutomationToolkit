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

        # Note: Testing actual reachability requires mocking Test-PatServerReachable
        # which is covered in integration tests
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
}
