---
canonical: decisions:docs/plans/2026-11-02-show-the-page-before-asking.md
phases: [4]
status: active
---
# Show the page before asking about it (pointer)

Canonical plan: [decisions/docs/plans/2026-11-02-show-the-page-before-asking.md](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-11-02-show-the-page-before-asking.md) (ADR-0058, rule `work.page-shown-before-asked`).

This repository carries Phase 4: the always-on CLAUDE.md line about pages for the person names `amont-agent open '<url>'` (amont-agent 3.16.0) and the `ask-unopened-page` hook, instead of `open '<url>'`. The laptop's `~/.claude/CLAUDE.md` was edited first, and the template is patched from it.

## Code review

- chezmoi: none — one line of the CLAUDE.md template (the dotfiles repository)

## Decision log

- 2026-11-03 — The laptop line went live before amont-agent 3.16.0, so for a few minutes every session was told to run a command the installed binary did not have (implementation review). It was put back to the old line until 3.16.0 is installed. This PR merges after that, and the laptop line is re-applied before the render check.
- 2026-11-03 — The wording differs slightly from the canonical plan's quote ("a preview or a question's options", "chrome-devtools MCP / Playwright"), to fit the line's width. The meaning is the same; accepted as written.

## Implementation review

- implementation-review: approve-with-changes, 2 findings recorded above (release order, wording); no change to the template. 30k, 23 s.

## Verification

| Check | Actual |
| --- | --- |
| template renders the laptop | `diff <(chezmoi --source <worktree> cat ~/.claude/CLAUDE.md) ~/.claude/CLAUDE.md`: empty; the old source differs on lines 41-42; template directives 2 before and after |
| secret scan | the only token-shaped line is the existing `~/.netrc` mention (no secret) |
