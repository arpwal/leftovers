#!/usr/bin/env bash
# Copies build/Leftovers.app to ~/Applications and relaunches it.
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x Leftovers 2>/dev/null && sleep 1 || true  # let it exit before relaunching
rm -rf "$HOME/Applications/Leftovers.app"
mkdir -p "$HOME/Applications"
cp -R build/Leftovers.app "$HOME/Applications/"
open "$HOME/Applications/Leftovers.app"
echo "Installed and launched ~/Applications/Leftovers.app"
