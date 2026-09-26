#!/usr/bin/env bash
# Notarizes and staples build/Leftovers.app, then produces the release
# artifacts in dist/: a zip and a SHA-256 checksum.
#
# One-time setup (stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials leftovers \
#     --apple-id <your Apple ID> --team-id <team id>
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
APP="build/Leftovers.app"
mkdir -p dist
ZIP="dist/Leftovers-$VERSION.zip"

# notarytool needs an archive; ditto keeps the bundle's signature intact.
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

# Re-zip so the published archive carries the stapled ticket (works offline).
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
