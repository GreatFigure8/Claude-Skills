"""merged-branch-cleanup.py: deletes one merged branch, every worktree holding it, local and remote.

Run: uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
Fixtures (real throwaway repos, git shim, fake gh) live in conftest.py.
"""
import shutil
from pathlib import Path

import pytest

BRANCH = "wip/r/a"
OTHER = "wip/r/other"
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


def ignore(world, *patterns):
    """Ignore `patterns` in every worktree via the shared info/exclude, without a commit."""
    exclude = world.clone / ".git" / "info" / "exclude"
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.write_text("".join(f"{pattern}\n" for pattern in patterns))


def add_branch_with_commits(world, name, count):
    """Like GitWorld.add_branch(merged=True), but with `count` commits on the branch."""
    world.git("checkout", "-q", "-b", name, "feat/r")
    for index in range(count):
        world.commit(f"step-{index}.txt", f"{index}\n", message=f"step {index}")
    world.git("push", "-q", "origin", name)
    world.merge_no_ff(name, "feat/r")


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
def test_worktree_holding_an_ignored_file_is_kept_with_the_file(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    ignore(git_world, ".env", "__pycache__/")
    held, clean = git_world.worktree("env", BRANCH), git_world.worktree("clean", BRANCH)
    local_only = held / ".env"
    local_only.write_text("LOCAL_SETTING=keep-me\n")

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}"}
    assert "ignored" in left[f"worktree:{held}"] and ".env" in left[f"worktree:{held}"]
    assert str(held) in left[f"local:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{clean}", f"origin:{BRANCH}"])
    assert local_only.read_text() == "LOCAL_SETTING=keep-me\n"
    assert f"refs/heads/{BRANCH}" in git_world.refs(git_world.clone)


@pytest.mark.integration
def test_worktree_whose_only_ignored_files_are_caches_is_removed(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    ignore(git_world, "__pycache__/", "node_modules/", "*.pyc")
    cached = git_world.worktree("cache", BRANCH)
    for relative in ("pkg/__pycache__/mod.cpython-39.pyc", "node_modules/dep/index.js"):
        (cached / relative).parent.mkdir(parents=True, exist_ok=True)
        (cached / relative).write_text("regenerable\n")

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    expected = [f"worktree:{cached}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert run.data["left"] == [] and not cached.exists()


CACHE_VERDICTS = {
    "!! node_modules/": True,
    "!! pkg/__pycache__/": True,
    "!! pkg/__pycache__/mod.pyc": True,
    "!! .venv/": True,
    "!! .env": False,
    "!! config/.env": False,
    "!! .venv": False,  # a file named like a cache directory is not one
    "!! build/": False,
    "?? node_modules/": False,
    " M node_modules/x.js": False,
    # regenerable outputs of Next.js, TypeScript, Playwright, coverage, macOS, setuptools, tooling
    "!! next-env.d.ts": True,
    "!! web/next-env.d.ts": True,
    "!! tsconfig.tsbuildinfo": True,
    "!! app/tsconfig.app.tsbuildinfo": True,
    "!! test-results/": True,
    "!! e2e/test-results/x.png": True,
    "!! playwright-report/": True,
    "!! .coverage": True,
    "!! .coverage.host.123.456": True,
    "!! .DS_Store": True,
    "!! docs/.DS_Store": True,
    "!! src/pkg.egg-info/": True,
    "!! pkg.egg-info/PKG-INFO": True,
    "!! htmlcov/": True,
    "!! .tox/": True,
    "!! .nox/": True,
    "!! .turbo/": True,
    "!! .parcel-cache/": True,
    "!! .eslintcache": True,
    # near-misses stay blocking: exact and case-sensitive, ignored entries only
    "!! .env.local": False,
    "!! secrets.pem": False,
    "!! next-env.d.ts.bak": False,
    "!! notes.tsbuildinfo.txt": False,
    "?? next-env.d.ts": False,
    "?? .DS_Store": False,
    " M test-results/keep.txt": False,
    "!! dist/": False,
    "!! coverage.json": False,
}


@pytest.mark.unit
@pytest.mark.parametrize("entry, is_cache", CACHE_VERDICTS.items(), ids=CACHE_VERDICTS.keys())
def test_only_ignored_regenerable_outputs_count_as_cache(entry, is_cache, load_script):
    module = load_script("merged-branch-cleanup")

    assert module.is_cache(entry) is is_cache


@pytest.mark.unit
def test_cache_rules_are_named_immutable_string_tuples(load_script):
    module = load_script("merged-branch-cleanup")

    for rules in (module.CACHE_DIRS, module.CACHE_FILES):
        assert isinstance(rules, (tuple, frozenset)) and rules
        assert all(isinstance(rule, str) for rule in rules)


REGENERABLE = ("next-env.d.ts", "tsconfig.tsbuildinfo", "test-results/a.png",
               "playwright-report/index.html", ".coverage", ".DS_Store")
REGENERABLE_IGNORES = ("next-env.d.ts", "*.tsbuildinfo", "test-results/", "playwright-report/",
                       ".coverage", ".DS_Store")


def write_files(base, names):
    for name in names:
        (base / name).parent.mkdir(parents=True, exist_ok=True)
        (base / name).write_text("regenerable\n")


@pytest.mark.integration
def test_worktree_whose_only_ignored_files_are_regenerable_outputs_is_removed(
    git_world, run_cleanup
):
    git_world.add_branch(BRANCH)
    ignore(git_world, *REGENERABLE_IGNORES)
    built = git_world.worktree("built", BRANCH)
    write_files(built, REGENERABLE)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    expected = [f"worktree:{built}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert run.data["left"] == [] and not built.exists()


@pytest.mark.integration
def test_regenerable_outputs_plus_ignored_env_keep_the_worktree(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    ignore(git_world, *REGENERABLE_IGNORES, ".env")
    held = git_world.worktree("held", BRANCH)
    write_files(held, REGENERABLE)
    (held / ".env").write_bytes(b"SECRET=keep-me\n")

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}"}
    assert ".env" in left[f"worktree:{held}"]
    assert (held / ".env").read_bytes() == b"SECRET=keep-me\n"
    assert run.data["deleted"] == [f"origin:{BRANCH}"]


@pytest.mark.integration
@pytest.mark.parametrize("operation", ["rebase", "bisect"])
def test_branch_being_rebased_or_bisected_keeps_local_branch(operation, git_world, run_cleanup):
    add_branch_with_commits(git_world, BRANCH, 3)
    busy = git_world.worktree("busy", BRANCH)
    steps = {"rebase": ("rebase", "--force-rebase", "--exec", "false", "HEAD~2"),
             "bisect": ("bisect", "start", BRANCH, "trunk")}[operation]
    git_world.git(*steps, cwd=busy, check=False)
    assert git_world.out("branch", "--show-current", cwd=busy) == "", "worktree must be detached"
    tip = git_world.sha(BRANCH)

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"local:{BRANCH}"}
    assert "rebase or bisect" in left[f"local:{BRANCH}"]
    assert git_world.sha(f"refs/heads/{BRANCH}") == tip and busy.exists()
    assert "update-ref" not in run.subcommands


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
def test_stale_entry_holding_the_branch_is_removed_and_other_stale_entries_kept(
    git_world, run_cleanup
):
    git_world.add_branch(BRANCH)
    git_world.add_branch(OTHER)
    gone, elsewhere = git_world.worktree("gone", BRANCH), git_world.worktree("away", OTHER)
    shutil.rmtree(gone)
    shutil.rmtree(elsewhere)  # e.g. a worktree on an unmounted volume: not this run's business
    assert git_world.worktrees().count("prunable") == 2

    run = run_cleanup(*cli(git_world))

    assert run.code == 0, run.stderr
    expected = [f"worktree:{gone}", f"local:{BRANCH}", f"origin:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert run.data["left"] == []
    listing = git_world.worktrees()
    assert str(gone) not in listing and str(elsewhere) in listing
    assert ("worktree", "prune") not in [call[2:4] for call in run.calls]
    removals = [call[4:] for call in run.calls if call[2:4] == ("worktree", "remove")]
    assert removals == [(str(gone),)]


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


# --- --local-only: the remote copy is never touched ----------------------------------------

LOCAL_ONLY_WHY = "origin copy kept: --local-only"


def remote_calls(run):
    """Every git call that could write to a remote: any push, or a lease/delete flag."""
    return [call for call in run.calls
            if call[2] == "push" or any(arg.startswith("--force-with-lease") for arg in call)]


@pytest.mark.integration
def test_local_only_never_pushes_and_keeps_a_merged_origin_copy(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    held = git_world.worktree("one", BRANCH)
    origin_tip = git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin)

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    assert "push" not in run.subcommands and remote_calls(run) == []
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == origin_tip
    assert left_map(run.data) == {f"origin:{BRANCH}": LOCAL_ONLY_WHY}
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{held}", f"local:{BRANCH}"])
    assert not any(ref.startswith("origin:") for ref in run.data["deleted"])


@pytest.mark.integration
def test_local_only_reports_an_unmerged_origin_copy_once(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    extra = move_origin_ahead(git_world, BRANCH)

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    entries = [entry for entry in run.data["left"] if entry["ref"].startswith("origin:")]
    assert entries == [{"ref": f"origin:{BRANCH}", "why": LOCAL_ONLY_WHY}]
    assert run.data["deleted"] == [f"local:{BRANCH}"]
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == extra
    assert "push" not in run.subcommands


@pytest.mark.integration
def test_local_only_without_an_origin_copy_leaves_no_remote_entry(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    git_world.git("push", "-q", "origin", "--delete", BRANCH)

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == [f"local:{BRANCH}"]
    assert not any(entry["ref"].startswith("origin:") for entry in run.data["left"])


@pytest.mark.integration
def test_local_only_keeps_worktree_holding_an_ignored_env(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    ignore(git_world, ".env")
    held = git_world.worktree("env", BRANCH)
    (held / ".env").write_bytes(b"LOCAL_SETTING=keep-me\n")

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert "ignored" in left[f"worktree:{held}"] and ".env" in left[f"worktree:{held}"]
    assert (held / ".env").read_bytes() == b"LOCAL_SETTING=keep-me\n"
    assert run.data["deleted"] == []
    assert f"refs/heads/{BRANCH}" in git_world.refs(git_world.clone)


@pytest.mark.integration
def test_local_only_removes_clean_worktree_and_deletes_branch_compare_and_swap(
    git_world, run_cleanup
):
    git_world.add_branch(BRANCH)
    held = git_world.worktree("clean", BRANCH)
    tip = git_world.sha(f"refs/heads/{BRANCH}")

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{held}", f"local:{BRANCH}"])
    assert not held.exists() and f"refs/heads/{BRANCH}" not in git_world.refs(git_world.clone)
    deletes = [call[2:] for call in run.calls if call[2] == "update-ref"]
    assert deletes == [("update-ref", "-d", f"refs/heads/{BRANCH}", tip)]
    for call in run.calls:
        if call[2] == "worktree":
            assert not UNSAFE & set(call), call


@pytest.mark.integration
@pytest.mark.parametrize("operation", ["rebase", "bisect"])
def test_local_only_keeps_branch_being_rebased_or_bisected(operation, git_world, run_cleanup):
    add_branch_with_commits(git_world, BRANCH, 3)
    busy = git_world.worktree("busy", BRANCH)
    steps = {"rebase": ("rebase", "--force-rebase", "--exec", "false", "HEAD~2"),
             "bisect": ("bisect", "start", BRANCH, "trunk")}[operation]
    git_world.git(*steps, cwd=busy, check=False)
    assert git_world.out("branch", "--show-current", cwd=busy) == "", "worktree must be detached"
    tip = git_world.sha(BRANCH)

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert "rebase or bisect" in left[f"local:{BRANCH}"]
    assert left[f"origin:{BRANCH}"] == LOCAL_ONLY_WHY
    assert git_world.sha(f"refs/heads/{BRANCH}") == tip and busy.exists()
    assert "update-ref" not in run.subcommands and "push" not in run.subcommands


@pytest.mark.integration
def test_local_only_keeps_an_unmerged_local_branch(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    held = git_world.worktree("held", BRANCH)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, "--local-only"))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == []
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert f"not merged into {TARGET}" in left[f"local:{BRANCH}"]
    assert left[f"origin:{BRANCH}"] == LOCAL_ONLY_WHY
    assert snapshot(git_world) == before
    assert not {"update-ref", "push"} & set(run.subcommands)


@pytest.mark.integration
def test_local_only_dry_run_plans_no_remote_delete_and_changes_nothing(git_world, run_cleanup):
    git_world.add_branch(BRANCH)
    first, second = git_world.worktree("one", BRANCH), git_world.worktree("two", BRANCH)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, "--local-only", "--dry-run"))

    assert run.code == 0, run.stderr
    assert run.data["dry_run"] is True
    expected = [f"worktree:{first}", f"worktree:{second}", f"local:{BRANCH}"]
    assert sorted(run.data["deleted"]) == sorted(expected)
    assert run.data["left"] == [{"ref": f"origin:{BRANCH}", "why": LOCAL_ONLY_WHY}]
    assert "fetch" not in run.subcommands
    assert snapshot(git_world) == before
    assert not MUTATING & (set(run.subcommands) - {"worktree"})
    assert {call[3] for call in run.calls if call[2] == "worktree"} == {"list"}


@pytest.mark.unit
def test_docstring_contract_and_help_name_local_only(load_script, run_cleanup):
    doc = load_script("merged-branch-cleanup").__doc__
    contract = " ".join(doc.split("Contract:")[1].split("Safety:")[0].split())

    helped = run_cleanup("--help")

    assert "[--local-only]" in contract
    assert "never touches the remote copy" in contract and 'reported in "left"' in contract
    assert helped.code == 0 and "--local-only" in helped.stdout


LOCAL_ONLY_REFUSALS = {
    "main": ("main", TARGET),
    "protected-upper": ("DEV", TARGET),
    "default-branch": ("trunk", TARGET),
    "own-target": ("feat/r", "origin/feat/r"),
    "missing-target": (BRANCH, "origin/does-not-exist"),
    "tip-expression": (BRANCH, f"{BRANCH}~0"),
    "option-like-branch": ("-rf", TARGET),
}


@pytest.mark.unit
@pytest.mark.parametrize("branch, target", LOCAL_ONLY_REFUSALS.values(),
                         ids=LOCAL_ONLY_REFUSALS.keys())
def test_refusals_still_apply_with_local_only(branch, target, git_world, run_cleanup,
                                              assert_refused):
    git_world.add_branch(BRANCH, merged=False)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, "--local-only", branch=branch, target=target))

    assert_refused(run)
    assert "unrecognized" not in run.data["error"], "the flag must parse before it can be refused"
    assert snapshot(git_world) == before


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
def test_refuses_default_branch_when_origin_head_is_not_set_locally(
    git_world, run_cleanup, assert_refused
):
    git_world.git("remote", "set-head", "origin", "--delete")
    git_world.git("checkout", "-q", "feat/r")  # so trunk is held by no worktree
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, branch="trunk"))

    assert_refused(run)
    assert "default branch" in run.data["error"]
    assert snapshot(git_world) == before


@pytest.mark.unit
def test_refuses_when_the_default_branch_cannot_be_determined(
    git_world, run_cleanup, assert_refused
):
    git_world.add_branch(BRANCH)
    git_world.git("remote", "set-head", "origin", "--delete")
    git_world.git("remote", "set-url", "origin", str(git_world.root / "unreachable.git"))
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world))

    assert_refused(run)
    assert "default branch" in run.data["error"]
    assert snapshot(git_world) == before


TIP_EXPRESSIONS = ["{branch}~0", "{branch}@{{0}}", "{branch}^{{commit}}", "{sha}", "trunk..{branch}"]


@pytest.mark.unit
@pytest.mark.parametrize("pattern", TIP_EXPRESSIONS)
def test_refuses_target_that_is_a_commit_expression_not_a_ref(
    pattern, git_world, run_cleanup, assert_refused
):
    sha = git_world.add_branch(BRANCH, merged=False)
    before = snapshot(git_world)

    run = run_cleanup(*cli(git_world, target=pattern.format(branch=BRANCH, sha=sha)))

    assert_refused(run)
    assert "target" in run.data["error"]
    assert snapshot(git_world) == before


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


# --- FIX1 R1-6: --local-only is decided inside the plan, not filtered out afterwards ---------

KEPT = "origin copy kept: --local-only"


def local_only_survey(mod, local, remote, fetch_error=None):
    """A --local-only Survey of branch wip/x whose local and origin copies are given."""
    return mod.Survey(
        branch="wip/x", target="origin/feat/r", remote="origin", main_path="/m",
        local=local, remote_copy=remote, fetch_error=fetch_error, holders=(), local_only=True,
    )


LOCAL_ONLY_SCENARIOS = {
    "merged-both": ("merged", "merged", None),
    "merged-both-fetch-failed": ("merged", "merged", "network down"),
    "unmerged-local-merged-origin": ("unmerged", "merged", None),
    "unmerged-both": ("unmerged", "unmerged", None),
    "origin-only": ("absent", "merged", None),
    "origin-only-unmerged": ("absent", "unmerged", None),
}


def copy_of(mod, state):
    return {"merged": mod.Copy("a" * 40, True, ""), "unmerged": mod.Copy("b" * 40, False, ""),
            "absent": mod.Copy(None, False, "")}[state]


@pytest.mark.unit
@pytest.mark.parametrize("local, remote, fetch_error", LOCAL_ONLY_SCENARIOS.values(),
                         ids=LOCAL_ONLY_SCENARIOS.keys())
def test_local_only_plan_reports_the_origin_copy_once_whatever_the_state(
    local, remote, fetch_error, load_script
):
    mod = load_script("merged-branch-cleanup")
    survey = local_only_survey(mod, copy_of(mod, local), copy_of(mod, remote), fetch_error)
    kept = mod.Left("origin:wip/x", KEPT)

    plan = mod.plan_cleanup(survey)

    assert [item for item in plan.left if item.ref == "origin:wip/x"] == [kept]
    assert plan.delete_remote is False


@pytest.mark.unit
@pytest.mark.parametrize("fetch_error", [None, "network down"])
def test_local_only_plan_remote_decides_the_origin_copy_itself(fetch_error, load_script):
    mod = load_script("merged-branch-cleanup")
    survey = local_only_survey(mod, copy_of(mod, "merged"), copy_of(mod, "merged"), fetch_error)

    assert mod.plan_remote(survey) == ((mod.Left("origin:wip/x", KEPT),), False)


@pytest.mark.unit
def test_local_only_plan_unmerged_decides_the_origin_copy_itself(load_script):
    mod = load_script("merged-branch-cleanup")
    survey = local_only_survey(mod, copy_of(mod, "unmerged"), copy_of(mod, "merged"))

    plan = mod.plan_unmerged(survey)

    assert plan.left[-1] == mod.Left("origin:wip/x", KEPT)
    assert [item.ref for item in plan.left].count("origin:wip/x") == 1


# --- FIX1 R1-1: --pushed proves "pushed" instead of "merged" (the machine-move tidy) ---------


def pushed_cli(world, *extra, branch=BRANCH, target=None):
    return cli(world, "--pushed", *extra, branch=branch, target=target or f"origin/{branch}")


@pytest.mark.integration
def test_pushed_keeps_a_worktree_holding_an_ignored_env(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    ignore(git_world, ".env")
    held = git_world.worktree("env", BRANCH)
    (held / ".env").write_bytes(b"LOCAL_SETTING=keep-me\n")
    origin_tip = git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin)

    run = run_cleanup(*pushed_cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert ".env" in left[f"worktree:{held}"] and left[f"origin:{BRANCH}"] == LOCAL_ONLY_WHY
    assert (held / ".env").read_bytes() == b"LOCAL_SETTING=keep-me\n"
    assert run.data["deleted"] == []
    assert "push" not in run.subcommands
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == origin_tip


@pytest.mark.integration
def test_pushed_removes_a_clean_worktree_and_deletes_only_the_local_branch(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    held = git_world.worktree("clean", BRANCH)
    tip = git_world.sha(f"refs/heads/{BRANCH}")

    run = run_cleanup(*pushed_cli(git_world))

    assert run.code == 0, run.stderr
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{held}", f"local:{BRANCH}"])
    assert left_map(run.data) == {f"origin:{BRANCH}": LOCAL_ONLY_WHY}
    assert not held.exists() and f"refs/heads/{BRANCH}" not in git_world.refs(git_world.clone)
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == tip
    assert [call[2:] for call in run.calls if call[2] == "update-ref"] == [
        ("update-ref", "-d", f"refs/heads/{BRANCH}", tip)]
    assert remote_calls(run) == []
    for call in run.calls:
        if call[2] == "worktree":
            assert not UNSAFE & set(call), call


@pytest.mark.integration
def test_pushed_deletes_a_local_branch_that_origin_is_ahead_of(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    extra = move_origin_ahead(git_world, BRANCH)

    run = run_cleanup(*pushed_cli(git_world))

    assert run.code == 0, run.stderr
    assert run.data["deleted"] == [f"local:{BRANCH}"]
    assert git_world.sha(f"refs/heads/{BRANCH}", cwd=git_world.origin) == extra


@pytest.mark.integration
def test_pushed_keeps_worktree_and_branch_holding_unpushed_commits(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    held = git_world.worktree("one", BRANCH)
    local_tip = git_world.commit("later.txt", "not pushed\n", cwd=held, message="unpushed")
    before = snapshot(git_world)

    run = run_cleanup(*pushed_cli(git_world))

    assert run.code == 0, run.stderr
    left = left_map(run.data)
    assert set(left) == {f"worktree:{held}", f"local:{BRANCH}", f"origin:{BRANCH}"}
    assert f"not merged into origin/{BRANCH}" in left[f"local:{BRANCH}"]
    assert run.data["deleted"] == [] and held.exists()
    assert git_world.sha(f"refs/heads/{BRANCH}") == local_tip
    assert snapshot(git_world) == before and "update-ref" not in run.subcommands


@pytest.mark.integration
@pytest.mark.parametrize("operation", ["rebase", "bisect"])
def test_pushed_keeps_a_branch_being_rebased_or_bisected(operation, git_world, run_cleanup):
    add_branch_with_commits(git_world, BRANCH, 3)
    busy = git_world.worktree("busy", BRANCH)
    steps = {"rebase": ("rebase", "--force-rebase", "--exec", "false", "HEAD~2"),
             "bisect": ("bisect", "start", BRANCH, "trunk")}[operation]
    git_world.git(*steps, cwd=busy, check=False)
    tip = git_world.sha(BRANCH)

    run = run_cleanup(*pushed_cli(git_world))

    assert run.code == 0, run.stderr
    assert "rebase or bisect" in left_map(run.data)[f"local:{BRANCH}"]
    assert git_world.sha(f"refs/heads/{BRANCH}") == tip and busy.exists()
    assert "update-ref" not in run.subcommands


@pytest.mark.integration
def test_pushed_dry_run_plans_the_local_deletes_and_changes_nothing(git_world, run_cleanup):
    git_world.add_branch(BRANCH, merged=False)
    held = git_world.worktree("one", BRANCH)
    before = snapshot(git_world)

    run = run_cleanup(*pushed_cli(git_world, "--dry-run"))

    assert run.code == 0, run.stderr
    assert sorted(run.data["deleted"]) == sorted([f"worktree:{held}", f"local:{BRANCH}"])
    assert run.data["left"] == [{"ref": f"origin:{BRANCH}", "why": LOCAL_ONLY_WHY}]
    assert "fetch" not in run.subcommands and snapshot(git_world) == before


PUSHED_REFUSALS = {
    "other-target": (BRANCH, TARGET),
    "no-origin-copy": (BRANCH, "origin/wip/r/never-pushed"),
    "local-target": (BRANCH, BRANCH),
    "protected": ("dev", "origin/dev"),
    "default-branch": ("trunk", "origin/trunk"),
}


@pytest.mark.unit
@pytest.mark.parametrize("branch, target", PUSHED_REFUSALS.values(), ids=PUSHED_REFUSALS.keys())
def test_pushed_still_refuses_anything_but_the_branchs_own_origin_copy(
    branch, target, git_world, run_cleanup, assert_refused
):
    git_world.add_branch(BRANCH, merged=False)
    before = snapshot(git_world)

    run = run_cleanup(*pushed_cli(git_world, branch=branch, target=target))

    assert_refused(run)
    assert "unrecognized" not in run.data["error"], "the flag must parse before it can be refused"
    assert snapshot(git_world) == before


@pytest.mark.unit
def test_own_origin_copy_target_is_still_refused_without_pushed(git_world, run_cleanup,
                                                                 assert_refused):
    git_world.add_branch(BRANCH, merged=False)

    assert_refused(run_cleanup(*cli(git_world, "--local-only", target=f"origin/{BRANCH}")))
    assert_refused(run_cleanup(*cli(git_world, target=f"origin/{BRANCH}")))


@pytest.mark.unit
def test_docstring_contract_and_help_name_pushed(load_script, run_cleanup):
    doc = load_script("merged-branch-cleanup").__doc__
    contract = " ".join(doc.split("Contract:")[1].split("Safety:")[0].split())

    helped = run_cleanup("--help")

    assert "[--pushed]" in contract and "implies --local-only" in contract
    assert "own" in contract and helped.code == 0 and "--pushed" in helped.stdout
