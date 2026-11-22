#!/usr/bin/env python3
"""Give an agent a repository's session context once: at SessionStart when the
session starts inside it, or at the first tool call that touches it.

Claude Code runs this as a hook and sends the event as one JSON object on
stdin. The command that prints the context comes after `--`, so this script
names no tool of its own. Examples:

  entry.py --session-start --name ctx --needle @scope/pkg- -- npx -y pkg context
  entry.py --name ctx --needle @scope/pkg- -- npx -y pkg context

Contract (the hook must never block a tool call):
  - the exit code is always 0; errors go to one stderr line;
  - stdout is empty, the context as plain text (--session-start, where
    SessionStart stdout joins the context), or one PreToolUse JSON object with
    the context as `additionalContext`;
  - the context is given once per session, agent and repository root: a marker
    file is claimed with O_CREAT|O_EXCL before the command runs, so parallel
    tool calls print once, and it is removed when the command fails, so the
    next call retries (after three failures, not again for ten minutes);
  - on a `resume`, `compact` or `clear` SessionStart the session's markers are
    cleared, because the earlier context is gone.

State lives under $XDG_STATE_HOME/<name> (default ~/.local/state/<name>):
markers, a failure counter per root and log.jsonl, one line per decision.
Sessions untouched for seven days are pruned.
"""

# Only what the common call needs is imported here: most calls find their
# marker and stop. json (with re), subprocess, shutil and signal load where
# they are used: json alone is about a third of a call's own cost.
import os
import sys
import time
import zlib

# Claude Code saves a hook's context to a file above 10,000 characters.
CAP = 9500
FAIL_LIMIT = 3
FAIL_WINDOW = 600
PRUNE_AGE = 7 * 86400
SKIP_DIRS = {"node_modules", ".git"}
MAX_DEPTH = 3
DEFAULT_LABEL = "context for {root} (first touch this session)"
FILE_TOOLS = {"Read", "Edit", "Write", "MultiEdit", "NotebookEdit"}


def parse_args(argv):
    """Split argv at `--`: options before it, the command after it."""
    options = {
        "session_start": False,
        "name": "entry-hook",
        "needles": [],
        "own_hooks": [],
        "timeout": 10.0,
        "label": DEFAULT_LABEL,
    }
    if "--" in argv:
        split = argv.index("--")
        head, command = argv[:split], argv[split + 1 :]
    else:
        head, command = argv, []
    i = 0
    while i < len(head):
        flag = head[i]
        if flag == "--session-start":
            options["session_start"] = True
        elif flag in ("--name", "--needle", "--own-hook", "--timeout", "--label"):
            i += 1
            if i >= len(head):
                raise ValueError(f"{flag} needs a value")
            value = head[i]
            if flag == "--name":
                options["name"] = value
            elif flag == "--needle":
                options["needles"].append(value)
            elif flag == "--own-hook":
                options["own_hooks"].append(value)
            elif flag == "--timeout":
                options["timeout"] = float(value)
            else:
                options["label"] = value
        else:
            raise ValueError(f"unknown option {flag}")
        i += 1
    if not command:
        raise ValueError("no command after --")
    options["command"] = command
    return options


def state_dir(name):
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, name)


def safe(text):
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in str(text)) or "_"


def digest(text):
    """A short stable name for a path: its last folder and a CRC of the whole."""
    tail = safe(os.path.basename(text.rstrip(os.sep)))[:40]
    return f"{tail}-{zlib.crc32(text.encode('utf-8')):08x}"


def read_event(stream):
    """The hook's JSON object from stdin, or None when it is not one.

    CPython's C scanner reads it without importing json, and so without re:
    the same parser json.loads uses. The scanner's private interface moves
    between Python versions (3.15 added `array_hook`), so any trouble falls
    back to json itself: slower, never wrong.
    """
    text = stream.read()
    try:
        from _json import make_scanner

        class Context:
            strict = True
            object_hook = None
            object_pairs_hook = None
            array_hook = None
            parse_float = float
            parse_int = int
            parse_constant = None
            memo = {}

        value, _ = make_scanner(Context())(text.lstrip(), 0)
    except Exception:
        import json

        try:
            value = json.loads(text)
        except ValueError:
            return None
    return value if isinstance(value, dict) else None


def log(state, **fields):
    import json

    try:
        os.makedirs(state, exist_ok=True)
        fields["ts"] = round(time.time(), 3)
        with open(os.path.join(state, "log.jsonl"), "a", encoding="utf-8") as handle:
            handle.write(json.dumps(fields) + "\n")
    except OSError:
        pass


def git_root(directory):
    """The repository root above a folder: the nearest `.git`, a folder or, in a worktree, a file.

    Walked in Python, on the real path, so a call that finds its marker never
    starts git and a symlinked path and its target name the same root.
    """
    current = os.path.realpath(directory)
    while True:
        if os.path.exists(os.path.join(current, ".git")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def nearest_dir(path):
    """The folder a path lives in, or the nearest parent that exists."""
    current = path if os.path.isdir(path) else os.path.dirname(path)
    while current and not os.path.isdir(current):
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent
    return current or None


def touched_dir(data):
    """Where a tool call works: its file's folder, else the cwd (Bash)."""
    cwd = data.get("cwd") or os.getcwd()
    tool_input = data.get("tool_input") or {}
    target = None
    if data.get("tool_name") in FILE_TOOLS and isinstance(tool_input, dict):
        target = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not target:
        return nearest_dir(cwd)
    return nearest_dir(os.path.abspath(os.path.join(cwd, str(target))))


def is_consumer(root, needles):
    """A cheap superset of the real test: some package.json names a needle.

    The command run in the root has the last word and prints nothing for a
    repository that is not a consumer. With no needle every repository passes.
    """
    if not needles:
        return True
    root_depth = root.rstrip(os.sep).count(os.sep)
    for folder, dirs, files in os.walk(root):
        depth = folder.count(os.sep) - root_depth
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS] if depth < MAX_DEPTH - 1 else []
        if "package.json" not in files:
            continue
        try:
            with open(os.path.join(folder, "package.json"), encoding="utf-8", errors="replace") as handle:
                text = handle.read(1_000_000)
        except OSError:
            continue
        if any(needle in text for needle in needles):
            return True
    return False


def marker_path(state, session, agent, root):
    return os.path.join(state, safe(session), safe(agent), digest(root))


def prune(state):
    import shutil

    now = time.time()
    try:
        entries = os.listdir(state)
    except OSError:
        return
    for entry in entries:
        path = os.path.join(state, entry)
        if entry in ("log.jsonl", "failures") or not os.path.isdir(path):
            continue
        try:
            if now - os.path.getmtime(path) > PRUNE_AGE:
                shutil.rmtree(path, ignore_errors=True)
        except OSError:
            pass


def claim(state, path):
    """Create the marker; False when it already exists."""
    first_of_session = not os.path.isdir(os.path.dirname(os.path.dirname(path)))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        return False
    os.close(descriptor)
    if first_of_session:
        prune(state)
    return True


def release(path):
    try:
        os.unlink(path)
    except OSError:
        pass


def failure_file(state, root):
    return os.path.join(state, "failures", digest(root))


def backing_off(state, root):
    try:
        with open(failure_file(state, root), encoding="utf-8") as handle:
            count, stamp = handle.read().split()
        return int(count) >= FAIL_LIMIT and time.time() - float(stamp) < FAIL_WINDOW
    except (OSError, ValueError):
        return False


def note_failure(state, root):
    path = failure_file(state, root)
    count = 0
    try:
        with open(path, encoding="utf-8") as handle:
            old, stamp = handle.read().split()
        if time.time() - float(stamp) < FAIL_WINDOW:
            count = int(old)
    except (OSError, ValueError):
        pass
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f"{count + 1} {time.time()}")
    except OSError:
        pass


def clear_failures(state, root):
    try:
        os.unlink(failure_file(state, root))
    except OSError:
        pass


def run_command(command, root, timeout):
    """Run the context command; (ok, stdout, reason). Kills its whole group on timeout."""
    import signal
    import subprocess

    try:
        child = subprocess.Popen(
            command,
            cwd=root,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
    except OSError as error:
        return False, "", f"cannot start: {error}"
    try:
        out, _ = child.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            child.communicate(timeout=2)
        except subprocess.SubprocessError:
            pass
        return False, "", "timeout"
    if child.returncode != 0:
        return False, "", f"exit {child.returncode}"
    return True, out, ""


def fetch(options, state, root, marker, event, session, agent):
    """Run the command once. Returns the context text, or None (marker released on failure)."""
    started = time.time()
    ok, out, reason = run_command(options["command"], root, options["timeout"])
    elapsed = int((time.time() - started) * 1000)
    if not ok:
        release(marker)
        note_failure(state, root)
        log(state, event=event, session=session, agent=agent, root=root, outcome=f"failed: {reason}", ms=elapsed)
        sys.stderr.write(f"entry: no context for {root} ({reason})\n")
        return None
    clear_failures(state, root)
    text = out.strip()
    if not text:
        log(state, event=event, session=session, agent=agent, root=root, outcome="empty", ms=elapsed)
        return None
    if len(text) > CAP:
        text = text[:CAP].rstrip() + "\n[context cut at the hook size cap]"
    log(state, event=event, session=session, agent=agent, root=root, outcome="given", ms=elapsed)
    return text


def on_session_start(data, options, state):
    session = data.get("session_id")
    if not session:
        return
    # The earlier context is gone, whatever the start directory: clear first.
    if data.get("source") in ("resume", "compact", "clear"):
        import shutil

        shutil.rmtree(os.path.join(state, safe(session)), ignore_errors=True)
    root = git_root(data.get("cwd") or os.getcwd())
    if not root:
        return
    marker = marker_path(state, session, "main", root)
    if not is_consumer(root, options["needles"]):
        claim(state, marker)
        log(state, event="session-start", session=session, agent="main", root=root, outcome="not a consumer")
        return
    if backing_off(state, root) or not claim(state, marker):
        return
    if any(os.path.exists(os.path.join(root, own)) for own in options["own_hooks"]):
        log(state, event="session-start", session=session, agent="main", root=root, outcome="own hook")
        return
    text = fetch(options, state, root, marker, "session-start", session, "main")
    if text:
        sys.stdout.write(text + "\n")


def on_tool_call(data, options, state):
    session = data.get("session_id")
    if not session:
        return
    directory = touched_dir(data)
    root = git_root(directory) if directory else None
    if not root:
        return
    agent = data.get("agent_id") or "main"
    marker = marker_path(state, session, agent, root)
    if os.path.exists(marker):
        return
    if not is_consumer(root, options["needles"]):
        claim(state, marker)
        log(state, event="tool", session=session, agent=agent, root=root, outcome="not a consumer")
        return
    if backing_off(state, root) or not claim(state, marker):
        return
    text = fetch(options, state, root, marker, "tool", session, agent)
    if text:
        import json

        label = options["label"].replace("{root}", root)
        sys.stdout.write(
            json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": f"{label}\n{text}"}})
            + "\n"
        )


def main(argv, stdin):
    options = parse_args(argv)
    data = read_event(stdin)
    if data is None:
        return
    state = state_dir(options["name"])
    if options["session_start"]:
        on_session_start(data, options, state)
    else:
        on_tool_call(data, options, state)


if __name__ == "__main__":
    try:
        main(sys.argv[1:], sys.stdin)
    except Exception as error:  # a hook must never block a tool call
        sys.stderr.write(f"entry: {error}\n")
    sys.exit(0)
