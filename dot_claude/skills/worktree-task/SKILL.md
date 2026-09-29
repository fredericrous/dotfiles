---
name: worktree-task
description: Create or tear down a per-task git worktree, isolated from the live checkout — landing the approved plan as the first commit and running the verification loop (and, for UI, the localhost preview) before the single push. Use at the start of substantive edit/commit work in any repo, and again when that work is done.
---

# worktree-task

Standing rule (see `~/.claude/CLAUDE.md` § Git worktree isolation for agent work): do substantive edit/commit work in a per-task worktree, not the shared/live checkout — the user runs their own git activity (branch switches, commits, releases) in that same checkout concurrently, and collisions have repeatedly clobbered uncommitted work on both sides.

This repo's own convention for worktree paths (observed across duro-app, trade-agents, sre-agent, grid, website-builder, homelab, gtm-agent, stealth-fetch, duro-design-system, gt, application-landscape): a **sibling directory** named `<repo>-wt-<slug>`, e.g. `../duro-app-wt-toast`, `../sre-agent-wt-provenance`. Use that convention unless the user specifies otherwise.

## Args

- `args` empty, or `start <slug>` / `<slug>`: **start** mode — create a new worktree.
- `args` = `finish` / `done`: **finish** mode — rebase, push, and remove the *current* worktree (run this from inside the worktree, or pass the path).
- `args` = `cleanup <slug>` / `remove <slug>`: **cleanup** mode — abandon and remove a worktree without pushing (use for scrapped work; confirm with the user before discarding uncommitted changes).

If no slug is given in start mode, derive a short kebab-case one from the task at hand and confirm it with the user before creating the worktree.

## Start

```bash
cd <repo-root>
git fetch origin -q
git worktree add ../<repo>-wt-<slug> -b <branch-name> origin/main
```

- Pick `<branch-name>` following this repo's existing convention (check recent branch names via `git branch -a` / `git log --all --oneline -20` if unsure — e.g. `feat/…`, `fix/…`).
- After creating it, `cd` into the new worktree path for the rest of the task. Confirm you're on the right branch with `git branch --show-current` before editing.
- Do NOT symlink `node_modules` or other deps into the worktree as a shortcut — it has broken dev-server file resolution before (see `application_landscape_e2e_debug_traps` project memory). Let the worktree install its own deps.

### Land the plan (fleet ADR-0022, `work.plan-lives-in-the-repo`)

The approved plan is the branch's FIRST commit, before any code.

1. **Which plan.** The path this session's ExitPlanMode result gave. If this
   session approved no plan, ask the person for the path. Never pick the
   newest file in `~/.claude/plans/` — with parallel sessions, mtime is not
   task identity.
2. **Reuse before writing.** If `docs/plans/` already holds an `active` plan
   for this work, continue it instead of adding a second one.
3. **Write it** as `docs/plans/<approval-date>-<slug>.md` (slug: the H1,
   kebab-case, ≤5 words), with front matter per
   [plan-template.md](plan-template.md): `status: active`, `branch`, `repos`,
   `adrs`. When this repo is not the plan's home (the repo owning its
   decision), write a **pointer file** of the same name instead
   (`canonical:`, `phases:`, `status:` for this slice).
4. **Check its review** (`work.plan-review-panel`), before writing it:
   - **No `## Review panel` heading** (a plan from before amont-agent
     2.22.0, or one the person had skipped): land it as it is, with a
     one-line note in its Decision log.
   - **The section is there:** the last line must be the machine comment
     with a `body-sha`. If it is not, refuse; never treat the plan as
     unreviewed.
   - **Compare the sha:** run `amont-agent plan-sha --short <source>` on
     the approved source file in `~/.claude/plans/` (the file the hook
     judged). Never run it on the landed copy, whose front matter
     `plan-sha` does not strip. It must equal `body-sha`.
   - **On a mismatch** (the body changed after its review), do not land.
     Either re-run `/plan-review` as a delta and land once it passes, or
     the person accepts it unreviewed, recorded in one Decision-log line.
   - **Where the reviews go:** move `## Full reviews (reference)` into a
     sidecar, `docs/plans/<name>.reviews.md`. Link it from a
     `📄 Full reviews:` line inside `## Review panel`, which is outside
     the reviewed body.
   - **Check the landed copy:** `amont-agent plan-sha --short <landed>`
     must still equal `body-sha`. Since 2.22.1, `plan-sha` skips front
     matter.
5. **Commit it alone** (with its sidecar): `docs(plan): <slug>`.

Skip all of this for a change describable in one sentence: it joins the
open batch branch with no plan (`work.ceremony-scales-with-size`).

**Duro stack, new screen or material UI choice** (`handoff.fresh-directions-trigger`):
before implementing, run `/duro-mockup` for 2–4 directions (`duro mockup
check` must pass), let the person pick through options, and commit the
picked artboard on this branch. A fix that restores an existing design
reuses the picked artboard.

## Finish

Run from inside the worktree. The steps are labelled; every "return to"
below names one of them.

- **F1. Rebase.** `git fetch origin -q && git rebase origin/main`. Resolve
  conflicts in place, never in the live checkout.
- **F2. Verification loop** (`work.verification-loop-before-push`). Check
  the changed behaviour observably, against the plan's Verification section:
  - UI: Claude in Chrome on the local dev server — open the changed route,
    exercise the interaction (click, type, mobile width), read console and
    network, screenshot; on the Duro stack, beside the picked artboard
    (`handoff.prove-fidelity`). Put the two side by side and list every
    difference BEFORE the guide: fix each, or name it
    `deliberate: <reason>`. When accessibility seems to need a design
    change, look first for a fix that keeps the design (an `sr-only`
    copy, aria, a live region outside the control).
  - Non-UI: a piloted run (`run` skill) — the CLI on a real input, the
    service plus requests, an operator on kind, `kustomize build` /
    `flux diff`. A focused test can be the check for a library, test-only
    or docs change; a green general suite alone never is.
  - Budget: one attempt plus at most 3 repairs of the same failure, then
    stop and report without pushing. Missing credentials or infrastructure
    is a blocker report, not a fix. Changes the person asks for do not
    count against the budget.
- **F3. Record.** In the plan: input → expected → actual per check, tick
  the phases, append Decision log / Outcome. Set `status: done` only if
  verification passed AND this PR implements the last phase. Offer to turn
  a lasting decision into an ADR in this same PR
  (`work.lasting-decisions-become-adrs`). Screenshots and raw output go
  OUTSIDE the worktree (`~/.claude/amont-agent/attestations/<sha>/`).
- **F4. Commit.** Where amont is installed this commit IS the project gate
  (ADR-0009 runs the tests at pre-commit); only a repo without amont runs a
  separate `make check` or equivalent here. Run `git status` first and
  stage explicit paths.
- **F5.** If the SHA to push differs from the verified tree in more than
  the plan commit, return to F2.
- **F6. Non-UI push.** `amont rehearse --wait` where amont is installed,
  then `git push -u origin <branch>` bare, confirm with
  `git ls-remote origin refs/heads/<branch>`, and open ONE pull request
  whose body carries the verification record.
- **F7. UI push** (the push carries interface changes in a repository with a
  user interface; fleet ADR-0023, `work.preview-is-guided`). The person works
  on several projects at once and will not remember where this one stood.
  **Never ask for an approval without a guide.**
  1. Install from the lockfile, frozen (`npm ci`, `pnpm install
     --frozen-lockfile`), so the tree stays clean; start the dev server on a
     free port and keep it up until the person answers.
  2. **Screenshots.** Take `before.jpg` from `origin/main`'s build or from a
     step taken earlier, and `after.jpg` from this commit, at the same route
     and state. Put them in `~/.claude/amont-agent/attestations/<short-sha>/`,
     outside the worktree.
  3. **Write the guide** in that directory as `guide.md`, from
     [preview-guide-template.md](preview-guide-template.md). Fill every
     section:
     - Where we are;
     - What you should see;
     - Try it: numbered steps, the exact URL, each click named by its visible
       label and position, and after each step what should appear;
     - Reference;
     - Already checked.
     Write it for someone who has not seen this session.
  4. **Register it**, as its own foreground command (a leading
     `cd <worktree> &&` is fine; copying images next to the guide is a
     separate command before it, never chained):
     `amont-agent preview register --url <url> --guide <that guide.md> --open`
     It refuses an incomplete guide. `--open` opens the rendered guide page
     in the person's browser.
     Its JSON prints `label` (and `aliases`): the question in step 6 names
     one of them, or the answer approves nothing. A register that did not
     bind says so right after it runs; run the command it prints.
  5. **Open the app for them** with Claude in Chrome: a tab at the URL,
     already at the state step 1 of "Try it" reaches (for example the panel
     already open). Say which tab it is.
  6. **Print the brief in the terminal**: the guide's sections, short. Then,
     in the SAME turn, ask ONE marked question with AskUserQuestion:
     - its text begins with the project and the one-line change, then
       `[preview <id>]` and every `repo@<7-char sha>` it covers;
     - options exactly `Approve`, `Request changes`, `Hold`, with no
       "(Recommended)" suffix;
     - never pre-fill `answers`.
  7. On `Approve` (or the person typing `approve`/`ship`/`lgtm`/`looks
     good` as the next prompt), push as in F6. On `Request changes`, apply
     what the person describes, then return to F1. On no answer, wait with
     the server up.
  - An approval given before the person had a guide is not informed. Hold
    the push, give the guide, and ask again.
- **F8.** Any code change or rebase after F4 returns to F1.

No release unless the person asks for one (`work.release-on-request`).

Only after the push succeeds, remove the worktree from the **primary**
checkout (not from inside itself):

```bash
cd <repo-root>
git worktree remove ../<repo>-wt-<slug>
```

- If `git worktree remove` refuses because of untracked files, inspect them first (don't `--force` blindly — it may be legitimate leftover build output, but check).
- One implementation pull request per repo per plan (`work.one-implementation-pr-per-repo-per-plan`); merge it with the `merge-when-green` skill.

Then sweep any *other* worktree in this repo that became redundant while you were
working — a merged PR elsewhere does not clean itself up:

```bash
python3 ~/.claude/tools/worktree-sweep/sweep.py --repo <repo> --apply
```

It removes only worktrees that are clean, fully pushed, merged, and contained in a
release tag; anything it cannot verify is left alone. See the `worktree-sweep` skill.

## Cleanup (abandon)

```bash
cd <repo-root>
git status --short              # sanity check what's about to be discarded, from the worktree path
git worktree remove --force ../<repo>-wt-<slug>
git branch -D <branch-name>     # only if the branch was never pushed / isn't needed
```

Confirm with the user before this mode if the worktree has any uncommitted work — this is the one destructive path in this skill.

## Never

Don't use `git stash` inside a worktree to move work between it and another checkout — `refs/stash` is shared across all worktrees of a repo. See the "Git stash policy (worktrees)" section of `~/.claude/CLAUDE.md` and use `gwt-stash-save`/`gwt-stash-pop` if a stash is genuinely needed.
