#!/usr/bin/env bash
# Fork the interface skills out of an upstream skills checkout, dropping the
# "better-" prefix. Usage: fork-interface-skills.sh <upstream-skills-dir> <dest-dir> <name>...
# Each <name> is copied from <upstream>/better-<name>, or from
# <upstream>/interface-review as is; agents/ and LICENSE are not copied.
# Each rewrite is counted before and after; a mismatch, or any "better-"
# left outside NOTICE.md, is an error.
# shellcheck disable=SC2016  # backticks are literal in the patterns
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <upstream-skills-dir> <dest-dir> <name>..." >&2
  exit 2
fi
upstream=$1
dest=$2
shift 2

# count <ere> <dir>: occurrences of the pattern under dir (NOTICE.md aside).
count() {
  { grep -rhoE --exclude=NOTICE.md -e "$1" "$2" || true; } | wc -l | tr -d ' '
}

die() {
  echo "fork-interface-skills: $*" >&2
  exit 1
}

P_STAR='the `better-\*` skills'
P_PREFIX='without the `better-` prefix'
P_NAME='^name: better-[a-z]+'
P_TICK='`better-[a-z]+`'

mkdir -p "$dest"
for name in "$@"; do
  case "$name" in
    interface-review) src="$upstream/interface-review" ;;
    *) src="$upstream/better-$name" ;;
  esac
  [ -d "$src" ] || die "missing upstream directory $src"
  rm -rf "${dest:?}/$name"
  mkdir -p "$dest/$name"
  cp -R "$src/." "$dest/$name/"
  rm -rf "$dest/$name/agents" "$dest/$name/LICENSE"

  out="$dest/$name"
  b_star=$(count "$P_STAR" "$out")
  b_prefix=$(count "$P_PREFIX" "$out")
  b_new_star=$(count 'the interface skills' "$out")
  b_new_prefix=$(count "the owning skill's name" "$out")

  while IFS= read -r -d '' f; do
    tmp=$(mktemp)
    sed -E \
      -e 's/the `better-\*` skills/the interface skills/g' \
      -e 's/without the `better-` prefix/as its bare name/g' \
      -e 's/the owning skill as its bare name/the owning skill'"'"'s name/g' \
      -e 's/^name: better-/name: /' \
      -e 's/`better-([a-z]+)`/`\1`/g' \
      -e 's/`better-\*`/interface/g' \
      "$f" >"$tmp"
    cat "$tmp" >"$f"
    rm -f "$tmp"
  done < <(find "$out" -type f -name '*.md' ! -name NOTICE.md -print0)

  [ "$(count "$P_STAR" "$out")" = 0 ] || die "$name: better-* rewrite incomplete"
  [ "$(count 'the interface skills' "$out")" = "$((b_new_star + b_star))" ] ||
    die "$name: count mismatch for the better-* skills phrase"
  [ "$(count "$P_PREFIX" "$out")" = 0 ] || die "$name: prefix phrase rewrite incomplete"
  [ "$(count "the owning skill's name" "$out")" = "$((b_new_prefix + b_prefix))" ] ||
    die "$name: count mismatch for the prefix phrase"
  [ "$(count "$P_NAME" "$out")" = 0 ] || die "$name: name line rewrite incomplete"
  [ "$(count "$P_TICK" "$out")" = 0 ] || die "$name: backticked better-x rewrite incomplete"

  left=$(grep -rn --exclude=NOTICE.md 'better-' "$out" || true)
  [ -z "$left" ] || die "$name: better- left over:
$left"
done
