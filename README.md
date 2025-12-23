# PlexAutomationToolkit

A PowerShell module for managing Plex servers

## Overview

PlexAutomationToolkit provides cmdlets for managing Plex servers, including server configuration, library management, and content operations.

## Installation

## Examples

## Testing

PlexAutomationToolkit includes comprehensive unit and integration tests.

### Run All Tests
```powershell
./build.ps1 -Task Test
```

### Run Only Unit Tests
```powershell
Invoke-Pester -Path tests/Unit/
```

### Run Integration Tests

Integration tests require a live Plex server. Setup:

1. Copy `tests/local.settings.example.ps1` to `tests/local.settings.ps1`
2. Configure your Plex server URI and token
3. Load settings: `. ./tests/local.settings.ps1`
4. Run tests: `./build.ps1 -Task Test` (integration tests will auto-run)

See `tests/Integration/README.md` for detailed setup instructions.

**Note**: Integration tests automatically skip if environment variables are not configured.
