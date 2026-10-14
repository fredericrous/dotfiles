# Full reviews — Always-on text becomes an index

### backend — round 1: approve-with-changes (36k tokens, 51 s)
1. [high] worktree-task/SKILL.md:347 still sends agents to the unreachable `gwt-stash-*` helpers → accepted, fixed in the same PR, grep check.
2. [medium] Parallel sessions can append to MEMORY.md during the rewrite → accepted, sha256 at backup, re-hash before write, dropped-link check after.
3. [medium] Baseline windows straddle stance changes; some ids may not be in the journal → accepted, per-rule stance window, ids confirmed.

### backend — round 2: approve-with-changes (33k tokens, 30 s)
All three resolved; no blocker. Carried into implementation:
1. [medium] The new stash line names only the `git stash push -u -m <tag>` form, never the helpers, so `grep -r gwt-stash dot_claude/` prints nothing.
2. [low] Phase 3 Verification also checks the sha256 re-hash and the 0-dropped backup-link script.
3. [low] Phase 1 Verification lists stance, raw count and id confirmation per rule.
