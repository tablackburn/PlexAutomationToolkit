# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PlexAutomationToolkit is a PowerShell module for managing Plex servers. It provides cmdlets for server management (add/remove/configure servers) and library operations (list sections, refresh libraries, browse content, resolve paths).

## Build and Test Commands

### Running PowerShell Commands (Important for Claude Code)

When executing PowerShell scripts from a bash/sh shell environment (which Claude Code uses by default), always invoke `pwsh` explicitly:

```bash
# Correct - explicitly invoke PowerShell
pwsh -File ./build.ps1 -Task Test
pwsh -Command "Import-Module ./PlexAutomationToolkit/PlexAutomationToolkit.psd1 -Force"

# Incorrect - will fail with syntax errors in bash
./build.ps1 -Task Test  # ❌ Bash interprets PowerShell syntax as shell script
```

Running `./build.ps1` directly in bash causes syntax errors like:
```
syntax error near unexpected token `newline'
```

This happens because bash tries to parse PowerShell attributes (e.g., `[CmdletBinding()]`) as shell syntax.

### Initial Setup
```powershell
pwsh -File ./build.ps1 -Bootstrap
```
This installs all build dependencies (PSDepend, Pester 5, psake, BuildHelpers, PowerShellBuild, PSScriptAnalyzer) to the current user scope.

### Primary Development Loop
```powershell
pwsh -File ./build.ps1 -Task Test
```
Default task that builds the module and runs all tests (Manifest, Help, Meta tests).

### List Available Tasks
```powershell
pwsh -File ./build.ps1 -Help
```

### Run Single Test File
```powershell
# First set build environment, then run specific test
pwsh -Command "Set-BuildEnvironment -Force; Invoke-Pester -Path tests/Help.tests.ps1"
```

### Import Module Locally
```powershell
# Import from built output
pwsh -Command "Import-Module ./Output/PlexAutomationToolkit/<version>/PlexAutomationToolkit.psd1 -Force"

# Or import from source during iteration
pwsh -Command "Import-Module ./PlexAutomationToolkit/PlexAutomationToolkit.psd1 -Force"
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
   pwsh -Command "Copy-Item tests/local.settings.example.ps1 tests/local.settings.ps1"
   ```

2. Edit `tests/local.settings.ps1`:
   - Set `PLEX_SERVER_URI` to your Plex server (e.g., `http://192.168.1.100:32400`)
   - Set `PLEX_TOKEN` (obtain via `Get-PatToken`)

3. Run tests (settings are automatically loaded by the Test task):
   ```powershell
   pwsh -File ./build.ps1 -Task Test  # Test task automatically loads local.settings.ps1
   ```

   The psake Test task depends on the Init_Integration task, which automatically loads `tests/local.settings.ps1` if it exists. This follows the psake task dependency pattern. You can also manually load settings for ad-hoc testing:
   ```powershell
   pwsh -Command ". ./tests/local.settings.ps1; Invoke-Pester -Path tests/Integration/"
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

## PowerShell Best Practices

### Naming Conventions

**Functions**
- Use approved PowerShell verbs: `Get`, `Set`, `Add`, `Remove`, `Update`, `New`, `Test`, `Invoke`
- Check verb approval: `Get-Verb | Where-Object Verb -eq 'YourVerb'`
- Follow Verb-Noun format in PascalCase: `Get-PatLibrary`, `Update-PatLibrary`
- Module prefix (`Pat` for PlexAutomationToolkit) ensures uniqueness

**Parameters**
- Use PascalCase: `-ServerUri`, `-LibraryId`, `-Path`
- Use singular forms: `-Library` not `-Libraries` (even if accepting arrays)
- Match PowerShell common parameter names when applicable:
  - `-Name`, `-Path`, `-Force`, `-PassThru`, `-WhatIf`, `-Confirm`
- Avoid abbreviations unless widely recognized: `-Id` is OK, `-Srv` is not

**Code Style**
- Never use aliases in code (`foreach` instead of `%`, `Where-Object` instead of `?`)
- Full cmdlet names for clarity and maintainability
- Opening braces on same line: `function Get-PatLibrary {`

### Parameter Design

**Validation Attributes**
```powershell
# String validation
[ValidateNotNullOrEmpty()]
[string]$ServerUri

# Numeric bounds
[ValidateRange(1, [int]::MaxValue)]
[int]$LibraryId

# Restricted options
[ValidateSet('Movies', 'TV Shows', 'Music')]
[string]$LibraryType

# Pattern matching
[ValidatePattern('^https?://')]
[string]$Uri
```

**Switch Parameters**
```powershell
# Use [switch] for boolean flags
[switch]$Force

# NOT this:
[bool]$Force  # ❌ Anti-pattern
```

**Pipeline Support**
```powershell
# Accept pipeline input by value
[Parameter(ValueFromPipeline)]
[object]$InputObject

# Accept pipeline input by property name
[Parameter(ValueFromPipelineByPropertyName)]
[string]$Name

# Support both patterns when appropriate
[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
[int]$LibraryId
```

### Pipeline and Output Design

**Pipeline Processing**
```powershell
function Get-PatLibraryItem {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [int]$LibraryId
    )

    begin {
        # Initialize once (e.g., establish connection, validate prerequisites)
        Write-Verbose "Starting library item retrieval"
    }

    process {
        # Execute for each pipeline item
        foreach ($id in $LibraryId) {
            # Process each item
            $result = Invoke-PatApi -Uri $uri
            Write-Output $result
        }
    }

    end {
        # Cleanup once (e.g., close connections, summary logging)
        Write-Verbose "Completed library item retrieval"
    }
}
```

**Output Rich Objects**
```powershell
# Return structured objects, not formatted text
[PSCustomObject]@{
    PSTypeName = 'PlexAutomationToolkit.Library'
    LibraryId  = $section.key
    Name       = $section.title
    Type       = $section.type
    ServerUri  = $ServerUri
}

# NOT this:
Write-Output "Library: $($section.title) (ID: $($section.key))"  # ❌ Anti-pattern
```

**PassThru Pattern**
```powershell
# Mutation cmdlets should be silent by default, but support -PassThru
function Update-PatLibrary {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$LibraryId,

        [switch]$PassThru
    )

    if ($PSCmdlet.ShouldProcess("Library $LibraryId", "Refresh")) {
        # Perform update
        Invoke-PatApi -Uri $uri -Method Post

        # Optionally return the updated object
        if ($PassThru) {
            Get-PatLibrary -LibraryId $LibraryId
        }
    }
}
```

### Error Handling and Streams

**Output Streams**
```powershell
# Verbose: Detailed progress for -Verbose users
Write-Verbose "Connecting to server: $ServerUri"

# Warning: Non-fatal issues that users should know about
Write-Warning "Library not found, using default"

# Error: Terminating errors with proper ErrorRecord
Write-Error -Message "Failed to connect to server" `
            -Category ConnectionError `
            -TargetObject $ServerUri `
            -ErrorId "ServerConnectionFailed"

# Information: General informational messages (PS 5.0+)
Write-Information "Processing 10 libraries" -InformationAction Continue
```

**ErrorRecord Construction**
```powershell
try {
    Invoke-PatApi -Uri $uri
}
catch {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $_.Exception,
        'ApiInvocationFailed',
        [System.Management.Automation.ErrorCategory]::ConnectionError,
        $uri
    )
    $PSCmdlet.WriteError($errorRecord)
}
```

**Non-Interactive Design**
```powershell
# Support automation - avoid Read-Host or other interactive prompts
# Use parameters with defaults instead:
param(
    [string]$ServerUri = (Get-PatDefaultServer).Uri
)

# For confirmations, use ShouldProcess (respects -Confirm and -WhatIf)
if ($PSCmdlet.ShouldProcess($targetName, $action)) {
    # Perform action
}
```

### ShouldProcess Pattern

```powershell
function Remove-PatServer {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    # ShouldProcess returns false when -WhatIf is used
    if ($PSCmdlet.ShouldProcess($Name, "Remove Plex server configuration")) {
        # Perform destructive operation
        $config = Get-PatServerConfig
        $config.servers = $config.servers | Where-Object { $_.name -ne $Name }
        Set-PatServerConfig -Config $config
    }
}
```

**ConfirmImpact Levels**
- `None`: No confirmation needed (Get-* cmdlets)
- `Low`: Minor changes (Set-PatDefaultServer)
- `Medium`: Significant changes (Update-PatLibrary) - default
- `High`: Destructive operations (Remove-PatServer)

### Comment-Based Help

Every public function must include comprehensive help:

```powershell
function Get-PatLibrary {
    <#
    .SYNOPSIS
    Retrieves Plex library sections from a Plex server.

    .DESCRIPTION
    The Get-PatLibrary cmdlet retrieves information about library sections
    configured on a Plex Media Server. You can retrieve all libraries or
    filter by library ID.

    .PARAMETER ServerUri
    The URI of the Plex server. Defaults to the stored default server.
    Format: http://hostname:32400

    .PARAMETER LibraryId
    The ID of a specific library section to retrieve. If omitted, all
    libraries are returned.

    .EXAMPLE
    Get-PatLibrary

    Retrieves all library sections from the default Plex server.

    .EXAMPLE
    Get-PatLibrary -ServerUri "http://plex.local:32400" -LibraryId 1

    Retrieves library section with ID 1 from the specified server.

    .EXAMPLE
    1, 2, 3 | Get-PatLibrary

    Retrieves library sections with IDs 1, 2, and 3 via pipeline input.

    .OUTPUTS
    PlexAutomationToolkit.Library

    .LINK
    https://github.com/user/PlexAutomationToolkit
    #>
    [CmdletBinding()]
    param(
        [string]$ServerUri,

        [Parameter(ValueFromPipeline)]
        [int]$LibraryId
    )

    process {
        # Implementation
    }
}
```

## Coding Conventions

### File and Encoding Standards
- 4-space indentation (no tabs)
- UTF-8 encoding only (no UTF-16)
- Opening braces on same line
- Newline at end of file

### Code Style
```powershell
# ✓ Correct formatting
function Get-PatLibrary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    process {
        if ($condition) {
            # Implementation
        }
    }
}

# ❌ Incorrect - brace on new line
function Get-PatLibrary
{
    # Don't do this
}
```

### Variable and Scoping
```powershell
# Use meaningful variable names
$librarySection  # ✓ Clear
$ls              # ❌ Ambiguous

# Prefer explicit scoping when necessary
$script:moduleConfig
$global:plexServers

# Use approved variable names for common patterns
$PSCmdlet        # Current cmdlet context
$PSBoundParameters  # Parameters passed to function
```

### Return Values
- Return objects from API helpers, don't write directly to pipeline inside helpers
- Use `Write-Output` explicitly when needed for clarity, or just output the object
- Avoid `return` unless exiting early; let objects flow to output naturally
- Private functions should return objects; public functions write to pipeline
