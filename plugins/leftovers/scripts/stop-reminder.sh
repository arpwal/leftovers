#!/usr/bin/env bash
# Stop hook: if this session created git worktrees that are still on disk,
# remind Claude once to offer a cleanup before it finishes. Claude must ask
# the user first; this hook never removes anything itself.
set -u
input=$(cat)
. "$(dirname "$0")/lib.sh"

# Claude is already continuing because of a Stop hook: don't loop.
printf '%s' "$input" | tr -d ' \n' | grep -q '"stop_hook_active":true' && exit 0
[ "${LEFTOVERS_NO_WORKTREE_REMINDER:-}" = "1" ] && exit 0

sid=$(session_id "$input")
cwd=$(session_cwd "$input")
[ -n "$sid" ] || exit 0
baseline="$STATE_DIR/$sid.baseline"
[ -f "$baseline" ] || exit 0   # no SessionStart record: don't guess
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

new=$(linked_worktrees "$cwd" | LC_ALL=C comm -23 - "$baseline")
# Leave out the worktree this session is running in; it can't be removed from inside.
here=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
new=$(printf '%s\n' "$new" | grep -vxF -- "$here" | sed '/^$/d')
[ -n "$new" ] || exit 0

# Remind once per set of new worktrees.
reminded="$STATE_DIR/$sid.reminded"
[ -f "$reminded" ] && [ "$(cat "$reminded")" = "$new" ] && exit 0
printf '%s' "$new" > "$reminded"

count=$(printf '%s\n' "$new" | wc -l | tr -d ' ')
list=$(printf '%s\n' "$new" | sed 's/^/- /')
reason="Leftovers: this session created $count git worktree(s) that are still on disk:
$list

If the work in them is finished (merged, pushed, or abandoned), run the /leftovers:cleanup-worktrees skill now: it asks the user for permission first, then has the worktree-cleanup agent check them in the background and presents the options. If the work is still in progress, say nothing about this and stop. Never remove a worktree without the user's explicit choice."

# JSON-escape the reason for the hook output.
esc=${reason//\\/\\\\}; esc=${esc//\"/\\\"}; esc=${esc//$'\n'/\\n}; esc=${esc//$'\t'/\\t}
printf '{"decision": "block", "reason": "%s"}\n' "$esc"
exit 0
