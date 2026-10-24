---
canonical: github:fredericrous/aval/docs/plans/2026-10-23-code-rules-reach-writers-reviewers.md
phases: [4]
status: done
branch: docs/code-rules-full-text
---
# Code rules reach the agent that writes and the agent that reviews

Pointer. The plan and its review panel live in aval (aval#42); the ADR is
decisions ADR-0043 (decisions#86). This repository carries Phase 4: the
implementation-review brief built by `worktree-task` F4b carries the full text
of the `governs: code` constraints and the decisions that apply to the changed
files, and the `implementation-review` agent blocks on a code-rule violation the
diff introduces, deletions included.

## Verification record

The two files were patched into the live `~/.claude` (only this branch's hunks:
the live `SKILL.md` carries a newer preview step not on `origin/main`, which a
`chezmoi apply` would have reverted; backups kept). Then the real
`implementation-review` agent read briefs built exactly as the new F4b step
says, on the relais branch (55 code rules in full, other constraints,
`aval relevant --top 20` for the changed file):
- Seeded diff adding `checkout_names` with `let mut v`, `for r in roots`,
  `Some(n)` in `crates/relais/src/repo.rs` → blocking finding citing
  `names.reveal-intent` → `Verdict: rework`, blocking, `repo.rs:115-117`, the
  rule's own exception quoted and ADR-0043 named as why it blocks.
- Seeded deletion-only diff removing `crate::tooling::GUIDANCE_TIMEOUT` from a
  `run_aval` call in `crates/relais/src/context/mod.rs` → blocking finding
  citing `reliability.every-wait-is-bounded` at the old-side line →
  `Verdict: rework`, blocking, `context/mod.rs:219` (the deleted line).
- Both drills ran on the live agent as patched before `04ee438` (verdict
  wording); under that wording a rename is a blocking finding under
  `approve-with-changes`. The blocking finding and rule id are what Phase 4
  asks for, and both drills show them.
- The brief's commands → `aval --json rules --level constraint --governs code
  --full` 55 rules; `aval relevant --json --top 20` 18 ranked keys.

## Decision log

- 2026-10-24 — `aval resolve <key>` runs without `--scope`: aval's `relevant`
  already reports each key's resolved verdict at the default scope, and no
  fleet repository resolves scoped decisions in review today. Follow-up if one
  does.

## Implementation review

- Round 1 approve-with-changes (31k, 34 s): verification recorded above (two
  drills on the live agent), verdict wording for a locally fixable rule finding
  (`04ee438`), scope kept as a recorded decision.
