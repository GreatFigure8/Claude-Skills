#!/usr/bin/env python3
"""deploy-guard.py — PreToolUse hook for dev-bother-me-nope.

Blocks (exit 2, reason on stderr) any Vercel deploy, any push to a production branch, and any
change to a remote Supabase database, unless the Bash segment is prefixed with
BMN_USER_APPROVED_DEPLOY=1 (set only when Jonathan said "deploy" in chat). One exception:
`supabase db push` / `migration up` may target the Supabase DEV project named in the repo's
.claude/bmn.config.json — never MAIN. Anything it cannot parse is allowed — this is an
accident guard, not a sandbox.

Two more rule families are checked before that approval pass-through, so the prefix is a
deploy-only pass-through that never lifts either of them. The merge guard keeps history: it
blocks every squash merge (`git merge|pull --squash`, `gh pr merge --squash`/`-s`, `gh api` with
merge_method=squash, the GitHub MCP `merge_pull_request` with merge_method=squash) and every
`gh pr merge` that omits --delete-branch (a merged PR's source branch is deleted). Merge commits
only: `git merge --no-ff`, `gh pr merge <n> --merge --delete-branch`. The branch guard keeps the
integration branches: `git push --delete`/`:ref` never removes a protected branch (main master
prod production release dev develop staging, or the remote's default branch; `heads/dev` is
`refs/heads/dev` to git), approved deploy or not; if one should go, Jonathan deletes it himself.
DELETE_PROTECTED is held equal to merged-branch-cleanup.py's PROTECTED by
test_protected_branch_parity.py. Branch cleanup (`git push origin --delete <wip or sprint branch>`,
`git branch -D`, `git worktree remove|prune`) is never blocked. Wrappers that take options or
values (`timeout 60`, `sudo -u me`, `nice -n 5`, `env -u X`, `xargs -n1`, `xargs --replace`) and
shell command strings (`sh -ec '…'`, `fish --command '…'`, `fish -C '…'`) are unwrapped before
matching.

Shipped as a plugin hook, so it fires in every session; it only acts inside a git repo with a
dev-bother-me-nope run in progress (docs/sprints/bmn-*/bmn.json whose phase isn't done,
blocked or decision), checked in every worktree of the repo — the run's state lives in its sibling run
worktree, not in the human's main checkout.
Rules and rationale: ../../references/deploy-guards.md
"""
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path
from types import MappingProxyType
from typing import NamedTuple

APPROVAL_VAR = "BMN_USER_APPROVED_DEPLOY"
PROTECTED_BRANCHES = frozenset({"main", "master", "prod", "production", "release"})
# Never deleted on origin: the production names plus merged-branch-cleanup.py's integration names.
DELETE_PROTECTED = PROTECTED_BRANCHES | frozenset({"dev", "develop", "staging"})

SEPARATOR_CHARS = frozenset(";&|()\n")
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n[ \t]*\2[ \t]*(?=\n|$)", re.DOTALL)
WHICH_SUBST = re.compile(r"\$\(\s*(?:which|command\s+-v)\s+([\w.-]+)\s*\)|`\s*which\s+([\w.-]+)\s*`")
SHELLS = frozenset({"sh", "bash", "zsh", "dash", "ksh", "fish"})
SHELL_VALUE_FLAGS = frozenset({"-o", "+o", "-O", "+O", "--rcfile", "--init-file"})
COMMAND_LONG_FLAGS = frozenset({"--command"})  # fish's spelling of -c: the string follows or is `=`-joined
FISH_LONG_FLAGS = COMMAND_LONG_FLAGS | {"--init-command"}  # fish runs its `-C` strings before `-c`
FISH_INIT_SHORT = re.compile(r"-[^-cC]*C(.*)", re.DOTALL)  # fish's -C, bundled or not (noclobber in bash)
BRANCH_REF_PREFIX = re.compile(r"^(?:refs/)?heads/")
SIMPLE_WRAPPERS = frozenset({"env", "time", "nohup", "sudo", "command", "exec", "xargs",
                             "npx", "bunx", "nice", "timeout"})
DURATION_WRAPPERS = frozenset({"timeout"})
WRAPPER_VALUE_FLAGS = MappingProxyType({
    "sudo": frozenset({"-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-U", "-r", "-t",
                       "--user", "--group", "--host", "--prompt", "--close-from", "--chdir",
                       "--role", "--type", "--other-user", "--command-timeout"}),
    "timeout": frozenset({"-s", "--signal", "-k", "--kill-after"}),
    "nice": frozenset({"-n", "--adjustment"}),
    "env": frozenset({"-u", "--unset", "-C", "--chdir", "-S", "--split-string", "-P"}),
    # GNU `--replace`, `--max-lines` and `--eof` take a value only after `=` (optional_argument).
    "xargs": frozenset({"-n", "--max-args", "-P", "--max-procs", "-I", "-L", "-s", "--max-chars",
                        "-d", "--delimiter", "-E", "-a", "--arg-file",
                        "--process-slot-var", "-J", "-R", "-S"}),
    "time": frozenset({"-f", "--format", "-o", "--output"}),
    "exec": frozenset({"-a"}),
    "npx": frozenset({"-p", "--package"}),
})
TWO_WORD_WRAPPERS = frozenset({("uv", "run"), ("poetry", "run"), ("pipenv", "run"),
                               ("bun", "x"), ("pnpm", "dlx"), ("pnpm", "exec"),
                               ("yarn", "dlx"), ("yarn", "exec"), ("npm", "exec")})
PACKAGE_RUNNERS = frozenset({"yarn", "pnpm", "bun"})
GUARDED_PROGRAMS = frozenset({"vercel", "supabase"})

VERCEL_VALUE_FLAGS = frozenset({"--cwd", "--scope", "-S", "-A", "--local-config", "--token",
                                "-t", "--team", "-T", "--global-config", "-Q"})
VERCEL_SAFE = frozenset({"dev", "build", "pull", "ls", "list", "inspect", "logs", "whoami",
                         "link", "help", "login", "logout", "switch"})
VERCEL_SAFE_FLAGS = frozenset({"--version", "-v", "--help", "-h"})
VERCEL_GROUPS = frozenset({"env", "project", "projects", "domains", "dns", "certs", "alias",
                           "teams", "git"})
VERCEL_GROUP_READS = frozenset({"ls", "list", "inspect", "pull"})

SUPABASE_VALUE_FLAGS = frozenset({"--workdir", "--project-ref", "--db-url", "--profile",
                                  "-o", "--output", "--schema", "-s", "--password", "-p"})
REMOTE_TARGET_FLAGS = ("--linked", "--db-url")
SUPABASE_ALWAYS_BLOCKED = {
    ("db", "push"), ("functions", "deploy"), ("secrets", "set"), ("secrets", "unset"),
    ("config", "push"), ("migration", "repair"), ("branches", "create"),
    ("branches", "delete"), ("branches", "update"), ("projects", "create"),
    ("projects", "delete"),
}
SUPABASE_BLOCKED_WHEN_REMOTE = {("db", "reset"), ("migration", "up")}
SUPABASE_DEV_ALLOWED = {("db", "push"), ("migration", "up")}
CONFIG_PATH = (".claude", "bmn.config.json")
RUN_STATE_GLOB = "docs/sprints/bmn-*/bmn.json"
# `decision`: the run is waiting for Jonathan's release answer and has nothing in flight.
FINISHED_PHASES = frozenset({"done", "blocked", "decision"})
LINKED_REF_PATH = ("supabase", ".temp", "project-ref")

REMOTE_DB_HOST = re.compile(r"supabase\.(co|com)\b")
REMOTE_DB_VAR = re.compile(r"\$\{?\w*(SUPABASE|PROD|MAIN|REMOTE)\w*", re.IGNORECASE)
GIT_VALUE_OPTIONS = frozenset({"-C", "-c"})
PUSH_VALUE_OPTIONS = frozenset({"-o", "--push-option", "--repo"})
PUSH_DELETE_CLUSTER = re.compile(r"^-[nfuqv46]*d[nfuqv46]*$")

MCP_SUPABASE_WRITE_TOOLS = ("apply_migration", "deploy_edge_function", "create_branch",
                            "merge_branch", "reset_branch", "rebase_branch", "delete_branch",
                            "pause_project", "restore_project", "create_project")
MCP_UNIQUE_SUPABASE_TOOLS = ("apply_migration", "deploy_edge_function")
MCP_VERCEL_WRITE_PREFIXES = ("deploy", "promote", "rollback", "alias", "redeploy",
                             "create_deployment", "set_alias", "assign_alias")
SQL_WRITE_WORDS = re.compile(
    r"\b(insert|update|delete|drop|alter|create|truncate|grant|revoke|comment|merge|copy|"
    r"vacuum|reindex|call|do)\b")
SQL_READ_START = re.compile(r"^(select|with|explain|show)\b")

DEPLOY_GUARD = "deploy"
MERGE_GUARD = "merge"
BRANCH_GUARD = "branch"
GIT_MERGE_SUBCOMMANDS = frozenset({"merge", "pull"})
GIT_MERGE_VALUE_FLAGS = frozenset({
    "-m", "--message", "-F", "--file", "-s", "--strategy", "-X", "--strategy-option",
    "--into-name", "--cleanup", "--upload-pack", "--depth", "--deepen", "--shallow-since",
    "--shallow-exclude", "--refmap", "-o", "--server-option", "--negotiation-tip"})
GH_REPO_FLAGS = frozenset({"-R", "--repo"})
GH_PR_MERGE_SHORTS = MappingProxyType({
    "A": "author-email", "b": "body", "F": "body-file", "d": "delete-branch", "m": "merge",
    "r": "rebase", "s": "squash", "t": "subject", "R": "repo", "h": "help"})
GH_PR_MERGE_VALUES = frozenset({"author-email", "body", "body-file", "match-head-commit",
                                "subject", "repo"})
GH_API_SHORTS = MappingProxyType({
    "F": "field", "f": "raw-field", "H": "header", "i": "include", "q": "jq", "X": "method",
    "p": "preview", "t": "template", "h": "help"})
GH_API_VALUES = frozenset({"cache", "field", "header", "hostname", "input", "jq", "method",
                           "preview", "raw-field", "template"})
GH_FIELD_FLAGS = frozenset({"field", "raw-field"})
PFLAG_TRUE = frozenset({"1", "t", "T", "TRUE", "true", "True"})
SQUASH_FIELD_KEYS = frozenset({"merge_method", "mergemethod"})
GRAPHQL_SQUASH = re.compile(r'mergeMethod\s*:\s*"?squash\b', re.IGNORECASE)
ALLOWED_MERGE_FORMS = ("`git merge --no-ff <branch>`, and for a PR "
                       "`gh pr merge <n> --merge --delete-branch`")
MERGE_ADVICE = ("Merge commits only: squash merges flatten history and are never run inside "
                "a bmn run, and a merged PR's source branch is deleted. Allowed: "
                f"{ALLOWED_MERGE_FORMS}.")
DEPLOY_ADVICE = ("Jonathan decides every deploy and every remote database change — add it to "
                 "the report's Deploy checklist instead. (Only if he said 'deploy' in chat "
                 f"this session: prefix the command with {APPROVAL_VAR}=1.)")
BRANCH_ADVICE = ("A protected branch is never deleted inside a bmn run, approved deploy or not; "
                 "if it should go, Jonathan deletes it himself.")
GUARD_ADVICE = MappingProxyType({DEPLOY_GUARD: DEPLOY_ADVICE, MERGE_GUARD: MERGE_ADVICE,
                                 BRANCH_GUARD: BRANCH_ADVICE})


class Block(NamedTuple):
    """A refusal: which rule family raised it, and why."""
    guard: str
    reason: str


# ---------------------------------------------------------------- tokenizing

def normalize(command):
    without_heredocs = HEREDOC.sub("\n", command)
    return WHICH_SUBST.sub(lambda m: m.group(1) or m.group(2), without_heredocs)


def tokenize(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    return list(lexer)


def is_separator(token):
    return bool(token) and all(c in SEPARATOR_CHARS for c in token)


def split_segments(command):
    """Token lists, one per simple command; quoted text never splits a segment."""
    try:
        tokens = tokenize(normalize(command))
    except ValueError:
        return [s.split() for s in re.split(r"&&|\|\||[;\n|&()]", command) if s.strip()]
    segments, current = [], []
    for token in tokens:
        if is_separator(token):
            if current:
                segments.append(current)
            current = []
        else:
            current = [*current, token]
    return [*segments, current] if current else segments


def program_name(token):
    base = token.rsplit("/", 1)[-1]
    return base if base.startswith("@") else base.split("@", 1)[0]


def is_assignment(token):
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token))


def skip_flags(tokens):
    i = 0
    while i < len(tokens) and (tokens[i].startswith("-") or is_assignment(tokens[i])):
        i += 1
    return tokens[i:]


def skip_wrapper_args(wrapper, tokens):
    """Drop a wrapper's own flags, the values of its value flags (`sudo -u me`, `nice -n 5`,
    `timeout -k 5`) and env assignments; `timeout` then takes its DURATION positional."""
    value_flags = WRAPPER_VALUE_FLAGS.get(wrapper, frozenset())
    i = 0
    while i < len(tokens):
        if tokens[i] in value_flags:
            i += 2
        elif tokens[i].startswith("-") or is_assignment(tokens[i]):
            i += 1
        else:
            break
    rest = tokens[i:]
    return rest[1:] if wrapper in DURATION_WRAPPERS else rest


def shell_option_string(shell, arg, following):
    """(string, extra args used) of an option that carries a command string, else None:
    `--command[=]S` for any shell, `--init-command[=]S` and `-C S` / `-lC S` / `-CS` for fish."""
    is_fish = shell == "fish"
    name, has_value, value = arg.partition("=")
    short = FISH_INIT_SHORT.fullmatch(arg) if is_fish else None
    if name in (FISH_LONG_FLAGS if is_fish else COMMAND_LONG_FLAGS):
        attached = value if has_value else None
    elif short:
        attached = short[1] or None
    else:
        return None
    if attached is not None:
        return attached, 0
    return (following[0], 1) if following else None


def shell_command_strings(shell, args):
    """Every string the shell runs from its own command line, in order: the command string of
    `sh -c` / `bash -ec` / `bash -o pipefail -lc` / `fish --command[=]`, and fish's `-C` /
    `--init-command[=]` strings. () when the shell runs a script file or reads stdin."""
    found, has_c, i = (), False, 0
    while i < len(args):
        arg, following = args[i], args[i + 1:i + 2]
        i += 1
        option = shell_option_string(shell, arg, following)
        if option:
            found, i = (*found, option[0]), i + option[1]
        elif arg in SHELL_VALUE_FLAGS:
            i += 1
        elif arg.startswith("--"):
            continue
        elif arg[:1] in ("-", "+") and len(arg) > 1:
            has_c = has_c or "c" in arg[1:]
            i += 1 if arg[-1] in ("o", "O") else 0
        elif has_c:
            found, has_c = (*found, arg), False
            if shell != "fish":
                break
        else:
            break
    return found


def unwrap(tokens):
    """Strip env assignments and runner/wrapper prefixes. Returns (approved, tokens)."""
    approved = False
    while tokens:
        if is_assignment(tokens[0]):
            key, _, value = tokens[0].partition("=")
            approved = approved or (key == APPROVAL_VAR and value == "1")
            tokens = tokens[1:]
        elif program_name(tokens[0]) in SIMPLE_WRAPPERS:
            tokens = skip_wrapper_args(program_name(tokens[0]), tokens[1:])
        elif tuple(tokens[:2]) in TWO_WORD_WRAPPERS:
            tokens = skip_flags(tokens[2:])
        elif (tokens[0] in PACKAGE_RUNNERS and len(tokens) > 1
              and program_name(tokens[1]) in GUARDED_PROGRAMS):
            tokens = tokens[1:]
        else:
            break
    return approved, tokens


def positional(args, value_flags=frozenset()):
    words, skip_next = [], False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in value_flags:
            skip_next = True
        elif not arg.startswith("-"):
            words = [*words, arg]
    return words


# ---------------------------------------------------------------- per-program checks

def check_vercel(args):
    words = positional(args, VERCEL_VALUE_FLAGS)
    if not words:
        if any(a in VERCEL_SAFE_FLAGS for a in args):
            return None
        return "`vercel` with no subcommand deploys"
    sub = words[0]
    if sub in VERCEL_SAFE:
        return None
    if sub in VERCEL_GROUPS and len(words) > 1 and words[1] in VERCEL_GROUP_READS:
        return None
    return f"`vercel {' '.join(words[:2])}` deploys or changes a live Vercel project"


def flag_value(args, flag):
    for i, arg in enumerate(args):
        if arg == flag and i + 1 < len(args):
            return args[i + 1]
        if arg.startswith(flag + "="):
            return arg.split("=", 1)[1]
    return None


def targets_dev_only(args, ctx):
    """True when this db push / migration up provably targets the DEV project, not MAIN."""
    dev, main = ctx["refs"]
    if not dev or not main or dev == main:
        return False
    db_url = flag_value(args, "--db-url")
    if db_url is not None:
        return dev in db_url and main not in db_url
    return ctx["linked_ref"] == dev


def check_supabase(args, ctx):
    words = positional(args, SUPABASE_VALUE_FLAGS)
    pairs = {tuple(words[i:i + 2]) for i in range(len(words) - 1)}
    if pairs & SUPABASE_DEV_ALLOWED and targets_dev_only(args, ctx):
        return None
    blocked = pairs & SUPABASE_ALWAYS_BLOCKED
    if blocked:
        return f"`supabase {' '.join(min(blocked))}` changes a remote Supabase project"
    remote = pairs & SUPABASE_BLOCKED_WHEN_REMOTE
    if remote and any(a.startswith(REMOTE_TARGET_FLAGS) for a in args):
        return f"`supabase {' '.join(min(remote))}` against a linked/remote database"
    return None


def check_remote_sql_client(prog, args):
    text = " ".join(args)
    if REMOTE_DB_HOST.search(text) or REMOTE_DB_VAR.search(text):
        return f"`{prog}` against a remote Supabase database"
    return None


def current_branch(cwd):
    try:
        out = subprocess.run(["git", "branch", "--show-current"], cwd=cwd or None,
                             capture_output=True, text=True, timeout=5, check=False)
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def git_subcommand(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_VALUE_OPTIONS else 1
    return args[i:]


def ref_destination(spec):
    """The branch a push refspec writes to (or deletes): `+src:refs/heads/dev` -> `dev`. git's
    rev-parse rules also resolve `heads/dev` to refs/heads/dev, so either prefix goes, once."""
    return BRANCH_REF_PREFIX.sub("", spec.lstrip("+").rsplit(":", 1)[-1], count=1)


def push_deletes(push_args):
    """True when `git push` runs in delete mode: `--delete`, its abbreviations, or `-d` (alone
    or bundled, `-nd`). Options end at `--`."""
    for arg in push_args:
        if arg == "--":
            return False
        if is_abbrev(arg, "--delete", "--de") or PUSH_DELETE_CLUSTER.match(arg):
            return True
    return False


def default_branch(cwd, remote):
    """The remote's default branch from the local refs/remotes/<remote>/HEAD, else ''."""
    for name in dict.fromkeys([remote, "origin"]):
        try:
            out = subprocess.run(["git", "symbolic-ref", "--quiet", "--short",
                                  f"refs/remotes/{name}/HEAD"], cwd=cwd or None,
                                 capture_output=True, text=True, timeout=5, check=False)
        except (OSError, subprocess.SubprocessError):
            continue
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip().removeprefix(f"{name}/")
    return ""


def deleted_protected_ref(push, cwd):
    """The refspec that deletes a protected branch or the remote's default branch, else None.
    A delete is `--delete <branch>` or an empty-source refspec (`:dev`, `+:dev`). The default
    branch is read at most once, and only when no refspec is a protected name already."""
    options, remote, refspecs = push
    delete_mode = push_deletes(options)
    default = None
    for spec in refspecs:
        dest = ref_destination(spec).casefold()
        if not dest or not (delete_mode or spec.lstrip("+").startswith(":")):
            continue
        if dest in DELETE_PROTECTED:
            return spec
        if default is None:
            default = default_branch(cwd, remote).casefold()
        if dest == default:
            return spec
    return None


def push_parts(args):
    """(push options and words, remote, refspecs) of a `git push`; None for any other git
    command. The first positional word is the remote, the rest are refspecs."""
    rest = git_subcommand(args)
    if not rest or rest[0] != "push":
        return None
    push_args = tuple(rest[1:])
    words = positional(push_args, PUSH_VALUE_OPTIONS)
    return push_args, (words[0] if words else ""), tuple(words[1:])


def check_git(push, cwd):
    if push is None:
        return None
    options, _remote, refspecs = push
    if "--all" in options or "--mirror" in options:
        return "`git push --all/--mirror` would push production branches"
    if not refspecs:
        branch = current_branch(cwd)
        if branch in PROTECTED_BRANCHES:
            return f"`git push` from `{branch}` pushes a production branch"
        return None
    for spec in refspecs:
        if ref_destination(spec) in PROTECTED_BRANCHES:
            return f"`git push … {spec}` pushes a production branch"
    return None


def branch_reason(push, cwd):
    """Why a `git push` deletes a protected branch on origin (never a deploy step), else None."""
    doomed = deleted_protected_ref(push, cwd) if push is not None else None
    return f"`git push … {doomed}` deletes a protected branch" if doomed else None


def repo_root(cwd):
    try:
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=cwd or None,
                             capture_output=True, text=True, timeout=5, check=False)
        return Path(out.stdout.strip()) if out.returncode == 0 else Path(cwd or ".")
    except (OSError, subprocess.SubprocessError):
        return Path(cwd or ".")


def git_roots(cwd):
    """Every worktree root of the repo (main checkout, run worktree, harness worktrees);
    empty outside git. A run's state lives in its sibling run worktree, so all are checked."""
    try:
        out = subprocess.run(["git", "worktree", "list", "--porcelain"], cwd=cwd or None,
                             capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.SubprocessError):
        return []
    if out.returncode != 0:
        return []
    return list(dict.fromkeys(Path(line[len("worktree "):])
                              for line in out.stdout.splitlines() if line.startswith("worktree ")))


def owns_state(root, named):
    """A state file counts only in the worktree it names; copies inherited by harness, scratch
    or human worktrees are ignored. Runs before 1.4.0 name no worktree and always count."""
    if not named or not isinstance(named, str):
        return True
    try:
        return Path(named).resolve() == Path(root).resolve()
    except (OSError, RuntimeError):
        return False


def run_in_progress(cwd):
    for root in git_roots(cwd):
        for state in root.glob(RUN_STATE_GLOB):
            try:
                data = json.loads(state.read_text())
                phase = data.get("phase")
                named = data.get("worktree")
            except (OSError, ValueError, AttributeError):
                phase, named = None, None
            if not owns_state(root, named):
                continue
            if phase not in FINISHED_PHASES:
                return True
    return False


def read_text(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def load_context(cwd):
    root = repo_root(cwd)
    try:
        refs = json.loads(read_text(root.joinpath(*CONFIG_PATH)) or "{}").get("supabase") or {}
    except ValueError:
        refs = {}
    return {"cwd": cwd, "refs": (refs.get("dev_ref"), refs.get("main_ref")),
            "linked_ref": read_text(root.joinpath(*LINKED_REF_PATH)), "approved": False}


def with_link(ctx, prog, args):
    """`supabase link --project-ref X` earlier in the same command re-targets later segments."""
    if prog != "supabase" or positional(args, SUPABASE_VALUE_FLAGS)[:1] != ["link"]:
        return ctx
    ref = flag_value(args, "--project-ref")
    return {**ctx, "linked_ref": ref} if ref else ctx


# ---------------------------------------------------------------- merge guard
# Merge commits only: no squash merge, and a PR merge deletes its source branch. Its sibling, the
# branch guard, never deletes a protected branch on origin. Both are checked before the deploy
# approval pass-through (`unliftable_block`), so BMN_USER_APPROVED_DEPLOY never unlocks them.

def is_abbrev(arg, full, shortest):
    """git accepts any unambiguous prefix of a long option; `shortest` is the shortest one."""
    return len(arg) >= len(shortest) and full.startswith(arg)


def git_merge_squashes(args):
    """True when git would squash: the last of --squash / --no-squash wins, `--` ends options,
    and the value of a value flag (`-m "--squash"`) is not an option."""
    squash, skip_next = False, False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg == "--":
            break
        elif arg in GIT_MERGE_VALUE_FLAGS:
            skip_next = True
        elif is_abbrev(arg, "--squash", "--sq"):
            squash = True
        elif is_abbrev(arg, "--no-squash", "--no-sq"):
            squash = False
    return squash


def check_git_merge(args):
    rest = git_subcommand(args)
    if not rest or rest[0] not in GIT_MERGE_SUBCOMMANDS:
        return None
    if git_merge_squashes(rest[1:]):
        return f"`git {rest[0]} --squash` folds a branch's commits into one"
    return None


def is_true(value):
    """pflag reads a bool flag's value with strconv.ParseBool."""
    return value in PFLAG_TRUE


def long_flag(body, rest, value_names):
    """One `--name[=value]` as pflag's parseLongArg reads it: ((name, value),), rest."""
    name, has_value, value = body.partition("=")
    if has_value:
        return ((name, value),), rest
    if name in value_names and rest:
        return ((name, rest[0]),), rest[1:]
    return ((name, "true"),), rest


def short_cluster(letters, rest, shorts, value_names):
    """A `-abc` cluster as pflag's parseSingleShortArg reads it, left to right: `-x=v` takes v,
    a bool letter reads "true" and continues, a value letter takes the rest of the cluster or
    else the next argument. Unknown letters read as bools. Returns ((name, value), ...), rest."""
    found = ()
    while letters:
        name = shorts.get(letters[0], letters[0])
        if len(letters) > 2 and letters[1] == "=":
            return (*found, (name, letters[2:])), rest
        if name not in value_names:
            found, letters = (*found, (name, "true")), letters[1:]
        elif len(letters) > 1:
            return (*found, (name, letters[1:])), rest
        elif rest:
            return (*found, (name, rest[0])), rest[1:]
        else:
            break
    return found, rest


def pflag_items(args, shorts, value_names):
    """(long_name, value) for every flag in args, in order, as spf13/pflag v1.0.10 (the parser
    inside gh) reads them: flags may follow positionals, `--` stops, a lone `-` is positional."""
    items, rest = (), tuple(args)
    while rest:
        arg, rest = rest[0], rest[1:]
        if arg == "--":
            break
        if arg.startswith("--"):
            found, rest = long_flag(arg[2:], rest, value_names)
        elif arg.startswith("-") and len(arg) > 1:
            found, rest = short_cluster(arg[1:], rest, shorts, value_names)
        else:
            found = ()
        items = (*items, *found)
    return items


def check_gh_pr_merge(args):
    flags = dict(pflag_items(args, GH_PR_MERGE_SHORTS, GH_PR_MERGE_VALUES))
    if is_true(flags.get("help")):
        return None
    if is_true(flags.get("squash")):
        return "`gh pr merge --squash` folds the PR's commits into one"
    if is_true(flags.get("disable-auto")):
        return None
    if not is_true(flags.get("delete-branch")):
        return "`gh pr merge` without `--delete-branch` leaves the merged source branch on origin"
    return None


def is_squash_field(text):
    """A `gh api` field that asks for a squash: `merge_method=squash` (REST, or a GraphQL
    variable) or a `mergeMethod: SQUASH` in a GraphQL query."""
    key, has_value, value = text.partition("=")
    if (has_value and key.strip().lower() in SQUASH_FIELD_KEYS
            and value.strip().strip("'\"").lower() == "squash"):
        return True
    return bool(GRAPHQL_SQUASH.search(text))


def check_gh_api(args):
    items = pflag_items(args, GH_API_SHORTS, GH_API_VALUES)
    if any(name in GH_FIELD_FLAGS and is_squash_field(value) for name, value in items):
        return "`gh api` merge with `merge_method=squash`"
    return None


def check_gh(args):
    words = tuple(positional(args, GH_REPO_FLAGS)[:2])
    if words == ("pr", "merge"):
        return check_gh_pr_merge(args)
    if words[:1] == ("api",):
        return check_gh_api(args)
    return None


def merge_reason(prog, args):
    if prog == "git":
        return check_git_merge(args)
    if prog == "gh":
        return check_gh(args)
    return None


def unliftable_block(prog, args, push, ctx):
    """The merge-guard or branch-guard Block for this command (`push`: its parsed `git push`, if
    it is one), else None. The approval prefix never lifts either, so `check_segment` asks
    before it looks at approval."""
    merge = merge_reason(prog, args)
    if merge:
        return Block(MERGE_GUARD, merge)
    branch = branch_reason(push, ctx["cwd"])
    return Block(BRANCH_GUARD, branch) if branch else None


def deploy_reason(prog, args, push, ctx):
    if prog == "vercel":
        return check_vercel(args)
    if prog == "supabase":
        return check_supabase(args, ctx)
    if prog in ("psql", "pg_restore"):
        return check_remote_sql_client(prog, args)
    if prog == "git":
        return check_git(push, ctx["cwd"])
    return None


def check_segment(tokens, ctx):
    """(Block or None, ctx for the next segment). A shell command string is checked as its own
    command; the approval prefix reaches its deploys but never its merges or protected deletes."""
    approved, tokens = unwrap(tokens)
    if not tokens:
        return None, ctx
    prog, args = program_name(tokens[0]), tokens[1:]
    scripts = shell_command_strings(prog, args) if prog in SHELLS else ()
    if scripts:
        inner = {**ctx, "approved": approved or ctx["approved"]}
        blocks = (check_bash(script, inner) for script in scripts)
        return next((block for block in blocks if block), None), ctx
    push = push_parts(args) if prog == "git" else None
    unliftable = unliftable_block(prog, args, push, ctx)
    if unliftable:
        return unliftable, ctx
    if approved or ctx["approved"]:
        return None, ctx
    deploy = deploy_reason(prog, args, push, ctx)
    return (Block(DEPLOY_GUARD, deploy) if deploy else None), with_link(ctx, prog, args)


def check_bash(command, ctx):
    for segment in split_segments(command):
        block, ctx = check_segment(segment, ctx)
        if block:
            return block
    return None


# ---------------------------------------------------------------- MCP

def is_read_only_sql(query):
    text = re.sub(r"--[^\n]*|/\*.*?\*/", " ", query or "", flags=re.DOTALL).strip().lower()
    return bool(SQL_READ_START.match(text)) and not SQL_WRITE_WORDS.search(text)


def check_mcp_merge(tool, tool_input):
    """The GitHub MCP merge tool with merge_method squash (any server name, any case)."""
    if not tool.endswith("merge_pull_request") or not isinstance(tool_input, dict):
        return None
    method = tool_input.get("merge_method") or tool_input.get("mergeMethod")
    if isinstance(method, str) and method.strip().lower() == "squash":
        return "MCP `merge_pull_request` with merge_method=squash"
    return None


def mcp_deploy_reason(server, tool, tool_input):
    is_supabase = "supabase" in server or "project_id" in tool_input
    if tool.endswith(MCP_UNIQUE_SUPABASE_TOOLS) or (
            is_supabase and tool.endswith(MCP_SUPABASE_WRITE_TOOLS)):
        return f"MCP `{tool}` changes a remote Supabase project"
    if (is_supabase and tool.endswith("execute_sql")
            and not is_read_only_sql(tool_input.get("query") or tool_input.get("sql"))):
        return "MCP `execute_sql` with a non-read-only statement against Supabase"
    if "vercel" in server and tool.startswith(MCP_VERCEL_WRITE_PREFIXES):
        return f"MCP `{tool}` deploys or changes a live Vercel project"
    return None


def check_mcp(tool_name, tool_input):
    server, _, tool = tool_name.lower().removeprefix("mcp__").partition("__")
    merge = check_mcp_merge(tool, tool_input)
    if merge:
        return Block(MERGE_GUARD, merge)
    deploy = mcp_deploy_reason(server, tool, tool_input)
    return Block(DEPLOY_GUARD, deploy) if deploy else None


def block_message(block):
    return (f"Blocked by dev-bother-me-nope {block.guard} guard: {block.reason}. "
            f"{GUARD_ADVICE[block.guard]}")


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    tool_name = payload.get("tool_name") or ""
    tool_input = payload.get("tool_input") or {}
    if tool_name != "Bash" and not tool_name.startswith("mcp__"):
        return 0
    if not run_in_progress(payload.get("cwd")):
        return 0
    if tool_name == "Bash":
        block = check_bash(tool_input.get("command") or "", load_context(payload.get("cwd")))
    else:
        block = check_mcp(tool_name, tool_input)
    if not block:
        return 0
    print(block_message(block), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
