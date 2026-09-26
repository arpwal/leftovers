#!/usr/bin/env bash
# Copies build/MemoryJanitor.app to ~/Applications and relaunches it.
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x MemoryJanitor 2>/dev/null || true
rm -rf "$HOME/Applications/MemoryJanitor.app"
mkdir -p "$HOME/Applications"
cp -R build/MemoryJanitor.app "$HOME/Applications/"
open "$HOME/Applications/MemoryJanitor.app"
echo "Installed and launched ~/Applications/MemoryJanitor.app"
