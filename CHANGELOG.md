# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [0.6.0] - 2025-12-27

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
