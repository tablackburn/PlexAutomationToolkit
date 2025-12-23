# Integration Tests for PlexAutomationToolkit

## Overview

Integration tests verify PlexAutomationToolkit against a real Plex server. These tests are **automatically skipped** if environment variables are not set.

## Quick Start

1. **Create local settings file**:
   ```powershell
   Copy-Item tests/local.settings.example.ps1 tests/local.settings.ps1
   ```

2. **Edit `tests/local.settings.ps1`** with your Plex server details:
   - Set `PLEX_SERVER_URI` (e.g., `http://192.168.1.100:32400`)
   - Set `PLEX_TOKEN` (get via `Get-PatToken`)

3. **Load settings and run tests**:
   ```powershell
   # Load environment variables
   . ./tests/local.settings.ps1

   # Run all tests (integration tests will auto-run)
   ./build.ps1 -Task Test

   # Or run only integration tests
   Invoke-Pester -Path tests/Integration/
   ```

## Environment Variables

### Required for Integration Tests
- `PLEX_SERVER_URI` - Plex server URL (e.g., `http://192.168.1.100:32400`)
- `PLEX_TOKEN` - Plex authentication token (see `Get-PatToken` for instructions)

### Optional
- `PLEX_TEST_SECTION_ID` - Specific section ID to test (discovered dynamically if not set)
- `PLEX_TEST_SECTION_NAME` - Specific section name to test (discovered dynamically if not set)
- `PLEX_ALLOW_MUTATIONS` - Set to `'true'` to enable tests that trigger library refresh

## CI/CD Setup (GitHub Actions)

In GitHub repository secrets, add:
- `PLEX_SERVER_URI`
- `PLEX_TOKEN`

Workflow will automatically use these as environment variables. Integration tests will run automatically when secrets are present, and skip when not configured.

## Security Notes

- **NEVER commit `local.settings.ps1`** (it contains your token)
- `local.settings.ps1` is in `.gitignore`
- Plex tokens provide full account access - treat as passwords
- Only use test tokens on trusted CI/CD systems

## Test Categories

### Read-Only Tests (Always Safe)
- Server connectivity and info retrieval
- Library section listing
- Path queries
- Content browsing

Tests in this category use dynamic discovery and work with any Plex server configuration.

### Server Configuration Tests (Safe with Cleanup)
- Add/remove server configurations
- Set default server
- Retrieve stored server configurations

Tests use temporary entries with "IntegrationTest-" prefix and always clean up after completion.

### Mutating Tests (Require `PLEX_ALLOW_MUTATIONS=true`)
- Library refresh operations

These tests trigger server work (scanning for new content). Set `$env:PLEX_ALLOW_MUTATIONS = 'true'` to enable.

## Troubleshooting

**Tests are skipped**:
- Ensure `local.settings.ps1` is loaded: `. ./tests/local.settings.ps1`
- Verify env vars are set: `$env:PLEX_SERVER_URI` and `$env:PLEX_TOKEN`
- Check output message showing which variables are missing

**Connection failures**:
- Verify Plex server is running and accessible
- Check URI format: `http://hostname:32400` (not https for local servers)
- Verify token with: `Get-PatServer -ServerUri $env:PLEX_SERVER_URI`
- Check firewall settings allow access to port 32400

**Authentication failures**:
- Token may be expired - regenerate via `Get-PatToken` instructions
- Verify token is correct (no extra spaces/quotes)
- Ensure token has required permissions

## Test File Organization

```
tests/Integration/
├── README.md                                    (this file)
├── IntegrationTestHelpers.psm1                  (shared utilities)
└── Public/
    ├── LibraryQueries.Integration.tests.ps1     (read-only query tests)
    ├── ServerManagement.Integration.tests.ps1   (server config tests)
    └── LibraryOperations.Integration.tests.ps1  (mutation tests)
```

## How It Works

Integration tests use Pester's `BeforeDiscovery` block to check for environment variables:

- **If env vars are set**: Tests run normally against your real Plex server
- **If env vars are NOT set**: Entire test suite is skipped (not failed) with a helpful message

This means:
- You can run `./build.ps1 -Task Test` without any setup - integration tests will skip gracefully
- Once you configure your local settings, the same command automatically enables integration tests
- CI/CD pipelines work the same way - just add secrets to enable integration testing
