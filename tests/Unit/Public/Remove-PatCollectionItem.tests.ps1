BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatCollectionItem' {

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
            ItemCount    = 3
            ServerUri    = 'http://plex.local:32400'
        }

        $script:mockServerContext = [PSCustomObject]@{
            Uri            = 'http://plex.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            WasExplicitUri = $true
            Server         = $null
            Token          = 'test-token'
        }

        $script:mockDefaultServerContext = [PSCustomObject]@{
            Uri            = 'http://plex-default.local:32400'
            Headers        = @{ Accept = 'application/json'; 'X-Plex-Token' = 'default-token' }
            WasExplicitUri = $false
            Server         = @{ name = 'Default'; uri = 'http://plex-default.local:32400' }
            Token          = $null
        }
    }

    Context 'Function definition' {
        It 'Should exist as a public function' {
            Get-Command Remove-PatCollectionItem -Module PlexAutomationToolkit | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess' {
            $cmd = Get-Command Remove-PatCollectionItem -Module PlexAutomationToolkit
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It 'Should have Medium ConfirmImpact' {
            $cmd = Get-Command Remove-PatCollectionItem -Module PlexAutomationToolkit
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.ConfirmImpact | Should -Be 'Medium'
        }
    }

    Context 'When removing items by collection ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
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

        It 'Removes items without error' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Calls Resolve-PatServerContext' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $ServerUri -eq 'http://plex.local:32400'
            }
        }

        It 'Calls the delete endpoint for each item' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/collections/12345/items/1001'
            }
        }

        It 'Uses DELETE method' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Makes separate delete calls for multiple items' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002, 1003 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 3 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Passes Token to Resolve-PatServerContext' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -Token 'my-token'
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }

        It 'Returns updated collection with PassThru' {
            $result = Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' -PassThru
            $result.ItemCount | Should -Be 3
        }

        It 'Does not return anything without PassThru' {
            $result = Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When collection info cannot be retrieved for ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                throw 'Collection not found'
            }
        }

        It 'Still attempts to remove items' {
            Remove-PatCollectionItem -CollectionId 99999 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }

    Context 'When removing items by collection name with LibraryId' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
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
                return $null
            }
        }

        It 'Resolves name to ID and removes items' {
            { Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Calls Get-PatCollection with correct parameters' {
            Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryId -eq 1
            }
        }

        It 'Throws when collection name not found' {
            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $null
            }
            { Remove-PatCollectionItem -CollectionName 'Nonexistent' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name 'Nonexistent' in library 1*"
        }
    }

    Context 'When removing items by collection name with LibraryName' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
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
                return $null
            }
        }

        It 'Resolves name to ID using LibraryName and removes items' {
            { Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Passes LibraryName to Get-PatCollection' {
            Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryName -eq 'Movies'
            }
        }

        It 'Throws when collection not found in library' {
            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $null
            }
            { Remove-PatCollectionItem -CollectionName 'Nonexistent' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name 'Nonexistent' in library 'Movies'*"
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

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }
        }

        It 'Rejects empty rating keys array (mandatory parameter)' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey @() -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*empty array*'
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
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

        It 'Accepts rating keys from pipeline' {
            { 1001, 1002, 1003 | Remove-PatCollectionItem -CollectionId 12345 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Processes all piped rating keys' {
            1001, 1002 | Remove-PatCollectionItem -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 2 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockDefaultServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
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

        It 'Uses default server when ServerUri not specified' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                -not $ServerUri
            }
        }

        It 'Uses URI from server context' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-default.local:32400'
            }
        }

        It 'Does not pass ServerUri to Get-PatCollection when using default' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('ServerUri')
            }
        }
    }

    Context 'When server resolution fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                throw 'No default server configured. Use Add-PatServer with -Default or specify -ServerUri.'
            }
        }

        It 'Throws an error indicating no default server' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } |
                Should -Throw '*No default server configured*'
        }

        It 'Wraps error with context' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } |
                Should -Throw '*Failed to resolve server*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
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

        It 'Throws an error with context' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw '*Failed to remove items from collection*'
        }
    }

    Context 'When using WhatIf' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
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

        It 'Does not remove items with WhatIf' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Still resolves server context with WhatIf' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -Times 1
        }
    }

    Context 'Parameter validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }
        }

        It 'Rejects CollectionId of 0' {
            { Remove-PatCollectionItem -CollectionId 0 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects negative CollectionId' {
            { Remove-PatCollectionItem -CollectionId -1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects RatingKey of 0' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 0 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects negative RatingKey' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey -1 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects LibraryId of 0' {
            { Remove-PatCollectionItem -CollectionName 'Test' -LibraryId 0 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }

        It 'Rejects empty CollectionName' {
            { Remove-PatCollectionItem -CollectionName '' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }
    }

    Context 'When PassThru with collection name resolution' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
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
            $result = Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' -PassThru
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When collection info unavailable for target description' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                throw 'Collection not found'
            }
        }

        It 'Uses fallback description without collection info' {
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Still processes removal request' {
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 1
        }
    }

    Context 'When using LibraryId parameter set' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                return $null
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
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
            Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryId -eq 1
            }
        }
    }

    Context 'When processing multiple items via pipeline' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
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

        It 'Accumulates all rating keys before processing' {
            @(1001, 1002, 1003, 1004) | Remove-PatCollectionItem -CollectionId 12345 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 4 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }

    Context 'CollectionName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Remove-PatCollectionItem
            $collectionNameParam = $command.Parameters['CollectionName']
            $script:collectionNameCompleter = $collectionNameParam.Attributes | Where-Object { $_ -is [ArgumentCompleter] } | Select-Object -ExpandProperty ScriptBlock
        }

        It 'Returns matching collection names with LibraryName' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                        [PSCustomObject]@{ Title = 'Horror Classics' }
                        [PSCustomObject]@{ Title = 'Action Films' }
                    )
                }

                $fakeBoundParams = @{ LibraryName = 'Movies' }
                & $completer 'Remove-PatCollectionItem' 'CollectionName' 'Mar' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Returns matching collection names with LibraryId' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                    )
                }

                $fakeBoundParams = @{ LibraryId = 1 }
                & $completer 'Remove-PatCollectionItem' 'CollectionName' '' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Returns nothing when no LibraryName or LibraryId provided' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                $fakeBoundParams = @{}
                & $completer 'Remove-PatCollectionItem' 'CollectionName' '' $null $fakeBoundParams
            }
            $results | Should -BeNullOrEmpty
        }

        It 'Passes ServerUri to Get-PatCollection' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @()
                }

                $fakeBoundParams = @{
                    LibraryName = 'Movies'
                    ServerUri   = 'http://custom:32400'
                }
                & $completer 'Remove-PatCollectionItem' 'CollectionName' '' $null $fakeBoundParams

                Should -Invoke Get-PatCollection -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Filters collections by word to complete' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:collectionNameCompleter } {
                Mock Get-PatCollection {
                    return @(
                        [PSCustomObject]@{ Title = 'Marvel Movies' }
                        [PSCustomObject]@{ Title = 'Horror Classics' }
                    )
                }

                $fakeBoundParams = @{ LibraryName = 'Movies' }
                & $completer 'Remove-PatCollectionItem' 'CollectionName' 'Hor' $null $fakeBoundParams
            }
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context 'LibraryName argument completer' {
        BeforeAll {
            $command = Get-Command -Module PlexAutomationToolkit -Name Remove-PatCollectionItem
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
                            @{ title = 'Music' }
                        )
                    }
                }

                & $completer 'Remove-PatCollectionItem' 'LibraryName' 'Mov' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }

        It 'Passes ServerUri when provided' {
            InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:libraryNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                        )
                    }
                }

                $fakeBoundParams = @{ ServerUri = 'http://custom:32400' }
                & $completer 'Remove-PatCollectionItem' 'LibraryName' '' $null $fakeBoundParams

                Should -Invoke Get-PatLibrary -ParameterFilter {
                    $ServerUri -eq 'http://custom:32400'
                }
            }
        }

        It 'Filters libraries by word to complete' {
            $results = InModuleScope PlexAutomationToolkit -Parameters @{ completer = $script:libraryNameCompleter } {
                Mock Get-PatLibrary {
                    return @{
                        Directory = @(
                            @{ title = 'Movies' }
                            @{ title = 'TV Shows' }
                            @{ title = 'Music' }
                        )
                    }
                }

                & $completer 'Remove-PatCollectionItem' 'LibraryName' 'Mu' $null @{}
            }
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
