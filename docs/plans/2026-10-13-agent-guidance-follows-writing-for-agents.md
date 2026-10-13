---
canonical: decisions:docs/plans/2026-10-13-agent-guidance-follows-writing-for-agents.md
phases: [3]
status: active
---
Part of [Agent guidance follows writing-for-agents](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-10-13-agent-guidance-follows-writing-for-agents.md).

This repository carries Phase 3: the `skill-trigger-test` tool, the
diagnosing-bugs prompts file, retro's pointers to the `guidance.*` rules,
and the sweep that gives every prohibition in `dot_claude/CLAUDE.md.tmpl`
its positive target (`guidance.state-the-target`, ADR-0032).

## Decision log
- 2026-10-13 — Isolation by a scratch `CLAUDE_CONFIG_DIR`, not by renaming
  the copy: the first full run showed every should-prompt loading the
  installed `diagnosing-bugs` (30/30 "collision"), because an identical
  installed skill wins. The scratch config holds the auth settings
  (`apiKeyHelper`, `env`), the global CLAUDE.md, every other installed
  skill, and the skill under test under its real name; the `collision`
  state is gone. Hooks and plugins are left out, so rates read higher than
  in a full session (the earlier harness, with hooks, measured 8/10).
- 2026-10-13 — The trap kills the workers' own process group (`set -m`,
  pgid from `ps`), not group 0: from a non-interactive caller, group 0 is
  the caller's shell.
- 2026-10-13 — stdout lines carry a verdict column (`ok`, `FAIL`, `error`,
  `budget`) between kind and hits/runs, beyond the plan's three columns, so
  a failing prompt can be read without counting.
- 2026-10-13 — Every wait is bounded: the budget lock gives up after 60 s
  (the run is an `error`), and each `claude -p` runs under `timeout 300`.
- 2026-10-13 — The default ceiling scales with the plan: prompts × runs ×
  $0.35, and an in-flight run reserves $0.35 (measured means: $0.26 a run
  with hooks, $0.07 with this tool's scratch config).

## Observed (before the push)
- `make check` → render, lint (shellcheck covers the tool), private-refs:
  ok.
- Exit codes: no arguments → 2; a 2-column TSV → 2; `--max-usd 0.01` → 3,
  every run `budget`, $0.00, no scratch dir left; a vague skill
  ("Helpers for various things.") on 2 should + 2 near-miss → 1, $1.03.
- Signals: `kill -TERM` 10 s into a run → exit 143, tagged `claude -p`
  processes 6 → 0, scratch dir gone; SIGINT from a fresh session → exit
  130, 6 → 0, gone.
- `skill-trigger-test dot_claude/skills/diagnosing-bugs
  dot_claude/skills/diagnosing-bugs/trigger-prompts.tsv --runs 3` →
  `should 30/30 · near-miss 0/30 · $4.41`, exit 0.
- Prohibitions in `dot_claude/CLAUDE.md.tmpl`, from `grep -nE
  'NEVER|[Nn]ever |Do not|[Dd]on.t |forbidden'` after the sweep (lines cut
  to 110 characters). Each rule names its target in the same or the next
  sentence; lines marked `(prose)` use the word without stating a rule:

```
10:1. NEVER run `git stash pop` or `git stash apply` without an explicit stash
11:   reference (e.g. `stash@{2}`). Bare pop/apply is forbidden.
26:   use `gwt-stash-save` / `gwt-stash-pop`, never raw `git stash`.
49:edit/commit — never assume your branch is still checked out across turns.
56:  one session, never rely on ambient cwd for a mutating git command — a stray
64:- **Never force-push a git tag.** If a release needs a fix after tagging, cut
68:- **In repos where a `v*` tag drives CI build/publish, never chain `git commit
89:  Never run `amont-fleet fix --apply --agents-md` against the live checkouts:
91:  worktrees start from `origin/main` so they never see the edit.  (prose)
102:  don't rely on CI to catch the first round of failures. Match the CI
113:- **NEVER pipe a mutating command through `tail`/`head`/`grep` to trim its
122:  reported "exited with code 0" and had never left the machine; a long  (prose)
127:  fallback) and check it's actually correct — don't stop at CI green, a
142:to `main` outright ("Pushing to branch main is forbidden. Open a Pull  (prose)
143:Request."), so branch + PR is the only route — don't reach for
154:yourself: never a `🧑 decision` for the merge or release, never "a person
161:**Never use `gh pr merge --auto` on the user's repos.** None of them have
167:`conclusion=success`, THEN merge as a separate command. Never chain the poll
206:Never echo the token into output, a commit, or a PR body — pass it through the
209:Details that don't belong here — the CI-log recipe (Forgejo has **no** log  (prose)
217:tool never uses it (verified 2026-09-09: `ps -p $$` → `/bin/zsh`, and 32,555  (prose)
219:Write bash-compatible syntax. Never write fish syntax (`set x (cmd)`,
235:  and the tool reports success, so the grep you wanted silently never ran  (prose)
320:contract from the approved plan or the request; never ask the person for
345:matters; don't re-mention it in every reply.
```
  Before the sweep, two had no target: the "never mark the plan's merge /
  never add a person watches" pair (now "Write the plan's own merge and
  release as agent steps…") and "Do not re-read a file" (now "Trust the
  Edit/Write result…").
- Skill descriptions, checked with a one-off `awk` that applies the same
  test as amont-agent's `agent-guidance-shape` `has_trigger` (a `Use
  <lowercase word>` or `whenever` clause on one `description:` line): every
  model-invoked `dot_claude/skills/*/SKILL.md` passes; `retro` is
  person-invoked. The hook itself is observed in Phase 4.

## Implementation review
Round 1: approve-with-changes (47k tokens, 73 s). Fixed: bounded lock wait
and per-run `timeout 300`; unreadable settings and a failed copy are loud
(exit 3); `--max-usd` validated (`.`, `1.2.3`, `abc` → exit 2); a signal
before the pgid lookup still kills the group; verdict column recorded; the
prohibition list pasted and the description check named.
