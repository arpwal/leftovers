#!/usr/bin/env bash
# Downloads the latest release the way a user would and checks the checksum
# and Gatekeeper verdict.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -sSL -o "$TMP/Leftovers.dmg" https://github.com/arpwal/leftovers/releases/latest/download/Leftovers.dmg
EXPECTED=$(grep Leftovers.dmg dist/SHA256SUMS | cut -d' ' -f1)
ACTUAL=$(shasum -a 256 "$TMP/Leftovers.dmg" | cut -d' ' -f1)
[ "$EXPECTED" = "$ACTUAL" ] || { echo "Checksum mismatch: $ACTUAL"; exit 1; }
spctl --assess --type open --context context:primary-signature "$TMP/Leftovers.dmg"
echo "Latest download matches this build and passes Gatekeeper"
