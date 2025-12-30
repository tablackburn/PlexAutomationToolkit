BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'New-PatCompletionResult' {

    Context 'When value has no spaces and no quote' {
        It 'Returns completion text without quotes' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies'
            }
            $result.CompletionText | Should -Be 'Movies'
        }

        It 'Sets ListItemText to value' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies'
            }
            $result.ListItemText | Should -Be 'Movies'
        }

        It 'Sets ToolTip to value' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies'
            }
            $result.ToolTip | Should -Be 'Movies'
        }

        It 'Sets ResultType to ParameterValue' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies'
            }
            $result.ResultType | Should -Be 'ParameterValue'
        }
    }

    Context 'When value has spaces and no quote' {
        It 'Auto-wraps completion text with single quotes' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies'
            }
            $result.CompletionText | Should -Be "'Action Movies'"
        }

        It 'ListItemText remains unquoted' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies'
            }
            $result.ListItemText | Should -Be 'Action Movies'
        }

        It 'ToolTip remains unquoted' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies'
            }
            $result.ToolTip | Should -Be 'Action Movies'
        }
    }

    Context 'When QuoteChar is provided' {
        It 'Uses provided single quote character' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies' -QuoteChar "'"
            }
            $result.CompletionText | Should -Be "'Movies'"
        }

        It 'Uses provided double quote character' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies' -QuoteChar '"'
            }
            $result.CompletionText | Should -Be '"Movies"'
        }

        It 'Preserves provided quote even when value has no spaces' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Movies' -QuoteChar "'"
            }
            $result.CompletionText | Should -Be "'Movies'"
        }

        It 'Preserves provided quote when value has spaces' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies' -QuoteChar '"'
            }
            $result.CompletionText | Should -Be '"Action Movies"'
        }
    }

    Context 'When custom ToolTip is provided' {
        It 'Uses custom tooltip' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '12345' -ToolTip 'Movies (ID: 12345)'
            }
            $result.ToolTip | Should -Be 'Movies (ID: 12345)'
        }

        It 'CompletionText is still the value' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '12345' -ToolTip 'Movies (ID: 12345)'
            }
            $result.CompletionText | Should -Be '12345'
        }
    }

    Context 'When custom ListItemText is provided' {
        It 'Uses custom list item text' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '12345' -ListItemText '12345 - Movies'
            }
            $result.ListItemText | Should -Be '12345 - Movies'
        }

        It 'CompletionText is still the value' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '12345' -ListItemText '12345 - Movies'
            }
            $result.CompletionText | Should -Be '12345'
        }
    }

    Context 'Combining options' {
        It 'Handles QuoteChar with ToolTip' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies' -QuoteChar '"' -ToolTip 'My action movie collection'
            }
            $result.CompletionText | Should -Be '"Action Movies"'
            $result.ToolTip | Should -Be 'My action movie collection'
        }

        It 'Handles QuoteChar with ListItemText' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Action Movies' -QuoteChar '"' -ListItemText 'Action Movies (5 items)'
            }
            $result.CompletionText | Should -Be '"Action Movies"'
            $result.ListItemText | Should -Be 'Action Movies (5 items)'
        }

        It 'Handles all options together' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '2' -QuoteChar '' -ToolTip 'Movies (ID: 2)' -ListItemText '2 - Movies'
            }
            $result.CompletionText | Should -Be '2'
            $result.ToolTip | Should -Be 'Movies (ID: 2)'
            $result.ListItemText | Should -Be '2 - Movies'
        }
    }

    Context 'Output type' {
        It 'Returns CompletionResult object' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'Test'
            }
            $result | Should -BeOfType [System.Management.Automation.CompletionResult]
        }
    }

    Context 'Parameter validation' {
        It 'Requires Value parameter' {
            { InModuleScope PlexAutomationToolkit { New-PatCompletionResult } } |
                Should -Throw
        }

        It 'Rejects empty Value' {
            { InModuleScope PlexAutomationToolkit { New-PatCompletionResult -Value '' } } |
                Should -Throw
        }

        It 'Rejects null Value' {
            { InModuleScope PlexAutomationToolkit { New-PatCompletionResult -Value $null } } |
                Should -Throw
        }
    }

    Context 'Edge cases' {
        It 'Handles numeric strings' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '12345'
            }
            $result.CompletionText | Should -Be '12345'
        }

        It 'Handles paths without spaces' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '/mnt/media/Movies'
            }
            $result.CompletionText | Should -Be '/mnt/media/Movies'
        }

        It 'Handles paths with spaces' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value '/mnt/media/My Movies'
            }
            $result.CompletionText | Should -Be "'/mnt/media/My Movies'"
        }

        It 'Handles single character value' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value 'M'
            }
            $result.CompletionText | Should -Be 'M'
        }

        It 'Handles value with tabs' {
            $result = InModuleScope PlexAutomationToolkit {
                New-PatCompletionResult -Value "Movies`tCollection"
            }
            # Tab is whitespace, so should be quoted
            $result.CompletionText | Should -Be "'Movies`tCollection'"
        }
    }
}
