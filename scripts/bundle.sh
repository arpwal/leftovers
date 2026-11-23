#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) release binary and wraps it in
# build/Leftovers.app. Signing is a separate step (scripts/sign.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env

BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_ARGS[@]}"
# Ask SwiftPM where it put the products: newer toolchains moved them from
# .build/apple to .build/out, and a hard-coded path silently shipped a stale binary.
PRODUCTS="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BIN="$PRODUCTS/Leftovers"

APP="build/Leftovers.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Leftovers"
# The fseventsd helper: a root launchd daemon the app registers with
# SMAppService.daemon; its plist must live in Contents/Library/LaunchDaemons.
cp "$PRODUCTS/LeftoversHelper" "$APP/Contents/MacOS/LeftoversHelper"
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cp packaging/LaunchDaemons/com.arpwal.leftovers.helper.plist "$APP/Contents/Library/LaunchDaemons/"
plutil -lint "$APP/Contents/Library/LaunchDaemons/com.arpwal.leftovers.helper.plist" >/dev/null
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Sparkle (updates) is linked dynamically; the binary's rpath points here.
mkdir -p "$APP/Contents/Frameworks"
ditto "$PRODUCTS/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
sed -e "s|__BUNDLE_ID__|$BUNDLE_ID|" -e "s|__VERSION__|$VERSION|" \
    -e "s|__BUILD__|$BUILD|" -e "s|__COPYRIGHT__|$COPYRIGHT|" \
    packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
echo "Bundled $APP ($(lipo -archs "$APP/Contents/MacOS/Leftovers"))"
