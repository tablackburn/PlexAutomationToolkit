BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Get-PatAuthHeaders.ps1')
}

Describe 'Get-PatAuthHeaders' {
    Context 'When server has a token' {
        It 'Should include X-Plex-Token header when token is present' {
            $server = [PSCustomObject]@{
                name    = 'TestServer'
                uri     = 'http://test:32400'
                token   = 'ABC123xyz'
                default = $true
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers['X-Plex-Token'] | Should -Be 'ABC123xyz'
            $headers['Accept'] | Should -Be 'application/json'
            $headers.Count | Should -Be 2
        }

        It 'Should include X-Plex-Token header with special characters' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = 'xyz123-ABC_456.789'
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers['X-Plex-Token'] | Should -Be 'xyz123-ABC_456.789'
        }
    }

    Context 'When server does not have a token' {
        It 'Should not include X-Plex-Token header when token property is missing' {
            $server = [PSCustomObject]@{
                name    = 'TestServer'
                uri     = 'http://test:32400'
                default = $true
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
            $headers['Accept'] | Should -Be 'application/json'
            $headers.Count | Should -Be 1
        }

        It 'Should not include X-Plex-Token header when token is null' {
            $server = [PSCustomObject]@{
                name    = 'TestServer'
                uri     = 'http://test:32400'
                token   = $null
                default = $true
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
        }

        It 'Should not include X-Plex-Token header when token is empty string' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = ''
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
        }

        It 'Should not include X-Plex-Token header when token is whitespace only' {
            $server = [PSCustomObject]@{
                name  = 'TestServer'
                uri   = 'http://test:32400'
                token = '   '
            }

            $headers = Get-PatAuthHeaders -Server $server

            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
        }
    }

    Context 'When no server object is provided' {
        It 'Should return default headers when server parameter is null' {
            $headers = Get-PatAuthHeaders -Server $null

            $headers['Accept'] | Should -Be 'application/json'
            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
            $headers.Count | Should -Be 1
        }

        It 'Should return default headers when server parameter is omitted' {
            $headers = Get-PatAuthHeaders

            $headers['Accept'] | Should -Be 'application/json'
            $headers.ContainsKey('X-Plex-Token') | Should -Be $false
            $headers.Count | Should -Be 1
        }
    }
}
