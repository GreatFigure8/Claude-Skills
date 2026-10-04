#!/usr/bin/env python3
"""merged-branch-cleanup.py — delete one merged branch, every worktree holding it, local and remote.

Purpose:
  After a merge, remove every linked worktree that has the branch checked out, delete the local
  branch and its remote copy, but only once git proves the tip is in --target. Whatever it cannot
  prove or cannot safely remove is kept and reported in "left".

Contract:
  merged-branch-cleanup.py --repo <path> --branch <name> --target <ref>
                           [--remote origin] [--no-fetch] [--dry-run]
  stdout, one JSON object: {"branch", "target", "dry_run", "deleted": [...], "left": [{"ref", "why"}]}
  Refs are "worktree:<abs path>", "local:<branch>" and "<remote>:<branch>". Exit 0 = it ran
  (inspect "left"). Exit 2 = refused or usage error: stdout {"error": "..."}, nothing changed.
  --dry-run runs no fetch, changes nothing and prints the plan.

Safety:
  Refuses protected names (main master dev develop prod production release staging, any case), the
  remote's default branch (asked of the remote when <remote>/HEAD is unset; refused if unknowable),
  a --target that is not a branch or tag name or is the branch itself, malformed names and a
  non-work-tree repo. Proves ancestry with `merge-base --is-ancestor` before any delete. Keeps main,
  locked and dirty worktrees (dirty counts ignored files outside CACHE_DIRS, which `worktree remove`
  would delete) and the local branch while a rebase or bisect of it runs. Never forces, unlocks or
  prunes other worktrees. Deletes are compare-and-swap on the checked SHA (update-ref -d, push
  --force-with-lease). Git runs as an argument list via `git -C <path>`, and never checkout,
  switch, reset, stash, merge, rebase or pull.
"""

import argparse
import json
import os
import subprocess
import sys
from collections import namedtuple
from pathlib import Path

PROTECTED = frozenset({"main", "master", "dev", "develop", "prod", "production", "release", "staging"})
# Ignored directories that tooling regenerates; any other ignored path keeps its worktree.
CACHE_DIRS = frozenset({"__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache", ".venv",
                        "node_modules", ".next"})
# A rebase or bisect in progress; git's own branch delete refuses the branch these files name.
BUSY_FILES = ("rebase-merge/head-name", "rebase-apply/head-name", "BISECT_START")
GIT_READ_TIMEOUT_S = 30
GIT_NETWORK_TIMEOUT_S = 120
EXIT_RAN = 0
EXIT_REFUSED = 2
HEADS = "refs/heads/"
REMOTES = "refs/remotes/"


class Refusal(Exception):
    """A request the script will not act on; its message becomes {"error": ...}."""


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise Refusal(f"usage: {message}")


# Immutable records: what the options say, what a survey found, what the plan decides.
Options = namedtuple("Options", "repo branch target remote fetch dry_run target_ref", defaults=(None,))
Worktree = namedtuple("Worktree", "path branch is_main locked prunable")  # locked: None or reason
Holder = namedtuple("Holder", "worktree dirty")  # dirty: status entries that block removal
Copy = namedtuple("Copy", "sha merged problem")  # sha None = no such ref
Survey = namedtuple("Survey", "branch target remote main_path local remote_copy fetch_error "
                              "holders busy", defaults=("",))  # busy: why a rebase/bisect holds it
Left = namedtuple("Left", "ref why")
Plan = namedtuple("Plan", "remove delete_local delete_remote left")
GitResult = namedtuple("GitResult", "code ok out text reason")


# arguments and git plumbing
def parse_args(argv):
    parser = JsonArgumentParser(prog="merged-branch-cleanup.py", allow_abbrev=False,
                                description="Delete a merged branch and every worktree holding it.")
    parser.add_argument("--repo", required=True, help="path of the repository (any worktree)")
    parser.add_argument("--branch", required=True, help="branch to delete")
    parser.add_argument("--target", required=True, help="branch or tag it must be merged into")
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--no-fetch", action="store_true", help="skip `git fetch --prune`")
    parser.add_argument("--dry-run", action="store_true", help="print the plan, change nothing")
    args = parser.parse_args(argv)
    if not args.repo:
        raise Refusal("usage: --repo must not be empty")
    return Options(os.path.abspath(args.repo), args.branch, args.target, args.remote,
                   not args.no_fetch, args.dry_run)


def failure_line(text):
    """The most telling line of a failure: a rejection or error line, else the first line."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    for line in lines:
        if "rejected" in line or line.startswith(("error:", "fatal:")):
            return line
    return lines[0] if lines else "git failed with no output"


def git_result(code, out, err):
    return GitResult(code, code == 0, out, out.strip(), failure_line(err or out))


def run_git(cwd, *args, timeout=GIT_READ_TIMEOUT_S):
    """Run `git -C cwd args`; never raises, a timeout or a missing git is a non-zero result."""
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    try:
        proc = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True,
                              encoding="utf-8", errors="replace", env=env, timeout=timeout,
                              check=False)
    except subprocess.TimeoutExpired:
        return git_result(124, "", f"git {args[0]} timed out after {timeout}s")
    except OSError as exc:
        return git_result(127, "", f"cannot run git: {exc}")
    return git_result(proc.returncode, proc.stdout, proc.stderr)


def short_branch(full_ref):
    """`refs/heads/x` and `refs/remotes/<remote>/x` both give `x`; anything else is unchanged."""
    if full_ref.startswith(REMOTES):
        return full_ref[len(REMOTES):].partition("/")[2]
    return full_ref.removeprefix(HEADS)


def resolve_commit(repo, ref):
    result = run_git(repo, "rev-parse", "--verify", "--quiet", "--end-of-options", f"{ref}^{{commit}}")
    return result.text if result.ok and result.text else None


# refusals: static checks first, then read-only git
def refuse_static(opts):
    name = opts.branch
    if not name or name.startswith(("-", "refs/")):
        raise Refusal(f"invalid branch name: {name!r}")
    if name.casefold() in PROTECTED:
        raise Refusal(f"branch {name!r} is protected and is never deleted")
    for label, value in (("--remote", opts.remote), ("--target", opts.target)):
        if not value or value.startswith("-"):
            raise Refusal(f"invalid {label} value: {value!r}")


def require_repo(opts):
    """A git work tree, a well-formed branch name and a configured remote, or a Refusal."""
    inside = run_git(opts.repo, "rev-parse", "--is-inside-work-tree")
    if not (inside.ok and inside.text == "true"):
        raise Refusal(f"{opts.repo} is not a git work tree")
    name = run_git(opts.repo, "check-ref-format", "--branch", opts.branch)
    if not name.ok or name.text != opts.branch:  # `@{-1}` and friends expand to another name
        raise Refusal(f"invalid branch name: {opts.branch!r}")
    remotes = run_git(opts.repo, "remote")
    if not remotes.ok or opts.remote not in remotes.out.split():
        raise Refusal(f"remote {opts.remote!r} is not configured in {opts.repo}")


def default_branch(opts):
    """<remote>/HEAD, else the remote's own HEAD; a remote that cannot be asked is a Refusal."""
    head = run_git(opts.repo, "symbolic-ref", "--quiet", f"{REMOTES}{opts.remote}/HEAD")
    if head.ok:
        return short_branch(head.text)
    asked = run_git(opts.repo, "ls-remote", "--symref", opts.remote, "HEAD",
                    timeout=GIT_NETWORK_TIMEOUT_S)
    if not asked.ok:
        raise Refusal(f"cannot tell the default branch of {opts.remote}: {asked.reason}")
    symrefs = [line.split()[1] for line in asked.out.splitlines() if line.startswith("ref: ")]
    return short_branch(symrefs[0]) if symrefs else ""  # no symref: the remote has no default


def resolve_target(opts):
    """Pin --target to the full branch or tag ref it names. A commit or an expression such as
    `<branch>~0` is refused: it would let the branch prove its own merge."""
    if resolve_commit(opts.repo, opts.target) is None:
        raise Refusal(f"--target {opts.target!r} does not resolve to a commit")
    full = run_git(opts.repo, "rev-parse", "--symbolic-full-name", opts.target).text
    if "\n" in full or not full.startswith((HEADS, REMOTES, "refs/tags/")):
        raise Refusal(f"--target {opts.target!r} must name a branch or tag, not a commit")
    if short_branch(full).casefold() == opts.branch.casefold():
        raise Refusal(f"{opts.branch!r} is the target's own branch; it cannot be merged into itself")
    return opts._replace(target_ref=full)


def validate(opts):
    """Return opts with target_ref set, or raise Refusal unless the request is safe to act on."""
    refuse_static(opts)
    require_repo(opts)
    default = default_branch(opts)
    if default and default.casefold() == opts.branch.casefold():
        raise Refusal(f"{opts.branch!r} is the default branch of {opts.remote}")
    return resolve_target(opts)


# survey: read what exists
def parse_worktrees(text):
    """Parse `git worktree list --porcelain -z`; the first entry is the main checkout."""
    blocks = [dict(field.partition(" ")[::2] for field in block.split("\0"))
              for block in text.split("\0\0") if block.strip("\0")]
    return tuple(Worktree(attrs.get("worktree", ""), short_branch(attrs.get("branch", "")) or None,
                          index == 0, attrs.get("locked"), "prunable" in attrs)
                 for index, attrs in enumerate(blocks))


def check_copy(repo, ref, target_sha):
    """Does `ref` exist, and is its tip proven to be an ancestor of the target?"""
    tip = resolve_commit(repo, ref)
    if tip is None:
        return Copy(None, False, "")
    verdict = run_git(repo, "merge-base", "--is-ancestor", tip, target_sha)
    if verdict.code in (0, 1):
        return Copy(tip, verdict.code == 0, "")
    return Copy(tip, False, f"could not prove merged: {verdict.reason}")


def is_cache(entry):
    """An ignored status entry inside a regenerable cache directory, e.g. `!! pkg/__pycache__/`."""
    return entry.startswith("!! ") and not CACHE_DIRS.isdisjoint(entry[3:].split("/")[:-1])


def dirty_paths(worktree):
    """Status entries `git worktree remove` would lose: changes, untracked and ignored files other
    than caches. A failing status counts as dirty because clean cannot be proved."""
    status = run_git(worktree.path, "status", "--porcelain", "-z", "--untracked-files=normal",
                     "--ignored=matching", "--ignore-submodules=none")
    if not status.ok:
        return (f"status failed: {status.reason}",)
    return tuple(entry for entry in status.out.split("\0") if entry and not is_cache(entry))


def find_holders(branch, worktrees):
    """Holders of the branch; main, locked and stale (directory gone) ones need no status check."""
    def checked(wt):
        stale = wt.prunable and not os.path.lexists(wt.path)
        return () if wt.is_main or wt.locked is not None or stale else dirty_paths(wt)
    return tuple(Holder(wt, checked(wt)) for wt in worktrees if wt.branch == branch)


def busy_with(opts):
    """Why a rebase or bisect started from the branch keeps it (git's own delete refuses), or ""."""
    common = run_git(opts.repo, "rev-parse", "--git-common-dir")
    if not common.ok:
        return f"cannot rule out a rebase or bisect of it: {common.reason}"
    names = (opts.branch, HEADS + opts.branch)
    try:
        root = Path(opts.repo, common.text)
        admin = root / "worktrees"
        gitdirs = [root, *sorted(admin.iterdir())] if admin.is_dir() else [root]
        for state in (gitdir / name for gitdir in gitdirs for name in BUSY_FILES):
            if state.is_file() and state.read_text("utf-8", "replace").strip() in names:
                return f"a rebase or bisect of it is in progress ({state})"
    except OSError as exc:
        return f"cannot rule out a rebase or bisect of it: {exc}"
    return ""


def survey(opts):
    fetched = run_git(opts.repo, "fetch", "--prune", opts.remote, timeout=GIT_NETWORK_TIMEOUT_S) \
        if opts.fetch and not opts.dry_run else None
    target_sha = resolve_commit(opts.repo, opts.target_ref)
    if target_sha is None:
        raise Refusal(f"--target {opts.target!r} no longer resolves to a commit")
    listing = run_git(opts.repo, "worktree", "list", "--porcelain", "-z")
    if not listing.ok:
        raise Refusal(f"cannot list worktrees, so nothing was deleted: {listing.reason}")
    worktrees = parse_worktrees(listing.out)
    return Survey(
        branch=opts.branch, target=opts.target, remote=opts.remote, main_path=worktrees[0].path,
        local=check_copy(opts.repo, f"{HEADS}{opts.branch}", target_sha),
        remote_copy=check_copy(opts.repo, f"{REMOTES}{opts.remote}/{opts.branch}", target_sha),
        fetch_error=fetched.reason if fetched and not fetched.ok else None,
        holders=find_holders(opts.branch, worktrees), busy=busy_with(opts),
    )


# plan: pure, decides what is deleted and what is left
def plan_unmerged(s):
    why = s.local.problem or f"not merged into {s.target}"
    held = tuple(Left(f"worktree:{h.worktree.path}", why) for h in s.holders)
    left = held + (Left(f"local:{s.branch}", why),)
    if s.remote_copy.sha is not None:
        remote_why = (f"kept with unmerged local:{s.branch}" if s.remote_copy.merged
                      else s.remote_copy.problem or f"not merged into {s.target}")
        left += (Left(f"{s.remote}:{s.branch}", remote_why),)
    return Plan((), False, False, left)


def blocker(holder):
    """Why this worktree cannot be removed, or None when it can."""
    wt, dirty = holder
    if wt.is_main:
        return "main checkout is never removed or switched"
    if wt.locked is not None:
        return f"locked: {wt.locked or 'no reason given'}; never unlocked"
    if dirty:
        return f"uncommitted or ignored files ({len(dirty)} paths, e.g. {dirty[0]}); never forced"
    return None


def plan_local(s, blocked):
    if s.local.sha is None:
        return (), False
    if s.busy:
        return (Left(f"local:{s.branch}", s.busy),), False
    if not blocked:
        return (), True
    in_main = any(h.worktree.is_main for h in blocked)
    why = "checked out in the main checkout" if in_main \
        else "checked out in worktree " + ", ".join(h.worktree.path for h in blocked)
    return (Left(f"local:{s.branch}", why),), False


def plan_remote(s):
    copy, ref = s.remote_copy, f"{s.remote}:{s.branch}"
    if copy.sha is None:
        return (), False
    if s.fetch_error:
        return (Left(ref, f"fetch failed, remote copy not verified: {s.fetch_error}"),), False
    if copy.merged:
        return (), True
    default_why = (f"{s.remote} has commits not in {s.target}" if s.local.sha is not None
                   else f"not merged into {s.target}")
    return (Left(ref, copy.problem or default_why),), False


def plan_merged(s):
    holders = s.holders if s.local.sha is not None else ()
    verdicts = tuple((holder, blocker(holder)) for holder in holders)
    blocked = tuple(holder for holder, why in verdicts if why is not None)
    held = tuple(Left(f"worktree:{h.worktree.path}", why) for h, why in verdicts if why)
    local_left, delete_local = plan_local(s, blocked)
    remote_left, delete_remote = plan_remote(s)
    remove = tuple(h.worktree.path for h, why in verdicts if why is None)
    return Plan(remove, delete_local, delete_remote, held + local_left + remote_left)


def plan_cleanup(s):
    if s.local.sha is not None and not s.local.merged:
        return plan_unmerged(s)
    return plan_merged(s)


# execute: every mutating call runs as `git -C <main checkout>`
def attempt(main, ref, *git_args, timeout=GIT_READ_TIMEOUT_S):
    """One mutating git call: success deletes `ref`, failure leaves it with git's own reason."""
    result = run_git(main, *git_args, timeout=timeout)
    return ((ref,), ()) if result.ok else ((), (Left(ref, result.reason),))


def delete_local_branch(main, branch, sha):
    done, failed = attempt(main, f"local:{branch}", "update-ref", "-d", f"{HEADS}{branch}", sha)
    if done:
        run_git(main, "config", "--remove-section", f"branch.{branch}")  # best effort
    return done, failed


def delete_remote_branch(main, remote, branch, sha):
    ref = f"{HEADS}{branch}"
    return attempt(main, f"{remote}:{branch}", "push", remote, "--delete",
                   f"--force-with-lease={ref}:{sha}", ref, timeout=GIT_NETWORK_TIMEOUT_S)


def planned_deletions(s, plan):
    return (tuple(f"worktree:{path}" for path in plan.remove)
            + ((f"local:{s.branch}",) if plan.delete_local else ())
            + ((f"{s.remote}:{s.branch}",) if plan.delete_remote else ()))


def execute(s, plan):
    main, deleted, left = s.main_path, (), ()
    for path in plan.remove:
        done, failed = attempt(main, f"worktree:{path}", "worktree", "remove", path)
        deleted, left = deleted + done, left + failed
    if plan.delete_local and left:
        stuck = left[0].ref.partition(":")[2]
        left += (Left(f"local:{s.branch}", f"worktree not removed: {stuck}"),)
    elif plan.delete_local:
        done, failed = delete_local_branch(main, s.branch, s.local.sha)
        deleted, left = deleted + done, left + failed
    if plan.delete_remote:
        done, failed = delete_remote_branch(main, s.remote, s.branch, s.remote_copy.sha)
        deleted, left = deleted + done, left + failed
    return deleted, plan.left + left


def main(argv=None):
    try:
        opts = validate(parse_args(sys.argv[1:] if argv is None else argv))
        found = survey(opts)
        plan = plan_cleanup(found)
        deleted, left = (planned_deletions(found, plan), plan.left) if opts.dry_run \
            else execute(found, plan)
    except Refusal as refusal:
        print(json.dumps({"error": str(refusal)}))
        return EXIT_REFUSED
    print(json.dumps({"branch": opts.branch, "target": opts.target, "dry_run": opts.dry_run,
                      "deleted": list(deleted),
                      "left": [{"ref": item.ref, "why": item.why} for item in left]}))
    return EXIT_RAN


if __name__ == "__main__":
    sys.exit(main())
