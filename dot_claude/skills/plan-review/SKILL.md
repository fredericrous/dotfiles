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
- Record the round, BEFORE the plan is edited (it saves the reviewed body
  only while the file still holds it), with one object per finding on
  stdin; `section` is the plan heading it is about, `area` one of
  cli|ui|ops|large|lang:<x> when it is clear:

  ```sh
  echo '[{"role":"tui","severity":"high","disposition":"accepted","section":"Behaviour","area":"cli"}]' \
    | amont-agent plan-review record <plan.md>
  ```

  It prints `wrote N rows (round R, plan <sha12>)`. Exit 1 (ledger or a
  missing agent id) is reported in one line and never stops the review.
- `cp` the plan to a scratch file first: round 2's diff is `diff -u`
  against that copy.
- Apply the accepted findings with no model: each reviewer's `Patches:`
  block is read from the transcript, so stdin names only the findings:

  ```sh
  echo '[{"role":"tui","finding":1},{"role":"unix","finding":3}]' \
    | amont-agent plan-apply <plan.md>
  ```

  It prints `applied tui#1 <section>` or `unmatched tui#3: <reason>` per
  finding, then `applied A, unmatched U, sha <sha12>`, and exits 0 when
  everything matched. On 2026-10-11 the four subagents that applied one
  review's findings cost about 320k tokens, more than the reviews.
- Exit 3 means some patch did not match (the matched ones are written; a
  `next:` line and an `<<<APPLY path=… sha=…>>>` block end stdout). Apply
  the remainder the cheapest way that fits:
  - at most 3 unmatched findings, each edit under about 15 lines: the main
    session writes the pair itself and runs `plan-apply` again with it on
    stdin, so the edit is applied, recorded and checked like any other —
    the old and new text cost less than a subagent's read of the plan:

    ```sh
    echo '[{"role":"tui","finding":3,"patch":{"old_string":"…","new_string":"…"}}]' \
      | amont-agent plan-apply <plan.md>
    ```

  - otherwise ONE `general-purpose` subagent, in the foreground, with
    `model: "sonnet"` on the call. Its prompt starts with the `<<<APPLY …>>>`
    block verbatim, then the unmatched findings with their evidence and
    edit, and ends with: run `amont-agent plan-apply --check <plan>` with
    the findings on stdin as the last command and return its output only.
    `sonnet` is a preference, not a pin: relais's router keeps it when
    routing is off or abstains, and overrides it when its table decides.
  After the subagent, record what it did (it finds the launch by the
  `<<<APPLY` block, so this is the subagent path only):

  ```sh
  echo '[{"role":"tui","finding":3}]' | amont-agent plan-apply --record-fallback <plan.md>
  ```

  Exit 1 (no transcript, ledger) is reported in one line and never stops
  the review: apply the edits by hand and go on. Exit 2 is a usage error
  and nothing was applied: when it names a reviewer's patch (an empty
  `old_string`), drop that finding from stdin, re-run, and apply it in the
  remainder.
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
   - that reviewer's round-1 findings, and that its patches were applied
     by `plan-apply` where they matched;
   - the diff of the plan since round 1;
   - "answer resolved / not resolved / new blocker for each".

After round 2, only a `high` or blocking finding may change the body. A
`medium` or `low` one gets no edit: it goes in step 7's review section, as
`carried into implementation`, and the landed plan keeps it beside the
body. An edit after round 2 makes backend stale, so a blocker that forces
one is applied as in step 4 (`plan-apply`, then the remainder), and
backend alone re-runs on it.

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
     each role with the model it ran on, for example
     `📍 dotfiles · Phases 1–3 shipped · next: the nine agent files. Panel: backend (fable-5-1), tui (sonnet-5-5).`;
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

1. Edit the plan as in step 4's remainder: `plan-apply` with a `patch`
   object under `role: "person"` when small, else the Sonnet subagent, with
   the person's words as the accepted line; there is no reviewer patch for
   it.
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
