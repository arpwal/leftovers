#!/usr/bin/env bash
# Builds dist/Leftovers.dmg (drag-to-Applications) from build/Leftovers.app
# and signs it with the Developer ID. Run after the app is stapled.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
cp -R build/Leftovers.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
hdiutil create -volname "Leftovers" -srcfolder "$STAGE" -ov -format UDZO dist/Leftovers.dmg >/dev/null
codesign --force --timestamp --sign "$SIGNING_IDENTITY" dist/Leftovers.dmg
echo "Built and signed dist/Leftovers.dmg"
