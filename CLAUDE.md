# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PlexAutomationToolkit is a PowerShell module for managing Plex servers. It provides cmdlets for server management (add/remove/configure servers) and library operations (list sections, refresh libraries, browse content, resolve paths).

## Build and Test Commands

### Initial Setup
```powershell
./build.ps1 -Bootstrap
```
This installs all build dependencies (PSDepend, Pester 5, psake, BuildHelpers, PowerShellBuild, PSScriptAnalyzer) to the current user scope.

### Primary Development Loop
```powershell
./build.ps1 -Task Test
```
Default task that builds the module and runs all tests (Manifest, Help, Meta tests).

### List Available Tasks
```powershell
./build.ps1 -Help
```

### Run Single Test File
```powershell
# First set build environment
Set-BuildEnvironment -Force

# Then run specific test
Invoke-Pester -Path tests/Help.tests.ps1
```

### Import Module Locally
```powershell
# Import from built output
Import-Module ./Output/PlexAutomationToolkit/<version>/PlexAutomationToolkit.psd1 -Force

# Or import from source during iteration
Import-Module ./PlexAutomationToolkit/PlexAutomationToolkit.psd1 -Force
```

## Module Architecture

### File Structure Pattern
- **PlexAutomationToolkit/PlexAutomationToolkit.psm1** - Dot-sources all .ps1 files from `Public/` and `Private/` directories, exports only public functions via `Export-ModuleMember -Function $public.Basename`
- **Public/** - Exported cmdlets available to users (must be added to `FunctionsToExport` in manifest)
- **Private/** - Internal helper functions (not exported)
- **Output/** - Built module artifacts (created by build process, loads from here during tests)

### Core API Helpers (Private/)

**Invoke-PatApi.ps1** - Wraps `Invoke-RestMethod` for all Plex API calls:
- Defaults to `Accept: application/json` header
- Returns `MediaContainer` property from response when present, otherwise full response
- Standardized error handling pattern

**Join-PatUri.ps1** - URI construction helper:
- Uses `[Uri]` class to normalize path separators
- Handles query string parameters
- Use this for all endpoint construction to ensure consistent URI formatting

**Get-PatServerConfig.ps1 / Set-PatServerConfig.ps1** - Server configuration persistence:
- Stores server connections in JSON format at user profile location
- Schema: `{ version: "1.0", servers: [...] }`
- Handles default server selection

### Public Command Pattern

All public cmdlets follow consistent patterns:

1. **CmdletBinding and Parameters**:
   - `[CmdletBinding()]` on every function
   - `ValidateNotNullOrEmpty` for required strings
   - `ValidateRange` for numeric bounds
   - `-ServerUri` parameter defaults to stored default server when omitted

2. **Error Handling**:
   ```powershell
   try {
       # API operation
   }
   catch {
       throw "Failed to <operation>: $($_.Exception.Message)"
   }
   ```

3. **URI Construction**:
   ```powershell
   $uri = Join-PatUri -BaseUri $ServerUri -Endpoint '/library/sections'
   ```

4. **API Invocation**:
   ```powershell
   Invoke-PatApi -Uri $uri -Method Get
   ```

5. **ShouldProcess for Mutations**:
   See `Update-PatLibrary.ps1` for reference - includes `SupportsShouldProcess` and `ConfirmImpact` attributes, with `if ($PSCmdlet.ShouldProcess(...))` checks.

## Testing Requirements

Tests run against built module in `Output/<ModuleName>/<Version>/` directory. The build sets `BH*` environment variables via `Set-BuildEnvironment` that tests rely on.

### Manifest.tests.ps1
- Validates manifest fields populated (ModuleVersion, Author, Copyright, Description)
- Ensures `ModuleVersion` matches `CHANGELOG.md` latest entry
- Verifies RootModule reference

### Help.tests.ps1
- **Critical**: Every public function requires non-auto-generated comment-based help
- Must include: Synopsis, Description, Parameter descriptions, Examples (with code and explanation)
- Parameter help must match actual parameters (name, type, mandatory status)
- No extra parameters in help that don't exist in code

### Meta.tests.ps1
- All files must be UTF-8 encoding (no UTF-16)
- No tab characters allowed (use 4 spaces for indentation)

## Integration Testing

Integration tests verify PlexAutomationToolkit against a real Plex server. They are automatically skipped if environment variables are not configured.

### Setup Integration Tests

1. Create local configuration:
   ```powershell
   Copy-Item tests/local.settings.example.ps1 tests/local.settings.ps1
   ```

2. Edit `tests/local.settings.ps1`:
   - Set `PLEX_SERVER_URI` to your Plex server (e.g., `http://192.168.1.100:32400`)
   - Set `PLEX_TOKEN` (obtain via `Get-PatToken`)

3. Load settings before testing:
   ```powershell
   . ./tests/local.settings.ps1
   ./build.ps1 -Task Test  # Runs both unit and integration tests
   ```

### Integration Test Categories

**Read-Only Tests**: Safe, use dynamic discovery
- Server connectivity and info retrieval (`Get-PatServer`)
- Library section listing and querying (`Get-PatLibrary`)
- Server configuration retrieval (`Get-PatStoredServer`)
- Path and content browsing (if implemented)

**Server Configuration Tests**: Safe with cleanup
- Add/remove server configurations (`Add-PatServer`, `Remove-PatServer`)
- Set default server (`Set-PatDefaultServer`)
- Uses temporary test entries with "IntegrationTest-" prefix
- Always cleans up in `AfterAll` blocks

**Mutation Tests**: Require `$env:PLEX_ALLOW_MUTATIONS = 'true'`
- Library refresh operations (`Update-PatLibrary`)
- Triggers Plex server to scan for new content

### CI/CD Integration

GitHub Actions automatically runs integration tests when these secrets are configured:
- `PLEX_SERVER_URI`
- `PLEX_TOKEN`
- `PLEX_ALLOW_MUTATIONS` (optional)

If secrets are not set, integration tests are automatically skipped (not failed).

### Integration Test Implementation Pattern

All integration tests use conditional execution via `BeforeDiscovery`:

```powershell
BeforeDiscovery {
    $script:integrationEnabled = $false

    if ($env:PLEX_SERVER_URI -and $env:PLEX_TOKEN) {
        $script:integrationEnabled = $true
    }
}

Describe 'Test Suite' -Skip:(-not $script:integrationEnabled) {
    # Tests only run when env vars are set
}
```

See `tests/Integration/README.md` for detailed setup instructions.

## Versioning and Changelog

- **ModuleVersion** in `PlexAutomationToolkit.psd1` must match latest version in `CHANGELOG.md`
- Update both files together when releasing new version
- Changelog follows [Keep a Changelog](http://keepachangelog.com/) format
- Project uses [Semantic Versioning](http://semver.org/)

## Plex API Specifics

- All commands accept `-ServerUri` parameter (format: `http://hostname:32400`)
- Path parameters (e.g., in `Update-PatLibrary -Path`) must be URL-escaped
- Use `[Microsoft.PowerShell.Commands.WebRequestMethod]::Post` for POST operations
- MediaContainer is the standard Plex API response wrapper object

## Coding Conventions

- 4-space indentation (no tabs)
- UTF-8 encoding only
- Comment-based help in every public function
- Consistent parameter validation (`ValidateNotNullOrEmpty`, etc.)
- Short, user-facing error messages that rethrow with context
- Return objects from API helpers, don't write directly to pipeline inside helpers
