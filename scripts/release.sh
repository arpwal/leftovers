#!/usr/bin/env bash
# One-command release. Bumps the version (patch by default), builds, signs,
# notarizes and staples the app and DMG, writes the Sparkle update feed,
# publishes the GitHub release, updates
# the Homebrew tap, and verifies the live download.
#   scripts/release.sh            # 1.0.1 -> 1.0.2
#   scripts/release.sh minor      # 1.0.2 -> 1.1.0
#   BUMP=none scripts/release.sh  # rebuild the current version without publishing
set -euo pipefail
cd "$(dirname "$0")/.."
PART="${1:-patch}"

if [ "${BUMP:-}" != "none" ]; then
  [ -z "$(git status --porcelain)" ] || { echo "Commit or stash changes first."; exit 1; }
  [ "$(git branch --show-current)" = "main" ] || { echo "Release from main."; exit 1; }
  git pull -q --ff-only
  echo "Releasing $(scripts/bump-version.sh "$PART")"
fi

scripts/bundle.sh
scripts/sign.sh
scripts/notarize.sh
scripts/update-cask.sh
[ "${BUMP:-}" = "none" ] && exit 0
scripts/make-appcast.sh

scripts/publish-release.sh
scripts/update-tap.sh
scripts/verify-release.sh
