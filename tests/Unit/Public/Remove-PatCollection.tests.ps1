BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Remove-PatCollection' {

    BeforeAll {
        $script:mockCollection = [PSCustomObject]@{
            CollectionId = 12345
            Title        = 'Test Collection'
            LibraryId    = 1
            ItemCount    = 5
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
            Get-Command Remove-PatCollection -Module PlexAutomationToolkit | Should -Not -BeNullOrEmpty
        }

        It 'Should support ShouldProcess' {
            $cmd = Get-Command Remove-PatCollection -Module PlexAutomationToolkit
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It 'Should have High ConfirmImpact' {
            $cmd = Get-Command Remove-PatCollection -Module PlexAutomationToolkit
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.ConfirmImpact | Should -Be 'High'
        }

        It 'Should have ById as default parameter set' {
            $cmd = Get-Command Remove-PatCollection -Module PlexAutomationToolkit
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.DefaultParameterSetName | Should -Be 'ById'
        }
    }

    Context 'When removing collection by ID' {
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

        It 'Removes collection without error' {
            { Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Calls Resolve-PatServerContext with ServerUri' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $ServerUri -eq 'http://plex.local:32400'
            }
        }

        It 'Calls the delete endpoint with correct collection ID' {
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

        It 'Passes Token to Resolve-PatServerContext' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Token 'my-token' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }

        It 'Returns collection info with PassThru' {
            $result = Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result.CollectionId | Should -Be 12345
            $result.Title | Should -Be 'Test Collection'
        }

        It 'Does not return anything without PassThru' {
            $result = Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            $result | Should -BeNullOrEmpty
        }

        It 'Retrieves collection info before deletion' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -Times 1
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

        It 'Still attempts to delete the collection' {
            Remove-PatCollection -CollectionId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Does not return anything with PassThru when collection info unavailable' {
            $result = Remove-PatCollection -CollectionId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When removing collection by Name with LibraryName' {
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
                param($CollectionName, $LibraryName)
                if ($CollectionName -eq 'Test Collection' -and $LibraryName -eq 'Movies') {
                    return $script:mockCollection
                }
                return $null
            }
        }

        It 'Resolves name to ID and removes' {
            { Remove-PatCollection -CollectionName 'Test Collection' -LibraryName 'Movies' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Passes LibraryName to Get-PatCollection' {
            Remove-PatCollection -CollectionName 'Test Collection' -LibraryName 'Movies' -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryName -eq 'Movies'
            }
        }

        It 'Returns collection with PassThru' {
            $result = Remove-PatCollection -CollectionName 'Test Collection' -LibraryName 'Movies' -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result.Title | Should -Be 'Test Collection'
        }
    }

    Context 'When removing collection by Name with LibraryId' {
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
                param($CollectionName, $LibraryId)
                if ($CollectionName -eq 'Test Collection' -and $LibraryId -eq 1) {
                    return $script:mockCollection
                }
                return $null
            }
        }

        It 'Resolves name to ID using LibraryId' {
            { Remove-PatCollection -CollectionName 'Test Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Passes LibraryId to Get-PatCollection' {
            Remove-PatCollection -CollectionName 'Test Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Get-PatCollection -ParameterFilter {
                $CollectionName -eq 'Test Collection' -and $LibraryId -eq 1
            }
        }
    }

    Context 'When collection name not found' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }

            Mock -ModuleName PlexAutomationToolkit Get-PatCollection {
                return $null
            }
        }

        It 'Throws when collection not found with LibraryName' {
            { Remove-PatCollection -CollectionName 'Nonexistent' -LibraryName 'Movies' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No collection found with name 'Nonexistent' in library 'Movies'*"
        }

        It 'Throws when collection not found with LibraryId' {
            { Remove-PatCollection -CollectionName 'Nonexistent' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw "*No collection found with name 'Nonexistent' in library 1*"
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
            Remove-PatCollection -CollectionId 12345 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                -not $ServerUri
            }
        }

        It 'Uses URI from server context' {
            Remove-PatCollection -CollectionId 12345 -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://plex-default.local:32400'
            }
        }

        It 'Does not pass ServerUri to Get-PatCollection when using default' {
            Remove-PatCollection -CollectionId 12345 -Confirm:$false
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
            { Remove-PatCollection -CollectionId 12345 -Confirm:$false } |
                Should -Throw '*No default server configured*'
        }

        It 'Wraps error with context' {
            { Remove-PatCollection -CollectionId 12345 -Confirm:$false } |
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
            { Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw '*Failed to remove collection*'
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

        It 'Does not delete collection with WhatIf' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Still resolves server context with WhatIf' {
            Remove-PatCollection -CollectionId 12345 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -Times 1
        }
    }

    Context 'Pipeline input' {
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
                return [PSCustomObject]@{
                    CollectionId = $CollectionId
                    Title        = "Collection $CollectionId"
                    ItemCount    = 3
                }
            }
        }

        It 'Accepts CollectionId from pipeline' {
            { 12345 | Remove-PatCollection -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Processes multiple IDs from pipeline' {
            @(111, 222, 333) | Remove-PatCollection -ServerUri 'http://plex.local:32400' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 3 -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Accepts object with CollectionId property from pipeline' {
            $obj = [PSCustomObject]@{ CollectionId = 12345 }
            { $obj | Remove-PatCollection -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Not -Throw
        }
    }

    Context 'Parameter validation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Resolve-PatServerContext {
                return $script:mockServerContext
            }
        }

        It 'Rejects CollectionId of 0' {
            { Remove-PatCollection -CollectionId 0 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects negative CollectionId' {
            { Remove-PatCollection -CollectionId -1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects LibraryId of 0' {
            { Remove-PatCollection -CollectionName 'Test' -LibraryId 0 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects empty CollectionName' {
            { Remove-PatCollection -CollectionName '' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }

        It 'Rejects empty LibraryName' {
            { Remove-PatCollection -CollectionName 'Test' -LibraryName '' -ServerUri 'http://plex.local:32400' -Confirm:$false } |
                Should -Throw
        }
    }

    Context 'When using PassThru without collection info available' {
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

        It 'Does not return anything with PassThru when collection info unavailable' {
            $result = Remove-PatCollection -CollectionId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false -PassThru
            $result | Should -BeNullOrEmpty
        }

        It 'Uses fallback target description when collection info unavailable' {
            Remove-PatCollection -CollectionId 99999 -ServerUri 'http://plex.local:32400' -Confirm:$false
            # Should still call the API even without collection info
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 1
        }
    }

    Context 'When using Token with collection name lookup' {
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
                param($CollectionName, $LibraryId)
                if ($CollectionName -eq 'Test Collection') {
                    return $script:mockCollection
                }
                return $null
            }
        }

        It 'Passes Token through for collection name lookup' {
            Remove-PatCollection -CollectionName 'Test Collection' -LibraryId 1 -ServerUri 'http://plex.local:32400' -Token 'my-token' -Confirm:$false
            Should -Invoke -ModuleName PlexAutomationToolkit Resolve-PatServerContext -ParameterFilter {
                $Token -eq 'my-token'
            }
        }
    }
}
