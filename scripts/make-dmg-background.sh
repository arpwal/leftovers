#!/usr/bin/env bash
# Renders design/dmg-background.html to packaging/dmg/background.tiff, a
# two-resolution TIFF (660×400 @1x and @2x) so the DMG looks sharp on Retina.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
for scale in 1 2; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=660,400 \
    --force-device-scale-factor=$scale --screenshot="$WORK/bg@${scale}x.png" \
    "file://$PWD/design/dmg-background.html" >/dev/null 2>&1
done
tiffutil -cathidpicheck "$WORK/bg@1x.png" "$WORK/bg@2x.png" -out packaging/dmg/background.tiff >/dev/null
cp "$WORK/bg@2x.png" design/dmg-background@2x.png
echo "Wrote packaging/dmg/background.tiff"
