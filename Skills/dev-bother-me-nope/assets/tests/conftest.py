"""Shared fixtures for the helper-script tests (merged-branch-cleanup.py, repo-merge-policy.py).

Every test builds throwaway repos under pytest's tmp_path: a bare `origin.git`, a clone with
`trunk` as its default branch, and linked worktrees. A `git` shim on PATH logs every argv before
running the real git, and a fake `gh` on PATH answers from a JSON fixture. No test touches this
repo, the network or the real GitHub API.
"""
import ast
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parents[1] / "bin"
CLEANUP = BIN / "merged-branch-cleanup.py"
POLICY = BIN / "repo-merge-policy.py"
FORBIDDEN_SUBCOMMANDS = frozenset({"checkout", "switch", "reset", "stash", "merge", "rebase", "pull"})
REFUSAL_SUBCOMMANDS = frozenset({"rev-parse", "check-ref-format", "symbolic-ref", "remote",
                                 "ls-remote"})
GIT_ENV_LEAKS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX")
GIT_CONFIG = """[user]
\tname = Test User
\temail = test@example.com
[init]
\tdefaultBranch = trunk
[commit]
\tgpgsign = false
[tag]
\tgpgsign = false
[advice]
\tdetachedHead = false
"""

GIT_SHIM = """#!{python}
import json, os, sys
log = os.environ.get("GIT_SHIM_LOG")
if log:
    with open(log, "a") as handle:
        handle.write(json.dumps(sys.argv[1:]) + "\\n")
real = os.environ["REAL_GIT"]
os.execv(real, [real] + sys.argv[1:])
"""

FAKE_GH = """#!{python}
import json, os, sys

argv = sys.argv[1:]
fixture = json.load(open(os.environ["FAKE_GH_FIXTURE"]))
state_path = os.environ["FAKE_GH_STATE"]
with open(os.environ["FAKE_GH_LOG"], "a") as handle:
    handle.write(json.dumps({{"argv": argv, "cwd": os.getcwd()}}) + "\\n")


def fail(code, message):
    sys.stderr.write(message + "\\n")
    sys.exit(code)


def load_state():
    if os.path.exists(state_path):
        return json.load(open(state_path))
    return fixture["repo"]


def apply_patch(fields):
    state = dict(load_state())
    for pair in fields:
        key, _, value = pair.partition("=")
        if value not in ("true", "false"):
            fail(98, "fake gh: untyped or non-boolean field " + pair)
        state[key] = value == "true"
    json.dump(state, open(state_path, "w"))


if argv[:2] == ["auth", "status"]:
    if fixture["auth_ok"]:
        print("Logged in as fake (token: ghp_FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE)")
        sys.exit(0)
    fail(1, "You are not logged in. token ghp_FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE")
if argv == ["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]:
    view = fixture["repo_view"]
    sys.stdout.write(view["out"])
    sys.stderr.write(view["err"])
    sys.exit(view["code"])
if argv[:1] == ["api"]:
    method = "PATCH" if argv[1:2] == ["-X"] else "GET"
    rest = argv[2:] if method == "PATCH" else argv[1:]
    if method == "PATCH":
        if rest[0] != "PATCH":
            fail(99, "fake gh: expected -X PATCH")
        rest = rest[1:]
    if not rest or rest[0] != fixture["path"]:
        fail(99, "fake gh: unexpected api path " + repr(rest[:1]))
    if method == "GET":
        get = fixture["get"]
        if get["code"] != 0:
            fail(get["code"], get["err"])
        raw = get["raw"]
        print(raw if raw is not None else json.dumps(load_state()))
        sys.exit(0)
    patch = fixture["patch"]
    if patch["code"] != 0:
        fail(patch["code"], patch["err"])
    flags, fields = rest[1::2], rest[2::2]
    if any(flag != "-F" for flag in flags):
        fail(98, "fake gh: boolean fields must be sent with -F")
    if patch["applies"]:
        apply_patch(fields)
    print(json.dumps(load_state()))
    sys.exit(0)
fail(99, "fake gh: unexpected call " + json.dumps(argv))
"""

DEFAULT_REPO = {
    "allow_squash_merge": True,
    "delete_branch_on_merge": False,
    "allow_merge_commit": True,
    "allow_rebase_merge": True,
    "permissions": {"admin": True},
}
DEFAULT_GH = {
    "auth_ok": True,
    "path": "repos/OWNER/NAME",
    "repo_view": {"code": 0, "out": "OWNER/NAME\n", "err": ""},
    "repo": DEFAULT_REPO,
    "get": {"code": 0, "raw": None, "err": ""},
    "patch": {"code": 0, "err": "", "applies": True},
}


def pytest_configure(config):
    config.addinivalue_line("markers", "unit: fast test of a pure function or a static property")
    config.addinivalue_line("markers", "integration: drives a script against real throwaway repos")


@pytest.fixture
def load_script():
    """Import a hyphen-named script from assets/bin as a module."""

    def load(name):
        path = BIN / f"{name}.py"
        spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module

    return load


@pytest.fixture
def subprocess_violations():
    """Return a function listing unsafe process spawns found in a script's source."""

    def find(path):
        problems = []
        for node in ast.walk(ast.parse(Path(path).read_text())):
            if isinstance(node, ast.Call):
                problems.extend(_spawn_problems(node))
        return problems

    return find


def _spawn_problems(call):
    name = ast.unparse(call.func)
    if name in {"os.system", "os.popen"}:
        return [f"{name} at line {call.lineno}"]
    if name != "subprocess.run":
        return []
    problems = []
    if not call.args or not isinstance(call.args[0], (ast.List, ast.Tuple)):
        problems.append(f"subprocess.run without a literal argv list at line {call.lineno}")
    for keyword in call.keywords:
        truthy = not (isinstance(keyword.value, ast.Constant) and not keyword.value.value)
        if keyword.arg == "shell" and truthy:
            problems.append(f"subprocess.run(shell=...) at line {call.lineno}")
    return problems


@pytest.fixture
def isolated_git_env(tmp_path, monkeypatch):
    """Env snapshot with no user, system or hook-inherited git configuration."""
    home = tmp_path / "home"
    home.mkdir()
    config = tmp_path / "gitconfig"
    config.write_text(GIT_CONFIG)
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", str(config))
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    monkeypatch.setenv("GIT_TERMINAL_PROMPT", "0")
    for name in GIT_ENV_LEAKS:
        monkeypatch.delenv(name, raising=False)
    return dict(os.environ)


@dataclass(frozen=True)
class GitWorld:
    """A bare origin, a clone whose default branch is `trunk`, and helpers to bend them."""

    root: Path
    origin: Path
    clone: Path
    env: dict

    def git(self, *args, cwd=None, check=True):
        target = str(cwd if cwd is not None else self.clone)
        return subprocess.run(
            ["git", "-C", target, *args], env=self.env, capture_output=True, text=True, check=check
        )

    def out(self, *args, cwd=None):
        return self.git(*args, cwd=cwd).stdout.strip()

    def commit(self, filename, content, cwd=None, message="change"):
        base = Path(cwd if cwd is not None else self.clone)
        (base / filename).parent.mkdir(parents=True, exist_ok=True)
        (base / filename).write_text(content)
        self.git("add", filename, cwd=cwd)
        self.git("commit", "-q", "-m", message, cwd=cwd)
        return self.out("rev-parse", "HEAD", cwd=cwd)

    def add_branch(self, name, merged=True, base="feat/r"):
        """Create `name` off `base` with one commit and push it; optionally merge --no-ff."""
        slug = name.replace("/", "-")
        self.git("checkout", "-q", "-b", name, base)
        self.commit(f"{slug}.txt", f"{name}\n", message=f"work on {name}")
        self.git("push", "-q", "origin", name)
        if merged:
            self.merge_no_ff(name, base)
        self.git("checkout", "-q", "trunk")
        return self.out("rev-parse", name)

    def merge_no_ff(self, source, into):
        self.git("checkout", "-q", into)
        self.git("merge", "-q", "--no-ff", "-m", f"Merge {source} into {into}", source)
        self.git("push", "-q", "origin", into)
        self.git("checkout", "-q", "trunk")

    def worktree(self, name, branch):
        path = self.root / f"wt-{name}"
        self.git("worktree", "add", "-q", "--force", str(path), branch)
        return path.resolve()

    def refs(self, repo):
        return self.out("for-each-ref", "--format=%(refname) %(objectname)", cwd=repo)

    def worktrees(self):
        return self.out("worktree", "list", "--porcelain")

    def sha(self, ref, cwd=None):
        return self.out("rev-parse", ref, cwd=cwd)


@pytest.fixture
def git_world(tmp_path, isolated_git_env):
    root = (tmp_path / "world").resolve()
    root.mkdir()
    world = GitWorld(root, root / "origin.git", root / "clone", isolated_git_env)
    subprocess.run(
        ["git", "init", "-q", "--bare", str(world.origin)], env=world.env, check=True
    )
    subprocess.run(
        ["git", "clone", "-q", str(world.origin), str(world.clone)],
        env=world.env, check=True, capture_output=True,
    )
    world.commit("README.md", "demo\n", message="init")
    world.git("push", "-q", "origin", "trunk")
    world.git("remote", "set-head", "origin", "--auto")
    world.git("branch", "feat/r")
    world.git("push", "-q", "origin", "feat/r")
    return world


@dataclass(frozen=True)
class GitShim:
    directory: Path
    log: Path
    real_git: str

    def reset(self):
        self.log.write_text("")

    def calls(self):
        lines = self.log.read_text().splitlines()
        return tuple(tuple(json.loads(line)) for line in lines)


@pytest.fixture
def git_shim(tmp_path):
    directory = tmp_path / "shim"
    directory.mkdir()
    shim = directory / "git"
    shim.write_text(GIT_SHIM.format(python=sys.executable))
    shim.chmod(0o755)
    return GitShim(directory, tmp_path / "git-calls.log", shutil.which("git"))


@dataclass(frozen=True)
class ScriptRun:
    code: int
    stdout: str
    stderr: str
    calls: tuple

    @property
    def data(self):
        return json.loads(self.stdout)

    @property
    def subcommands(self):
        return [call[2] for call in self.calls if len(call) > 2]


def assert_calls_are_safe(calls):
    for call in calls:
        assert call[0] == "-C" and len(call) >= 3, f"git call without -C <path>: {call}"
        assert call[2] not in FORBIDDEN_SUBCOMMANDS, f"forbidden git call: {call}"


@pytest.fixture
def run_cleanup(git_shim, isolated_git_env, tmp_path):
    """Run merged-branch-cleanup.py through the logging git shim and audit every git call."""

    def run(*args, cwd=None):
        git_shim.reset()
        path = f"{git_shim.directory}{os.pathsep}{isolated_git_env['PATH']}"
        env = {**isolated_git_env, "PATH": path, "GIT_SHIM_LOG": str(git_shim.log),
               "REAL_GIT": git_shim.real_git}
        proc = subprocess.run(
            [sys.executable, str(CLEANUP), *args],
            env=env, capture_output=True, text=True, cwd=str(cwd or tmp_path), check=False,
        )
        calls = git_shim.calls()
        assert_calls_are_safe(calls)
        return ScriptRun(proc.returncode, proc.stdout, proc.stderr, calls)

    return run


@pytest.fixture
def assert_refused():
    """Assert a run was a refusal: exit 2, a JSON error, only read-only git, nothing changed."""

    def check(run):
        assert run.code == 2, f"exit {run.code}: {run.stdout} {run.stderr}"
        body = json.loads(run.stdout)
        assert set(body) == {"error"}
        assert isinstance(body["error"], str) and body["error"]
        assert set(run.subcommands) <= REFUSAL_SUBCOMMANDS, run.calls

    return check


@dataclass(frozen=True)
class FakeGh:
    """A fake `gh` first (and only) on PATH, driven by a JSON fixture and logging every call."""

    directory: Path
    fixture: Path
    state: Path
    log: Path

    @property
    def default_repo(self):
        return json.loads(json.dumps(DEFAULT_REPO))

    def configure(self, repo=None, **overrides):
        merged = json.loads(json.dumps(DEFAULT_GH))
        merged["repo"] = {**merged["repo"], **(repo or {})}
        merged.update(overrides)
        self.fixture.write_text(json.dumps(merged))
        self.state.unlink(missing_ok=True)
        self.log.write_text("")

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def patch_calls(self):
        return [call for call in self.calls() if call["argv"][:3] == ["api", "-X", "PATCH"]]

    def api_calls(self):
        return [call["argv"][0] + (" PATCH" if "PATCH" in call["argv"] else " GET")
                for call in self.calls() if call["argv"][0] == "api"]

    def run(self, *args, cwd=None, gh_on_path=True):
        path = str(self.directory) if gh_on_path else str(self.directory.parent / "empty-bin")
        found = shutil.which("gh", path=path)
        assert (found == str(self.directory / "gh")) == gh_on_path, "wrong gh first on PATH"
        env = {"PATH": path, "FAKE_GH_FIXTURE": str(self.fixture),
               "FAKE_GH_STATE": str(self.state), "FAKE_GH_LOG": str(self.log)}
        proc = subprocess.run(
            [sys.executable, str(POLICY), *args],
            env=env, capture_output=True, text=True, cwd=str(cwd) if cwd else None, check=False,
        )
        return ScriptRun(proc.returncode, proc.stdout, proc.stderr, ())


@pytest.fixture
def fake_gh(tmp_path):
    directory = tmp_path / "fake-bin"
    directory.mkdir()
    (tmp_path / "empty-bin").mkdir()
    script = directory / "gh"
    script.write_text(FAKE_GH.format(python=sys.executable))
    script.chmod(0o755)
    fake = FakeGh(directory, tmp_path / "gh-fixture.json", tmp_path / "gh-state.json",
                  tmp_path / "gh-calls.log")
    fake.configure()
    return fake
