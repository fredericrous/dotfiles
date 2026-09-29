#!/bin/sh
# `make render`: every template renders against the placeholder data in
# ci/chezmoi.toml, into a temporary destination, hermetically — no key
# (encrypted files excluded), no network (externals excluded), no script run
# (scripts excluded). The two run_once_* templates are the ones that call
# `include` and `lookPath`, so they are rendered on their own with
# execute-template. chezmoi's state file goes into the same temporary
# directory: it otherwise lands beside the config file and dirties the tree.

set -eu

cd "$(dirname "$0")/.."
CHEZMOI=.tools/chezmoi
CONFIG=ci/chezmoi.toml

dst=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-render.XXXXXX")
trap 'rm -rf "$dst"' EXIT INT TERM
state="$dst/state.boltdb"

run() {
  "$CHEZMOI" --config "$CONFIG" --persistent-state "$state" --source . "$@"
}

run --destination "$dst" apply --exclude encrypted,externals,scripts

# What must have come out.
for f in .zshrc .claude/CLAUDE.md .claude/skills/worktree-task/SKILL.md; do
  if [ ! -s "$dst/$f" ]; then
    echo "render: $f is missing or empty in the rendered home" >&2
    exit 1
  fi
done
# What must never reach a home directory (see .chezmoiignore).
for f in Makefile tools.env ci amont.conf scripts docs README.md; do
  if [ -e "$dst/$f" ]; then
    echo "render: $f was deployed; it belongs to the repository, not a home — add it to .chezmoiignore" >&2
    exit 1
  fi
done

# The run_once_* templates, one by one. Listed with a git pathspec: `*`
# matches across `/`, and the two live at different depths. NUL-safe, since
# a tracked path in this repository contains a space.
n=0
git ls-files -z -- '*run_once_*.tmpl' | tr '\0' '\n' > "$dst/run_once.list"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n + 1))
  echo "  render $f"
  if ! run execute-template < "$f" > /dev/null; then
    echo "render: $f does not render" >&2
    exit 1
  fi
done < "$dst/run_once.list"
if [ "$n" -lt 2 ]; then
  echo "render: expected at least 2 run_once_* templates, found $n" >&2
  exit 1
fi

# The config template itself, as `chezmoi init` would render it, answering
# the one prompt that has no default. With the ci config, promptStringOnce
# reads placeholders, never a workstation's real data.
if ! run execute-template --init --promptString "bitwarden server url=x" < .chezmoi.toml.tmpl \
  | grep -q 'encryption = "gpg"'; then
  echo "render: .chezmoi.toml.tmpl does not render to a config that sets encryption" >&2
  exit 1
fi

echo "  render ok ($n run_once templates, config template, home applied to a temp dir)"
