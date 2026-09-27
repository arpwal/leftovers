#!/usr/bin/env bash
# Installs build/Leftovers.app and relaunches it. Keeps ONE copy: updates
# /Applications if Leftovers is installed there (the DMG's location), else
# ~/Applications, and moves any other copy to the Trash.
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x Leftovers 2>/dev/null && sleep 1 || true  # let it exit before relaunching
TARGET="$HOME/Applications"
[ -d /Applications/Leftovers.app ] && TARGET=/Applications
for copy in /Applications/Leftovers.app "$HOME/Applications/Leftovers.app"; do
  if [ -d "$copy" ] && [ "$copy" != "$TARGET/Leftovers.app" ]; then
    mv "$copy" "$HOME/.Trash/Leftovers-duplicate-$(date +%s).app"
    echo "Moved duplicate $copy to the Trash"
  fi
done
mkdir -p "$TARGET"
rm -rf "$TARGET/Leftovers.app"
ditto build/Leftovers.app "$TARGET/Leftovers.app"
open "$TARGET/Leftovers.app"
echo "Installed and launched $TARGET/Leftovers.app"
