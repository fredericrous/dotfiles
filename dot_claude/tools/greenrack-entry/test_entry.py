"""Tests for entry.py. Standard library only: python3 -m unittest test_entry"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ENTRY = os.path.join(HERE, "entry.py")

FAKE = """
import os, sys, time
mode = sys.argv[1]
counter = os.environ.get("FAKE_COUNT")
if counter:
    with open(counter, "a") as handle:
        handle.write("x")
if mode == "ok":
    print("INDEX BODY")
elif mode == "fail":
    sys.exit(1)
elif mode == "hang":
    time.sleep(30)
elif mode == "slow":
    time.sleep(1)
    print("INDEX BODY")
elif mode == "big":
    print("x" * 12000)
"""

NEEDLE = "@scope/pkg-"


class EntryCase(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="entry-test-"))
        self.state = os.path.join(self.tmp, "state")
        self.fake = os.path.join(self.tmp, "fake.py")
        with open(self.fake, "w", encoding="utf-8") as handle:
            handle.write(FAKE)
        self.env = dict(os.environ)
        self.env.update(
            XDG_STATE_HOME=self.state,
            GIT_CONFIG_GLOBAL="/dev/null",
            GIT_CONFIG_SYSTEM="/dev/null",
        )
        self.env.pop("FAKE_COUNT", None)
        self.addCleanup(subprocess.run, ["rm", "-rf", self.tmp])

    def repo(self, name, package=None, extra=None):
        path = os.path.join(self.tmp, name)
        os.makedirs(path)
        subprocess.run(["git", "init", "-q", path], check=True, env=self.env)
        if package is not None:
            relative = package if isinstance(package, str) else "package.json"
            target = os.path.join(path, relative)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as handle:
                handle.write(json.dumps({"dependencies": {NEEDLE + "ui": "1.0.0"}}))
        for relative in extra or []:
            target = os.path.join(path, relative)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w").close()
        return path

    def argv(self, mode="ok", session_start=False, timeout=None, own_hooks=()):
        args = [sys.executable, "-I", ENTRY, "--name", "entry-test", "--needle", NEEDLE]
        args += ["--label", "index for {root} (first touch)"]
        if session_start:
            args.append("--session-start")
        if timeout is not None:
            args += ["--timeout", str(timeout)]
        for own in own_hooks:
            args += ["--own-hook", own]
        return args + ["--", sys.executable, "-I", self.fake, mode]

    def run_entry(self, payload, **kwargs):
        env = dict(self.env)
        env.update(kwargs.pop("env", {}))
        text = payload if isinstance(payload, str) else json.dumps(payload)
        return subprocess.run(self.argv(**kwargs), input=text, capture_output=True, text=True, env=env, timeout=60)

    def read(self, root, session="s1", **extra):
        payload = {
            "session_id": session,
            "cwd": root,
            "hook_event_name": "PreToolUse",
            "tool_name": "Read",
            "tool_input": {"file_path": os.path.join(root, "src", "a.ts")},
        }
        payload.update(extra)
        return payload

    def start(self, root, session="s1", source="startup"):
        return {"session_id": session, "cwd": root, "hook_event_name": "SessionStart", "source": source}

    def context_of(self, done):
        return json.loads(done.stdout)["hookSpecificOutput"]["additionalContext"]

    def runs(self, counter):
        """How many times the fake command ran."""
        with open(counter, encoding="utf-8") as handle:
            return len(handle.read())


class SessionStartTests(EntryCase):
    def test_outside_a_repository_prints_nothing(self):
        plain = os.path.join(self.tmp, "plain")
        os.makedirs(plain)
        done = self.run_entry(self.start(plain), session_start=True)
        self.assertEqual((done.returncode, done.stdout, done.stderr), (0, "", ""))

    def test_in_a_consumer_prints_plain_text_once(self):
        root = self.repo("app", package=True)
        first = self.run_entry(self.start(root), session_start=True)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(first.stdout, "INDEX BODY\n")
        second = self.run_entry(self.start(root), session_start=True)
        self.assertEqual(second.stdout, "")

    def test_resume_compact_and_clear_print_again(self):
        root = self.repo("app", package=True)
        self.run_entry(self.start(root), session_start=True)
        for source in ("resume", "compact", "clear"):
            done = self.run_entry(self.start(root, source=source), session_start=True)
            self.assertEqual(done.stdout, "INDEX BODY\n", source)

    def test_a_session_started_outside_a_repo_gets_its_index_again_after_a_compact(self):
        plain = os.path.join(self.tmp, "plain")
        os.makedirs(plain)
        root = self.repo("app", package=True)
        self.assertIn("INDEX BODY", self.context_of(self.run_entry(self.read(root))))
        self.assertEqual(self.run_entry(self.read(root)).stdout, "")
        compact = self.run_entry(self.start(plain, source="compact"), session_start=True)
        self.assertEqual(compact.stdout, "")
        again = self.run_entry(self.read(root))
        self.assertIn("INDEX BODY", self.context_of(again))

    def test_a_session_started_in_the_repo_is_told_once_after_a_compact(self):
        root = self.repo("app", package=True)
        self.run_entry(self.start(root), session_start=True)
        compact = self.run_entry(self.start(root, source="compact"), session_start=True)
        self.assertEqual(compact.stdout, "INDEX BODY\n")
        self.assertEqual(self.run_entry(self.read(root)).stdout, "")

    def test_a_repo_with_its_own_hook_stays_silent_and_is_marked(self):
        root = self.repo("app", package=True, extra=[".claude/hooks/own-catalog.sh"])
        done = self.run_entry(self.start(root), session_start=True, own_hooks=[".claude/hooks/own-catalog.sh"])
        self.assertEqual(done.stdout, "")
        later = self.run_entry(self.read(root))
        self.assertEqual(later.stdout, "")

    def test_a_subfolder_start_resolves_the_git_root(self):
        root = self.repo("app", package=True)
        sub = os.path.join(root, "packages", "x")
        os.makedirs(sub)
        done = self.run_entry(self.start(sub), session_start=True)
        self.assertEqual(done.stdout, "INDEX BODY\n")


class ToolCallTests(EntryCase):
    def test_first_read_in_a_consumer_returns_one_json_object_once(self):
        root = self.repo("app", package=True)
        first = self.run_entry(self.read(root))
        self.assertEqual(first.returncode, 0)
        output = json.loads(first.stdout)
        self.assertEqual(output["hookSpecificOutput"]["hookEventName"], "PreToolUse")
        self.assertEqual(
            output["hookSpecificOutput"]["additionalContext"],
            f"index for {root} (first touch)\nINDEX BODY",
        )
        second = self.run_entry(self.read(root))
        self.assertEqual((second.returncode, second.stdout), (0, ""))

    def test_a_session_started_in_the_repo_is_not_told_twice(self):
        root = self.repo("app", package=True)
        self.run_entry(self.start(root), session_start=True)
        done = self.run_entry(self.read(root))
        self.assertEqual(done.stdout, "")

    def test_a_subagent_gets_its_own_index(self):
        root = self.repo("app", package=True)
        self.run_entry(self.read(root))
        sub = self.run_entry(self.read(root, agent_id="a1", agent_type="general-purpose"))
        self.assertIn("INDEX BODY", self.context_of(sub))
        again = self.run_entry(self.read(root, agent_id="a1"))
        self.assertEqual(again.stdout, "")

    def test_another_session_is_told_again(self):
        root = self.repo("app", package=True)
        self.run_entry(self.read(root, session="s1"))
        other = self.run_entry(self.read(root, session="s2"))
        self.assertIn("INDEX BODY", self.context_of(other))

    def test_bash_uses_the_cwd(self):
        root = self.repo("app", package=True)
        payload = {"session_id": "s1", "cwd": root, "tool_name": "Bash", "tool_input": {"command": "ls"}}
        done = self.run_entry(payload)
        self.assertIn("INDEX BODY", self.context_of(done))

    def test_a_cwd_outside_any_repository_prints_nothing(self):
        plain = os.path.join(self.tmp, "plain")
        os.makedirs(plain)
        payload = {"session_id": "s1", "cwd": plain, "tool_name": "Bash", "tool_input": {"command": "ls"}}
        done = self.run_entry(payload)
        self.assertEqual((done.returncode, done.stdout, done.stderr), (0, "", ""))

    def test_a_file_in_another_repository_follows_the_file_not_the_cwd(self):
        plain = os.path.join(self.tmp, "plain")
        os.makedirs(plain)
        root = self.repo("app", package=True)
        payload = self.read(root)
        payload["cwd"] = plain
        done = self.run_entry(payload)
        self.assertIn(f"index for {root}", self.context_of(done))

    def test_a_write_into_a_folder_that_does_not_exist_yet(self):
        root = self.repo("app", package=True)
        target = os.path.join(root, "new", "deeper", "file.ts")
        done = self.run_entry(self.read(root, tool_name="Write", tool_input={"file_path": target}))
        self.assertIn("INDEX BODY", self.context_of(done))

    def test_a_notebook_path(self):
        root = self.repo("app", package=True)
        target = os.path.join(root, "notes", "a.ipynb")
        done = self.run_entry(self.read(root, tool_name="NotebookEdit", tool_input={"notebook_path": target}))
        self.assertIn("INDEX BODY", self.context_of(done))

    def test_a_relative_path_resolves_against_the_cwd(self):
        root = self.repo("app", package=True)
        done = self.run_entry(self.read(root, tool_input={"file_path": "src/a.ts"}))
        self.assertIn("INDEX BODY", self.context_of(done))

    def test_a_worktree_marks_its_root_with_a_dot_git_file(self):
        root = os.path.join(self.tmp, "wt")
        os.makedirs(root)
        with open(os.path.join(root, ".git"), "w", encoding="utf-8") as handle:
            handle.write("gitdir: /nowhere/.git/worktrees/wt\n")
        with open(os.path.join(root, "package.json"), "w", encoding="utf-8") as handle:
            handle.write(json.dumps({"dependencies": {NEEDLE + "ui": "1.0.0"}}))
        done = self.run_entry(self.read(root))
        self.assertIn(f"index for {root}", self.context_of(done))

    def test_a_symlinked_path_names_the_same_root(self):
        root = self.repo("app", package=True)
        link = os.path.join(self.tmp, "link")
        os.symlink(root, link)
        self.run_entry(self.read(root))
        again = self.run_entry(self.read(link, tool_input={"file_path": os.path.join(link, "src", "a.ts")}))
        self.assertEqual(again.stdout, "")

    def test_a_repository_that_is_not_a_consumer_prints_nothing_quietly(self):
        root = self.repo("other")
        done = self.run_entry(self.read(root))
        self.assertEqual((done.returncode, done.stdout, done.stderr), (0, "", ""))

    def test_the_consumer_test_looks_three_levels_down_and_skips_node_modules(self):
        deep = self.repo("deep", package="packages/ui/package.json")
        self.assertIn("INDEX BODY", self.context_of(self.run_entry(self.read(deep))))
        hidden = self.repo("hidden", package="node_modules/x/package.json")
        self.assertEqual(self.run_entry(self.read(hidden)).stdout, "")
        too_deep = self.repo("toodeep", package="a/b/c/d/package.json")
        self.assertEqual(self.run_entry(self.read(too_deep)).stdout, "")

    def test_a_command_with_no_output_keeps_the_marker(self):
        root = self.repo("app", package=True)
        count = os.path.join(self.tmp, "count")
        env = {"FAKE_COUNT": count}
        self.run_entry(self.read(root), mode="empty", env=env)
        self.run_entry(self.read(root), mode="empty", env=env)
        self.assertEqual(self.runs(count), 1)

    def test_context_over_the_cap_is_cut(self):
        root = self.repo("app", package=True)
        done = self.run_entry(self.read(root), mode="big")
        self.assertLess(len(self.context_of(done)), 9700)


class FailureTests(EntryCase):
    def test_a_failing_command_exits_zero_and_the_next_call_retries(self):
        root = self.repo("app", package=True)
        failed = self.run_entry(self.read(root), mode="fail")
        self.assertEqual((failed.returncode, failed.stdout), (0, ""))
        self.assertEqual(len(failed.stderr.strip().splitlines()), 1)
        retried = self.run_entry(self.read(root), mode="ok")
        self.assertIn("INDEX BODY", self.context_of(retried))

    def test_a_hanging_command_is_killed_at_the_timeout(self):
        root = self.repo("app", package=True)
        started = time.time()
        done = self.run_entry(self.read(root), mode="hang", timeout=1)
        self.assertLess(time.time() - started, 8)
        self.assertEqual((done.returncode, done.stdout), (0, ""))
        retried = self.run_entry(self.read(root), mode="ok")
        self.assertIn("INDEX BODY", self.context_of(retried))

    def test_three_failures_back_off_instead_of_running_again(self):
        root = self.repo("app", package=True)
        count = os.path.join(self.tmp, "count")
        env = {"FAKE_COUNT": count}
        for _ in range(5):
            self.run_entry(self.read(root), mode="fail", env=env)
        self.assertEqual(self.runs(count), 3)

    def test_garbage_input_exits_zero_quietly(self):
        done = self.run_entry("not json at all")
        self.assertEqual((done.returncode, done.stdout), (0, ""))
        done = self.run_entry("[1, 2]")
        self.assertEqual((done.returncode, done.stdout), (0, ""))

    def test_a_missing_command_exits_zero(self):
        done = subprocess.run(
            [sys.executable, "-I", ENTRY, "--name", "entry-test"],
            input="{}",
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertEqual((done.returncode, done.stdout), (0, ""))
        self.assertIn("entry:", done.stderr)


class ConcurrencyTests(EntryCase):
    def test_parallel_calls_print_the_index_once(self):
        root = self.repo("app", package=True)
        payload = json.dumps(self.read(root))
        runs = [
            subprocess.Popen(
                self.argv(mode="slow"),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=self.env,
            )
            for _ in range(4)
        ]
        outputs = [run.communicate(payload, timeout=60)[0] for run in runs]
        self.assertEqual(len([out for out in outputs if out.strip()]), 1)


class TimingTests(EntryCase):
    @unittest.skipUnless(os.environ.get("ENTRY_TIMING"), "set ENTRY_TIMING=1 to measure")
    def test_calls_after_the_first_take_under_60_ms_of_cpu_at_p95(self):
        # CPU time of the child (and its git), not the wall clock: a busy
        # machine stretches the wall clock but not the work a call does.
        import resource

        root = self.repo("app", package=True)
        self.run_entry(self.read(root))
        samples = []
        for _ in range(100):
            before = resource.getrusage(resource.RUSAGE_CHILDREN)
            self.run_entry(self.read(root))
            after = resource.getrusage(resource.RUSAGE_CHILDREN)
            samples.append((after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime))
        samples.sort()
        p95 = samples[94]
        baseline = []
        for _ in range(20):
            before = resource.getrusage(resource.RUSAGE_CHILDREN)
            subprocess.run([sys.executable, "-I", "-c", "pass"], check=True)
            after = resource.getrusage(resource.RUSAGE_CHILDREN)
            baseline.append((after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime))
        baseline.sort()
        print(
            f"p95 {p95 * 1000:.1f} ms of cpu per call; an empty python start p95 {baseline[18] * 1000:.1f} ms",
            file=sys.stderr,
        )
        self.assertLess(p95, 0.060)


if __name__ == "__main__":
    unittest.main()
