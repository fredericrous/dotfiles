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
- Prohibitions in `dot_claude/CLAUDE.md.tmpl`: of the 27 matches, about 23
  are rules, and all but two already named their target; the two (the
  "never mark the plan's merge… / never a person watches" pair, and "do not
  re-read a file") now lead with it.
- Skill descriptions: every model-invoked `dot_claude/skills/*/SKILL.md`
  carries a `Use <word>` or `whenever` clause on one line; `retro` is
  person-invoked.
