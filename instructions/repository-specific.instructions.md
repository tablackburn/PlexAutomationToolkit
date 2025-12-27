---
applyTo: '**/*'
description: 'Repository-specific instructions for PlexAutomationToolkit'
---

# PlexAutomationToolkit Specific Instructions

These instructions are specific to the PlexAutomationToolkit PowerShell module and take precedence over general instructions.

## Project Overview

PlexAutomationToolkit is a PowerShell module for managing Plex Media Servers. It provides cmdlets for:

- Server management (add/remove/configure servers)
- Library operations (list sections, refresh libraries, browse content)
- Collection and playlist management
- Path resolution and content browsing

## Build and Test Commands

### Running PowerShell from Bash/Shell

When executing PowerShell scripts from a bash/sh shell environment, always invoke `pwsh` explicitly:

```bash
# Correct - explicitly invoke PowerShell
pwsh -File ./build.ps1 -Task Test
pwsh -Command "Import-Module ./PlexAutomationToolkit/PlexAutomationToolkit.psd1 -Force"

# Incorrect - will fail with syntax errors in bash
./build.ps1 -Task Test  # Bash interprets PowerShell syntax incorrectly
```

Running `./build.ps1` directly in bash causes syntax errors like `syntax error near unexpected token 'newline'` because bash tries to parse PowerShell attributes (e.g., `[CmdletBinding()]`) as shell syntax.

### Primary Commands

| Task | Command |
|------|---------|
| Bootstrap dependencies | `pwsh -File ./build.ps1 -Bootstrap` |
| Build and test (default) | `pwsh -File ./build.ps1 -Task Test` |
| List available tasks | `pwsh -File ./build.ps1 -Help` |
| Run single test file | `pwsh -Command "Set-BuildEnvironment -Force; Invoke-Pester -Path tests/Help.tests.ps1"` |
| Import from source | `pwsh -Command "Import-Module ./PlexAutomationToolkit/PlexAutomationToolkit.psd1 -Force"` |
| Import from built output | `pwsh -Command "Import-Module ./Output/PlexAutomationToolkit/<version>/PlexAutomationToolkit.psd1 -Force"` |

## Module Architecture

### Directory Structure

- `PlexAutomationToolkit/` - Module source
  - `Public/` - Exported cmdlets (added to `FunctionsToExport` in manifest)
  - `Private/` - Internal helper functions (not exported)
  - `PlexAutomationToolkit.psm1` - Module loader (dot-sources Public/ and Private/)
  - `PlexAutomationToolkit.psd1` - Module manifest
  - `en-US/` - Help locale files (default locale is `en-US`)
- `Output/` - Built module artifacts (created by build process)
- `tests/` - Pester tests

### Core API Helpers (Private/)

When implementing new cmdlets, use these private helper functions:

**Invoke-PatApi.ps1**

- Wraps `Invoke-RestMethod` for all Plex API calls
- Defaults to `Accept: application/json` header
- Returns `MediaContainer` property from response when present, otherwise full response
- Standardized error handling pattern

**Join-PatUri.ps1**

- URI construction helper using `[Uri]` class to normalize path separators
- Handles query string parameters
- Use for all endpoint construction to ensure consistent URI formatting

**Get-PatServerConfig.ps1 / Set-PatServerConfig.ps1**

- Server configuration persistence in JSON format at user profile location
- Schema: `{ version: "1.0", servers: [...] }`
- Handles default server selection

**Resolve-PatServerContext.ps1**

- Resolves server URI and token from parameters or stored defaults
- Use in cmdlets that need server connection context

### Public Cmdlet Pattern

All public cmdlets must follow this pattern:

```powershell
function Verb-PatNoun {
    <#
    .SYNOPSIS
    Brief description.

    .DESCRIPTION
    Detailed description.

    .PARAMETER ServerUri
    The URI of the Plex server. Defaults to the stored default server.

    .EXAMPLE
    Verb-PatNoun -Parameter 'Value'

    Example description.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServerUri
    )

    try {
        $uri = Join-PatUri -BaseUri $ServerUri -Endpoint '/path'
        Invoke-PatApi -Uri $uri -Method Get
    }
    catch {
        throw "Failed to <operation>: $($_.Exception.Message)"
    }
}
```

### Existing Cmdlet References

Use these existing cmdlets as implementation patterns:

- `Get-PatServer.ps1` - Hits the root endpoint to return server metadata
- `Get-PatLibrary.ps1` - Lists all sections or a specific `SectionId`
- `Update-PatLibrary.ps1` - Triggers section refresh; supports `-Path` (URL-escaped) and `ShouldProcess`

### Mutation Cmdlets

For cmdlets that modify state, include `SupportsShouldProcess`:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(...)

if ($PSCmdlet.ShouldProcess($targetName, $action)) {
    # Perform action
}
```

**ConfirmImpact Levels:**

- `None`: No confirmation needed (Get-* cmdlets)
- `Low`: Minor changes (Set-PatDefaultServer)
- `Medium`: Significant changes (Update-PatLibrary) - default
- `High`: Destructive operations (Remove-PatServer)

## Testing Requirements

Tests run against built module in `Output/<ModuleName>/<Version>/` directory. The build sets `BH*` environment variables via `Set-BuildEnvironment` that tests rely on.

### Test Categories

1. **Manifest.tests.ps1** - Validates manifest fields and version matching with CHANGELOG.md
2. **Help.tests.ps1** - Verifies comment-based help for all public functions
3. **Meta.tests.ps1** - UTF-8 encoding and no tab characters

### Critical Help Requirements

Every public function requires:

- Synopsis and Description
- Parameter descriptions for all parameters
- At least one Example with code and explanation
- Parameter help must match actual parameters (name, type, mandatory status)
- No extra parameters in help that don't exist in code

### Integration Tests

Integration tests verify PlexAutomationToolkit against a real Plex server. They are automatically skipped if environment variables are not configured.

**Required environment variables:**

- `PLEX_SERVER_URI` - Plex server URI (e.g., `http://192.168.1.100:32400`)
- `PLEX_TOKEN` - Plex authentication token (obtain via `Get-PatToken`)
- `PLEX_ALLOW_MUTATIONS` - Set to `'true'` for mutation tests

**Setup:**

1. Copy `tests/local.settings.example.ps1` to `tests/local.settings.ps1`
2. Configure environment variables in the file
3. Run `pwsh -File ./build.ps1 -Task Test` (Test task automatically loads local.settings.ps1)

### Integration Test Categories

**Read-Only Tests** (safe, use dynamic discovery):

- Server connectivity and info retrieval (`Get-PatServer`)
- Library section listing and querying (`Get-PatLibrary`)
- Server configuration retrieval (`Get-PatStoredServer`)

**Server Configuration Tests** (safe with cleanup):

- Add/remove server configurations (`Add-PatServer`, `Remove-PatServer`)
- Set default server (`Set-PatDefaultServer`)
- Uses temporary test entries with "IntegrationTest-" prefix
- Always cleans up in `AfterAll` blocks

**Mutation Tests** (require `PLEX_ALLOW_MUTATIONS = 'true'`):

- Library refresh operations (`Update-PatLibrary`)
- Triggers Plex server to scan for new content

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

### CI/CD Integration

GitHub Actions automatically runs integration tests when these secrets are configured:

- `PLEX_SERVER_URI`
- `PLEX_TOKEN`
- `PLEX_ALLOW_MUTATIONS` (optional)

If secrets are not set, integration tests are automatically skipped (not failed).

## Versioning

- **ModuleVersion** in `PlexAutomationToolkit.psd1` must match latest version in `CHANGELOG.md`
- Update both files together when releasing
- Follow [Semantic Versioning](http://semver.org/)
- Follow [Keep a Changelog](http://keepachangelog.com/) format

## File Standards

- 4-space indentation (no tabs)
- UTF-8 encoding only (no UTF-16)
- Opening braces on same line
- Single newline at end of file

## Naming Conventions

- Module prefix: `Pat` (PlexAutomationToolkit)
- Function names: `Verb-PatNoun` (e.g., `Get-PatLibrary`, `Update-PatLibrary`)
- Use approved PowerShell verbs (check with `Get-Verb`)
- Use singular nouns

## Plex API Notes

- All commands accept `-ServerUri` parameter (format: `http://hostname:32400`)
- Path parameters must be URL-escaped
- `MediaContainer` is the standard Plex API response wrapper
- Default header: `Accept: application/json`
- Use `[Microsoft.PowerShell.Commands.WebRequestMethod]::Post` for POST operations
