#!/bin/sh
# `make tools`: the pinned tools into .tools/, from the release asset of the
# pinned tag, verified against the checksum in tools.env before extraction.
# Never PATH's copy: a workstation and a runner must run the same binary
# (toolchain.tools-pinned-with-it, toolchain.one-pin-read-by-both).
#
# Idempotent: a tool already present at its pinned version is kept, so a
# second run sends no request.

set -eu

cd "$(dirname "$0")/.."
# A plain KEY=value file; shellcheck cannot follow it without -x (SC1091).
# shellcheck disable=SC1091
. ./tools.env

TOOLS=.tools
DL="$TOOLS/dl"
mkdir -p "$DL"

os=$(uname -s)
arch=$(uname -m)
case "$os/$arch" in
  Linux/x86_64)   chezmoi_asset=linux_amd64;  shellcheck_asset=linux.x86_64 ;;
  Darwin/x86_64)  chezmoi_asset=darwin_amd64; shellcheck_asset=darwin.x86_64 ;;
  Darwin/arm64)   chezmoi_asset=darwin_arm64; shellcheck_asset=darwin.aarch64 ;;
  *)
    echo "tools: no pinned asset for $os/$arch (tools.env knows linux/x86_64, darwin/x86_64, darwin/arm64)" >&2
    exit 1 ;;
esac

# The digest tool differs by platform; both print `<hex>  <file>`.
if command -v shasum >/dev/null 2>&1; then
  digest() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null 2>&1; then
  digest() { sha256sum "$1" | cut -d' ' -f1; }
else
  echo "tools: neither shasum nor sha256sum is available" >&2
  exit 1
fi

# have <binary> <pin>: the tool is already there at the pinned version.
have() {
  [ -x "$TOOLS/$1" ] && "$TOOLS/$1" --version 2>/dev/null | grep -qF "$2"
}

# fetch <url> <file> <expected sha256>
fetch() {
  if ! curl -fsSL --retry 3 -o "$2" "$1"; then
    echo "tools: could not download $1" >&2
    exit 1
  fi
  got=$(digest "$2")
  if [ "$got" != "$3" ]; then
    echo "tools: checksum mismatch for $(basename "$2"): tools.env says $3, the download is $got" >&2
    rm -f "$2"
    exit 1
  fi
}

# expect <binary> <pin>: refuse a binary that is not the pin it claims.
expect() {
  if ! "$TOOLS/$1" --version 2>/dev/null | grep -qF "$2"; then
    echo "tools: $TOOLS/$1 does not report $2:" >&2
    "$TOOLS/$1" --version >&2 || true
    exit 1
  fi
  echo "  tools  $1 $2"
}

# chezmoi: chezmoi_<ver>_<os>_<arch>.tar.gz, binary at the archive root.
ver=${CHEZMOI#v}
if have chezmoi "$CHEZMOI"; then
  echo "  tools  chezmoi $CHEZMOI (present)"
else
  sum=$(eval "printf '%s' \"\${CHEZMOI_SHA256_$chezmoi_asset}\"")
  tarball="$DL/chezmoi_${ver}_${chezmoi_asset}.tar.gz"
  fetch "https://github.com/twpayne/chezmoi/releases/download/$CHEZMOI/chezmoi_${ver}_${chezmoi_asset}.tar.gz" "$tarball" "$sum"
  tar -xzf "$tarball" -C "$TOOLS" chezmoi
  expect chezmoi "$CHEZMOI"
fi

# ShellCheck ships shellcheck-<tag>.<os>.<arch>.tar.xz, binary under shellcheck-<tag>/.
if have shellcheck "${SHELLCHECK#v}"; then
  echo "  tools  shellcheck $SHELLCHECK (present)"
else
  key=$(printf '%s' "$shellcheck_asset" | tr . _)
  sum=$(eval "printf '%s' \"\${SHELLCHECK_SHA256_$key}\"")
  tarball="$DL/shellcheck-$SHELLCHECK.$shellcheck_asset.tar.xz"
  fetch "https://github.com/koalaman/shellcheck/releases/download/$SHELLCHECK/shellcheck-$SHELLCHECK.$shellcheck_asset.tar.xz" "$tarball" "$sum"
  tar -xJf "$tarball" -C "$DL" "shellcheck-$SHELLCHECK/shellcheck"
  mv "$DL/shellcheck-$SHELLCHECK/shellcheck" "$TOOLS/shellcheck"
  rmdir "$DL/shellcheck-$SHELLCHECK"
  expect shellcheck "${SHELLCHECK#v}"
fi
