#!/usr/bin/env bash
# Full release: bundle → sign (Developer ID) → notarize → staple → dist/.
# Publishing to GitHub is a separate, manual step:
#   gh release create v$VERSION dist/MemoryJanitor-$VERSION.zip dist/*.sha256
set -euo pipefail
cd "$(dirname "$0")"
./bundle.sh
./sign.sh
./notarize.sh
