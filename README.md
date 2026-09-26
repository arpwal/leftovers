<p align="center">
  <img src="design/AppIcon-1024.png" width="160" alt="Memory Janitor icon">
</p>

<h1 align="center">Memory Janitor</h1>

<p align="center">
  A menu-bar app for macOS that finds memory leaked by other software, and gives it back.<br>
  Built for machines running many coding agents at once.
</p>

---

## Why

Coding agents start processes and don't always stop them: dev servers that outlive
their terminal, one copy of every MCP server per session, video encoders that never
release their buffers. The memory stays taken, swap fills up, and the Mac slows down.

Activity Monitor makes this hard to see. It sorts by memory in RAM, but a leak that has
been swapped out barely shows there. Memory Janitor reads each process's **footprint**:
RAM plus compressed plus swapped. That's the number macOS actually pays for.

> The case that started this project: a video-encoder helper showing **7 MB** in RAM
> while holding a **59 GB** footprint, idle for four days.

## What it does

- **Menu bar**: memory pressure, swap, and how much memory can be reclaimed.
- **Likely leaks**: each one with a plain-language reason and a Quit button.
- **Agents**: memory per coding-agent session (Claude Code, Codex, Gemini CLI, Cursor
  Agent, Aider, OpenCode), including every process it started, and the tool servers
  that several sessions each run their own copy of.
- **Clean up**: quits every likely leak in one step, after showing you the list.
- **Protect**: mark any app "never flag or quit".
- **Command line for agents**: the same engine and safety rules, as text or JSON.

## What counts as a leak

| Rule | Condition |
|---|---|
| Hoarding | Footprint ≥ 2 GB, at least 4× what is in RAM, idle, running ≥ 1 hour |
| Orphaned dev process | node / python / bun / deno… whose terminal or agent is gone, idle ≥ 12 hours |
| Folder deleted | A dev process whose working folder no longer exists (e.g. a removed git worktree) |
| Large while idle | Footprint ≥ 8 GB, idle, running ≥ 1 hour |

All thresholds live in [`Classification/Thresholds.swift`](Sources/MemoryJanitor/Classification/Thresholds.swift).

## What it never touches

Protection is checked before any leak rule runs, so a protected process can't become a
candidate:

- anything owned by root or another user
- core macOS processes (WindowServer, Dock, Finder, Spotlight, loginwindow, and more)
- macOS binaries under `/System`, `/usr` and `/sbin`, with one exception: on-demand
  XPC helpers. launchd relaunches those when needed, so one may be quit only
  while it's hoarding.
- Memory Janitor itself, and anything you protect

Before signalling a process, it checks the process ID still belongs to the same process
(by start time). It asks the process to quit first and forces it only after 3 seconds.

## Install

Download the latest `MemoryJanitor-<version>.zip` from
[Releases](../../releases), unzip it, and move **Memory Janitor.app** to Applications.
Builds are signed with a Developer ID and notarized by Apple, so they open without warnings.

Requires macOS 14 Sonoma or later, on Apple silicon or Intel.

## Command line

The app binary doubles as a CLI, so scripts and coding agents can use it:

```sh
ln -s "/Applications/MemoryJanitor.app/Contents/MacOS/MemoryJanitor" /usr/local/bin/memory-janitor

memory-janitor --report   # human-readable summary
memory-janitor --json     # machine-readable report (stable field names)
memory-janitor --clean    # quit every likely leak; protected processes are refused
```

An agent can run `memory-janitor --json`, read `likelyLeaks` and `duplicateToolServers`,
and decide what to do. It's the same data the app shows.

## Privacy

Memory Janitor makes no network requests and collects nothing. Everything it reads comes
from the kernel on your Mac, and nothing leaves it.

## Build from source

```sh
swift build                    # debug build
swift run MemoryJanitor        # run the menu-bar app
scripts/bundle.sh              # universal release .app in build/
SIGNING_IDENTITY_OVERRIDE=- scripts/sign.sh   # ad-hoc sign for local use
scripts/install-local.sh       # copy to ~/Applications and launch
```

Maintainers releasing a notarized build: `scripts/release.sh`
(configuration in [`packaging/release.env`](packaging/release.env)).

## Project layout

```
Sources/MemoryJanitor/
  Sampling/        libproc + sysctl readers (footprint, CPU, argv, swap)
  Classification/  protection policy, leak rules, thresholds
  Agents/          agent-session attribution, duplicate tool servers
  Actions/         safe termination (identity check, TERM then KILL)
  Store/           sampling loop and app state
  UI/              menu-bar popover, dashboard, design tokens
  CLI/             --report, --json, --clean, --snapshot
design/            icon sources (SVG)
packaging/         Info.plist, icon, release config
scripts/           bundle, sign, notarize, release
```

## License

MIT © Arpit Agarwal
