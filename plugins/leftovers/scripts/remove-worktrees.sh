#!/usr/bin/env bash
# Remove the exact worktrees named, the same way the Leftovers app does.
#
#   remove-worktrees.sh [--exclude PATH]... WORKTREE_PATH...
#   remove-worktrees.sh --prune REPO_DIR
#
# Each path is checked again right before removal: it must still be a linked
# worktree (never the main checkout), have no uncommitted or untracked files,
# and no running process may be working in it. Removal is always
# `git worktree remove` WITHOUT --force, so git itself refuses if anything
# would be lost. Branches are always kept. Prints one line per path.
set -u

excludes=()
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --prune)
      if git -C "$2" worktree prune -v; then echo "pruned: missing worktrees cleared from $2"; else echo "kept: prune failed in $2"; fi
      exit 0 ;;
    --exclude) excludes+=("$(cd "$2" 2>/dev/null && pwd -P || printf '%s' "$2")"); shift 2 ;;
    *) paths+=("$1"); shift ;;
  esac
done

in_use_table=$(lsof -a -d cwd -F cn 2>/dev/null | awk '/^c/{c=substr($0,2)} /^n/{print substr($0,2) "\t" c}')

status=0
for p in "${paths[@]+"${paths[@]}"}"; do
  if [ ! -d "$p" ]; then echo "kept: $p (folder not found; use --prune on its repository)"; status=1; continue; fi
  p=$(cd "$p" && pwd -P)

  skip=""
  for e in "${excludes[@]+"${excludes[@]}"}"; do
    case "$e" in "$p"|"$p"/*) skip="this Claude session is working in it" ;; esac
  done
  [ -n "$skip" ] && { echo "kept: $p ($skip)"; status=1; continue; }

  toplevel=$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)
  gitdir=$(git -C "$p" rev-parse --path-format=absolute --git-dir 2>/dev/null)
  common=$(git -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ -z "$toplevel" ] || [ "$(cd "$toplevel" && pwd -P)" != "$p" ]; then
    echo "kept: $p (not the top of a git worktree)"; status=1; continue
  fi
  if [ "$gitdir" = "$common" ]; then
    echo "kept: $p (this is the main checkout)"; status=1; continue
  fi

  user=$(printf '%s\n' "$in_use_table" | awk -F'\t' -v p="$p" '$1==p || index($1, p "/")==1 {print $2; exit}')
  [ -n "$user" ] && { echo "kept: $p ($user is working in it right now)"; status=1; continue; }

  changes=$(git -C "$p" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$changes" != "0" ] && { echo "kept: $p ($changes uncommitted change(s))"; status=1; continue; }

  branch=$(git -C "$p" symbolic-ref -q --short HEAD 2>/dev/null || echo "detached")
  # Run from the main repository, not from inside the worktree being removed.
  if out=$(git --git-dir="$common" worktree remove "$p" 2>&1); then
    echo "removed: $p (branch $branch kept)"
  else
    echo "kept: $p (git refused: $(printf '%s' "$out" | tr '\n' ' '))"; status=1
  fi
done
exit $status
