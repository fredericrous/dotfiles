---
status: active
branch: feat/plan-apply
repos: [amont-agent, relais, dotfiles]
canonical: amont-agent:docs/plans/2026-10-11-plan-review-edits-apply-without-opus.md
phases: [2]
adrs: []
---
# Plan-review edits apply without an Opus subagent (dotfiles slice)

Pointer to the plan's home in amont-agent (its PR #98, released as
amont-agent 2.36.0). This repository implements **Phase 2** only: the 11
`plan-review-*` agents' output contract gains a `Patches:` block, and the
plan-review skill's merge step applies it with `amont-agent plan-apply`.

## Behaviour (Phase 2)

- Every `plan-review-*.md` agent (not `implementation-review.md`) ends its
  output block with `Patches:` and a fenced JSON array of
  `{finding, old_string, new_string}`; the block's outer fence is four
  backticks so the inner `json` fence nests.
- `SKILL.md` step 4: `plan-review record`, then `plan-apply` with the
  accepted `{role, finding}` on stdin; on exit 3 the remainder is applied
  by the main session's `Edit` when small (≤ 3 findings, each under about
  15 lines) or by one Sonnet-preferred `general-purpose` subagent that ends
  with `plan-apply --check`; then `plan-apply --record-fallback`.
- The source was first brought level with the installed copy (the `record`
  bullet and the model-in-panel-line wording had been edited in place).

## Phases
- [ ] Phase 2 — the 11 agents, the skill, `chezmoi apply`.

## Verification
- `chezmoi diff` shows only these files; after `chezmoi apply` the installed
  copies equal the source; a real `/plan-review` round returns a parseable
  `Patches:` block per reviewer and `plan-apply` applies it → observed.

## Decision log
- 2026-10-11 — pointer plan: the decision and the reviews live in amont-agent.
