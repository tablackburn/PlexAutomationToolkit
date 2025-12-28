BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertTo-PsCustomObjectFromHashtable' {
    Context 'Null and primitive handling' {
        It 'Throws when input is null due to Mandatory parameter' {
            { InModuleScope PlexAutomationToolkit { ConvertTo-PsCustomObjectFromHashtable -Hashtable $null } } | Should -Throw '*is null*'
        }

        It 'Returns string as-is' {
            $result = InModuleScope PlexAutomationToolkit { ConvertTo-PsCustomObjectFromHashtable -Hashtable 'test string' }
            $result | Should -Be 'test string'
        }

        It 'Returns integer as-is' {
            $result = InModuleScope PlexAutomationToolkit { ConvertTo-PsCustomObjectFromHashtable -Hashtable 42 }
            $result | Should -Be 42
        }

        It 'Returns boolean as-is' {
            $result = InModuleScope PlexAutomationToolkit { ConvertTo-PsCustomObjectFromHashtable -Hashtable $true }
            $result | Should -BeTrue
        }

        It 'Returns double as-is' {
            $result = InModuleScope PlexAutomationToolkit { ConvertTo-PsCustomObjectFromHashtable -Hashtable 3.14 }
            $result | Should -Be 3.14
        }
    }

    Context 'Simple hashtable conversion' {
        It 'Converts a simple hashtable to PSCustomObject' {
            $hashtable = @{
                Name  = 'Test'
                Value = 123
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            $result.Name | Should -Be 'Test'
            $result.Value | Should -Be 123
        }

        It 'Converts an empty hashtable to empty PSCustomObject' {
            $hashtable = @{}
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Converts ordered hashtable with case-variant keys (last wins)' {
            # PSCustomObject property access is case-insensitive, so when converting
            # a hashtable with both "guid" and "Guid", the last one processed wins
            $hashtable = [ordered]@{}
            $hashtable['guid'] = 'lowercase-guid'
            $hashtable['Guid'] = 'uppercase-guid'

            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            # Both access the same property (case-insensitive), last value wins
            $result.guid | Should -Be 'uppercase-guid'
            $result.Guid | Should -Be 'uppercase-guid'
        }
    }

    Context 'Nested hashtable conversion' {
        It 'Converts nested hashtables recursively' {
            $hashtable = @{
                Name   = 'Parent'
                Child  = @{
                    Name  = 'Child'
                    Value = 456
                }
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            $result.Name | Should -Be 'Parent'
            $result.Child | Should -BeOfType [PSCustomObject]
            $result.Child.Name | Should -Be 'Child'
            $result.Child.Value | Should -Be 456
        }

        It 'Converts deeply nested hashtables' {
            $hashtable = @{
                Level1 = @{
                    Level2 = @{
                        Level3 = @{
                            Value = 'deep'
                        }
                    }
                }
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result.Level1.Level2.Level3.Value | Should -Be 'deep'
            $result.Level1.Level2.Level3 | Should -BeOfType [PSCustomObject]
        }
    }

    Context 'Array handling' {
        It 'Converts array of primitives' {
            $array = @(1, 2, 3)
            $result = InModuleScope PlexAutomationToolkit -ArgumentList @(, $array) { param($arr) ConvertTo-PsCustomObjectFromHashtable -Hashtable $arr }

            $result | Should -HaveCount 3
            $result[0] | Should -Be 1
            $result[1] | Should -Be 2
            $result[2] | Should -Be 3
        }

        It 'Converts array of hashtables' {
            $array = @(
                @{ Name = 'First'; Id = 1 }
                @{ Name = 'Second'; Id = 2 }
            )
            $result = InModuleScope PlexAutomationToolkit -ArgumentList @(, $array) { param($arr) ConvertTo-PsCustomObjectFromHashtable -Hashtable $arr }

            $result | Should -HaveCount 2
            $result[0] | Should -BeOfType [PSCustomObject]
            $result[0].Name | Should -Be 'First'
            $result[1].Name | Should -Be 'Second'
        }

        It 'Converts hashtable with array property' {
            $hashtable = @{
                Name  = 'Container'
                Items = @(
                    @{ Id = 1 }
                    @{ Id = 2 }
                )
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            $result.Items | Should -HaveCount 2
            $result.Items[0] | Should -BeOfType [PSCustomObject]
            $result.Items[0].Id | Should -Be 1
        }

        It 'Handles empty array' {
            $array = @()
            $result = InModuleScope PlexAutomationToolkit -ArgumentList @(, $array) { param($arr) ConvertTo-PsCustomObjectFromHashtable -Hashtable $arr }

            $result | Should -HaveCount 0
        }

        It 'Handles mixed array (primitives and hashtables)' {
            $array = @(
                'string value'
                @{ Name = 'Object' }
                42
            )
            $result = InModuleScope PlexAutomationToolkit -ArgumentList @(, $array) { param($arr) ConvertTo-PsCustomObjectFromHashtable -Hashtable $arr }

            $result | Should -HaveCount 3
            $result[0] | Should -Be 'string value'
            $result[1] | Should -BeOfType [PSCustomObject]
            $result[1].Name | Should -Be 'Object'
            $result[2] | Should -Be 42
        }

        It 'Flattens nested arrays of primitives' {
            # Due to PowerShell array += behavior, nested arrays of primitives get flattened
            $array = @(
                @(1, 2, 3)
                @(4, 5, 6)
            )
            $result = InModuleScope PlexAutomationToolkit -ArgumentList @(, $array) { param($arr) ConvertTo-PsCustomObjectFromHashtable -Hashtable $arr }

            # Arrays are flattened to a single array
            $result | Should -HaveCount 6
            $result | Should -Be @(1, 2, 3, 4, 5, 6)
        }
    }

    Context 'Real-world Plex API response simulation' {
        It 'Converts typical Plex MediaContainer response' {
            # Simulates a response from ConvertFrom-Json -AsHashtable
            $response = @{
                MediaContainer = @{
                    size = 2
                    Directory = @(
                        @{
                            key       = '1'
                            title     = 'Movies'
                            type      = 'movie'
                            Location  = @(
                                @{ path = '/media/movies' }
                            )
                        }
                        @{
                            key       = '2'
                            title     = 'TV Shows'
                            type      = 'show'
                            Location  = @(
                                @{ path = '/media/tv' }
                            )
                        }
                    )
                }
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $response { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            $result.MediaContainer | Should -BeOfType [PSCustomObject]
            $result.MediaContainer.size | Should -Be 2
            $result.MediaContainer.Directory | Should -HaveCount 2
            $result.MediaContainer.Directory[0].title | Should -Be 'Movies'
            $result.MediaContainer.Directory[0].Location[0].path | Should -Be '/media/movies'
        }

        It 'Handles metadata with case-variant keys (last value wins)' {
            # When Plex API returns both "guid" and "Guid", the ordered hashtable preserves both
            # but PSCustomObject access is case-insensitive, so the last value wins
            $metadata = [ordered]@{}
            $metadata['guid'] = 'plex://movie/abc123'
            $metadata['Guid'] = @(
                @{ id = 'imdb://tt1234567' }
                @{ id = 'tmdb://12345' }
            )
            $metadata['title'] = 'Test Movie'

            $result = InModuleScope PlexAutomationToolkit -ArgumentList $metadata { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            # The array value (last assigned) is accessible via either case
            $result.guid | Should -HaveCount 2
            $result.Guid[0].id | Should -Be 'imdb://tt1234567'
            $result.title | Should -Be 'Test Movie'
        }
    }

    Context 'Edge cases' {
        It 'Handles hashtable with null values' {
            $hashtable = @{
                Name     = 'Test'
                NullProp = $null
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result.Name | Should -Be 'Test'
            $result.NullProp | Should -BeNullOrEmpty
        }

        It 'Handles string values that look like arrays' {
            $hashtable = @{
                ArrayString = '[1, 2, 3]'
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $hashtable { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result.ArrayString | Should -Be '[1, 2, 3]'
            $result.ArrayString | Should -BeOfType [string]
        }

        It 'Handles ordered dictionary' {
            $ordered = [ordered]@{
                First  = 1
                Second = 2
                Third  = 3
            }
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $ordered { param($ht) ConvertTo-PsCustomObjectFromHashtable -Hashtable $ht }

            $result | Should -BeOfType [PSCustomObject]
            $result.First | Should -Be 1
        }
    }
}
