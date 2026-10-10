---
name: plan-review
description: Run the expert review panel on a plan before ExitPlanMode (ADR-0022, work.plan-review-panel), and again as a delta after the person asks for a change. Use in plan mode every time a plan is about to be presented. The amont-agent plan-review-panel hook refuses a plan whose panel did not run.
---

# plan-review

Every plan is reviewed by a panel of experts **before** the person sees it.
The panel follows what the plan touches, and amont-agent computes it from
the repositories, never from keywords:

| area | agents |
|---|---|
| always | `plan-review-language` for each language, and `plan-review-backend` |
| ops | `plan-review-platform` |
| a command line | `plan-review-unix`, `plan-review-tui` |
| large (500 or more files or own commits) | `plan-review-po`, `plan-review-architect` |
| an interface | `plan-review-react`, `plan-review-ui-design`, `plan-review-ux-research`, `plan-review-game-ux` |

Rounds are bounded: round 1 is the whole panel, round 2 is a delta, and
there is no round 3. A change the person asks for gets one delta review and
never a loop.

## 0. The machine comment

The plan's **last line** names the repositories it touches, and the areas it
adds that do not exist yet:

```
<!-- panel: repos=amont-agent,decisions adds=ui -->
```

- Repository names resolve to `~/Developer/Perso/<name>`. A repository kept
  elsewhere has `git config --global amont.agent.plan-review.<name>.path`
  set. Here that is `dotfiles` → `~/.local/share/chezmoi`, not the
  `chezmoi` directory, which is upstream chezmoi.
- `adds=` takes `cli`, `ui`, `ops`, `large` or `lang:<language>`. It is
  required for an area the plan creates: a first CLI, UI or manifests, or a
  new repository (`adds=lang:rust`).

The plan also needs a `## Review panel` section directly under the H1. Write
a placeholder line there now; step 7 fills it.

## 1. What to run

```sh
amont-agent plan-panel <plan.md>
```

The first line reads `repos=… areas=… body=<12> panel=full|delta|current`,
then one agent per line. That list is exactly what the hook will require;
launch that list, no more and no fewer. `panel=current` means nothing
changed since the last accepted body: go to step 7.

## 2. The shared brief

Build it once and give it to every reviewer, so that each one does not
explore the repositories on its own. That exploration is where the tokens
go, about 40–80k per reviewer.

- The `plan-panel` output (areas, and why this panel).
- Each repository's top level:
  `git -C <repo> ls-tree --name-only origin/HEAD`.
- The decisions the plan bears on: `aval relevant --text "<plan title and
  key terms>"`, then `aval resolve <key>` on each key it names. Include the
  verdicts, not the ranking.
- The files the plan names, with line counts (`wc -l`).

## 3. Round 1: the whole panel

1. Tell the person first, in one line:
   `📍 <project>: reviewing "<plan title>" with <agent names>; about 3–6 min, you can switch projects meanwhile.`
2. For each agent, get its review block, and pass `--lang` for a language
   review:

   ```sh
   amont-agent plan-sha --block [--lang rust] <plan.md>
   ```

3. Launch **all** the agents in ONE message, in parallel. Each prompt
   carries, in this order:
   - the review block line, verbatim;
   - `Round 1.`;
   - the shared brief;
   - "Read the plan at the block's path. Open at most 10 more files or
     1,500 lines. Follow your output contract."
4. As each one returns, post one line, so that a round longer than 10 s
   shows what is done and what is left:
   `k/N returned: <role> <verdict> (<tokens>, <seconds>)`, for example
   `2/4 returned: lang:rust approve-with-changes (35k, 45 s)`.

A launch that fails is relaunched once. If it fails again, it becomes a 👉
decision for the person, and is never silently dropped.

## 4. Merge

The main session keeps a ledger, not the plan. Editing the plan there
resends the old and new text of every edit: on 2026-10-10 the integration
edits cost more of the session's context than the four reviews they applied.

- Write one line per finding: `accepted`, `rejected: <why>`, or
  `👉 decision`. Findings that duplicate each other become one line.
  Findings that conflict become a 👉 decision for the person, with both
  positions.
- `cp` the plan to a scratch file first: round 2's diff is `diff -u`
  against that copy.
- Launch one `general-purpose` subagent, in the foreground, to apply the
  accepted lines. Its prompt carries the plan's path and each accepted
  finding verbatim, with its evidence and proposed edit. It edits the file
  and returns only one line per changed section, plus the output of
  `amont-agent plan-sha --short <plan>`.
- Do not read the plan back. Read a section only to settle a 👉 decision.

## 5. Round 2: delta only

Re-run the reviewers whose verdict was `rework`, plus
**`plan-review-backend` always**. Backend must bind the FINAL body, because
the hook requires it: every edit to the body after backend's review makes
backend stale.

1. Post: `📍 <project>: round 2, re-running <names>, about 2 min.`
   Returns use the same `k/N returned:` line.
2. Get fresh blocks. The sha changed with the edits.
3. Each prompt carries:
   - the block;
   - `Round 2.`;
   - that reviewer's round-1 findings;
   - the diff of the plan since round 1;
   - "answer resolved / not resolved / new blocker for each".

After round 2, only a `high` or blocking finding may change the body. A
`medium` or `low` one gets no edit: it goes in step 7's review section, as
`carried into implementation`, and the landed plan keeps it beside the
body. An edit after round 2 makes backend stale, so a blocker that forces
one is applied through the step 4 subagent, and backend alone re-runs on
it.

## 6. No round 3

Whatever stays unresolved goes to the person as a 👉 decision, with both
positions stated. It never becomes another round.

## 7. Write the results

Writing these never changes the body's sha, so the reviews stay bound.

- **The `## Review panel` section**, under the H1, at most 5 lines of
  **about 20 words each**. The person reads it after being away, working
  on several projects, so it leads with the decision and says what comes
  next:
  1. `⚠ unreviewed: <why>`, only when the person asked to skip the panel;
  2. `👉 **Decide:** <what the person must decide>`, or
     `none — approve if <the one-line bet>`;
  3. `📍 <repositories> · <where the work stands> · next: <one action>. Panel: <roles>.`,
     for example
     `📍 dotfiles · Phases 1–3 shipped · next: the nine agent files. Panel: backend.`;
  4. `**Changed by review:**` up to 3 items;
  5. `**Verdicts:**` the counts per verdict, any delta rework that went
     to the person, and the count of findings `carried into
     implementation` (listed in the full reviews). Token counts and
     timings go in the full reviews, not here.
- **`## Full reviews (reference)`** as the last heading: each reviewer's
  verdict, findings, tokens and wall time, as a plain section with no
  `<details>`.
- **The machine comment** as the last line:
  `<!-- panel: repos=… adds=… reviewers=<roles> body-sha=<plan-sha --short> -->`.

Then call ExitPlanMode.

## 8. The person asks for a change

After ExitPlanMode is rejected with feedback:

1. Edit the plan through the step 4 subagent, with the person's words as
   the accepted line.
2. Run `amont-agent plan-panel <plan.md>`. It prints `panel=delta`, with
   backend plus the reviewers of any area that is new.
3. Launch those once. Each prompt carries:
   - the block;
   - `Delta.`;
   - the person's words, quoted;
   - the diff;
   - "check how the change is made, not whether".
4. A `rework` from them becomes a 👉 decision, never a re-run.
5. Update the review section, then call ExitPlanMode.

## If the hook refuses

The refusal names what is missing (`missing for repos=X: <roles>`) or stale
(`stale (reviewed an older body)`). Run exactly those, then present again.
After 2 refusals of the same plan, the hook hands the decision to the person
with `UNREVIEWED: refused N×`, naming the missing reviewers and the body
each time, so a repeated prompt still says something new. Do not try to
get past it. Tell the person what is missing and why.

A warning seen again and again stops being read, so the prompt must stay
rare. The hook cannot see how the person answers; the number it can give
is how often it asked. Before the panel's usefulness is decided, count
them:
`grep -c 'plan-review-panel deny asked' ~/.claude/amont-agent/journal.log`.

## Skipping

Only the person can skip the panel. Write `⚠ unreviewed: <their reason>` as
the first line of the review section. The hook then asks the person to
confirm, and remembers nothing.
