#!/usr/bin/env bash
# Notarizes and staples the app, then builds, notarizes and staples the DMG.
# Produces dist/Leftovers.dmg, dist/Leftovers.zip and dist/SHA256SUMS; the
# names carry no version so /releases/latest/download/Leftovers.dmg is stable.
#
# One-time setup (stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials leftovers --apple-id <Apple ID> --team-id <team id>
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
APP="build/Leftovers.app"
mkdir -p dist

# Fails unless Apple reports "Accepted" (`--wait` alone exits 0 on "Invalid").
notarize() {
  local result status
  result=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
  status=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["status"])' "$result")
  [ "$status" = "Accepted" ] || { echo "Notarization of $1: $status"; echo "$result"; exit 1; }
  echo "Notarized $1"
}

# The app: notarytool needs an archive; ditto keeps the signature intact.
ditto -c -k --keepParent "$APP" dist/Leftovers.zip
notarize dist/Leftovers.zip
xcrun stapler staple "$APP"
rm dist/Leftovers.zip
ditto -c -k --keepParent "$APP" dist/Leftovers.zip   # re-zip with the ticket inside

# The disk image, built from the stapled app.
./scripts/make-dmg.sh
notarize dist/Leftovers.dmg
xcrun stapler staple dist/Leftovers.dmg

spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 dist/Leftovers.dmg
(cd dist && shasum -a 256 Leftovers.dmg Leftovers.zip | tee SHA256SUMS)
