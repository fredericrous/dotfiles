# Reviews: 2026-09-29-review-panel-phase-4

## Full reviews (reference)

- **Backend, round 1 (approve-with-changes, 35k tokens, 45 s):**
  1. [high] Front matter enters the hash, so the landing check can never
     match on the landed file. Check the source instead, and put the
     sidecar link in the review section.
  2. [medium] A mismatch was a dead end. Add a delta re-review, or an
     unreviewed acceptance recorded in the Decision log.
  3. [medium] ux-research web queries could leak private names; the
     5-search limit is only a soft cap.
  4. [medium] No cost numbers: an unbriefed 9-agent round is 360–720k
     tokens.
  5. [low] Agent types load at session start.
  6. [low] The edited-plan check had no concrete input.
- **Backend, round 2 (approve-with-changes, 30k tokens, 36 s):** findings
  1–5 resolved. Finding 6 was not: a line appended after the machine
  comment tests the "missing review" branch. New: say that a missing
  section means an absent heading, and that a present one with a bad
  comment is refused. The ux-research tools also belong in the shape
  bullet.
- **Backend, confirmation (approve, 27k tokens, 8 s):** both resolved;
  nothing new.
