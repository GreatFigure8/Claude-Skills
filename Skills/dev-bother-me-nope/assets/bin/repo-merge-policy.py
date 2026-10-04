#!/usr/bin/env python3
"""repo-merge-policy.py — GitHub repo: no squash merges, delete the head branch on merge.

Purpose:
  Set allow_squash_merge=false and delete_branch_on_merge=true on a GitHub repository through the
  gh CLI (and allow_merge_commit=true when it was off, because GitHub needs one merge method and
  merge commits are how history is kept), then read the values back to confirm them.
  allow_rebase_merge is never touched.

Contract:
  repo-merge-policy.py [--repo-path <dir>] [--repo OWNER/NAME] [--dry-run]
  stdout, one JSON object:
    {"repo": "OWNER/NAME" or null,
     "status": "changed" | "already-set" | "dry-run" | "skipped" | "failed",
     "changes": {"<field>": {"old": <bool>, "new": <bool>}}, "reason": null or "..."}
  "changes" holds what was applied (changed) or would be (dry-run), else {}.
  Exit 0 in every non-usage case: a missing or unauthenticated gh, a missing GitHub repo, missing
  admin rights, a rejected change or an unconfirmed read-back are recorded, never blocking.
  Exit 2 = usage error, stdout {"error": "..."}.

Safety:
  --repo must match OWNER/NAME (a "." or ".." part is refused) before any gh call. Without --repo
  the name comes from `gh repo view` run in --repo-path, and anything that is not OWNER/NAME is
  skipped. gh output is validated, never trusted: bad JSON, a missing field or a wrong type is
  "skipped", never a traceback. gh runs as an argument list, never through a shell, with prompts
  disabled and a timeout. The change is one typed PATCH carrying only the fields that differ, and
  the failure reason is gh's first error line with tokens and Authorization headers redacted.
  `gh auth status` output is never echoed.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass

REPO_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
DOT_PARTS = frozenset({".", ".."})
GH_TIMEOUT_S = 60
EXIT_OK = 0
EXIT_USAGE = 2
WANTED = (("allow_squash_merge", False), ("delete_branch_on_merge", True))
MERGE_COMMIT = "allow_merge_commit"
BOOLEAN_FIELDS = ("allow_squash_merge", "delete_branch_on_merge", MERGE_COMMIT)
SECRET_PATTERNS = (
    re.compile(r"authorization:[^\n]*", re.IGNORECASE),
    re.compile(r"gh[pousr]_[A-Za-z0-9_]+"),
    re.compile(r"github_pat_[A-Za-z0-9_]+"),
    re.compile(r"\b(?:token|bearer)\s+\S{12,}", re.IGNORECASE),
)


class UsageError(Exception):
    """Bad command line; its message becomes {"error": ...} and the exit code is 2."""


class BadResponse(Exception):
    """gh returned something other than the repository JSON the policy needs."""


class Stop(Exception):
    """Ends the run early with a status and a reason."""

    status = "skipped"


class Skipped(Stop):
    status = "skipped"


class Failed(Stop):
    status = "failed"


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(f"usage: {message}")


@dataclass(frozen=True)
class Options:
    repo: str | None
    repo_path: str
    dry_run: bool


@dataclass(frozen=True)
class GhResult:
    code: int
    out: str
    err: str

    @property
    def ok(self):
        return self.code == 0

    @property
    def reason(self):
        return first_error_line(self.err or self.out)


@dataclass(frozen=True)
class Settings:
    allow_squash_merge: bool
    delete_branch_on_merge: bool
    allow_merge_commit: bool
    admin: bool


@dataclass(frozen=True)
class Change:
    field: str
    old: bool
    new: bool


@dataclass(frozen=True)
class Outcome:
    repo: str | None
    status: str
    changes: tuple
    reason: str | None


def valid_repo(name):
    if not REPO_PATTERN.match(name):
        return False
    return not DOT_PARTS & set(name.split("/"))


def parse_args(argv):
    parser = JsonArgumentParser(prog="repo-merge-policy.py", allow_abbrev=False,
                                description="No squash merges; delete head branches on merge.")
    parser.add_argument("--repo", help="OWNER/NAME; default: asked from gh in --repo-path")
    parser.add_argument("--repo-path", default=".", help="directory inside the repository")
    parser.add_argument("--dry-run", action="store_true", help="print the plan, change nothing")
    args = parser.parse_args(argv)
    if args.repo is not None and not valid_repo(args.repo):
        raise UsageError(f"usage: --repo must be OWNER/NAME, got {args.repo!r}")
    repo_path = os.path.abspath(args.repo_path)
    if not os.path.isdir(repo_path):
        raise UsageError(f"usage: --repo-path is not a directory: {args.repo_path!r}")
    return Options(args.repo, repo_path, args.dry_run)


def redact(line):
    for pattern in SECRET_PATTERNS:
        line = pattern.sub("[redacted]", line)
    return line


def first_error_line(text):
    for line in text.splitlines():
        if line.strip():
            return redact(line.strip())
    return "gh failed with no output"


def run_gh(*args, cwd=None):
    """Run `gh args`; never raises, a timeout or a missing gh is a non-zero result."""
    env = {**os.environ, "GH_PROMPT_DISABLED": "1", "GH_NO_UPDATE_NOTIFIER": "1"}
    try:
        proc = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8",
                              errors="replace", env=env, cwd=cwd, timeout=GH_TIMEOUT_S,
                              check=False)
    except subprocess.TimeoutExpired:
        return GhResult(124, "", f"gh timed out after {GH_TIMEOUT_S}s")
    except OSError as exc:
        return GhResult(127, "", f"cannot run gh: {exc}")
    return GhResult(proc.returncode, proc.stdout, proc.stderr)


def require_gh():
    if shutil.which("gh") is None:
        raise Skipped("gh CLI not found on PATH")
    if not run_gh("auth", "status").ok:  # its output may name accounts or tokens: never echoed
        raise Skipped("gh is not authenticated")


def resolve_repo(options):
    result = run_gh("repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner",
                    cwd=options.repo_path)
    if not result.ok:
        raise Skipped(f"no GitHub repository at {options.repo_path}: {result.reason}")
    name = result.out.strip()
    if not valid_repo(name):
        raise Skipped("gh repo view returned no valid nameWithOwner")
    return name


def parse_settings(text):
    """Validate the `gh api repos/O/N` JSON; BadResponse names the first problem."""
    try:
        data = json.loads(text)
    except ValueError:
        raise BadResponse("not valid JSON") from None
    if not isinstance(data, dict):
        raise BadResponse("not a JSON object")
    for field in BOOLEAN_FIELDS:
        if not isinstance(data.get(field), bool):
            raise BadResponse(f"{field} is not a boolean")
    permissions = data.get("permissions")
    admin = permissions.get("admin") if isinstance(permissions, dict) else None
    if not isinstance(admin, bool):
        raise BadResponse("permissions.admin is not a boolean")
    return Settings(data["allow_squash_merge"], data["delete_branch_on_merge"],
                    data[MERGE_COMMIT], admin)


def read_settings(repo):
    result = run_gh("api", f"repos/{repo}")
    if not result.ok:
        raise Skipped(f"cannot read {repo}: {result.reason}")
    try:
        return parse_settings(result.out)
    except BadResponse as exc:
        raise Skipped(f"unexpected gh api response: {exc}") from None


def plan_changes(current):
    """The changes that bring `current` to the policy, in a fixed order; rebase is never listed."""
    changes = tuple(Change(field, getattr(current, field), want) for field, want in WANTED
                    if getattr(current, field) != want)
    if not current.allow_merge_commit:
        changes += (Change(MERGE_COMMIT, False, True),)
    return changes


def send_patch(repo, changes):
    fields = [part for change in changes
              for part in ("-F", f"{change.field}={'true' if change.new else 'false'}")]
    result = run_gh("api", "-X", "PATCH", f"repos/{repo}", *fields)
    if not result.ok:
        raise Failed(result.reason)


def confirm(repo, changes):
    result = run_gh("api", f"repos/{repo}")
    if not result.ok:
        raise Failed(f"read-back failed: {result.reason}")
    try:
        after = parse_settings(result.out)
    except BadResponse as exc:
        raise Failed(f"read-back returned an unexpected response: {exc}") from None
    for change in changes:
        shown = getattr(after, change.field)
        if shown != change.new:
            raise Failed(f"read-back still shows {change.field}={str(shown).lower()}")


def apply_policy(repo, options):
    current = read_settings(repo)
    changes = plan_changes(current)
    if not changes:
        return Outcome(repo, "already-set", (), None)
    if not current.admin:
        raise Skipped(f"missing admin rights on {repo}")
    if options.dry_run:
        return Outcome(repo, "dry-run", changes, None)
    send_patch(repo, changes)
    confirm(repo, changes)
    return Outcome(repo, "changed", changes, None)


def run(options):
    repo = options.repo
    try:
        require_gh()
        repo = repo or resolve_repo(options)
        return apply_policy(repo, options)
    except Stop as stop:
        return Outcome(repo, stop.status, (), str(stop))
    except (ValueError, KeyError, TypeError) as exc:
        return Outcome(repo, "skipped", (), f"unexpected gh api response: {exc}")


def to_json(outcome):
    return {"repo": outcome.repo, "status": outcome.status,
            "changes": {c.field: {"old": c.old, "new": c.new} for c in outcome.changes},
            "reason": outcome.reason}


def main(argv=None):
    try:
        options = parse_args(sys.argv[1:] if argv is None else argv)
    except UsageError as exc:
        print(json.dumps({"error": str(exc)}))
        return EXIT_USAGE
    print(json.dumps(to_json(run(options))))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
