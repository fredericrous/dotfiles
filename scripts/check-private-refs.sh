#!/bin/sh
# Refuse private identifiers in PLAINTEXT files.
#
# This repository is public. Hostnames of private infrastructure and employer
# names must not land here in clear. Encrypted entries are exempt by nature —
# an encrypted_*.asc is ciphertext, and grepping it finds nothing anyway.
#
# THE TERMS ARE NOT IN THIS FILE. They live in ~/.config/chezmoi/private-terms,
# outside the source tree, because a banned-terms list committed next to the
# check publishes precisely what it exists to hide. The first version of this
# script carried them inline and so re-introduced the forge host into the public
# repository — the guard leaking the thing it guards.
#
# Two modes:
#   (default)  the STAGED files — amont's pre-commit gate. A pre-existing
#              reference in an untouched file is not this commit's problem,
#              the rule amont's own checks follow. On a hit the matching
#              lines are shown: the terminal is the committer's own.
#   --tree     every tracked file — `make check`, and therefore CI. On a hit
#              only file names are printed, never the lines, because a CI
#              log is public and a regex term defeats GitHub's secret
#              masking; a path that itself matches is `<path withheld>`.
#
# The terms file is read from $PRIVATE_TERMS_FILE. Without one the check
# fails OPEN, loudly: failing closed would block every commit on a machine
# not set up yet, including the commit that sets it up. CI is different —
# there the secret should exist — so PRIVATE_REFS_REQUIRE_TERMS=1 makes a
# missing or empty terms file a failure (general.no-disabled-safety).
#
# Values, not mechanisms: `~/.netrc` and mTLS are standard and belong in
# readable documentation. Ban what names a person or a machine.

set -eu

mode=staged
case "${1:-}" in
  --tree) mode=tree ;;
  '') ;;
  *) echo "usage: $0 [--tree]" >&2; exit 2 ;;
esac

TERMS_FILE="${PRIVATE_TERMS_FILE:-$HOME/.config/chezmoi/private-terms}"
require="${PRIVATE_REFS_REQUIRE_TERMS:-}"

if [ ! -r "$TERMS_FILE" ]; then
  if [ -n "$require" ]; then
    echo "private-refs: no term list at $TERMS_FILE and PRIVATE_REFS_REQUIRE_TERMS is set — failing." >&2
    exit 1
  fi
  echo "private-refs: no term list at $TERMS_FILE — NOT checking." >&2
  echo "  create it (one regex per line) or set PRIVATE_TERMS_FILE." >&2
  exit 0
fi

PATTERN=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$TERMS_FILE" \
  | grep -v '^$' | paste -sd '|' -)
if [ -z "$PATTERN" ]; then
  if [ -n "$require" ]; then
    echo "private-refs: the term list at $TERMS_FILE holds no term and PRIVATE_REFS_REQUIRE_TERMS is set — failing." >&2
    exit 1
  fi
  exit 0
fi

# The files to scan, one per line, spaces intact (no tracked path holds a
# newline). NUL from git, because a tracked path here contains a space and
# word-splitting used to skip it without a word.
files=$(mktemp "${TMPDIR:-/tmp}/private-refs.XXXXXX")
trap 'rm -f "$files"' EXIT INT TERM
if [ "$mode" = tree ]; then
  git ls-files -z | tr '\0' '\n' > "$files"
else
  git diff --cached --name-only -z --diff-filter=ACM | tr '\0' '\n' > "$files"
fi
[ -s "$files" ] || exit 0

found=''
scanned=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # ciphertext cannot match, and skipping it keeps the scan cheap
  case "$f" in *encrypted_*) continue ;; esac
  [ -f "$f" ] || continue
  scanned=$((scanned + 1))
  if [ "$mode" = tree ]; then
    content() { cat "$f"; }
  else
    # the staged content, not the working tree: they can differ
    content() { git show ":$f" 2>/dev/null; }
  fi
  if content | grep -qiE "$PATTERN"; then
    found="$found
$f"
  fi
done < "$files"

if [ -z "$found" ]; then
  [ "$mode" = tree ] && echo "  private-refs ok ($scanned plaintext files scanned)"
  exit 0
fi

echo "private identifiers in plaintext, in a PUBLIC repository:" >&2
printf '%s\n' "$found" | sed '/^$/d' | while IFS= read -r f; do
  if [ "$mode" = tree ]; then
    if printf '%s' "$f" | grep -qiE "$PATTERN"; then
      echo "  <path withheld>" >&2
    else
      echo "  $f" >&2
    fi
  else
    echo "  $f" >&2
    git show ":$f" | grep -inE "$PATTERN" | head -3 | sed 's/^/      /' >&2
  fi
done
cat >&2 <<'EOF'

Prefer templating the VALUE over encrypting the file: put it in [data] in
~/.config/chezmoi/chezmoi.toml — generated, outside the source tree — and
reference it as {{ .forge.host }}. The file stays readable and reviewable.

Encrypt the whole file only when the prose itself is the secret:
    chezmoi add --encrypt ~/<path>
EOF
exit 1
