#!/usr/bin/env bash
# Integration test for the dev-epic-workflow context-budget gate's STOP band
# ([STOP, HARD)) in SPRINT mode — runs the repo's real gate script
# (../../../dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh)
# against a throwaway git repo, no network. Usage: bash stop-threshold-integration.sh
# (exit 0 = pass). This is integration-only: it exercises the gate end to end
# through real PreToolUse JSON on stdin and a real context-usage sentinel, and
# does not duplicate or modify the sibling unit-fixture harness
# (context-budget-gate-fixtures.sh), which owns synthetic-PATH/parser-engine
# coverage.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"
GATE="$REPO_ROOT/Skills/dev-epic-workflow/assets/claude-config/hooks/context-budget-gate.sh"
[ -f "$GATE" ] || { echo "ERROR: not found: $GATE" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
cd "$TMP"
mkdir -p .claude/signals

# Sprint mode: active-epic names a .claude/stories/ path — this is what makes
# the gate's mode-default STOP resolve to 160000 (and HARD to 165000).
printf '.claude/stories/x\n' > .claude/signals/active-epic

NOW="$(date +%s)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }

# SOFT is pinned to the STOP value (160000) so the soft-band nudge — which is
# orthogonal to what this test asserts — never fires inside the used-token
# range under test. HARD is pinned to its sprint default (165000) explicitly,
# because the gate only honors either of these two env vars if BOTH are set
# together; leaving HARD unset here would silently fall back to a from-file
# or default SOFT too, undoing the SOFT pin above. STOP itself is left
# unset so this test exercises the real sprint-mode default (160000) driven
# by the active-epic signal above, not an env override.
export CONTEXT_BUDGET_SOFT_TOKENS=160000
export CONTEXT_BUDGET_HARD_TOKENS=165000

# $1=used_tokens  $2=tool_name  ->  sets RC, OUT, ERR
run_gate() {
  local used="$1" tool="$2"
  printf 'epoch=%s\nused_tokens=%s\n' "$NOW" "$used" > .claude/signals/context-usage
  # No session_id in the payload: the gate then reads the generic
  # .claude/signals/context-usage sentinel written above, not a
  # per-session one.
  local payload
  payload="$(printf '{"hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{}}' "$tool")"
  OUT="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$TMP" bash "$GATE" 2>"$TMP/err")"
  RC=$?
  ERR="$(cat "$TMP/err")"
}

# ---------------------------------------------------------------------------
# Decision table (STOP=160000, HARD=165000 sprint defaults):
#   159999, any tool          : exit 0, empty stdout
#   160000, Bash or Read      : exit 0, stdout contains "STOP threshold of 160000"
#   160000, Agent              : exit 0, stdout contains stop context (not silent)
#   165000, Bash or Read      : exit 0, stdout contains stop context (allow)
#   165000, Agent              : exit 2 (deny)
# ---------------------------------------------------------------------------

for TOOL in Bash Read Agent; do
  run_gate 159999 "$TOOL"
  if [ "$RC" = 0 ] && [ -z "$OUT" ]; then ok; else bad "159999/$TOOL: expected exit 0 + empty stdout, got rc=$RC out=[$OUT]"; fi
done

for TOOL in Bash Read; do
  run_gate 160000 "$TOOL"
  if [ "$RC" = 0 ] && case "$OUT" in *"STOP threshold of 160000"*) true ;; *) false ;; esac; then
    ok
  else
    bad "160000/$TOOL: expected exit 0 + stdout containing 'STOP threshold of 160000', got rc=$RC out=[$OUT]"
  fi
done

run_gate 160000 Agent
if [ "$RC" = 0 ] && [ -n "$OUT" ] && case "$OUT" in *"STOP threshold of 160000"*) true ;; *) false ;; esac; then
  ok
else
  bad "160000/Agent: expected exit 0 + non-empty stdout with stop context, got rc=$RC out=[$OUT]"
fi

for TOOL in Bash Read; do
  run_gate 165000 "$TOOL"
  if [ "$RC" = 0 ] && [ -n "$OUT" ] && case "$OUT" in *"STOP threshold of 160000"*) true ;; *) false ;; esac; then
    ok
  else
    bad "165000/$TOOL: expected exit 0 + stdout containing stop context, got rc=$RC out=[$OUT]"
  fi
done

run_gate 165000 Agent
if [ "$RC" = 2 ] && case "$ERR" in *"BLOCKED"*) true ;; *) false ;; esac; then
  ok
else
  bad "165000/Agent: expected exit 2 + stderr containing 'BLOCKED', got rc=$RC err=[$ERR]"
fi

echo "stop-threshold integration: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
