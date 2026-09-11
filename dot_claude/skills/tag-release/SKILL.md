---
name: tag-release
description: Cut a version tag that drives a CI build/publish (npm, ghcr image, etc.) safely — commit, verify HEAD actually advanced, only then tag, then verify the published artifact.
---

# tag-release

Standing rule (see `~/.claude/CLAUDE.md` § Git hygiene): in repos where a `v*` tag drives CI build/publish, **never chain `git commit && git tag vX && git push origin vX` in one shot.** A commit-msg hook can reject the commit; the shell still proceeds to `git tag`, which then tags the OLD HEAD — CI builds/publishes the new version number from stale code. This has actually shipped a stale npm version once (unrecoverable — npm versions are immutable).

## Args

`args` = the target version (e.g. `1.18.1`) or a bump type (`patch`/`minor`/`major`). If omitted, ask, or infer the next patch version from the latest tag (`git describe --tags --abbrev=0`).

## Steps

1. **Land the code change as its own commit, if not already committed.**
   ```bash
   git status
   git add <explicit files>          # not -A/-u, per git-hygiene rule — check what's actually staged
   git commit -m "..."
   ```

2. **Verify HEAD actually advanced before doing anything else.**
   ```bash
   git log --oneline -1 HEAD
   ```
   Compare against the pre-commit SHA. If the commit-msg hook rejected the commit (common failure modes in this user's repos: subject >50 chars, gitmoji-prefix eating the character budget, `--no-verify` needed for a Helm-template false-positive), HEAD will NOT have moved. **STOP here if it didn't** — surface the hook's rejection reason, fix the commit message/content, and retry step 1. Do not proceed to tagging on an unchanged HEAD.

3. **Only once HEAD has confirmed-advanced, tag and push:**
   ```bash
   git tag v<version>
   git push origin v<version>
   ```
   (If the repo also needs the commit itself pushed to `main` first, per the repo-ownership rule, push the branch before or together with the tag — check the repo's actual release workflow trigger.)

4. **Watch the release workflow, verifying `conclusion` explicitly** (not `gh run watch --exit-status` alone — see `~/.claude/CLAUDE.md` § Before pushing):
   ```bash
   gh run list --repo <owner>/<repo> --limit 1 --json databaseId,status,conclusion
   gh run view <run-id> --json conclusion --jq .conclusion
   ```

5. **Verify the published artifact itself — not just "workflow: success."** A green workflow can still ship a stale/broken artifact (e.g. a chart-publish PR merging a stale `Chart.yaml`, or Flux sitting on the prior OCI revision for its reconcile interval). Check the actual thing:
   - npm: `npm view <pkg>@<version>` or `npm pack <pkg>@<version>` and inspect.
   - container image: check the digest/sha that was actually pushed (`gh api` on the release, or `docker manifest inspect`), not just that the job exited 0.
   - GH release: confirm the expected assets are attached.

## Recovery if the tag ended up on the wrong commit

- **Mutable registries (container images via ghcr, etc.):** delete the remote+local tag, re-tag the correct commit, cancel the bad in-flight release run, let the correct one rebuild. Recoverable.
- **Immutable registries (npm):** a stale publish cannot be overwritten. Bump to the next version instead (e.g. `0.35.2` → `0.35.3`) — don't attempt to force-republish the same version.
