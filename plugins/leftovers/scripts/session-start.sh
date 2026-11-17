#!/usr/bin/env bash
# SessionStart hook: remember which worktrees already existed, so the Stop
# hook only reminds Claude about worktrees this session created.
set -u
input=$(cat)
. "$(dirname "$0")/lib.sh"

sid=$(session_id "$input")
cwd=$(session_cwd "$input")
[ -n "$sid" ] || exit 0
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

mkdir -p "$STATE_DIR"
# Keep an existing baseline on resume/compact: the session is the same.
[ -f "$STATE_DIR/$sid.baseline" ] || linked_worktrees "$cwd" > "$STATE_DIR/$sid.baseline"
# Tidy state left by sessions older than a week.
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null
exit 0
