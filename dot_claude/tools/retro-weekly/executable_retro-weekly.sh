#!/bin/sh
# Weekly retrospective over the sessions greenbelay flagged.
#
# The retro skill cannot trigger itself: it judges a session after the fact,
# and a SessionEnd hook gets 1.5 s. So launchd runs this every Monday
# (com.fredericrous.retro-weekly). It picks the sessions of the last 7 days
# with the most greenbelay deny/advise lines, runs the retro skill on each in
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

# launchd's login zsh does not read .zshrc, where ~/.local/bin (the `claude`
# install) joins PATH; jq and osascript are on the login PATH already.
PATH="$HOME/.local/bin:$PATH"
export PATH

retro_dir="${RETRO_DIR:-$HOME/.claude/retro}"
journal="$HOME/.claude/greenbelay/journal.log"
skill="${RETRO_SKILL:-$HOME/.claude/skills/retro/SKILL.md}"
max_sessions=3
max_bytes=104857600 # 100 MB; a 61 MB transcript cost under $1 read by jq windows
budget_usd=1
tools='Read,Grep,Glob,Bash(jq:*),Bash(grep:*),Bash(greenbelay mine:*),Bash(sort:*),Bash(uniq:*),Bash(head:*),Bash(wc:*)'

mkdir -p "$retro_dir" || exit 1
cd "$retro_dir" || exit 1

report="$retro_dir/$(date +%F).md"
sections=$(mktemp) || exit 1
trap 'rm -f "$sections" "$sections.json" "$sections.err" "$sections.ttd.g" "$sections.ttd.r" "$sections.ttd.err" "$sections.ttd.j" "$sections.ttd.s"' EXIT

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
    --add-dir "$HOME/.claude/projects" "$HOME/.claude/greenbelay" \
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

# ADR-0042 (harness.revisit-on-a-new-model): a model no harness review covers
# starts one. --check prints one line and exits 1 when that is so; any other
# status (2: a greenbelay too old to know the command) adds nothing.
harness=''
if command -v greenbelay >/dev/null 2>&1; then
  out=$(greenbelay harness-review --check 2>/dev/null)
  if [ $? -eq 1 ]; then
    harness="Harness: $out. Run \`greenbelay harness-review\` (ADR-0042)."
  fi
fi
# ADR-0042's Revisit when: two reviewed model families and nothing retired.
# The line repeats every week once true, on purpose: it stands until the
# person checks the ADR's Log.
# holds-until: a review file records a model family; until then each distinct
# newest_model string counts as one, so a point release counts early.
reviews="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/greenbelay/harness-review"
models=$(cat "$reviews"/*.json 2>/dev/null | jq -r '.newest_model // empty' 2>/dev/null | sort -u | grep -c .)
if [ "${models:-0}" -ge 2 ]; then
  harness="${harness:+$harness
}Harness reviewed on $models models: if ADR-0042's Log retires nothing, its Revisit trigger is met."
fi

# Time to done (ADR-0070, decisions time-to-done t01): greenbelay measures each
# plan, relais publishes its run hours, and this joins them on the session id
# and the session's window on the plan. Each tool is optional: absent
# (`command -v`), older (exit 2, an unknown flag) or a schema it does not
# know gives one line, and the report goes on.
ttd="$sections.ttd"
window=$(/bin/date -v-7d +%F)
bt='`'
# The last stderr line of a failed tool, in a code span.
last_err() {
  printf '%s%s%s' "$bt" "$(tail -n 1 "$ttd.err" | tr -d "$bt")" "$bt"
}
time_to_done() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is not installed: no time-to-done measure.\n'
    return
  fi
  if ! command -v greenbelay >/dev/null 2>&1; then
    printf 'greenbelay is not installed: no time-to-done measure.\n'
    return
  fi
  greenbelay plan-review stats --time --json --since "$window" >"$ttd.g" 2>"$ttd.err"
  rc=$?
  older_g='greenbelay gave no plan-review stats --time schema 1: no time-to-done measure.'
  if [ "$rc" -eq 2 ]; then
    printf '%s\n' "$older_g"
    return
  elif [ "$rc" -ne 0 ]; then
    printf 'greenbelay failed (exit %s): %s\n' "$rc" "$(last_err)"
    return
  elif [ "$(jq -r '.schema' "$ttd.g" 2>/dev/null)" != 1 ]; then
    printf '%s\n' "$older_g"
    return
  fi
  printf '[]' >"$ttd.r"
  relais_note=''
  older_r='relais is older than 0.62.0 (no report runs, schema 1): relais h is blank.'
  if ! command -v relais >/dev/null 2>&1; then
    relais_note='relais is not installed: relais h is blank.'
  else
    relais report runs --json --since "$window" >"$ttd.r" 2>"$ttd.err"
    rc=$?
    if [ "$rc" -eq 2 ]; then
      relais_note=$older_r
      printf '[]' >"$ttd.r"
    elif [ "$rc" -ne 0 ]; then
      relais_note="relais report runs failed (exit $rc): $(last_err); relais h is blank."
      printf '[]' >"$ttd.r"
    elif [ "$(jq -r '.schema' "$ttd.r" 2>/dev/null)" != 1 ]; then
      relais_note=$older_r
      printf '[]' >"$ttd.r"
    elif [ "$(jq '.runs | length' "$ttd.r" 2>/dev/null)" = 0 ]; then
      relais_note='relais recorded no run in the window.'
    fi
  fi
  # The table goes to its own file and is printed only once jq succeeds, so
  # a failure never leaves half a table.
  if jq -r --slurpfile r "$ttd.r" '
    def t: sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601;
    ($r[0] | if type == "object" then .runs else [] end) as $runs
    | def rh($p): [$runs[] | . as $u | select(any($p.sessions[];
          .id == $u.root_session and ($u.started_at | t) >= (.from | t) and ($u.started_at | t) <= (.to | t))) | .hours] | add // 0;
    (.plans | map(. + {relais_h: rh(.)})) as $ps
    | "| plan | elapsed h | blocked h | relais h | person h | person stops | words × |",
      "|---|---:|---:|---:|---:|---:|---:|",
      ($ps[] | "| \(.repo)/\(.branch)\(if .reviewed then "" else " (unreviewed)" end) | \(.elapsed_h) | \(.blocked_h) | \(if ($runs|length) == 0 then "" else (.relais_h * 100 | round / 100) end) | \(.person_h) | \(.stops) | \(if (.words.round1 // 0) > 0 then (.words.final / .words.round1 * 100 | round / 100) else "-" end) |"),
      "",
      "relais h overlaps blocked h (a foreground relais call is both): do not add them.",
      (if ($runs|length) > 0 then
        ([$runs[].hours] | add) as $all | ([$ps[].relais_h] | add // 0) as $hit
        | "relais hours that matched no plan session: \((($all - $hit) * 100 | round) / 100) of \(($all * 100 | round) / 100)."
       else empty end),
      "Summary: \(.summary.finished) finished plans, median blocked \(.summary.median_blocked_h // "-") h, unattributed \(.summary.unattributed_share // "-") of blocked (unmapped \(.summary.unmapped_share // "-"))."
  ' "$ttd.g" >"$ttd.j" 2>"$ttd.err"; then
    cat "$ttd.j"
  else
    printf 'The time-to-done join failed: %s\n' "$(last_err)"
  fi
  if [ -n "$relais_note" ]; then
    printf '\n%s\n' "$relais_note"
  fi
}
# Built before the report is opened: a slow or failing query never leaves
# today's report cut short.
time_to_done >"$ttd.s"

{
  printf 'candidates: %s\n\n# Retro %s\n\n' "$total" "$(date +%F)"
  if [ -n "$harness" ]; then
    printf '%s\n\n' "$harness"
  fi
  printf '## Time to done\n\nPlans done since %s.\n\n' "$window"
  cat "$sections.ttd.s"
  printf '\n'
  if [ "$reviewed" -eq 0 ]; then
    printf 'No session flagged by greenbelay in the last 7 days.\n'
  else
    printf 'Sessions: the %s with the most greenbelay deny/advise lines in the last 7 days.\n' "$reviewed"
    cat "$sections"
  fi
} >"$report"

notify "$total candidates in $(basename "$report")"
