BeforeAll {
    # Import the module
    if ($null -eq $Env:BHBuildOutput) {
        $buildFilePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\.build.psake.ps1'
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

Describe 'Get-PatToken' {
    Context 'Default behavior (quick instructions)' {
        It 'Should return instructions when called without parameters' {
            $result = Get-PatToken

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should include "HOW TO FIND YOUR PLEX TOKEN" header' {
            $result = Get-PatToken

            $result | Should -BeLike "*HOW TO FIND YOUR PLEX TOKEN*"
        }

        It 'Should include Method 1 (Web App)' {
            $result = Get-PatToken

            $result | Should -BeLike "*Method 1 - Via Plex Web App*"
        }

        It 'Should include Method 2 (Server Settings)' {
            $result = Get-PatToken

            $result | Should -BeLike "*Method 2 - Via Server Settings*"
        }

        It 'Should include usage example with Add-PatServer' {
            $result = Get-PatToken

            $result | Should -BeLike "*Add-PatServer*"
        }

        It 'Should include security warning' {
            $result = Get-PatToken

            $result | Should -BeLike "*SECURITY WARNING*"
        }

        It 'Should mention plaintext storage warning' {
            $result = Get-PatToken

            $result | Should -BeLike "*PLAINTEXT*"
        }

        It 'Should include link to official Plex documentation' {
            $result = Get-PatToken

            $result | Should -BeLike "*https://support.plex.tv/articles/204059436*"
        }

        It 'Should mention ShowInstructions parameter for detailed help' {
            $result = Get-PatToken

            $result | Should -BeLike "*Get-PatToken -ShowInstructions*"
        }
    }

    Context 'Detailed instructions (-ShowInstructions)' {
        It 'Should return detailed instructions with -ShowInstructions' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should include "HOW TO OBTAIN YOUR PLEX AUTHENTICATION TOKEN" header' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*HOW TO OBTAIN YOUR PLEX AUTHENTICATION TOKEN*"
        }

        It 'Should include METHOD 1: WEB APP section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*METHOD 1: WEB APP*"
        }

        It 'Should include METHOD 2: BROWSER DEVELOPER TOOLS section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*METHOD 2: BROWSER DEVELOPER TOOLS*"
        }

        It 'Should include METHOD 3: SERVER LOGS section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*METHOD 3: SERVER LOGS*"
        }

        It 'Should include server log paths for different platforms' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*Windows: %LOCALAPPDATA%\Plex Media Server\Logs*"
            $result | Should -BeLike "*Linux:*"
            $result | Should -BeLike "*macOS:*"
        }

        It 'Should include "USING YOUR TOKEN" section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*USING YOUR TOKEN*"
        }

        It 'Should include "WHEN IS AUTHENTICATION REQUIRED?" section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*WHEN IS AUTHENTICATION REQUIRED?*"
        }

        It 'Should include "SECURITY CONSIDERATIONS" section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*SECURITY CONSIDERATIONS*"
        }

        It 'Should include security warnings about plaintext storage' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*PLAINTEXT STORAGE*"
        }

        It 'Should include information about token revocation' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*TOKEN REVOCATION*"
        }

        It 'Should include "ADDITIONAL RESOURCES" section' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*ADDITIONAL RESOURCES*"
        }

        It 'Should include both documentation links' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*https://support.plex.tv/articles/204059436*"
            $result | Should -BeLike "*https://support.plex.tv/articles/200890058*"
        }

        It 'Should include example with Add-PatServer cmdlet' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*Add-PatServer*-Name*"
        }

        It 'Should include example with Remove-PatServer cmdlet' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*Remove-PatServer*"
        }
    }

    Context 'Output comparison' {
        It 'Should return different output with and without -ShowInstructions' {
            $quick = Get-PatToken
            $detailed = Get-PatToken -ShowInstructions

            $quick | Should -Not -Be $detailed
        }

        It 'Should return longer output with -ShowInstructions' {
            $quick = Get-PatToken
            $detailed = Get-PatToken -ShowInstructions

            $detailed.Length | Should -BeGreaterThan $quick.Length
        }

        It 'Should include METHOD 3 only in detailed instructions' {
            $quick = Get-PatToken
            $detailed = Get-PatToken -ShowInstructions

            $quick | Should -Not -BeLike "*METHOD 3*"
            $detailed | Should -BeLike "*METHOD 3*"
        }
    }

    Context 'Function attributes' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-PatToken
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have ShowInstructions switch parameter' {
            $command = Get-Command Get-PatToken
            $command.Parameters.ContainsKey('ShowInstructions') | Should -Be $true
            $command.Parameters['ShowInstructions'].ParameterType | Should -Be ([switch])
        }

        It 'Should have ShowInstructions as optional parameter' {
            $command = Get-Command Get-PatToken
            $command.Parameters['ShowInstructions'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }

    Context 'Security warnings' {
        It 'Should warn about full account access in quick instructions' {
            $result = Get-PatToken

            $result | Should -BeLike "*FULL ACCESS*"
        }

        It 'Should warn about not sharing token in quick instructions' {
            $result = Get-PatToken

            $result | Should -BeLike "*Never share your token*"
        }

        It 'Should warn about full account access in detailed instructions' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*FULL ACCOUNT ACCESS*"
        }

        It 'Should warn about password change for token revocation' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*change your Plex*password*"
        }

        It 'Should include best practices in detailed instructions' {
            $result = Get-PatToken -ShowInstructions

            $result | Should -BeLike "*BEST PRACTICES*"
        }
    }

    Context 'Cmdlet discoverability' {
        It 'Should be exported from module' {
            $command = Get-Command Get-PatToken -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
        }

        It 'Should have Pat prefix' {
            $command = Get-Command Get-PatToken
            $command.Name | Should -BeLike "*Pat*"
        }

        It 'Should use approved Get verb' {
            $command = Get-Command Get-PatToken
            $command.Verb | Should -Be 'Get'
        }
    }
}
