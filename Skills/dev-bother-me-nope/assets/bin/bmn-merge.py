#!/usr/bin/env python3
"""bmn-merge.py — merge a step's branches into the sprint branch, gate once, push, clean up, merge to dev.

Purpose:
  The end of every CODE wave and FIX round is a fixed sequence of git commands, so it runs as
  this helper instead of a merger agent. An agent is dispatched only for what needs judgement:
  a merge conflict, a gate that stays red, or a file that looks like a secret.

Contract:
  bmn-merge.py --worktree <run worktree> --integration <sprint branch> --branch <b> [--branch ...]
               [--evidence <b>]... [--gate "<shell command>"]... [--to-dev] [--dev-worktree <path>]
               [--dev-title "<conventional title>"] [--remote origin] [--dev dev] [--no-cleanup]
  Branches merge in the order given (deps first), then evidence branches, each as
  `git merge --no-ff <remote>/<branch>`; with --to-dev, <remote>/<dev> is merged in last. Every
  --gate then runs ONCE, in order, through `bash -c` in the worktree. A red gate reverts the
  newest branch merge (`git revert -m 1`) and re-runs, until green or nothing is left to revert.
  Then: push the sprint branch, run merged-branch-cleanup.py for each branch still merged, and
  with --to-dev merge the sprint branch into <dev> in a detached worktree and push HEAD:<dev>.
  stdout, one JSON object: {"integration", "merged": [{"branch", "tip", "merge"}],
    "reverted": [{"branch", "gate", "output"}], "gates": [{"gate", "ok"}], "pushed",
    "dev_merge": "<sha>|skipped", "deleted": [...], "left": [{"ref", "why"}],
    "needs_agent": null | {"why", "branch", "remaining": [...], "output"}}
  Exit 0 = done. Exit 3 = stopped for an agent: "needs_agent" says why; merges made before the
  stop stay as local commits in the worktree, nothing after the stop ran. Exit 2 = refused or
  usage error: stdout {"error": "..."}, nothing changed.

Safety:
  Refuses unless --worktree has --integration checked out and no uncommitted tracked change,
  and refuses protected sprint-branch names (main master dev develop prod production release
  staging). Merge commits only: never --squash, never a fast-forward of a branch merge, never
  --force on any push, never a checkout, switch, reset, stash or rebase of the worktree (the one
  pull is --rebase=merges, which keeps commits made there by hand). Never touches main. A
  conflicting merge is aborted, not resolved. Nothing is pushed while a gate is red or while an
  added file looks like a secret (.env, *.pem, *.key, id_rsa). Git runs as an argument list.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROTECTED = frozenset({"main", "master", "dev", "develop", "prod", "production", "release", "staging"})
SECRET_PATTERNS = (".env", ".env.*", "*.pem", "*.key", "id_rsa", "id_ed25519")
SECRET_ALLOWED = (".env.example", ".env.sample", ".env.template", ".env.test.example")
GIT_TIMEOUT_S = 300
GATE_TIMEOUT_S = 3600
OUTPUT_TAIL_LINES = 20
EXIT_DONE = 0
EXIT_REFUSED = 2
EXIT_NEEDS_AGENT = 3


class Refusal(Exception):
    """A request the script will not act on; its message becomes {"error": ...}."""


class NeedsAgent(Exception):
    """A stop that needs judgement; carries the fields of "needs_agent"."""

    def __init__(self, why, branch=None, output=""):
        super().__init__(why)
        self.detail = {"why": why, "branch": branch, "output": tail(output)}


def tail(text: str) -> str:
    return "\n".join((text or "").strip().splitlines()[-OUTPUT_TAIL_LINES:])


def git(path, *args, check=True):
    done = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=GIT_TIMEOUT_S, check=False)
    if check and done.returncode != 0:
        raise NeedsAgent(f"git {' '.join(args[:3])} failed", output=done.stdout + done.stderr)
    return done


def ref_exists(path, ref) -> bool:
    return git(path, "rev-parse", "--verify", "--quiet", ref, check=False).returncode == 0


def sha(path, ref) -> str:
    return git(path, "rev-parse", ref).stdout.strip()


def check_start(args) -> None:
    worktree = Path(args.worktree)
    if not worktree.is_dir():
        raise Refusal(f"--worktree {args.worktree} is not a directory")
    if args.integration.lower() in PROTECTED:
        raise Refusal(f"--integration {args.integration} is a protected branch")
    current = git(worktree, "branch", "--show-current", check=False).stdout.strip()
    if current != args.integration:
        raise Refusal(f"{args.worktree} has {current or 'no branch'} checked out, not {args.integration}")
    dirty = git(worktree, "status", "--porcelain", "--untracked-files=no", check=False).stdout.strip()
    if dirty:
        raise Refusal("the run worktree has uncommitted tracked changes; a merger agent must handle this step")
    if args.to_dev and not args.dev_worktree:
        raise Refusal("--to-dev needs --dev-worktree")
    if not args.branch and not args.evidence and not args.to_dev:
        raise Refusal("nothing to merge: give --branch, --evidence or --to-dev")


def sync(args) -> None:
    fetched = git(args.worktree, "fetch", "--prune", args.remote, check=False)
    if fetched.returncode != 0:
        raise Refusal(f"git fetch failed: {tail(fetched.stderr)}")
    if ref_exists(args.worktree, f"refs/remotes/{args.remote}/{args.integration}"):
        pulled = git(args.worktree, "pull", "--rebase=merges", args.remote, args.integration, check=False)
        if pulled.returncode != 0:
            git(args.worktree, "rebase", "--abort", check=False)
            raise NeedsAgent("pull --rebase=merges of the sprint branch failed",
                             output=pulled.stdout + pulled.stderr)


def merge_one(args, branch: str, message: str) -> dict:
    ref = f"{args.remote}/{branch}"
    if not ref_exists(args.worktree, f"refs/remotes/{ref}"):
        raise NeedsAgent(f"{ref} does not exist", branch=branch)
    tip = sha(args.worktree, ref)
    done = git(args.worktree, "merge", "--no-ff", "--no-edit", "-m", message, ref, check=False)
    if done.returncode != 0:
        git(args.worktree, "merge", "--abort", check=False)
        raise NeedsAgent("merge conflict", branch=branch, output=done.stdout + done.stderr)
    return {"branch": branch, "tip": tip, "merge": sha(args.worktree, "HEAD")}


def merge_all(args, result: dict) -> None:
    queue = list(args.branch) + list(args.evidence)
    for index, branch in enumerate(queue):
        try:
            result["merged"].append(merge_one(args, branch, f"merge: {branch} into {args.integration}"))
        except NeedsAgent as stop:
            stop.detail["remaining"] = queue[index:]
            raise
    if args.to_dev and ref_exists(args.worktree, f"refs/remotes/{args.remote}/{args.dev}"):
        merge_one(args, args.dev, f"merge: {args.dev} into {args.integration}")


def run_gate(args, gate: str):
    shell = shutil.which("bash") or shutil.which("sh")
    if shell is None:
        raise NeedsAgent("no bash or sh on PATH to run the gates")
    try:
        done = subprocess.run([shell, "-c", gate], cwd=args.worktree, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=GATE_TIMEOUT_S, check=False)
    except subprocess.TimeoutExpired:
        return False, f"gate timed out after {GATE_TIMEOUT_S} s"
    return done.returncode == 0, done.stdout + done.stderr


def first_red(args):
    """Run every gate in order; return (gate, output) for the first red one, or None."""
    for gate in args.gate:
        ok, output = run_gate(args, gate)
        if not ok:
            return gate, output
    return None


def gate_until_green(args, result: dict) -> None:
    """Gates once; while red, revert the newest branch merge and re-run."""
    red = first_red(args)
    while red is not None:
        gate, output = red
        if not result["merged"]:
            result["gates"] = [{"gate": gate, "ok": False}]
            raise NeedsAgent("gates are red with every branch merge reverted", output=output)
        newest = result["merged"].pop()
        git(args.worktree, "revert", "-m", "1", "--no-edit", newest["merge"])
        result["reverted"].append({"branch": newest["branch"], "gate": gate, "output": tail(output)})
        red = first_red(args)
    result["gates"] = [{"gate": gate, "ok": True} for gate in args.gate]


def looks_secret(path: str) -> bool:
    name = path.rsplit("/", 1)[-1]
    if name in SECRET_ALLOWED:
        return False
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in SECRET_PATTERNS)


def audit(args, base: str) -> None:
    added = git(args.worktree, "diff", "--name-only", "--diff-filter=A", base, "HEAD").stdout.split("\n")
    secrets = sorted(path for path in added if path and looks_secret(path))
    if secrets:
        raise NeedsAgent("the merges add files that look like secrets", output="\n".join(secrets))


def push_integration(args, result: dict) -> None:
    git(args.worktree, "push", args.remote, f"HEAD:refs/heads/{args.integration}")
    git(args.worktree, "fetch", args.remote, check=False)
    result["pushed"] = True


def cleanup(args, result: dict) -> None:
    helper = Path(__file__).resolve().parent / "merged-branch-cleanup.py"
    target = f"{args.remote}/{args.integration}"
    for item in result["merged"]:
        done = subprocess.run([sys.executable, str(helper), "--repo", str(args.worktree), "--branch",
                               item["branch"], "--target", target, "--remote", args.remote],
                              capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=GIT_TIMEOUT_S, check=False)
        try:
            report = json.loads(done.stdout)
        except ValueError:
            report = {"error": tail(done.stdout + done.stderr) or "no output"}
        result["deleted"].extend(report.get("deleted", []))
        result["left"].extend(report.get("left", []))
        if "error" in report:
            result["left"].append({"ref": item["branch"], "why": report["error"]})


def merge_to_dev(args, result: dict) -> None:
    """Merge the sprint branch into dev in a detached worktree; dev is never checked out anywhere."""
    dev_ref = f"refs/remotes/{args.remote}/{args.dev}"
    if not ref_exists(args.worktree, dev_ref):
        raise NeedsAgent(f"{args.remote}/{args.dev} does not exist")
    title = args.dev_title or f"merge: {args.integration} into {args.dev}"
    git(args.worktree, "worktree", "add", "--detach", args.dev_worktree, f"{args.remote}/{args.dev}")
    try:
        git(args.dev_worktree, "merge", "--no-ff", "--no-edit", "-m", title, args.integration)
        git(args.dev_worktree, "push", args.remote, f"HEAD:refs/heads/{args.dev}")
        result["dev_merge"] = sha(args.dev_worktree, "HEAD")
    finally:
        git(args.dev_worktree, "merge", "--abort", check=False)
        gone =git(args.worktree, "worktree", "remove", args.dev_worktree, check=False)
        if gone.returncode != 0:
            result["left"].append({"ref": f"worktree:{args.dev_worktree}", "why": tail(gone.stderr)})


def run(args) -> dict:
    result = {"integration": args.integration, "merged": [], "reverted": [], "gates": [],
              "pushed": False, "dev_merge": "skipped", "deleted": [], "left": [], "needs_agent": None}
    check_start(args)
    try:
        sync(args)
        base = sha(args.worktree, "HEAD")
        merge_all(args, result)
        gate_until_green(args, result)
        audit(args, base)
        push_integration(args, result)
        if not args.no_cleanup:
            cleanup(args, result)
        if args.to_dev:
            merge_to_dev(args, result)
    except NeedsAgent as stop:
        result["needs_agent"] = {"remaining": [], **stop.detail}
    return result


def parse(argv):
    parser = argparse.ArgumentParser(prog="bmn-merge.py")
    parser.add_argument("--worktree", required=True)
    parser.add_argument("--integration", required=True)
    parser.add_argument("--branch", action="append", default=[])
    parser.add_argument("--evidence", action="append", default=[])
    parser.add_argument("--gate", action="append", default=[])
    parser.add_argument("--to-dev", action="store_true")
    parser.add_argument("--dev-worktree")
    parser.add_argument("--dev-title")
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--dev", default="dev")
    parser.add_argument("--no-cleanup", action="store_true")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse(argv)
    try:
        result = run(args)
    except Refusal as refusal:
        print(json.dumps({"error": str(refusal)}))
        return EXIT_REFUSED
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return EXIT_NEEDS_AGENT if result["needs_agent"] else EXIT_DONE


if __name__ == "__main__":
    sys.exit(main())
