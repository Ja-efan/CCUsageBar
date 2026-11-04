#!/usr/bin/env bash
# Builds and installs to ~/Applications, then (re)launches the app.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Noonchi 2>/dev/null || true
for _ in $(seq 1 30); do pgrep -x Noonchi >/dev/null || break; sleep 0.1; done
# Replace the app from before the rename (CCUsageBar), if installed.
pkill -x CCUsageBar 2>/dev/null || true
rm -rf "$DEST/CCUsageBar.app"
rm -rf "$DEST/Noonchi.app"
cp -R dist/Noonchi.app "$DEST/"
xattr -dr com.apple.quarantine "$DEST/Noonchi.app" 2>/dev/null || true
# Launch Services can refuse (-600) right after the old app quits.
for attempt in 1 2 3 4 5; do
  open "$DEST/Noonchi.app" 2>/dev/null && break
  [ "$attempt" = 5 ] && { echo "Couldn't launch $DEST/Noonchi.app; open it from Finder." >&2; exit 1; }
  sleep 1
done
echo "Installed to $DEST/Noonchi.app"
