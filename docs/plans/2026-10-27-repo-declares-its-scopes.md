---
canonical: github:fredericrous/aval/docs/plans/2026-10-27-repo-declares-its-scopes.md
phases: [4]
status: done
branch: docs/scope-membership
---
# A repository declares the scopes it is in

Pointer. The plan lives in aval (aval#46, 1.11.0); the ADR is decisions
ADR-0046 (decisions#102). This repository carries the dotfiles part of
Phase 4: the interface, layout, writing, accessibility and interface-review
skills, worktree-task step 2b and the interface-review agent now say that
`aval resolve <key>` answers at the repository's declared `in_scopes`, with no
hand-typed `--scope`.

## Verification record

- The two phrasings ("resolved at its applicable scope", "at the diff's
  scope") → replaced in all 7 files → 7 replacements in the source, 7 in the
  live `~/.claude` copies; each source file is byte-identical to its live copy
  (the laptop is the source).
- The behaviour the text now names → a scratch UI change in customer-vision
  (declared `[effect-stack, duro-stack]`) → `amont-agent review-brief` carried
  `ui.design-system` (ADR-0006 at duro-stack), `ui.measures`,
  `stack.web-framework`.
