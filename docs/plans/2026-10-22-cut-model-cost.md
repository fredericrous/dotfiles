---
canonical: relais:docs/plans/2026-10-22-cut-model-cost.md
phases: [A]
status: active
---
# Cut model cost where the money is (pointer)

The plan lives in relais, which owns ADR-0001 (the session router) and
ADR-0006 (typed research routing). This repository carries Part A: an Opus
advisor behind the routed session (`advisorModel`), with the reviewer agents
pinned to Opus first so the router never lowers them.

## Verification

- Probe: `claude -p --model sonnet --advisor opus` → advisor ran:
  `~/.claude/projects/-private-tmp-claude-501-advisor-probe/5992a938-81bb-4e8a-b5ff-812c65d64eb4.jsonl:29`
  holds `"type":"server_tool_use",…,"name":"advisor"`; Opus 26,185 input tokens, $0.116 per consult,
  uncached. `--model haiku --advisor opus` → Opus $0.115. Both through the local proxy.
- `grep -L '^model:' dot_claude/agents/*.md` → empty (13 pinned).
- Deviation from Part A step 4: no full `chezmoi apply`. The live `~/.claude/settings.json` holds keys the
  source lacks (apiKeyHelper, ANTHROPIC_BASE_URL, amont-agent hooks, relais paths; `chezmoi status`: MM),
  so only the 13 agent targets are applied, and the same `advisorModel` line goes into the live file by
  hand. holds-until: the live-only keys are reconciled into the source.

## Implementation review

approve-with-changes. Both findings fixed here: the targeted-apply deviation and the probe record above.
29.8k tokens, 38 s.
