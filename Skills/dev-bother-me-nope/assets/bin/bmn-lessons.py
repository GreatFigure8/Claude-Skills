#!/usr/bin/env python3
"""bmn-lessons.py — the dev-bother-me-nope lessons ledger: status, select, check, export-global.

Purpose:
  Every bmn run's RETRO writes one append-only event file, docs/bmn/lessons/<run>.jsonl, in the
  project repo; TEACH writes one, chat-<date>-<slug>.jsonl, from any conversation. This helper
  folds those files, plus the machine's global ledger (~/.claude/bmn/lessons/), into the current state of every lesson; picks the lessons each brief
  is given; validates a run file before it is committed; and copies a run's global-scope events
  into the global ledger so every repo on the machine learns from them.

Contract:
  bmn-lessons.py status --repo <dir> [--global-dir <dir>]
    stdout {"runs": n, "lessons": [{id, scope, kind, source, status, rule, why, briefs, stack,
            tags, hits, seen_runs, repos, last_run}]}; status is active|dormant|promoted|retired.
  bmn-lessons.py select --repo <dir> --stack <kind> [--tag <t>]... [--limit n] [--global-dir <dir>]
    stdout {"runs": n, "served": [ids], "briefs": {<brief>: [{id, rule, why, hits, source}]},
            "text": {<brief>: "- [id] rule — why"}}; every brief name is a key.
  bmn-lessons.py check --file <run.jsonl> [--repo <dir>] [--global-dir <dir>]
    stdout {"ok": bool, "errors": [...]}; exit 1 when not ok. A bmn-<slug> file needs its run
    event; a chat-<date>-<slug> file (TEACH) must not have one, since it is not a run. A chat
    event counts toward dormancy after the last run that started before it.
  bmn-lessons.py export-global --file <run.jsonl> --repo-name <name> [--global-dir <dir>]
    stdout {"written": <path>, "events": n}; exit 1 when the file fails check.
  Exit 2 = usage error, stdout {"error": "..."}.

Safety:
  Reads only *.jsonl in <repo>/docs/bmn/lessons and the global dir. Writes only in export-global:
  one file, <repo-name>--<run>.jsonl, inside the global dir; the repo name and run are validated
  so the path cannot leave it. status and select skip a malformed line (check reports it), never
  a traceback. A global-ledger file only contributes global-scope lessons. Rule and why are one
  line of at most 240 characters. A lesson is guidance for a brief, never permission: nothing
  it says lifts a hard line. No subprocess, no network.
"""
from __future__ import annotations

import argparse
import bisect
import json
import re
import sys
from pathlib import Path
from types import MappingProxyType

EVENTS = frozenset({"run", "lesson", "hit", "revise", "retire", "promoted"})
KINDS = frozenset({"code", "workflow"})
SCOPES = frozenset({"project", "global"})
SOURCES = frozenset({
    "review", "test", "fix", "merge", "assumption", "timing", "blocker", "jonathan", "chat",
})
BRIEFS = (
    "orchestrator", "stack-scout", "researcher", "synthesizer", "designer", "splitter", "planner",
    "coder", "merger", "db-sync", "tester", "reviewer", "fixer", "cleaner", "release-prep", "retro",
)
REQUIRED = MappingProxyType({
    "run": ("stack", "tested", "served"),
    "lesson": ("id", "kind", "scope", "source", "briefs", "stack", "tags", "rule", "why", "evidence"),
    "hit": ("id", "evidence", "served"),
    "revise": ("id", "rule", "why"),
    "retire": ("id", "why"),
    "promoted": ("id", "to"),
})
LEDGER = ("docs", "bmn", "lessons")
MAX_TEXT = 240
DORMANT_AFTER = 8
DEFAULT_LIMIT = 8
SERVED_FIELDS = ("id", "rule", "why", "hits", "source")
ID_RE = re.compile(r"^[LF]-[a-z0-9][a-z0-9-]*-\d+$")
RUN_RE = re.compile(
    r"^(bmn-[a-z0-9][a-z0-9-]*|learn-\d{4}-\d{2}-\d{2}|chat-\d{4}-\d{2}-\d{2}-[a-z0-9][a-z0-9-]*)$"
)
AT_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


class UsageError(Exception):
    pass


def default_global_dir() -> Path:
    return Path.home() / ".claude" / "bmn" / "lessons"


def parse_line(line: str):
    try:
        event = json.loads(line)
    except ValueError:
        return None
    ok = isinstance(event, dict) and event.get("event") in EVENTS
    ok = ok and isinstance(event.get("run"), str) and isinstance(event.get("at"), str)
    return event if ok else None


def read_events(path: Path) -> list:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    return [e for e in (parse_line(line) for line in lines if line.strip()) if e]


def key_of(event: dict) -> tuple:
    return (event["event"], event.get("id", ""), event["run"])


def load_events(repo, global_dir) -> list:
    """Project files first, so a project event wins over its copy in the global ledger."""
    seen, events = set(), []
    sources = [(Path(repo).joinpath(*LEDGER), "project")] if repo else []
    if global_dir:
        sources.append((Path(global_dir), "global"))
    for folder, origin in sources:
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.jsonl")):
            for event in read_events(path):
                if origin == "global" and event["event"] == "lesson" and event.get("scope") != "global":
                    continue
                if key_of(event) not in seen:
                    seen.add(key_of(event))
                    events.append(dict(event, origin=origin, repo=event.get("repo", "this")))
    return sorted(events, key=lambda e: e["at"])


def run_order(events: list) -> dict:
    """Each run's name -> the `at` of its run event, in run order (events are sorted by `at`)."""
    runs = {}
    for event in events:
        if event["event"] == "run":
            runs.setdefault(event["run"], event["at"])
    return runs


def new_lesson(event: dict) -> dict:
    return {
        "id": event["id"], "scope": event.get("scope"), "kind": event.get("kind"),
        "source": event.get("source"), "rule": event.get("rule", ""), "why": event.get("why", ""),
        "briefs": list(event.get("briefs") or []), "stack": event.get("stack", "any"),
        "tags": list(event.get("tags") or []), "hits": 0, "seen": [(event["run"], event["at"])],
        "repos": [event["repo"]], "retired": False, "promoted": False,
    }


def apply_event(lessons: dict, event: dict) -> None:
    kind, lesson = event["event"], lessons.get(event.get("id"))
    if kind == "lesson" and lesson is None and isinstance(event.get("id"), str):
        lessons[event["id"]] = new_lesson(event)
    elif lesson is None or kind == "lesson":
        return
    elif kind == "hit":
        lesson["hits"] += 1
        lesson["seen"] = lesson["seen"] + [(event["run"], event["at"])]
        lesson["repos"] = sorted(set(lesson["repos"]) | {event["repo"]})
    elif kind == "revise":
        lesson["rule"], lesson["why"] = event.get("rule", lesson["rule"]), event.get("why", lesson["why"])
    elif kind == "retire":
        lesson["retired"] = True
    elif kind == "promoted":
        lesson["promoted"] = True


def fold(events: list) -> list:
    """Dormancy counts this repo's runs for a project lesson, every run for a global one."""
    lessons = {}
    all_runs = run_order(events)
    project_runs = run_order([e for e in events if e["origin"] == "project"])
    for event in events:
        apply_event(lessons, event)
    return [
        finish(lesson, all_runs if lesson["scope"] == "global" else project_runs)
        for lesson in lessons.values()
    ]


def position(run: str, at: str, runs: dict) -> int:
    """A bmn run's own index; a chat or learn event sits after the last run started before it."""
    if run in runs:
        return list(runs).index(run)
    return bisect.bisect_right(list(runs.values()), at) - 1


def finish(lesson: dict, runs: dict) -> dict:
    last = max(position(run, at, runs) for run, at in lesson["seen"])
    idle = len(runs) - 1 - last
    if lesson["retired"]:
        status = "retired"
    elif lesson["promoted"]:
        status = "promoted"
    elif idle >= DORMANT_AFTER and lesson["source"] != "jonathan":
        status = "dormant"
    else:
        status = "active"
    out = {k: v for k, v in lesson.items() if k not in ("seen", "retired", "promoted")}
    return dict(out, status=status, seen_runs=len({run for run, _ in lesson["seen"]}),
                last_run=lesson["seen"][-1][0], last_index=last)


def matches(lesson: dict, stack: str, tags: set) -> bool:
    if lesson["scope"] != "global":
        return True
    stack_ok = lesson["stack"] in ("any", stack)
    return stack_ok and (not lesson["tags"] or bool(tags & set(lesson["tags"])))


def rank(lesson: dict) -> tuple:
    return (lesson["source"] != "jonathan", -lesson["hits"], -lesson["last_index"], lesson["id"])


def render(entries: list) -> str:
    if not entries:
        return "none yet"
    lines = []
    for entry in entries:
        seen = f" (recurred {entry['hits']}×)" if entry["hits"] else ""
        lines.append(f"- [{entry['id']}] {entry['rule']} — {entry['why']}{seen}")
    return "\n".join(lines)


def select(lessons: list, stack: str, tags: set, limit: int) -> dict:
    pool = sorted(
        (item for item in lessons if item["status"] == "active" and matches(item, stack, tags)),
        key=rank,
    )
    briefs, served = {}, set()
    for brief in BRIEFS:
        picked = [item for item in pool if brief in item["briefs"]][:limit]
        served.update(item["id"] for item in picked)
        briefs[brief] = [{k: item[k] for k in SERVED_FIELDS} for item in picked]
    text = {brief: render(entries) for brief, entries in briefs.items()}
    return {"served": sorted(served), "briefs": briefs, "text": text}


def text_errors(event: dict, where: str) -> list:
    errors = []
    for field in ("rule", "why"):
        value = event.get(field)
        if field in REQUIRED[event["event"]]:
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{where}: {field} must be a non-empty string")
            elif len(value) > MAX_TEXT or "\n" in value:
                errors.append(f"{where}: {field} must be one line of at most {MAX_TEXT} characters")
    return errors


def lesson_errors(event: dict, where: str) -> list:
    checks = (
        (event.get("kind") in KINDS, "kind"), (event.get("scope") in SCOPES, "scope"),
        (event.get("source") in SOURCES, "source"),
        (isinstance(event.get("stack"), str) and bool(event.get("stack")), "stack"),
        (isinstance(event.get("tags"), list), "tags"),
        (isinstance(event.get("briefs"), list) and bool(event.get("briefs"))
         and set(event.get("briefs")) <= set(BRIEFS), "briefs"),
    )
    return [f"{where}: bad {name}" for ok, name in checks if not ok]


def event_errors(event: dict, where: str) -> list:
    kind = event["event"]
    missing = [field for field in REQUIRED[kind] if field not in event]
    if missing:
        return [f"{where}: {kind} is missing {', '.join(missing)}"]
    errors = [] if AT_RE.match(event["at"]) else [f"{where}: at must be ISO 8601"]
    if "id" in event and not (isinstance(event["id"], str) and ID_RE.match(event["id"])):
        errors.append(f"{where}: id must look like L-<run-slug>-<n> or F-<run-slug>-<n>")
    if "evidence" in event and not (isinstance(event["evidence"], list) and event["evidence"]):
        errors.append(f"{where}: evidence must be a non-empty list")
    if kind == "lesson":
        errors += lesson_errors(event, where)
    if kind == "run" and not isinstance(event["served"], list):
        errors.append(f"{where}: served must be a list")
    return errors + text_errors(event, where)


def parse_file(path: Path) -> tuple:
    events, errors = [], []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return [], [f"cannot read {path}: {exc}"]
    for number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        event = parse_line(line)
        if event is None:
            errors.append(f"line {number}: not a ledger event (event, run, at)")
        else:
            events.append(event)
            errors += event_errors(event, f"line {number}")
    return events, errors


def file_errors(path: Path, events: list) -> list:
    errors = []
    runs = {e["run"] for e in events}
    if len(runs) != 1:
        return [f"one file holds one run's events, found {sorted(runs) or 'none'}"]
    run = runs.pop()
    if not RUN_RE.match(run) or path.name != f"{run}.jsonl":
        errors.append(f"file must be named <run>.jsonl for run {run!r}")
    has_run = any(e["event"] == "run" for e in events)
    if run.startswith("bmn-") and not has_run:
        errors.append("a bmn run file needs one run event")
    if run.startswith("chat-") and has_run:
        errors.append("a chat file holds no run event: a conversation is not a bmn run")
    ids = [e["id"] for e in events if e["event"] == "lesson"]
    errors += [f"lesson {i} is defined twice" for i in sorted({i for i in ids if ids.count(i) > 1})]
    return errors


def check(path: Path, repo, global_dir) -> list:
    events, errors = parse_file(path)
    if errors:
        return errors
    errors = file_errors(path, events)
    others = [e for e in load_events(repo, global_dir) if e["run"] != events[0]["run"]]
    known = {e["id"] for e in others if e["event"] == "lesson"}
    own = {e["id"] for e in events if e["event"] == "lesson"}
    errors += [f"lesson {i} already exists in the ledger" for i in sorted(own & known)]
    for event in events:
        if event["event"] in ("hit", "revise", "retire", "promoted") and event["id"] not in own | known:
            errors.append(f"{event['event']} names unknown lesson {event['id']}")
    return errors


def export_global(path: Path, repo_name: str, global_dir: Path) -> dict:
    if not NAME_RE.match(repo_name) or repo_name in (".", ".."):
        raise UsageError(f"bad --repo-name {repo_name!r}")
    events, _ = parse_file(path)
    known = {item["id"] for item in fold(load_events(None, global_dir)) if item["scope"] == "global"}
    own = {e["id"] for e in events if e["event"] == "lesson" and e.get("scope") == "global"}
    keep = [
        dict(e, repo=repo_name) for e in events
        if e["event"] == "run" or e.get("id") in own | known
    ]
    global_dir.mkdir(parents=True, exist_ok=True)
    target = global_dir / f"{repo_name}--{events[0]['run']}.jsonl"
    target.write_text("".join(json.dumps(e, ensure_ascii=False) + "\n" for e in keep), encoding="utf-8")
    return {"written": str(target), "events": len(keep)}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="bmn-lessons.py")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("status", "select", "check", "export-global"):
        cmd = sub.add_parser(name)
        cmd.add_argument("--global-dir", default=None)
        if name in ("status", "select"):
            cmd.add_argument("--repo", required=True)
        if name in ("check", "export-global"):
            cmd.add_argument("--file", required=True)
        if name == "check":
            cmd.add_argument("--repo", default=None)
        if name == "export-global":
            cmd.add_argument("--repo-name", required=True)
        if name == "select":
            cmd.add_argument("--stack", required=True)
            cmd.add_argument("--tag", action="append", default=[])
            cmd.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    return parser


def run(args) -> tuple:
    global_dir = Path(args.global_dir) if args.global_dir else default_global_dir()
    if args.command in ("status", "select"):
        events = load_events(Path(args.repo), global_dir)
        lessons = fold(events)
        runs = len(run_order(events))
        if args.command == "status":
            public = [{k: v for k, v in item.items() if k != "last_index"} for item in lessons]
            return {"runs": runs, "lessons": sorted(public, key=lambda item: item["id"])}, 0
        if args.limit < 1:
            raise UsageError("--limit must be 1 or more")
        return dict(select(lessons, args.stack, set(args.tag), args.limit), runs=runs), 0
    errors = check(Path(args.file), getattr(args, "repo", None), global_dir)
    if args.command == "check" or errors:
        return {"ok": not errors, "errors": errors}, 1 if errors else 0
    return export_global(Path(args.file), args.repo_name, global_dir), 0


def main(argv=None) -> int:
    try:
        args = build_parser().parse_args(argv)
        result, code = run(args)
    except SystemExit as exc:
        if exc.code in (0, None):
            raise
        print(json.dumps({"error": "usage: see the module docstring"}))
        return 2
    except UsageError as exc:
        print(json.dumps({"error": str(exc)}))
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return code


if __name__ == "__main__":
    sys.exit(main())
