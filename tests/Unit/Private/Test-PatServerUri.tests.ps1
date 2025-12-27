BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'

    # Get reference to private function
    $script:TestPatServerUri = & (Get-Module PlexAutomationToolkit) { Get-Command Test-PatServerUri }
}

Describe 'Test-PatServerUri' {

    Context 'Valid URIs' {
        It 'Accepts HTTP URI with port' {
            $result = & $script:TestPatServerUri -Uri 'http://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Accepts HTTPS URI with port' {
            $result = & $script:TestPatServerUri -Uri 'https://plex.local:32400'
            $result | Should -Be $true
        }

        It 'Accepts HTTP URI without port' {
            $result = & $script:TestPatServerUri -Uri 'http://plex.example.com'
            $result | Should -Be $true
        }

        It 'Accepts HTTPS URI without port' {
            $result = & $script:TestPatServerUri -Uri 'https://secure-plex.example.com'
            $result | Should -Be $true
        }

        It 'Accepts IP address with port' {
            $result = & $script:TestPatServerUri -Uri 'http://192.168.1.100:32400'
            $result | Should -Be $true
        }

        It 'Accepts localhost' {
            $result = & $script:TestPatServerUri -Uri 'http://localhost:32400'
            $result | Should -Be $true
        }

        It 'Accepts single segment hostname' {
            $result = & $script:TestPatServerUri -Uri 'http://plex:32400'
            $result | Should -Be $true
        }

        It 'Accepts multi-segment domain' {
            $result = & $script:TestPatServerUri -Uri 'https://plex.media.home.local:32400'
            $result | Should -Be $true
        }

        It 'Accepts empty/null string (deferred to ValidateNotNullOrEmpty)' {
            $result = & $script:TestPatServerUri -Uri ''
            $result | Should -Be $true
        }
    }

    Context 'Invalid URIs' {
        It 'Rejects URI without scheme' {
            { & $script:TestPatServerUri -Uri 'plex.local:32400' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects FTP scheme' {
            { & $script:TestPatServerUri -Uri 'ftp://plex.local:32400' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects file scheme' {
            { & $script:TestPatServerUri -Uri 'file:///path/to/file' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects URI with path' {
            { & $script:TestPatServerUri -Uri 'http://plex.local:32400/api' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects URI with query string' {
            { & $script:TestPatServerUri -Uri 'http://plex.local:32400?token=abc' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects URI with trailing slash' {
            { & $script:TestPatServerUri -Uri 'http://plex.local:32400/' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects malformed URI' {
            { & $script:TestPatServerUri -Uri 'http://:32400' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Rejects random text' {
            { & $script:TestPatServerUri -Uri 'not a url' } | Should -Throw '*must be a valid HTTP or HTTPS URL*'
        }

        It 'Includes provided URI in error message' {
            { & $script:TestPatServerUri -Uri 'invalid-uri' } | Should -Throw "*Received: 'invalid-uri'*"
        }
    }

    Context 'Edge cases' {
        It 'Accepts port at edge of valid range (1)' {
            $result = & $script:TestPatServerUri -Uri 'http://plex.local:1'
            $result | Should -Be $true
        }

        It 'Accepts port at edge of valid range (65535)' {
            $result = & $script:TestPatServerUri -Uri 'http://plex.local:65535'
            $result | Should -Be $true
        }

        It 'Accepts hostname with hyphens' {
            $result = & $script:TestPatServerUri -Uri 'http://my-plex-server:32400'
            $result | Should -Be $true
        }

        It 'Accepts domain with hyphens' {
            $result = & $script:TestPatServerUri -Uri 'http://my-plex.my-domain.com:32400'
            $result | Should -Be $true
        }
    }
}
