#!/usr/bin/env bash
# Builds and installs to ~/Applications, then (re)launches the app.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x CCUsageBar 2>/dev/null || true
rm -rf "$DEST/CCUsageBar.app"
cp -R dist/CCUsageBar.app "$DEST/"
xattr -dr com.apple.quarantine "$DEST/CCUsageBar.app" 2>/dev/null || true
open "$DEST/CCUsageBar.app"
echo "Installed to $DEST/CCUsageBar.app"
