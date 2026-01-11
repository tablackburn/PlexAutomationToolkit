BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Get-PatCollectionItem' {
    BeforeAll {
        # Set up common test data
        $script:testServerUri = 'http://localhost:32400'
        $script:testHeaders = @{
            'X-Plex-Token' = 'test-token-123'
            'Accept'       = 'application/json'
        }
    }

    Context 'Parameter validation' {
        It 'Should throw when CollectionId is not provided' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                    param($uri, $headers)
                    Get-PatCollectionItem -ServerUri $uri -Headers $headers
                }
            } | Should -Throw
        }

        It 'Should throw when ServerUri is null' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testHeaders {
                    param($headers)
                    Get-PatCollectionItem -CollectionId 123 -ServerUri $null -Headers $headers
                }
            } | Should -Throw
        }

        It 'Should throw when ServerUri is empty' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testHeaders {
                    param($headers)
                    Get-PatCollectionItem -CollectionId 123 -ServerUri '' -Headers $headers
                }
            } | Should -Throw
        }

        It 'Should throw when Headers is not provided' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri {
                    param($uri)
                    Get-PatCollectionItem -CollectionId 123 -ServerUri $uri
                }
            } | Should -Throw
        }

        It 'Should accept null CollectionTitle' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                    param($uri, $headers)
                    Mock Invoke-PatApi { return @{ Metadata = @() } }
                    Get-PatCollectionItem -CollectionId 123 -CollectionTitle $null -ServerUri $uri -Headers $headers
                }
            } | Should -Not -Throw
        }

        It 'Should not require CollectionTitle parameter' {
            {
                InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                    param($uri, $headers)
                    Mock Invoke-PatApi { return @{ Metadata = @() } }
                    Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
                }
            } | Should -Not -Throw
        }
    }

    Context 'API endpoint construction' {
        It 'Should construct correct API endpoint with collection ID' {
            InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return $BaseUri + $Endpoint } -Verifiable
                Mock Invoke-PatApi { return @{ Metadata = @() } }

                Get-PatCollectionItem -CollectionId 12345 -ServerUri $uri -Headers $headers

                Should -Invoke Join-PatUri -Times 1 -ParameterFilter {
                    $Endpoint -eq '/library/collections/12345/children'
                }
            }
        }

        It 'Should pass ServerUri to Join-PatUri' {
            InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://localhost:32400/library/collections/123/children' } -Verifiable
                Mock Invoke-PatApi { return @{ Metadata = @() } }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers

                Should -Invoke Join-PatUri -Times 1 -ParameterFilter {
                    $BaseUri -eq 'http://localhost:32400'
                }
            }
        }

        It 'Should call Invoke-PatApi with constructed URI' {
            InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                $expectedUri = 'http://localhost:32400/library/collections/123/children'
                Mock Join-PatUri { return $expectedUri }
                Mock Invoke-PatApi { return @{ Metadata = @() } } -Verifiable

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers

                Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                    $Uri -eq $expectedUri
                }
            }
        }

        It 'Should call Invoke-PatApi with provided headers' {
            InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://localhost:32400/library/collections/123/children' }
                Mock Invoke-PatApi { return @{ Metadata = @() } } -Verifiable

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers

                Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                    $Headers['X-Plex-Token'] -eq 'test-token-123'
                }
            }
        }

        It 'Should call Invoke-PatApi with ErrorAction Stop' {
            InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://localhost:32400/library/collections/123/children' }
                Mock Invoke-PatApi { return @{ Metadata = @() } } -Verifiable

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers

                Should -Invoke Invoke-PatApi -Times 1 -ParameterFilter {
                    $ErrorAction -eq 'Stop'
                }
            }
        }
    }

    Context 'Successful item retrieval and transformation' {
        It 'Should return array of collection items' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Movie 1'
                                type      = 'movie'
                                year      = 2020
                                thumb     = '/thumb1.jpg'
                                addedAt   = 1609459200
                            }
                            [PSCustomObject]@{
                                ratingKey = 222
                                title     = 'Movie 2'
                                type      = 'movie'
                                year      = 2021
                                thumb     = '/thumb2.jpg'
                                addedAt   = 1640995200
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result | Should -HaveCount 2
        }

        It 'Should transform items with correct properties' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 12345
                                title     = 'Avengers: Endgame'
                                type      = 'movie'
                                year      = 2019
                                thumb     = '/library/metadata/12345/thumb/1234567890'
                                addedAt   = 1609459200
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 999 -ServerUri $uri -Headers $headers
            }

            $result[0].RatingKey | Should -Be 12345
            $result[0].RatingKey | Should -BeOfType [int]
            $result[0].Title | Should -Be 'Avengers: Endgame'
            $result[0].Type | Should -Be 'movie'
            $result[0].Year | Should -Be 2019
            $result[0].Thumb | Should -Be '/library/metadata/12345/thumb/1234567890'
            $result[0].AddedAt | Should -BeOfType [DateTime]
            $result[0].CollectionId | Should -Be 999
            $result[0].ServerUri | Should -Be $script:testServerUri
        }

        It 'Should set PSTypeName to PlexAutomationToolkit.CollectionItem' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.CollectionItem'
        }

        It 'Should convert addedAt Unix timestamp to DateTime' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                                addedAt   = 1609459200  # 2021-01-01 00:00:00 UTC
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].AddedAt | Should -BeOfType [DateTime]
            $result[0].AddedAt | Should -Not -BeNullOrEmpty
        }

        It 'Should handle null year property' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                                year      = $null
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].Year | Should -BeNullOrEmpty
        }

        It 'Should handle missing year property' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].Year | Should -BeNullOrEmpty
        }

        It 'Should handle null addedAt property' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                                addedAt   = $null
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].AddedAt | Should -BeNullOrEmpty
        }

        It 'Should handle zero addedAt property' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Test'
                                type      = 'movie'
                                addedAt   = 0
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].AddedAt | Should -BeNullOrEmpty
        }

        It 'Should preserve CollectionId in each item' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Movie 1'
                                type      = 'movie'
                            }
                            [PSCustomObject]@{
                                ratingKey = 222
                                title     = 'Movie 2'
                                type      = 'movie'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 54321 -ServerUri $uri -Headers $headers
            }

            $result[0].CollectionId | Should -Be 54321
            $result[1].CollectionId | Should -Be 54321
        }

        It 'Should preserve ServerUri in each item' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testHeaders {
                param($headers)
                Mock Join-PatUri { return 'https://plex.example.com:32400/library/collections/123/children' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'Movie 1'
                                type      = 'movie'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri 'https://plex.example.com:32400' -Headers $headers
            }

            $result[0].ServerUri | Should -Be 'https://plex.example.com:32400'
        }
    }

    Context 'Empty results handling' {
        It 'Should return empty array when result is null' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { return $null }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }

        It 'Should return empty array when Metadata is null' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = $null
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }

        It 'Should return empty array when Metadata is empty array' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @()
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }

        It 'Should return empty array when result has no Metadata property' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        size = 0
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }
    }

    Context 'Error handling with warning output' {
        It 'Should catch errors and return empty array' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw 'API connection failed' }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers 3>$null
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }

        It 'Should output warning when error occurs' {
            $warnings = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw '404 Not Found' }

                $warningList = @()
                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers -WarningVariable warningList 3>$null
                return $warningList
            }

            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should include collection ID in warning when CollectionTitle not provided' {
            $warnings = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw 'Connection timeout' }

                $warningList = @()
                Get-PatCollectionItem -CollectionId 12345 -ServerUri $uri -Headers $headers -WarningVariable warningList 3>$null
                return $warningList
            }

            $warnings | Should -Match 'ID 12345'
        }

        It 'Should include CollectionTitle in warning when provided' {
            $warnings = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw 'Server error' }

                $warningList = @()
                Get-PatCollectionItem -CollectionId 123 -CollectionTitle 'Marvel Movies' -ServerUri $uri -Headers $headers -WarningVariable warningList 3>$null
                return $warningList
            }

            $warnings | Should -Match 'Marvel Movies'
            $warnings | Should -Not -Match 'ID 123'
        }

        It 'Should include error message in warning' {
            $warnings = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw 'Authentication failed: Invalid token' }

                $warningList = @()
                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers -WarningVariable warningList 3>$null
                return $warningList
            }

            $warnings | Should -Match 'Invalid token'
        }

        It 'Should handle HTTP 404 error gracefully' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw '404 Not Found' }

                Get-PatCollectionItem -CollectionId 999 -ServerUri $uri -Headers $headers 3>$null
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }

        It 'Should handle network timeout gracefully' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi { throw 'The operation has timed out' }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers 3>$null
            }

            $result | Should -BeNullOrEmpty
            @($result).Count | Should -Be 0
        }
    }

    Context 'Real-world API response simulation' {
        It 'Should handle typical Plex collection items response' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey           = 45678
                                key                 = '/library/metadata/45678'
                                guid                = 'plex://movie/5d7768ba96b655001fdc0408'
                                studio              = 'Marvel Studios'
                                type                = 'movie'
                                title               = 'Iron Man'
                                contentRating       = 'PG-13'
                                summary             = 'Tony Stark builds an armored suit...'
                                rating              = 7.9
                                year                = 2008
                                thumb               = '/library/metadata/45678/thumb/1234567890'
                                art                 = '/library/metadata/45678/art/1234567890'
                                duration            = 7560000
                                originallyAvailableAt = '2008-05-02'
                                addedAt             = 1577836800
                                updatedAt           = 1609459200
                            }
                            [PSCustomObject]@{
                                ratingKey           = 45679
                                key                 = '/library/metadata/45679'
                                guid                = 'plex://movie/5d7768c196b655001fdc044a'
                                studio              = 'Marvel Studios'
                                type                = 'movie'
                                title               = 'The Incredible Hulk'
                                contentRating       = 'PG-13'
                                summary             = 'Bruce Banner seeks a cure...'
                                rating              = 6.7
                                year                = 2008
                                thumb               = '/library/metadata/45679/thumb/1234567891'
                                art                 = '/library/metadata/45679/art/1234567891'
                                duration            = 6720000
                                originallyAvailableAt = '2008-06-13'
                                addedAt             = 1577836801
                                updatedAt           = 1609459201
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 12345 -CollectionTitle 'MCU Phase 1' -ServerUri $uri -Headers $headers
            }

            $result | Should -HaveCount 2
            $result[0].RatingKey | Should -Be 45678
            $result[0].Title | Should -Be 'Iron Man'
            $result[0].Type | Should -Be 'movie'
            $result[0].Year | Should -Be 2008
            $result[0].AddedAt | Should -BeOfType [DateTime]
            $result[0].CollectionId | Should -Be 12345
            $result[1].Title | Should -Be 'The Incredible Hulk'
        }

        It 'Should handle TV show items in collection' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 77777
                                title     = 'Breaking Bad'
                                type      = 'show'
                                year      = 2008
                                thumb     = '/library/metadata/77777/thumb/1234567890'
                                addedAt   = 1609459200
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 999 -ServerUri $uri -Headers $headers
            }

            $result[0].Type | Should -Be 'show'
            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.CollectionItem'
        }

        It 'Should handle mixed media types in collection' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 111
                                title     = 'A Movie'
                                type      = 'movie'
                                year      = 2020
                            }
                            [PSCustomObject]@{
                                ratingKey = 222
                                title     = 'A TV Show'
                                type      = 'show'
                                year      = 2021
                            }
                            [PSCustomObject]@{
                                ratingKey = 333
                                title     = 'A Season'
                                type      = 'season'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 456 -ServerUri $uri -Headers $headers
            }

            $result | Should -HaveCount 3
            $result[0].Type | Should -Be 'movie'
            $result[1].Type | Should -Be 'show'
            $result[2].Type | Should -Be 'season'
        }
    }

    Context 'Type casting behavior' {
        It 'Should cast ratingKey to int from string' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = '12345'
                                title     = 'Test'
                                type      = 'movie'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].RatingKey | Should -Be 12345
            $result[0].RatingKey | Should -BeOfType [int]
        }

        It 'Should cast year to int from string' {
            $result = InModuleScope PlexAutomationToolkit -ArgumentList $script:testServerUri, $script:testHeaders {
                param($uri, $headers)
                Mock Join-PatUri { return 'http://test/uri' }
                Mock Invoke-PatApi {
                    return [PSCustomObject]@{
                        Metadata = @(
                            [PSCustomObject]@{
                                ratingKey = 123
                                title     = 'Test'
                                type      = 'movie'
                                year      = '2020'
                            }
                        )
                    }
                }

                Get-PatCollectionItem -CollectionId 123 -ServerUri $uri -Headers $headers
            }

            $result[0].Year | Should -Be 2020
            $result[0].Year | Should -BeOfType [int]
        }
    }
}
