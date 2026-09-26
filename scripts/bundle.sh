#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) release binary and wraps it in
# build/Leftovers.app. Signing is a separate step (scripts/sign.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env

swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release/Leftovers"

APP="build/Leftovers.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Leftovers"
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Sparkle (updates) is linked dynamically; the binary's rpath points here.
mkdir -p "$APP/Contents/Frameworks"
ditto ".build/apple/Products/Release/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
sed -e "s|__BUNDLE_ID__|$BUNDLE_ID|" -e "s|__VERSION__|$VERSION|" \
    -e "s|__BUILD__|$BUILD|" -e "s|__COPYRIGHT__|$COPYRIGHT|" \
    packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
echo "Bundled $APP ($(lipo -archs "$APP/Contents/MacOS/Leftovers"))"
