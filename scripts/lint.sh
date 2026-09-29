#!/bin/sh
# `make lint`: shellcheck, pinned in .tools/, over every tracked shell
# script — `*.sh`, plus any tracked file whose first line is a sh or bash
# shebang. fish and PowerShell are not shellcheck's business. The list is
# computed, printed and NUL-safe: a tracked path here contains a space.

set -eu

cd "$(dirname "$0")/.."
SHELLCHECK=.tools/shellcheck

tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-lint.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM

# Tracked files, one per line, spaces intact (paths here hold no newline).
git ls-files -z | tr '\0' '\n' > "$tmp"
total=$(grep -c . "$tmp")

n=0
list=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.sh) ;;
    *)
      # The first 64 bytes, NUL stripped: a tracked binary is not a script.
      first=$(LC_ALL=C head -c 64 "$f" 2>/dev/null | tr -d '\0' | head -n 1 || true)
      case "$first" in
        '#!'*/sh|'#!'*/bash|'#!'*' sh'|'#!'*' bash'|'#!'*/sh' '*|'#!'*/bash' '*|'#!'*' sh '*|'#!'*' bash '*) ;;
        *) continue ;;
      esac ;;
  esac
  n=$((n + 1))
  echo "  lint   $f"
  list="$list
$f"
done < "$tmp"

if [ "$n" -eq 0 ]; then
  echo "lint: no shell script found among $total tracked files" >&2
  exit 1
fi

# One shellcheck run over the list; a path with a space survives the loop.
printf '%s\n' "$list" | sed '/^$/d' | while IFS= read -r f; do
  printf '%s\0' "$f"
done | xargs -0 "$SHELLCHECK" --external-sources

echo "  lint   ok ($n scripts of $total tracked files)"
