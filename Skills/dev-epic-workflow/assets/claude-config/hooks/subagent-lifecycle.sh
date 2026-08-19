#!/usr/bin/env bash
# SubagentStart / SubagentStop hook — dev-epic-workflow executor lifecycle.
#
# SubagentStart: create a marker in .claude/signals/ (arms the cancel gate and
#                the tool logger) and open a bracket line in the epic status log.
# SubagentStop:  remove the marker(s), close the bracket, and stamp the newest
#                status.json for the current branch as terminal:true so a
#                stuck task-list UI can never masquerade as "still running".
#
# The repo decides, not the sidebar: reconciliation lives on disk.
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
EVENT=""; AGENT_ID=""
if [ -n "$INPUT" ]; then
  if command -v jq > /dev/null 2>&1; then
    EVENT="$(printf '%s' "$INPUT"    | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
    AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // .session_id // empty' 2>/dev/null || true)"
  elif command -v python3 > /dev/null 2>&1; then
    EVENT="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hook_event_name") or "")
except Exception: pass' 2>/dev/null || true)"
    AGENT_ID="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin); print(d.get("agent_id") or d.get("session_id") or "")
except Exception: pass' 2>/dev/null || true)"
  fi
fi
[ -n "$AGENT_ID" ] || AGENT_ID="unknown-$$"
AGENT_ID="$(printf '%s' "$AGENT_ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64)"

SIGNALS_DIR=".claude/signals"
mkdir -p "$SIGNALS_DIR" 2>/dev/null || exit 0

# Resolve the active epic's status dir (newest plan), if any.
EPIC_PLAN="$(ls -t docs/epics/*/plan.md 2>/dev/null | head -1)"
STATUS_DIR=""
if [ -n "$EPIC_PLAN" ]; then
  STATUS_DIR="$(dirname "$EPIC_PLAN")/status"
  mkdir -p "$STATUS_DIR" 2>/dev/null || STATUS_DIR=""
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
BRANCH_SLUG="$(printf '%s' "$BRANCH" | tr '/' '-')"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$EVENT" in
  SubagentStart)
    : > "$SIGNALS_DIR/subagent-active-$AGENT_ID"
    if [ -n "$STATUS_DIR" ]; then
      echo "$NOW | ── SUBAGENT START ($AGENT_ID) on branch $BRANCH ──" \
        >> "$STATUS_DIR/$BRANCH_SLUG.log" 2>/dev/null || true
    fi
    ;;
  SubagentStop)
    rm -f "$SIGNALS_DIR/subagent-active-$AGENT_ID" 2>/dev/null || true
    # Belt-and-braces: clear stale markers older than a day so a crashed run
    # can't leave the cancel gate / logger armed forever.
    find "$SIGNALS_DIR" -name 'subagent-active-*' -mmin +1440 -delete 2>/dev/null || true
    if [ -n "$STATUS_DIR" ]; then
      echo "$NOW | ── SUBAGENT STOP  ($AGENT_ID) on branch $BRANCH ──" \
        >> "$STATUS_DIR/$BRANCH_SLUG.log" 2>/dev/null || true
      # Stamp the item's status.json terminal, preserving its last state.
      STATUS_JSON="$STATUS_DIR/$BRANCH_SLUG.json"
      if [ -f "$STATUS_JSON" ] && command -v python3 > /dev/null 2>&1; then
        python3 - "$STATUS_JSON" "$NOW" << 'PYEOF' 2>/dev/null || true
import json, sys, os, tempfile
path, now = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
d["terminal"] = True
d["updated"] = now
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2); f.write("\n")
os.replace(tmp, path)
PYEOF
      fi
    fi
    ;;
esac

exit 0
