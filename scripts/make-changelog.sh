#!/usr/bin/env bash
# Writes plain-language release notes by having Claude (the Claude Code CLI,
# `claude -p`) summarise the commits since the previous release, following
# packaging/changelog-prompt.md. Falls back to commit subjects if Claude isn't
# available or answers in the wrong shape.
#   scripts/make-changelog.sh             notes for $VERSION -> dist/notes.md, prepended to CHANGELOG.md
#   scripts/make-changelog.sh --backfill  rebuild CHANGELOG.md for every tagged release
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/release.env

commits() {   # subjects and bodies in a range, minus release bookkeeping
  git log --no-merges --format='* %s%n%b' "$1" | grep -v -E '^(Co-Authored-By|\* Release v)' | sed '/^$/d'
}

summarise() {   # range -> bullets on stdout; a range with no ".." is the first release
  local log bullets hint=""
  log=$(commits "$1")
  [[ "$1" != *..* ]] && hint=$'This is the very first release: say what the app does for people, not what changed.\n'
  bullets=$(printf '%s%s\n%s\n' "$hint" "$(cat packaging/changelog-prompt.md)" "$log" \
    | claude -p --model claude-sonnet-5 --output-format text 2>/dev/null | grep -E '^- ' | head -5 || true)
  if [ -z "$bullets" ]; then   # fallback: first five subjects
    bullets=$(git log --no-merges --format='- %s' "$1" | grep -v -E '^- Release v' | head -5)
  fi
  printf '%s\n' "$bullets"
}

section() {   # version, date (YYYY-MM-DD), range
  printf '## %s · %s\n\n%s\n\n' "$1" "$(date -j -f %F "$2" '+%B %-d, %Y')" "$(summarise "$3")"
}

HEADER=$'# What\'s new in Leftovers\n\nWritten by Claude from each release\'s changes, in plain words.\n\n'

if [ "${1:-}" = "--backfill" ]; then
  body="" previous=""
  for tag in $(git tag --sort=creatordate); do
    range="${previous:+$previous..}$tag"
    body="$(section "${tag#v}" "$(git log -1 --format=%cs "$tag")" "$range")"$'\n\n'"$body"
    previous=$tag
  done
  printf '%s%s' "$HEADER" "$body" > CHANGELOG.md
  echo "Rebuilt CHANGELOG.md for $(git tag | wc -l | tr -d ' ') releases"
  exit 0
fi

PREVIOUS=$(git describe --tags --abbrev=0 2>/dev/null || true)
mkdir -p dist
summarise "${PREVIOUS:+$PREVIOUS..}HEAD" > dist/notes.md
existing=$( [ -f CHANGELOG.md ] && tail -n +5 CHANGELOG.md || true )
printf '%s%s\n\n%s\n' "$HEADER" "$(section "$VERSION" "$(date +%F)" "${PREVIOUS:+$PREVIOUS..}HEAD")" "$existing" > CHANGELOG.md
echo "Wrote release notes for $VERSION:"; cat dist/notes.md
