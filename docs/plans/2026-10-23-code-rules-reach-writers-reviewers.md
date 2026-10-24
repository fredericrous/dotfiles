---
canonical: github:fredericrous/aval/docs/plans/2026-10-23-code-rules-reach-writers-reviewers.md
phases: [4]
status: active
branch: docs/code-rules-full-text
---
# Code rules reach the agent that writes and the agent that reviews

Pointer. The plan and its review panel live in aval (aval#42); the ADR is
decisions ADR-0043 (decisions#86). This repository carries Phase 4: the
implementation-review brief built by `worktree-task` F4b carries the full text
of the `governs: code` constraints and the decisions that apply to the changed
files, and the `implementation-review` agent blocks on a code-rule violation the
diff introduces, deletions included.
