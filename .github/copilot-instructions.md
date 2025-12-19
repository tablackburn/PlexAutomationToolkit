# PlexAutomationToolkit – AI coding guide

- **Module layout:** [PlexAutomationToolkit/PlexAutomationToolkit.psm1](PlexAutomationToolkit/PlexAutomationToolkit.psm1) dot-sources everything under `Public/` and `Private/`; exports only the public basenames. Keep new public functions in `Public/` and add them to `FunctionsToExport` in [PlexAutomationToolkit/PlexAutomationToolkit.psd1](PlexAutomationToolkit/PlexAutomationToolkit.psd1). Manifest `ModuleVersion` must match the changelog.
- **API helpers:** [PlexAutomationToolkit/Private/Invoke-PatApi.ps1](PlexAutomationToolkit/Private/Invoke-PatApi.ps1) wraps `Invoke-RestMethod`, defaults to `Accept=application/json`, and returns `MediaContainer` when present. [PlexAutomationToolkit/Private/Join-PatUri.ps1](PlexAutomationToolkit/Private/Join-PatUri.ps1) builds URIs with `[Uri]` to normalize slashes and can append query strings—reuse it for all endpoints.
- **Public commands:**
  - [PlexAutomationToolkit/Public/Get-PatServer.ps1](PlexAutomationToolkit/Public/Get-PatServer.ps1) hits the root endpoint to return server metadata.
  - [PlexAutomationToolkit/Public/Get-PatLibrary.ps1](PlexAutomationToolkit/Public/Get-PatLibrary.ps1) lists all sections or a specific `SectionId`.
  - [PlexAutomationToolkit/Public/Update-PatLibrary.ps1](PlexAutomationToolkit/Public/Update-PatLibrary.ps1) triggers a section refresh; supports `-Path` (URL-escaped) and `ShouldProcess` (`-WhatIf`). Follow the same pattern—build endpoint, optional query string, descriptive try/catch that rethrows with a friendly message.
- **Parameter/validation pattern:** Every function uses `[CmdletBinding()]` with `ValidateNotNullOrEmpty` and `ValidateRange` where applicable. Keep outputs as plain objects from the API helpers; avoid writing directly to the pipeline before returning.
- **Error-handling convention:** Wrap API calls in try/catch and throw a short, user-facing message (`Failed to ...: $($_.Exception.Message)`).
- **Build & test workflow:** Use `./build.ps1 -Bootstrap` once to install toolchain (PSDepend, Pester 5, PowerShellBuild, BuildHelpers). Primary loop: `./build.ps1 -Task Test` (default task) or VS Code task **Test**. `Set-BuildEnvironment` (invoked inside the build) sets `BH*` paths used by tests—run through the build script rather than raw `Invoke-Pester`.
- **What tests expect:**
  - [tests/Manifest.tests.ps1](tests/Manifest.tests.ps1) loads the built module from `Output/<Module>/<Version>`; manifest name/root module/version/author/copyright must be populated and equal to the changelog entry.
  - [tests/Help.tests.ps1](tests/Help.tests.ps1) requires non-auto-generated help with descriptions and examples for every parameter; keep comment-based help current.
  - [tests/Meta.tests.ps1](tests/Meta.tests.ps1) enforces UTF-8 (no UTF-16) and no tab characters. Use spaces and UTF-8-only files.
- **Changelog/versioning:** Update [CHANGELOG.md](CHANGELOG.md) when bumping `ModuleVersion`; versions must match or Manifest tests fail. Git tagging tests are present but skipped—still mirror the pattern.
- **Help locale:** `PSBPreference.Help.DefaultLocale` is `en-US`; place additional help in `PlexAutomationToolkit/en-US/` if needed.
- **Plex specifics:** All commands take a `ServerUri` (include protocol/port). Use `Join-PatUri` for endpoint composition and `Invoke-PatApi` for HTTP verbs (default GET; pass `[Microsoft.PowerShell.Commands.WebRequestMethod]::Post` for refresh operations). `Update-PatLibrary` already URL-escapes `Path`—do the same for new path-based parameters.
- **Style/conventions:** Stick to ASCII/UTF-8, 4-space indentation, and avoid tabs. Follow existing comment-based help format for consistency.
- **Quick start:** `./build.ps1 -Bootstrap` (first time) → `./build.ps1 -Task Test` → import the module from the `Output` folder or `Import-Module ./PlexAutomationToolkit` during local iteration.
