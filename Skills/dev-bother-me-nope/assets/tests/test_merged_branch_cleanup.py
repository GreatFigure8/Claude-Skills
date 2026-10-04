"""merged-branch-cleanup.py: deletes one merged branch, every worktree holding it, local and remote.

Run: uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
Fixtures (real throwaway repos, git shim, fake gh) live in conftest.py.
"""
import shutil
from pathlib import Path

import pytest

BRANCH = "wip/r/a"
TARGET = "origin/feat/r"
UNSAFE = frozenset({"--force", "-f", "-ff"})
MUTATING = frozenset({"fetch", "push", "update-ref", "config", "worktree"})


def cli(world, *extra, branch=BRANCH, target=TARGET):
    return ("--repo", str(world.clone), f"--branch={branch}", f"--target={target}", *extra)


def left_map(data):
    return {entry["ref"]: entry["why"] for entry in data["left"]}


def snapshot(world):
    return (world.refs(world.clone), world.refs(world.origin), world.worktrees())


def move_origin_ahead(world, branch):
    """Push one extra commit to origin/<branch>, then rewind the local branch to its old tip."""
    tip = world.sha(branch)
    world.git("checkout", "-q", branch)
    extra = world.commit("extra.txt", "ahead\n", message="origin only")
    world.git("push", "-q", "origin", branch)
    world.git("checkout", "-q", "trunk")
    world.git("branch", "-f", branch, tip)
    return extra


# --- AC 1-10: behaviour against real repos -------------------------------------------------


@pytest.mark.integration
def test_merged_branch_in_two_worktrees_removes_both_and_deletes_local_and_origin(
    git_world, run_cleanup
):
    git_world.add_branch(BRANCH)
    first, second = git_world.worktree("one", BRANCH), git_world.worktree("two", BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    data = run.data
    assert (data["branch"], data["target"], data["dry_run"]) == (BRANCH, TARGET, False)
    expected = [f"worktree:{first}", f"worktree:{second}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(data["deleted"]) == sorted(expected)
    assert data["left"] == []
    listing = git_world.worktrees()
    assert str(first) not in listing and str(second) not in listing
    assert not first.exists() and not second.exists()
    assert f"refs/heads/{BRANCH}" not in git_world.refs(git_world.clone)
    assert f"refs/heads/{BRANCH}" not in git_world.refs(git_world.origin)


@pytest.mark.integration
def test_deleting_local_branch_drops_its_config_section(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    git_world.git("branch", "--set-upstream-to", f"origin/{BRANCH}", BRANCH)
    assert git_world.git("config", "--get", f"branch.{BRANCH}.remote").returncode == 0

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    leftover = git_world.git("config", "--get-regexp", f"^branch\\.{BRANCH}\\.", check=False)
    assert leftover.returncode != 0 and leftover.stdout == ""


@pytest.mark.integration
def test_dirty_worktree_is_left_byte_identical_and_never_forced(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    dirty, clean = git_world.worktree("dirty", BRANCH), git_world.worktree("clean", BRANCH)
    tracked, untracked = dirty / "wip-r-a.txt", dirty / "scratch.txt"
    tracked.write_bytes(b"edited \x00 bytes\n")
    untracked.write_bytes(b"mine, not committed\n")
    before = (tracked.read_bytes(), untracked.read_bytes())

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{dirty}", f"local:{BRANCH}"}
    assert "uncommitted" in left[f"worktree:{dirty}"]
    assert str(dirty) in left[f"local:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{clean}", f"origin:{BRANCH}"])
    assert (tracked.read_bytes(), untracked.read_bytes()) == before
    assert dirty.exists() and not clean.exists()
    assert f"refs/heads/{BRANCH}" in git_world.refs(git_world.clone)
    assert "branch" not in run.subcommands
    for call in run.calls:
        if call[2] == "worktree":
            assert not UNSAFE & set(call), call


@pytest.mark.integration
def test_locked_worktree_is_left_locked_with_lock_reason(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    locked = git_world.worktree("lock", BRANCH)
    git_world.git("worktree", "lock", "--reason", "on usb stick", str(locked))

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{locked}", f"local:{BRANCH}"}
    assert "locked" in left[f"worktree:{locked}"] and "on usb stick" in left[f"worktree:{locked}"]
    assert str(locked) in left[f"local:{BRANCH}"]
    assert run.data["deleted"] == [f"origin:{BRANCH}"]
    assert "locked on usb stick" in git_world.worktrees()
    assert not any(call[2:4] == ("worktree", "unlock") for call in run.calls)


@pytest.mark.integration
def test_unmerged_branch_deletes_nothing(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    held = git_world.worktree("held", BRANCH)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == []
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert all(f"not merged into {TARGET}" in why for why in left.values())
    assert snapshot(git_world) == before
    assert not {"update-ref", "push"} & set(run.subcommands)


@pytest.mark.integration
def test_origin_ahead_of_target_keeps_origin_copy_only(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    extra = move_origin_ahead(git_world, BRANCH)
    held = git_world.worktree("a", BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{held}", f"local:{BRANCH}"])
    assert left_map(run.data) == {f"origin:{BRANCH}": f"origin has commits not in {TARGET}"}
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == extra


@pytest.mark.integration
def test_origin_copy_moved_after_check_is_not_deleted(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    other = git_world.root / "clone2"
    git_world.git("clone", "-q", str(git_world.origin), str(other), cwd=git_world.root)
    git_world.git("checkout", "-q", BRANCH, cwd=other)
    moved = git_world.commit("later.txt", "pushed by someone else\n", cwd=other)
    git_world.git("push", "-q", "origin", BRANCH, cwd=other)

    run = run_cleanup(*cli(git_world, "--no-fetch"))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == [f"local:{BRANCH}"]
    assert "stale info" in left_map(run.data)[f"origin:{BRANCH}"]
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == moved


@pytest.mark.integration
def test_main_checkout_is_never_removed_or_switched(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    git_world.git("checkout", "-q", BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == [f"origin:{BRANCH}"]
    left = left_map(run.data)
    assert "checked out in the main checkout" in left[f"local:{BRANCH}"]
    assert "main checkout" in left[f"worktree:{git_world.clone}"]
    assert git_world.out("branch", "--show-current") == BRANCH
    assert git_world.clone.exists()
    assert f"refs/heads/{BRANCH}" in git_world.refs(git_world.clone)


@pytest.mark.integration
def test_remote_only_branch_deletes_origin_copy(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    git_world.git("branch", "-D", BRANCH)
    assert f"refs/remotes/origin/{BRANCH}" in git_world.refs(git_world.clone)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == [f"origin:{BRANCH}"]
    assert run.data["left"] == []
    assert f"refs/heads/{BRANCH}" not in git_world.refs(git_world.origin)


@pytest.mark.integration
def test_stale_worktree_entry_is_pruned_before_scan(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    gone = git_world.worktree("gone", BRANCH)
    shutil.rmtree(gone)
    assert "prunable" in git_world.worktrees()

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert sorted(run.data["deleted"]) == sorted([f"local:{BRANCH}", f"origin:{BRANCH}"])
    assert run.data["left"] == []
    assert str(gone) not in git_world.worktrees()
    prefixes = [call[2:4] for call in run.calls]
    assert prefixes.index(("worktree", "prune")) < prefixes.index(("worktree", "list"))


@pytest.mark.integration
def test_dry_run_lists_plan_and_changes_no_refs_or_worktrees(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    first, second = git_world.worktree("one", BRANCH), git_world.worktree("two", BRANCH)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, "--dry-run"))

    assert run.code == 0, run.stderr
    assert run.data["dry_run"] is True
    expected = [f"worktree:{first}", f"worktree:{second}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert run.data["left"] == []
    assert snapshot(git_world) == before
    assert not MUTATING & (set(run.subcommands) - {"worktree"})
    assert {call[3] for call in run.calls if call[2] == "worktree"} == {"list"}


@pytest.mark.integration
def test_fetches_with_prune_by_default(git_world, run_cleanup):
    git_world.add_branch(BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    fetches = [i for i, call in enumerate(run.calls) if call[2:] == ("fetch", "--prune", "origin")]
    ancestry = [i for i, call in enumerate(run.calls) if call[2] == "merge-base"]
    assert len(fetches) == 1 and ancestry and fetches[0] < ancestry[0]


@pytest.mark.integration
def test_no_fetch_runs_no_fetch(git_world, run_cleanup):
    git_world.add_branch(BRANCH)

    run = run_cleanup(*cli(git_world, "--no-fetch"))

    assert run.code == 0, run.stderr
    assert "fetch" not in run.subcommands
    assert sorted(run.data["deleted"]) == sorted([f"local:{BRANCH}", f"origin:{BRANCH}"])


@pytest.mark.integration
def test_repo_may_be_a_linked_worktree_that_is_removed(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    linked = git_world.worktree("here", BRANCH)

    run = run_cleanup("--repo", str(linked), f"--branch={BRANCH}", f"--target={TARGET}")

    assert run.code == 0, run.stderr
    expected = [f"worktree:{linked}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert not linked.exists()
    mutating = [c for c in run.calls if c[2] in {"update-ref", "push"} or c[2:4] == ("worktree", "remove")]
    assert mutating and all(Path(call[1]).resolve() == git_world.clone for call in mutating)


# --- AC 11: refusals (exit 2, JSON error, nothing but read-only git) -----------------------

PROTECTED_NAMES = ["main", "master", "dev", "develop", "prod", "production", "release",
                   "staging", "Main", "DEV"]


@pytest.mark.unit
@pytest.mark.parametrize("name", PROTECTED_NAMES)
def test_refuses_protected_branch_names(name, git_world, run_cleanup, assert_refused):
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, branch=name))

    assert_refused(run)
    assert "protected" in run.data["error"]
    assert run.calls == () and snapshot(git_world) == before


@pytest.mark.unit
def test_refuses_remote_default_branch(git_world, run_cleanup, assert_refused):
    run = run_cleanup(*cli(git_world, branch="trunk"))

    assert_refused(run)
    assert "default branch" in run.data["error"]


@pytest.mark.unit
@pytest.mark.parametrize("target", ["origin/feat/r", "refs/remotes/origin/feat/r", "feat/r"])
def test_refuses_branch_equal_to_target_branch(target, git_world, run_cleanup, assert_refused):
    run = run_cleanup(*cli(git_world, branch="feat/r", target=target))

    assert_refused(run)
    assert "target" in run.data["error"]


@pytest.mark.unit
def test_refuses_target_head_when_head_is_the_branch(git_world, run_cleanup, assert_refused):
    git_world.add_branch(BRANCH)
    git_world.git("checkout", "-q", BRANCH)

    assert_refused(run_cleanup(*cli(git_world, target="HEAD")))


@pytest.mark.unit
@pytest.mark.parametrize("name", ["-rf", "--all", "a..b", "a b", "@{-1}", "refs/heads/x", ""])
def test_refuses_invalid_branch_names(name, git_world, run_cleanup, assert_refused):
    git_world.git("checkout", "-q", "feat/r")
    git_world.git("checkout", "-q", "trunk")  # so @{-1} names a real branch
    before = snapshot(git_world)

    assert_refused(run_cleanup(*cli(git_world, branch=name)))

    assert snapshot(git_world) == before


@pytest.mark.unit
def test_refuses_unresolvable_target(git_world, run_cleanup, assert_refused):
    run = run_cleanup(*cli(git_world, target="origin/does-not-exist"))

    assert_refused(run)
    assert "target" in run.data["error"]


@pytest.mark.unit
def test_refuses_repo_that_is_not_a_git_work_tree(tmp_path, git_world, run_cleanup, assert_refused):
    plain = tmp_path / "plain"
    plain.mkdir()

    run = run_cleanup("--repo", str(plain), f"--branch={BRANCH}", f"--target={TARGET}")

    assert_refused(run)
    assert "work tree" in run.data["error"]


@pytest.mark.unit
@pytest.mark.parametrize("remote", ["nowhere", "-x"])
def test_refuses_unconfigured_remote(remote, git_world, run_cleanup, assert_refused):
    run = run_cleanup(*cli(git_world), f"--remote={remote}")

    assert_refused(run)
    assert "remote" in run.data["error"]


MISSING_ARGS = {
    "no-repo": ["--branch=wip/r/a", "--target=origin/feat/r"],
    "no-branch": ["--repo=.", "--target=origin/feat/r"],
    "no-target": ["--repo=.", "--branch=wip/r/a"],
    "unknown-flag": ["--repo=.", "--branch=wip/r/a", "--target=origin/feat/r", "--force"],
}


@pytest.mark.unit
@pytest.mark.parametrize("argv", MISSING_ARGS.values(), ids=MISSING_ARGS.keys())
def test_missing_required_args_exit_2_with_json_error(argv, run_cleanup, assert_refused):
    run = run_cleanup(*argv)

    assert_refused(run)
    assert run.calls == ()


# --- AC 12: safe execution ------------------------------------------------------------------


@pytest.mark.unit
def test_subprocess_calls_are_argument_lists_without_shell(subprocess_violations):
    script = Path(__file__).resolve().parents[1] / "bin" / "merged-branch-cleanup.py"

    assert subprocess_violations(script) == []


@pytest.mark.integration
def test_every_git_call_is_dash_c_and_never_switches_branches(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    git_world.worktree("one", BRANCH)
    git_world.worktree("two", BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    assert run.calls
    for call in run.calls:
        assert call[0] == "-C" and Path(call[1]).is_absolute(), call
        assert call[2] not in {"checkout", "switch", "reset", "stash", "merge", "rebase", "pull"}
        assert call[2] != "branch" and not UNSAFE & set(call), call
    mutating = [c for c in run.calls if c[2] in {"update-ref", "config", "push"}]
    assert {Path(call[1]).resolve() for call in mutating} == {git_world.clone}


@pytest.mark.unit
def test_parse_worktree_porcelain_reads_locked_prunable_detached_entries(load_script):
    module = load_script("merged-branch-cleanup")
    entries = [
        ["worktree /m", "HEAD aaa", "branch refs/heads/trunk"],
        ["worktree /w1", "HEAD bbb", "branch refs/heads/wip/x", "locked on usb"],
        ["worktree /w2", "HEAD ccc", "detached", "prunable gitdir file points nowhere"],
        ["worktree /w3", "HEAD ddd", "branch refs/heads/wip/y", "locked"],
    ]
    text = "".join("\0".join(entry) + "\0\0" for entry in entries)

    parsed = module.parse_worktrees(text)

    assert [wt.path for wt in parsed] == ["/m", "/w1", "/w2", "/w3"]
    assert [wt.branch for wt in parsed] == ["trunk", "wip/x", None, "wip/y"]
    assert [wt.is_main for wt in parsed] == [True, False, False, False]
    assert [wt.locked for wt in parsed] == [None, "on usb", None, ""]
    assert [wt.prunable for wt in parsed] == [False, False, True, False]


@pytest.mark.unit
def test_plan_keeps_local_branch_while_any_worktree_holds_it(load_script):
    mod = load_script("merged-branch-cleanup")
    merged = mod.Copy(sha="a" * 40, merged=True, problem="")
    free = mod.Holder(mod.Worktree("/w/free", "wip/x", False, None, False), ())
    locked = mod.Holder(mod.Worktree("/w/lock", "wip/x", False, "usb", False), ())
    survey = mod.Survey(
        branch="wip/x", target="origin/feat/r", remote="origin", main_path="/m", local=merged,
        remote_copy=mod.Copy(sha=None, merged=False, problem=""), fetch_error=None,
        holders=(free, locked),
    )

    plan = mod.plan_cleanup(survey)

    assert plan.remove == ("/w/free",)
    assert plan.delete_local is False and plan.delete_remote is False
    refs = {item.ref: item.why for item in plan.left}
    assert set(refs) == {"worktree:/w/lock", "local:wip/x"}
    assert "/w/lock" in refs["local:wip/x"]
    assert survey.holders == (free, locked)
    with pytest.raises(AttributeError):
        plan.delete_local = True
