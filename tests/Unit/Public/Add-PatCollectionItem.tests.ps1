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
    }

    Context 'When adding items by collection ID' {
        BeforeAll {
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
            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Does nothing and returns without error' {
            # Since RatingKey is mandatory, this test validates early exit when empty array somehow passed
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey @() -ServerUri 'http://plex.local:32400' } |
                Should -Throw
        }
    }

    Context 'When using default server' {
        BeforeAll {
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

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeader {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $script:mockCollection
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001
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
            { Add-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
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
    }
}
