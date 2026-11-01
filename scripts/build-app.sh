#!/usr/bin/env bash
# Builds a release binary and packages it into dist/CCUsageBar.app (+ zip).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="dist/CCUsageBar.app"

swift build -c release --arch arm64 ${SWIFT_BUILD_FLAGS:-}
BIN="$(swift build -c release --arch arm64 --show-bin-path ${SWIFT_BUILD_FLAGS:-})/CCUsageBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/CCUsageBar"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# Ad-hoc signature (local use). Set SIGN_IDENTITY for a Developer ID build.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"

(cd dist && rm -f "CCUsageBar-$VERSION.zip" && ditto -c -k --keepParent CCUsageBar.app "CCUsageBar-$VERSION.zip")
echo "Built $APP (v$VERSION, build $BUILD)"
