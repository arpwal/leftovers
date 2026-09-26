# Security Policy

Leftovers reads information about the processes on your Mac and can quit them,
so security reports are taken seriously.

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please report privately through GitHub:
[Report a vulnerability](https://github.com/arpwal/leftovers/security/advisories/new).
Don't open a public issue for security problems.

You can expect an acknowledgement within 3 days. Fixes ship as a new
notarized release, with credit to the reporter unless you prefer otherwise.

## What Leftovers does and doesn't do

- It makes no network requests and collects no data.
- It never signals processes owned by root or other users, or core macOS
  processes (`Sources/Leftovers/Classification/ProtectionPolicy.swift`).
- Before sending a signal it checks that the process is still the same one it
  sampled (pid and start time), so a reused pid is never hit.
- Every release is signed with a Developer ID and notarized by Apple.
