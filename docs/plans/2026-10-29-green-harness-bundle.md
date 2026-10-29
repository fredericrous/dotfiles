---
canonical: github:fredericrous/decisions/docs/plans/2026-10-29-green-harness-bundle.md
phases: [7]
status: done
branch: feat/grh-skills-from-repo
---
# Green Harness bundle

Pointer. The plan and its review panel live in decisions, with ADR-0050
(harness.skills-source). This repository carries phase 7: the published
skills and agents leave `dot_claude/` (grh places them from
greenharness/skills), and the private overlay keeps the Forgejo recipes.

## Verification

| Check | Input | Expected | Actual |
|---|---|---|---|
| backup first | tar of `~/.claude/{skills,agents}` | tarball before any change | `~/.local/state/grh-migration-backup-20261030-004629.tgz`, 463 entries |
| source check | `make check` (render, lint, private-refs) | rc 0 | rc 0 |
| laptop install | `grh install full workflow --replace --yes` (grh 0.1.0 from the tap) | exit 0; existing binaries adopted; published skills replace the old copies | exit 0; aval, amont, amont-agent, relais, adr-lint adopted; decisions and guardrails machine integrations already present, recorded adopted; router a reported gap (relais doctor has no integration state yet); 13 skills and 11 agents placed, each overwritten file backed up under `~/.local/state/grh/backup/`; relais-architecture-conflict and relais-verified-push left to relais (its marker) |
| status | `grh status` | parts installed | decisions, gate, guardrails, router, conform, workflow installed; router machine unknown |
| integrations | `amont-agent doctor`, `claude mcp get aval` | green, registered | green, registered |
| session | a fresh Claude Code session | workflow skills and the overlay listed | listed (forgejo-recipes, merge-when-green, plan-review, tag-release…) |
| no drift | `chezmoi diff --source <this branch> ~/.zshenv ~/.claude/skills/forgejo-recipes ~/.claude/CLAUDE.md` | empty | 0 lines (the laptop's newer cd-rule wording folded into CLAUDE.md.tmpl) |

## Implementation review

approve-with-changes after two deltas (44k + 47k + 49k). Fixed: the overlay names merge-when-green instead of "above", says which sweep.py reads the variables, and the zshenv guard needs both host and slug.
