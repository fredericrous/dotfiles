---
name: worktree-task
description: Create or tear down a per-task git worktree, isolated from the live checkout. Use at the start of substantive edit/commit work in any repo, and again when that work is done.
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

## Finish

Run from inside the worktree (or pass its path explicitly):

```bash
git status                      # confirm everything you care about is committed
git fetch origin -q
git rebase origin/main          # origin/main may have advanced since the worktree was created
git push -u origin <branch-name>
```

- If the rebase conflicts, resolve it in place — don't fall back to the live checkout to sort it out.
- Only after the push succeeds, remove the worktree from the **primary** checkout (not from inside itself):

```bash
cd <repo-root>
git worktree remove ../<repo>-wt-<slug>
```

- If `git worktree remove` refuses because of untracked files, inspect them first (don't `--force` blindly — it may be legitimate leftover build output, but check).
- This is a good moment to open the PR / follow the repo-ownership rule in CLAUDE.md (commit+push to main directly on owned repos unless the user asked for a PR).

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
