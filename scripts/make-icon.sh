#!/usr/bin/env bash
# Renders design/<icon>.svg to packaging/AppIcon.icns (all macOS sizes).
# Needs Google Chrome for SVG rendering (filters/blur); the .icns is committed,
# so normal builds never need this script.
# Usage: scripts/make-icon.sh [icon-c-pressure-dial]
set -euo pipefail
cd "$(dirname "$0")/.."
ICON="${1:-icon-c-pressure-dial}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1024,1024 \
  --default-background-color=00000000 --screenshot="$WORK/1024.png" "file://$PWD/design/$ICON.svg" >/dev/null 2>&1

SET="$WORK/AppIcon.iconset"; mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$WORK/1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o packaging/AppIcon.icns
cp "$WORK/1024.png" design/AppIcon-1024.png
echo "Wrote packaging/AppIcon.icns from design/$ICON.svg"
