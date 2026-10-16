# PurgeMac

A native macOS system cleanup utility, built with pure Swift and AppKit. Clean up system junk, caches, and unnecessary files with ease.

## Features

- **System Cleanup**: Remove system caches, logs, and temporary files
- **User Cache Cleanup**: Clean user application caches and preferences
- **Trash Management**: Empty trash with secure deletion options
- **Large File Finder**: Identify and remove large files taking up space
- **Duplicate File Detection**: Find and remove duplicate files
- **Startup Items Management**: Control login items and startup agents
- **Menu Bar Integration**: Quick access from the menu bar
- **Safe Mode**: Preview changes before applying them

## Requirements

- **macOS 13.0 (Ventura) or later**
- Full disk access permission (for system cleanup)
- Administrator privileges (for some system-level operations)

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
./build.sh
open PurgeMac.app
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

PurgeMac uses [Sparkle](https://sparkle-project.org/) for automatic updates. The app checks for updates on launch and can download and install them automatically.

## Project Home

https://github.com/J-Liu/PurgeMac

## License

This project is licensed under the Apache License 2.0.
See [LICENSE](LICENSE) for details.

Copyright © 2026 Jia Liu.
