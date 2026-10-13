#!/bin/sh
# skill-trigger-test — how often a skill's description makes Claude load it.
#
# Usage: skill-trigger-test <skill-dir> <prompts.tsv> [--runs N] [--max-usd X] [--quiet]
# --max-usd defaults to $0.35 per prompt and run.
#
# prompts.tsv has three tab-separated columns: id, should|near-miss, prompt.
# Each prompt runs `claude -p` from a scratch directory that holds a copy of
# the skill under a run-unique name, so an installed skill of the same name
# cannot answer for it (guidance.trigger-is-measured, ADR-0032).
#
# stdout: one sorted line per prompt (id, kind, verdict, hits/runs), then the
# summary. stderr: the run plan, then one progress line per run.
# Exit: 0 pass (should >= 80%, near-miss <= 10%), 1 below that, 2 usage,
# 3 a run errored or loaded the installed copy, or the budget ran out
# (3 wins over 1). Interrupted: 130 (INT) or 143 (TERM).

set -u

# launchd and non-interactive shells miss ~/.local/bin, where `claude` lives.
PATH="$HOME/.local/bin:$PATH"
export PATH

per_run_usd=0.5
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
parallel=5

usage() {
  echo "usage: skill-trigger-test <skill-dir> <prompts.tsv> [--runs N] [--max-usd X] [--quiet]" >&2
  exit 2
}

# --- worker: one claude run, called by xargs -------------------------------
if [ "${1:-}" = --worker ]; then
  id=$2 kind=$3 round=$4 prompt=$5
  out="$TT_DIR/out/$id.$round"
  # Budget guard, under a lock: start only if spent + in flight stays under it.
  until mkdir "$TT_DIR/lock" 2>/dev/null; do sleep 0.1; done
  spent=$(cat "$TT_DIR"/res/* 2>/dev/null | awk '{ s += $5 } END { printf "%.4f", s + 0 }')
  inflight=$(find "$TT_DIR/run" -type f | wc -l | tr -d ' ')
  if awk -v s="$spent" -v i="$inflight" -v p="$per_run_usd" -v m="$TT_MAX" \
    'BEGIN { exit !(s + (i + 1) * p > m) }'; then
    rmdir "$TT_DIR/lock"
    printf '%s %s %s budget 0\n' "$id" "$kind" "$round" >"$TT_DIR/res/$id.$round"
    printf '%-10s budget  not run: the budget would be exceeded\n' "$id" >&2
    exit 0
  fi
  : >"$TT_DIR/run/$id.$round"
  rmdir "$TT_DIR/lock"

  (cd "$TT_DIR/home" && claude -p "$prompt" --max-budget-usd "$per_run_usd" \
    --permission-mode default --disallowedTools Write,Edit,NotebookEdit \
    --allowedTools Skill --output-format stream-json --verbose \
    </dev/null >"$out.jsonl" 2>"$out.err")
  rc=$?
  verdict=$(jq -rs --arg copy "$TT_COPY" --arg orig "$TT_NAME" --argjson rc "$rc" '
    (map(select(.type == "result")) | last) as $r
    | [ .[] | select(.type == "assistant") | .message.content[]?
        | select(.type == "tool_use" and .name == "Skill") | .input.skill | tostring ] as $s
    | if $rc != 0 or $r == null or $r.is_error then "error"
      elif ($s | index($copy)) != null then "HIT"
      elif ($s | index($orig)) != null then "collision"
      else "miss" end' "$out.jsonl" 2>/dev/null || echo error)
  cost=$(jq -rs '(map(select(.type == "result")) | last | .total_cost_usd) // 0' "$out.jsonl" 2>/dev/null || echo 0)
  printf '%s %s %s %s %s\n' "$id" "$kind" "$round" "$verdict" "$cost" >"$TT_DIR/res/$id.$round"
  rm -f "$TT_DIR/run/$id.$round"
  printf '%-10s %-9s %s\n' "$id" "$verdict" "$prompt" | cut -c1-80 >&2
  exit 0
fi

# --- arguments ---------------------------------------------------------------
[ $# -ge 2 ] || usage
skill_dir=${1%/}
prompts=$2
shift 2
runs=1
max_usd=
quiet=0
while [ $# -gt 0 ]; do
  case $1 in
    --runs) [ $# -ge 2 ] || usage; runs=$2; shift 2 ;;
    --max-usd) [ $# -ge 2 ] || usage; max_usd=$2; shift 2 ;;
    --quiet) quiet=1; shift ;;
    *) usage ;;
  esac
done
case $runs in '' | *[!0-9]* | 0) usage ;; esac
case $max_usd in *[!0-9.]*) usage ;; esac
[ -f "$skill_dir/SKILL.md" ] || { echo "skill-trigger-test: no SKILL.md in $skill_dir" >&2; exit 2; }
[ -f "$prompts" ] || { echo "skill-trigger-test: no prompts file $prompts" >&2; exit 2; }
if ! awk -F'\t' 'NF && !/^#/ && (NF != 3 || ($2 != "should" && $2 != "near-miss")) { bad = 1 } END { exit bad }' "$prompts"; then
  echo "skill-trigger-test: $prompts needs 3 tab-separated columns: id, should|near-miss, prompt" >&2
  exit 2
fi
for tool in claude jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "skill-trigger-test: $tool not found on PATH" >&2; exit 3; }
done

name=$(awk '/^---$/ { f++; next } f == 1 && /^name:/ { sub(/^name:[ \t]*/, ""); print; exit }' "$skill_dir/SKILL.md")
[ -n "$name" ] || name=$(basename "$skill_dir")
copy="$name-tt-$$"

# --- scratch dir, signals ------------------------------------------------------
TT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/skill-trigger-test.XXXXXX") || exit 3
jobs_pgid=
cleanup() { rm -rf "$TT_DIR"; }
on_signal() {
  trap - INT TERM EXIT
  # The workers run in their own process group (set -m below): kill that
  # group, never group 0, which may be the caller's shell.
  [ -n "$jobs_pgid" ] && kill -TERM "-$jobs_pgid" 2>/dev/null
  cleanup
  exit "$1"
}
trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

mkdir -p "$TT_DIR/home/.claude/skills" "$TT_DIR/out" "$TT_DIR/res" "$TT_DIR/run"
cp -R "$skill_dir" "$TT_DIR/home/.claude/skills/$copy"
awk -v copy="$copy" '/^---$/ { f++ } f == 1 && /^name:/ { print "name: " copy; next } { print }' \
  "$skill_dir/SKILL.md" >"$TT_DIR/home/.claude/skills/$copy/SKILL.md"

n=$(awk -F'\t' 'NF && !/^#/' "$prompts" | wc -l | tr -d ' ')
# Default ceiling: $0.35 a run, the measured mean ($0.26, 2026-10-13) plus headroom.
[ -n "$max_usd" ] || max_usd=$(awk -v n="$n" -v r="$runs" 'BEGIN { printf "%.2f", n * r * 0.35 }')
printf '%s prompts × %s runs, ceiling $%s (≤ $%s a run), skill %s\n' "$n" "$runs" "$max_usd" "$per_run_usd" "$name" >&2

export TT_DIR TT_COPY="$copy" TT_NAME="$name" TT_MAX="$max_usd" per_run_usd

# --- runs ----------------------------------------------------------------------
set -m
r=1
while [ "$r" -le "$runs" ]; do
  awk -F'\t' -v r="$r" 'NF && !/^#/ { print $1 "\t" $2 "\t" r "\t" $3 }' "$prompts"
  r=$((r + 1))
done | tr '\t\n' '\000\000' | xargs -0 -n 4 -P "$parallel" "$self" --worker &
jobs_pid=$!
# $! is the pipeline's last process (xargs); its group is led by the first.
jobs_pgid=$(ps -o pgid= -p "$jobs_pid" | tr -d ' ')
wait "$jobs_pid"
set +m

# --- report --------------------------------------------------------------------
cat "$TT_DIR"/res/* 2>/dev/null | awk -v quiet="$quiet" '
  { kind[$1] = $2; runs[$1]++; cost += $5
    if ($4 == "HIT") hits[$1]++
    else if ($4 == "error" || $4 == "collision" || $4 == "budget") { bad[$1] = $4; broken++ } }
  END {
    for (id in runs) {
      h = hits[id] + 0
      if (kind[id] == "should") { st += runs[id]; sh += h; fail = h < runs[id] }
      else { nt += runs[id]; nh += h; fail = h > 0 }
      verdict = (id in bad) ? bad[id] : (fail ? "FAIL" : "ok")
      if (!quiet || verdict != "ok") printf "%s\t%s\t%s\t%d/%d\n", id, kind[id], verdict, h, runs[id] | "sort"
    }
    close("sort")
    printf "should %d/%d · near-miss %d/%d · $%.2f\n", sh, st, nh, nt, cost
    if (broken) exit 3
    if (st == 0 || sh * 10 < st * 8 || nh * 10 > nt) exit 1
    exit 0
  }'
