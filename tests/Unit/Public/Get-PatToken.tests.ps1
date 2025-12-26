BeforeAll {
    # Import the module from source
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $ModuleRoot = Join-Path $ProjectRoot 'PlexAutomationToolkit'
    $moduleManifestPath = Join-Path $ModuleRoot 'PlexAutomationToolkit.psd1'

    Get-Module PlexAutomationToolkit | Remove-Module -Force -ErrorAction 'Ignore'
    Import-Module -Name $moduleManifestPath -Verbose:$false -ErrorAction 'Stop'
}

Describe 'Get-PatToken' {
    Context 'Output content' {
        It 'Should return instructions when called' {
            $result = Get-PatToken
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should include header' {
            $result = Get-PatToken
            $result | Should -BeLike "*PLEX TOKEN RETRIEVAL*"
        }

        It 'Should recommend Connect-PatAccount' {
            $result = Get-PatToken
            $result | Should -BeLike "*Connect-PatAccount*"
        }

        It 'Should include manual method instructions' {
            $result = Get-PatToken
            $result | Should -BeLike "*MANUAL METHOD*"
        }

        It 'Should include app.plex.tv URL' {
            $result = Get-PatToken
            $result | Should -BeLike "*app.plex.tv*"
        }

        It 'Should include security warning' {
            $result = Get-PatToken
            $result | Should -BeLike "*SECURITY WARNING*"
        }

        It 'Should warn about plaintext storage' {
            $result = Get-PatToken
            $result | Should -BeLike "*PLAINTEXT*"
        }

        It 'Should include official documentation link' {
            $result = Get-PatToken
            $result | Should -BeLike "*support.plex.tv/articles/204059436*"
        }
    }

    Context 'Function attributes' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-PatToken
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have no required parameters' {
            $command = Get-Command Get-PatToken
            $mandatoryParams = $command.Parameters.Values | Where-Object {
                $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            }
            $mandatoryParams | Should -BeNullOrEmpty
        }
    }
}
