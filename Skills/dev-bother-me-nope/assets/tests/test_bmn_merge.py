"""bmn-merge.py and bmn-cores.py: the deterministic merge step and the processor count.

Every test builds throwaway repos under tmp_path: a bare origin, a `run` clone standing in for
the run worktree (sprint branch checked out) and a `dev` clone that pushes story branches. No
test touches this repo or the network.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parents[1] / "bin"
MERGE = BIN / "bmn-merge.py"
CORES = BIN / "bmn-cores.py"
SPRINT = "sprint/demo"


def git(path, *args):
    done = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True, check=False)
    assert done.returncode == 0, done.stderr
    return done.stdout.strip()


def commit(path, name, content, message):
    target = Path(path) / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    git(path, "add", "-A")
    git(path, "commit", "-m", message)


@pytest.fixture
def world(tmp_path, monkeypatch):
    home = tmp_path / "home"
    home.mkdir()
    (home / ".gitconfig").write_text(
        "[user]\n\tname = Test User\n\temail = test@example.com\n[init]\n\tdefaultBranch = trunk\n"
        "[commit]\n\tgpgsign = false\n[core]\n\tautocrlf = false\n")
    for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("USERPROFILE", str(home))
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", str(home / ".gitconfig"))
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    origin = tmp_path / "origin.git"
    subprocess.run(["git", "init", "--bare", "-b", "trunk", str(origin)], check=True, capture_output=True)
    seed = tmp_path / "seed"
    subprocess.run(["git", "clone", str(origin), str(seed)], check=True, capture_output=True)
    commit(seed, "README.md", "seed\n", "chore: seed")
    git(seed, "push", "origin", "HEAD:trunk", "HEAD:dev", f"HEAD:{SPRINT}")
    run = tmp_path / "run"
    subprocess.run(["git", "clone", str(origin), str(run)], check=True, capture_output=True)
    git(run, "switch", "-c", SPRINT, f"origin/{SPRINT}")
    return {"origin": origin, "seed": seed, "run": run, "tmp": tmp_path}


def story(world, branch, name, content="x\n"):
    """Push a story branch cut from the sprint branch with one new file."""
    seed = world["seed"]
    git(seed, "fetch", "origin")
    git(seed, "switch", "-C", "work", f"origin/{SPRINT}")
    commit(seed, name, content, f"feat: {name}")
    git(seed, "push", "origin", f"HEAD:refs/heads/{branch}")


def merge(world, *args):
    done = subprocess.run(
        [sys.executable, str(MERGE), "--worktree", str(world["run"]), "--integration", SPRINT, *args],
        capture_output=True, text=True, check=False)
    return done.returncode, json.loads(done.stdout)


def origin_has(world, ref):
    done = subprocess.run(["git", "-C", str(world["origin"]), "rev-parse", "--verify", "--quiet", ref],
                          capture_output=True, check=False)
    return done.returncode == 0


@pytest.mark.unit
def test_merges_branches_in_order_as_merge_commits_and_pushes(world):
    story(world, "wip/demo/a", "a.txt")
    story(world, "wip/demo/b", "b.txt")

    code, out = merge(world, "--branch", "wip/demo/a", "--branch", "wip/demo/b", "--no-cleanup")

    assert code == 0 and out["needs_agent"] is None and out["pushed"] is True
    assert [item["branch"] for item in out["merged"]] == ["wip/demo/a", "wip/demo/b"]
    assert git(world["run"], "rev-parse", "HEAD") == git(world["origin"], "rev-parse", SPRINT)
    parents = git(world["run"], "rev-list", "--parents", "-n", "1", "HEAD").split()
    assert len(parents) == 3, "a branch merge must be a merge commit, never a fast-forward"
    assert out["dev_merge"] == "skipped"


@pytest.mark.unit
def test_red_gate_reverts_the_newest_merge_and_keeps_the_rest(world):
    story(world, "wip/demo/good", "good.txt")
    story(world, "wip/demo/bad", "bad.txt")

    code, out = merge(world, "--branch", "wip/demo/good", "--branch", "wip/demo/bad",
                      "--gate", "test ! -f bad.txt", "--no-cleanup")

    assert code == 0
    assert [item["branch"] for item in out["merged"]] == ["wip/demo/good"]
    assert [item["branch"] for item in out["reverted"]] == ["wip/demo/bad"]
    assert out["gates"] == [{"gate": "test ! -f bad.txt", "ok": True}]
    assert (world["run"] / "good.txt").exists() and not (world["run"] / "bad.txt").exists()
    assert out["pushed"] is True


@pytest.mark.unit
def test_gate_red_with_nothing_left_to_revert_stops_without_pushing(world):
    story(world, "wip/demo/a", "a.txt")
    before = git(world["origin"], "rev-parse", SPRINT)

    code, out = merge(world, "--branch", "wip/demo/a", "--gate", "false", "--no-cleanup")

    assert code == 3 and out["pushed"] is False
    assert out["needs_agent"]["why"] == "gates are red with every branch merge reverted"
    assert git(world["origin"], "rev-parse", SPRINT) == before


@pytest.mark.unit
def test_conflict_is_aborted_and_handed_to_an_agent_with_the_remaining_branches(world):
    story(world, "wip/demo/one", "same.txt", "one\n")
    story(world, "wip/demo/two", "same.txt", "two\n")
    story(world, "wip/demo/three", "three.txt")
    before = git(world["origin"], "rev-parse", SPRINT)

    code, out = merge(world, "--branch", "wip/demo/one", "--branch", "wip/demo/two",
                      "--branch", "wip/demo/three", "--no-cleanup")

    assert code == 3 and out["pushed"] is False
    assert out["needs_agent"]["why"] == "merge conflict"
    assert out["needs_agent"]["branch"] == "wip/demo/two"
    assert out["needs_agent"]["remaining"] == ["wip/demo/two", "wip/demo/three"]
    assert [item["branch"] for item in out["merged"]] == ["wip/demo/one"]
    assert git(world["run"], "status", "--porcelain", "--untracked-files=no") == ""
    assert git(world["origin"], "rev-parse", SPRINT) == before


@pytest.mark.unit
def test_added_secret_file_stops_before_any_push(world):
    story(world, "wip/demo/leak", ".env", "KEY=1\n")
    before = git(world["origin"], "rev-parse", SPRINT)

    code, out = merge(world, "--branch", "wip/demo/leak", "--no-cleanup")

    assert code == 3 and out["pushed"] is False
    assert ".env" in out["needs_agent"]["output"]
    assert git(world["origin"], "rev-parse", SPRINT) == before


@pytest.mark.unit
def test_env_example_is_not_a_secret(world):
    story(world, "wip/demo/example", ".env.example", "KEY=\n")

    code, out = merge(world, "--branch", "wip/demo/example", "--no-cleanup")

    assert code == 0 and out["pushed"] is True


@pytest.mark.unit
def test_to_dev_merges_dev_in_then_the_sprint_branch_into_dev_without_checking_dev_out(world):
    story(world, "wip/demo/a", "a.txt")
    seed = world["seed"]
    git(seed, "switch", "-C", "devwork", "origin/dev")
    commit(seed, "other.txt", "other session\n", "feat: other session")
    git(seed, "push", "origin", "HEAD:dev")
    dev_worktree = world["tmp"] / "run-dev"

    code, out = merge(world, "--branch", "wip/demo/a", "--to-dev", "--dev-worktree", str(dev_worktree),
                      "--dev-title", "feat: demo sprint", "--no-cleanup")

    assert code == 0, out
    dev_tip = git(world["origin"], "rev-parse", "dev")
    assert out["dev_merge"] == dev_tip
    assert git(world["origin"], "log", "-1", "--format=%s", "dev") == "feat: demo sprint"
    assert len(git(world["origin"], "rev-list", "--parents", "-n", "1", "dev").split()) == 3
    files = git(world["origin"], "ls-tree", "--name-only", "dev").split()
    assert {"a.txt", "other.txt"} <= set(files)
    assert not dev_worktree.exists()
    assert git(world["run"], "branch", "--show-current") == SPRINT
    assert git(world["origin"], "rev-parse", "trunk") != dev_tip, "main is never touched"


@pytest.mark.unit
def test_cleanup_deletes_the_merged_story_branch_on_origin(world):
    story(world, "wip/demo/a", "a.txt")
    git(world["run"], "remote", "set-head", "origin", "trunk")

    code, out = merge(world, "--branch", "wip/demo/a")

    assert code == 0, out
    assert "origin:wip/demo/a" in out["deleted"]
    assert not origin_has(world, "refs/heads/wip/demo/a")
    assert origin_has(world, f"refs/heads/{SPRINT}")


@pytest.mark.unit
@pytest.mark.parametrize("setup, extra, message", [
    ("wrong_branch", ["--branch", "wip/demo/a"], "checked out"),
    ("dirty", ["--branch", "wip/demo/a"], "uncommitted"),
    ("clean", [], "nothing to merge"),
    ("clean", ["--to-dev"], "--dev-worktree"),
])
def test_refuses_and_changes_nothing(world, setup, extra, message):
    if setup == "wrong_branch":
        git(world["run"], "switch", "-c", "elsewhere")
    if setup == "dirty":
        (world["run"] / "README.md").write_text("edited by hand\n")
    before = git(world["origin"], "rev-parse", SPRINT)

    done = subprocess.run(
        [sys.executable, str(MERGE), "--worktree", str(world["run"]), "--integration", SPRINT, *extra],
        capture_output=True, text=True, check=False)

    assert done.returncode == 2
    assert message in json.loads(done.stdout)["error"]
    assert git(world["origin"], "rev-parse", SPRINT) == before


@pytest.mark.unit
def test_refuses_a_protected_integration_branch(world):
    done = subprocess.run(
        [sys.executable, str(MERGE), "--worktree", str(world["run"]), "--integration", "main",
         "--branch", "wip/demo/a"], capture_output=True, text=True, check=False)

    assert done.returncode == 2 and "protected" in json.loads(done.stdout)["error"]


@pytest.mark.unit
def test_source_never_squashes_forces_or_resets():
    source = MERGE.read_text(encoding="utf-8")
    code = source.split('"""', 2)[2]
    for banned in ('"--squash"', '"--force"', '"-f"', '"reset"', '"checkout"', '"stash"', '"switch"'):
        assert banned not in code, banned


# --- bmn-cores.py ----------------------------------------------------------------------


def cores(*args, env=None):
    environ = {key: value for key, value in os.environ.items()
               if key != "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS"}
    environ.update(env or {})
    done = subprocess.run([sys.executable, str(CORES), *args], capture_output=True, text=True,
                          check=False, env=environ)
    return done


@pytest.mark.unit
def test_cores_reports_this_machine_and_fills_it():
    out = json.loads(cores().stdout)

    assert out["logical"] >= 1 and out["solo_workers"] == out["logical"]
    assert out["shards"] * out["workers"] <= out["logical"]
    assert out["agent_cap"] == 20 and out["cap_source"] == "default"


@pytest.mark.unit
@pytest.mark.parametrize("logical, shards, workers", [(36, 6, 6), (8, 3, 2), (1, 1, 1), (64, 8, 8)])
def test_cores_split_fills_the_machine(logical, shards, workers):
    out = json.loads(cores("--cores", str(logical)).stdout)

    assert (out["shards"], out["workers"]) == (shards, workers)
    assert out["flags"]["vitest"] == f"--maxWorkers={workers} --shard=<i>/{shards}"


@pytest.mark.unit
def test_cores_reads_the_subagent_cap_and_never_shards_past_it():
    out = json.loads(cores("--cores", "64", env={"CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS": "4"}).stdout)

    assert out["agent_cap"] == 4 and out["cap_source"] == "env"
    assert out["shards"] == 4 and out["workers"] == 16


@pytest.mark.unit
def test_cores_never_exceeds_a_pinned_worker_count():
    out = json.loads(cores("--cores", "36", "--pinned", "2").stdout)

    assert out["workers"] == 2 and out["solo_workers"] == 2 and out["pinned"] == 2


@pytest.mark.unit
@pytest.mark.parametrize("flag", ["--cores", "--cap", "--pinned"])
def test_cores_refuses_a_flag_that_is_not_a_whole_number(flag):
    done = cores(flag, "0")

    assert done.returncode == 2 and done.stdout == "" and flag in done.stderr
