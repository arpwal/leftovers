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

- It collects no data and has no telemetry. Its only network request is the update
  check against `https://arpwal.github.io/leftovers/appcast.xml`, which can be turned off in
  Settings. Updates install only if signed with the project's EdDSA key.
- It never signals processes owned by root or other users, or core macOS
  processes (`Sources/Leftovers/Classification/ProtectionPolicy.swift`), with one
  exception: restarting a runaway `fseventsd`. That goes through a root helper
  (`Sources/LeftoversHelper/`) that the user allows in Login Items. Its XPC calls take
  no input. One changes something: SIGTERM fseventsd at its exact system path (root,
  parent launchd, pid and start time re-checked right before each signal; SIGKILL only
  if the same process is alive after 60 s), one restart at a time. The other two only
  read fseventsd's usage and the helper's version. It accepts only clients with
  Leftovers' bundle ID signed by the same team.
- Before sending a signal it checks that the process is still the same one it
  sampled (pid and start time), so a reused pid is never hit.
- Every release is signed with a Developer ID and notarized by Apple.
