---
canonical: greenrack:docs/plans/2026-11-21-greenrack-context-becomes-an-index.md
phases: [4]
status: done
---

Part of [Greenrack context becomes an index](greenrack:docs/plans/2026-11-21-greenrack-context-becomes-an-index.md).
This repository carries Phase 4: the entry hook, its test and the settings change.

## Code review

- chezmoi: backend, lang:python, platform, architect (new entry.py module)

## Verification

- Phase 4: the 36 tests (standard library only) pass; one opt-in timing test skips on a busy host. Three live `claude -p` sessions started in `~/Developer/Perso` read a file in `social-planner` (a consumer), a second file there, then one in `amont`. The hook logged `given` once and `not a consumer` for `amont`, nothing at session start, and the model reported A=YES B=NO C=NO each time. The mirror check, the template rendered against `~/.claude/settings.json`, is empty. On a quiet host a call's median is 62 ms against 52 ms for an empty interpreter start, so the script adds 9 ms; the plan's absolute bound of 60 ms at p95 is withdrawn, because this machine's interpreter start alone is above it.

## Implementation review

- implementation-review: approve on the delta; all 16 candidates ruled fine, the swallowed errors being the hook's reported fail-open. 102k tokens, 62 s.
- backend: approve on the delta. The marker is released on any exception, a failure reports the command's last stderr line, the counter is atomic. Carried: a hook killed at 15 s between claim and release; a denied sibling call. 96k, 85 s.
- lang:python: approve on the delta. Output decodes as UTF-8, trailing data is refused. `deliberate:` options stay a dict, a stopgap with a named replacement. 67k, 59 s.
- platform: approve-with-changes on the delta. `deliberate:` the floor is `^7.6.0`, not `~7.6.0`, because the index must list the components later 7.x releases add; the CLI's tests hold its size and the hook cuts at 9,500. 88k, 73 s.
- architect: approve. Carried: the scanner's private interface, pinned by a test that prints the Python version. `deliberate:` the arguments repeat in two settings entries, one stopgap. 66k, 45 s.
