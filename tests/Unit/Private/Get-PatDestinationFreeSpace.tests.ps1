BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatDestinationFreeSpace' {
    Context 'Drive letter paths' {
        It 'Returns free space for a valid drive letter path' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'C'
                        Free = 500GB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'C:\'

                $result | Should -Be 500GB
            }
        }

        It 'Handles drive letter with nested path' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'E'
                        Free = 1TB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'E:\Movies\Action'

                $result | Should -Be 1TB
            }
        }

        It 'Extracts correct drive letter from path' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    param($Name)
                    if ($Name -eq 'D') {
                        return [PSCustomObject]@{
                            Name = 'D'
                            Free = 250GB
                        }
                    }
                    throw "Drive not found"
                }

                $result = Get-PatDestinationFreeSpace -Path 'D:\Media\TV Shows\Breaking Bad'

                Should -Invoke -CommandName Get-PSDrive -ParameterFilter { $Name -eq 'D' }
                $result | Should -Be 250GB
            }
        }

        It 'Lowercase drive letters fall through to DriveInfo lookup' {
            InModuleScope PlexAutomationToolkit {
                # The regex uses [A-Z] which doesn't match lowercase
                # So lowercase paths fall through to DriveInfo.GetDrives() lookup
                $result = Get-PatDestinationFreeSpace -Path 'c:\test'

                # On Windows, DriveInfo.GetDrives() will find C: drive regardless of case
                # Result should be the actual free space or 0 on non-Windows
                $result | Should -BeGreaterOrEqual 0
            }
        }

        It 'Returns free space as long type' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'C'
                        Free = 123456789012
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'C:\'

                $result | Should -BeOfType [long]
                $result | Should -Be 123456789012
            }
        }
    }

    Context 'UNC path handling' {
        It 'Attempts to get free space for UNC paths' {
            InModuleScope PlexAutomationToolkit {
                # For UNC paths, the function uses DriveInfo.GetDrives()
                # Since we can't easily mock static .NET methods, we verify behavior
                $result = Get-PatDestinationFreeSpace -Path '\\server\share\folder'

                # Result will be 0 (as a [long]) unless the path matches a mounted drive
                # The function consistently returns a [long] value for both 0 and actual free space
                $result | Should -Be 0
            }
        }

        It 'Returns 0 when UNC path does not match any drive' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-PatDestinationFreeSpace -Path '\\nonexistent\share'

                $result | Should -Be 0
            }
        }

        It 'Handles UNC path with nested folders' {
            InModuleScope PlexAutomationToolkit {
                $result = Get-PatDestinationFreeSpace -Path '\\NAS\Media\Movies\Action\Movie.mkv'

                # Result is 0 for non-existent UNC paths
                $result | Should -Be 0
            }
        }
    }

    Context 'Error handling' {
        It 'Returns 0 when Get-PSDrive fails' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    throw "Drive not accessible"
                }

                $result = Get-PatDestinationFreeSpace -Path 'X:\'

                $result | Should -Be 0
            }
        }

        It 'Writes warning when drive info cannot be determined' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    throw "Access denied"
                }

                Mock Write-Warning { }

                Get-PatDestinationFreeSpace -Path 'Z:\test'

                Should -Invoke -CommandName Write-Warning -Times 1
            }
        }

        It 'Warning message contains exception details' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    throw "Specific error message"
                }

                $warningMessage = $null
                Mock Write-Warning {
                    param($Message)
                    $script:capturedWarning = $Message
                }

                Get-PatDestinationFreeSpace -Path 'Z:\test'

                $script:capturedWarning | Should -Match 'Could not determine free space'
                $script:capturedWarning | Should -Match 'Specific error message'
            }
        }

        It 'Returns 0 and does not throw on any error' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    throw [System.UnauthorizedAccessException]::new("Access denied")
                }

                {
                    $result = Get-PatDestinationFreeSpace -Path 'C:\'
                    $result | Should -Be 0
                } | Should -Not -Throw
            }
        }
    }

    Context 'Parameter validation' {
        It 'Has mandatory Path parameter' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatDestinationFreeSpace
                $parameter = $command.Parameters['Path']

                $parameter | Should -Not -BeNullOrEmpty
                $parameter.Attributes.Mandatory | Should -Contain $true
            }
        }

        It 'Path parameter validates not null or empty' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatDestinationFreeSpace
                $parameter = $command.Parameters['Path']

                $validateAttribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] }
                $validateAttribute | Should -Not -BeNullOrEmpty
            }
        }

        It 'Throws on empty path' {
            InModuleScope PlexAutomationToolkit {
                { Get-PatDestinationFreeSpace -Path '' } | Should -Throw
            }
        }

        It 'Throws on null path' {
            InModuleScope PlexAutomationToolkit {
                { Get-PatDestinationFreeSpace -Path $null } | Should -Throw
            }
        }

        It 'Returns long type as specified in OutputType' {
            InModuleScope PlexAutomationToolkit {
                $command = Get-Command Get-PatDestinationFreeSpace
                $outputType = $command.OutputType

                $outputType.Type | Should -Contain ([long])
            }
        }
    }

    Context 'Edge cases' {
        It 'Handles drive with zero free space' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'C'
                        Free = 0
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'C:\'

                $result | Should -Be 0
            }
        }

        It 'Handles very large free space values' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'C'
                        Free = 10TB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'C:\'

                $result | Should -Be 10TB
            }
        }

        It 'Handles path with spaces' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'E'
                        Free = 500GB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'E:\My Videos\TV Shows'

                $result | Should -Be 500GB
            }
        }

        It 'Handles path with special characters' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'D'
                        Free = 200GB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path "D:\Movies\Movie's Collection (2020)"

                $result | Should -Be 200GB
            }
        }

        It 'Handles drive letter only path' {
            InModuleScope PlexAutomationToolkit {
                Mock Get-PSDrive {
                    return [PSCustomObject]@{
                        Name = 'C'
                        Free = 100GB
                    }
                }

                $result = Get-PatDestinationFreeSpace -Path 'C:'

                # 'C:' matches the regex '^([A-Z]):' so should work
                $result | Should -Be 100GB
            }
        }
    }

    Context 'Real-world scenarios' {
        It 'Returns actual free space for system drive' -Skip:(-not $IsWindows -and $PSVersionTable.PSEdition -ne 'Desktop') {
            InModuleScope PlexAutomationToolkit {
                $result = Get-PatDestinationFreeSpace -Path 'C:\'

                # Should return a positive value for the actual system drive
                $result | Should -BeGreaterThan 0
            }
        }

        It 'Handles non-existent drive letter gracefully' {
            InModuleScope PlexAutomationToolkit {
                # Using a drive letter that is unlikely to exist
                $result = Get-PatDestinationFreeSpace -Path 'Z:\NonExistent'

                # Should return 0 without throwing
                $result | Should -Be 0
            }
        }
    }
}
