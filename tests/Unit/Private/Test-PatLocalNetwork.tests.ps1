BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get reference to private function
    $script:TestPatLocalNetwork = & (Get-Module PlexAutomationToolkit) { Get-Command Test-PatLocalNetwork }
}

Describe 'Test-PatLocalNetwork' {

    Context 'IPv4 Private Ranges' {
        It 'Identifies 10.x.x.x as private' {
            & $script:TestPatLocalNetwork -IPAddress '10.0.0.1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '10.255.255.255' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '10.100.50.25' | Should -Be $true
        }

        It 'Identifies 172.16-31.x.x as private' {
            & $script:TestPatLocalNetwork -IPAddress '172.16.0.1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '172.31.255.255' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '172.20.100.50' | Should -Be $true
        }

        It 'Identifies 172.x outside 16-31 as public' {
            & $script:TestPatLocalNetwork -IPAddress '172.15.0.1' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '172.32.0.1' | Should -Be $false
        }

        It 'Identifies 192.168.x.x as private' {
            & $script:TestPatLocalNetwork -IPAddress '192.168.0.1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '192.168.255.255' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '192.168.1.100' | Should -Be $true
        }

        It 'Identifies 127.x.x.x (localhost) as private' {
            & $script:TestPatLocalNetwork -IPAddress '127.0.0.1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '127.255.255.255' | Should -Be $true
        }

        It 'Identifies 169.254.x.x (link-local/APIPA) as private' {
            & $script:TestPatLocalNetwork -IPAddress '169.254.0.1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress '169.254.255.255' | Should -Be $true
        }
    }

    Context 'IPv4 Public Addresses' {
        It 'Identifies public IPs as not private' {
            & $script:TestPatLocalNetwork -IPAddress '8.8.8.8' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '1.1.1.1' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '203.0.113.50' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '74.125.224.72' | Should -Be $false
        }

        It 'Identifies edge cases correctly' {
            & $script:TestPatLocalNetwork -IPAddress '9.255.255.255' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '11.0.0.1' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '192.167.1.1' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '192.169.1.1' | Should -Be $false
        }
    }

    Context 'IPv6 Addresses' {
        It 'Identifies ::1 (localhost) as private' {
            & $script:TestPatLocalNetwork -IPAddress '::1' | Should -Be $true
        }

        It 'Identifies fc00::/7 (ULA) as private' {
            & $script:TestPatLocalNetwork -IPAddress 'fc00::1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress 'fd00::1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress 'fdab:cdef:1234::1' | Should -Be $true
        }

        It 'Identifies fe80::/10 (link-local) as private' {
            & $script:TestPatLocalNetwork -IPAddress 'fe80::1' | Should -Be $true
            & $script:TestPatLocalNetwork -IPAddress 'fe80::abcd:1234:5678:9abc' | Should -Be $true
        }

        It 'Identifies public IPv6 as not private' {
            & $script:TestPatLocalNetwork -IPAddress '2001:4860:4860::8888' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '2607:f8b0:4004:800::200e' | Should -Be $false
        }
    }

    Context 'Hostname Resolution' {
        It 'Returns true for localhost hostname' {
            & $script:TestPatLocalNetwork -Hostname 'localhost' | Should -Be $true
        }

        It 'Returns false for unresolvable hostname' {
            & $script:TestPatLocalNetwork -Hostname 'this-hostname-definitely-does-not-exist-12345.invalid' | Should -Be $false
        }
    }

    Context 'Invalid Input' {
        It 'Returns false for invalid IP address format' {
            & $script:TestPatLocalNetwork -IPAddress 'not-an-ip' | Should -Be $false
            & $script:TestPatLocalNetwork -IPAddress '256.256.256.256' | Should -Be $false
        }
    }
}
