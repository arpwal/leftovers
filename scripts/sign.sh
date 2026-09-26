#!/usr/bin/env bash
# Signs build/Leftovers.app with the Developer ID in packaging/release.env,
# using the hardened runtime and a secure timestamp — both required for
# notarization. Set SIGNING_IDENTITY=- for a local ad-hoc build.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
IDENTITY="${SIGNING_IDENTITY_OVERRIDE:-$SIGNING_IDENTITY}"
APP="build/Leftovers.app"

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  # Inside-out, as Sparkle documents: helpers first, then the framework, then the app.
  SIGN=(codesign --force --options runtime --timestamp --sign "$IDENTITY")
  "${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
  "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
  "${SIGN[@]}" "$SPARKLE/Autoupdate"
  "${SIGN[@]}" "$SPARKLE/Updater.app"
  "${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
  "${SIGN[@]}" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer|TeamIdentifier|Runtime" || true
