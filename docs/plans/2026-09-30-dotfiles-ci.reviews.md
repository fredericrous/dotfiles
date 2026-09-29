# Full reviews — dotfiles gets the CI its rules require

Reference for [the plan](2026-09-30-dotfiles-ci.md). Written by the panel on 2026-09-30; not part of the reviewed body.

## Full reviews (reference)
### plan-review-backend, round 1 — approve-with-changes (39k, 62 s)

1. [blocking] `Makefile`, `tools.env`, `ci/` would be deployed to `$HOME` (`.chezmoiignore:1-7`). → applied: ignored; `render` asserts their absence.
2. [blocking] CI infrastructure undeclared. → applied: `adds=ops`.
3. [high] `ci/chezmoistate.boltdb` would dirty the tree. → applied: `--persistent-state "$dst/state.boltdb"`; `git status --porcelain` check.
4. [high] Matching lines printed into a public log. → applied: names only in `--tree`.
5. [medium] Silent pass on a missing secret for pushes to `main`. → applied: `PRIVATE_REFS_REQUIRE_TERMS=1` on push and same-repo PRs.
6. [medium] Installer script piped to `sh`, no checksums. → applied: release assets + SHA-256 per asset in `tools.env`.
7. [low] Unmeasured pre-push cost, no shellcheck baseline. → applied: measured in Phase 2.
Would measure: `chezmoi managed` shows none of the three; `git status --porcelain` empty; a deliberate hit names the file, not the term.

### plan-review-backend, round 2 — approve-with-changes (36k, 57 s)

1–7 resolved. New: 1. [medium] no test of the `REQUIRE_TERMS` failure path → applied. 2. [medium] shellcheck may publish no checksums; asset naming → applied (computed at pin time; mapping written out). 3. [low] config-template check without the ci config → applied. 4. [low] pre-push cost unbounded → applied (20 s, else `lint private-refs`). 5. [low] a path can carry a term → applied (`<path withheld>`).

### plan-review-platform, round 1 — approve-with-changes (36k, 50 s)

1. [high] `run_once_*.tmpl` skipped by the apply → applied: each rendered with `execute-template`; falsification added.
2. [high] no step creates the secret; first same-repo run would fail → applied: `gh secret set … < file` before the push; drift recorded.
3. [medium] secret placement → applied: `env:` + `printf` into `$RUNNER_TEMP`.
4. [medium] no `permissions:`, unpinned action → applied: `contents: read`, checkout pinned by SHA.
5. [low] `--tree` baseline and cold time → applied.
Would measure: a broken `run_once` template goes red; first same-repo run red then green after the secret; cold vs warm `make check`.

### plan-review-backend, final binding — approve-with-changes (37k, 49 s)

1–5 resolved. **Carried into Phase 2:** [high] `for f in $staged` splits `private_Library/private_Application Support/…/settings.json.tmpl` on the space and skips it silently — `--tree`, the staged mode and `lint` read `git ls-files -z` / `git diff --cached -z` NUL-safely; a term planted only in that file → exit 1. [medium] `lint`'s list built from `-z` and its count compared to `git ls-files`. [low] under `REQUIRE_TERMS`, an empty pattern (comments-only terms file) is a failure; falsification with `# x`. [low] the `include`/`lookPath` claim holds today; no edit.

### plan-review-platform, final binding — approve-with-changes (32k, 30 s)

1–5 resolved. **Carried into Phase 2:** [medium] `execute-template < $f` makes chezmoi name `stdin`, so the Makefile prints `render: $f` and exits 1 itself. [medium] `--persistent-state "$dst/state.boltdb"` on both `execute-template` calls too, run before `dst` is removed. [low] the two `run_once` templates are at different depths — list them with `git ls-files '*run_once_*.tmpl'`, print the list, fail under 2 entries.
