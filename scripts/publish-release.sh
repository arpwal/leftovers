#!/usr/bin/env bash
# Commits the version bump, tags it (signed), pushes, and creates the GitHub
# release with the notarized assets in dist/. Notes list the commits since
# the previous tag.
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env
TAG="v$VERSION"
PREVIOUS=$(git describe --tags --abbrev=0 2>/dev/null || true)
NOTES="$(mktemp)"; trap 'rm -f "$NOTES"' EXIT

git add packaging/release.env
git commit -q -m "Release $TAG"
git tag -s "$TAG" -m "Leftovers $VERSION"
git push -q origin main "$TAG"

{
  echo "**Download:** \`Leftovers.dmg\` below, then drag Leftovers to Applications. Signed and notarized by Apple."
  echo
  echo "**Homebrew:** \`brew upgrade --cask arpwal/tap/leftovers\`"
  echo
  echo "### Changes"
  git log --pretty='- %s' "${PREVIOUS:+$PREVIOUS..}HEAD" | grep -v -E '^- Release v' || true
} > "$NOTES"
gh release create "$TAG" dist/Leftovers.dmg dist/Leftovers.zip dist/SHA256SUMS \
  --title "Leftovers $VERSION" --notes-file "$NOTES"
