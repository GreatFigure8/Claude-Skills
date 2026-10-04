#!/usr/bin/env python3
"""merged-branch-cleanup.py — delete one merged branch, every worktree holding it, local and remote.

Purpose:
  Once a branch is merged, remove every linked worktree that has it checked out, delete the local
  branch and delete its copy on the remote, but only after git proves the branch's commits are in
  --target. Anything it cannot prove or cannot safely remove is kept and reported in "left".

Contract:
  merged-branch-cleanup.py --repo <path> --branch <name> --target <ref>
                           [--remote origin] [--no-fetch] [--dry-run]
  stdout, one JSON object:
    {"branch": ..., "target": ..., "dry_run": false, "deleted": [...], "left": [{"ref", "why"}]}
  A ref is "worktree:<abs path>", "local:<branch>" or "<remote>:<branch>".
  Exit 0 = it ran (inspect "left"). Exit 2 = refused or usage error: stdout is {"error": "..."}
  and nothing was changed. --dry-run changes nothing (no fetch, no prune) and prints the plan.

Safety:
  Refuses protected names (main, master, dev, develop, prod, production, release, staging, any
  case), the remote's default branch, the target's own branch, option-like or malformed names and
  a repo that is not a work tree. Ancestry is proved with `merge-base --is-ancestor` before any
  delete. Never uses --force, never unlocks, and never removes or switches the main checkout;
  dirty, locked and main-checkout worktrees are kept. Deletes are compare-and-swap on the checked
  SHA (`update-ref -d <ref> <sha>`, `push --force-with-lease=<ref>:<sha> --delete`), so a branch
  that moved after the check is kept. Every git call is an argument list run as `git -C <path>`;
  checkout, switch, reset, stash, merge, rebase and pull are never run.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass

PROTECTED = frozenset({"main", "master", "dev", "develop", "prod", "production", "release",
                       "staging"})
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


@dataclass(frozen=True)
class Options:
    repo: str
    branch: str
    target: str
    remote: str
    fetch: bool
    dry_run: bool


@dataclass(frozen=True)
class GitResult:
    code: int
    out: str
    err: str

    @property
    def ok(self):
        return self.code == 0

    @property
    def text(self):
        return self.out.strip()

    @property
    def reason(self):
        return failure_line(self.err or self.out)


@dataclass(frozen=True)
class Worktree:
    path: str
    branch: str | None
    is_main: bool
    locked: str | None
    prunable: bool


@dataclass(frozen=True)
class Holder:
    worktree: Worktree
    dirty: tuple


@dataclass(frozen=True)
class Copy:
    sha: str | None
    merged: bool
    problem: str


@dataclass(frozen=True)
class Survey:
    branch: str
    target: str
    remote: str
    main_path: str
    local: Copy
    remote_copy: Copy
    fetch_error: str | None
    holders: tuple


@dataclass(frozen=True)
class Left:
    ref: str
    why: str


@dataclass(frozen=True)
class Plan:
    remove: tuple
    delete_local: bool
    delete_remote: bool
    left: tuple


# --- arguments and git plumbing ---------------------------------------------------------------


def parse_args(argv):
    parser = JsonArgumentParser(prog="merged-branch-cleanup.py", allow_abbrev=False,
                                description="Delete a merged branch and every worktree holding it.")
    parser.add_argument("--repo", required=True, help="path of the repository (any worktree)")
    parser.add_argument("--branch", required=True, help="branch to delete")
    parser.add_argument("--target", required=True, help="ref the branch must be merged into")
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


def run_git(cwd, *args, timeout=GIT_READ_TIMEOUT_S):
    """Run `git -C cwd args`; never raises, a timeout or a missing git is a non-zero result."""
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    try:
        proc = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True,
                              encoding="utf-8", errors="replace", env=env, timeout=timeout,
                              check=False)
    except subprocess.TimeoutExpired:
        return GitResult(124, "", f"git {args[0]} timed out after {timeout}s")
    except OSError as exc:
        return GitResult(127, "", f"cannot run git: {exc}")
    return GitResult(proc.returncode, proc.stdout, proc.stderr)


def short_branch(full_ref):
    """`refs/heads/x` and `refs/remotes/<remote>/x` both give `x`; anything else is unchanged."""
    if full_ref.startswith(HEADS):
        return full_ref[len(HEADS):]
    if full_ref.startswith(REMOTES):
        return full_ref[len(REMOTES):].partition("/")[2]
    return full_ref


def strip_remote(name, remote):
    for prefix in (f"{REMOTES}{remote}/", f"{remote}/", HEADS):
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def resolve_commit(repo, ref):
    result = run_git(repo, "rev-parse", "--verify", "--quiet", "--end-of-options",
                     f"{ref}^{{commit}}")
    return result.text if result.ok and result.text else None


# --- refusals: static checks first, then read-only git ----------------------------------------


def refuse_static(opts):
    name = opts.branch
    if not name or name.startswith(("-", "refs/")):
        raise Refusal(f"invalid branch name: {name!r}")
    if name.casefold() in PROTECTED:
        raise Refusal(f"branch {name!r} is protected and is never deleted")
    for label, value in (("--remote", opts.remote), ("--target", opts.target)):
        if not value or value.startswith("-"):
            raise Refusal(f"invalid {label} value: {value!r}")


def require_work_tree(repo):
    result = run_git(repo, "rev-parse", "--is-inside-work-tree")
    if not (result.ok and result.text == "true"):
        raise Refusal(f"{repo} is not a git work tree")


def require_branch_name(repo, branch):
    result = run_git(repo, "check-ref-format", "--branch", branch)
    if not result.ok or result.text != branch:  # `@{-1}` and friends expand to another name
        raise Refusal(f"invalid branch name: {branch!r}")


def require_remote(repo, remote):
    result = run_git(repo, "remote")
    if not result.ok or remote not in result.out.split():
        raise Refusal(f"remote {remote!r} is not configured in {repo}")


def refuse_default_branch(opts):
    head = run_git(opts.repo, "symbolic-ref", "--quiet", "--short",
                   f"{REMOTES}{opts.remote}/HEAD")
    default = strip_remote(head.text, opts.remote) if head.ok else ""
    if default and default.casefold() == opts.branch.casefold():
        raise Refusal(f"{opts.branch!r} is the default branch of {opts.remote}")


def target_branch_names(opts):
    full = run_git(opts.repo, "rev-parse", "--symbolic-full-name", opts.target).text
    names = {strip_remote(opts.target, opts.remote), short_branch(full)}
    return {name.casefold() for name in names if name}


def validate(opts):
    """Raise Refusal unless the request is safe to act on."""
    refuse_static(opts)
    require_work_tree(opts.repo)
    require_branch_name(opts.repo, opts.branch)
    require_remote(opts.repo, opts.remote)
    refuse_default_branch(opts)
    if resolve_commit(opts.repo, opts.target) is None:
        raise Refusal(f"--target {opts.target!r} does not resolve to a commit")
    if opts.branch.casefold() in target_branch_names(opts):
        raise Refusal(f"{opts.branch!r} is the target's own branch; it cannot be merged into itself")


# --- survey: read what exists ------------------------------------------------------------------


def worktree_from_fields(fields, is_main):
    path, branch, locked, prunable = "", None, None, False
    for field in fields:
        key, _, value = field.partition(" ")
        if key == "worktree":
            path = value
        elif key == "branch":
            branch = short_branch(value)
        elif key == "locked":
            locked = value
        elif key == "prunable":
            prunable = True
    return Worktree(path, branch, is_main, locked, prunable)


def parse_worktrees(text):
    """Parse `git worktree list --porcelain -z`; the first entry is the main checkout."""
    entries, current = [], []
    for field in text.split("\0"):
        if field:
            current.append(field)
        elif current:
            entries.append(current)
            current = []
    if current:
        entries.append(current)
    return tuple(worktree_from_fields(fields, index == 0) for index, fields in enumerate(entries))


def list_worktrees(repo):
    result = run_git(repo, "worktree", "list", "--porcelain", "-z")
    if not result.ok:
        raise Refusal(f"cannot list worktrees, so nothing was deleted: {result.reason}")
    return parse_worktrees(result.out)


def check_copy(repo, ref, target_sha):
    """Does `ref` exist, and is its tip proven to be an ancestor of the target?"""
    tip = resolve_commit(repo, ref)
    if tip is None:
        return Copy(None, False, "")
    verdict = run_git(repo, "merge-base", "--is-ancestor", tip, target_sha)
    if verdict.code in (0, 1):
        return Copy(tip, verdict.code == 0, "")
    return Copy(tip, False, f"could not prove merged: {verdict.reason}")


def dirty_paths(worktree):
    """Porcelain status lines; a failing status counts as dirty because clean cannot be proved."""
    status = run_git(worktree.path, "status", "--porcelain")
    if not status.ok:
        return (f"status failed: {status.reason}",)
    return tuple(line for line in status.out.splitlines() if line)


def find_holders(branch, worktrees):
    held = [wt for wt in worktrees if wt.branch == branch and not wt.prunable]
    return tuple(
        Holder(wt, () if wt.is_main or wt.locked is not None else dirty_paths(wt)) for wt in held
    )


def fetch_remote(opts):
    if opts.dry_run or not opts.fetch:
        return None
    result = run_git(opts.repo, "fetch", "--prune", opts.remote, timeout=GIT_NETWORK_TIMEOUT_S)
    return None if result.ok else result.reason


def survey(opts):
    fetch_error = fetch_remote(opts)
    if not opts.dry_run:
        run_git(opts.repo, "worktree", "prune")
    target_sha = resolve_commit(opts.repo, opts.target)
    if target_sha is None:
        raise Refusal(f"--target {opts.target!r} no longer resolves to a commit")
    worktrees = list_worktrees(opts.repo)
    return Survey(
        branch=opts.branch, target=opts.target, remote=opts.remote, main_path=worktrees[0].path,
        local=check_copy(opts.repo, f"{HEADS}{opts.branch}", target_sha),
        remote_copy=check_copy(opts.repo, f"{REMOTES}{opts.remote}/{opts.branch}", target_sha),
        fetch_error=fetch_error, holders=find_holders(opts.branch, worktrees),
    )


# --- plan: pure, decides what is deleted and what is left -------------------------------------


def not_merged_why(survey_, copy):
    return copy.problem or f"not merged into {survey_.target}"


def plan_unmerged(s):
    why = not_merged_why(s, s.local)
    held = tuple(Left(f"worktree:{h.worktree.path}", why) for h in s.holders)
    left = held + (Left(f"local:{s.branch}", why),)
    if s.remote_copy.sha is not None:
        remote_why = (f"kept with unmerged local:{s.branch}" if s.remote_copy.merged
                      else not_merged_why(s, s.remote_copy))
        left += (Left(f"{s.remote}:{s.branch}", remote_why),)
    return Plan((), False, False, left)


def blocker(holder):
    """Why this worktree cannot be removed, or None when it can."""
    wt = holder.worktree
    if wt.is_main:
        return "main checkout is never removed or switched"
    if wt.locked is not None:
        return f"locked: {wt.locked or 'no reason given'}; never unlocked"
    if holder.dirty:
        return f"uncommitted changes ({len(holder.dirty)} paths, e.g. {holder.dirty[0]}); never forced"
    return None


def holder_why(blocked):
    if any(h.worktree.is_main for h in blocked):
        return "checked out in the main checkout"
    return "checked out in worktree " + ", ".join(h.worktree.path for h in blocked)


def plan_local(s, blocked):
    if s.local.sha is None:
        return (), False
    if not blocked:
        return (), True
    return (Left(f"local:{s.branch}", holder_why(blocked)),), False


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


# --- execute: every mutating call runs as `git -C <main checkout>` ----------------------------


def remove_worktrees(main, paths):
    deleted, left = (), ()
    for path in paths:
        result = run_git(main, "worktree", "remove", path)
        if result.ok:
            deleted += (f"worktree:{path}",)
        else:
            left += (Left(f"worktree:{path}", result.reason),)
    return deleted, left


def delete_local_branch(main, branch, sha):
    result = run_git(main, "update-ref", "-d", f"{HEADS}{branch}", sha)
    if not result.ok:
        return (), (Left(f"local:{branch}", result.reason),)
    run_git(main, "config", "--remove-section", f"branch.{branch}")  # best effort, may not exist
    return (f"local:{branch}",), ()


def delete_remote_branch(main, remote, branch, sha):
    ref = f"{HEADS}{branch}"
    result = run_git(main, "push", remote, "--delete", f"--force-with-lease={ref}:{sha}", ref,
                     timeout=GIT_NETWORK_TIMEOUT_S)
    if not result.ok:
        return (), (Left(f"{remote}:{branch}", result.reason),)
    return (f"{remote}:{branch}",), ()


def planned_deletions(s, plan):
    paths = tuple(f"worktree:{path}" for path in plan.remove)
    local = (f"local:{s.branch}",) if plan.delete_local else ()
    remote = (f"{s.remote}:{s.branch}",) if plan.delete_remote else ()
    return paths + local + remote


def execute(s, plan):
    deleted, left = remove_worktrees(s.main_path, plan.remove)
    if plan.delete_local and left:
        stuck = left[0].ref.partition(":")[2]
        left += (Left(f"local:{s.branch}", f"worktree not removed: {stuck}"),)
    elif plan.delete_local:
        done, failed = delete_local_branch(s.main_path, s.branch, s.local.sha)
        deleted, left = deleted + done, left + failed
    if plan.delete_remote:
        done, failed = delete_remote_branch(s.main_path, s.remote, s.branch, s.remote_copy.sha)
        deleted, left = deleted + done, left + failed
    return deleted, plan.left + left


def report(opts, deleted, left):
    return {"branch": opts.branch, "target": opts.target, "dry_run": opts.dry_run,
            "deleted": list(deleted),
            "left": [{"ref": item.ref, "why": item.why} for item in left]}


def main(argv=None):
    try:
        opts = parse_args(sys.argv[1:] if argv is None else argv)
        validate(opts)
        found = survey(opts)
        plan = plan_cleanup(found)
        if opts.dry_run:
            deleted, left = planned_deletions(found, plan), plan.left
        else:
            deleted, left = execute(found, plan)
    except Refusal as refusal:
        print(json.dumps({"error": str(refusal)}))
        return EXIT_REFUSED
    print(json.dumps(report(opts, deleted, left)))
    return EXIT_RAN


if __name__ == "__main__":
    sys.exit(main())
