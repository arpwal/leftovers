#!/usr/bin/env bash
# Regenerates docs/screenshots/ from live data, redacted for publishing:
# renders views offscreen (--snapshot --redact), then adds the window frame
# offscreen capture cannot draw: rounded corners, traffic lights, shadow.
# Needs ImageMagick. Run after scripts/bundle.sh so the real app icon is used.
set -euo pipefail
cd "$(dirname "$0")/.."
RAW="$(mktemp -d)"; trap 'rm -rf "$RAW"' EXIT
OUT="docs/screenshots"; mkdir -p "$OUT"
build/Leftovers.app/Contents/MacOS/Leftovers --snapshot "$RAW" --redact 2>/dev/null

frame() { # <input> <output>
  local r=32 w h
  w=$(magick identify -format "%w" "$1")
  h=$(magick identify -format "%h" "$1")
  magick "$1" \
    \( -size "${w}x${h}" xc:none -fill white -draw "roundrectangle 0,0,$((w-1)),$((h-1)),$r,$r" \) \
    -alpha set -compose DstIn -composite -compose over \
    -fill "#FF5F57" -stroke "#E0443E" -strokewidth 1 -draw "circle 28,28 40,28" \
    -fill "#FEBC2E" -stroke "#DEA123" -draw "circle 68,28 80,28" \
    -fill "#28C840" -stroke "#1AAB29" -draw "circle 108,28 120,28" \
    \( +clone -background black -shadow 35x28+0+18 \) +swap -background none -layers merge +repage \
    -resize 1400x "$2"
}

frame "$RAW/dashboard-agents-light.png"   "$OUT/agents-light.png"
frame "$RAW/dashboard-apps-dark.png"      "$OUT/apps-dark.png"
frame "$RAW/dashboard-leaks-light.png"    "$OUT/leaks-light.png"
frame "$RAW/welcome-2-light.png"          "$OUT/welcome-agents-light.png"
frame "$RAW/dashboard-scheduled-light.png" "$OUT/scheduled-light.png"
frame "$RAW/dashboard-worktrees-light.png" "$OUT/worktrees-light.png"
frame "$RAW/dashboard-overview-light.png"  "$OUT/overview-light.png"
echo "Wrote $(ls "$OUT" | wc -l | tr -d ' ') screenshots to $OUT"
