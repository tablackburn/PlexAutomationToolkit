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
        # Not an exact version. Pester 6 discovers each test file separately and
        # autoloads Pester to resolve Describe; autoload always selects the highest
        # installed version, overriding whatever was explicitly imported. So a pin
        # below the runner image's Pester collides:
        #   Could not load file or assembly 'Pester, Version=6.0.1.0'.
        #   Assembly with same name is already loaded
        # which is how CI here broke with no commit to blame. The pin was never
        # authoritative; it only guaranteed breakage on every Pester release.
        Version    = 'latest'
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
