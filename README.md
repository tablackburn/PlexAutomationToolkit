# PlexAutomationToolkit

[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PlexAutomationToolkit)](https://www.powershellgallery.com/packages/PlexAutomationToolkit/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PlexAutomationToolkit)](https://www.powershellgallery.com/packages/PlexAutomationToolkit/)
[![CI](https://img.shields.io/github/actions/workflow/status/tablackburn/PlexAutomationToolkit/CI.yaml?branch=main)](https://github.com/tablackburn/PlexAutomationToolkit/actions/workflows/CI.yaml)
[![codecov](https://codecov.io/gh/tablackburn/PlexAutomationToolkit/graph/badge.svg)](https://codecov.io/gh/tablackburn/PlexAutomationToolkit)
![Platform](https://img.shields.io/powershellgallery/p/PlexAutomationToolkit)
[![AI Assisted](https://img.shields.io/badge/AI-Assisted-blue)](https://claude.ai)
[![License](https://img.shields.io/github/license/tablackburn/PlexAutomationToolkit)](LICENSE)

A PowerShell module for managing Plex Media Servers through automation and scripting.

## Overview

PlexAutomationToolkit provides a comprehensive set of cmdlets for automating Plex server management tasks, including server configuration, library operations, media syncing, and content browsing. Whether you're managing a single server or multiple Plex instances, this module simplifies common automation workflows.

## Features

- **Server Management**: Add, remove, and configure multiple Plex server connections with default server support
- **Authentication**: X-Plex-Token authentication with secure vault storage via SecretManagement
- **Local Network Detection**: Automatically detect and prefer local connections for better performance with automatic fallback to remote
- **Library Operations**:
  - List and query library sections
  - Refresh entire libraries or specific paths
  - Browse library content and resolve filesystem paths
  - Compare library content before and after scans
  - Tab completion for library names and paths
- **Media Operations**:
  - Search media across all libraries
  - Get detailed media info (codecs, bitrate, resolution)
  - Sync media from playlists to local folders with progress reporting
- **Watch Status**: Compare and sync watch status between multiple Plex servers
- **Collections**: Create, modify, and delete library collections
- **Playlists**: Create, modify, and delete playlists with sync planning
- **Session Management**: Monitor active sessions and terminate playback
- **Pipeline Support**: All cmdlets follow PowerShell conventions for pipeline operations
- **Error Handling**: Consistent error messages with `-WhatIf` and `-Confirm` support for destructive operations

## Requirements

- PowerShell 5.1 or higher
- Network access to your Plex Media Server
- Plex authentication token (optional, for secured servers)

## Installation

### From PowerShell Gallery (recommended)

```powershell
Install-Module -Name PlexAutomationToolkit -Scope CurrentUser
```

### From source

```powershell
# Clone the repository
git clone https://github.com/tablackburn/PlexAutomationToolkit.git
cd PlexAutomationToolkit

# Install build dependencies
./build.ps1 -Bootstrap

# Build and test the module
./build.ps1 -Task Test

# Import the built module
Import-Module './Output/PlexAutomationToolkit/0.1.0/PlexAutomationToolkit.psd1'
```

## Quick Start

### 1. Add your Plex server

```powershell
# Add server without authentication (local network)
Add-PatServer -Name 'Main Server' -ServerUri 'http://plex.local:32400' -Default

# Add server with authentication token
Add-PatServer -Name 'Remote Server' -ServerUri 'http://plex.example.com:32400' -Token 'YOUR_TOKEN_HERE' -Default

# Add server with local network detection (auto-selects fastest connection)
Add-PatServer -Name 'Smart Server' -ServerUri 'https://remote.example.com:32400' -Token 'YOUR_TOKEN' -DetectLocalUri -PreferLocal -Default
```

### 2. List library sections

```powershell
# Get all libraries from default server
Get-PatLibrary

# Get libraries using server name
Get-PatLibrary -ServerName 'Main Server'

# Get specific library section
Get-PatLibrary -SectionId 1
```

### 3. Refresh a library

```powershell
# Refresh entire library by ID
Update-PatLibrary -SectionId 2

# Refresh entire library by name (with tab completion)
Update-PatLibrary -SectionName 'Movies'

# Refresh specific path within a library
Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/New Releases'
```

## Examples

### Server management

```powershell
# Add multiple servers
Add-PatServer -Name 'Main' -ServerUri 'http://192.168.1.100:32400' -Default
Add-PatServer -Name 'Remote' -ServerUri 'https://remote.example.com:32400' -Token 'abc123'

# List configured servers
Get-PatStoredServer

# Get only the default server
Get-PatStoredServer -Default

# Test server connectivity
Test-PatServer -ServerName 'Main'

# Change default server
Set-PatDefaultServer -Name 'Remote'

# Remove a server
Remove-PatServer -Name 'Main'
```

### Getting server information

```powershell
# Get server identity and capabilities
Get-PatServer -ServerUri 'http://plex.local:32400'

# Get server info using stored server name
Get-PatServer -ServerName 'Main'

# Get server info from default configured server
Get-PatServer
```

### Library operations

```powershell
# List all library sections
$libraries = Get-PatLibrary
$libraries.Directory | Select-Object -Property title, type, key

# Get library root paths
Get-PatLibraryPath -SectionId 1

# Browse library content by path
Get-PatLibraryChildItem -Path '/mnt/media/Movies'

# Browse library content by section
Get-PatLibraryChildItem -SectionId 1
Get-PatLibraryChildItem -SectionName 'TV Shows'

# Refresh entire library
Update-PatLibrary -SectionId 2 -Confirm:$false

# Refresh specific path (useful after adding new media)
Update-PatLibrary -SectionName 'Movies' -Path '/mnt/media/Movies/Action'

# Wait for library scan to complete
Update-PatLibrary -SectionName 'Movies'
Wait-PatLibraryScan -SectionName 'Movies'
```

### Searching media

```powershell
# Search for media by title
Search-PatMedia -Query 'Inception'

# Search within a specific library
Search-PatMedia -Query 'Breaking Bad' -SectionName 'TV Shows'

# Get detailed media information
Get-PatMediaInfo -RatingKey 12345
```

### Syncing media

```powershell
# Generate a sync plan from a playlist
Get-PatSyncPlan -PlaylistName 'Offline Viewing' -Destination 'D:\PlexSync'

# Sync media from playlist to local folder
Sync-PatMedia -PlaylistName 'Offline Viewing' -Destination 'D:\PlexSync'

# Sync with progress reporting
Sync-PatMedia -PlaylistName 'Travel Movies' -Destination 'E:\Movies' -Verbose
```

### Watch status sync

```powershell
# Compare watch status between two servers
Compare-PatWatchStatus -SourceServerName 'Main' -TargetServerName 'Remote' -SectionName 'Movies'

# Sync watch status from one server to another
Sync-PatWatchStatus -SourceServerName 'Main' -TargetServerName 'Remote' -SectionName 'Movies'

# Sync watch status for TV shows
Sync-PatWatchStatus -SourceServerName 'Main' -TargetServerName 'Remote' -SectionName 'TV Shows'
```

### Collection management

```powershell
# List collections in a library
Get-PatCollection -SectionName 'Movies'

# Create a new collection
New-PatCollection -SectionName 'Movies' -Title 'Marvel Universe'

# Add items to a collection
Add-PatCollectionItem -CollectionId 12345 -RatingKey 67890

# Remove a collection
Remove-PatCollection -CollectionId 12345
```

### Playlist management

```powershell
# List all playlists
Get-PatPlaylist

# Create a new playlist
New-PatPlaylist -Title 'Weekend Watchlist' -PlaylistType 'video'

# Add items to a playlist
Add-PatPlaylistItem -PlaylistId 12345 -RatingKey 67890

# Remove a playlist
Remove-PatPlaylist -PlaylistId 12345
```

### Session management

```powershell
# View current activity
Get-PatActivity

# List active playback sessions
Get-PatSession

# Stop a specific session
Stop-PatSession -SessionId 'abc123'
```

### Working with multiple servers

```powershell
# Query specific server using -ServerName (recommended)
Get-PatLibrary -ServerName 'Remote'

# Query specific server using URI (overrides default)
Get-PatLibrary -ServerUri 'http://other-server:32400'

# Refresh library on specific server
Update-PatLibrary -ServerName 'Remote' -SectionId 1
```

### Tab completion features

The module provides intelligent tab completion for common parameters:

```powershell
# Tab completion for library section names
Update-PatLibrary -SectionName <TAB>
# Shows: "Movies", "TV Shows", "Music", etc.

# Tab completion for library paths
Update-PatLibrary -SectionName 'Movies' -Path <TAB>
# Shows root paths and subdirectories as you type

# Tab completion for server names
Get-PatLibrary -ServerName <TAB>
# Shows: "Main", "Remote", etc.
```

## Authentication

### When is authentication required?

Plex authentication is **optional** if your server allows unauthenticated local network access (default for most local setups). However, tokens are required for:

- Remote access (outside your local network)
- Servers configured to require authentication
- Accessing shared servers

See [Plex documentation on local network authentication](https://support.plex.tv/articles/200890058) for details.

### Obtaining your Plex token

Use the built-in helper cmdlet:

```powershell
# Quick instructions
Get-PatToken

# Detailed step-by-step guide
Get-PatToken -ShowInstructions

# Or authenticate interactively (prompts for credentials)
Connect-PatAccount
```

Or follow these steps:

1. Open https://app.plex.tv in your browser
2. Navigate to any media item
3. Click the three-dot menu (...) and select "Get Info"
4. Click "View XML" at the bottom
5. Look for `X-Plex-Token` in the URL
6. Copy the token value after `X-Plex-Token=`

Official guide: https://support.plex.tv/articles/204059436

### Using tokens

```powershell
# Add server with token
Add-PatServer -Name 'MyServer' -ServerUri 'http://plex.local:32400' -Token 'YOUR_TOKEN_HERE' -Default

# Migrate plaintext tokens to secure vault (requires SecretManagement module)
Import-PatServerToken
```

### Security warning

**IMPORTANT**: Tokens are stored in **PLAINTEXT** in `servers.json` by default:

- Windows: `%USERPROFILE%\Documents\PlexAutomationToolkit\servers.json`
- Or: `%OneDrive%\Documents\PlexAutomationToolkit\servers.json`

Your Plex token grants **full access** to your Plex account. Best practices:

- Use `Import-PatServerToken` to migrate tokens to SecretManagement vault
- Only use on trusted systems
- Never commit `servers.json` to source control
- Never share your token publicly
- Set appropriate file permissions on `servers.json`
- Revoke tokens by changing your Plex password if compromised

## Development

### Running tests

```powershell
# Run all tests (manifest, help, meta, and integration tests)
./build.ps1 -Task Test

# Run only unit tests
Invoke-Pester -Path 'tests/Unit/'

# Run specific test file
Invoke-Pester -Path 'tests/Help.tests.ps1'
```

### Integration tests

Integration tests verify functionality against a live Plex server:

1. Copy the example settings file:

   ```powershell
   Copy-Item -Path 'tests/local.settings.example.ps1' -Destination 'tests/local.settings.ps1'
   ```

2. Edit `tests/local.settings.ps1` with your server details:

   ```powershell
   $env:PLEX_SERVER_URI = 'http://192.168.1.100:32400'
   $env:PLEX_TOKEN = 'YOUR_TOKEN_HERE'
   ```

3. Load settings and run tests:

   ```powershell
   . ./tests/local.settings.ps1
   ./build.ps1 -Task Test
   ```

Integration tests are automatically skipped if environment variables are not configured.

See `tests/Integration/README.md` for detailed setup instructions.

### Build tasks

```powershell
# List available build tasks
./build.ps1 -Help

# Install build dependencies
./build.ps1 -Bootstrap

# Build module
./build.ps1 -Task Build

# Run tests
./build.ps1 -Task Test

# Clean output directory
./build.ps1 -Task Clean
```

## Command reference

| Category | Cmdlets | Description |
|----------|---------|-------------|
| Server Management | 10 | Add, remove, configure, and test server connections |
| Library Operations | 8 | Browse, refresh, and compare library content |
| Media Operations | 3 | Search, get details, and sync media files |
| Watch Status | 2 | Compare and sync watch status between servers |
| Collections | 5 | Create and manage library collections |
| Playlists | 6 | Create and manage playlists, generate sync plans |
| Sessions/Activity | 3 | Monitor and manage active playback sessions |

For a complete list of cmdlets:

```powershell
Get-Command -Module PlexAutomationToolkit
```

For detailed help on any cmdlet:

```powershell
Get-Help Add-PatServer -Full
Get-Help Update-PatLibrary -Examples
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass (`./build.ps1 -Task Test`)
5. Follow existing code conventions (see `AGENTS.md`)
6. Submit a pull request

## Versioning

This project follows [Semantic Versioning](http://semver.org/). See [CHANGELOG.md](CHANGELOG.md) for release history.

## Acknowledgments

This project was developed with assistance from [Claude](https://claude.ai) by Anthropic.

## License

Copyright (c) Trent Blackburn. All rights reserved.

See [LICENSE](LICENSE) for license information.

## Resources

- **GitHub Repository**: https://github.com/tablackburn/PlexAutomationToolkit
- **Plex API Documentation**: https://support.plex.tv/articles/201638786-plex-media-server-url-commands/
- **Finding Your Token**: https://support.plex.tv/articles/204059436
- **Local Network Auth**: https://support.plex.tv/articles/200890058
