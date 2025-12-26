BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'

    # Import the function directly for testing
    . (Join-Path $ModuleRoot 'Private\Join-PatUri.ps1')
}

Describe 'Join-PatUri' {
    Context 'Basic URI construction' {
        It 'Should join base URI and endpoint' {
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '/library/sections'
            $result | Should -Be 'http://localhost:32400/library/sections'
        }

        It 'Should handle trailing slash on base URI' {
            $result = Join-PatUri -BaseUri 'http://localhost:32400/' -Endpoint '/library/sections'
            $result | Should -Be 'http://localhost:32400/library/sections'
        }

        It 'Should handle missing leading slash on endpoint' {
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint 'library/sections'
            $result | Should -Be 'http://localhost:32400/library/sections'
        }

        It 'Should handle both trailing and missing leading slash' {
            $result = Join-PatUri -BaseUri 'http://localhost:32400/' -Endpoint 'library/sections'
            $result | Should -Be 'http://localhost:32400/library/sections'
        }
    }

    Context 'Query string parameters' {
        It 'Should append query string' {
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '/library/sections' -QueryString 'X-Plex-Token=test-token'
            $result | Should -Be 'http://localhost:32400/library/sections?X-Plex-Token=test-token'
        }

        It 'Should append query string with multiple parameters' {
            $queryString = 'X-Plex-Token=test-token&type=1'
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '/library/sections' -QueryString $queryString
            $result | Should -Match 'X-Plex-Token=test-token'
            $result | Should -Match 'type=1'
            $result | Should -Match '\?'
        }

        It 'Should handle URL encoded query string values' {
            $queryString = 'path=%2Ffolder%20with%20spaces%2Ffile.mkv'
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '/library/sections/1/all' -QueryString $queryString
            $result | Should -Match 'path=%2[Ff]folder'
            $result | Should -Match 'spaces'
        }

        It 'Should handle special characters in query string' {
            $queryString = 'title=Movie%20%26%20Show'
            $result = Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '/search' -QueryString $queryString
            $result | Should -Match 'title='
            $result | Should -Match '%26'  # URL encoded &
        }
    }

    Context 'Edge cases' {
        It 'Should handle HTTPS URIs' {
            $result = Join-PatUri -BaseUri 'https://localhost:32400' -Endpoint '/library/sections'
            $result | Should -Be 'https://localhost:32400/library/sections'
        }

        It 'Should handle custom ports' {
            $result = Join-PatUri -BaseUri 'http://localhost:8080' -Endpoint '/library/sections'
            $result | Should -Be 'http://localhost:8080/library/sections'
        }

        It 'Should handle hostname instead of localhost' {
            $result = Join-PatUri -BaseUri 'http://plex.local:32400' -Endpoint '/library/sections'
            $result | Should -Be 'http://plex.local:32400/library/sections'
        }
    }

    Context 'Parameter validation' {
        It 'Should throw on null BaseUri' {
            { Join-PatUri -BaseUri $null -Endpoint '/test' } | Should -Throw
        }

        It 'Should throw on empty BaseUri' {
            { Join-PatUri -BaseUri '' -Endpoint '/test' } | Should -Throw
        }

        It 'Should throw on invalid URI format' {
            { Join-PatUri -BaseUri 'not-a-uri' -Endpoint '/test' } | Should -Throw "*Failed to join URI*"
        }

        It 'Should throw on null Endpoint' {
            { Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint $null } | Should -Throw
        }

        It 'Should throw on empty Endpoint' {
            { Join-PatUri -BaseUri 'http://localhost:32400' -Endpoint '' } | Should -Throw
        }
    }

    Context 'Error messages' {
        It 'Should include error details in exception message' {
            { Join-PatUri -BaseUri 'not-a-valid-uri' -Endpoint '/test' } | Should -Throw "*Failed to join URI*"
        }
    }
}
