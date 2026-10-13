# Trigger test — diagnosing-bugs

> Superseded by `~/.claude/tools/skill-trigger-test` (source
> `dot_claude/tools/skill-trigger-test/`), with the prompts in
> `dot_claude/skills/diagnosing-bugs/trigger-prompts.tsv`. This file keeps the
> harness that produced the 2026-10-13 numbers.

The harness behind the plan's trigger rows, kept so a later description
change can be measured the same way. Prompts `p*` should load the skill;
`n*` are near-misses (a fix whose cause is known, other work). Positive
wording is mined from the person's own prompts, names generalised.

Set-up: a scratch directory holding `.claude/skills/diagnosing-bugs/` (a copy
of the source skill), `prompts.tsv`, `run.sh` and an `out/` directory. Run
all 20, five at a time:

```sh
awk -F'\t' '{print $1"\t"$2}' prompts.tsv |
  while IFS="$(printf '\t')" read -r id p; do printf '%s\0%s\0' "$id" "$p"; done |
  xargs -0 -n 2 -P 5 sh -c './run.sh "$0" "$1" r1' | sort
```

Pass: at least 8/10 `p*` HIT and at most 1/10 `n*` HIT. Cost: about $4 a round
on the default model.

## prompts.tsv

```
p01	investigate why apps/builder-webapp fails check, then fix it
p02	look into the billing canary failure
p03	investigate this flaky test in tests/sync.spec.ts
p04	do we have crashloop pods that leak memory? fix the leak
p05	I opened the app with ?subdebug=1, played my video and got "error occurred when downloading"
p06	auth on cli worked, auth on phone did not. I tried the qrcode but authentication failed with invalid authentication url
p07	the east-west gateway is in a crash loop, fix it
p08	the homelab PR has red tests, figure out why and fix
p09	the div with class wrap still misses 24 px bottom padding, I thought you fixed it
p10	fix the amont bug: on a cold commit the "tree lint cold — warming" line is never printed even though the warm-up does run
n01	fix vault-transit-unseal-operator lint
n02	implement all 5 fixes from the review
n03	add a dark mode toggle to the settings page
n04	review PR #24 and merge it when green
n05	why did we choose pnpm over bun?
n06	tag a release of duro-design-system
n07	is attest configured in all our active repos?
n08	fix the broken pin and make ci assert the tag exists
n09	address the cosmetic gap in the header spacing per the artboard
n10	write a plan to migrate the CI runners to the new cluster
```

## run.sh

```sh
#!/bin/sh
# usage: run.sh <id> <prompt> <round>
cd "$(dirname "$0")" || exit 1
claude -p "$2" --max-budget-usd 0.5 --permission-mode default --disallowedTools Write,Edit,NotebookEdit --allowedTools Skill --output-format stream-json --verbose > "out/$1.$3.jsonl" 2>/dev/null
if jq -e 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill" and (.input.skill|tostring|test("diagnosing-bugs")))' "out/$1.$3.jsonl" >/dev/null 2>&1; then echo "$1 HIT"; else echo "$1 miss"; fi
```
