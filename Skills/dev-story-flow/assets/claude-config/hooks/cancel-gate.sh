#!/usr/bin/env bash
# PreToolUse hook — shared deterministic cancel gate (dev-story-flow / dev-story-sprint / dev-epic-workflow).
#
# Cancellation that does not depend on the model noticing: while a cancel
# sentinel exists, every tool call from a SUBAGENT (executor) in this project
# dir is denied (exit 2 → the denial message on stderr is fed back to the
# agent). The orchestrator / main session is NEVER gated, so it can always
# clean up and remove the sentinel.
#
# Attribution — what makes "never gate the orchestrator" actually true:
# PreToolUse input JSON carries `agent_id` ONLY when the call happens inside a
# subagent. No `agent_id` → main session → allow, unconditionally. The
# .claude/signals/subagent-active-* markers are deliberately NOT consulted:
# they say "some subagent is running", never "this call belongs to it", so
# under a marker the old logic denied the orchestrator too and the sentinel
# could not be removed from inside the session (GH #2).
#
# Sentinels (any one triggers the gate):
#   docs/epics/<NN>-<slug>/CANCEL     — cancel executors for that epic
#   .claude/signals/cancel            — cancel all executors in this project dir
#
# Granularity: an EMPTY sentinel cancels every active executor (so does one
# holding nothing but blank lines / #-comments). A sentinel with content
# cancels only the executors it names, one selector per line:
#
#   * an AGENT ID — exact match, or any prefix of 8+ characters. Read the id
#     from `ls .claude/signals/subagent-active-*` or from the "SUBAGENT START
#     (<id>)" bracket in docs/epics/<NN>-<slug>/status/*.log. This is the
#     granular form, and the only one that works under worktree dispatch.
#   * a BRANCH NAME — honoured ONLY in direct (single-checkout) dispatch, where
#     the project dir's branch genuinely is the executor's branch. Hooks always
#     resolve CLAUDE_PROJECT_DIR — the ORCHESTRATOR's checkout — so under
#     `git worktree` dispatch a branch name cannot identify the caller: the
#     item branch never matches, and the orchestrator's branch would match
#     every executor at once. Branch selectors are therefore ignored whenever
#     the repo has linked worktrees; use an agent id (or an empty sentinel).
#
# Must be FAST, and must never break a session on its own errors: malformed
# input, missing jq AND python3, no git, unreadable sentinel → exit 0 (allow).

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

# Read (never discard) the hook input JSON, and always drain stdin fully.
INPUT="$(cat 2>/dev/null || true)"

# Fast path 1: no agent_id anywhere in the payload → main session → allow.
# Cheap pre-filter only; an escaped occurrence inside a tool argument is
# rejected by the real extraction below.
case "$INPUT" in
  *'"agent_id"'*) ;;
  *) exit 0 ;;
esac

SIGNALS_DIR=".claude/signals"

# Fast path 2: collect sentinels; none exist → allow.
SENTINELS=""
[ -f "$SIGNALS_DIR/cancel" ] && SENTINELS="$SIGNALS_DIR/cancel"
for C in docs/epics/*/CANCEL; do
  [ -f "$C" ] && SENTINELS="$SENTINELS $C"
done
[ -z "$SENTINELS" ] && exit 0

# Extract the caller's agent id: jq, python3 fallback, then a parser-free
# grep/sed fallback so the gate keeps working with neither installed. The
# (^|[{,]) anchor stops an escaped \"agent_id\" inside tool_input from matching.
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

# Absent, null, or unparseable → treat as main session → allow (fail open).
[ -n "$AGENT_ID" ] || exit 0

# Same sanitisation the lifecycle hook applies to marker filenames, so a
# selector copied from a marker filename also matches.
AGENT_ID_SLUG="$(printf '%s' "$AGENT_ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64 2>/dev/null || true)"

# Legacy branch selectors: only meaningful without linked worktrees (see header).
LEGACY_BRANCH=""
if [ "$(git worktree list 2>/dev/null | wc -l | tr -d ' ')" = "1" ]; then
  LEGACY_BRANCH="$(git branch --show-current 2>/dev/null || true)"
fi

deny() {
  {
    echo "CANCELLED by cancel gate (sentinel: $1; matched: $2)."
    echo "This work item has been cancelled by the orchestrator. Do NOT retry or route around this."
    echo "Everything already pushed is safe. Stop now and return a summary of exactly where the"
    echo "branch stands: last pushed commit, what was in flight, what remains. No final status"
    echo "write is possible (tool calls are denied); state it in your summary instead."
  } >&2
  exit 2
}

for SENTINEL in $SENTINELS; do
  # Empty sentinel → cancel every executor.
  [ -s "$SENTINEL" ] || deny "$SENTINEL" "empty sentinel (all executors)"

  SELECTORS=0
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%$'\r'}"
    LINE="${LINE#"${LINE%%[![:space:]]*}"}"
    LINE="${LINE%"${LINE##*[![:space:]]}"}"
    [ -n "$LINE" ] || continue
    case "$LINE" in \#*) continue ;; esac
    SELECTORS=$((SELECTORS + 1))

    if [ "$LINE" = "$AGENT_ID" ] || [ "$LINE" = "$AGENT_ID_SLUG" ]; then
      deny "$SENTINEL" "agent id: $LINE"
    fi
    if [ ${#LINE} -ge 8 ]; then
      case "$AGENT_ID" in "$LINE"*) deny "$SENTINEL" "agent id prefix: $LINE" ;; esac
    fi
    if [ -n "$LEGACY_BRANCH" ] && [ "$LINE" = "$LEGACY_BRANCH" ]; then
      deny "$SENTINEL" "branch (direct dispatch): $LINE"
    fi
  done < "$SENTINEL"

  # Content, but no usable selector (whitespace / comments only) → treat as empty.
  [ "$SELECTORS" -gt 0 ] || deny "$SENTINEL" "sentinel has no selectors (all executors)"
done

exit 0
