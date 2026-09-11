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
# Scoped to what is STAGED, so a pre-existing reference in an untouched file is
# not this commit's problem — the rule amont's own checks follow.
#
# Values, not mechanisms: `~/.netrc` and mTLS are standard and belong in
# readable documentation. Ban what names a person or a machine.

set -eu

TERMS_FILE="${PRIVATE_TERMS_FILE:-$HOME/.config/chezmoi/private-terms}"

if [ ! -r "$TERMS_FILE" ]; then
  # Fail OPEN, but loudly. Failing closed would block every commit on a machine
  # not set up yet, including the commit that sets it up; silence would leave
  # the repository unguarded with nothing to notice.
  echo "private-refs: no term list at $TERMS_FILE — NOT checking." >&2
  echo "  create it (one regex per line) or set PRIVATE_TERMS_FILE." >&2
  exit 0
fi

PATTERN=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$TERMS_FILE" \
  | grep -v '^$' | paste -sd '|' -)
[ -n "$PATTERN" ] || exit 0

staged=$(git diff --cached --name-only --diff-filter=ACM)
[ -n "$staged" ] || exit 0

found=''
for f in $staged; do
  # ciphertext cannot match, and skipping it keeps the scan cheap
  case "$f" in *encrypted_*) continue ;; esac
  [ -f "$f" ] || continue
  # the staged content, not the working tree: they can differ
  if git show ":$f" 2>/dev/null | grep -qiE "$PATTERN"; then
    found="$found $f"
  fi
done

[ -n "$found" ] || exit 0

echo "private identifiers in plaintext, in a PUBLIC repository:" >&2
for f in $found; do
  echo "  $f" >&2
  git show ":$f" | grep -inE "$PATTERN" | head -3 | sed 's/^/      /' >&2
done
cat >&2 <<'EOF'

Prefer templating the VALUE over encrypting the file: put it in [data] in
~/.config/chezmoi/chezmoi.toml — generated, outside the source tree — and
reference it as {{ .forge.host }}. The file stays readable and reviewable.

Encrypt the whole file only when the prose itself is the secret:
    chezmoi add --encrypt ~/<path>
EOF
exit 1
