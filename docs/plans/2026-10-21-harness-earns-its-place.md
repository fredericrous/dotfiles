---
canonical: decisions:docs/plans/2026-10-21-harness-earns-its-place.md
phases: [3]
status: done
---
# A harness part earns its place on each model (pointer)

The plan lives in decisions, which owns ADR-0042. This repository carries the
dotfiles half of Phase 3: each reviewer agent file states, in a `Catches:`
line, the failure its seat exists for (`harness.part-names-its-failure`).

## Implementation review

- Phase 3 (dotfiles): approve after two deltas. Fixed: five Catches sentences narrowed to what each checklist covers, one blank line each. Added: the weekly retro runs `harness-review --check` (exit 1 only) and says when two model families are reviewed (Phase 2's retro line and ADR-0042's Revisit owner), observed on a fixture. Deferred to decisions: interface-review.md in the plan's Phase 3 list.
