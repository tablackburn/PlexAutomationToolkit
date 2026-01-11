BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertTo-PatCollectionObject' {
    Context 'Parameter validation' {
        It 'Should throw when CollectionData is null' {
            {
                InModuleScope PlexAutomationToolkit {
                    ConvertTo-PatCollectionObject -CollectionData $null -LibraryId 1 -ServerUri 'http://localhost:32400'
                }
            } | Should -Throw
        }

        It 'Should throw when LibraryId is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    $data = @{ ratingKey = 123; title = 'Test' }
                    ConvertTo-PatCollectionObject -CollectionData $data -ServerUri 'http://localhost:32400'
                }
            } | Should -Throw
        }

        It 'Should throw when ServerUri is null' {
            {
                InModuleScope PlexAutomationToolkit {
                    $data = @{ ratingKey = 123; title = 'Test' }
                    ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri $null
                }
            } | Should -Throw
        }

        It 'Should throw when ServerUri is empty' {
            {
                InModuleScope PlexAutomationToolkit {
                    $data = @{ ratingKey = 123; title = 'Test' }
                    ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri ''
                }
            } | Should -Throw
        }

        It 'Should accept null LibraryName' {
            {
                InModuleScope PlexAutomationToolkit {
                    $data = @{ ratingKey = 123; title = 'Test'; childCount = 5 }
                    ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -LibraryName $null -ServerUri 'http://localhost:32400'
                }
            } | Should -Not -Throw
        }
    }

    Context 'Property mapping from API data' {
        It 'Should map ratingKey to CollectionId' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 12345
                    title      = 'Test Collection'
                    childCount = 10
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.CollectionId | Should -Be 12345
            $result.CollectionId | Should -BeOfType [int]
        }

        It 'Should map title to Title' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Marvel Collection'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.Title | Should -Be 'Marvel Collection'
        }

        It 'Should map childCount to ItemCount' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 42
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.ItemCount | Should -Be 42
            $result.ItemCount | Should -BeOfType [int]
        }

        It 'Should preserve LibraryId parameter' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 7 -ServerUri 'http://localhost:32400'
            }

            $result.LibraryId | Should -Be 7
        }

        It 'Should preserve LibraryName parameter when provided' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -LibraryName 'Movies' -ServerUri 'http://localhost:32400'
            }

            $result.LibraryName | Should -Be 'Movies'
        }

        It 'Should set LibraryName to null when not provided' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.LibraryName | Should -BeNullOrEmpty
        }

        It 'Should map thumb to Thumb' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    thumb      = '/library/metadata/123/thumb/1234567890'
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.Thumb | Should -Be '/library/metadata/123/thumb/1234567890'
        }

        It 'Should preserve ServerUri parameter' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'https://plex.example.com:32400'
            }

            $result.ServerUri | Should -Be 'https://plex.example.com:32400'
        }
    }

    Context 'DateTime conversion from Unix timestamps' {
        It 'Should convert addedAt Unix timestamp to DateTime' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    addedAt    = 1609459200  # 2021-01-01 00:00:00 UTC
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.AddedAt | Should -BeOfType [DateTime]
            $result.AddedAt | Should -Not -BeNullOrEmpty
        }

        It 'Should convert updatedAt Unix timestamp to DateTime' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    updatedAt  = 1609545600  # 2021-01-02 00:00:00 UTC
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.UpdatedAt | Should -BeOfType [DateTime]
            $result.UpdatedAt | Should -Not -BeNullOrEmpty
        }

        It 'Should convert both addedAt and updatedAt timestamps' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    addedAt    = 1609459200
                    updatedAt  = 1609545600
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.AddedAt | Should -BeOfType [DateTime]
            $result.UpdatedAt | Should -BeOfType [DateTime]
            $result.UpdatedAt | Should -BeGreaterThan $result.AddedAt
        }

        It 'Should use LocalDateTime for converted timestamps' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    addedAt    = 1609459200
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            # Verify it's a DateTime (not DateTimeOffset) and represents local time
            $result.AddedAt.GetType().Name | Should -Be 'DateTime'
        }
    }

    Context 'Handling null/missing optional fields' {
        It 'Should set AddedAt to null when addedAt is missing' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.AddedAt | Should -BeNullOrEmpty
        }

        It 'Should set AddedAt to null when addedAt is null' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    addedAt    = $null
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.AddedAt | Should -BeNullOrEmpty
        }

        It 'Should set AddedAt to null when addedAt is 0' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    addedAt    = 0
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.AddedAt | Should -BeNullOrEmpty
        }

        It 'Should set UpdatedAt to null when updatedAt is missing' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.UpdatedAt | Should -BeNullOrEmpty
        }

        It 'Should set UpdatedAt to null when updatedAt is null' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    updatedAt  = $null
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.UpdatedAt | Should -BeNullOrEmpty
        }

        It 'Should set UpdatedAt to null when updatedAt is 0' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    updatedAt  = 0
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.UpdatedAt | Should -BeNullOrEmpty
        }

        It 'Should handle missing thumb property' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.Thumb | Should -BeNullOrEmpty
        }

        It 'Should handle null thumb property' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                    thumb      = $null
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.Thumb | Should -BeNullOrEmpty
        }
    }

    Context 'PSTypeName is set correctly' {
        It 'Should set PSTypeName to PlexAutomationToolkit.Collection' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test Collection'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
        }

        It 'Should return PSCustomObject type' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result | Should -BeOfType [PSCustomObject]
        }
    }

    Context 'Complete collection object with all properties' {
        It 'Should create complete collection object with all properties' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 98765
                    title      = 'Star Wars Collection'
                    childCount = 11
                    thumb      = '/library/metadata/98765/thumb/1234567890'
                    addedAt    = 1609459200  # 2021-01-01 00:00:00 UTC
                    updatedAt  = 1640995200  # 2022-01-01 00:00:00 UTC
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 3 -LibraryName 'Movies' -ServerUri 'https://plex.example.com:32400'
            }

            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
            $result.CollectionId | Should -Be 98765
            $result.Title | Should -Be 'Star Wars Collection'
            $result.LibraryId | Should -Be 3
            $result.LibraryName | Should -Be 'Movies'
            $result.ItemCount | Should -Be 11
            $result.Thumb | Should -Be '/library/metadata/98765/thumb/1234567890'
            $result.AddedAt | Should -BeOfType [DateTime]
            $result.UpdatedAt | Should -BeOfType [DateTime]
            $result.ServerUri | Should -Be 'https://plex.example.com:32400'
        }
    }

    Context 'Type casting behavior' {
        It 'Should cast ratingKey to int from string' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = '12345'
                    title      = 'Test'
                    childCount = 5
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.CollectionId | Should -Be 12345
            $result.CollectionId | Should -BeOfType [int]
        }

        It 'Should cast childCount to int from string' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Test'
                    childCount = '42'
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.ItemCount | Should -Be 42
            $result.ItemCount | Should -BeOfType [int]
        }

        It 'Should handle zero childCount' {
            $result = InModuleScope PlexAutomationToolkit {
                $data = [PSCustomObject]@{
                    ratingKey  = 123
                    title      = 'Empty Collection'
                    childCount = 0
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -ServerUri 'http://localhost:32400'
            }

            $result.ItemCount | Should -Be 0
            $result.ItemCount | Should -BeOfType [int]
        }
    }

    Context 'Real-world API response simulation' {
        It 'Should convert typical Plex collection API response' {
            $result = InModuleScope PlexAutomationToolkit {
                # Simulates actual Plex API response structure
                $data = [PSCustomObject]@{
                    ratingKey         = 234567
                    key               = '/library/collections/234567/children'
                    guid              = 'collection://234567'
                    type              = 'collection'
                    title             = 'MCU Timeline Order'
                    subtype           = 'movie'
                    summary           = 'Marvel movies in chronological order'
                    index             = 1
                    thumb             = '/library/metadata/234567/thumb/1640995200'
                    addedAt           = 1577836800  # 2020-01-01 00:00:00 UTC
                    updatedAt         = 1640995200  # 2022-01-01 00:00:00 UTC
                    childCount        = 30
                    maxYear           = 2023
                    minYear           = 2008
                    contentRating     = 'PG-13'
                    ratingCount       = 150
                }
                ConvertTo-PatCollectionObject -CollectionData $data -LibraryId 1 -LibraryName 'Movies' -ServerUri 'http://localhost:32400'
            }

            # Verify all mapped properties
            $result.CollectionId | Should -Be 234567
            $result.Title | Should -Be 'MCU Timeline Order'
            $result.LibraryId | Should -Be 1
            $result.LibraryName | Should -Be 'Movies'
            $result.ItemCount | Should -Be 30
            $result.Thumb | Should -Be '/library/metadata/234567/thumb/1640995200'
            $result.AddedAt | Should -BeOfType [DateTime]
            $result.UpdatedAt | Should -BeOfType [DateTime]
            $result.ServerUri | Should -Be 'http://localhost:32400'
            $result.PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.Collection'
        }
    }
}
