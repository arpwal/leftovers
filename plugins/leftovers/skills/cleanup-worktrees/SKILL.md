---
name: cleanup-worktrees
description: Clean up git worktrees once the work in them is done. Asks the user for permission first, has the worktree-cleanup agent check them in the background, presents the options, and removes only what the user accepts. Use when the Leftovers Stop hook reminds you, when you finish work that used worktrees, or when the user asks to clean up worktrees.
---

# Clean up worktrees (permission first)

Worktrees left behind after a task take disk space and clutter `git worktree list`.
Offer to clean them up, but **never remove anything the user hasn't chosen**.

The plugin's scripts are in `../../scripts` relative to this skill's base directory.
Call that absolute folder `SCRIPTS` below.

## 1. Ask for permission

Before checking or touching anything, ask with AskUserQuestion (or in plain text if
that tool isn't available). Name the worktrees you know about, for example:

> **Clean up worktrees?** This session left 2 worktrees on disk (`feat-login`, `fix-typo`).
> Want me to check them in the background and show you what's safe to remove?
> - **Yes, check them** — read-only check; nothing is removed until you pick an option
> - **Not now**

If the user says no, or doesn't answer, stop here and don't bring it up again this session.

## 2. Survey in the background

Launch the agent with the Agent tool, `subagent_type: "leftovers:worktree-cleanup"`
(or `worktree-cleanup` if that's how it's listed), `run_in_background: true`, and a prompt like:

```
MODE: SURVEY
REPO: <absolute path of the repository>
EXCLUDE: <absolute path of the folder this session is working in>
SCRIPTS: <SCRIPTS>
```

Tell the user in one line that the check is running and they can keep working.
If the Agent tool isn't available, run `"$SCRIPTS/survey-worktrees.sh" REPO --exclude EXCLUDE`
yourself; it's read-only.

## 3. Present the options

When the agent reports back, show its SUMMARY and the worktrees in each group
(short names, branch, reason, size), then ask with AskUserQuestion using the agent's
OPTIONS, recommended first:

- **Remove the safe ones (Recommended)** — already on main, squash-merged, or branch deleted; clean; nothing using them
- **Also remove the probably-done ones** — only if there are any
- **Clear the missing entries** — only if there are any
- **Let me pick** — then ask a multiSelect question listing each removable worktree
- **Leave everything**

Always say that branches are kept and that git refuses to remove anything with
uncommitted work. Never offer `has_changes`, `in_use` or `not_on_main` worktrees for
removal; list them as kept, with the reason.

## 4. Remove exactly what was accepted

If the user picked anything other than "Leave everything", launch the agent again in
the background with only the approved paths:

```
MODE: REMOVE
REPO: <repository>
EXCLUDE: <folder this session is working in>
SCRIPTS: <SCRIPTS>
APPROVED:
<path 1>
<path 2>
PRUNE: <repository>        (only if "Clear the missing entries" was chosen)
```

When it finishes, tell the user in one or two lines what was removed, what was kept
and why, and that the branches are still there (`git branch -d <name>` deletes one
later if they want).

## Never

- Remove, prune or delete anything before step 4, or anything the user didn't pick.
- Use `git worktree remove --force`, `rm -rf`, `git clean`, or delete branches.
- Remove the worktree this session is running in.
