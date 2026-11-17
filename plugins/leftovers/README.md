# Leftovers plugin for Claude Code

Coding agents create git worktrees for parallel work and then move on, leaving them on
disk. This plugin makes Claude clean up after itself, **with your permission**.

## What it adds

| Part | What it does |
|---|---|
| `SessionStart` hook | Records which worktrees already exist when a session starts. |
| `Stop` hook | When Claude finishes, if the session created worktrees that are still on disk, it reminds Claude once to offer a cleanup. It never removes anything itself. |
| `/leftovers:cleanup-worktrees` skill | Asks you for permission, runs the check in the background, shows the options, and removes only what you accept. Run it any time. |
| `worktree-cleanup` agent | The background worker. Read-only in SURVEY mode; in REMOVE mode it acts only on the exact paths you approved. |

## The flow

1. Claude finishes a task that used worktrees. The Stop hook reminds it.
2. Claude asks: *"This session left 2 worktrees on disk. Check them in the background?"*
3. If you say yes, the `worktree-cleanup` agent checks each one (read-only) while you keep working.
4. Claude shows what it found and asks what to do:
   - Remove the safe ones (already on main, squash-merged, or branch deleted; clean; unused)
   - Also remove the probably-done ones (clean, no commits in 14+ days)
   - Clear missing entries (`git worktree prune`)
   - Let me pick
   - Leave everything
5. The agent removes exactly what you picked and reports back.

## Safety

- Nothing is removed without your choice in the conversation.
- `git worktree remove` without `--force`: git refuses if anything is uncommitted or untracked.
- Every path is re-checked right before removal (still clean, nothing working in it).
- The main checkout, locked worktrees, and the folder Claude is working in are never removed.
- Branches are always kept.

The verdicts match the Leftovers app's Worktrees view and `leftovers --worktrees --json`.
If the app is installed, the agent can also use its CLI to find worktrees in your other
repositories.

## Install

```
/plugin marketplace add arpwal/leftovers
/plugin install leftovers@leftovers
```

Set `LEFTOVERS_NO_WORKTREE_REMINDER=1` to turn off the Stop-hook reminder while keeping
the skill and agent.

## Tests

```sh
plugins/leftovers/tests/run.sh
```
