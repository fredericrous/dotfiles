---
canonical: decisions:docs/plans/2026-11-02-show-the-page-before-asking.md
phases: [4]
status: active
---
# Show the page before asking about it (pointer)

Canonical plan: [decisions/docs/plans/2026-11-02-show-the-page-before-asking.md](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-11-02-show-the-page-before-asking.md) (ADR-0058, rule `work.page-shown-before-asked`).

This repository carries Phase 4: the always-on CLAUDE.md line about pages for the person names `amont-agent open '<url>'` (amont-agent 3.16.0) and the `ask-unopened-page` hook, instead of `open '<url>'`. The laptop's `~/.claude/CLAUDE.md` was edited first, and the template is patched from it.

## Code review

- dotfiles: none — one line of the CLAUDE.md template

## Verification

| Check | Actual |
| --- | --- |
| template renders the laptop | `diff <(chezmoi --source <worktree> cat ~/.claude/CLAUDE.md) ~/.claude/CLAUDE.md`: empty; the old source differs on lines 41-42; template directives 2 before and after |
| secret scan | the only token-shaped line is the existing `~/.netrc` mention (no secret) |
