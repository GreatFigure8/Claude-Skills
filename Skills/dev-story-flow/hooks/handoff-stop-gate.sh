#!/usr/bin/env bash
# Stop hook — shared hand-off gate (dev-story-flow / dev-story-sprint / dev-epic-workflow).
#
# The other half of the context budget. context-budget-gate.sh (PreToolUse)
# can only nudge or refuse a dispatch; it cannot stop the session ENDING with
# the hand-off unwritten. That is the failure that actually costs: the turn
# ends, the session sits at 160K, and the next prompt re-bills all of it
# because nobody ran /clear-prompt. This hook blocks the turn from ending
# ONCE, past the STOP threshold, with the same stop-band text the PreToolUse
# gate already speaks — so the model's next move is the hand-off.
#
# `Stop` hook contract (no `matcher` — it has no meaning for Stop):
#   stdin JSON: session_id, transcript_path, cwd, hook_event_name,
#               permission_mode, stop_hook_active, last_assistant_message
#   BLOCK = a TOP-LEVEL {"decision":"block","reason":"..."} on stdout, exit 0.
#           (NOT nested under hookSpecificOutput — that shape is ignored here.)
#   ALLOW = EMPTY stdout, exit 0. Silence is mandatory on every allow path:
#           any non-JSON stdout from a Stop hook exiting 0 is surfaced as a
#           hook error in the transcript, so a stray echo is a visible bug.
#
# ONE forced retry, never a loop. Two independent guards:
#   1. `stop_hook_active` — true when this Stop is itself the continuation of
#      a previous block. Claude Code also hard-caps at 8 consecutive blocks,
#      but this is the primary guard and it is checked first.
#   2. `.claude/signals/handoff-stop-gate-<session-slug>` — written BEFORE the
#      block is printed, so even a crash mid-print cannot yield a second block
#      for this session. The marker is per session, same slug convention
#      context-budget-gate.sh uses for its context-usage-<slug> sentinel.
#
# Decision ladder, first match wins (everything but the last row is a silent
# allow):
#   1. stop_hook_active                                  -> allow
#   2. handoff-stop-gate marker already exists           -> allow
#   3. no fresh context-usage sentinel                   -> allow
#   4. USED < STOP                                       -> allow
#   5. sprint mode + prep-for-clear-<slug>.md exists     -> allow (posted)
#   6. epic mode + docs/epics/handoff.md newer than the
#      sentinel's epoch                                  -> allow (written)
#   7. otherwise                                         -> BLOCK (once)
#
# FAIL OPEN on everything it does not understand — no sentinel, a stale or
# unparseable one, no usage numbers, a misconfigured threshold pair, missing
# jq AND python3, an unwritable marker, no working mtime tool. A gate that
# refuses to let a turn end because it could not read a file is a broken gate.

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

# --- JSON field extraction: jq first, python3 second, neither -> fail open. ---
if command -v jq > /dev/null 2>&1; then
  JSON_ENGINE=jq
elif command -v python3 > /dev/null 2>&1; then
  JSON_ENGINE=python3
else
  exit 0
fi

# A payload that does not parse as JSON at all must fail open, decided BEFORE
# anything on disk is consulted — never inferred from a string heuristic,
# always from the JSON engine itself. Covers empty stdin too.
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

# Booleans need their own extractor: `false` is falsy to jq's `//` and python
# renders True/False capitalised. Prints `true` for boolean true, else empty.
json_flag() {
  case "$JSON_ENGINE" in
    jq)
      printf '%s' "$INPUT" | jq -r --arg k "$1" 'if .[$k] == true then "true" else "" end' 2> /dev/null || true ;;
    python3)
      printf '%s' "$INPUT" | K="$1" python3 -c 'import json,os,sys
try:
    print("true" if json.load(sys.stdin).get(os.environ["K"]) is True else "")
except Exception: pass' 2> /dev/null || true ;;
  esac
}

# --- Row 1: loop guard. This Stop is the continuation of a previous block. ----
[ "$(json_flag stop_hook_active)" = true ] && exit 0

SIGNALS_DIR=".claude/signals"

# Session scoping: per-session marker and sentinel, never another session's.
# In a shared checkout the generic files may belong to a concurrent session;
# gating on someone else's usage is worse than not gating at all.
SESSION_ID="$(json_field session_id)"
SESSION_SLUG=""
if [ -n "$SESSION_ID" ]; then
  SESSION_SLUG="$(session_slug_for "$SESSION_ID")"
  [ -n "$SESSION_SLUG" ] || exit 0
  MARKER="$SIGNALS_DIR/handoff-stop-gate-$SESSION_SLUG"
  SENTINEL="$SIGNALS_DIR/context-usage-$SESSION_SLUG"
else
  MARKER="$SIGNALS_DIR/handoff-stop-gate"
  SENTINEL="$SIGNALS_DIR/context-usage"
fi

# --- Row 2: already blocked once this session. One forced retry, not a loop. --
[ -e "$MARKER" ] && exit 0

# --- Row 3: no fresh sentinel. -----------------------------------------------
[ -f "$SENTINEL" ] && [ -r "$SENTINEL" ] || exit 0

read_sentinel "$SENTINEL"
is_int "$EPOCH" || exit 0

NOW="$(date +%s 2> /dev/null || true)"
is_int "$NOW" || exit 0
MAX_AGE="${CONTEXT_BUDGET_MAX_AGE_SECONDS:-600}"
is_int "$MAX_AGE" || MAX_AGE=600
AGE=$((NOW - EPOCH))
[ "$AGE" -lt 0 ] && exit 0
[ "$AGE" -gt "$MAX_AGE" ] && exit 0

# --- Resolve USED tokens (same ladder as context-budget-gate.sh). -------------
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

# --- Row 4: still under the STOP threshold. ----------------------------------
[ "$USED" -lt "$STOP" ] && exit 0

# --- Row 5: sprint mode, the prep-for-clear hand-off is already posted. ------
if [ "$MODE" = sprint ] && [ -n "$SESSION_SLUG" ]; then
  [ -e "$SIGNALS_DIR/prep-for-clear-$SESSION_SLUG.md" ] && exit 0
fi

# mtime in seconds, portably: BSD `date -r` (also GNU's --reference), then BSD
# `stat -f %m`, then GNU `stat -c %Y`. Returns 1 when none of them work.
file_mtime() {
  FM_V="$(date -r "$1" +%s 2> /dev/null || true)"
  is_int "$FM_V" && { printf '%s' "$FM_V"; return 0; }
  FM_V="$(stat -f %m "$1" 2> /dev/null || true)"
  is_int "$FM_V" && { printf '%s' "$FM_V"; return 0; }
  FM_V="$(stat -c %Y "$1" 2> /dev/null || true)"
  is_int "$FM_V" && { printf '%s' "$FM_V"; return 0; }
  return 1
}

# --- Row 6: epic mode, docs/epics/handoff.md written since the sentinel. ------
# A handoff.md OLDER than the sentinel is last session's file, not this one's.
# No working mtime tool -> allow: never block over a tooling failure.
if [ "$MODE" != sprint ] && [ -f "docs/epics/handoff.md" ]; then
  HANDOFF_MTIME="$(file_mtime "docs/epics/handoff.md")" || exit 0
  [ "$HANDOFF_MTIME" -gt "$EPOCH" ] && exit 0
fi

# --- Row 7: BLOCK, exactly once. ---------------------------------------------
if [ "$ESTIMATED" = yes ]; then
  MEASURE="~${USED} tokens (ESTIMATED from ${USED_PCT}% of a ${WINDOW}-token window)"
else
  MEASURE="${USED} tokens"
fi

HANDOFF_SENTENCE="$(handoff_sentence "$SIGNALS_DIR")"

STOP_TEXT="This turn may not end yet: Context budget: this session is at ${MEASURE}, past the STOP threshold of ${STOP} (hard stop ${HARD}). Find a stopping point now, per ${RULE}: do not wait for running agents, do not start any new step. Make the on-disk state truthful (${STATE}), commit, push, then produce ${HANDOFF}. Everything already pushed is safe. ${HANDOFF_SENTENCE}"

# Marker FIRST: a crash between here and the print must never produce a second
# block. An unwritable signals dir is a misconfigured install -> fail open.
printf 'epoch=%s\nused_tokens=%s\n' "$NOW" "$USED" > "$MARKER" 2> /dev/null || exit 0

if [ "$JSON_ENGINE" = jq ]; then
  jq -cn --arg r "$STOP_TEXT" '{decision:"block",reason:$r}' 2> /dev/null || exit 0
else
  R="$STOP_TEXT" python3 -c 'import json,os
print(json.dumps({"decision":"block","reason":os.environ["R"]},separators=(",",":"),ensure_ascii=False))' 2> /dev/null || exit 0
fi
exit 0
