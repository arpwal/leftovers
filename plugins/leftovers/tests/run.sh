#!/usr/bin/env bash
# Tests for the plugin's scripts against throwaway git repositories.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
scripts="$here/../scripts"
tmp=$(mktemp -d); tmp=$(cd "$tmp" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
export CLAUDE_PLUGIN_DATA="$tmp/data" GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

repo="$tmp/repo"; wt="$tmp/wt"
git init -q -b main "$repo"
git -C "$repo" commit -q --allow-empty -m init

# Hooks: baseline taken before any worktree exists.
echo "{\"session_id\":\"s1\",\"cwd\":\"$repo\"}" | "$scripts/session-start.sh"
check "baseline recorded" '[ -f "$CLAUDE_PLUGIN_DATA/sessions/s1.baseline" ]'
out=$(echo "{\"session_id\":\"s1\",\"cwd\":\"$repo\",\"stop_hook_active\":false}" | "$scripts/stop-reminder.sh")
check "no reminder without new worktrees" '[ -z "$out" ]'

# merged: branch with a commit merged into main.
git -C "$repo" worktree add -q -b merged "$wt/merged"
git -C "$wt/merged" commit -q --allow-empty -m m
git -C "$repo" merge -q --ff-only merged
# squashed: changes squash-merged into main.
git -C "$repo" worktree add -q -b squashed "$wt/squashed"
echo a > "$wt/squashed/a"; git -C "$wt/squashed" add a; git -C "$wt/squashed" commit -q -m a1
echo b >> "$wt/squashed/a"; git -C "$wt/squashed" commit -q -am a2
git -C "$repo" merge -q --squash squashed >/dev/null; git -C "$repo" commit -q -m "squash"
# dirty, active, missing.
git -C "$repo" worktree add -q -b dirty "$wt/dirty"; echo x > "$wt/dirty/x"
git -C "$repo" worktree add -q -b active "$wt/active"
git -C "$wt/active" commit -q --allow-empty -m wip
git -C "$repo" worktree add -q -b gone "$wt/gone"; rm -rf "$wt/gone"
# session: the folder Claude is in.
git -C "$repo" worktree add -q -b session "$wt/session"

json=$("$scripts/survey-worktrees.sh" "$repo" --exclude "$wt/session")
check "survey is valid JSON" 'printf "%s" "$json" | jq -e . >/dev/null'
v() { printf '%s' "$json" | jq -r --arg p "$1" '.[] | select(.path==$p) | .verdict'; }
check "main checkout kept"      '[ "$(v "$repo")" = in_use ]'
check "merged is safe"          '[ "$(v "$wt/merged")" = safe ]'
check "squash-merged is safe"   '[ "$(v "$wt/squashed")" = safe ]'
check "dirty has changes"       '[ "$(v "$wt/dirty")" = has_changes ]'
check "active not on main"      '[ "$(v "$wt/active")" = not_on_main ]'
check "deleted folder missing"  '[ "$(v "$wt/gone")" = missing ]'
check "session folder excluded" '[ "$(v "$wt/session")" = in_use ]'

# Stop hook reminds once, then stays quiet; never loops.
out=$(echo "{\"session_id\":\"s1\",\"cwd\":\"$repo\",\"stop_hook_active\":false}" | "$scripts/stop-reminder.sh")
check "reminder blocks with JSON" 'printf "%s" "$out" | jq -e ".decision==\"block\"" >/dev/null'
check "reminder names worktrees"  'printf "%s" "$out" | jq -r .reason | grep -q "$wt/merged"'
out=$(echo "{\"session_id\":\"s1\",\"cwd\":\"$repo\"}" | "$scripts/stop-reminder.sh")
check "reminds only once"         '[ -z "$out" ]'
out=$(echo "{\"session_id\":\"s2\",\"cwd\":\"$repo\",\"stop_hook_active\": true}" | "$scripts/stop-reminder.sh")
check "no reminder when stop_hook_active" '[ -z "$out" ]'

# A process working in a finished worktree keeps it.
git -C "$repo" worktree add -q --detach "$wt/busy" main
(cd "$wt/busy" && exec sleep 30) & busy=$!
sleep 0.5
json=$("$scripts/survey-worktrees.sh" "$repo")
check "busy worktree in use"    '[ "$(v "$wt/busy")" = in_use ]'
res=$("$scripts/remove-worktrees.sh" "$wt/busy")
check "busy worktree kept"      '[ -d "$wt/busy" ]'
kill $busy 2>/dev/null; wait $busy 2>/dev/null

# Removal: only clean linked worktrees, never forced, branches kept.
res=$("$scripts/remove-worktrees.sh" --exclude "$wt/session" "$wt/merged" "$wt/squashed" "$wt/dirty" "$wt/session" "$repo")
check "merged removed"          '[ ! -d "$wt/merged" ]'
check "squashed removed"        '[ ! -d "$wt/squashed" ]'
check "dirty kept"              '[ -f "$wt/dirty/x" ] && grep -q "kept: $wt/dirty" <<<"$res"'
check "session kept"            '[ -d "$wt/session" ]'
check "main checkout kept"      'grep -q "main checkout" <<<"$res"'
check "branches kept"           'git -C "$repo" rev-parse -q --verify merged >/dev/null && git -C "$repo" rev-parse -q --verify squashed >/dev/null'
"$scripts/remove-worktrees.sh" --prune "$repo" >/dev/null 2>&1
check "prune clears missing"    '! git -C "$repo" worktree list | grep -q "$wt/gone"'

echo; [ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
