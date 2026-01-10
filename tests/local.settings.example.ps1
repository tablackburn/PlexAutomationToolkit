# PlexAutomationToolkit Integration Test Configuration
# Copy this file to local.settings.ps1 and fill in your values
# local.settings.ps1 is gitignored and will not be committed

# REQUIRED: Plex server connection details
$env:PLEX_SERVER_URI = 'http://your-plex-server:32400'  # Example: http://192.168.1.100:32400
$env:PLEX_TOKEN = 'your-plex-token-here'                # Get token via: Get-PatToken

# OPTIONAL: Test-specific configuration
# $env:PLEX_TEST_SECTION_ID = '1'                       # A known library section ID for testing
# $env:PLEX_TEST_SECTION_NAME = 'Movies'                # A known library section name for testing
# $env:PLEX_TEST_LIBRARY_PATH = '/mnt/media/Movies/SomeFolder'  # A real path on your Plex server for path validation tests
# $env:PLEX_ALLOW_LIBRARY_REFRESH = 'true'              # Enable library refresh tests (trigger server background scans)

# USAGE:
# Before running integration tests, run:
#   . ./tests/local.settings.ps1
# Or add to your PowerShell profile for automatic loading

Write-Host "Integration test environment variables configured" -ForegroundColor Green
Write-Host "Server URI: $env:PLEX_SERVER_URI" -ForegroundColor Cyan
