---
status: active
branch: feat/always-on-index
repos: [dotfiles]
adrs: [ADR-0026, ADR-0032, ADR-0018, ADR-0029]
---
# Always-on text becomes an index

## Review panel
👉 **Decide:** none — approve if CLAUDE.md and MEMORY.md become ≤ 8 KB indexes, with a one-week firing-rate check as the safety net.
📍 dotfiles + local MEMORY.md · plan only · next: Phase 1 baseline rates from the journal. Panel: backend (opus-5-5).
**Changed by review:** worktree-task's dead `gwt-stash` advice fixed in the same PR; MEMORY.md write guarded by a sha256 re-hash; baseline counted per rule stance window.
**Verdicts:** round 1 approve-with-changes (3 accepted); round 2 approve-with-changes, no blocker; 3 carried into implementation.
📄 Full reviews: [reviews](2026-10-14-always-on-text-becomes-an-index.reviews.md)

## Goal
The global `~/.claude/CLAUDE.md` (19.8 KB, 344 lines) and the auto-memory
index `MEMORY.md` (23.1 KB, 149 lines) are loaded into every session. Both
break `guidance.always-on-is-an-index` (ADR-0026), and MEMORY.md is 1.9 KB
from Claude Code's 25 KB truncation, past which entries silently stop
loading. Rewrite both as indexes under 8,192 bytes each: one line per item,
naming the rule, skill or file that holds the detail. Nothing the agent
needs is lost: each removed item has an owner, and a dated measurement
shows whether any guardrail weakened.

## Non-goals
- No new aval rule or ADR; no amont-agent change. Raising
  `agent-guidance-shape` above advise is a later decision, after this lands.
- No rewrite of any memory file's own text, except appending status detail
  that a trimmed index line carried and the file lacks.
- Project `CLAUDE.md`/`AGENTS.md` files are not touched (generated blocks,
  ADR-0018).

## Behaviour

### `dot_claude/CLAUDE.md.tmpl` → an index (dotfiles)
- **Headings kept** that skills cite by name: "Git stash policy
  (worktrees)", "Git worktree isolation for agent work", "Git hygiene",
  "Before pushing / declaring CI green", "Repo ownership / PR workflow",
  "Forgejo API", "Shell environment", plus "Reading files", "Working
  method", "Relais routing", "Security", "Communication style". A
  reference such as `worktree-task:8` ("see § Git worktree isolation")
  still lands on a heading.
- **Each item is one line**, in this order of preference
  (`guidance.disclose-by-branch`, `guidance.do-not-cache-the-environment`):
  1. owned by a skill → `<what> — the \`<skill>\` skill`;
  2. decided in aval → `<what> (\`<rule-id>\`)`; `aval rule <id>` has it;
  3. guarded by an amont-agent rule → `<what> (amont-agent \`<id>\`)`;
  4. a fact nothing else holds → the fact itself, one line, with its
     target behaviour first (`guidance.state-the-target`).
- **Kept as facts** (no other owner, from the coverage map): run `git stash
  list` and pick the entry by message before any stash op; drop the
  `gwt-stash-*` fish helpers (unreachable from the zsh Bash tool) in favour
  of `git stash push -u -m <tag>` and apply by sha; no Co-Authored-By on
  repos the user does not own; assert each scripted bulk-edit replacement
  landed; `amont.fix` is unset here, run `amont agents-md` in the task
  worktree, never `amont-fleet fix --apply --agents-md` on live checkouts;
  the Bash tool runs zsh 5.9; `grep` is ugrep and skips gitignored paths
  (`--no-ignore-files`); `status` is read-only in zsh; 1M-context model
  spawns: pass an explicit `model` (kept after a check that it still
  applies, else dropped and logged); say in one line which path a task
  took (relais or session); silence HTTP client loggers when a secret
  rides in a URL; mention an open action item once.
- **Forgejo API** stays the one templated block (`{{ .forge.host }}`,
  `{{ .forge.slug }}`): two lines — both credentials are required, probe
  `/repos/{owner}/{repo}` not `/user` — and a pointer to the
  `reference_forgejo_*` memories and the `merge-when-green` recipe.
- **Dropped**: no-ops (`&&`/heredoc list, "Bash is fine for programs"),
  the measurement narrative behind "Reading files", and prose that a deny
  rule already enforces (pipe-to-tail, `==`, glob, `--auto`,
  `--no-verify`, file re-read) — each keeps its one index line.
- Budget: ≤ 8,192 bytes rendered; no line over 200 characters.

### `MEMORY.md` → an index (local, not versioned)
- Backup first: `~/.claude/backups/MEMORY.md.2026-10-14` (outside the
  memory directory, so it is not read as a memory), recording its sha256.
  Just before the write, re-hash MEMORY.md; if it changed, carry the new
  lines over first. After the write, every link in the backup resolves from
  MEMORY.md or a hub (script prints 0 dropped).
- **Lines**: `- [title](file.md) — hook`, at most 150 characters; the
  hook says what the file is about and, for live work, its one next date
  (`DUE 10-20`). Status detail (versions, PR numbers, sub-states) moves
  into the file. Before a line is cut, a script lists the dates, versions
  and PR numbers it carries; any token absent from its target file is
  appended there under `## Status (from the index, 2026-10-14)`.
- **Structure**: the same sections; each keeps only live or recurring
  items, and links its hub (`index_tooling.md`, `homelab_index.md`,
  `duro_index.md`, `trade_agents_index.md`, `sre_agent_index.md`,
  `index_other_apps_misc.md`, `index_conventions.md`, …). Closed items move
  to their hub, so the hubs hold history and MEMORY.md holds what is
  current.
- **Reachability**: every memory file is linked from MEMORY.md or a hub —
  the 63 orphans get a hub line; `index_tooling.md`'s dangling
  `SEMANTICS.md` mention is fixed.
- Budget: ≤ 8,192 bytes and ≤ 80 lines.

## Phases
- [x] Phase 1 — baseline, before any edit: from
  `~/.claude/amont-agent/journal.log` (7 days) and the transcripts' tool-use
  count, record per-1,000 firing rates for the rules whose prose is cut:
  `bare-stash-pop`, `worktree-isolation`, `git-add-broad`,
  `release-tag-push`, `tag-after-commit`, `pipe-to-tail`,
  `equals-separator`, `glob-in-flag-value`, `file-reread`,
  `whole-file-dump`, `read-unbounded-large`, `gh-pr-merge-auto`,
  `no-verify`, `implementation-review`, `plan-review-panel`. Each id is
  confirmed in `amont-agent rules --json` (any id not in the journal names
  where it is measured instead); each rate counts only from that rule's last
  stance change (`file-reread` deny since 10-11 12:10Z), and the table
  records stance, window, raw count and denominator. Saved in the plan.
- [x] Phase 2 — dotfiles: rewrite `dot_claude/CLAUDE.md.tmpl` from the
  coverage map; in the same PR replace the `gwt-stash-save`/`gwt-stash-pop`
  advice at `dot_claude/skills/worktree-task/SKILL.md:347` with the new stash
  fact; `make check`; one PR, merged on green; `chezmoi apply
  ~/.claude/CLAUDE.md` only.
- [x] Phase 3 — MEMORY.md: backup, status-token script, rewrite, hub lines
  for orphans and moved items, reachability check.
- [ ] Phase 4 — 2026-10-21: recompute the Phase 1 rates over the 7 days
  after the switch. A rule whose rate at least doubles (and fires ≥ 5
  times) gets its detail line back, in a follow-up PR; record all rates
  here and close the plan.

## Decision log
- 2026-10-14 — The 1M-context spawn item is dropped: no tool error with
  "model may not exist" in any transcript since 2026-09-20.
- 2026-10-14 — The `gwt-stash-*` helpers are not mentioned (they are
  unreachable from zsh); the stash line names `git stash push -u -m <tag>`
  and apply-by-sha, so the `gwt-stash` grep holds.
- 2026-10-14 — Items only watched by an observe-stance rule (worktree
  isolation, broad `git add`, release tag push) shrink to one line like the
  rest, with the one-week rate comparison as the safety net (person's
  choice over keeping their full text).
- 2026-10-14 — The PR merges on green and an approved review, without a
  read-through by the person (person's choice); the PR body carries the
  before/after and the item-to-owner map.
- 2026-10-14 — MEMORY.md is rewritten in place (it is not in a repo); the
  backup and the reachability check stand in for a diff review.

## Verification
- Phase 1: the rate table is in the plan, with the window and the
  tool-call denominator.
- Phase 2: `make check` green (render, lint, private-refs); rendered
  `~/.claude/CLAUDE.md` ≤ 8,192 bytes (`wc -c`), longest line ≤ 200
  (`awk`); every heading cited by a skill exists (`grep` each cited name); `grep -r gwt-stash dot_claude/` prints nothing;
  every removed item appears in the PR's owner map, and each named rule id
  resolves (`aval rule <id>` or `amont-agent rules --json`); the amont-agent
  shape advice no longer fires on an edit of the file (journal).
- Phase 3: `wc -c` ≤ 8,192 and `wc -l` ≤ 80; longest line ≤ 150; the
  status-token script reports 0 tokens missing from their files; every
  `*.md` in the memory directory is linked from MEMORY.md or a hub (script
  prints 0 orphans, 0 broken links); a fresh session's context shows the
  new index (no truncation notice).
- Phase 4: the before/after rate table, and the follow-up PR if a rule
  doubled.

## Observed

### Phase 1 — baseline (2026-10-14 09:39, before any edit)
`python3 2026-10-14-always-on-text-becomes-an-index.rates.py <ids>` (the
script beside this plan). Window: the journal's whole span (it keeps 7 days),
from each rule's last stance change inside it; no stance changed inside the
span, so every window starts 10-07 09:39 (`file-reread` was already deny).
Denominator: tool calls in transcripts over the same window. "Fires" counts
journal lines whose stance column is observe, advise or deny; `unconfirmed`
lines (matched, then refused by the rule's confirm step) are not firings.
Every id is an amont-agent rule (`amont-agent rules --json`).

| rule | stance now | window from | fires | tool calls | per 1,000 |
|---|---|---|---|---|---|
| `bare-stash-pop` | deny | 10-07 09:39 | 0 | 23364 | 0.00 |
| `worktree-isolation` | observe | 10-07 09:39 | 0 | 23364 | 0.00 |
| `git-add-broad` | observe | 10-07 09:39 | 0 | 23364 | 0.00 |
| `release-tag-push` | observe | 10-07 09:39 | 3 | 23364 | 0.13 |
| `tag-after-commit` | advise | 10-07 09:39 | 0 | 23364 | 0.00 |
| `pipe-to-tail` | deny | 10-07 09:39 | 2 | 23364 | 0.09 |
| `equals-separator` | deny | 10-07 09:39 | 3 | 23364 | 0.13 |
| `glob-in-flag-value` | deny | 10-07 09:39 | 8 | 23364 | 0.34 |
| `file-reread` | deny | 10-07 09:39 | 2 | 23364 | 0.09 |
| `whole-file-dump` | advise | 10-07 09:39 | 13 | 23364 | 0.56 |
| `read-unbounded-large` | advise | 10-07 09:39 | 3 | 23364 | 0.13 |
| `gh-pr-merge-auto` | deny | 10-07 09:39 | 0 | 23364 | 0.00 |
| `no-verify` | deny | 10-07 09:39 | 0 | 23364 | 0.00 |
| `implementation-review` | deny | 10-07 09:39 | 4 | 23364 | 0.17 |
| `plan-review-panel` | deny | 10-07 09:39 | 5 | 23364 | 0.21 |

### Phase 2 — CLAUDE.md (2026-10-14)
- Rendered `~/.claude/CLAUDE.md`: 19,827 → 4,625 bytes, 344 → 93 lines,
  longest line 103 characters (4,899 bytes after the review fixes).
- Every heading a skill cites is present (Git stash policy (worktrees), Git
  worktree isolation, Git hygiene, Before pushing, Repo ownership / PR
  workflow, Forgejo API, Shell environment). `grep -r gwt-stash dot_claude/`
  prints nothing.
- Every named id resolves: 9 aval rules (`aval rule <id>`), 10 amont-agent
  rules (`rules --json`), 6 skills, 1 memory file. `merge-when-green` holds
  the Forgejo curl recipe the index points to.
- `make check` → ok (render, lint, private-refs).
- Journal on the rewrite's Write of `dot_claude/CLAUDE.md.tmpl`:
  `agent-guidance-written advise advised`; no `agent-guidance-shape` line (the
  write shrank the file, so the ratchet stays silent).
- Owner map (old section → where its detail lives now):

| old section | owner |
|---|---|
| Git stash policy | amont-agent `bare-stash-pop` (deny); index line: stash list + push -m + apply by sha |
| Worktree isolation | `worktree-task` skill; amont-agent `worktree-isolation` (observe) |
| Git hygiene: cwd, git status, tag, subject, agents-md, trailer | index lines; `tag-release` skill; `guidance.generated-block-rides-the-change`; amont-agent `git-add-broad` |
| Before pushing: local checks, gh run watch, bulk edits, pipe-to-tail, browser, exact view | `work.verification-loop-before-push`; `merge-when-green`; amont-agent `pipe-to-tail` (deny), `relais-verified-push`; index lines (bulk edit, browser, exact view) |
| Repo ownership / PR workflow | `work.agent-lands-the-plan`, `work.merge-on-green`, `work.ask-only-what-the-plan-left-open`, `general.no-disabled-safety`; `merge-when-green` |
| Forgejo API | index lines (two credentials, probe, never echo); `merge-when-green` recipe; `reference_forgejo_*` memories |
| Shell environment | `claude_code_bash_tool_runs_zsh_not_fish.md`; amont-agent `equals-separator`, `glob-in-flag-value`, `glob-no-match`, `sed-in-place`, `stat-bsd-format`; index lines (rc, ugrep, tool flavors) |
| Reading files | amont-agent `whole-file-dump`, `read-unbounded-large`, `file-reread`, `persisted-output-dump` |
| Claude Code agent tooling (1M spawns) | dropped: no failure since 09-20 (Decision log) |
| Working method | `work.*` (ADR-0022/0023/0028), `/plan-review`, `work.human-decisions-offer-options` |
| Relais routing | `relais:relais` skill; index line (say which path) |
| Security, Communication style | index lines |

### Phase 2 — live
- dotfiles #38 merged (49eb7b1); `chezmoi apply ~/.claude/CLAUDE.md`: 4,899
  bytes, `chezmoi diff` empty.

### Phase 3 — MEMORY.md (2026-10-14, local)
- Backup `~/.claude/backups/MEMORY.md.2026-10-14`, sha256 f8ea4287…; the
  re-hash just before the write matched (no other session wrote meanwhile).
- Status tokens: 7 tokens in 5 files were missing from their target files;
  each file got its old index line under `## Status (from the index,
  2026-10-14)`; a re-run reports 0 missing.
- Hubs: 45 index lines that the new index drops were appended whole to their
  section's hub, and the 63 orphan memories got a hub line, each under
  `## Moved from the index (2026-10-14)`. `index_tooling.md`'s
  `SEMANTICS.md` mention now names the aval repo.
- New MEMORY.md: 23,325 → 7,856 bytes, 150 → 80 lines, longest line 149.
  Reachability over 515 files: 0 broken links, 0 orphans, 0 links of the
  backup dropped.

## Implementation review
Phase 2, round 1: approve-with-changes (55k tokens, 71 s). Fixed: the web/UI
item now states its fact (real browser; exact view before and after); the
tool-flavor facts are back; the `amont-fleet` line no longer implies a
permission; the never-echo wording is kept; the Reading-files heading keeps
"overrides the bypass-mode default"; the journal check and owner map are
recorded.

## Outcome

<!-- panel: repos=dotfiles reviewers=backend body-sha=2c43d12e7ae9 -->
