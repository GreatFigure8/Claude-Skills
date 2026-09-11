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
# STOP resolves independently, same source order (env CONTEXT_BUDGET_STOP_TOKENS
# -> .claude/context-budget `stop=` -> mode default): sprint 160000; epic
# defaults to the resolved HARD, i.e. an empty/disabled STOP..HARD band.
# MODE is `sprint` when .claude/signals/active-epic points at .claude/stories/,
# else `epic`; it also picks which handoff the denial demands.
#
# Must be FAST, and must FAIL OPEN on everything it does not understand:
# no sentinel, a stale one (> CONTEXT_BUDGET_MAX_AGE_SECONDS, default 600),
# an unparseable one, no usage numbers, a misconfigured threshold pair
# (soft >= hard), missing jq AND python3 → exit 0. A budget gate that blocks
# work because it could not read a file is a broken gate, not a strict one.

set -u

# Resolve the shared lib RELATIVE TO THIS SCRIPT, and do it before the cd below
# moves us to the project dir. Builtins only (`cd`/`pwd`, not `dirname`): this
# runs before the PATH is known to hold anything, and a hook that needs a
# coreutil to find its own library is a hook that breaks on a thin PATH.
# A missing or unreadable lib is a misconfigured install, and a misconfigured
# gate never blocks work: fail open.
LIB_SRC="${BASH_SOURCE[0]:-$0}"
LIB_DIR="${LIB_SRC%/*}"
[ "$LIB_DIR" = "$LIB_SRC" ] && LIB_DIR="."
LIB_DIR="$(cd "$LIB_DIR" 2> /dev/null && pwd)" || exit 0
[ -n "$LIB_DIR" ] && [ -r "$LIB_DIR/context-budget-lib.sh" ] || exit 0
# shellcheck source=./context-budget-lib.sh
. "$LIB_DIR/context-budget-lib.sh" || exit 0

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

# Fast path 1: wired without a matcher → any tool reaches the decide block
# below, but only agent dispatch (Agent/Task, or no tool_name at all) counts
# as a dispatch for the soft-band nudge and the hard-band deny; every other
# tool only ever sees the stop-band nudge (allow) in the STOP..HARD band.
TOOL_NAME="$(json_field tool_name)"
case "$TOOL_NAME" in
  '' | Agent | Task) IS_DISPATCH=yes ;;
  *) IS_DISPATCH=no ;;
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
  SESSION_SLUG="$(session_slug_for "$SESSION_ID")"
  [ -n "$SESSION_SLUG" ] || exit 0
  SENTINEL="$SIGNALS_DIR/context-usage-$SESSION_SLUG"
else
  SENTINEL="$SIGNALS_DIR/context-usage"
fi
[ -f "$SENTINEL" ] && [ -r "$SENTINEL" ] || exit 0

# --- Parse the sentinel (see read_sentinel in context-budget-lib.sh). ---------
read_sentinel "$SENTINEL"

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

# --- MODE + thresholds (see context-budget-lib.sh). ---------------------------
# resolve_mode sets MODE/DEF_SOFT/DEF_HARD/RULE/HANDOFF/STATE; resolve_thresholds
# then reads those defaults and sets SOFT/HARD/STOP.
resolve_mode "$SIGNALS_DIR"
resolve_thresholds

# A misconfigured gate never blocks work.
is_int "$SOFT" || exit 0
is_int "$HARD" || exit 0
is_int "$STOP" || exit 0
[ "$SOFT" -gt 0 ] || exit 0
[ "$HARD" -gt 0 ] || exit 0
[ "$SOFT" -lt "$HARD" ] || exit 0
[ "$SOFT" -le "$STOP" ] || exit 0
[ "$STOP" -le "$HARD" ] || exit 0

# --- Decide. ------------------------------------------------------------------
[ "$USED" -lt "$SOFT" ] && exit 0

if [ "$ESTIMATED" = yes ]; then
  MEASURE="~${USED} tokens (ESTIMATED from ${USED_PCT}% of a ${WINDOW}-token window)"
else
  MEASURE="${USED} tokens"
fi

emit_context() {
  if [ "$JSON_ENGINE" = jq ]; then
    jq -cn --arg t "$1" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$t}}' 2> /dev/null || exit 0
  else
    T="$1" python3 -c 'import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["T"]}},separators=(",",":"),ensure_ascii=False))' 2> /dev/null || exit 0
  fi
  exit 0
}

HANDOFF_SENTENCE="$(handoff_sentence "$SIGNALS_DIR")"

STOP_TEXT="Context budget: this session is at ${MEASURE}, past the STOP threshold of ${STOP} (hard stop ${HARD}). Find a stopping point now, per ${RULE}: do not wait for running agents, do not start any new step. Make the on-disk state truthful (${STATE}), commit, push, then produce ${HANDOFF}. Everything already pushed is safe. ${HANDOFF_SENTENCE}"

if [ "$USED" -lt "$STOP" ]; then
  # Soft band [SOFT, STOP): only a dispatch tool gets the nudge; every other
  # tool in the main session stays silent.
  [ "$IS_DISPATCH" = yes ] || exit 0
  TEXT="Context budget: this session is at ${MEASURE}, past the soft threshold of ${SOFT} (hard stop ${HARD}). That is ${RULE}'s stop-dispatching threshold: land what is already in flight, then hand off — do not start new work or dispatch further items."
  emit_context "$TEXT"
fi

if [ "$USED" -lt "$HARD" ]; then
  # Stop band [STOP, HARD): ALLOW for every tool, dispatch or not, but say so.
  emit_context "$STOP_TEXT"
fi

if [ "$IS_DISPATCH" != yes ]; then
  # Hard band [HARD, ...), non-dispatch tool: still ALLOW, still the stop nudge.
  emit_context "$STOP_TEXT"
fi

# Hard band, dispatch: DENY. Same voice as cancel-gate.sh's deny().
{
  echo "BLOCKED by the dev-epic-workflow context budget gate (used: ${MEASURE}; hard threshold: ${HARD})."
  echo "This session is past its context budget. Do NOT retry or route around this: dispatching"
  echo "another agent from here re-bills the whole context on every remaining turn."
  echo "Stop dispatching immediately. Land what is already in flight (let running items finish,"
  echo "merge or record what they returned), then produce ${HANDOFF}, per ${RULE}."
  echo "Everything already pushed is safe. Clear the session and resume from the handoff. ${HANDOFF_SENTENCE}"
} >&2
exit 2
