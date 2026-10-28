# PurgeMac

A native macOS system cleanup utility, built with pure Swift and AppKit. Clean up system junk, caches, and unnecessary files with ease.

## Features

### App Uninstaller
- Uninstall applications with one click
- Automatically finds and removes related files (caches, preferences, logs, etc.)
- Preview leftover files before deletion

### System Junk Cleanup
- **User Caches**: Clean application caches
- **Logs & Errors**: Remove log files and crash reports
- **App Leftovers**: Find and clean orphaned files from uninstalled apps
- **Large Files**: Identify large files taking up space
- **Trash**: Empty the trash

### Developer Junk Cleanup
- **Xcode**: Derived data, archives, device logs, simulators
- **Homebrew**: Cache and old versions
- **Node.js**: npm/yarn caches, node_modules
- **Python**: pip cache, __pycache__, virtualenvs
- **Rust**: Cargo cache, target directories
- **Go**: Go modules cache
- **JetBrains**: IDE caches and logs
- **VS Code**: Extensions cache
- **Containers**: Docker and container caches

## Requirements

- **macOS 13.0 (Ventura) or later**
- Full disk access permission (for system cleanup)

## Installation

1. Download the latest `PurgeMac.zip` from the [Releases](https://github.com/J-Liu/PurgeMac/releases) page.
2. Unzip and drag `PurgeMac.app` to `/Applications`.
3. Because the app is not code-signed, macOS Gatekeeper will block it on first launch.

### Bypassing Gatekeeper

**Option A — Terminal (fast):**

```bash
xattr -dr com.apple.quarantine /Applications/PurgeMac.app
```

Then double-click the app.

**Option B — Finder (graphical):**

1. Right-click (or Control-click) `PurgeMac.app`.
2. Choose **Open**.
3. Click **Open** again in the warning dialog.

After doing this once, the app opens normally.

## Build from Source

```bash
git clone https://github.com/J-Liu/PurgeMac.git
cd PurgeMac
swift build -c release
open .build/out/Products/Release/PurgeMac.app
```

Requires Swift 5.9+ and Xcode command line tools.

## CLI Usage

PurgeMac includes a command-line interface:

```bash
# Run from the app bundle
/Applications/PurgeMac.app/Contents/MacOS/PurgeMacCLI --help

# Or use the standalone binary
./PurgeMacCLI --help
```

## Automatic Updates

PurgeMac uses [Sparkle](https://sparkle-project.org/) for automatic updates. Configure update frequency in Settings:
- At Startup
- Daily
- Weekly (default)
- Monthly
- Never

Manual update checks are always available from the menu or Settings.

## Project Home

https://github.com/J-Liu/PurgeMac

## License

This project is licensed under the GNU Affero General Public License v3.0 or later.
See [LICENSE](LICENSE) for details.

Copyright © 2026 Jia Liu.