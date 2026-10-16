#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
# Builds the release executable and assembles a signed PurgeMac.app bundle.
# Override CODE_SIGN_IDENTITY to use a non-ad-hoc signing identity.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="PurgeMac"
EXECUTABLE_NAME="PurgeMacGUI"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

# Build the release executable.
swift build -c "$CONFIGURATION"

BIN_DIR="$ROOT_DIR/.build/$CONFIGURATION"
EXECUTABLE="$BIN_DIR/$EXECUTABLE_NAME"

# Assemble the standard macOS app bundle directory layout.
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Embed the Sparkle framework so updates work in a distributed bundle.
SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -type d -name 'Sparkle.framework' -print -quit 2>/dev/null || true)"
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

# Sign the bundle. For local testing, an ad-hoc signature is sufficient.
# For distribution, set CODE_SIGN_IDENTITY and then notarize the app.
IDENTITY="${CODE_SIGN_IDENTITY:--}"
codesign --force --deep --sign "$IDENTITY" "$APP_DIR"

echo "Built $APP_DIR"
