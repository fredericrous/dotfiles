# Plans

An approved plan is the first commit of its task branch (ADR-0022,
`work.plan-lives-in-the-repo`). This directory is history, read on demand,
and never loaded into every session (`work.plans-are-not-context`). What is
true now lives in the rest of `docs/`; what was decided lives in
`docs/adr/`.

**File name.** `YYYY-MM-DD-<slug>.md`. The date is the approval date. The
slug is the plan's H1 in kebab-case, five words at most.

## Template

```markdown
---
status: active            # active | done | abandoned | imported
branch: feat/<name>
repos: [<this-repo>]      # every repository the plan touches
adrs: []                  # records this plan adds or relies on
---
# <Title>

## Goal
What changes for whom, in two or three sentences.

## Non-goals
What this deliberately leaves alone.

## Behaviour
The observable behaviour after the change. This is the spec. Link a picked
artboard here when one exists (handoff.prove-fidelity).

## Preview
evidence: <why the person will have nothing left to judge: the visible change
is one this plan decides, and the screenshot comparison will show nothing else>

Optional, for an interface change (ADR-0028); delete the section to have the
person preview the commit as usual. The `evidence:` line must stay the first
line under the heading.

## Phases
- [ ] Phase 1 — <one line>; becomes one or more commits
- [ ] 🧑 decision: <question the person answers, with 2–4 options>
- [ ] Phase 2 — …

## Decision log
- YYYY-MM-DD — <decision>, because <reason>. (A scope change is recorded
  here, never as a silent rewrite of the sections above. A lasting decision
  becomes an ADR and is linked from here.)

## Verification
Per phase: what is driven → what should be observed → what was observed.
- Phase 1: open `/settings`, toggle "Compact" → list density changes and
  survives a reload → <result, screenshot path>
- "Tests pass" is not a check (`work.verification-loop-before-push`).

## Outcome
Filled when the plan closes: what shipped, what did not, and what surprised.
```

## Status

| status | meaning | editable |
|---|---|---|
| `active` | phases open | tick phases; append Decision log, Verification, Outcome |
| `done` | every phase implemented and verified | frozen; a follow-up is a new plan |
| `abandoned` | stopped, with the reason in Outcome | frozen |
| `imported` | a legacy plan moved here, completion not established | frozen |

Merge state is never written here; git records it.

## Pointer files

A plan that spans repositories lives in the one that owns its decision.
Each other repository carries a pointer with the same file name:

```markdown
---
canonical: decisions:docs/plans/2026-09-28-plans-and-preview.md
phases: [2]               # the phases this repository carries
status: active            # this repository's slice only
---
Part of [<title>](<link to the canonical plan>).
```
