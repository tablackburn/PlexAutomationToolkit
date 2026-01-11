# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [0.10.3] - 2026-01-11

### Added

- Extended `Get-PatMediaInfo` output with human-readable formatted properties:
  - `DurationFormatted` - human-readable duration (e.g., "2h 16m")
  - `ContentRating` - age rating (e.g., "PG-13", "R", "TV-MA")
  - `Rating` - critic/Plex rating (handles complex Plex API formats)
  - `BitrateFormatted` on MediaVersion (e.g., "25.5 Mbps")
  - `SizeFormatted` on MediaPart (e.g., "4.21 GB")
  - `StreamTypeName` on MediaStream (Video, Audio, Subtitle)
- New `Format-PatBitrate` private helper for bitrate formatting

### Fixed

- Handle Plex API returning `rating` as complex object or array instead of simple value

### Changed

- Remove duplicate `StreamTypeId` property from MediaStream (use `StreamType` instead)

## [0.10.2] - 2026-01-11

### Added

- Extended `Search-PatMedia` output with 11 new properties (zero performance impact):
  - `Duration` / `DurationFormatted` - media length in milliseconds and human-readable format
  - `ContentRating` - age rating (PG-13, R, TV-MA, etc.)
  - `Rating` / `AudienceRating` - critic and audience scores
  - `Studio` - production company
  - `ViewCount` - watch count
  - `OriginallyAvailableAt` - release date
  - `ShowName`, `Season`, `Episode` - TV episode details
- New `Format-PatDuration` private helper for human-readable duration formatting

### Changed

- Refactor `Compare-PatWatchStatus` to extract helper functions for better testability:
  - `Get-WatchStatusMatchKey` - generates normalized match keys
  - `Get-PatShowEpisodes` - fetches episodes for a TV show
  - `ConvertTo-PatWatchStatusDiff` - creates standardized diff objects

## [0.10.1] - 2026-01-10

### Fixed

- Division-by-zero error in `Invoke-PatFileDownload` when downloading files with unknown size
- HTTP security warning spam - now only shows once per session instead of on every API call

### Changed

- Extract `Format-ByteSize` to standalone private function for better testability and reuse
- Improve test coverage for `Register-PatArgumentCompleter` (63% → 72%)

## [0.10.0] - 2026-01-09

### Added

- New `-ServerName` parameter on 26+ public functions for easier server targeting
  - Use stored server names instead of remembering URIs and tokens
  - Works with `Get-PatServer`, `Get-PatLibrary`, `Sync-PatMedia`, `Update-PatLibrary`, and more
  - Mutually exclusive with `-ServerUri` parameter
- New `Test-PatServer` function to validate server connectivity and authentication
- New private helper `Resolve-PatServerContext` for consistent server resolution across all functions

## [0.9.0] - 2026-01-06

### Added

- **Intelligent local network detection** for Plex servers
  - Automatically detect and prefer local connections for better performance
  - New parameters on `Add-PatServer`: `-LocalUri`, `-PreferLocal`, `-DetectLocalUri`
  - Auto-detect local URI from Plex.tv API using server's machineIdentifier
  - Automatic fallback to remote URI when local is unreachable
- New private functions for network detection:
  - `Get-PatServerConnection`: Query Plex.tv API for all server connection URIs
  - `Get-PatServerIdentity`: Get server's unique machineIdentifier
  - `Test-PatLocalNetwork`: Check if IP is in private range (RFC 1918/4193)
  - `Test-PatServerReachable`: Quick connectivity test with configurable timeout
  - `Select-PatServerUri`: Intelligent URI selection based on reachability
- Enhanced progress reporting in `Sync-PatMedia` with per-file download progress
  - Shows download speed (e.g., "1.5 GB / 4.2 GB @ 25.3 MB/s")
  - Displays estimated time remaining for each file
  - Nested progress bars: overall sync progress (parent) and current file progress (child)
- Progress reporting for watch status sync operations
- Progress reporting for playlist item removal when using `-RemoveWatched`
- New parameters on `Invoke-PatFileDownload`: `-ProgressId`, `-ProgressParentId`, `-ProgressActivity`

### Fixed

- PowerShell 5.1 compatibility for HTTPS certificate validation
  - Uses `ServerCertificateValidationCallback` on PS 5.1, `SkipCertificateCheck` on PS 6+
  - Properly restores original callback even when original was null

### Security

- TLS certificate validation skip is now opt-in via `-SkipCertificateCheck` parameter
  - Prevents man-in-the-middle attacks by default
  - Only skip for trusted local servers with self-signed certificates

## [0.8.3] - 2026-01-05

### Fixed

- Add retry logic with exponential backoff to `Invoke-PatApi` for transient network errors
  - Retries DNS failures, connection timeouts, 503/429 status codes
  - Does not retry permanent errors (401, 403, 404)
  - Default 3 retries with exponential delays (1s, 2s, 4s)
- Fix path validation in `Test-PatLibraryPath` to use correct property
  - Plex browse API returns `key` (API endpoint) and `path` (filesystem path)
  - Was incorrectly matching against `key`, now correctly uses `path`

### Added

- Integration tests for path validation using `PLEX_TEST_LIBRARY_PATH` environment variable
- CI workflow support for `PLEX_TEST_LIBRARY_PATH` secret
- Regression tests to verify `path` vs `key` property handling

## [0.8.2] - 2025-12-30

### Changed

- Refactor ArgumentCompleters to use testable helper functions
  - Extract duplicated quote handling into `ConvertFrom-PatCompleterInput` private function
  - Extract CompletionResult creation into `New-PatCompletionResult` private function
  - Remove ~430 lines of duplicated code across 15 public functions
  - Add 46 unit tests for the extracted logic

## [0.8.1] - 2025-12-29

### Fixed

- **Security**: Moved authentication tokens from URL query strings to `X-Plex-Token` header in `Invoke-PatFileDownload` and `Sync-PatMedia`
- **Security**: Changed `Remove-PatServerToken` to use `Get-SecretInfo` instead of `Get-Secret` to avoid unnecessarily exposing secret values
- **Bug**: Fixed `-Token` parameter being ignored when explicitly provided in `Sync-PatMedia`
- **Bug**: Fixed FileStream resource leak in `Invoke-PatFileDownload` with proper `try/finally` disposal pattern
- **Bug**: Fixed JSON array detection in `Invoke-PatApi` (now handles responses starting with `[`)
- **Performance**: Eliminated redundant `Get-PatMediaInfo` API calls in `Get-PatSyncPlan` by caching results

### Added

- PSScriptAnalyzer lint job in CI pipeline for early detection of code issues
- `workflow_dispatch` trigger for manual publish workflow runs
- Independent checks for GitHub release and PSGallery version in publish workflow

## [0.8.0] - 2025-12-29

### Added

- New `-Token` parameter on all cmdlets that accept `-ServerUri`, enabling explicit authentication without storing server configurations
  - Allows ad-hoc connections: `Get-PatLibrary -ServerUri "http://plex:32400" -Token $myToken`
  - Eliminates need for `Add-PatServer` when working with temporary or one-off server connections
  - Token is passed through to nested cmdlet calls for consistent authentication
  - Tab completion for library/playlist/collection names works with explicit Token
  - 21 cmdlets updated: `Add-PatCollectionItem`, `Add-PatPlaylistItem`, `Get-PatActivity`, `Get-PatLibraryChildItem`, `Get-PatLibraryItem`, `Get-PatLibraryPath`, `Get-PatMediaInfo`, `Get-PatServer`, `Get-PatSyncPlan`, `New-PatCollection`, `New-PatPlaylist`, `Remove-PatCollection`, `Remove-PatCollectionItem`, `Remove-PatPlaylist`, `Remove-PatPlaylistItem`, `Search-PatMedia`, `Stop-PatSession`, `Sync-PatMedia`, `Test-PatLibraryPath`, `Update-PatLibrary`, `Wait-PatLibraryScan`

## [0.7.0] - 2025-12-28

### Added

- New cmdlet `Search-PatMedia` for searching media items across Plex libraries
  - Full-text search via Plex's `/hubs/search` API endpoint
  - `-Query` parameter for search terms (required)
  - `-SectionName` or `-SectionId` to limit search to specific library
  - `-Type` parameter to filter by media type (movie, show, episode, artist, album, track, photo, collection)
  - `-Limit` parameter to control max results per type (default: 10)
  - Returns flattened results with Type property for easy pipeline filtering
  - Tab completion for `-SectionName` parameter
  - Returns `PlexAutomationToolkit.SearchResult` objects with RatingKey, Title, Year, Summary, LibraryId, LibraryName, and ServerUri

## [0.6.3] - 2025-12-27

### Fixed

- Fixed publish workflow permissions for automated release creation

## [0.6.2] - 2025-12-27

### Fixed

- Added platform tags to module manifest for shields.io badge compatibility

## [0.6.1] - 2025-12-27

### Added

- Status badges to README (downloads, version, CI status, platform)
- `CompatiblePSEditions` to module manifest for PSGallery platform badge

## [0.6.0] - 2025-12-27

### Changed

- Renamed cmdlets and parameters to use full words instead of abbreviations:
  - `Get-PatServerConfig` → `Get-PatServerConfiguration`
  - `Set-PatServerConfig` → `Set-PatServerConfiguration`
  - `Get-PatConfigPath` → `Get-PatConfigurationPath`
  - `Get-PatAuthHeader` → `Get-PatAuthenticationHeader`
  - `-Config` parameter → `-Configuration`
- Fixed PSScriptAnalyzer violations for improved code quality:
  - Added `SupportsShouldProcess` to `New-PatPin` and `Set-PatServerConfiguration`
  - Added `OutputType` attributes to `Compare-PatWatchStatus` and `Get-PatLibraryChildItem`
  - Replaced `Write-Host` with `Write-Information` for proper output streams
  - Fixed empty catch blocks with `Write-Debug` statements
- Updated AIM framework from 0.2.2 to 0.3.0

### Added

- New collection management cmdlets for organizing media items into collections:
  - `Get-PatCollection` - Retrieve collections from a Plex library
    - List all collections in a library or filter by ID/name
    - `-IncludeItems` switch to fetch collection contents
    - Tab completion for `-CollectionName` parameter
    - Returns `PlexAutomationToolkit.Collection` objects
  - `New-PatCollection` - Create new collections
    - Requires at least one item to create (Plex API limitation)
    - Automatically detects library type for proper collection type
    - Pipeline support for rating keys
    - `-PassThru` to return created collection
  - `Remove-PatCollection` - Delete collections
    - Remove by ID or name (with tab completion)
    - Pipeline support from Get-PatCollection
    - High confirm impact for safety
    - `-PassThru` for auditing
  - `Add-PatCollectionItem` - Add items to existing collections
    - Add by collection ID or name
    - Accepts multiple rating keys
    - Pipeline support for batch additions
  - `Remove-PatCollectionItem` - Remove items from collections
    - Uses `RatingKey` to identify items (simpler than playlists)
    - Pipeline support for batch removals
    - Works with output from `Get-PatCollection -IncludeItems`

### Notes

- Collections are library-scoped, so `LibraryId` is required when listing or searching by name
- Collection API uses simpler URI format than playlists (no machine identifier required)
- Only regular collections supported; smart collections with filters are not supported via API

## [0.5.0] - 2025-12-27

### Added

- Media sync functionality for transferring content between Plex servers via API downloads:
  - `Get-PatMediaInfo` - Retrieve detailed media metadata including file paths, sizes, and streams
    - Returns nested Media[], Part[], Streams[] structure
    - Pipeline support for rating keys
    - Identifies external subtitle streams
  - `Get-PatSyncPlan` - Analyze playlist and generate sync operations
    - Compares playlist content against destination folder
    - Calculates AddOperations[], RemoveOperations[], and space requirements
    - Detects existing files by size to skip re-downloads
    - Default playlist name is 'Travel'
    - Returns `PlexAutomationToolkit.SyncPlan` objects
  - `Sync-PatMedia` - Execute media sync from playlist to destination
    - Downloads media files with Plex-compatible folder structure
    - Subtitles included by default (use `-SkipSubtitles` to exclude)
    - Default playlist name is 'Travel' - just specify `-Destination`
    - Progress reporting for both download and removal operations
    - Space sufficiency check (override with `-Force`)
    - Supports `-WhatIf`, `-Confirm`, and `-PassThru`
    - Resume support for interrupted downloads
- Watch status synchronization between Plex servers:
  - `Compare-PatWatchStatus` - Compare watch status between two servers
    - Matches movies by title and year
    - Matches TV episodes by show name, season, and episode number
    - Filter with `-WatchedOnSourceOnly` or `-WatchedOnTargetOnly`
    - Returns `PlexAutomationToolkit.WatchStatusDiff` objects
  - `Sync-PatWatchStatus` - Apply watched status from source to target server
    - Uses Plex scrobble endpoint to mark items as watched
    - Supports `-SectionId` filter for targeted sync
    - Supports `-WhatIf`, `-Confirm`, and `-PassThru`
    - Returns `PlexAutomationToolkit.WatchStatusSyncResult` objects
- New private helper functions:
  - `Get-PatSafeFilename` - Sanitize strings for filesystem compatibility
  - `Get-PatMediaPath` - Generate Plex-compatible destination paths
  - `Invoke-PatFileDownload` - Binary file download with progress and resume support

### Notes

- Media sync uses Plex API for downloads (no SMB/path mapping required)
- Folder structure follows Plex conventions: `Movies/Title (Year)/` and `TV Shows/Show/Season ##/`
- Server configurations stored with `Add-PatServer` are used for cross-server operations

## [0.4.0] - 2025-12-26

### Added

- New playlist management cmdlets for creating, managing, and deleting playlists:
  - `Get-PatPlaylist` - Retrieve playlists from a Plex server
    - List all playlists or filter by ID/name
    - `-IncludeItems` switch to fetch playlist contents
    - Tab completion for `-PlaylistName` parameter
    - Returns `PlexAutomationToolkit.Playlist` objects
  - `New-PatPlaylist` - Create new playlists
    - Specify playlist title and type (video, audio, photo)
    - Optionally add initial items via `-RatingKey` parameter
    - Pipeline support for rating keys
    - `-PassThru` to return created playlist
  - `Remove-PatPlaylist` - Delete playlists
    - Remove by ID or name (with tab completion)
    - Pipeline support from Get-PatPlaylist
    - High confirm impact for safety
    - `-PassThru` for auditing
  - `Add-PatPlaylistItem` - Add items to existing playlists
    - Add by playlist ID or name
    - Accepts multiple rating keys
    - Pipeline support for batch additions
  - `Remove-PatPlaylistItem` - Remove items from playlists
    - Uses `PlaylistItemId` (distinct from media `RatingKey`)
    - Pipeline support from playlist items
    - Works with output from `Get-PatPlaylist -IncludeItems`

### Notes

- Playlist cmdlets work with regular (non-smart) playlists only
- Smart playlists are automatically filtered out as they have limited API support for modifications

## [0.3.0] - 2025-12-26

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
- Private helper function `Get-PatAuthenticationHeader` for centralized authentication header management
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
