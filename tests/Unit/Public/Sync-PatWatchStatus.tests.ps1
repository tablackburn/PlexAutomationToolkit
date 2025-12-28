BeforeAll {
    # Import the module from the source directory for unit testing
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\PlexAutomationToolkit\PlexAutomationToolkit.psm1'
    Import-Module $modulePath -Force
}

Describe 'Sync-PatWatchStatus' {
    BeforeAll {
        Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
            param($Name)

            if ($Name -eq 'Source') {
                return [PSCustomObject]@{
                    name  = 'Source'
                    uri   = 'http://source.test:32400'
                    token = 'source-token'
                }
            }
            elseif ($Name -eq 'Target') {
                return [PSCustomObject]@{
                    name  = 'Target'
                    uri   = 'http://target.test:32400'
                    token = 'target-token'
                }
            }
            return $null
        }

        Mock -ModuleName PlexAutomationToolkit Get-PatAuthenticationHeader {
            return @{
                Accept         = 'application/json'
                'X-Plex-Token' = 'test-token'
            }
        }

        Mock -ModuleName PlexAutomationToolkit Join-PatUri {
            param($BaseUri, $Endpoint)
            return "$BaseUri$Endpoint"
        }
    }

    Context 'Basic sync operation' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        PSTypeName      = 'PlexAutomationToolkit.WatchStatusDiff'
                        Title           = 'The Matrix'
                        Type            = 'movie'
                        Year            = 1999
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceViewCount = 1
                        TargetViewCount = 0
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Calls scrobble endpoint for each difference' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false

            Should -Invoke -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 1
        }

        It 'Passes WatchedOnSourceOnly to Compare-PatWatchStatus' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $WatchedOnSourceOnly -eq $true
            }
        }

        It 'Returns results with PassThru' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result[0].Title | Should -Be 'The Matrix'
            $result[0].Status | Should -Be 'Success'
        }
    }

    Context 'Multiple items sync' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Movie 1'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    },
                    [PSCustomObject]@{
                        Title           = 'Pilot'
                        Type            = 'episode'
                        Year            = $null
                        ShowName        = 'Breaking Bad'
                        Season          = 1
                        Episode         = 1
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1002
                        TargetRatingKey = 2002
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Syncs all items' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false

            Should -Invoke -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Returns correct result count' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result | Should -HaveCount 2
        }

        It 'Includes episode metadata in results' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $episode = $result | Where-Object { $_.Type -eq 'episode' }
            $episode.ShowName | Should -Be 'Breaking Bad'
            $episode.Season | Should -Be 1
            $episode.Episode | Should -Be 1
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Failed Movie'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "Scrobble failed"
            }
        }

        It 'Continues on individual item failure' {
            { Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false } |
                Should -Not -Throw
        }

        It 'Reports failures in results' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].Status | Should -Be 'Failed'
            $result[0].Error | Should -Match 'Scrobble failed'
        }
    }

    Context 'No differences' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @()
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Returns nothing when no differences' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result | Should -BeNullOrEmpty
        }

        It 'Does not call scrobble when no differences' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false

            Should -Invoke -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'SectionId filter' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @()
            }
        }

        It 'Passes SectionId to Compare-PatWatchStatus' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -SectionId 1, 2 -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SectionId -contains 1 -and $SectionId -contains 2
            }
        }
    }

    Context 'WhatIf support' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'WhatIf Movie'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Does not call scrobble with WhatIf' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -WhatIf

            Should -Invoke -CommandName Invoke-PatApi -ModuleName PlexAutomationToolkit -Times 0
        }
    }

    Context 'Server not found' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws when target server not found' {
            { Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'NonExistent' } |
                Should -Throw "*not found*"
        }
    }

    Context 'PSTypeName assignment' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Test'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Assigns correct PSTypeName to results' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].PSObject.TypeNames[0] | Should -Be 'PlexAutomationToolkit.WatchStatusSyncResult'
        }
    }

    Context 'Direction parameter - SourceToTarget' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Test Movie'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Syncs from Source to Target with default direction' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SourceServerName -eq 'Source' -and $TargetServerName -eq 'Target'
            }
        }

        It 'Syncs from Source to Target with explicit direction' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction SourceToTarget -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SourceServerName -eq 'Source' -and $TargetServerName -eq 'Target'
            }
        }
    }

    Context 'Direction parameter - TargetToSource' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Test Movie'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 2001
                        TargetRatingKey = 1001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Syncs from Target to Source when direction is TargetToSource' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction TargetToSource -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SourceServerName -eq 'Target' -and $TargetServerName -eq 'Source'
            }
        }

        It 'Returns SyncedTo with correct target server name' {
            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction TargetToSource -PassThru -Confirm:$false

            $result[0].SyncedTo | Should -Be 'Source'
        }
    }

    Context 'Direction parameter - Bidirectional' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            $script:compareCallCount = 0
            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                $script:compareCallCount++
                return @(
                    [PSCustomObject]@{
                        Title           = "Movie $script:compareCallCount"
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }

            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi { }
        }

        It 'Calls Compare-PatWatchStatus twice for bidirectional sync' {
            $script:compareCallCount = 0

            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction Bidirectional -Confirm:$false

            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 2
        }

        It 'Syncs in both directions' {
            Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction Bidirectional -Confirm:$false

            # First call: Source -> Target
            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SourceServerName -eq 'Source' -and $TargetServerName -eq 'Target'
            }

            # Second call: Target -> Source
            Should -Invoke -CommandName Compare-PatWatchStatus -ModuleName PlexAutomationToolkit -Times 1 -ParameterFilter {
                $SourceServerName -eq 'Target' -and $TargetServerName -eq 'Source'
            }
        }

        It 'Returns results from both directions' {
            $script:compareCallCount = 0

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction Bidirectional -PassThru -Confirm:$false

            $result | Should -HaveCount 2
        }

        It 'Includes correct SyncedTo for each direction' {
            $script:compareCallCount = 0

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -Direction Bidirectional -PassThru -Confirm:$false

            ($result | Where-Object { $_.SyncedTo -eq 'Target' }) | Should -Not -BeNullOrEmpty
            ($result | Where-Object { $_.SyncedTo -eq 'Source' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'API error scenarios' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                return [PSCustomObject]@{
                    name  = $Name
                    uri   = "http://$Name.test:32400"
                    token = 'token'
                }
            }

            Mock -ModuleName PlexAutomationToolkit Compare-PatWatchStatus {
                return @(
                    [PSCustomObject]@{
                        Title           = 'Test Movie'
                        Type            = 'movie'
                        Year            = 2020
                        ShowName        = $null
                        Season          = $null
                        Episode         = $null
                        SourceWatched   = $true
                        TargetWatched   = $false
                        SourceRatingKey = 1001
                        TargetRatingKey = 2001
                    }
                )
            }
        }

        It 'Handles HTTP 401 Unauthorized' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "401 Unauthorized"
            }

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].Status | Should -Be 'Failed'
            $result[0].Error | Should -Match '401'
        }

        It 'Handles HTTP 404 Not Found' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "404 Not Found"
            }

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].Status | Should -Be 'Failed'
            $result[0].Error | Should -Match '404'
        }

        It 'Handles HTTP 500 Server Error' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "500 Internal Server Error"
            }

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].Status | Should -Be 'Failed'
            $result[0].Error | Should -Match '500'
        }

        It 'Handles network timeout' {
            Mock -ModuleName PlexAutomationToolkit Invoke-PatApi {
                throw "The operation has timed out"
            }

            $result = Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' -PassThru -Confirm:$false

            $result[0].Status | Should -Be 'Failed'
            $result[0].Error | Should -Match 'timed out'
        }
    }

    Context 'Server validation - both servers' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                if ($Name -eq 'Source') {
                    return $null
                }
                return $null
            }
        }

        It 'Throws when source server not found' {
            { Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' } |
                Should -Throw "*Source*not found*"
        }
    }

    Context 'Server validation - target only' {
        BeforeAll {
            Mock -ModuleName PlexAutomationToolkit Get-PatStoredServer {
                param($Name)
                if ($Name -eq 'Source') {
                    return [PSCustomObject]@{
                        name  = 'Source'
                        uri   = 'http://source.test:32400'
                        token = 'token'
                    }
                }
                return $null
            }
        }

        It 'Throws when only target server not found' {
            { Sync-PatWatchStatus -SourceServerName 'Source' -TargetServerName 'Target' } |
                Should -Throw "*Target*not found*"
        }
    }
}
