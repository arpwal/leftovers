#!/usr/bin/env bash
# Builds dist/Leftovers.dmg from build/Leftovers.app with the designed
# drag-to-Applications window (packaging/dmg/), then signs it with the
# Developer ID. Run after the app is stapled.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
VENV=.build/dmg-venv
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q -r packaging/dmg/requirements.txt
fi
mkdir -p dist
rm -f dist/Leftovers.dmg
"$VENV/bin/dmgbuild" -s packaging/dmg/settings.py -D app=build/Leftovers.app "Leftovers" dist/Leftovers.dmg >/dev/null
codesign --force --timestamp --sign "$SIGNING_IDENTITY" dist/Leftovers.dmg
echo "Built and signed dist/Leftovers.dmg"
