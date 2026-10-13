---
status: active
branch: feat/skills-diagnose-retro
repos: [dotfiles]
adrs: [ADR-0026, ADR-0022, ADR-0029]
---
# Diagnosing-bugs and retro skills

## Review panel
👉 **Decide:** none — approve if a tuned description (hook only if it under-fires by 10-20) and a weekly $3-capped Sonnet retro suit you.
📍 dotfiles · plan only · next: Phase 1 spike (headless retro, write-refusal, transcript sizes). Panel: backend (opus-5-5).
**Changed by review:** headless runs the SKILL.md body, not `/retro`; one $1 call per session, read-only even under bypass; launchd failures visible.
**Verdicts:** 2 rounds + delta (3 runs), final approve; 13 accepted; 5 carried into implementation (listed in Full reviews).
📄 Full reviews: [reviews](2026-10-13-diagnosing-bugs-and-retro-skills.reviews.md)

## Goal
Adapt two skills from mattpocock/skills (MIT, pinned at commit
`49dd158d1076134a641b33efb035946536778336`, fetched 2026-10-13; the sha is
recorded in each NOTICE.md) into the dotfiles skills, and make both run
without the person remembering them. `diagnosing-bugs` is a phase-gated debug
loop that Claude reaches for on its own, through a description tuned on the
person's real wording and tested. `retro` turns agent mistakes into hooks,
checks, rules or deletions, and runs weekly on its own over the sessions that
showed trouble; the person reads one ranked report a week.

## Non-goals
- No other upstream skill (grilling, tdd, pr, writing-for-agents,
  codebase-design stay out; each is a separate decision).
- No new aval rule or ADR. `retro` proposes them; the person decides.
- No change to amont-agent, amont or relais in this plan. A hook that nudges
  toward `diagnosing-bugs` is a follow-up plan, made only if Phase 4 shows
  the description under-fires.
- No verbatim copy: the text is rewritten to ASD-STE100
  (`guidance.prose-canon`) and to this fleet's tools.
- Upstream's HITL script is not ported.

## Behaviour

### How each skill gets triggered
Context-engineering sources consulted 2026-10-13: Anthropic's skill-creator
("Claude has a tendency to undertrigger skills … make the skill descriptions
a little bit pushy"; the description is "the primary mechanism" for
invocation; tune it with ~20 should/should-not prompts, near-misses
included), the Claude Code hooks guide (hooks give "deterministic control …
rather than relying on the LLM"), and "Effective context engineering for AI
agents" (start sparse, add instructions on observed failures).
- `diagnosing-bugs`: model-invoked. The description names the situations in
  the person's own words, mined from past transcripts. A trigger test gates
  it (Verification), and a dated count after one week decides whether a hook
  is needed (Phase 4).
- `retro`: cannot trigger in-session (it judges a session after the fact, and
  a `SessionEnd` hook has a 1.5 s budget, too short to run a model). A weekly
  launchd job runs it headless over the week's flagged sessions.

### `dot_claude/skills/diagnosing-bugs/SKILL.md` (model-invoked)
Description: one line (`guidance.always-on-is-an-index`), what + when, pushy.
Draft, to be replaced by the mined wording: "Debug loop for anything broken,
failing, flaky, slow or red: build a red loop first, then minimise, rank
hypotheses, instrument, fix, clean up. Use whenever the person reports a bug,
a check or test fails, CI is red, output is wrong, or a fix did not take."

Phases, each with a checkable completion criterion (upstream structure kept):
1. **Red loop.** One command, already run and shown (redacted), that goes red
   on the person's exact symptom, is deterministic and takes seconds. No
   hypothesis before it exists. Ways to build one, in order: failing test,
   curl, CLI with a fixture, browser via chrome-devtools MCP (reproduce the
   person's exact view: route, mode, zoom, state), replayed capture, throwaway
   harness, property/fuzz loop, bisection harness, differential loop. Tighten
   the loop (faster, sharper, deterministic); for flaky bugs, raise the
   reproduction rate. The loop must be agent-runnable. If no loop is
   possible: say so, list what was tried, ask.
2. **Reproduce + minimise** until every remaining element is load-bearing.
3. **Hypothesise**: 3–5 ranked, each with a falsifiable prediction; show the
   list to the person, do not block on it.
4. **Instrument**: one variable per probe; debug logs tagged `[DEBUG-xxxx]`;
   perf: baseline measurement first.
5. **Fix + regression test** at a correct seam; no correct seam is itself a
   finding.
6. **Cleanup**: loop green on the original scenario, tag grep empty, the
   confirmed hypothesis written in the commit/PR body.

Fleet adaptations (replacing upstream's GLOSSARY/ADR pointers):
- Start: `aval_relevant` on the paths involved, `aval_resolve` the keys it
  returns; a `contradiction` stops the work.
- **Prove the red is real**: a forced red must show the mutation landed
  (`diff`/`cmp`); a Rust re-run must print `Compiling <crate>` (same-second
  mtime trap); prove the file under test is the one the system loads (grep
  the object name in the applied config/bundle).
- Machine traps in the loop itself: `grep` skips gitignored paths
  (`--no-ignore-files`); every wait is bounded; a mutating command is never
  piped through `tail`.
- Redact section kept (secrets to `<REDACTED>`, loops read env vars).

### `dot_claude/skills/retro/SKILL.md` (person-invoked, also run weekly)
Frontmatter `disable-model-invocation: true`. Description: "Retrospective on
one or more sessions: finds where the agent lost time or made a mistake, and
proposes the harness change that stops it, most severe first."

Steps:
1. Read the sessions: the transcript paths given as arguments, else the
   current one (newest `*.jsonl` under the cwd's project slug; say the file
   and session id chosen before reading, so the person can correct it). Read
   with `grep`/`jq` windows, never whole. Also `amont-agent mine` (shapes no
   rule names yet) and the journal lines for each session id.
2. Find candidates in these classes: navigation, automated checks, coding
   rules, always-on text (CLAUDE.md, MEMORY.md, skill descriptions, including
   a skill that should have fired and did not), tool economy, no-ops,
   information access.
3. Map each candidate to exactly one fix, in this order of preference:
   - mechanical mistake → an amont-agent rule (hook) or an amont check
     (`amont.conf`) — a check beats a written rule;
   - judgement call → a proposed aval rule or ADR in `decisions`;
   - missing pointer → one index line (CLAUDE.md, MEMORY.md) or a skill
     description sharpened;
   - no-op or stale text → delete it;
   - a fact only this machine knows → a memory file.
   Before proposing a check, look for an existing one that is unwired or
   silently broken; that is the finding. Drop a candidate already proposed in
   an earlier report under `~/.claude/retro/` unless its evidence is new.
4. Present the list ranked by severity: evidence (transcript line or tool
   call), the fix, where it lands. Completion: every candidate has evidence
   and exactly one fix. Retro changes nothing itself; the person picks.

### Weekly batch: `dot_claude/tools/retro-weekly/executable_retro-weekly.sh`
POSIX sh (under `make lint`). Each run:
1. Selects sessions: session ids with a `deny` or `advise` line in
   `~/.claude/amont-agent/journal.log` over the last 7 days, ranked by count,
   top 3; each id resolved to its `~/.claude/projects/*/<id>*.jsonl`. None
   flagged → writes a one-line report and exits 0 without calling a model.
2. Runs, once per session, `claude -p` (not a `/retro` slash command, which
   `-p` may not run) with the installed retro SKILL.md body plus the session
   path as the prompt, `--model sonnet --max-budget-usd 1 --permission-mode default --disallowedTools Write,Edit,NotebookEdit` (a global bypass mode would otherwise leave every tool open), read-only tools
   (`--allowedTools Read,Grep,Glob,Bash(amont-agent mine*),Bash(jq *)` style
   list, settled in the Phase 1 spike), a fixed cwd
   whose project slug step 1 excludes; a session over the Phase 1 size limit
   is skipped and named. First report line is `candidates: N`. Output to
   `~/.claude/retro/YYYY-MM-DD.md`; a failure writes the exit code and stderr
   tail there instead.
3. Posts one macOS notification naming the report and the `candidates: N`
   value from its first line. The plist sets `StandardErrorPath` to
   `~/.claude/retro/launchd.err`.

Scheduling: `private_Library/LaunchAgents/com.fredericrous.retro-weekly.plist.tmpl`
(Mondays 08:57, `/bin/zsh -lc` so PATH finds `claude`), loaded by a
darwin-only `run_onchange_after_load-retro-weekly.sh.tmpl`
(`launchctl bootout` then `bootstrap gui/$(id -u)`, a failure only warns;
plist paths use `{{ .chezmoi.homeDir }}`, never `~`); ignored on other OSes
via `.chezmoiignore`.

### `NOTICE.md` in each skill directory
Source URL, upstream commit sha, MIT notice with Matt Pocock's copyright,
and one line saying the text is adapted. The repository is public, so this is
the license's condition, not a courtesy.

## Phases
- [x] Phase 1 — spike: run the SKILL.md-as-prompt call by hand on one flagged
  session; record the transcript bytes of the top-3 candidates, the cost, and
  that a non-empty candidate list returns and that a Write attempt is refused; settle the tool list and size
  limit. Then mine wording: grep the person's prompts in
  `~/.claude/projects/*/*.jsonl` (last 60 days) for bug reports; keep the 10
  most common phrasings (redacted, no private terms) as the description's
  triggers and as the positive trigger prompts.
- [x] Phase 2 — worktree on dotfiles: two skills, two NOTICE.md, the
  retro-weekly script, plist, loader, `.chezmoiignore` line; `make check`
  green; trigger test passes (Verification); one PR, merged on green.
- [ ] Phase 3 — `chezmoi apply` of the target files only, `cmp` each; run
  the batch once by hand (`launchctl kickstart`) and read the report.
- [ ] Phase 4 — 2026-10-20: count `diagnosing-bugs` Skill calls in the
  week's transcripts against sessions with a red check or a bug report; read
  the first scheduled report. Under-firing (fewer than half) → open the
  amont-agent hook plan; else close this plan.

## Decision log
- 2026-10-13 — Two skills only, because they fill gaps nothing in the
  harness covers; the rest overlaps plan-review, relais or
  implementation-review (analysis given to the person in this session).
- 2026-10-13 — The person will not run skills by hand. diagnosing-bugs:
  tuned description now, a hook only on observed under-firing (person chose
  over "hook now"). retro: weekly scheduled batch over flagged sessions
  (person chose over a session-end nudge or manual only).
- 2026-10-13 — Batch on Sonnet, one call per session with a $1 cap, at most 3
  sessions ($3 a week), because cost saving is a priority and retro reads.
- 2026-10-13 — Done in the session, not through relais: multi-file guidance
  plus scheduling whose acceptance includes reading a report.

- 2026-10-13 — Spike results: the SKILL.md body as a `claude -p` prompt
  works headless ($0.41 on a 2.3 MB transcript, $0.21 on 16 MB: `jq` windows
  keep the cost flat, so the size limit is 100 MB). Under `--permission-mode
  default`, `jq` on a transcript is refused outside the cwd, so the call adds
  `--add-dir ~/.claude/projects ~/.claude/amont-agent`. Tool list settled:
  Read, Grep, Glob, Bash(jq/grep/sort/uniq/head/wc/amont-agent mine).
- 2026-10-13 — Mined wording (8,178 person prompts, 60 days, 278 bug-like):
  "investigate why X fails", "figure out why", "look into the X
  failure/error", crash loop, flaky/red test, leak, "I tried X and got …",
  "still …". Near-misses are fixes whose cause is known ("fix the lint",
  "implement all 5 fixes"), so the description keys on "cause not known yet".
- 2026-10-13 — A neutral description triggered 3/10: every miss went
  straight to Bash. "Load this FIRST, before running any command or reading
  code" raised it to 7/10 then 8/10; negatives stayed 0/10 each round.
- 2026-10-13 — `scripts/render.sh` now also renders `run_onchange_*`
  templates, so the new loader is checked like the run_once ones (minimum
  raised from 2 to 3). Not in the plan; needed so `make check` covers it.
- 2026-10-13 — The script takes `RETRO_DIR` and `RETRO_SKILL` overrides, so
  it can be run from the worktree before anything is installed.

- 2026-10-13 — Phase 3's first `launchctl kickstart` failed: exit 127,
  `claude: command not found` for all three sessions. launchd's login zsh
  does not read `.zshrc`, where `~/.local/bin` joins PATH; the dry run had
  inherited the session's PATH. The script now prepends `~/.local/bin`.
  Checked under `env -i HOME USER /bin/zsh -lc`: `candidates: 16` =
  6 + 6 + 4, $0.71. The kickstart is re-run after this fix is applied.
- 2026-10-13 — The fix rides a second PR (`fix/retro-weekly-path`), against
  `work.one-implementation-pr-per-repo-per-plan`, because PR #34 was already
  merged: the failure only shows in Phase 3's live launchd run, after merge.

## Verification
- Phase 2: `make check` in the worktree → `private-refs ok (N plaintext
  files scanned)` with N = main's count (recorded before branching) + the new
  plaintext files, then `ok tools render lint private-refs`; a `NOT
  checking` line is a failure. shellcheck covers the script.
- Phase 2: `grep -c '^description:'` on each SKILL.md → 1, and the next line
  starts with `---` or a `key:`.
- Phase 2: trigger test — 10 should-trigger prompts (Phase 1 phrasings) and
  10 near-misses (feature work, a review, a "why did we choose" question, a
  release), each via `claude -p --max-budget-usd 0.5` with only the Skill
  tool allowed, from a scratch cwd holding a copy of the skill in its
  `.claude/skills` (live `~/.claude` untouched); a prompt near the line is run
  twice; a Skill call to
  `diagnosing-bugs` in the stream-json counts. Pass: ≥ 8/10 and ≤ 1/10. A
  fail revises the description and re-runs, at most 3 rounds, then a 👉
  decision.
- Phase 3: `chezmoi status` lists the target files (unrelated rows left
  alone); after apply, `cmp` source vs installed → identical; `launchctl
  print gui/$(id -u)/com.fredericrous.retro-weekly` shows the calendar
  interval.
- Phase 3: kickstart run → `~/.claude/retro/<date>.md` exists, names ≤ 3
  sessions, each candidate cites a transcript line or tool call; spend ≤ $3.
- Phase 3: in a fresh session `diagnosing-bugs` is in the skill list and
  `retro` is absent from the model-invocable list but runs as `/retro`.
- Phase 4: `ls ~/.claude/retro/2026-10-19.md` exists, and the count and the
  decision are recorded here.

### Observed (2026-10-13, before the push)
- Phase 1 spike, write probes (`--permission-mode default --disallowedTools
  Write,Edit,NotebookEdit`): Write → "No such tool available"; `jq -n 1 >
  ~/.claude/retro/probe2.txt` and `> ~/.claude/projects/probe3.txt` →
  refused as an edit of a sensitive file; no probe file exists afterwards.
- `make check` → `render ok (3 script templates …)`, `lint ok (14 scripts
  of 117 tracked files)`, `private-refs ok (108 plaintext files scanned)`
  (main: 99; +2 plan files, +7 new plaintext files), `ok tools render lint
  private-refs`.
- Description: one `description:` line in each SKILL.md; the next line is
  `---` (diagnosing-bugs) and `disable-model-invocation: true` (retro).
- Trigger test (default model, scratch cwd with the skill in
  `.claude/skills`, only the Skill tool allowed): round 1 (neutral wording)
  3/10 + 0/10; round 2 ("Load this FIRST") 7/10 + 0/10, a re-run of the 3
  misses hit 2; round 3 (+ "figure out why") **8/10 + 0/10 → pass**.
  Prompts and harness: [trigger-test](2026-10-13-diagnosing-bugs-and-retro-skills.trigger-test.md). Cost
  of the three rounds: $12.04.
- Batch dry run from the worktree (`RETRO_DIR` scratch, `RETRO_SKILL` the
  worktree file): report `candidates: 17` = 5 + 6 + 6 over sessions
  de32f809, d1960b45, 6ce58c42; `total_cost_usd` 0.22 + 0.16 + 0.14 =
  $0.52 ≤ $3; each candidate carries an Evidence line; the scratch dir held
  only the report.

## Implementation review
approve (delta), after approve-with-changes in round 1 (98k tokens, 45 s in total).
Fixed: duplicate copyright line, Phase 2 ticked before the merge, stale `RETRO_WEEKLY=1`, trigger harness not kept, exit 0 with `is_error` counted as success.
Next: Phase 3 after the merge: `chezmoi apply` of the targets, `cmp`, a `launchctl kickstart` run.

## Outcome

<!-- panel: repos=dotfiles reviewers=backend body-sha=a67df02ccaf1 -->
