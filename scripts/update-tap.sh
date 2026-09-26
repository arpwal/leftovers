#!/usr/bin/env bash
# Pushes dist/leftovers.rb to the arpwal/homebrew-tap repository (signed commit).
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
gh repo clone arpwal/homebrew-tap "$WORK" -- -q
cp dist/leftovers.rb "$WORK/Casks/leftovers.rb"
cd "$WORK"
git -c user.name="Arpit Agarwal" -c user.email="arpwal@users.noreply.github.com" \
    -c gpg.format=ssh -c user.signingkey="$HOME/.ssh/id_ed25519.pub" -c commit.gpgsign=true \
    commit -q -am "leftovers $VERSION"
git push -q
echo "Tap updated to $VERSION"
