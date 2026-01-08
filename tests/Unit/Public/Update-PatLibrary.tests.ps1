BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Update-PatLibrary' {

    BeforeAll {
        # Mock library sections response
        $script:mockSectionsResponse = @{
            size      = 3
            allowSync = $false
            title1    = 'Plex Library'
            Directory = @(
                @{
                    key   = '2'
                    type  = 'movie'
                    title = 'Movies'
                }
                @{
                    key   = '3'
                    type  = 'show'
                    title = 'TV Shows'
                }
                @{
                    key   = '9'
                    type  = 'movie'
                    title = '4K Movies'
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
        }
    }

    Context 'When refreshing library by SectionId with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return "http://plex-test-server.local:32400/library/sections/$SectionId/refresh"
            }
        }

        It 'Refreshes the library section' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'Post'
            }
        }

        It 'Calls Join-PatUri with correct endpoint' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-test-server.local:32400' -and
                $Endpoint -eq '/library/sections/2/refresh'
            }
        }

        It 'Validates SectionId is greater than 0' {
            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 0 -Confirm:$false } | Should -Throw
        }
    }

    Context 'When refreshing library by SectionName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

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
        }

        It 'Resolves section name to section ID' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Movies' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $ServerUri -eq 'http://plex-test-server.local:32400'
            }
        }

        It 'Refreshes the correct library section' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionName 'TV Shows' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/sections/3/refresh'
            }
        }

        It 'Throws when section name is not found' {
            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Nonexistent' -Confirm:$false } | Should -Throw "*No library section found with name 'Nonexistent'*"
        }

        It 'Throws when multiple sections have the same name' {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '2'; title = 'Movies' }
                        @{ key = '9'; title = 'Movies' }
                    )
                }
            }

            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionName 'Movies' -Confirm:$false } | Should -Throw "*Multiple library sections found*"
        }
    }

    Context 'When refreshing library with a specific path' {
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
        }

        It 'Includes the path parameter in the request' {
            $testPath = '/mnt/media/Movies/Action'
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path $testPath -SkipPathValidation -Confirm:$false

            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -like "*path=*"
            }
        }

        It 'URL-encodes the path parameter' {
            $testPath = '/mnt/media/Movies With Spaces'
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path $testPath -SkipPathValidation -Confirm:$false

            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'path=.*%20.*'
            }
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
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }
        }

        It 'Uses the default server URI' {
            Update-PatLibrary -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Calls Join-PatUri with default server URI' {
            Update-PatLibrary -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-test-server.local:32400'
            }
        }

        It 'Uses Get-PatAuthenticationHeader for stored server' {
            Update-PatLibrary -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader -ParameterFilter {
                $Server.name -eq 'Test Server'
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
            { Update-PatLibrary -SectionId 2 -Confirm:$false } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }
        }

        It 'Does not call Invoke-PatApi' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 0
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection timeout'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }
        }

        It 'Throws an error with context' {
            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Confirm:$false } | Should -Throw '*Failed to refresh Plex library*'
        }
    }

    Context 'When using -PassThru' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    size      = 1
                    Directory = @{
                        key   = '2'
                        type  = 'movie'
                        title = 'Movies'
                    }
                }
            }
        }

        It 'Returns the library section after refreshing' {
            $result = Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -PassThru -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.Directory.title | Should -Be 'Movies'
        }

        It 'Calls Get-PatLibrary after refresh' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -PassThru -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $SectionId -eq 2 -and $ServerUri -eq 'http://plex-test-server.local:32400'
            }
        }
    }

    Context 'When using -PassThru with default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    size      = 1
                    Directory = @{
                        key   = '2'
                        type  = 'movie'
                        title = 'Movies'
                    }
                }
            }
        }

        It 'Calls Get-PatLibrary without ServerUri for default server' {
            Update-PatLibrary -SectionId 2 -PassThru -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $SectionId -eq 2 -and -not $ServerUri
            }
        }
    }

    Context 'When using -Wait' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Wait-PatLibraryScan {
                return $null
            }
        }

        It 'Waits for scan to complete' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Wait -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatLibraryScan -ParameterFilter {
                $SectionId -eq 2 -and $Timeout -eq 300
            }
        }

        It 'Uses custom timeout value' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Wait -Timeout 60 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatLibraryScan -ParameterFilter {
                $Timeout -eq 60
            }
        }
    }

    Context 'When using -ReportChanges' {
        BeforeAll {
            $script:mockBeforeItems = @(
                [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
                [PSCustomObject]@{ ratingKey = '2'; title = 'Movie B' }
            )

            $script:mockAfterItems = @(
                [PSCustomObject]@{ ratingKey = '1'; title = 'Movie A' }
                [PSCustomObject]@{ ratingKey = '2'; title = 'Movie B' }
                [PSCustomObject]@{ ratingKey = '3'; title = 'Movie C' }  # Added
            )

            $script:mockChanges = @(
                [PSCustomObject]@{
                    PSTypeName = 'PlexAutomationToolkit.LibraryChange'
                    ChangeType = 'Added'
                    RatingKey  = '3'
                    Title      = 'Movie C'
                }
            )

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Wait-PatLibraryScan {
                return $null
            }

            $script:getItemCallCount = 0
            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryItem {
                $script:getItemCallCount++
                if ($script:getItemCallCount -eq 1) {
                    return $script:mockBeforeItems
                }
                return $script:mockAfterItems
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatLibraryContent {
                return $script:mockChanges
            }
        }

        BeforeEach {
            $script:getItemCallCount = 0
        }

        It 'Returns changes detected during scan' {
            $result = Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -ReportChanges -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            ($result | Select-Object -First 1).ChangeType | Should -Be 'Added'
        }

        It 'Captures library state before and after scan' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -ReportChanges -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibraryItem -Times 2
        }

        It 'Compares before and after states' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -ReportChanges -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Compare-PatLibraryContent
        }

        It 'Implicitly waits for scan when reporting changes' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -ReportChanges -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatLibraryScan
        }
    }

    Context 'When path validation is enabled (default)' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Test-PatLibraryPath {
                return $true
            }

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
        }

        It 'Validates path before refreshing' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/media/Movies' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Test-PatLibraryPath -ParameterFilter {
                $Path -eq '/mnt/media/Movies'
            }
        }

        It 'Proceeds with refresh when path is valid' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/media/Movies' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi
        }
    }

    Context 'When path validation fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Test-PatLibraryPath {
                return $false
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }
        }

        It 'Throws when path does not exist' {
            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/invalid/path' -Confirm:$false } | Should -Throw '*Path validation failed*'
        }

        It 'Does not call Invoke-PatApi when path is invalid' {
            try {
                Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/invalid/path' -Confirm:$false
            }
            catch {
                # Expected
            }
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Exactly 0
        }
    }

    Context 'When using -SkipPathValidation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Test-PatLibraryPath {
                return $false  # Would fail if called
            }

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
        }

        It 'Skips path validation' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/any/path' -SkipPathValidation -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Test-PatLibraryPath -Exactly 0
        }

        It 'Proceeds with refresh without validation' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Path '/mnt/any/path' -SkipPathValidation -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi
        }
    }

    Context 'When using explicit Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }
        }

        It 'Uses token in request headers' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -Token 'my-secret-token' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'my-secret-token'
            }
        }
    }

    Context 'When Get-PatStoredServer throws' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                throw 'Configuration file corrupted'
            }
        }

        It 'Throws with server error context' {
            { Update-PatLibrary -SectionId 2 -Confirm:$false } | Should -Throw '*Failed to resolve server*'
        }
    }

    Context 'When using SectionName with default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Calls Get-PatLibrary without ServerUri for section name resolution' {
            Update-PatLibrary -SectionName 'Movies' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                -not $ServerUri
            }
        }
    }

    Context 'Parameter validation' {
        It 'Validates Timeout is between 1 and 3600' {
            { Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionId 2 -Wait -Timeout 0 } | Should -Throw
            { Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionId 2 -Wait -Timeout 3601 } | Should -Throw
        }

        It 'Does not allow empty SectionName' {
            { Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionName '' } | Should -Throw
        }

        It 'Does not allow empty Path' {
            { Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionId 2 -Path '' } | Should -Throw
        }
    }

    Context 'When using SectionName with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Calls Get-PatLibrary with explicit ServerUri for section resolution' {
            Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionName 'Movies' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatLibrary -ParameterFilter {
                $ServerUri -eq 'http://plex.local:32400'
            }
        }
    }

    Context 'When using Wait with ServerUri in parameters' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Wait-PatLibraryScan {
                return $null
            }
        }

        It 'Passes ServerUri to Wait-PatLibraryScan' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Wait -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Wait-PatLibraryScan -ParameterFilter {
                $ServerUri -eq 'http://plex-test-server.local:32400'
            }
        }
    }

    Context 'When ReportChanges has empty before state' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }

            Mock -ModuleName PlexAutomationToolkit Wait-PatLibraryScan {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibraryItem {
                return @()
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatLibraryContent {
                return @()
            }
        }

        It 'Handles empty library gracefully' {
            { Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -ReportChanges -Confirm:$false } |
                Should -Not -Throw
        }
    }

    Context 'When headers built without server object' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                return 'http://plex-test-server.local:32400/library/sections/2/refresh'
            }
        }

        It 'Builds headers with Accept header when no token provided' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Adds X-Plex-Token when Token parameter provided' {
            Update-PatLibrary -ServerUri 'http://plex-test-server.local:32400' -SectionId 2 -Token 'explicit-token' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Headers['X-Plex-Token'] -eq 'explicit-token'
            }
        }
    }

    Context 'When SectionName fails to resolve' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                throw 'Connection failed'
            }
        }

        It 'Throws with wrapped error message' {
            { Update-PatLibrary -ServerUri 'http://plex.local:32400' -SectionName 'Movies' -Confirm:$false } |
                Should -Throw '*Failed to resolve section name*'
        }
    }

    Context 'When using Path with SectionName and default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Test-PatLibraryPath {
                return $true
            }

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

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'default-token' }
            }
        }

        It 'Resolves SectionName and validates Path with default server' {
            Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/NewMovie' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Test-PatLibraryPath -ParameterFilter {
                $Path -eq '/mnt/media/Movies/NewMovie' -and $SectionId -eq 2
            }
        }
    }
}
