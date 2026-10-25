---
canonical: decisions:docs/plans/2026-10-24-code-rules-reach-the-reviewer.md
phases: [2, 4]
status: active
---
# Code rules reach the reviewer (pointer)

Canonical plan: [decisions/docs/plans/2026-10-24-code-rules-reach-the-reviewer.md](https://github.com/fredericrous/decisions/blob/main/docs/plans/2026-10-24-code-rules-reach-the-reviewer.md) (ADR-0044).

This repository carries Phase 2's skill and agent edits:
- worktree-task F4b step 2 builds the implementation-review brief with `amont-agent review-brief` (amont-agent 3.2.0), never by hand;
- step 3 and the implementation-review agent carry the `<<<RULES sha=…>>>` line the push check reads.

The `Candidates:` block (phase 4) comes in a later PR.

## Verification

- `amont-agent --version` after `brew upgrade fredericrous/tap/amont-agent` → 3.2.0, listing `rules-sha` and `review-brief` → 3.2.0, both listed.
- `amont-agent review-brief -C <amont-agent worktree> --plan=<canonical plan>` → a brief whose TREE and RULES lines bound amont-agent#142's own implementation review → it built that brief, and the review bound to it.
- `amont-agent review-brief -C <this worktree> --plan <canonical plan>` → exit 3, since this repository has no `.adr.yaml` → exit 3, aval says "no .adr.yaml".

`chezmoi apply` runs after the merge; its result is recorded in the decisions PR that records Phase 2.

## Implementation review

- approve-with-changes, then approve-with-changes on the Delta. Fixed: the reviewer contract's no-corpus case, exit 1 named, the repeated lines kept, the Delta's fresh RULES line.
- deliberate: the Delta step does not yet say "none in a repository with no `.adr.yaml`"; phase 4's dotfiles PR edits this same paragraph for the `Candidates:` block and adds it.
- 41k + 44k tokens.

## Phase 4

This repository carries Phase 4's skill and agent edits:
- F4b's brief lists the `<<<CANDIDATES …>>>` block that amont-agent 3.3.0 prints;
- step 3 and the Delta paste that block verbatim into the reviewer's prompt, after the RULES line;
- the implementation-review contract adds a `Candidates:` block ruling on every listed id, which the push check reads; the output word cap leaves that block out;
- the no-corpus exception goes, since `review-brief` now handles a repository with no `.adr.yaml`.

The Delta's "none in a repository with no `.adr.yaml`" note (Phase 2's deliberate) lands here.
