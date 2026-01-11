BeforeAll {
    # Remove any loaded instances of the module to avoid "multiple modules" error
    Get-Module PlexAutomationToolkit -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Get-PatShowEpisodes' {
    Context 'Parameter Validation' {
        It 'Should throw when Server is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    Get-PatShowEpisodes -ShowRatingKey 123
                }
            } | Should -Throw
        }

        It 'Should throw when ShowRatingKey is not provided' {
            {
                InModuleScope PlexAutomationToolkit {
                    $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                    Get-PatShowEpisodes -Server $server
                }
            } | Should -Throw
        }

        It 'Should throw for ShowRatingKey of 0' {
            {
                InModuleScope PlexAutomationToolkit {
                    $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                    Get-PatShowEpisodes -Server $server -ShowRatingKey 0
                }
            } | Should -Throw
        }

        It 'Should throw for negative ShowRatingKey' {
            {
                InModuleScope PlexAutomationToolkit {
                    $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                    Get-PatShowEpisodes -Server $server -ShowRatingKey -1
                }
            } | Should -Throw
        }
    }

    Context 'API Endpoint Construction' {
        BeforeEach {
            InModuleScope PlexAutomationToolkit {
                $script:capturedUri = $null
                Mock Join-PatUri {
                    $script:capturedUri = "$BaseUri$Endpoint"
                    return "$BaseUri$Endpoint"
                }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test-token' } }
                Mock Invoke-PatApi { return @{ Metadata = @() } }
            }
        }

        It 'Should construct correct allLeaves endpoint' {
            InModuleScope PlexAutomationToolkit {
                $server = [PSCustomObject]@{ uri = 'http://plex.local:32400' }
                Get-PatShowEpisodes -Server $server -ShowRatingKey 12345
                $script:capturedUri | Should -Be 'http://plex.local:32400/library/metadata/12345/allLeaves'
            }
        }

        It 'Should use server URI from Server object' {
            InModuleScope PlexAutomationToolkit {
                $server = [PSCustomObject]@{ uri = 'https://remote.plex.com:32400' }
                Get-PatShowEpisodes -Server $server -ShowRatingKey 99999
                $script:capturedUri | Should -Match '^https://remote\.plex\.com:32400'
            }
        }

        It 'Should include ShowRatingKey in endpoint' {
            InModuleScope PlexAutomationToolkit {
                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                Get-PatShowEpisodes -Server $server -ShowRatingKey 54321
                $script:capturedUri | Should -Match '/54321/allLeaves$'
            }
        }
    }

    Context 'Authentication Header' {
        BeforeEach {
            InModuleScope PlexAutomationToolkit {
                $script:capturedServer = $null
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader {
                    $script:capturedServer = $Server
                    return @{ 'X-Plex-Token' = 'mock-token' }
                }
                Mock Invoke-PatApi { return @{ Metadata = @() } }
            }
        }

        It 'Should pass Server object to Get-PatAuthenticationHeader' {
            InModuleScope PlexAutomationToolkit {
                $server = [PSCustomObject]@{ uri = 'http://test:32400'; token = 'secret' }
                Get-PatShowEpisodes -Server $server -ShowRatingKey 123
                $script:capturedServer | Should -Not -BeNullOrEmpty
                $script:capturedServer.uri | Should -Be 'http://test:32400'
            }
        }
    }

    Context 'Successful Episode Retrieval' {
        It 'Should return episode metadata with all properties' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                $mockEpisodes = @(
                    @{ ratingKey = '1001'; title = 'Pilot'; parentIndex = 1; index = 1; viewCount = 2 },
                    @{ ratingKey = '1002'; title = 'Episode 2'; parentIndex = 1; index = 2; viewCount = 0 }
                )
                Mock Invoke-PatApi { return @{ Metadata = $mockEpisodes } }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 2
                $result[0].ratingKey | Should -Be '1001'
                $result[0].title | Should -Be 'Pilot'
                $result[0].parentIndex | Should -Be 1
                $result[0].index | Should -Be 1
                $result[0].viewCount | Should -Be 2
                $result[1].title | Should -Be 'Episode 2'
            }
        }

        It 'Should return empty array when no episodes found' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                Mock Invoke-PatApi { return @{ Metadata = @() } }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 0
            }
        }

        It 'Should return empty array when Metadata is null' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                Mock Invoke-PatApi { return @{ Metadata = $null } }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 0
            }
        }

        It 'Should return empty array when result is null' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                Mock Invoke-PatApi { return $null }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 0
            }
        }
    }

    Context 'Error Handling' {
        It 'Should return empty array on API error' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                Mock Invoke-PatApi { throw 'Connection failed' }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 0
            }
        }

        It 'Should not throw on API error' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }
                Mock Invoke-PatApi { throw 'Server unavailable' }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                { Get-PatShowEpisodes -Server $server -ShowRatingKey 123 } | Should -Not -Throw
            }
        }
    }

    Context 'Large Episode Sets' {
        It 'Should handle shows with many episodes' {
            InModuleScope PlexAutomationToolkit {
                Mock Join-PatUri { return 'http://test:32400/library/metadata/123/allLeaves' }
                Mock Get-PatAuthenticationHeader { return @{ 'X-Plex-Token' = 'test' } }

                # Simulate a long-running show with 500 episodes
                $mockEpisodes = 1..500 | ForEach-Object {
                    @{
                        ratingKey   = $_.ToString()
                        title       = "Episode $_"
                        parentIndex = [math]::Ceiling($_ / 24)
                        index       = (($_ - 1) % 24) + 1
                    }
                }
                Mock Invoke-PatApi { return @{ Metadata = $mockEpisodes } }

                $server = [PSCustomObject]@{ uri = 'http://test:32400' }
                $result = Get-PatShowEpisodes -Server $server -ShowRatingKey 123

                $result | Should -HaveCount 500
            }
        }
    }
}
