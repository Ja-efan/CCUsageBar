#!/usr/bin/env bash
# Builds and installs to ~/Applications, then (re)launches the app.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Noonchi 2>/dev/null || true
# Replace the app from before the rename (CCUsageBar), if installed.
pkill -x CCUsageBar 2>/dev/null || true
rm -rf "$DEST/CCUsageBar.app"
rm -rf "$DEST/Noonchi.app"
cp -R dist/Noonchi.app "$DEST/"
xattr -dr com.apple.quarantine "$DEST/Noonchi.app" 2>/dev/null || true
open "$DEST/Noonchi.app"
echo "Installed to $DEST/Noonchi.app"
