#!/usr/bin/env bash
# Bumps VERSION (semver) and BUILD in packaging/release.env and prints the new
# version. Usage: scripts/bump-version.sh [patch|minor|major]   (default: patch)
set -euo pipefail
cd "$(dirname "$0")/.."
PART="${1:-patch}"
source packaging/release.env
IFS=. read -r MAJOR MINOR PATCH <<< "$VERSION"
case "$PART" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "usage: $0 [patch|minor|major]" >&2; exit 1 ;;
esac
NEW="$MAJOR.$MINOR.$PATCH"
sed -i '' -e "s/^VERSION=.*/VERSION=$NEW/" -e "s/^BUILD=.*/BUILD=$((BUILD + 1))/" packaging/release.env
echo "$NEW"
