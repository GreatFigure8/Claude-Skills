#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent) — dev-epic-workflow context budget gate.
#
# The context budget that does not depend on the model noticing. The rule
# ("announce at soft, checkpoint at hard, one work item per session") has failed
# every time it was left to judgement: there is no tidy stopping point, so the
# orchestrator always dispatches one more agent. This hook makes the threshold
# mechanical — past the hard line, dispatching a new subagent is DENIED
# (exit 2 → the message on stderr goes back to the model) until it hands off.
#
# Attribution — why this only ever gates the MAIN session:
# PreToolUse input JSON carries `agent_id` ONLY when the call happens inside a
# subagent. An executor that dispatches further agents is out of scope (and its
# own context is its own problem), so any `agent_id` → allow, unconditionally.
# Same cheap `case "$INPUT" in *'"agent_id"'*)` pre-filter cancel-gate.sh uses,
# then the real extraction, so an escaped occurrence in a tool argument cannot
# accidentally disable the gate for the orchestrator.
#
# Sentinel — written by statusline.sh as a side effect of every render:
#   .claude/signals/context-usage-<session-slug>   # per session; preferred
#   .claude/signals/context-usage                  # generic (no session id)
# `key=value` lines: epoch, session_id, used_tokens, max_tokens,
# used_percentage. Unknown values are OMITTED, never empty. When the payload
# names a session we read that session's file ONLY — in a shared checkout the
# generic file may belong to a different concurrent session, and gating on
# someone else's usage is worse than not gating at all.
#
# Thresholds, first source that yields BOTH values wins:
#   1. env CONTEXT_BUDGET_SOFT_TOKENS / CONTEXT_BUDGET_HARD_TOKENS
#   2. .claude/context-budget            (`soft = 150000` / `hard = 165000`)
#   3. defaults by MODE: sprint 150000/165000, epic 120000/150000
# MODE is `sprint` when .claude/signals/active-epic points at .claude/stories/,
# else `epic`; it also picks which handoff the denial demands.
#
# Must be FAST, and must FAIL OPEN on everything it does not understand:
# no sentinel, a stale one (> CONTEXT_BUDGET_MAX_AGE_SECONDS, default 600),
# an unparseable one, no usage numbers, a misconfigured threshold pair
# (soft >= hard), missing jq AND python3 → exit 0. A budget gate that blocks
# work because it could not read a file is a broken gate, not a strict one.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2> /dev/null || exit 0

# Read (never discard) the hook input JSON, and always drain stdin fully.
INPUT="$(cat 2> /dev/null || true)"

# --- JSON field extraction: jq first, python3 second, neither → fail open. ----
if command -v jq > /dev/null 2>&1; then
  JSON_ENGINE=jq
elif command -v python3 > /dev/null 2>&1; then
  JSON_ENGINE=python3
else
  exit 0
fi

# A payload that does not parse as JSON at all must fail open, decided BEFORE
# any sentinel is consulted — never inferred from a string heuristic, always
# from the JSON engine itself. Covers empty stdin too (neither engine parses
# an empty document).
case "$JSON_ENGINE" in
  jq)
    printf '%s' "$INPUT" | jq -e . > /dev/null 2>&1 || exit 0 ;;
  python3)
    printf '%s' "$INPUT" | python3 -c 'import json,sys
json.load(sys.stdin)' > /dev/null 2>&1 || exit 0 ;;
esac

json_field() {
  case "$JSON_ENGINE" in
    jq)
      printf '%s' "$INPUT" | jq -r --arg k "$1" '.[$k] // empty' 2> /dev/null || true ;;
    python3)
      printf '%s' "$INPUT" | K="$1" python3 -c 'import json,os,sys
try:
    v = json.load(sys.stdin).get(os.environ["K"])
    print("" if v is None else v)
except Exception: pass' 2> /dev/null || true ;;
  esac
}

# Fast path 1: wired without a matcher → only gate agent dispatch.
TOOL_NAME="$(json_field tool_name)"
case "$TOOL_NAME" in
  '' | Agent | Task) ;;
  *) exit 0 ;;
esac

# Fast path 2: MAIN SESSION ONLY. Cheap pre-filter, then the real extraction —
# an escaped "agent_id" inside a tool argument must not exempt the orchestrator.
case "$INPUT" in
  *'"agent_id"'*)
    [ -n "$(json_field agent_id)" ] && exit 0
    ;;
esac

SIGNALS_DIR=".claude/signals"

# Fast path 3: resolve the sentinel for THIS session (never another's).
SESSION_ID="$(json_field session_id)"
if [ -n "$SESSION_ID" ]; then
  SESSION_SLUG="$(printf '%s' "$SESSION_ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64 2> /dev/null || true)"
  [ -n "$SESSION_SLUG" ] || exit 0
  SENTINEL="$SIGNALS_DIR/context-usage-$SESSION_SLUG"
else
  SENTINEL="$SIGNALS_DIR/context-usage"
fi
[ -f "$SENTINEL" ] && [ -r "$SENTINEL" ] || exit 0

# --- Parse the sentinel: plain key=value lines, last wins, keys we know only. -
EPOCH=""; USED_TOKENS=""; MAX_TOKENS=""; USED_PCT=""
while IFS= read -r LINE || [ -n "$LINE" ]; do
  LINE="${LINE%$'\r'}"
  case "$LINE" in
    epoch=*) EPOCH="${LINE#epoch=}" ;;
    used_tokens=*) USED_TOKENS="${LINE#used_tokens=}" ;;
    max_tokens=*) MAX_TOKENS="${LINE#max_tokens=}" ;;
    used_percentage=*) USED_PCT="${LINE#used_percentage=}" ;;
  esac
done < "$SENTINEL"

# A bare integer, nothing else — `case` keeps this parser-free and locale-safe.
is_int() {
  case "${1:-}" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_int "$EPOCH" || exit 0

# Staleness: a sentinel from a render 10 minutes ago no longer describes this
# session. A clock skew that puts the sentinel in the future is equally unusable.
NOW="$(date +%s 2> /dev/null || true)"
is_int "$NOW" || exit 0
MAX_AGE="${CONTEXT_BUDGET_MAX_AGE_SECONDS:-600}"
is_int "$MAX_AGE" || MAX_AGE=600
AGE=$((NOW - EPOCH))
[ "$AGE" -lt 0 ] && exit 0
[ "$AGE" -gt "$MAX_AGE" ] && exit 0

# --- Resolve USED tokens. -----------------------------------------------------
WINDOW="${CONTEXT_BUDGET_WINDOW_TOKENS:-200000}"
is_int "$WINDOW" || WINDOW=200000
[ "$WINDOW" -gt 0 ] || WINDOW=200000

ESTIMATED=no
if is_int "$USED_TOKENS"; then
  USED="$USED_TOKENS"
elif is_int "$USED_PCT" && is_int "$MAX_TOKENS" && [ "$MAX_TOKENS" -gt 0 ]; then
  USED=$((USED_PCT * MAX_TOKENS / 100))
elif is_int "$USED_PCT"; then
  USED=$((USED_PCT * WINDOW / 100))
  ESTIMATED=yes
else
  exit 0
fi

# --- MODE: sprint (dev-story-sprint) vs epic (dev-epic-workflow). -------------
MODE=epic
ACTIVE_EPIC="$SIGNALS_DIR/active-epic"
if [ -f "$ACTIVE_EPIC" ] && [ -r "$ACTIVE_EPIC" ]; then
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%$'\r'}"
    LINE="${LINE#"${LINE%%[![:space:]]*}"}"
    LINE="${LINE%"${LINE##*[![:space:]]}"}"
    [ -n "$LINE" ] || continue
    case "$LINE" in *".claude/stories/"*) MODE=sprint ;; esac
    break
  done < "$ACTIVE_EPIC"
fi

if [ "$MODE" = sprint ]; then
  DEF_SOFT=150000; DEF_HARD=165000
  RULE="dev-story-sprint rule 9"
  HANDOFF="the dev-story-sprint prep-for-clear prompt"
else
  DEF_SOFT=120000; DEF_HARD=150000
  RULE="dev-epic-workflow context budget"
  HANDOFF="the dev-epic-workflow handoff at docs/epics/handoff.md"
fi

# --- Thresholds: env, then .claude/context-budget, then mode defaults. --------
SOFT=""; HARD=""
if [ -n "${CONTEXT_BUDGET_SOFT_TOKENS:-}" ] || [ -n "${CONTEXT_BUDGET_HARD_TOKENS:-}" ]; then
  SOFT="${CONTEXT_BUDGET_SOFT_TOKENS:-}"
  HARD="${CONTEXT_BUDGET_HARD_TOKENS:-}"
fi

if [ -z "$SOFT" ] || [ -z "$HARD" ]; then
  BUDGET_FILE=".claude/context-budget"
  if [ -f "$BUDGET_FILE" ] && [ -r "$BUDGET_FILE" ]; then
    F_SOFT=""; F_HARD=""
    while IFS= read -r LINE || [ -n "$LINE" ]; do
      LINE="${LINE%$'\r'}"
      LINE="${LINE#"${LINE%%[![:space:]]*}"}"
      LINE="${LINE%"${LINE##*[![:space:]]}"}"
      case "$LINE" in '' | '#'*) continue ;; esac
      case "$LINE" in *=*) ;; *) continue ;; esac
      KEY="${LINE%%=*}"; VALUE="${LINE#*=}"
      KEY="${KEY%"${KEY##*[![:space:]]}"}"
      VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
      VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"
      case "$KEY" in
        soft) F_SOFT="$VALUE" ;;
        hard) F_HARD="$VALUE" ;;
      esac
    done < "$BUDGET_FILE"
    if [ -n "$F_SOFT" ] && [ -n "$F_HARD" ]; then
      SOFT="$F_SOFT"; HARD="$F_HARD"
    fi
  fi
fi

if [ -z "$SOFT" ] || [ -z "$HARD" ]; then
  SOFT="$DEF_SOFT"; HARD="$DEF_HARD"
fi

# A misconfigured gate never blocks work.
is_int "$SOFT" || exit 0
is_int "$HARD" || exit 0
[ "$SOFT" -gt 0 ] || exit 0
[ "$HARD" -gt 0 ] || exit 0
[ "$SOFT" -lt "$HARD" ] || exit 0

# --- Decide. ------------------------------------------------------------------
[ "$USED" -lt "$SOFT" ] && exit 0

if [ "$ESTIMATED" = yes ]; then
  MEASURE="~${USED} tokens (ESTIMATED from ${USED_PCT}% of a ${WINDOW}-token window)"
else
  MEASURE="${USED} tokens"
fi

if [ "$USED" -lt "$HARD" ]; then
  # Soft band: ALLOW, but say so — this is the ONLY case that writes stdout.
  TEXT="Context budget: this session is at ${MEASURE}, past the soft threshold of ${SOFT} (hard stop ${HARD}). That is ${RULE}'s stop-dispatching threshold: land what is already in flight, then hand off — do not start new work or dispatch further items."
  if [ "$JSON_ENGINE" = jq ]; then
    jq -cn --arg t "$TEXT" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$t}}' 2> /dev/null || exit 0
  else
    T="$TEXT" python3 -c 'import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["T"]}},separators=(",",":"),ensure_ascii=False))' 2> /dev/null || exit 0
  fi
  exit 0
fi

# Hard band: DENY. Same voice as cancel-gate.sh's deny().
{
  echo "BLOCKED by the dev-epic-workflow context budget gate (used: ${MEASURE}; hard threshold: ${HARD})."
  echo "This session is past its context budget. Do NOT retry or route around this: dispatching"
  echo "another agent from here re-bills the whole context on every remaining turn."
  echo "Stop dispatching immediately. Land what is already in flight (let running items finish,"
  echo "merge or record what they returned), then produce ${HANDOFF}, per ${RULE}."
  echo "Everything already pushed is safe. Clear the session and resume from the handoff."
} >&2
exit 2
