#!/usr/bin/env bash
# Read-only survey of a repository's git worktrees, printed as JSON.
#
#   survey-worktrees.sh [REPO_DIR] [--exclude PATH]...
#
# Uses the same verdicts and field names as `leftovers --worktrees --json`
# (path, repository, verdict, reason, branch, lastCommit, changes, inUseBy,
# removable), so an agent can read either one. Nothing is changed.
set -u

dir="."
excludes=()
while [ $# -gt 0 ]; do
  case "$1" in
    --exclude) excludes+=("$(cd "$2" 2>/dev/null && pwd -P || printf '%s' "$2")"); shift 2 ;;
    *) dir="$1"; shift ;;
  esac
done

QUIET_DAYS=14   # matches Worktree.quietDays in the app

common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "[]"; exit 0; }

esc() { # JSON string escape
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
  printf '"%s"' "$s"
}
str_or_null() { if [ -n "$1" ]; then esc "$1"; else printf 'null'; fi; }

# Main branch to compare against: origin/HEAD, then origin/main, main, origin/master, master.
main_ref=""
for ref in "$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" \
           origin/main main origin/master master; do
  [ -n "$ref" ] && git -C "$dir" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 && { main_ref=$ref; break; }
done

# Working folders of running processes: "path<TAB>process name".
in_use_table=$(lsof -a -d cwd -F cn 2>/dev/null | awk '/^c/{c=substr($0,2)} /^n/{print substr($0,2) "\t" c}')

user_of() { # first process whose working folder is inside $1
  local p=$1
  printf '%s\n' "$in_use_table" | awk -F'\t' -v p="$p" '$1==p || index($1, p "/")==1 {print $2; exit}'
}

is_excluded() {
  local p=$1 e
  for e in "${excludes[@]+"${excludes[@]}"}"; do
    [ "$p" = "$e" ] && return 0
    case "$e" in "$p"/*) return 0 ;; esac
  done
  return 1
}

squash_merged() { # branch tip's changes already on main as a single squashed commit
  local head=$1 base tmp
  base=$(git -C "$dir" merge-base "$main_ref" "$head" 2>/dev/null) || return 1
  tmp=$(git -C "$dir" commit-tree "$head^{tree}" -p "$base" -m squash-check 2>/dev/null) || return 1
  git -C "$dir" cherry "$main_ref" "$tmp" 2>/dev/null | grep -q '^-'
}

now=$(date +%s)
first=1
emit() { # path repo verdict reason branch lastCommit changes inUseBy removable
  [ $first -eq 1 ] && first=0 || printf ',\n'
  printf '  {"path": %s, "repository": %s, "verdict": %s, "reason": %s, "branch": %s, "lastCommit": %s, "changes": %s, "inUseBy": %s, "removable": %s}' \
    "$(esc "$1")" "$(esc "$2")" "$(esc "$3")" "$(esc "$4")" "$(str_or_null "$5")" \
    "$(str_or_null "$6")" "${7:-null}" "$(str_or_null "$8")" "$9"
}

repo_root=""
printf '[\n'
index=0
path="" head="" branch="" locked="" prunable=""
process() {
  [ -z "$path" ] && return
  index=$((index + 1))
  if [ $index -eq 1 ]; then repo_root=$path; emit "$path" "$repo_root" in_use "Main checkout" "$branch" "" "" "" false; return; fi

  local last="" age_days="" changes="" user="" verdict reason removable=false
  if [ -n "$prunable" ] || [ ! -d "$path" ]; then
    emit "$path" "$repo_root" missing "Folder is gone; git still lists it" "$branch" "" "" "" false; return
  fi
  local ts; ts=$(git -C "$path" log -1 --format=%ct HEAD 2>/dev/null)
  if [ -n "$ts" ]; then
    last=$(git -C "$path" log -1 --format=%cI HEAD 2>/dev/null)
    age_days=$(( (now - ts) / 86400 ))
  fi
  changes=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  user=$(user_of "$path")

  if [ -n "$locked" ]; then verdict=in_use; reason="Locked"
  elif is_excluded "$path"; then verdict=in_use; reason="In use by this Claude session"; user="this Claude session"
  elif [ "${changes:-0}" -gt 0 ]; then verdict=has_changes; reason="$changes uncommitted change$([ "$changes" -eq 1 ] || echo s)"
  elif [ -n "$user" ]; then verdict=in_use; reason="In use by $user"
  elif [ -z "$main_ref" ]; then verdict=unknown; reason="No main branch found to compare with"
  elif git -C "$dir" merge-base --is-ancestor "$head" "$main_ref" 2>/dev/null; then verdict=safe; reason="Already on main"; removable=true
  elif squash_merged "$head"; then verdict=safe; reason="Squash-merged into main"; removable=true
  elif [ -n "$branch" ] && [ "$(git -C "$dir" for-each-ref --format='%(upstream:track)' "refs/heads/$branch")" = "[gone]" ]; then
    verdict=safe; reason="Branch deleted on the remote"; removable=true
  elif [ -n "$age_days" ] && [ "$age_days" -ge $QUIET_DAYS ]; then verdict=probably_done; reason="No commits in $age_days days"; removable=true
  else verdict=not_on_main; reason="Not on main yet"
  fi
  emit "$path" "$repo_root" "$verdict" "$reason" "$branch" "$last" "$changes" "$user" "$removable"
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) process; path=${line#worktree }; head="" branch="" locked="" prunable="" ;;
    "HEAD "*) head=${line#HEAD } ;;
    "branch "*) branch=${line#branch refs/heads/} ;;
    locked*) locked=1 ;;
    prunable*) prunable=1 ;;
    bare) index=$((index + 1)); repo_root=$path; path="" ;;
  esac
done < <(git -C "$dir" worktree list --porcelain; echo)
process
printf '\n]\n'
