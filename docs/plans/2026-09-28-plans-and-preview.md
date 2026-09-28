---
canonical: decisions:docs/plans/2026-09-28-plans-and-preview.md
phases: [3]
status: active
---
Part of [Plans in the repo, one PR per plan, a verification loop before
push](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-09-28-plans-and-preview.md).
This repository carries Phase 3: the `worktree-task` and `merge-when-green`
skills, the global `CLAUDE.md` pointer, and the drifted `settings.json`
re-added with the preview-approval hook targets.

## Decision log (this slice)

- 2026-09-28: the `"model": "opus[1m]"` override is dropped from the managed
  `settings.json` (the person's call); the live file already has none.
- 2026-09-28: `dot_claude/CLAUDE.md.tmpl` already existed. It is brought up
  to date with the live file, not added.
