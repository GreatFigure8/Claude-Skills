#!/usr/bin/env python3
"""bmn-cores.py — counts this machine's processors and sizes agents, shards and workers to them.

Purpose:
  "Use every processor" needs a number, not a guess. This helper reads the logical processor
  count the process may use and the subagent cap, and turns them into the figures the briefs
  carry: how many agents one message may dispatch, how many shards the full suite splits into,
  and how many workers each CPU-heavy command gets, so shards x workers fills the machine.

Contract:
  bmn-cores.py [--pinned <n>] [--cores <n>] [--cap <n>]
  stdout, one JSON object:
    {"logical": 36, "agent_cap": 36, "cap_source": "env|default|flag",
     "shards": 6, "workers": 6, "solo_workers": 36, "pinned": null,
     "flags": {"vitest": "--maxWorkers=6 --shard=<i>/6", "jest": "--maxWorkers=6 --shard=<i>/6",
               "pytest": "-n 6", "eslint": "--concurrency=auto", "playwright": "--workers=6"}}
  logical = processors this process may run on (affinity-aware where the OS reports it).
  agent_cap = CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS when set to a whole number >= 1, else 20.
  shards = the largest count <= round(sqrt(logical)) that is also <= agent_cap; workers =
  logical // shards, so shards x workers <= logical. solo_workers = logical, for a command that
  runs alone. --pinned <n> is a worker count the project pins: workers and solo_workers never
  exceed it. --cores and --cap override what the machine reports (tests, a shared machine).
  Exit 2 with one message on stderr (stdout empty) for a flag that is not a whole number >= 1.

Safety:
  Reads the processor count and one environment variable. Writes nothing, runs no subprocess,
  touches no network. A failure here is an assumption in the run, never a blocker: the
  stack-scout then sizes the gates by hand and says so in stack.md.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys

DEFAULT_AGENT_CAP = 20
CAP_ENV = "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS"
EXIT_USAGE = 2


class CoresError(Exception):
    """Raised for any input the helper refuses; the message goes to stderr."""


def logical_cores() -> int:
    """Processors this process may use: affinity first, then the machine's count, then 1."""
    process_count = getattr(os, "process_cpu_count", None)
    if process_count is not None and process_count():
        return process_count()
    affinity = getattr(os, "sched_getaffinity", None)
    if affinity is not None:
        return len(affinity(0)) or 1
    return os.cpu_count() or 1


def agent_cap(environ) -> tuple:
    raw = (environ.get(CAP_ENV) or "").strip()
    if raw.isdigit() and int(raw) >= 1:
        return int(raw), "env"
    return DEFAULT_AGENT_CAP, "default"


def positive(name: str, value) -> int | None:
    if value is None:
        return None
    if not str(value).isdigit() or int(value) < 1:
        raise CoresError(f"{name} must be a whole number >= 1, got {value!r}")
    return int(value)


def split(logical: int, cap: int, pinned: int | None) -> dict:
    shards = max(1, min(round(math.sqrt(logical)), cap, logical))
    workers = max(1, logical // shards)
    solo = logical
    if pinned is not None:
        workers = min(workers, pinned)
        solo = min(solo, pinned)
    return {"shards": shards, "workers": workers, "solo_workers": solo}


def flags(shards: int, workers: int) -> dict:
    shard = f"--maxWorkers={workers} --shard=<i>/{shards}"
    return {"vitest": shard, "jest": shard, "pytest": f"-n {workers}",
            "eslint": "--concurrency=auto", "playwright": f"--workers={workers}"}


def size(args, environ) -> dict:
    logical = positive("--cores", args.cores) or logical_cores()
    cap, source = agent_cap(environ)
    flag_cap = positive("--cap", args.cap)
    if flag_cap is not None:
        cap, source = flag_cap, "flag"
    pinned = positive("--pinned", args.pinned)
    sizes = split(logical, cap, pinned)
    return {"logical": logical, "agent_cap": cap, "cap_source": source, **sizes,
            "pinned": pinned, "flags": flags(sizes["shards"], sizes["workers"])}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="bmn-cores.py")
    parser.add_argument("--pinned")
    parser.add_argument("--cores")
    parser.add_argument("--cap")
    args = parser.parse_args(argv)
    try:
        result = size(args, os.environ)
    except CoresError as exc:
        print(f"bmn-cores.py: {exc}", file=sys.stderr)
        return EXIT_USAGE
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
