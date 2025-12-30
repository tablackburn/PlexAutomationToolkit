BeforeAll {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'ConvertFrom-PatCompleterInput' {

    Context 'When input has no quotes' {
        It 'Returns empty QuoteChar and original word' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Movies'
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be 'Movies'
        }

        It 'Handles words with spaces' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Action Movies'
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be 'Action Movies'
        }

        It 'Handles partial words' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Mov'
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be 'Mov'
        }
    }

    Context 'When input has single quote' {
        It 'Extracts single quote and strips it from word' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "'Movies"
            }
            $result.QuoteChar | Should -Be "'"
            $result.StrippedWord | Should -Be 'Movies'
        }

        It 'Handles partial quoted word' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "'Action Mov"
            }
            $result.QuoteChar | Should -Be "'"
            $result.StrippedWord | Should -Be 'Action Mov'
        }

        It 'Handles just a single quote' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "'"
            }
            $result.QuoteChar | Should -Be "'"
            $result.StrippedWord | Should -Be ''
        }
    }

    Context 'When input has double quote' {
        It 'Extracts double quote and strips it from word' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete '"Movies'
            }
            $result.QuoteChar | Should -Be '"'
            $result.StrippedWord | Should -Be 'Movies'
        }

        It 'Handles partial quoted word' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete '"Action Mov'
            }
            $result.QuoteChar | Should -Be '"'
            $result.StrippedWord | Should -Be 'Action Mov'
        }

        It 'Handles just a double quote' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete '"'
            }
            $result.QuoteChar | Should -Be '"'
            $result.StrippedWord | Should -Be ''
        }
    }

    Context 'When input is empty or null' {
        It 'Handles empty string' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete ''
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be ''
        }

        It 'Handles null by using default empty string' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be ''
        }
    }

    Context 'Edge cases' {
        It 'Does not treat quote in middle as leading quote' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "Movie's"
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be "Movie's"
        }

        It 'Only strips leading quote, not trailing' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "'Movies'"
            }
            $result.QuoteChar | Should -Be "'"
            $result.StrippedWord | Should -Be "Movies'"
        }

        It 'Handles numeric input' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete '12345'
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be '12345'
        }

        It 'Handles path-like input' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete '/mnt/media/Movies'
            }
            $result.QuoteChar | Should -Be ''
            $result.StrippedWord | Should -Be '/mnt/media/Movies'
        }

        It 'Handles quoted path' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete "'/mnt/media/My Movies"
            }
            $result.QuoteChar | Should -Be "'"
            $result.StrippedWord | Should -Be '/mnt/media/My Movies'
        }
    }

    Context 'Output type' {
        It 'Returns PSCustomObject' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Test'
            }
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Has QuoteChar property' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Test'
            }
            $result.PSObject.Properties.Name | Should -Contain 'QuoteChar'
        }

        It 'Has StrippedWord property' {
            $result = InModuleScope PlexAutomationToolkit {
                ConvertFrom-PatCompleterInput -WordToComplete 'Test'
            }
            $result.PSObject.Properties.Name | Should -Contain 'StrippedWord'
        }
    }
}
