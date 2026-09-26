#!/usr/bin/env bash
# Full release: bundle → sign → notarize + staple (app and DMG) → cask.
# Publishing is separate and manual:
#   gh release create v$VERSION dist/Leftovers.dmg dist/Leftovers.zip dist/SHA256SUMS
set -euo pipefail
cd "$(dirname "$0")"
./bundle.sh
./sign.sh
./notarize.sh
./update-cask.sh
