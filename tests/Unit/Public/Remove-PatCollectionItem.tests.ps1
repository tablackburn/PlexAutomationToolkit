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

        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://plex-test-server.local:32400'
            default = $true
            token   = 'test-token'
        }
    }

    Context 'When removing items by collection ID' {
        BeforeAll {
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

        It 'Returns updated collection with PassThru' {
            $result = Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' -PassThru
            $result.ItemCount | Should -Be 3
        }
    }

    Context 'When removing items by collection name with LibraryId' {
        BeforeAll {
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
                throw "No collection found with name '$CollectionName'"
            }
        }

        It 'Resolves name to ID and removes items' {
            { Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Throws when collection name not found' {
            { Remove-PatCollectionItem -CollectionName 'Nonexistent' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*"
        }
    }

    Context 'When removing items by collection name with LibraryName' {
        BeforeAll {
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
                throw "No collection found with name '$CollectionName'"
            }
        }

        It 'Resolves name to ID using LibraryName and removes items' {
            { Remove-PatCollectionItem -CollectionName 'Test Collection' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Throws when collection name not found in library' {
            { Remove-PatCollectionItem -CollectionName 'Nonexistent' -LibraryName 'Movies' -RatingKey 1001 -ServerUri 'http://plex.local:32400' } |
                Should -Throw "*No collection found with name*"
        }
    }

    Context 'When using pipeline input' {
        BeforeAll {
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
                param($BaseUri, $Endpoint)
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
            Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001
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
            { Remove-PatCollectionItem -CollectionId 12345 -RatingKey 1001 } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When API call fails' {
        BeforeAll {
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
    }
}
