BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'New-PatCollection' {

    BeforeAll {
        $script:mockLibraryResponse = @{
            type = 'movie'
        }

        $script:mockCreatedCollection = @{
            Metadata = @(
                @{
                    ratingKey  = '99999'
                    title      = 'New Collection'
                    childCount = 2
                    thumb      = '/library/collections/99999/thumb'
                    addedAt    = 1703548800
                    updatedAt  = 1703548800
                }
            )
        }

        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When creating a collection' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method, $Headers)
                # Return machine identifier for server info call
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Creates collection without error' {
            { New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Gets server info for machine identifier' {
            New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/'
            }
        }

        It 'Calls collections endpoint with POST' {
            New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'Returns created collection with PassThru' {
            $result = New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' -PassThru
            $result.CollectionId | Should -Be 99999
            $result.Title | Should -Be 'New Collection'
        }

        It 'Has correct PSTypeName with PassThru' {
            $result = New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -PassThru
            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
        }
    }

    Context 'When RatingKey is missing' {
        It 'Throws when no rating keys provided' {
            { New-PatCollection -Title 'Empty Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Accepts rating keys from pipeline' {
            $result = 1001, 1002, 1003 | New-PatCollection -Title 'Pipeline Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' -PassThru
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001
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
            { New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                # Return machine identifier for server info call
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    throw 'Connection refused'
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Throws an error with context' {
            { New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*Failed to create collection*'
        }
    }

    Context 'When using WhatIf' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                # Return machine identifier for server info call
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Does not create collection with WhatIf' {
            New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'POST'
            }
        }
    }

    Context 'When using LibraryName parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                        @{ key = '2'; title = 'TV Shows'; type = 'show' }
                    )
                }
            }
        }

        It 'Resolves LibraryName to LibraryId' {
            { New-PatCollection -Title 'Test' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Throws when LibraryName not found' {
            { New-PatCollection -Title 'Test' -LibraryName 'Nonexistent' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No library found with name*"
        }
    }

    Context 'When using different library types' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Uses correct type for show library' {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '2'; title = 'TV Shows'; type = 'show' }
                    )
                }
            }

            New-PatCollection -Title 'Test' -LibraryId 2 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'type=2'
            }
        }

        It 'Uses correct type for artist library' {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '3'; title = 'Music'; type = 'artist' }
                    )
                }
            }

            New-PatCollection -Title 'Test' -LibraryId 3 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'type=8'
            }
        }

        It 'Uses correct type for photo library' {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '4'; title = 'Photos'; type = 'photo' }
                    )
                }
            }

            New-PatCollection -Title 'Test' -LibraryId 4 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'type=13'
            }
        }

        It 'Defaults to type 1 for unknown library type' {
            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '5'; title = 'Unknown'; type = 'custom' }
                    )
                }
            }

            New-PatCollection -Title 'Test' -LibraryId 5 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $QueryString -match 'type=1'
            }
        }
    }

    Context 'When PassThru result has no Metadata' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    # Return result without Metadata wrapper
                    return @{
                        ratingKey  = '99999'
                        title      = 'Direct Result'
                        childCount = 1
                    }
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Handles result without Metadata wrapper' {
            $result = New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -PassThru
            $result.CollectionId | Should -Be 99999
            $result.Title | Should -Be 'Direct Result'
        }
    }

    Context 'LibraryName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name New-PatCollection
            $libraryNameParam = $command.Parameters['LibraryName']
            $script:libraryNameCompleter = $libraryNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching library names' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:libraryNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                        )
                    }
                }
                & $completer 'New-PatCollection' 'LibraryName' 'Mov' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:libraryNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }
                & $completer 'New-PatCollection' 'LibraryName' '' $null @{ ServerUri = 'http://custom:32400' }
            }
            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://custom:32400'
            }
        }
    }

    Context 'When machine identifier retrieval fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Connection failed'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws error with machine identifier context' {
            { New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*Failed to retrieve server machine identifier*'
        }
    }

    Context 'Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return [PSCustomObject]@{
                    Uri            = 'http://plex.local:32400'
                    Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'my-token' }
                    WasExplicitUri = $true
                    Server         = $null
                    Token          = 'my-token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '1'; title = 'Movies'; type = 'movie' }
                    )
                }
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }
}
