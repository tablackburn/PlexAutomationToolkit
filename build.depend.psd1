# Build dependencies for PlexAutomationToolkit
# These are the modules needed for building and testing the module
@{
    PSDependOptions    = @{
        Target     = 'CurrentUser'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }
    'Pester'           = @{
        Version    = '6.0.1'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake'            = @{
        Version = '5.0.4'
    }
    'BuildHelpers'     = @{
        Version = '2.0.16'
    }
    'PowerShellBuild'  = @{
        Version = '0.7.3'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.25.0'
    }
    # Parses CHANGELOG.md (Keep a Changelog format) so the Publish task can populate the
    # built manifest's PSData.ReleaseNotes from the matching version's entry.
    'ChangelogManagement' = @{
        Version = '3.1.0'
    }
    'Microsoft.PowerShell.SecretManagement' = @{
        Version = '1.1.2'
    }
}
