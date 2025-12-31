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
            { Update-PatLibrary -SectionId 2 -Confirm:$false } | Should -Throw '*Failed to get default server*'
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

    Context 'SectionName argument completer' {
        BeforeAll {
            # Get the completer script block from the parameter
            $command = Get-Command -Module PlexAutomationToolkit -Name Update-PatLibrary
            $sectionNameParam = $command.Parameters['SectionName']
            $script:sectionNameCompleter = $sectionNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching section names' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                & $completer 'Update-PatLibrary' 'SectionName' 'Mov' $null @{}
            }
            # Results are CompletionResult objects
            $completionTexts = $results | ForEach-Object { if ($_ -is [System.Management.Automation.CompletionResult]) { $_.CompletionText } else { $_ } }
            $completionTexts | Should -Contain 'Movies'
            $completionTexts | Should -Not -Contain 'TV Shows'
        }

        It 'Uses ServerUri from bound parameters' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ ServerUri = 'http://custom-server:32400' }
                & $completer 'Update-PatLibrary' 'SectionName' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom-server:32400'
                }
            }
        }

        It 'Handles errors gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    throw 'Connection failed'
                }

                # Should not throw, just return empty
                & $completer 'Update-PatLibrary' 'SectionName' '' $null @{}
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles quoted input' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:sectionNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'TV Shows' }
                        )
                    }
                }

                & $completer 'Update-PatLibrary' 'SectionName' "'TV" $null @{}
            }
            # Result should be a CompletionResult with the value quoted
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Path argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Update-PatLibrary
            $pathParam = $command.Parameters['Path']
            $script:pathCompleter = $pathParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns root paths when no input provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                        @{ path = '/mnt/tv' }
                    )
                }

                $fakeBoundParams = @{ SectionId = 2 }
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }

            $results | Should -Not -BeNullOrEmpty
        }

        It 'Resolves SectionId from SectionName' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ key = '/library/sections/2'; title = 'Movies' }
                        )
                    }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                $fakeBoundParams = @{ SectionName = 'Movies' }
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Uses explicit ServerUri when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                $fakeBoundParams = @{ ServerUri = 'http://custom:32400'; SectionId = 2 }
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibraryPath -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Browses subdirectories when input provided' {
            # This test verifies the browse code path is exercised
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                    )
                }

                $fakeBoundParams = @{ SectionId = 2 }
                # Execute the completer - should not throw
                { & $completer 'Update-PatLibrary' 'Path' '/mnt/movies/A' $null $fakeBoundParams } | Should -Not -Throw

                # Verify the browse function was called
                Should -Invoke Get-PatLibraryChildItem
            }
        }

        It 'Falls back to root paths when browse returns null' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                        @{ path = '/mnt/movies-backup' }
                    )
                }

                Mock Get-PatLibraryChildItem {
                    return $null
                }

                $fakeBoundParams = @{ SectionId = 2 }
                & $completer 'Update-PatLibrary' 'Path' '/mnt/movies' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Returns nothing when no default server and no ServerUri' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return $null
                }

                $fakeBoundParams = @{ SectionId = 2 }
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Returns nothing when no SectionId or SectionName provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                $fakeBoundParams = @{}
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles browse exception gracefully' {
            # When browse throws, should fall back to matching root paths
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                Mock Get-PatLibraryChildItem {
                    throw 'Access denied'
                }

                $fakeBoundParams = @{ SectionId = 2 }
                # Should not throw - exception is caught internally
                { & $completer 'Update-PatLibrary' 'Path' '/mnt/movies/test' $null $fakeBoundParams } | Should -Not -Throw
            }
        }

        It 'Handles Get-PatStoredServer exception gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    throw 'Config error'
                }

                $fakeBoundParams = @{ SectionId = 2 }
                # Should not throw
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles exact root path match for browsing' {
            # When input exactly matches a root path, browse that path directly
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies' }
                    )
                }

                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ path = '/mnt/movies/Action' }
                        [PSCustomObject]@{ path = '/mnt/movies/Comedy' }
                    )
                }

                $fakeBoundParams = @{ SectionId = 2 }
                # Execute the completer
                { & $completer 'Update-PatLibrary' 'Path' '/mnt/movies' $null $fakeBoundParams } | Should -Not -Throw

                # Verify browse was called with the exact root path
                Should -Invoke Get-PatLibraryChildItem -ParameterFilter {
                    $Path -eq '/mnt/movies'
                }
            }
        }

        It 'Handles SectionName resolution failure gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibrary {
                    throw 'API error'
                }

                $fakeBoundParams = @{ SectionName = 'Movies' }
                # Should not throw
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles Get-PatLibraryPath exception gracefully' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    throw 'Cannot get paths'
                }

                $fakeBoundParams = @{ SectionId = 2 }
                # Should not throw
                & $completer 'Update-PatLibrary' 'Path' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Handles items with Path property (capital P)' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:pathCompleter } {
                Mock Get-PatStoredServer {
                    return @{ name = 'Default'; uri = 'http://plex:32400' }
                }

                Mock Get-PatLibraryPath {
                    return @(
                        @{ path = '/mnt/movies' }
                    )
                }

                Mock Get-PatLibraryChildItem {
                    return @(
                        [PSCustomObject]@{ Path = '/mnt/movies/Action' }
                    )
                }

                $fakeBoundParams = @{ SectionId = 2 }
                & $completer 'Update-PatLibrary' 'Path' '/mnt/movies/A' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
