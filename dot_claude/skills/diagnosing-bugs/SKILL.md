---
name: diagnosing-bugs
description: Load this FIRST, before running any command or reading code, whenever a bug's cause is not known yet — "investigate why X fails", "figure out why", "look into this failure/error", a crash loop, a flaky or red test, a leak, "I tried X and got an error", "it still does Y", or a fix that did not take. The debug discipline: a loop that goes red on the symptom, then minimise, ranked hypotheses, instrument, fix with a regression test.
---

# Diagnosing bugs

A discipline for bugs whose cause is not known yet. Do the phases in order.
Skip a phase only when you say why.

Adapted from mattpocock/skills (see [NOTICE.md](NOTICE.md)).

Before you start: run `aval_relevant` on the paths involved, then
`aval_resolve` each key it returns. A `contradiction` stops the work: say
so. A decision tells you what the code is meant to do.

## Redact

You will show commands, output and captured data. Write `<REDACTED>` in place
of every secret before you show it. Loops read credentials from environment
variables, so the value stays out of what you show. A captured request
carries auth headers: quote only the lines that carry the signal. If the
redacted output is not enough, say so and ask.

## Phase 1: Build a red loop

**This is the skill.** With a **tight** pass/fail signal that goes **red** on
this bug, you will find the cause. Bisection, hypotheses and logs all only
use that signal. Without it, reading code will not save you. Spend most of
your effort here. Be creative. Do not give up early.

Ways to build one, roughly in this order:

1. A failing test at the seam that reaches the bug: unit, integration, e2e.
2. A `curl` script against a running dev server.
3. A CLI run on a fixture input, with stdout diffed against a known-good
   snapshot.
4. A browser run (chrome-devtools MCP, or headless Playwright) that asserts
   on DOM, console or network. Reproduce the person's **exact** view first:
   the same route, mode, zoom and state. Their words describe what they
   see, not which code path draws it.
5. A replay of a captured request, payload or event log through the code
   path, alone.
6. A throwaway harness: the smallest part of the system that runs the bug
   path with one call.
7. A property or fuzz loop, when the bug is "sometimes wrong output".
8. A bisection harness (`git bisect run`), when the bug appeared between two
   known states.
9. A differential loop: the same input through the old and the new version,
   outputs diffed.

**Tighten the loop.** Make it faster (cache setup, narrow the scope), sharper
(assert the exact symptom, not "did not crash") and deterministic (pin time,
seed random numbers, isolate the filesystem and network). A 30-second flaky
loop is barely better than none.

**Flaky bugs.** The goal is a higher reproduction rate, not a clean repro.
Run the trigger 100 times, in parallel, under load, with sleeps in the
timing window. A bug that shows 50% of the time can be debugged; 1% cannot.

**No loop possible.** Stop and say so. List what you tried. Ask for access
to an environment that reproduces it, a redacted capture (HAR, log dump,
screen recording with times), or permission for temporary production
logging. Do not go on to hypotheses.

**Prove the red is real.** A loop that cannot fail proves nothing:
- When you force a red by changing code or a fixture, show the change
  landed: `diff` or `cmp` against a clean copy.
- A Rust re-run must print `Compiling <crate>`. Without it, a same-second
  mtime kept the old build, and the result is stale.
- Prove the file you test is the one the system loads: grep the object name
  in the applied config, bundle or image.

**Machine traps inside the loop.** `grep` here skips gitignored paths without
a warning: pass `--no-ignore-files` or name the directory. Bound every wait
with a timeout. Never pipe a command that changes state through `tail` or
`head`: the pipe hides its exit status.

Phase 1 is done when you can name **one command** that you **already ran**
(show it and its redacted output), and that is:
- [ ] **red-capable**: it runs the real bug path and asserts the person's
  exact symptom, so it goes red now and green once fixed;
- [ ] **deterministic**: the same verdict every run (flaky: a high, pinned
  reproduction rate);
- [ ] **fast**: seconds, not minutes;
- [ ] **agent-runnable**: you run it with no person in the loop.

If you catch yourself reading code to build a theory before this command
exists, stop. That is the failure this skill prevents.

## Phase 2: Reproduce and minimise

Run the loop. Watch it go red. Confirm:
- [ ] it shows the failure the **person** described, not a different one
  nearby (wrong bug, wrong fix);
- [ ] it reproduces over several runs, or at a high enough rate;
- [ ] you captured the exact symptom (error text, wrong value, timing).

Then shrink it. Cut inputs, callers, config, data and steps **one at a
time**, and re-run after each cut. Keep only what the failure needs. Done
when removing any one remaining part makes the loop go green.

## Phase 3: Hypothesise

Write **3–5 ranked hypotheses** before you test any. One hypothesis anchors
on the first idea. Each one states its prediction:

> If <X> is the cause, then changing <Y> makes the bug go away, and
> changing <Z> makes it worse.

A hypothesis with no prediction is a guess: sharpen it or drop it.

Show the ranked list to the person before you test. They often know
something that re-ranks it at once ("we deployed #3 yesterday"). Do not wait
for an answer if they are away; go on with your ranking.

## Phase 4: Instrument

Each probe tests one prediction from Phase 3. Change one variable at a time.

1. A debugger or REPL, when the environment has one.
2. Targeted logs at the boundaries that tell the hypotheses apart.
3. Never "log everything and grep".

Tag every debug log with one prefix, for example `[DEBUG-a4f2]`, so one grep
removes them all.

**Performance bugs.** Logs are usually the wrong tool. Measure a baseline
first (a timing harness, a profiler, a query plan), then bisect. Measure
first, fix second.

## Phase 5: Fix and regression test

Write the regression test **before** the fix, but only at a **correct seam**:
one where the test runs the real bug pattern as it happens at the call
site. A seam that is too shallow (one caller when the bug needs two, a unit
test that cannot rebuild the chain) gives false confidence.

**No correct seam is itself a finding.** The design stops the bug from being
locked down. Say so in the report.

With a correct seam:
1. Turn the minimised repro into a failing test there.
2. Watch it fail (prove the red is real, as in Phase 1).
3. Apply the fix.
4. Watch it pass.
5. Run the Phase 1 loop again on the original, full scenario.

## Phase 6: Clean up

Done only when:
- [ ] the Phase 1 loop is green on the original scenario;
- [ ] the regression test passes, or the missing seam is written down;
- [ ] `grep` for the `[DEBUG-` prefix finds nothing;
- [ ] throwaway harnesses are deleted, or moved to a marked debug place;
- [ ] the commit or PR body states the hypothesis that proved correct, so
  the next person who debugs this learns from it.
