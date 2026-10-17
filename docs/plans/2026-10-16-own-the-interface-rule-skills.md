---
canonical: decisions:docs/plans/2026-10-16-own-the-interface-rule-skills.md
phases: [3]
status: active
---

Part of [Own the interface rule skills, split between the fleet and Duro](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-10-16-own-the-interface-rule-skills.md). This repository carries phase 3: the fork of accessibility, layout, writing, interface and interface-review, the rename script, motion-design, and the review wiring (plan-review agents, the interface-review agent, worktree-task F4b step 2b).

## Observed (phase 3, steps 1–6)

| Check | Expected | Actual |
|---|---|---|
| `make check` | tools, render, lint, private-refs ok | `ok tools render lint private-refs`, exit 0 |
| `grep -rn --exclude=NOTICE.md better- dot_claude/skills/{accessibility,layout,writing,interface,interface-review}` | 0 lines | 0 lines |
| relative-link check over the six skills | 0 broken | 0 broken |
| `fork-interface-skills.sh` rerun on upstream `4c66b1f` into a scratch dir | exit 0; differs from committed files only by the local edits | exit 0; differences are the precedence block and reconciled clauses |
| same script, a planted `better-xyz` in a copy | non-zero | exit 1 |
| `shellcheck scripts/fork-interface-skills.sh` | clean | clean |

Steps 7 (deploy) and 8 (trigger tests) run after the merge and the Duro release; their results go in the canonical plan.

## Implementation review

- Round 1 approve-with-changes (38k, 45 s); Delta approve-with-changes (39k, 9 s). Fixed: NUL-safe loop, 16px fallback in the accessibility NOTICE, step 2b launch wording. deliberate: `relais.toml` is its own commit (15a3f0e, person-approved onboarding).
