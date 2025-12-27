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

        It 'Creates collection without error' {
            { New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001, 1002 -ServerUri 'http://plex.local:32400' } |
                Should -Not -Throw
        }

        It 'Calls library endpoint to get type' {
            New-PatCollection -Title 'New Collection' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400'
            Should -Invoke -ModuleName PlexAutomationToolkit Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/sections/1'
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

            Mock -ModuleName PlexAutomationToolkit Get-PatAuthHeaders {
                return @{ Accept = 'application/json'; 'X-Plex-Token' = 'test-token' }
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
                if ($Method -eq 'POST') {
                    return $script:mockCreatedCollection
                }
                return $script:mockLibraryResponse
            }

            Mock -ModuleName PlexAutomationToolkit Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                return "$BaseUri$Endpoint"
            }
        }

        It 'Does not create collection with WhatIf' {
            New-PatCollection -Title 'Test' -LibraryId 1 -RatingKey 1001 -ServerUri 'http://plex.local:32400' -WhatIf
            Should -Invoke -ModuleName PlexAutomationToolkit Invoke-PatApi -Times 0 -ParameterFilter {
                $Method -eq 'POST'
            }
        }
    }
}
