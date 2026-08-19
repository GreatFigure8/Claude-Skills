#!/usr/bin/env bash
# PostToolUse hook — dev-epic-workflow executor telemetry.
#
# While a subagent is active (marker in .claude/signals/, maintained by
# subagent-lifecycle.sh), append one compact line per tool call to the epic's
# per-item log: docs/epics/<NN>-<slug>/status/<branch-slug>.log
#
# This is the deterministic progress stream — it does not depend on the model
# choosing to report anything. Tail it live:
#   tail -f docs/epics/<NN>-<slug>/status/<branch>.log
#
# Fast no-op when no subagent is active (so orchestrator/main-session tool
# calls are never logged). Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

# Fast path: no active subagent → do nothing (drain stdin and exit).
if ! ls .claude/signals/subagent-active-* > /dev/null 2>&1; then
  cat > /dev/null 2>&1 || true
  exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

EPIC_PLAN="$(ls -t docs/epics/*/plan.md 2>/dev/null | head -1)"
[ -n "$EPIC_PLAN" ] || exit 0
STATUS_DIR="$(dirname "$EPIC_PLAN")/status"
mkdir -p "$STATUS_DIR" 2>/dev/null || exit 0

BRANCH_SLUG="$(git branch --show-current 2>/dev/null | tr '/' '-')"
[ -n "$BRANCH_SLUG" ] || BRANCH_SLUG="detached"
LOG="$STATUS_DIR/$BRANCH_SLUG.log"

LINE=""
if command -v jq > /dev/null 2>&1; then
  LINE="$(printf '%s' "$INPUT" | jq -r '
    def trunc(n): tostring | if length > n then .[:n] + "…" else . end;
    [ (now | todate),
      (.tool_name // "?"),
      ( .tool_input // {} |
        ( .command // .file_path // .path // .pattern // .query // "" ) | trunc(120) )
    ] | join(" | ")' 2>/dev/null || true)"
elif command -v python3 > /dev/null 2>&1; then
  LINE="$(printf '%s' "$INPUT" | python3 -c '
import json, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
brief = str(ti.get("command") or ti.get("file_path") or ti.get("path")
            or ti.get("pattern") or ti.get("query") or "")
brief = " ".join(brief.split())
if len(brief) > 120: brief = brief[:120] + "…"
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
tool = d.get("tool_name") or "?"
print(now + " | " + tool + " | " + brief)' 2>/dev/null || true)"
fi

[ -n "$LINE" ] && echo "$LINE" >> "$LOG" 2>/dev/null

exit 0
