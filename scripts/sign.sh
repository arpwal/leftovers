#!/usr/bin/env bash
# Signs build/Leftovers.app with the Developer ID in packaging/release.env,
# using the hardened runtime and a secure timestamp — both required for
# notarization. Set SIGNING_IDENTITY=- for a local ad-hoc build.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
IDENTITY="${SIGNING_IDENTITY_OVERRIDE:-$SIGNING_IDENTITY}"
APP="build/Leftovers.app"

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer|TeamIdentifier|Runtime" || true
