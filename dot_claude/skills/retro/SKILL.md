---
name: retro
description: Retrospective on one or more sessions: finds where the agent lost time or made a mistake, and proposes the harness change that stops it, most severe first.
disable-model-invocation: true
---

# retro

You do a **retrospective**. You do not fix the session's task. You find what
in the agent's **environment** made the session slower or wrong, and you
propose the one change that stops it next time. You change nothing. The
person picks.

Adapted from mattpocock/skills (see [NOTICE.md](NOTICE.md)).

## 1. Find the sessions

- **Arguments are transcript paths**: use them.
- **No argument**: use the current session. It is the newest `*.jsonl` in
  `~/.claude/projects/<slug>/`, where `<slug>` is the cwd with every `/` and
  `.` changed to `-`. Before you read it, write the file name and the
  session id, so the person can correct you.

A transcript is large (often 10–60 MB). Never read one whole. Read it with
`jq` filters and `grep -n` windows. These filters give the signal:

```sh
T=<transcript.jsonl>
# what the person typed (corrections live here)
jq -r 'select(.type=="user" and (.message.content|type)=="string") | .message.content[0:400]' "$T"
# tool calls that failed
jq -c 'select(.type=="user") | .message.content[]? | select(.type=="tool_result" and .is_error==true) | .content|tostring|.[0:300]' "$T"
# tool calls by name, most used first
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$T" | sort | uniq -c | sort -rn
# skills that ran
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$T"
```

Also read:
- the amont-agent journal lines for the session: `grep ' <id8> '
  ~/.claude/amont-agent/journal.log` (`<id8>` is the first 8 characters of
  the session id; the 4th field is the stance: `deny`, `advise`, …);
- `amont-agent mine`: mistake shapes that no rule names yet.

Done when you can name, for each session, its task in one line and its
three most expensive moments (time, tokens or a wrong result), each with a
line of evidence.

## 2. Find candidates

Look for candidates in each class. A class with nothing is fine; say so.

- **Navigation**: the agent searched long for a file, a command or a fact.
  Would one pointer have found it?
- **Automated checks**: the agent made a mistake that a lint, a type check,
  a test or a hook could catch. First look for a check that exists but is
  not wired, or fails open. That is the finding, not a new check.
- **Coding rules**: the review did not catch a mistake. Is a rule missing,
  unclear, or not enforced?
- **Always-on text**: CLAUDE.md, MEMORY.md, skill descriptions. Is a line
  wrong, stale, or too long (`guidance.always-on-is-an-index`)? Did a skill
  not fire when it should have (for example `diagnosing-bugs` on a red
  check), or fire when it should not have (`guidance.pointer-names-when`)?
  Does a prohibition lack its positive target (`guidance.state-the-target`)?
- **Tool economy**: a call that returned much more than it needed (a whole
  file, a full log, a re-read), or a slow loop.
- **No-ops**: an instruction that changes nothing, because the model does
  it anyway (`guidance.delete-no-ops`).
- **Information access**: the agent did not have a log, a metric, or a
  read-only view that would have answered the question.

## 3. Give each candidate exactly one fix

Use the first fix that applies:

1. **Mechanical mistake** (a fixed pattern, a banned command, a path rule):
   an amont-agent rule (a hook), or an amont check in the repo's
   `amont.conf`. A check is better than a written rule.
2. **Judgement call**: a proposed aval rule or ADR in the `decisions`
   corpus. You propose it; the person decides it.
3. **Missing pointer**: one index line in CLAUDE.md or MEMORY.md, or a skill
   description made sharper.
4. **No-op or stale text**: delete it.
5. **A fact only this machine knows**: a memory file.

If an earlier report in `~/.claude/retro/` already proposed the same fix,
drop the candidate, unless its evidence is new. Then say "again, new
evidence".

## 4. Report

Print the list in your reply, most severe first (no file: a headless run captures the reply). Severity is the cost if nothing changes:
a wrong result before lost time, lost time before lost tokens.

For each candidate:

```
### <n>. <one-line title>  (severity: high | medium | low)
Evidence: <transcript path:line, or the tool call and its result, short>
Fix: <the one fix>  →  <where it lands: file, repo, rule id>
```

Start the report with one line: `candidates: <N>`.

Done when every candidate has evidence and exactly one fix. Retro does not
apply any fix.
