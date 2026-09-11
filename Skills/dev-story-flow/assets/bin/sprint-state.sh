#!/usr/bin/env bash
# sprint-state.sh — the one place dev-story-flow reads and writes docs/sprints/<sprint>/sprint.json.
# See references/sprint-state.md for the state machine. python3 is the only dependency.
#
#   sprint-state.sh new [--live <branch>] [--integration <branch>|none]
#   sprint-state.sh list [<status>]
#   sprint-state.sh get <sprint>
#   sprint-state.sh set <sprint> <status> [--by <id>] [--force]
#   sprint-state.sh story add <sprint> <slug> --title <t> --kind interactive|service [--issue <n>]
#   sprint-state.sh story set <sprint> <slug> <status> [--detail <t>] [--plan <relpath>] [--issue <n>] [--bump-attempts] [--force]
#   sprint-state.sh stale <sprint> [<hours>]        exit 0 = claim older than <hours> (default $DSF_STALE_HOURS or 6)
#
# SPRINTS_DIR overrides docs/sprints (relative to the git top level). Exit 2 on any usage/state error.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPRINTS_DIR="${SPRINTS_DIR:-docs/sprints}"
case "$SPRINTS_DIR" in /*) DIR="$SPRINTS_DIR" ;; *) DIR="$ROOT/$SPRINTS_DIR" ;; esac
DEFAULT_LIVE="$( (git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true) | sed 's#^origin/##')"
export DSF_DEFAULT_LIVE="${DEFAULT_LIVE:-main}"
export DSF_HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
exec python3 - "$DIR" "$@" <<'PY'
import json, os, sys, glob, re, tempfile
from datetime import datetime, timezone, timedelta

SPRINT_STATES = ["drafting", "ready-to-plan", "planning", "planned", "executing", "complete", "blocked"]
SPRINT_NEXT = {
    "drafting": {"ready-to-plan"},
    "ready-to-plan": {"planning"},
    "planning": {"planned", "ready-to-plan"},
    "planned": {"executing"},
    "executing": {"complete", "blocked", "planned"},
    "complete": set(),
    "blocked": {"planned", "executing"},
}
CLAIMING = {"planning", "executing"}
STORY_STATES = ["drafted", "planned", "executing", "validating", "done", "blocked"]
STORY_NEXT = {
    "drafted": {"planned"},
    "planned": {"executing"},
    "executing": {"validating", "blocked"},
    "validating": {"done", "executing", "blocked"},
    "done": set(),
    "blocked": {"executing"},
}
KINDS = {"interactive", "service"}
DEFAULT_STALE_HOURS = 6

def now(): return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
def die(msg, code=2): print(f"sprint-state: {msg}", file=sys.stderr); sys.exit(code)
def default_id(): return f"{os.environ.get('DSF_HOSTNAME','host')}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"

def path(base, name): return os.path.join(base, name, "sprint.json")
def load(base, name):
    p = path(base, name)
    if not os.path.isfile(p): die(f"no manifest at {p}")
    with open(p) as f: return json.load(f)
def save(base, name, m):
    p = path(base, name); os.makedirs(os.path.dirname(p), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p), prefix=".sprint.", suffix=".json")
    with os.fdopen(fd, "w") as f: json.dump(m, f, indent=2); f.write("\n")
    os.replace(tmp, p)
def with_history(m, status, by, forced=False):
    entry = {"at": now(), "status": status, "by": by}
    if forced: entry["forced"] = True
    return {**m, "status": status, "updated": entry["at"], "history": [*m.get("history", []), entry]}

def opt(args, flag, default=None, has_value=True):
    if flag not in args: return default, args
    i = args.index(flag)
    if not has_value: return True, args[:i] + args[i+1:]
    if i + 1 >= len(args): die(f"{flag} needs a value")
    return args[i+1], args[:i] + args[i+2:]

def cmd_new(base, args):
    live, args = opt(args, "--live", os.environ.get("DSF_DEFAULT_LIVE", "main"))
    integration, args = opt(args, "--integration", None)
    if args: die(f"unexpected: {args}")
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    used = [int(m.group(1)) for d in glob.glob(os.path.join(base, f"{today}-*"))
            if (m := re.search(rf"{today}-(\d{{3}})$", d))]
    name = f"{today}-{(max(used) + 1) if used else 1:03d}"
    if integration is None: integration = f"sprint/{name}"
    ts = now()
    m = {"sprint": name, "status": "drafting", "created": ts, "updated": ts,
         "branch": {"live": live, "integration": integration}, "claim": None, "stories": [],
         "history": [{"at": ts, "status": "drafting", "by": "creator"}]}
    save(base, name, m); print(name)

def cmd_list(base, args):
    want = args[0] if args else None
    if want and want not in SPRINT_STATES: die(f"unknown status {want}")
    for p in sorted(glob.glob(os.path.join(base, "*", "sprint.json"))):
        with open(p) as f: m = json.load(f)
        if want and m.get("status") != want: continue
        c = m.get("claim") or {}
        print("\t".join([m["sprint"], m["status"], c.get("by", "-"), c.get("at", "-")]))

def cmd_get(base, args):
    if len(args) != 1: die("get <sprint>")
    print(json.dumps(load(base, args[0]), indent=2))

def cmd_set(base, args):
    by, args = opt(args, "--by", None)
    force, args = opt(args, "--force", False, has_value=False)
    if len(args) != 2: die("set <sprint> <status> [--by <id>] [--force]")
    name, status = args
    if status not in SPRINT_STATES: die(f"unknown status {status}; one of {SPRINT_STATES}")
    m = load(base, name)
    cur = m["status"]
    if status != cur and status not in SPRINT_NEXT[cur] and not force:
        die(f"{name}: {cur} -> {status} is not an allowed transition (pass --force to override)")
    who = by or default_id()
    nm = with_history(m, status, who, forced=(force and status not in SPRINT_NEXT[cur] and status != cur))
    nm = {**nm, "claim": ({"by": who, "at": nm["updated"]} if status in CLAIMING else None)}
    save(base, name, nm); print(f"{name}\t{cur} -> {status}")

def find_story(m, slug):
    for i, s in enumerate(m.get("stories", [])):
        if s["slug"] == slug: return i, s
    return None, None

def cmd_story(base, args):
    if not args or args[0] not in {"add", "set"}: die("story add|set ...")
    sub, args = args[0], args[1:]
    if sub == "add":
        title, args = opt(args, "--title", None); kind, args = opt(args, "--kind", None); issue, args = opt(args, "--issue", None)
        if len(args) != 2 or not title or not kind: die("story add <sprint> <slug> --title <t> --kind interactive|service [--issue <n>]")
        name, slug = args
        if kind not in KINDS: die(f"kind must be one of {sorted(KINDS)}")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", slug): die("slug must be lower-case, dash-separated")
        m = load(base, name)
        if m["status"] != "drafting": die(f"{name} is {m['status']}; stories can only be added while drafting")
        if find_story(m, slug)[1]: die(f"story {slug} already exists in {name}")
        story = {"slug": slug, "title": title, "kind": kind, "issue": int(issue) if issue else None,
                 "status": "drafted", "plan": None, "attempts": 0, "detail": ""}
        save(base, name, {**m, "updated": now(), "stories": [*m["stories"], story]}); print(f"{name}\t{slug}\tdrafted")
        return
    detail, args = opt(args, "--detail", None); plan, args = opt(args, "--plan", None); issue, args = opt(args, "--issue", None)
    bump, args = opt(args, "--bump-attempts", False, has_value=False); force, args = opt(args, "--force", False, has_value=False)
    if len(args) != 3: die("story set <sprint> <slug> <status> [--detail <t>] [--plan <p>] [--issue <n>] [--bump-attempts] [--force]")
    name, slug, status = args
    if status not in STORY_STATES: die(f"unknown story status {status}; one of {STORY_STATES}")
    m = load(base, name); i, s = find_story(m, slug)
    if s is None: die(f"no story {slug} in {name}")
    cur = s["status"]
    if status != cur and status not in STORY_NEXT[cur] and not force:
        die(f"{name}/{slug}: {cur} -> {status} is not an allowed transition (pass --force to override)")
    ns = {**s, "status": status, "updated": now()}
    if detail is not None: ns["detail"] = detail
    if plan is not None: ns["plan"] = plan
    if issue is not None: ns["issue"] = int(issue)
    if bump: ns["attempts"] = s.get("attempts", 0) + 1
    stories = [*m["stories"][:i], ns, *m["stories"][i+1:]]
    save(base, name, {**m, "updated": ns["updated"], "stories": stories}); print(f"{name}\t{slug}\t{cur} -> {status}\tattempts={ns['attempts']}")

def cmd_stale(base, args):
    if not args: die("stale <sprint> [<hours>]")
    hours = float(args[1]) if len(args) > 1 else float(os.environ.get("DSF_STALE_HOURS", DEFAULT_STALE_HOURS))
    m = load(base, args[0]); c = m.get("claim")
    if not c: print("no claim"); sys.exit(1)
    at = datetime.fromisoformat(c["at"].replace("Z", "+00:00"))
    age = datetime.now(timezone.utc) - at
    stale = age > timedelta(hours=hours)
    print(f"{'stale' if stale else 'fresh'}\t{c['by']}\tage={int(age.total_seconds())}s")
    sys.exit(0 if stale else 1)

def main():
    base, args = sys.argv[1], sys.argv[2:]
    if not args: die("usage: new|list|get|set|story|stale (see header)")
    cmd, rest = args[0], args[1:]
    {"new": cmd_new, "list": cmd_list, "get": cmd_get, "set": cmd_set, "story": cmd_story, "stale": cmd_stale}.get(cmd, lambda b, a: die(f"unknown command {cmd}"))(base, rest)

main()
PY
