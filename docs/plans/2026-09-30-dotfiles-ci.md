---
status: active
branch: feat/ci
repos: [dotfiles]
adrs: [ADR-0017]
---
# dotfiles gets the CI its rules require

## Review panel

👉 **Decide:** none — approve if dotfiles gets one `make check` (pinned tools in `.tools/`, hermetic render, shellcheck, tree-wide private-refs) mirrored by GitHub Actions on Linux and macOS, and this PR is the first live F4b cycle.
📍 dotfiles · nothing built yet · next: worktree, plan commit, Phase 2. Panel: backend, platform (`adds=ops`).
**Changed by review:** `.chezmoiignore` covers the new machinery (it would have been deployed to `$HOME`); release assets with pinned SHA-256s instead of an installer piped to `sh`; the `PRIVATE_TERMS` secret is created before the push, passed via `env:`, required on same-repo runs, names-only in logs.
**Verdicts:** backend round 1 approve-with-changes (7, all applied); round 2 backend + platform approve-with-changes (5 + 5, all applied); final binding backend + platform approve-with-changes.
**Carried into Phase 2** (final binding, no body change): NUL-safe `git ls-files -z` loops in `--tree`, staged mode and `lint` (a tracked path holds a space); the render loop prints `render: $f` on failure and lists templates with a git pathspec; `--persistent-state` on every chezmoi call; an empty pattern under `PRIVATE_REFS_REQUIRE_TERMS=1` is a failure.

📄 Full reviews: [2026-09-30-dotfiles-ci.reviews.md](2026-09-30-dotfiles-ci.reviews.md)

## Implementation review

Round 1 `approve-with-changes` (52k tokens, 78 s), Delta `approve-with-changes` (31k, 30 s), tree `19bd0a5e4c1d`.
Fixed: an invalid regex in the terms file passed silently (grep exit 2 read as no match) — real, would have shipped; four workflow steps to match the targets; status lines and usage to stderr; usage exits 2; no `|| true` in lint's shebang read.
Deliberate: lint's unreadable-file guard (`[ -r "$f" ]`) is the next change's, not a third pass; the checksum wording in Behaviour now matches the code (`digest` + compare, not `shasum -c`).
Record-only items (phase ticks, this section) live under `docs/plans/`, outside the canonical tree, so the reviewed tree is the pushed tree.

## Context

`fredericrous/dotfiles` is a public GitHub repository with an amont
pre-commit gate and no continuous-integration workflow. ADR-0017 makes that
a defect (`ci.from-first-commit`: a repository has a workflow in its first
commit or in the commit that adds its first check target), and the working
method's soak notes recorded it as a trap on 2026-09-28. The repository is
also where every Claude skill and agent lives, so a template that no longer
renders, or a private hostname that slips into a plaintext file, reaches
every session and the public.

This change is also **Phase 4 of the implementation-review plan**
(`decisions:docs/plans/2026-09-29-implementation-reviewer-before-push.md`):
the first real F4b cycle, on a code diff with a plan, whose tokens, seconds,
verdict and finding quality feed the 2026-10-06 soak review.

## Goal

One check target, `make check`, that a workstation and GitHub Actions run
with the same commands and pinned tools: every template renders with
placeholder data, the shell scripts pass shellcheck, and no plaintext file in
the tree carries a private identifier. The workflow runs it on Linux and
macOS for every push to `main` and every pull request.

## Non-goals

- A Windows render. The `AppData` and PowerShell branches stay unverified
  until a runner is worth its minutes.
- Forgejo. The repository is public on GitHub, so GitHub Actions
  (`ci.system-follows-visibility`).
- Changing what amont's pre-commit checks; `private-refs` at pre-commit
  keeps scanning the staged files.
- Publishing the private terms. They stay outside the tree on the
  workstation and in a repository secret in CI.
- A fleet CI template or reusable workflow; one repository, its own file.

## Behaviour

### `make check`, the one target (`ci.mirrors-the-local-check`)

`check: tools render lint private-refs`, each a target of its own so a red
job names its step. The Makefile is POSIX make plus `/bin/sh`, since the
repository has no language of its own.

- **`tools`** installs the pinned tools into `.tools/` (gitignored) and
  never uses the machine's (`toolchain.pinned-exactly-in-the-repository`,
  `toolchain.tools-pinned-with-it`, `toolchain.one-pin-read-by-both`):
  - `tools.env` holds the only pins: `CHEZMOI=v2.72.1`,
    `SHELLCHECK=v0.11.0`. The Makefile reads it; nothing else states a
    version.
  - Both tools are downloaded as the **release asset of the pinned tag**,
    straight from GitHub releases, never through an installer script
    piped to `sh`: `chezmoi_<ver>_<os>_<arch>.tar.gz` and
    `shellcheck-<tag>.<os>.<arch>.tar.xz` for the host
    — chezmoi names them `linux_amd64`, `darwin_amd64`, `darwin_arm64`,
    shellcheck `linux.x86_64`, `darwin.x86_64`, `darwin.aarch64`; the
    Makefile maps `uname -s`/`uname -m` to both spellings. `tools.env`
    holds, beside each version, the **SHA-256 of each of the six assets**:
    chezmoi's from its published `chezmoi_<ver>_checksums.txt`; shellcheck
    publishes no checksums file, so its three are computed at pin time
    from the asset downloaded over HTTPS from the GitHub release, and pin
    what was reviewed rather than what upstream attests. The Makefile
    verifies every download — `shasum -a 256` (or `sha256sum`) compared to
    the pinned digest — before extracting; a mismatch fails naming the asset. An unknown host is a failure that
    names the host, not a fallback to PATH.
  - Afterwards `.tools/chezmoi --version` and `.tools/shellcheck
    --version` must contain their pins, or the target fails.
  - Idempotent: a `.tools/<tool>` already at the pinned version is not
    re-downloaded, so a second `make tools` sends no request.
- **`render`** proves every template renders:
  - `ci/chezmoi.toml` (committed) carries placeholder `[data]`:
    `bwserver = ""`, `forge.host = "forge.example.invalid"`,
    `forge.slug = "example"`, `work.dir = ""`, `work.config = ""` — the
    five keys the templates read, none of them a real value.
  - `.tools/chezmoi --config ci/chezmoi.toml --persistent-state
    "$dst/state.boltdb" --source . --destination "$dst" apply --exclude
    encrypted,externals,scripts` with `dst` a fresh temp directory: every
    template is executed against the placeholders and written there;
    encrypted files need no key, externals no network, and no `run_once_*`
    script runs. The state file goes into `dst` too, because chezmoi
    otherwise writes it beside the config file and dirties the tree.
    Afterwards the target asserts that `$dst/.zshrc`,
    `$dst/.claude/CLAUDE.md` and `$dst/.claude/skills/worktree-task/SKILL.md`
    exist and are non-empty, that `$dst/Makefile`, `$dst/tools.env` and
    `$dst/ci` do NOT exist (the repository machinery never reaches a home
    directory), and removes `dst`.
  - The two `run_once_*.tmpl` scripts are excluded from the apply (they
    must not run) but are the only templates that call `include` and
    `lookPath`, so each is rendered on its own: `.tools/chezmoi --config
    ci/chezmoi.toml --source . execute-template < $f` for every tracked
    `run_once_*.tmpl`, output discarded, exit status kept.
  - The config template itself: `.tools/chezmoi --config ci/chezmoi.toml
    execute-template --init --promptString "bitwarden server url=x"
    < .chezmoi.toml.tmpl | grep -q 'encryption = "gpg"'` — with the ci
    config, so `promptStringOnce` never reads the workstation's real data
    and the run is the same at home and on the runner.
- **`lint`**: `.tools/shellcheck` over every tracked `*.sh` and every
  tracked file whose first line is a `sh`/`bash` shebang
  (`scripts/check-private-refs.sh`, `install_dependencies_debian.sh`,
  `mac_defaults.sh` today; the list is computed, not written down). fish
  and PowerShell files are not shellcheck's business.
- **`private-refs`**: `scripts/check-private-refs.sh --tree` — a new mode
  of the existing script that scans every tracked plaintext file
  (`git ls-files`, `encrypted_*` skipped) instead of the staged set, with
  the same terms file (`PRIVATE_TERMS_FILE`, default
  `~/.config/chezmoi/private-terms`). Two differences from the staged
  mode, both because a CI log is public: on a hit it prints **file names
  only**, never the matching lines (a regex term defeats GitHub's secret
  masking), and a path that itself matches a term is printed as
  `<path withheld>`; and with `PRIVATE_REFS_REQUIRE_TERMS=1` a missing terms file is
  a failure, not the loud pass — CI sets it on every push to `main` and on
  a pull request from this repository, and leaves it unset only for a
  fork's pull request, which has no secret (`general.no-disabled-safety`).
  Without the flag the script behaves exactly as today, so amont's
  pre-commit entry is untouched.

### The workflow (`.github/workflows/ci.yaml`)

- `on: push: branches: [main]` and `pull_request`; `concurrency` cancels a
  superseded run; `timeout-minutes: 10`.
- `permissions: contents: read` at the top level (the default token in a
  public repository may carry write), and `actions/checkout` pinned by
  commit SHA with its tag in a comment (`toolchain.tools-pinned-with-it`
  applies to actions too).
- One job, `check`, `strategy.matrix.os: [ubuntu-latest, macos-latest]`
  (`fail-fast: false`, so both branches of the templates report): the
  checkout, then a step that receives the `PRIVATE_TERMS` repository secret
  through `env:` (never inside the `run:` text) and writes it with
  `printf '%s\n' "$PRIVATE_TERMS" > "$RUNNER_TEMP/private-terms"` — outside
  `$GITHUB_WORKSPACE` — exporting `PRIVATE_TERMS_FILE` when it is
  non-empty, and exporting `PRIVATE_REFS_REQUIRE_TERMS=1` when
  `github.event_name == 'push'` or the pull request's head repository is
  this one — so a missing secret fails the job where the secret should
  exist and only a fork's pull request gets the loud pass; then `make
  check`.
- The job name and the step are the same words as the Makefile targets, so
  a red line in the run is a target to run at home.

### The workstation side

- `amont.conf` gains `pre-push  check  *  block  make check`, so a push
  runs what CI runs before the remote sees it (ADR-0009). Its cost is
  measured in Phase 2 (a warm `make check` wall time) before the entry is
  added, and recorded below; if the warm run is over 20 s, the pre-push
  entry runs `make lint private-refs` only and the render stays CI's.
- `.gitignore` (new, at the source root; chezmoi ignores dot-files there,
  so nothing is deployed) holds `.tools/`.
- `.chezmoiignore` gains `Makefile`, `tools.env` and `ci/`: chezmoi
  deploys every non-dot source file it is not told to ignore, and these
  three are repository machinery like `amont.conf` and `scripts/`.
- `README.md` gains the CI badge and one sentence: `make check` is what CI
  runs.

## Phases

- [x] Phase 1 — this plan, `docs/plans/2026-09-30-dotfiles-ci.md`, the
  first commit.
- [x] Phase 2 — `tools.env` (versions and asset checksums), `Makefile`
  (`tools`, `render`, `lint`, `private-refs`, `check`), `ci/chezmoi.toml`,
  `.gitignore`, `.chezmoiignore` entries, and the `--tree` mode of
  `scripts/check-private-refs.sh` (names only, `PRIVATE_REFS_REQUIRE_TERMS`).
  `make check` green locally on this Mac; recorded before Phase 3: the
  warm and the cold (empty `.tools/`) wall time of `make check`, the count
  of shellcheck findings the existing scripts produce today, and the
  `--tree` hit count (file names) against the real terms file — a hit
  already in the tree is fixed in this phase, since `--tree` fails on it
  where the staged mode never did.
- [x] Phase 3 — `.github/workflows/ci.yaml`, the `amont.conf` pre-push
  entry, the README line. **Before the push**: `gh secret set
  PRIVATE_TERMS --repo fredericrous/dotfiles < ~/.config/chezmoi/private-terms`
  (stdin, never argv), otherwise the first same-repository run fails by
  design. Then F4b (the first real implementation review), push, both
  runners green, merge.
- [ ] Phase 4 — record the F4b cycle (tokens, seconds, verdict, whether
  each finding was real) in the implementation-review plan's Verification,
  in decisions, as its Phase 4; set that plan's Phase 4 ticked. (Opened
  right after this PR merges; this plan's tick rides the next dotfiles
  change.)

## Decision log

- 2026-09-30 — tools are downloaded by release tag into `.tools/`, not
  taken from Homebrew or apt: the fleet's toolchain rules want one pin read
  by both the workstation and the runner, and a `brew install shellcheck`
  in the workflow would be a second, floating version.
- 2026-09-30 — the render check applies into a temp directory rather than
  `--dry-run`: a dry run also executes templates, but writing the files
  lets the target assert on what came out, and `--exclude
  encrypted,externals,scripts` keeps it hermetic.
- 2026-09-30 — `private-refs --tree` is a mode of the existing script, not
  a second script: one term file, one message, one place to fix.
- 2026-09-30 — the `PRIVATE_TERMS` secret is a copy of the workstation's
  terms file and can drift from it; whoever edits the file re-sets the
  secret (`gh secret set … < file`), and the README says so.

## Verification (input → expected → actual)

- `make tools` on this Mac → `.tools/chezmoi --version` prints v2.72.1,
  `.tools/shellcheck --version` prints 0.11.0; a second run downloads
  nothing.
- `tools.env` edited to a version that does not exist → `make tools` fails
  naming the tool and the tag; one checksum digit changed → fails naming
  the asset (falsifications), then restored.
- `git status --porcelain` after `make check` → empty (no state file, no
  tool, nothing rendered inside the tree).
- `.tools/chezmoi --config ci/chezmoi.toml --source . managed | grep -E
  '^(Makefile|tools.env|ci)'` → prints nothing.
- `make render` → the temp destination holds `.zshrc`, `.claude/CLAUDE.md`,
  `.claude/skills/worktree-task/SKILL.md`; a template broken on purpose
  (an unclosed `{{`) → `make render` fails naming the file
  (falsification), then restored.
- `make lint` → shellcheck runs over the computed list (printed) and exits
  0; a script with an unquoted `$var` in a for loop added on purpose →
  fails (falsification), then removed.
- `make private-refs` with `PRIVATE_TERMS_FILE` pointing at a temp file
  containing a term that IS in the tree (a word from `README.md`) → exit 1
  naming the file and not the line; with the real terms file → exit 0;
  with no file → the loud NOT-checking line and exit 0;
  `PRIVATE_REFS_REQUIRE_TERMS=1 PRIVATE_TERMS_FILE=/nonexistent make
  private-refs` → exit 1 naming the missing file.
- `make render` with `run_once_fisher.fish.tmpl` broken on purpose (an
  unclosed `{{`) → fails naming that file (falsification), then restored.
- `make check` → all four, green, wall time recorded.
  - Phase 2 actuals (2026-09-30, this Mac, Intel): cold `make check` 15 s,
    warm 9–10 s (pre-push keeps the full target, under 20 s); `make tools`
    twice → second run "(present)" for both, no request; wrong version →
    "tools: could not download …/v0.11.99/…"; one checksum digit → "tools:
    checksum mismatch for shellcheck-v0.11.0.darwin.x86_64.tar.xz";
    `git status --porcelain` after `make check` → only the intended files;
    `chezmoi managed` → none of `Makefile`, `tools.env`, `ci`; broken
    `run_once_fisher.fish.tmpl` → "render: … does not render"; broken
    `dot_claude/CLAUDE.md.tmpl` → chezmoi names it ("unclosed action …
    CLAUDE.md.tmpl:336"); an unquoted-loop script → 2 × SC2086, exit 1; a
    README word as a term → exit 1 naming `README.md`, line not shown; the
    real terms → 0 hits over 96 files (= tracked minus `encrypted_*`); no
    terms file → "NOT checking", exit 0; `PRIVATE_REFS_REQUIRE_TERMS=1`
    with no file, with a comments-only file, and with `[unclosed` → exit 1
    each; a term only in the include line of the `Application Support`
    settings template → that path named (the NUL-safe loop reaches it);
    the term `code` → `<path withheld>` ×4, the path never printed.
    shellcheck baseline on the tracked scripts before the fixes: 1 finding
    in the three scripts the plan named, 20 more in the six git helpers
    the shebang rule pulled in, all fixed (two were real bugs: literal
    backslash-quotes to `git commit`, `${2:REMOVED}` for a default).
- GitHub Actions: the PR's `check (ubuntu-latest)` and `check
  (macos-latest)` → both green; the run's step names are the target names;
  the downloaded run log contains no `NOT checking` line and no term from
  the secret.
  - dotfiles#14, run 36642805700 (2026-09-30): ubuntu 6 s, macos 12 s, both
    `success`; steps `make tools`, `make render`, `make lint`, `make
    private-refs`; the log holds 0 `NOT checking` lines, 0 matches of any
    term, `private-refs ok (96 plaintext files scanned)` on both runners,
    both tools reporting their pins on both. The `PRIVATE_TERMS` secret was
    set before the push with `gh secret set … < file`.
- A deliberate hit on a throwaway branch (a placeholder term added to the
  secret's file locally, `--tree` run with it) → exit 1 naming the file
  and NOT printing the term.
- Pre-push cost: warm `make check` wall time on this Mac, recorded, and the
  shellcheck finding count on the existing scripts before any fix.
- F4b: `amont-agent tree-sha --block` → the block; the
  `implementation-review` agent → its verdict and findings; each finding
  fixed or `deliberate:`; the push → silent, journal `unconfirmed reviewed`
  (the hook's live `reviewed` case, still unverified). Tokens and seconds
  recorded here and in the implementation-review plan.
  - 2026-09-30: block `repo=chezmoi sha=19bd0a5e…`; round 1
    approve-with-changes (52k, 78 s, 6 findings, 1 real bug: the invalid
    regex); Delta approve-with-changes (31k, 30 s); the push of this branch
    → the hook silent, one journal line `implementation-review unconfirmed
    reviewed`, pass file `by-tree/chezmoi/19bd0a5e….json` written by the
    hook. Found on the hook itself: its Bash guard refused a read-only `ls`
    of the pass files (amont-agent#61).

## Outcome

(filled when the plan closes)

<!-- panel: repos=dotfiles adds=ops reviewers=backend,platform body-sha=f5d3133cd045 -->
