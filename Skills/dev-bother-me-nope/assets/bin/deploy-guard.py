#!/usr/bin/env python3
"""deploy-guard.py — PreToolUse hook for dev-bother-me-nope.

Blocks (exit 2, reason on stderr) any Vercel deploy, any push to a production branch, and any
change to a remote Supabase database, unless the Bash segment is prefixed with
BMN_USER_APPROVED_DEPLOY=1 (set only when Jonathan said "deploy" in chat). Anything it cannot
parse is allowed — this is an accident guard, not a sandbox.
Rules and rationale: ../../references/deploy-guards.md
"""
import json
import re
import shlex
import subprocess
import sys

APPROVAL_VAR = "BMN_USER_APPROVED_DEPLOY"
PROTECTED_BRANCHES = frozenset({"main", "master", "prod", "production", "release"})

SEPARATOR_CHARS = frozenset(";&|()\n")
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n[ \t]*\2[ \t]*(?=\n|$)", re.S)
WHICH_SUBST = re.compile(r"\$\(\s*(?:which|command\s+-v)\s+([\w.-]+)\s*\)|`\s*which\s+([\w.-]+)\s*`")
SHELLS = frozenset({"sh", "bash", "zsh", "dash"})
SIMPLE_WRAPPERS = frozenset({"env", "time", "nohup", "sudo", "command", "exec", "xargs",
                             "npx", "bunx", "nice"})
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

REMOTE_DB_HOST = re.compile(r"supabase\.(co|com)\b")
REMOTE_DB_VAR = re.compile(r"\$\{?\w*(SUPABASE|PROD|MAIN|REMOTE)\w*", re.I)
GIT_VALUE_OPTIONS = frozenset({"-C", "-c"})

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


def unwrap(tokens):
    """Strip env assignments and runner/wrapper prefixes. Returns (approved, tokens)."""
    approved = False
    while tokens:
        if is_assignment(tokens[0]):
            key, _, value = tokens[0].partition("=")
            approved = approved or (key == APPROVAL_VAR and value == "1")
            tokens = tokens[1:]
        elif program_name(tokens[0]) in SIMPLE_WRAPPERS:
            tokens = skip_flags(tokens[1:])
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


def check_supabase(args):
    words = positional(args, SUPABASE_VALUE_FLAGS)
    pairs = set(zip(words, words[1:]))
    blocked = pairs & SUPABASE_ALWAYS_BLOCKED
    if blocked:
        return f"`supabase {' '.join(sorted(blocked)[0])}` changes a remote Supabase project"
    remote = pairs & SUPABASE_BLOCKED_WHEN_REMOTE
    if remote and any(a.startswith(REMOTE_TARGET_FLAGS) for a in args):
        return f"`supabase {' '.join(sorted(remote)[0])}` against a linked/remote database"
    return None


def check_remote_sql_client(prog, args):
    text = " ".join(args)
    if REMOTE_DB_HOST.search(text) or REMOTE_DB_VAR.search(text):
        return f"`{prog}` against a remote Supabase database"
    return None


def current_branch(cwd):
    try:
        out = subprocess.run(["git", "branch", "--show-current"], cwd=cwd or None,
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def git_subcommand(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_VALUE_OPTIONS else 1
    return args[i:]


def check_git(args, cwd):
    rest = git_subcommand(args)
    if not rest or rest[0] != "push":
        return None
    push_args = rest[1:]
    if "--all" in push_args or "--mirror" in push_args:
        return "`git push --all/--mirror` would push production branches"
    refspecs = positional(push_args, frozenset({"-o", "--push-option", "--repo"}))[1:]
    if not refspecs:
        branch = current_branch(cwd)
        if branch in PROTECTED_BRANCHES:
            return f"`git push` from `{branch}` pushes a production branch"
        return None
    for spec in refspecs:
        dest = spec.lstrip("+").rsplit(":", 1)[-1].removeprefix("refs/heads/")
        if dest in PROTECTED_BRANCHES:
            return f"`git push … {spec}` pushes a production branch"
    return None


def check_segment(tokens, cwd):
    approved, tokens = unwrap(tokens)
    if approved or not tokens:
        return None
    prog, args = program_name(tokens[0]), tokens[1:]
    if prog in SHELLS and "-c" in args[:-1]:
        return check_bash(args[args.index("-c") + 1], cwd)
    if prog == "vercel":
        return check_vercel(args)
    if prog == "supabase":
        return check_supabase(args)
    if prog in ("psql", "pg_restore"):
        return check_remote_sql_client(prog, args)
    if prog == "git":
        return check_git(args, cwd)
    return None


def check_bash(command, cwd):
    for segment in split_segments(command):
        reason = check_segment(segment, cwd)
        if reason:
            return reason
    return None


# ---------------------------------------------------------------- MCP

def is_read_only_sql(query):
    text = re.sub(r"--[^\n]*|/\*.*?\*/", " ", query or "", flags=re.S).strip().lower()
    return bool(SQL_READ_START.match(text)) and not SQL_WRITE_WORDS.search(text)


def check_mcp(tool_name, tool_input):
    server, _, tool = tool_name.lower().removeprefix("mcp__").partition("__")
    is_supabase = "supabase" in server or "project_id" in tool_input
    if tool.endswith(MCP_UNIQUE_SUPABASE_TOOLS) or (
            is_supabase and tool.endswith(MCP_SUPABASE_WRITE_TOOLS)):
        return f"MCP `{tool}` changes a remote Supabase project"
    if is_supabase and tool.endswith("execute_sql"):
        if not is_read_only_sql(tool_input.get("query") or tool_input.get("sql")):
            return "MCP `execute_sql` with a non-read-only statement against Supabase"
    if "vercel" in server and tool.startswith(MCP_VERCEL_WRITE_PREFIXES):
        return f"MCP `{tool}` deploys or changes a live Vercel project"
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    tool_name = payload.get("tool_name") or ""
    tool_input = payload.get("tool_input") or {}
    if tool_name == "Bash":
        reason = check_bash(tool_input.get("command") or "", payload.get("cwd"))
    elif tool_name.startswith("mcp__"):
        reason = check_mcp(tool_name, tool_input)
    else:
        reason = None
    if not reason:
        return 0
    print(f"Blocked by dev-bother-me-nope deploy guard: {reason}. Jonathan decides every "
          f"deploy and every remote database change — add it to the report's Deploy checklist "
          f"instead. (Only if he said 'deploy' in chat this session: prefix the command with "
          f"{APPROVAL_VAR}=1.)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
