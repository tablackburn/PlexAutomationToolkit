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

PlexAutomationToolkit provides a comprehensive set of cmdlets for automating Plex server management tasks, including server configuration, library operations, and content browsing. Whether you're managing a single server or multiple Plex instances, this module simplifies common automation workflows.

## Features

- **Server Management**: Add, remove, and configure multiple Plex server connections with default server support
- **Authentication Support**: Optional X-Plex-Token authentication for secured servers
- **Library Operations**:
  - List and query library sections
  - Refresh entire libraries or specific paths
  - Browse library content and resolve filesystem paths
  - Tab completion for library names and paths
- **Pipeline Support**: All cmdlets follow PowerShell conventions for pipeline operations
- **Error Handling**: Consistent error messages with `-WhatIf` and `-Confirm` support for destructive operations

## Requirements

- PowerShell 5.1 or higher
- Network access to your Plex Media Server
- Plex authentication token (optional, for secured servers)

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name PlexAutomationToolkit -Scope CurrentUser
```

### From Source

```powershell
# Clone the repository
git clone https://github.com/tablackburn/PlexAutomationToolkit.git
cd PlexAutomationToolkit

# Install build dependencies
./build.ps1 -Bootstrap

# Build and test the module
./build.ps1 -Task Test

# Import the built module
Import-Module ./Output/PlexAutomationToolkit/0.1.0/PlexAutomationToolkit.psd1
```

## Quick Start

### 1. Add Your Plex Server

```powershell
# Add server without authentication (local network)
Add-PatServer -Name "Main Server" -ServerUri "http://plex.local:32400" -Default

# Add server with authentication token
Add-PatServer -Name "Remote Server" -ServerUri "http://plex.example.com:32400" -Token "YOUR_TOKEN_HERE" -Default
```

### 2. List Library Sections

```powershell
# Get all libraries from default server
Get-PatLibrary

# Get specific library section
Get-PatLibrary -SectionId 1
```

### 3. Refresh a Library

```powershell
# Refresh entire library by ID
Update-PatLibrary -SectionId 2

# Refresh entire library by name (with tab completion!)
Update-PatLibrary -SectionName "Movies"

# Refresh specific path within a library
Update-PatLibrary -SectionName "Movies" -Path "/mnt/media/Movies/New Releases"
```

## Examples

### Server Management

```powershell
# Add multiple servers
Add-PatServer -Name "Main" -ServerUri "http://192.168.1.100:32400" -Default
Add-PatServer -Name "Remote" -ServerUri "https://remote.example.com:32400" -Token "abc123"

# List configured servers
Get-PatStoredServer

# Get only the default server
Get-PatStoredServer -Default

# Change default server
Set-PatDefaultServer -Name "Remote"

# Remove a server
Remove-PatServer -Name "Main"
```

### Getting Server Information

```powershell
# Get server identity and capabilities
Get-PatServer -ServerUri "http://plex.local:32400"

# Get server info from default configured server
Get-PatServer
```

### Library Operations

```powershell
# List all library sections
$libraries = Get-PatLibrary
$libraries.Directory | Select-Object title, type, key

# Get library root paths
Get-PatLibraryPath -SectionId 1

# Browse library content by path
Get-PatLibraryChildItem -Path "/mnt/media/Movies"

# Browse library content by section
Get-PatLibraryChildItem -SectionId 1
Get-PatLibraryChildItem -SectionName "TV Shows"

# Refresh entire library
Update-PatLibrary -SectionId 2 -Confirm:$false

# Refresh specific path (useful after adding new media)
Update-PatLibrary -SectionName "Movies" -Path "/mnt/media/Movies/Action"

# Use -WhatIf to preview changes
Update-PatLibrary -SectionId 1 -WhatIf
```

### Working with Multiple Servers

```powershell
# Query specific server (overrides default)
Get-PatLibrary -ServerUri "http://other-server:32400"

# Refresh library on specific server
Update-PatLibrary -ServerUri "http://other-server:32400" -SectionId 1

# Get server info without adding to configuration
Get-PatServer -ServerUri "http://test-server:32400"
```

### Tab Completion Features

The module provides intelligent tab completion for common parameters:

```powershell
# Tab completion for library section names
Update-PatLibrary -SectionName <TAB>
# Shows: "Movies", "TV Shows", "Music", etc.

# Tab completion for library paths
Update-PatLibrary -SectionName "Movies" -Path <TAB>
# Shows root paths and subdirectories as you type
```

## Authentication

### When is Authentication Required?

Plex authentication is **optional** if your server allows unauthenticated local network access (default for most local setups). However, tokens are required for:

- Remote access (outside your local network)
- Servers configured to require authentication
- Accessing shared servers

See [Plex documentation on local network authentication](https://support.plex.tv/articles/200890058) for details.

### Obtaining Your Plex Token

Use the built-in helper cmdlet:

```powershell
# Quick instructions
Get-PatToken

# Detailed step-by-step guide
Get-PatToken -ShowInstructions
```

Or follow these steps:

1. Open https://app.plex.tv in your browser
2. Navigate to any media item
3. Click the three-dot menu (...) and select "Get Info"
4. Click "View XML" at the bottom
5. Look for `X-Plex-Token` in the URL
6. Copy the token value after `X-Plex-Token=`

Official guide: https://support.plex.tv/articles/204059436

### Using Tokens

```powershell
# Add server with token
Add-PatServer -Name "MyServer" -ServerUri "http://plex.local:32400" -Token "YOUR_TOKEN_HERE" -Default
```

### Security Warning

**IMPORTANT**: Tokens are stored in **PLAINTEXT** in `servers.json`:
- Windows: `%USERPROFILE%\Documents\PlexAutomationToolkit\servers.json`
- Or: `%OneDrive%\Documents\PlexAutomationToolkit\servers.json`

Your Plex token grants **full access** to your Plex account. Best practices:
- Only use on trusted systems
- Never commit `servers.json` to source control
- Never share your token publicly
- Set appropriate file permissions on `servers.json`
- Revoke tokens by changing your Plex password if compromised

## Development

### Running Tests

```powershell
# Run all tests (manifest, help, meta, and integration tests)
./build.ps1 -Task Test

# Run only unit tests
Invoke-Pester -Path tests/Unit/

# Run specific test file
Invoke-Pester -Path tests/Help.tests.ps1
```

### Integration Tests

Integration tests verify functionality against a live Plex server:

1. Copy the example settings file:
   ```powershell
   Copy-Item tests/local.settings.example.ps1 tests/local.settings.ps1
   ```

2. Edit `tests/local.settings.ps1` with your server details:
   ```powershell
   $env:PLEX_SERVER_URI = "http://192.168.1.100:32400"
   $env:PLEX_TOKEN = "YOUR_TOKEN_HERE"
   ```

3. Load settings and run tests:
   ```powershell
   . ./tests/local.settings.ps1
   ./build.ps1 -Task Test
   ```

Integration tests are automatically skipped if environment variables are not configured.

See `tests/Integration/README.md` for detailed setup instructions.

### Build Tasks

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

## Command Reference

| Cmdlet | Description |
|--------|-------------|
| `Add-PatServer` | Add a Plex server to configuration |
| `Remove-PatServer` | Remove a server from configuration |
| `Set-PatDefaultServer` | Set the default server |
| `Get-PatStoredServer` | Get configured server(s) |
| `Get-PatServer` | Get server identity and capabilities |
| `Get-PatToken` | Display instructions for obtaining authentication token |
| `Get-PatLibrary` | List library sections |
| `Get-PatLibraryPath` | Get library root filesystem paths |
| `Get-PatLibraryChildItem` | Browse library content by path or section |
| `Update-PatLibrary` | Refresh a library section |

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
5. Follow existing code conventions (see `CLAUDE.md`)
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
