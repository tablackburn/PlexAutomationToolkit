BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Add-PatCollectionItem' {

    BeforeAll {
        $script:mockCollection = [PSCustomObject]@{
            CollectionId = 12345
            Title        = 'Test Collection'
            LibraryId    = 1
            ItemCount    = 5
            ServerUri    = 'http://plex.local:32400'
        }

        $script:mockUpdatedCollection = [PSCustomObject]@{
            CollectionId = 12345
            Title        = 'Test Collection'
            LibraryId    = 1
            ItemCount    = 7
            ServerUri    = 'http://plex.local:32400'
        }

        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }

        $script:mockServerContext = [PSCustomObject]@{
            Uri            = 'http://plex.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            WasExplicitUri = $true
            Server         = $null
            Token          = 'test-token'
        }

        $script:mockDefaultServerContext = [PSCustomObject]@{
            Uri            = 'http://plex-test-server.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            WasExplicitUri = $false
            Server         = $script:mockDefaultServer
            Token          = $null
        }
    }

    Context 'When adding items by collection ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                # Return machine identifier for server info call
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionId)
                if ($CollectionId) {
                    return $script:mockUpdatedCollection
                }
                return $script:mockCollection
            }
        }

        It 'Adds items without error' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Calls the items endpoint' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/collections/12345/items'
            }
        }

        It 'Uses PUT method' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Returns updated collection with PassThru' {
            $result = Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' -PassThru
            $result.ItemCount | Should -Be 7
        }
    }

    Context 'When adding items by collection name with LibraryId' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionName, $CollectionId, $LibraryId)
                if ($CollectionName -eq 'Test Collection') {
                    return $script:mockCollection
                }
                if ($CollectionId) {
                    return $script:mockUpdatedCollection
                }
                throw "No collection found with name '$CollectionName'"
            }
        }

        It 'Resolves name to ID and adds items' {
            { Add-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Throws when collection name not found' {
            { Add-PatCollectionItem -CollectionName 'Nonexistent' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*"
        }
    }

    Context 'When adding items by collection name with LibraryName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionName, $CollectionId, $LibraryName)
                if ($CollectionName -eq 'Test Collection' -and $LibraryName -eq 'Movies') {
                    return $script:mockCollection
                }
                if ($CollectionId) {
                    return $script:mockUpdatedCollection
                }
                throw "No collection found with name '$CollectionName'"
            }
        }

        It 'Resolves name to ID using LibraryName and adds items' {
            { Add-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Throws when collection name not found in library' {
            { Add-PatCollectionItem -CollectionName 'Nonexistent' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*"
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Accepts rating keys from pipeline' {
            { 1001, 1002, 1003 | Add-PatCollectionItem -CollectionId 12345 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Makes separate API calls for each item' {
            1001, 1002, 1003 | Add-PatCollectionItem -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            # Collections require one API call per item (unlike playlists which can batch)
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 3 -ParameterFilter {
                $Method -eq 'PUT'
            }
        }
    }

    Context 'When no rating keys provided' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Rejects empty rating keys array (mandatory parameter)' {
            # Since RatingKey is mandatory, this test validates that empty arrays are rejected
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey @() -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*empty array*'
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockDefaultServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                -not $ServerUri
            }
        }

        It 'Uses URI from server context' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-test-server.local:32400'
            }
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                throw 'No default server configured. Use Add-PatServer with -Default or specify -ServerUri.'
            }
        }

        It 'Throws an error indicating no default server' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } | Should -Throw '*No default server configured*'
        }

        It 'Wraps error with context' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } | Should -Throw '*Failed to resolve server*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            $script:apiCallCount = 0
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                $script:apiCallCount++
                if ($script:apiCallCount -eq 1) {
                    # First call is for machine identifier - return valid response
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                # Subsequent calls fail
                throw 'Connection refused'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        BeforeEach {
            $script:apiCallCount = 0
        }

        It 'Throws an error with context' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*Failed to add items to collection*'
        }
    }

    Context 'When using WhatIf' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Does not add items with WhatIf' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Still retrieves machine identifier with WhatIf' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 1 -ParameterFilter {
                $Uri -match '/$'
            }
        }
    }

    Context 'When using Token parameter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }

    Context 'Parameter validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }
        }

        It 'Rejects CollectionId of 0' {
            { Add-PatCollectionItem -CollectionId 0 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects negative CollectionId' {
            { Add-PatCollectionItem -CollectionId -1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects RatingKey of 0' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 0 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects negative RatingKey' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey -1 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects LibraryId of 0' {
            { Add-PatCollectionItem -CollectionName 'Test' -LibraryId 0 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects empty CollectionName' {
            { Add-PatCollectionItem -CollectionName '' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }
    }

    Context 'When machine identifier retrieval fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw 'Failed to retrieve server info'
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Throws error with context about machine identifier' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*Failed to retrieve server machine identifier*'
        }
    }

    Context 'When collection info cannot be retrieved for ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                throw 'Collection not found'
            }
        }

        It 'Still adds items when collection lookup fails' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Uses fallback description without collection info' {
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }
    }

    Context 'When PassThru with collection name resolution' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            $script:getCollectionCallCount = 0
            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionName, $CollectionId, $LibraryName)
                $script:getCollectionCallCount++
                if ($CollectionName -eq 'Test Collection') {
                    return $script:mockCollection
                }
                if ($CollectionId) {
                    return $script:mockUpdatedCollection
                }
                return $null
            }
        }

        BeforeEach {
            $script:getCollectionCallCount = 0
        }

        It 'Returns updated collection with PassThru from name lookup' {
            $result = Add-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' -PassThru
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When using LibraryId parameter set' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri)
                if ($Uri -match '/$' -or $Uri -match ':32400$') {
                    return @{ machineIdentifier = 'test-machine-id' }
                }
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionName, $CollectionId, $LibraryId)
                if ($CollectionName -eq 'Test Collection' -and $LibraryId -eq 1) {
                    return $script:mockCollection
                }
                if ($CollectionId) {
                    return $script:mockUpdatedCollection
                }
                return $null
            }
        }

        It 'Passes LibraryId to Get-PatCollection' {
            Add-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryId -eq 1
            }
        }

        It 'Throws when collection not found with LibraryId' {
            { Add-PatCollectionItem -CollectionName 'Nonexistent' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*library 1*"
        }
    }

    Context 'CollectionName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Add-PatCollectionItem
            $collectionNameParam = $command.Parameters['CollectionName']
            $script:collectionNameCompleter = $collectionNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns nothing when no LibraryName or LibraryId provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                & $completer 'Add-PatCollectionItem' 'CollectionName' '' $null @{}
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Returns matching collections when LibraryName provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                        [PSCustomObject]@{ Title = 'DC Movies' }
                    )
                }
                & $completer 'Add-PatCollectionItem' 'CollectionName' 'Marv' $null @{ LibraryName = 'Movies' }
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Returns matching collections when LibraryId provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                    )
                }
                & $completer 'Add-PatCollectionItem' 'CollectionName' '' $null @{ LibraryId = 1 }
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                    )
                }
                & $completer 'Add-PatCollectionItem' 'CollectionName' '' $null @{ LibraryName = 'Movies'; ServerUri = 'http://custom:32400' }
            }
            Should -Invoke Get-PatCollection -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://custom:32400'
            }
        }
    }

    Context 'LibraryName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Add-PatCollectionItem
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
                & $completer 'Add-PatCollectionItem' 'LibraryName' 'Mov' $null @{}
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
                & $completer 'Add-PatCollectionItem' 'LibraryName' '' $null @{ ServerUri = 'http://custom:32400' }
            }
            Should -Invoke Get-PatLibrary -ModuleName PlexAutomationToolkit -ParameterFilter {
                $ServerUri -eq 'http://custom:32400'
            }
        }
    }
}
