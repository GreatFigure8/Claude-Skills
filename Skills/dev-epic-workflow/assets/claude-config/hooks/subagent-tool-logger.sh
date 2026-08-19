#!/usr/bin/env bash
# PostToolUse hook — dev-epic-workflow executor telemetry.
#
# Append one compact line per SUBAGENT tool call to the epic's per-item log:
# docs/epics/<NN>-<slug>/status/<branch-slug>.log
#
# This is the deterministic progress stream — it does not depend on the model
# choosing to report anything. Tail it live:
#   tail -f docs/epics/<NN>-<slug>/status/<branch>.log
#
# Attribution is per call, not per session: PostToolUse input carries
# `agent_id` ONLY inside a subagent call, so its absence identifies the
# orchestrator / main session and nothing is written. The
# .claude/signals/subagent-active-* markers are not consulted — a marker only
# proves that some subagent is running, so orchestrator calls made while an
# executor was armed used to be logged as executor activity (GH #2). The
# markers stay in place; subagent-lifecycle.sh still owns them.
#
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# Fast path: no agent_id anywhere in the payload → main session → log nothing.
# Cheap pre-filter only; an escaped occurrence inside a tool argument is
# rejected by the real extraction below.
case "$INPUT" in
  *'"agent_id"'*) ;;
  *) exit 0 ;;
esac

# Confirm it with a real parse: jq, python3 fallback, then a parser-free
# grep/sed fallback. The (^|[{,]) anchor stops an escaped \"agent_id\" inside
# tool_input from matching. Unparseable → treat as main session → log nothing.
AGENT_ID=""
if command -v jq > /dev/null 2>&1; then
  AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
elif command -v python3 > /dev/null 2>&1; then
  AGENT_ID="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("agent_id") or "")
except Exception: pass' 2>/dev/null || true)"
else
  # Only trust this path on a payload that at least opens and closes as an
  # object; a truncated one yields no id, so malformed input still fails open.
  RAW="${INPUT%"${INPUT##*[![:space:]]}"}"
  case "$RAW" in
    '{'*'}')
      AGENT_ID="$(printf '%s' "$RAW" \
        | grep -oE '(^|[{,])[[:space:]]*"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
        | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' 2>/dev/null || true)" ;;
  esac
fi
[ -n "$AGENT_ID" ] || exit 0

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
