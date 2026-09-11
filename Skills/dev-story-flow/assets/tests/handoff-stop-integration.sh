#!/usr/bin/env bash
# Integration test for the dev-epic-workflow Stop-hook hand-off gate
# (handoff-stop-gate.sh) working end to end through a REAL --user install,
# a real Stop-hook JSON payload, and a real SessionStart(source=clear) call
# into session-start-context.sh. No network, no jq/python assumptions beyond
# what the hooks themselves already require. Usage:
#   bash handoff-stop-integration.sh   (exit 0 = pass)
#
# This is integration-only: the decision table (allow/block rows) is owned
# exhaustively by a sibling fixture suite. This proves the pieces installed
# together actually cooperate.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$HERE/../../../dev-epic-workflow/assets/claude-config/install.sh"

TMP_HOME="$(mktemp -d)"
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME" "$TMP_REPO"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

# --- Step 1: real --user install into a throwaway HOME. ----------------------
INSTALL_OUT="$(mktemp "${TMPDIR:-/tmp}/handoff-stop-install-out.XXXXXX")"
if ! HOME="$TMP_HOME" bash "$INSTALL_SH" --user >"$INSTALL_OUT" 2>&1; then
  bad "install.sh --user exited nonzero"
  cat "$INSTALL_OUT" >&2
fi
rm -f "$INSTALL_OUT"
HOOK_STOP="$TMP_HOME/.claude/hooks/handoff-stop-gate.sh"
HOOK_START="$TMP_HOME/.claude/hooks/session-start-context.sh"
HOOK_LIB="$TMP_HOME/.claude/hooks/context-budget-lib.sh"
check "handoff-stop-gate.sh installed"        '[ -x "$HOOK_STOP" ]'
check "session-start-context.sh installed"     '[ -x "$HOOK_START" ]'
check "context-budget-lib.sh installed"        '[ -f "$HOOK_LIB" ]'

# --- Step 2: temp git repo + sprint-mode signals. -----------------------------
git -C "$TMP_REPO" init -q
UNIT="demo-sprint"
SESSION_ID="demo-session-1"

# Source the INSTALLED lib to derive the session slug the exact same way the
# gate does — no reimplementation of session_slug_for() in this test.
# shellcheck source=/dev/null
. "$HOOK_LIB"
SESSION_SLUG="$(session_slug_for "$SESSION_ID")"

mkdir -p "$TMP_REPO/.claude/signals" "$TMP_REPO/docs/sprints/$UNIT"
printf '%s\n' ".claude/stories/$UNIT/status" > "$TMP_REPO/.claude/signals/active-epic"
printf 'epoch=%s\nused_tokens=160000\n' "$(date +%s)" \
  > "$TMP_REPO/.claude/signals/context-usage-$SESSION_SLUG"
cat > "$TMP_REPO/docs/sprints/$UNIT/sprint.json" <<EOF
{
  "status": "executing"
}
EOF

PAYLOAD='{"session_id":"'"$SESSION_ID"'","stop_hook_active":false,"transcript_path":"","cwd":"'"$TMP_REPO"'","hook_event_name":"Stop","permission_mode":"default","last_assistant_message":""}'

json_field_py() {
  # $1 = json text on stdin already, $2 = field name
  python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get(sys.argv[1], "") or "")
except Exception:
    print("")
' "$2" 2>/dev/null
}

# --- Step 3: first Stop call — past STOP, no hand-off posted yet -> BLOCK. ----
OUT1="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP_REPO" "$HOOK_STOP")"
RC1=$?
DECISION1="$(printf '%s' "$OUT1" | json_field_py x decision)"
REASON1="$(printf '%s' "$OUT1" | json_field_py x reason)"
check "step3: hook exits 0"                    '[ "$RC1" = 0 ]'
check "step3: decision is block"               '[ "$DECISION1" = block ]'
check "step3: reason names the clear-prompt skill call" \
  'case "$REASON1" in *"Skill({skill: \"clear-prompt\""*) true ;; *) false ;; esac'
check "step3: per-session marker was written"  '[ -e "$TMP_REPO/.claude/signals/handoff-stop-gate-$SESSION_SLUG" ]'

# --- Step 4: prep-for-clear posted, re-run same input -> allow (empty, rc 0). -
printf 'prep content\n' > "$TMP_REPO/.claude/signals/prep-for-clear-$SESSION_SLUG.md"
OUT2="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP_REPO" "$HOOK_STOP")"
RC2=$?
check "step4: hook exits 0"                    '[ "$RC2" = 0 ]'
check "step4: allow is silent"                 '[ -z "$OUT2" ]'

# --- Step 5: remove prep file, re-run -> STILL allow (once-per-session marker,
# not the prep-for-clear file, is what is keeping this open). ------------------
rm -f "$TMP_REPO/.claude/signals/prep-for-clear-$SESSION_SLUG.md"
OUT3="$(printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP_REPO" "$HOOK_STOP")"
RC3=$?
check "step5: hook exits 0"                    '[ "$RC3" = 0 ]'
check "step5: allow is still silent"           '[ -z "$OUT3" ]'

# --- Step 6: SessionStart(source=clear) surfaces a FRESH prep-for-clear note
# and deletes it. ---------------------------------------------------------------
FRESH_SLUG="demo-session-2"
FRESH_CONTENT="Fresh handoff body for the session-start surfacing check."
FRESH_FILE="$TMP_REPO/.claude/signals/prep-for-clear-$FRESH_SLUG.md"
printf '%s\n' "$FRESH_CONTENT" > "$FRESH_FILE"

START_PAYLOAD='{"source":"clear","session_id":"'"$SESSION_ID"'"}'
OUT4="$(printf '%s' "$START_PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP_REPO" "$HOOK_START")"
check "step6: output has the prep-for-clear heading" \
  'printf "%s" "$OUT4" | grep -qF "### Prep-for-clear from the previous session"'
check "step6: output contains the fresh content"     \
  'printf "%s" "$OUT4" | grep -qF "$FRESH_CONTENT"'
check "step6: the prep-for-clear file is gone afterward" '[ ! -e "$FRESH_FILE" ]'

echo "handoff-stop integration: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
