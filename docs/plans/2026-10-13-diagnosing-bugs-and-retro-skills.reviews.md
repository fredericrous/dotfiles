# Full reviews — Diagnosing-bugs and retro skills

### backend — round 1: approve-with-changes (41k tokens, 43 s)
1. [medium] Upstream commit not named → accepted, sha 49dd158 in Goal.
2. [medium] private-refs fails open without the terms file → accepted, expect the scanned count.
3. [medium] Loop types, tightening, flaky section, agent-runnable dropped; HITL script unaddressed → accepted.
4. [medium] Phase 2 checks unobservable → accepted, transcript id and jsonl grep.
5. [low] One-line description check too weak → accepted.
6. [low] retro current-session lookup unspecified → accepted.
7. [low] ADR-0029 missing from adrs → accepted.

### backend — round 2: approve-with-changes (30k tokens, 16 s)
All 7 resolved (6 in part). Carried into implementation:
1. [low] retro states the jsonl file and session id it chose before reading.
2. [medium] Verification: `retro` (disable-model-invocation) is absent from the model list, runs as `/retro`; check split accordingly.
3. [low] Record main's private-refs scanned count before branching.

### backend — delta (person: "how will claude know when to run these skills"): approve-with-changes (41k tokens, 36 s)
1. [blocking] `claude -p "/retro …"` may not run a slash skill headless → accepted, SKILL.md body as prompt + spike.
2. [high] jq missing, one call for 3 sessions starves → accepted, $1 per session, size limit.
3. [medium] batch session could flag itself → accepted, fixed cwd excluded.
4. [medium] silent launchd failure → accepted, StandardErrorPath, `candidates: N`, 10-19 report check.
5. [medium] plist `~` / bootstrap failure aborts apply → accepted.
6. [low] trigger test touched live skills; noisy → accepted, scratch cwd, borderline re-run.

### backend — delta round 2: approve-with-changes (36k tokens, 53 s)
7. [high] bypass mode leaves Write open → accepted, `--permission-mode default --disallowedTools …`.
Carried into implementation: 8 [medium] one report from 3 calls — header N summed, per-session sections with `total_cost_usd`, a failed call keeps the others; 9 [low] drop the unused `RETRO_WEEKLY=1`; 10 [low] review header names the delta (done).

### backend — binding the final body: approve (28k tokens, 26 s)
Carried into implementation: [low] spike also probes a `jq … > file` redirect; expected refused, no file.
