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

# The update feed: GitHub Pages sometimes skips a build when pushes land
# close together, which would leave existing installs on the old version.
# Ask for a build, wait until the live feed lists this version, then check
# its signature against the live zip.
source packaging/release.env
gh api -X POST repos/arpwal/leftovers/pages/builds --silent || true
for _ in $(seq 1 30); do
  curl -s "https://arpwal.github.io/leftovers/appcast.xml" -o "$TMP/appcast.xml"
  grep -q "<sparkle:shortVersionString>$VERSION<" "$TMP/appcast.xml" && break
  sleep 10
done
grep -q "<sparkle:shortVersionString>$VERSION<" "$TMP/appcast.xml" || { echo "Update feed still not at $VERSION"; exit 1; }
SIG=$(grep -o 'sparkle:edSignature="[^"]*"' "$TMP/appcast.xml" | cut -d'"' -f2)
curl -sSL -o "$TMP/Leftovers.zip" "https://github.com/arpwal/leftovers/releases/download/v$VERSION/Leftovers.zip"
.build/artifacts/sparkle/Sparkle/bin/sign_update --verify "$TMP/Leftovers.zip" "$SIG" --account leftovers
echo "Update feed is live at $VERSION and its signature verifies"
