"""Per-rule firing rates per 1,000 tool calls, each from the rule's last stance change."""
import calendar, json, os, glob, subprocess, sys, time
J = os.path.expanduser("~/.claude/amont-agent/journal.log")
RULES = sys.argv[1].split(",")
now = time.time()
since_floor = now - 7 * 86400 if len(sys.argv) < 3 else float(sys.argv[2])
until = now if len(sys.argv) < 4 else float(sys.argv[3])
rules_json = {r["id"]: r for r in json.loads(subprocess.run(["amont-agent", "rules", "--json"], capture_output=True, text=True).stdout)}
lines = []
for l in open(J, errors="replace"):
    p = l.split()
    # Column 4 is the stance; "unconfirmed" means the rule matched but its
    # confirm step said no: not a firing, not a stance.
    if len(p) > 4 and p[0] == "F" and p[1].isdigit() and p[3] in ("observe", "advise", "deny"):
        lines.append((int(p[1]), p[2], p[3]))
# tool_use timestamps from transcripts modified in range
uses = []
for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
    if os.path.getmtime(f) < since_floor: continue
    for l in open(f, errors="replace"):
        if '"tool_use"' not in l: continue
        try: e = json.loads(l)
        except Exception: continue
        if e.get("type") != "assistant": continue
        ts = e.get("timestamp")
        if not ts: continue
        t = calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))
        n = sum(1 for c in e.get("message", {}).get("content", []) if isinstance(c, dict) and c.get("type") == "tool_use")
        uses.append((t, n))
print("| rule | stance now | window from | fires | tool calls | per 1,000 |")
print("|---|---|---|---|---|---|")
for r in RULES:
    known = r in rules_json
    stance = rules_json[r]["stance"] if known else "not a rule"
    mine = [(t, s) for t, rr, s in lines if rr == r and since_floor <= t <= until]
    start = since_floor
    for t, s in mine:  # last stance change inside the window
        pass
    changes = [t for (t, s), (t0, s0) in zip(mine[1:], mine[:-1]) if s != s0]
    if changes: start = changes[-1]
    fires = sum(1 for t, s in mine if t >= start)
    calls = sum(n for t, n in uses if start <= t <= until)
    rate = 1000 * fires / calls if calls else 0
    print(f"| `{r}` | {stance}{'' if known else ''} | {time.strftime('%m-%d %H:%M', time.localtime(start))} | {fires} | {calls} | {rate:.2f} |")
