#!/usr/bin/env bash
# Writes dist/leftovers.rb from the template, with this release's version and
# the notarized DMG's checksum. Copy it into arpwal/homebrew-tap/Casks/.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
SHA=$(shasum -a 256 dist/Leftovers.dmg | cut -d' ' -f1)
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" \
  packaging/homebrew/leftovers.rb.template > dist/leftovers.rb
echo "Wrote dist/leftovers.rb (v$VERSION, $SHA)"
