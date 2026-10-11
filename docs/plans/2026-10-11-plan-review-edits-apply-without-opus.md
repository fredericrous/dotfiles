---
status: done
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
- [x] Phase 2 — the 11 agents, the skill, `chezmoi apply`.

## Verification
- `chezmoi status` from the worktree listed the 12 files of this change,
  plus unrelated `MM`/`R` rows (settings.json, worktree-sweep, fish, git
  config: installed copies edited in place) → observed 2026-10-11; only the
  12 targets were applied (`chezmoi apply --source <wt> <targets>`, the
  skill with `--force` after checking its installed copy equalled the
  levelled source), and `cmp` shows all 12 installed files equal the source.
- amont-agent upgraded to 2.36.0 (brew, tap at 2.36.0; release assets for
  six targets plus SHA256SUMS) → observed.
- The agents' output shape through the real binary: a transcript holding a
  `plan-review-backend` result ending in the four-backtick `Patches:` block
  → `applied backend#1 Goal` / `applied 1, unmatched 0, sha be4f504ef257`,
  exit 0; step 8's `role: "person"` patch object → `applied person#1 Goal`,
  exit 0; two merge rows in the ledger → observed.
- A real `/plan-review` round on the new agents is Phase 4 of the canonical
  plan (the first three reviews are what it measures).

## Decision log
- 2026-10-11 — pointer plan: the decision and the reviews live in amont-agent.

## Implementation review

- Round 1 `approve-with-changes` (37k, 42 s), Delta `approve-with-changes` (40k, 85 s), final read `approve` (42k, 9 s).
- Fixed: the small remainder goes through `plan-apply` with a `patch` object (recorded and checked); `--record-fallback` is the subagent path only; exit 2 applied nothing; step 8 follows step 4.
- Would still check by hand (reviewer): that a real reviewer widens `old_string` until unique.
