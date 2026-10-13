#!/bin/sh
# Weekly retrospective over the sessions amont-agent flagged.
#
# The retro skill cannot trigger itself: it judges a session after the fact,
# and a SessionEnd hook gets 1.5 s. So launchd runs this every Monday
# (com.fredericrous.retro-weekly). It picks the sessions of the last 7 days
# with the most amont-agent deny/advise lines, runs the retro skill on each in
# a headless, read-only Claude call, and writes one report the person reads:
# ~/.claude/retro/YYYY-MM-DD.md, first line `candidates: N`.
#
# `claude -p` is given the skill's body as the prompt, not `/retro`: the skill
# is person-invoked (disable-model-invocation), so the model cannot load it.
#
# Read-only even when the person's settings default to bypass mode:
# --permission-mode default plus --disallowedTools; a shell redirect is
# refused as an edit (checked 2026-10-13, see docs/plans/).

set -u

retro_dir="${RETRO_DIR:-$HOME/.claude/retro}"
journal="$HOME/.claude/amont-agent/journal.log"
skill="${RETRO_SKILL:-$HOME/.claude/skills/retro/SKILL.md}"
max_sessions=3
max_bytes=104857600 # 100 MB; a 61 MB transcript cost under $1 read by jq windows
budget_usd=1
tools='Read,Grep,Glob,Bash(jq:*),Bash(grep:*),Bash(amont-agent mine:*),Bash(sort:*),Bash(uniq:*),Bash(head:*),Bash(wc:*)'

mkdir -p "$retro_dir" || exit 1
cd "$retro_dir" || exit 1

report="$retro_dir/$(date +%F).md"
sections=$(mktemp) || exit 1
trap 'rm -f "$sections" "$sections.json" "$sections.err"' EXIT

# This batch's own Claude runs are recorded under the slug of its cwd; a run
# that tripped a hook must not be picked up as a session to review.
own_slug=$(printf '%s' "$retro_dir" | tr '/.' '--')

notify() {
  osascript -e "display notification \"$1\" with title \"retro\"" >/dev/null 2>&1 || true
}

since=$(($(date +%s) - 604800))
ids=$(awk -v s="$since" '$1 == "F" && $2 >= s && ($4 == "deny" || $4 == "advise") { print $6 }' "$journal" 2>/dev/null |
  sort | uniq -c | sort -rn | awk '{ print $2 }')

total=0
reviewed=0
for id in $ids; do
  [ "$reviewed" -ge "$max_sessions" ] && break
  transcript=$(find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -name "$id*.jsonl" | head -n 1)
  [ -n "$transcript" ] || continue
  case "$transcript" in
    */"$own_slug"/*) continue ;;
  esac
  reviewed=$((reviewed + 1))
  bytes=$(wc -c <"$transcript" | tr -d ' ')
  {
    printf "\n## Session %s\n\n\`%s\` (%s bytes)\n\n" "$id" "$transcript" "$bytes"
  } >>"$sections"
  if [ "$bytes" -gt "$max_bytes" ]; then
    printf 'Skipped: over the %s-byte limit.\n' "$max_bytes" >>"$sections"
    continue
  fi
  body=$(awk 'f >= 2 { print } /^---$/ { f++ }' "$skill")
  if claude -p "$body

Sessions: $transcript" \
    --model sonnet --max-budget-usd "$budget_usd" \
    --permission-mode default --disallowedTools Write,Edit,NotebookEdit \
    --allowedTools "$tools" \
    --add-dir "$HOME/.claude/projects" "$HOME/.claude/amont-agent" \
    --output-format json >"$sections.json" 2>"$sections.err" &&
    [ "$(jq -r '.is_error' "$sections.json" 2>/dev/null)" = false ]; then
    result=$(jq -r '.result // ""' "$sections.json")
    cost=$(jq -r '.total_cost_usd // "?"' "$sections.json")
    n=$(printf '%s\n' "$result" | sed -n 's/^candidates: *\([0-9][0-9]*\).*/\1/p' | head -n 1)
    total=$((total + ${n:-0}))
    printf 'total_cost_usd: %s\n\n%s\n' "$cost" "$result" >>"$sections"
  else
    # Exit 0 with is_error (a spent budget, a max-turns stop) fails here too.
    rc=$?
    printf "Failed: exit %s\n\n\`\`\`\n%s\n%s\n\`\`\`\n" "$rc" "$(jq -r '.subtype // empty, .result // empty' "$sections.json" 2>/dev/null | tail -n 5)" "$(tail -n 20 "$sections.err")" >>"$sections"
  fi
done

{
  printf 'candidates: %s\n\n# Retro %s\n\n' "$total" "$(date +%F)"
  if [ "$reviewed" -eq 0 ]; then
    printf 'No session flagged by amont-agent in the last 7 days.\n'
  else
    printf 'Sessions: the %s with the most amont-agent deny/advise lines in the last 7 days.\n' "$reviewed"
    cat "$sections"
  fi
} >"$report"

notify "$total candidates in $(basename "$report")"
