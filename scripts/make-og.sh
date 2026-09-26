#!/usr/bin/env bash
# Renders design/og-card.html to docs/assets/og.png, the 1280×640 link preview.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,640 \
  --screenshot="$PWD/docs/assets/og.png" "file://$PWD/design/og-card.html" >/dev/null 2>&1
echo "Wrote docs/assets/og.png"
