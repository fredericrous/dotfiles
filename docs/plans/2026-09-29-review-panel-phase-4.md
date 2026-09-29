---
status: active
branch: feat/plan-review-panel
repos: [dotfiles]
adrs: [ADR-0022]
---

# Review panel, Phase 4: the other nine reviewers

## Review panel

👉 **Decide:** none — approve if the nine reviewers should share the two existing ones' shape and contract, and landing should refuse a plan whose body changed after its review.
📍 dotfiles (no language, UI, ops, CLI or size signal). Panel: staff backend only; the first live run of `/plan-review`.
**Changed by review:** landing checks the sha on the approved source file, because front matter would break it on the landed copy; a mismatch has a way forward (a delta, or the person accepts it); ux-research searches generic terms only.
**Verdicts:** backend approve-with-changes (round 1, 6 findings) → approve-with-changes (round 2, 5 of 6 resolved, 2 new) → approve (a confirmation of the final body). 92k tokens in total.
📄 Full reviews: [2026-09-29-review-panel-phase-4.reviews.md](2026-09-29-review-panel-phase-4.reviews.md)

## Context

Phase 4 of `decisions:docs/plans/2026-09-29-plan-review-panel.md`. Phases
1–3 have shipped:

- the rule `work.plan-review-panel`;
- amont-agent 2.22.0, whose hook is on and refuses a plan without reviews;
- `/plan-review`, with its first two roles, `plan-review-language` and
  `plan-review-backend`.

Today a plan for a CLI, ops, large or UI repository needs reviewers that do
not exist yet:

- `amont-agent plan-panel` on website-builder lists 9 agents, and 7 of them
  are missing;
- the hook would refuse that plan twice, then ask the person to accept it
  unreviewed.

This plan adds the missing nine roles. It also moves the standing
instruction from "a Plan subagent as a staff engineer" to `/plan-review`,
and makes `worktree-task` check the review when it lands a plan.

## Design

### The nine agents

They live in `dot_claude/agents/plan-review-<role>.md`, in the shape of the
two that exist:

- front matter `name`, `description` and `tools: Read, Grep, Glob` (plus
  WebSearch and WebFetch for `ux-research` only), with no `model` field;
- read the review block's `path` first, then the shared brief;
- open at most 10 more files or 1,500 lines;
- the same output contract: a verdict, findings each with evidence and an
  edit, "what I would measure", and at most 350 words;
- for round 2 and deltas, the same answers: resolved, not resolved or new
  blocker.

Only the focus differs:

| agent | looks at |
|---|---|
| `platform` | Flux/GitOps rollout safety; requests and limits; PDBs; secrets (no Secret for public env); blast radius; rollback; the cluster's known constraints (the 100 Mb/s node uplink, Ceph fullness) |
| `unix` | stdin/stdout/stderr; pipes; exit codes; signals and EPIPE; environment and config precedence; no-TTY behaviour; clig.dev (ADR-0021) |
| `tui` | what a person sees and types; prompts and their non-interactive fallback; `NO_COLOR`; progress; errors a human can act on; narrow terminals and screen readers |
| `po` | the user outcome; scope and non-goals; what not to build; acceptance criteria; sequencing by value; what to measure after release |
| `architect` | boundaries and coupling across the repository and the fleet; fit with the decisions (`aval resolve` on the keys the brief names); evolution; cross-repository impact |
| `react` | component boundaries, state and effects; react-strict-dom and Duro rules (no hand-rolled layout, gaps go upstream); performance; accessibility; a11y-selector tests |
| `ui-design` | hierarchy, layout, states (empty, loading, error) and consistency on Duro tokens and components; the mockup contract (ADR-0016) |
| `ux-research` | backs each UX choice with cited research (NN/g, Baymard, WCAG, academic work) or flags it as unbacked; proposes a cheap test where nothing applies. Also gets WebSearch and WebFetch. Queries use generic UX terms only, never a repository, product or host name, because the plans are private. "At most 5 searches" is a soft cap written in the prompt, not an enforced one |
| `game-ux` | feedback loops and "juice" (ADR-0014); onboarding and tutorialisation; flow and friction; reward; discoverability |

### The standing instruction

In `dot_claude/CLAUDE.md.tmpl`, § Working method, the sentence "before
ExitPlanMode on a non-trivial plan, run a Plan subagent as a staff
engineer…" becomes:

> before ExitPlanMode, run `/plan-review`: it puts the plan through the
> review panel its repositories call for (`work.plan-review-panel`); the
> amont-agent hook refuses a plan without it

### Landing the reviewed plan (`worktree-task`, § Land the plan)

- **A new step before writing the plan into the repository:** run
  `amont-agent plan-sha --short` on the **approved source file** (the
  ExitPlanMode path in `~/.claude/plans/`), which is the file the hook
  judged. It must equal the machine comment's `body-sha`. The landed copy
  gains front matter, and `plan-sha` does not strip front matter, so the
  check runs on the source, never on `docs/plans/<name>.md`.
- **On a mismatch** (the body changed after its review), do not land.
  Either re-run `/plan-review` as a delta (backend plus any new area) on
  the current body and land after that passes, or the person accepts it
  unreviewed and the Decision log records that in one line.
- **Where the reviews go:**
  - The `## Full reviews (reference)` section moves into a sidecar,
    `docs/plans/<name>.reviews.md`.
  - The link to it goes inside `## Review panel`, which is outside the
    canonical body.
  - The landed body, without its front matter, therefore still hashes to
    `body-sha`.
- **A missing review section** means the `## Review panel` heading is
  absent. Such a plan, from before 2.22.0 or skipped by the person, lands
  as it is, with a one-line note in its Decision log. A plan that has the
  section but whose machine comment is not the last line, or has no
  `body-sha`, is refused. It is never treated as unreviewed.

## Phases

- [x] Phase 4a: the nine agent files; one commit.
- [x] Phase 4b: the `CLAUDE.md.tmpl` sentence and the `worktree-task`
  landing step; one commit.
- [ ] Phase 4c: apply, check live, then open the dotfiles PR carrying
  Phases 3 and 4.
- [ ] 🧑 decision (from the parent plan): after the first real UI plan, is
  the panel useful, the right size and worth its cost?

  **Cost to measure against:** without a brief, a reviewer costs 40–80k
  tokens, so a 9-agent website-builder round 1 would be 360–720k. With the
  shared brief, this plan's single backend review cost 35k tokens in 45 s.
  Record tokens and wall time per agent for round 1 and for deltas.

## Verification (input → expected → actual)

- **`chezmoi apply` of the new files:** in a new session afterwards, all
  11 `plan-review-*` agent types appear in the agent list. They may also
  hot-load into this one, as the first two did.
- **The website-builder plan panel:** every agent that
  `amont-agent plan-panel` lists for a website-builder test plan is an
  existing agent type (9 of 9).
- **One UI role live:** `plan-review-ux-research` on this plan returns the
  output contract, with each claim cited or marked unbacked.
- **The landing step on this plan:**
  - `plan-sha --short` of the source equals `body-sha`;
  - the landed file, with its front matter stripped and read through
    `plan-sha -`, gives the same sha after the sidecar split;
  - the sidecar holds the full reviews.
- **A plan edited after review:** add one line under `## Context` of a
  reviewed plan, keeping the machine comment on the last line, then land
  it → the mismatch is printed and no `docs(plan)` commit exists.
- **A machine comment moved off the last line:** landing refuses, and
  does not treat the plan as unreviewed.
- **`chezmoi diff`** is empty after the PR's files are applied.

### Actual (2026-09-29)

- **The live gate:**
  - the first ExitPlanMode of this plan, with no reviews → deny,
    `missing for repos=dotfiles: backend`;
  - after `/plan-review` → passed. The journal shows `denied` at
    `c0e60fae` then `passed` at `ded8d951`, and `plan-panel` then reads
    `current`.
- **Review cost:** backend 35k + 30k + 27k tokens (92k in total), in
  45 s + 36 s + 8 s of wall time.
- **Applying:** 11 `plan-review-*` agents on disk, the unmanaged `relais-*`
  agents kept, `chezmoi diff` empty.
- **The website-builder panel:** 9 of 9 agent files exist.
- **Agent types in this session:** the 9 new ones did not hot-load, so the
  one UI role run live is deferred to a new session.
- **The landing check:**
  - the source hashes to `body-sha` (`ded8d9517523`) → the plan lands;
  - a line added under Context → refused, `body=4c3d28aeff7b`;
  - the comment moved off the last line → refused.
- **The landed copy:** it first hashed to `b3afe3065c7c`, because of the
  blank line after the front matter. Stripping the front matter and that
  line gives `ded8d9517523`. The recipe in `worktree-task` now says so.

<!-- panel: repos=dotfiles reviewers=backend body-sha=ded8d9517523 -->
