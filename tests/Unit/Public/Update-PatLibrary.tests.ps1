BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\build.psake.ps1'
        $invokePsakeParameters = @{
            TaskList  = 'Build'
            BuildFile = $buildFilePath
        }
        Invoke-psake @invokePsakeParameters
    }

    $moduleManifestFilename = $Env:BHProjectName + '.psd1'
    $moduleManifestPath = Join-Path -Path $Env:BHBuildOutput -ChildPath $moduleManifestFilename

    Get-Module $Env:BHProjectName | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Update-PatLibrary' {

    BeforeAll {
        # Mock library sections response
        $script:mockSectionsResponse = @{
            size      = 3
            allowSync = $false
            title1    = 'Plex Library'
            Directory = @(
                @{
                    key   = '2'
                    type  = 'movie'
                    title = 'Movies'
                }
                @{
                    key   = '3'
                    type  = 'show'
                    title = 'TV Shows'
                }
                @{
                    key   = '9'
                    type  = 'movie'
                    title = '4K Movies'
                }
            )
        }

        # Mock default server
        $script:mockDefaultServer = @{
            name    = 'Test Server'
            uri     = 'http://192.168.1.6:32400'
            default = $true
        }
    }

    Context 'When refreshing library by SectionId with explicit ServerUri' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $null
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return "http://192.168.1.6:32400/library/sections/$SectionId/refresh"
            }
        }

        It 'Refreshes the library section' {
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Invoke-PatApi -ParameterFilter {
                $Method -eq 'Post'
            }
        }

        It 'Calls Join-PatUri with correct endpoint' {
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.6:32400' -and
                $Endpoint -eq '/library/sections/2/refresh'
            }
        }

        It 'Validates SectionId is greater than 0' {
            { Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 0 -Confirm:$false } | Should -Throw
        }
    }

    Context 'When refreshing library by SectionName' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatLibrary {
                return $script:mockSectionsResponse
            }

            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $null
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Resolves section name to section ID' {
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionName 'Movies' -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatLibrary -ParameterFilter {
                $ServerUri -eq 'http://192.168.1.6:32400'
            }
        }

        It 'Refreshes the correct library section' {
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionName 'TV Shows' -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $Endpoint -eq '/library/sections/3/refresh'
            }
        }

        It 'Throws when section name is not found' {
            { Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionName 'Nonexistent' -Confirm:$false } | Should -Throw "*No library section found with name 'Nonexistent'*"
        }

        It 'Throws when multiple sections have the same name' {
            Mock -ModuleName $Env:BHProjectName Get-PatLibrary {
                return @{
                    Directory = @(
                        @{ key = '2'; title = 'Movies' }
                        @{ key = '9'; title = 'Movies' }
                    )
                }
            }

            { Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionName 'Movies' -Confirm:$false } | Should -Throw "*Multiple library sections found*"
        }
    }

    Context 'When refreshing library with a specific path' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $null
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                param($BaseUri, $Endpoint, $QueryString)
                if ($QueryString) {
                    return "$BaseUri$Endpoint`?$QueryString"
                }
                return "$BaseUri$Endpoint"
            }
        }

        It 'Includes the path parameter in the request' {
            $testPath = '/mnt/media/Movies/Action'
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -Path $testPath -Confirm:$false

            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $QueryString -like "*path=*"
            }
        }

        It 'URL-encodes the path parameter' {
            $testPath = '/mnt/media/Movies With Spaces'
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -Path $testPath -Confirm:$false

            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $QueryString -match 'path=.*%20.*'
            }
        }
    }

    Context 'When using default server' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatStoredServer {
                return $script:mockDefaultServer
            }

            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $null
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections/2/refresh'
            }
        }

        It 'Uses the default server URI' {
            Update-PatLibrary -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Get-PatStoredServer -ParameterFilter {
                $Default -eq $true
            }
        }

        It 'Calls Join-PatUri with default server URI' {
            Update-PatLibrary -SectionId 2 -Confirm:$false
            Should -Invoke -ModuleName $Env:BHProjectName Join-PatUri -ParameterFilter {
                $BaseUri -eq 'http://192.168.1.6:32400'
            }
        }
    }

    Context 'When no default server is configured' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Get-PatStoredServer {
                return $null
            }
        }

        It 'Throws an error indicating no default server' {
            { Update-PatLibrary -SectionId 2 -Confirm:$false } | Should -Throw '*No default server configured*'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                return $null
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections/2/refresh'
            }
        }

        It 'Does not call Invoke-PatApi' {
            Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -WhatIf
            Should -Invoke -ModuleName $Env:BHProjectName Invoke-PatApi -Exactly 0
        }
    }

    Context 'When API call fails' {
        BeforeAll {
            Mock -ModuleName $Env:BHProjectName Invoke-PatApi {
                throw 'Connection timeout'
            }

            Mock -ModuleName $Env:BHProjectName Join-PatUri {
                return 'http://192.168.1.6:32400/library/sections/2/refresh'
            }
        }

        It 'Throws an error with context' {
            { Update-PatLibrary -ServerUri 'http://192.168.1.6:32400' -SectionId 2 -Confirm:$false } | Should -Throw '*Failed to refresh Plex library*'
        }
    }
}
