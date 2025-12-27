# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added

- New cmdlet `Get-PatSession` to retrieve active playback sessions from a Plex server
  - Lists all active streaming sessions with detailed information
  - Properties include: SessionId, MediaTitle, Username, PlayerName, Progress, Bandwidth, etc.
  - Filter by `-Username` or `-Player` parameters
  - Returns `PlexAutomationToolkit.Session` objects
- New cmdlet `Stop-PatSession` to terminate an active playback session
  - Terminates streaming sessions by SessionId
  - Supports `-Reason` parameter to display a message to the disconnected user
  - Pipeline support: accepts input from `Get-PatSession`
  - `ConfirmImpact = 'High'` - prompts for confirmation by default
  - Supports `-WhatIf` and `-Confirm` for safe execution
  - Supports `-PassThru` to return session info before termination
- New private helper function `Test-PatServerUri` for centralized URI validation
  - Validates HTTP/HTTPS URL format for Plex server URIs
  - Provides consistent error messages across cmdlets
  - Designed for use with `ValidateScript` attribute

## [0.2.0] - 2025-12-26

### Added

- New cmdlet `Connect-PatAccount` for simplified Plex authentication using PIN/OAuth flow
  - Interactive authentication using 4-character PIN code at plex.tv/link
  - No credential handling - uses same secure flow as Plex TV apps
  - Returns authentication token for use with `Add-PatServer`
  - Configurable timeout (default 5 minutes)
  - Persistent client identifier stored in configuration
- New private helper functions for PIN authentication flow:
  - `Get-PatClientIdentifier` - Generates/retrieves unique device ID
  - `New-PatPin` - Requests PIN from Plex API
  - `Wait-PatPinAuthorization` - Polls for user authorization
  - `Invoke-PatPinAuthentication` - Orchestrates complete PIN flow
- New cmdlet `Clear-PatDefaultServer` to remove the default server designation from all configured servers
  - Supports `-PassThru` parameter to return server configurations after clearing
  - Supports `-WhatIf` and `-Confirm` for safe execution
  - Useful for scripts requiring explicit `-ServerUri` parameter on all cmdlets

## [0.1.0] - 2025-12-22

### Added

- Initial release of PlexAutomationToolkit with core server management commands (add, remove, set default, retrieve stored servers).
- Library management commands to list sections, refresh sections, resolve library paths, and browse child items by path, section name, or section ID.
- Optional X-Plex-Token authentication support for Plex servers requiring authentication
- New cmdlet `Get-PatToken` to help users obtain their Plex authentication token with detailed instructions
- New parameter `-Token` on `Add-PatServer` to store authentication tokens with server configurations
- Private helper function `Get-PatAuthHeaders` for centralized authentication header management
- All API-calling cmdlets now support authenticated requests when tokens are configured

### Changed

- Updated `Get-PatServer`, `Get-PatLibrary`, `Get-PatLibraryPath`, `Get-PatLibraryChildItem`, and `Update-PatLibrary` to include X-Plex-Token header in API requests when servers have authentication tokens configured
- Enhanced documentation with authentication guidance and security warnings

### Security

- **IMPORTANT**: Tokens are stored in PLAINTEXT in `servers.json`. Only use on trusted systems with appropriate file permissions.

### Notes

- Backward compatible: Existing server configurations without tokens continue to work
- Authentication is OPTIONAL: Unauthenticated local network access still supported when servers are configured to allow it
- No configuration schema version bump: Token property is additive
