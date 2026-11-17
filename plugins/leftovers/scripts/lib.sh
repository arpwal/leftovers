# Shared helpers for the hook scripts. Sourced, not run.

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/leftovers-claude}/sessions"

# Read a top-level string field from the hook's JSON input without needing jq.
json_field() { # json key
  printf '%s' "$1" | tr -d '\n' | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -1
}

session_id() { json_field "$1" session_id | tr -cd 'A-Za-z0-9_-'; }

session_cwd() {
  local c; c=$(json_field "$1" cwd)
  [ -n "$c" ] && [ -d "$c" ] && printf '%s' "$c" || pwd
}

# Linked worktrees of the repository at $1 (the main checkout is left out), one path per line, sorted.
linked_worktrees() {
  git -C "$1" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{n++; if (n>1) print substr($0,10)} /^bare$/{n=0}' | LC_ALL=C sort
}
