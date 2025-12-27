BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatCollection' {

    BeforeAll {
        $script:mockCollection = @{
            ratingKey        = '12345'
            title            = 'Test Collection'
            librarySectionID = '1'
            childCount       = 5
        }

        $script:mockCollectionsResponse = @{
            Metadata = @(
                @{
                    ratingKey        = '12345'
                    title            = 'Test Collection'
                    librarySectionID = '1'
                    childCount       = 5
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

    Context 'When removing collection by ID' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'DELETE') {
                    return $null
                }
                return $script:mockCollection
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return [PSCustomObject]@{
                    CollectionId = 12345
                    Title        = 'Test Collection'
                    LibraryId    = 1
                    ItemCount    = 5
                    ServerUri    = 'http://plex.local:32400'
                }
            }
        }

        It 'Removes collection without error' {
            { Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls the delete endpoint' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/collections/12345'
            }
        }

        It 'Uses DELETE method' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Returns collection info with PassThru' {
            $result = Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result.CollectionId | Should -Be 12345
            $result.Title | Should -Be 'Test Collection'
        }
    }

    Context 'When removing collection by Name' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                param($Uri, $Method)
                if ($Method -eq 'DELETE') {
                    return $null
                }
                return $script:mockCollectionsResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint)
                return "$BaseUri$Endpoint"
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                param($CollectionName, $LibraryId)
                if ($CollectionName -eq 'Test Collection') {
                    return [PSCustomObject]@{
                        CollectionId = 12345
                        Title        = 'Test Collection'
                        LibraryId    = 1
                        ItemCount    = 5
                        ServerUri    = 'http://plex.local:32400'
                    }
                }
                throw "No collection found with name '$CollectionName'"
            }
        }

        It 'Resolves name to ID and removes' {
            { Remove-PatCollection -CollectionName 'Test Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Throws when collection name not found' {
            { Remove-PatCollection -CollectionName 'Nonexistent' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No collection found with name*"
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
                return [PSCustomObject]@{
                    CollectionId = 12345
                    Title        = 'Test Collection'
                    LibraryId    = 1
                    ItemCount    = 5
                }
            }
        }

        It 'Uses default server when ServerUri not specified' {
            Remove-PatCollection -CollectionId 12345 -Confirm:$false
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
            { Remove-PatCollection -CollectionId 12345 -Confirm:$false } | Should -Throw '*No default server configured*'
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
                return [PSCustomObject]@{
                    CollectionId = 12345
                    Title        = 'Test Collection'
                    LibraryId    = 1
                    ItemCount    = 5
                }
            }
        }

        It 'Throws an error with context' {
            { Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to remove collection*'
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
                return [PSCustomObject]@{
                    CollectionId = 12345
                    Title        = 'Test Collection'
                    LibraryId    = 1
                    ItemCount    = 5
                }
            }
        }

        It 'Does not delete collection with WhatIf' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }
}
