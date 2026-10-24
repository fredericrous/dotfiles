---
canonical: decisions:docs/plans/2026-10-24-code-rules-reach-the-reviewer.md
phases: [2]
status: active
---
# Code rules reach the reviewer (pointer)

Canonical plan: [decisions/docs/plans/2026-10-24-code-rules-reach-the-reviewer.md](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-10-24-code-rules-reach-the-reviewer.md) (ADR-0044).

This repository carries Phase 2's skill and agent edits:
- worktree-task F4b step 2 builds the implementation-review brief with `amont-agent review-brief` (amont-agent 3.2.0), never by hand;
- step 3 and the implementation-review agent carry the `<<<RULES sha=…>>>` line the push check reads.

The `Candidates:` block (phase 4) comes in a later PR.
