#!/usr/bin/env bash
# Fixture harness for the dev-epic-workflow context-budget gate:
#   ../context-budget-gate.sh   (PreToolUse — deny Agent dispatch past the hard
#                                 context-usage threshold; ALLOW-with-reminder
#                                 past soft; fail open on anything it cannot
#                                 parse or does not understand)
#
# Runs the REPO copy of the hook against synthetic hook-input JSON and
# synthetic .claude/signals/context-usage* sentinels in a throwaway sandbox.
# Every project dir this suite touches is a fresh `mktemp -d` under the
# sandbox: nothing is ever written into this repo or into ~/.claude, and
# `CLAUDE_PROJECT_DIR` is the only thing that ever points the hook at one.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/context-budget-gate-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# The hook itself needs only `cat`, `date`, and (jq OR python3) — no git, no
# worktrees. Three tool availabilities are exercised:
#   full  — normal PATH (jq present)
#   nojq  — curated PATH with python3 but no jq
#   bare  — curated PATH with neither jq nor python3 (must fail open)
# `env -i` is used for every hook invocation so no ambient CONTEXT_BUDGET_*
# variable, or PATH entry, leaks in from the machine running this suite.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$HOOKS_DIR/context-budget-gate.sh"
[ -f "$GATE" ] || { echo "ERROR: not found: $GATE" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/context-budget-gate-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0

# ---------------------------------------------------------------- sandbox ----

# Curated PATHs for the "no jq" / "no parser" variants. The hook needs only
# cat/date plus an optional JSON engine, so these are tiny.
BIN_NOJQ="$SANDBOX/bin-nojq"; BIN_BARE="$SANDBOX/bin-bare"
mkdir -p "$BIN_NOJQ" "$BIN_BARE"
for t in cat date; do
  p="$(command -v "$t" 2> /dev/null)" || continue
  ln -sf "$p" "$BIN_NOJQ/$t"; ln -sf "$p" "$BIN_BARE/$t"
done
p="$(command -v python3 2> /dev/null)" && ln -sf "$p" "$BIN_NOJQ/python3"
PATH_FULL="$PATH"

path_for() {
  case "$1" in
    full) printf '%s' "$PATH_FULL" ;;
    nojq) printf '%s' "$BIN_NOJQ" ;;
    bare) printf '%s' "$BIN_BARE" ;;
  esac
}

# A fresh, empty project dir for exactly one case. Never reused.
newproj() {
  local d
  d="$(mktemp -d "$SANDBOX/proj.XXXXXX")" || exit 1
  mkdir -p "$d/.claude/signals"
  printf '%s' "$d"
}

write_sentinel() { # $1=path  $2..=key=value lines
  local f="$1"; shift
  : > "$f"
  for kv in "$@"; do printf '%s\n' "$kv" >> "$f"; done
}

# --------------------------------------------------------------- fixtures ----

FX="$SANDBOX/fx"; mkdir -p "$FX"

# Main-session Agent dispatch, session known.
cat > "$FX/agent-main.json" <<'EOF'
{"session_id":"sess-1","hook_event_name":"PreToolUse","tool_name":"Agent",
 "tool_input":{"subagent_type":"general-purpose","description":"grep the repo"}}
EOF

# Main-session Agent dispatch, no session id in the payload at all.
cat > "$FX/agent-main-nosession.json" <<'EOF'
{"hook_event_name":"PreToolUse","tool_name":"Agent",
 "tool_input":{"subagent_type":"general-purpose"}}
EOF

# A SUBAGENT dispatching a further agent: agent_id present. Out of scope for
# this gate no matter what the sentinel says.
cat > "$FX/agent-subagent.json" <<'EOF'
{"session_id":"sess-1","hook_event_name":"PreToolUse","tool_name":"Agent",
 "agent_id":"sub-item-7-xyz","agent_type":"work-item-executor",
 "tool_input":{"subagent_type":"general-purpose"}}
EOF

printf 'not json at all\n' > "$FX/garbage.json"
printf '%s' '{"session_id":"sess-1","hook_event_name":"PreToolUse","tool_name":"Agent"' \
  > "$FX/truncated.json"

# ---------------------------------------------------------------- helpers ----

run_gate() { # $1=proj  $2=fixture  $3=variant  $4..=EXTRA_ENV KEY=VALUE
  local proj="$1" fixture="$2" variant="$3"; shift 3
  env -i PATH="$(path_for "$variant")" CLAUDE_PROJECT_DIR="$proj" "$@" \
    /bin/bash "$GATE" < "$fixture" > "$SANDBOX/out" 2> "$SANDBOX/err"
  RC=$?
}

stdout_state() { [ -s "$SANDBOX/out" ] && echo nonempty || echo empty; }

json_ok() { # well-formed hookSpecificOutput.additionalContext on $SANDBOX/out
  if command -v jq > /dev/null 2>&1; then
    jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"
           and (.hookSpecificOutput.additionalContext | type == "string")
           and (.hookSpecificOutput.additionalContext | length > 0)' \
      "$SANDBOX/out" > /dev/null 2>&1
  else
    SANDBOX="$SANDBOX" python3 -c '
import json, os
d = json.load(open(os.path.join(os.environ["SANDBOX"], "out")))
c = d["hookSpecificOutput"]
assert c["hookEventName"] == "PreToolUse"
assert isinstance(c["additionalContext"], str) and c["additionalContext"]
' > /dev/null 2>&1
  fi
}

check() { # $1 label  $2 expected  $3 actual  $4 tag
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-62s %-5s exp=%-8s got=%-8s %s\n' "$1" "${4:-}" "$2" "$3" "$R"
}

echo "sandbox: $SANDBOX"
echo "gate:    $GATE"
echo "bash:    $(/bin/bash --version | head -1)"
echo

# =========================================================================
# A: decision ladder — env thresholds soft=1000 hard=2000, generic sentinel,
#    no session id in the payload. Boundaries: soft-1, ==soft, mid,
#    hard-1, ==hard, above hard. Both parsing engines.
# =========================================================================
echo "=== A: decision ladder (soft=1000 hard=2000) ============================"
for V in full nojq; do
  # used < soft: no sentinel at all.
  PROJ="$(newproj)"
  run_gate "$PROJ" "$FX/agent-main-nosession.json" "$V" \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
  check "A: no sentinel -> allow [exit]" 0 "$RC" "$V"
  check "A: no sentinel -> allow [stdout]" empty "$(stdout_state)" "$V"

  NOW="$(date +%s)"
  for ROW in "999:0:empty" "1000:0:nonempty" "1500:0:nonempty" \
             "1999:0:nonempty" "2000:2:n/a" "2500:2:n/a"; do
    USED="${ROW%%:*}"; REST="${ROW#*:}"; EXP_RC="${REST%%:*}"; EXP_OUT="${REST#*:}"
    PROJ="$(newproj)"
    write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=$USED"
    run_gate "$PROJ" "$FX/agent-main-nosession.json" "$V" \
      CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
    check "A: used=$USED [exit]" "$EXP_RC" "$RC" "$V"
    if [ "$EXP_RC" = 0 ]; then
      check "A: used=$USED [stdout]" "$EXP_OUT" "$(stdout_state)" "$V"
      [ "$EXP_OUT" = nonempty ] && { json_ok && J=ok || J=bad; check "A: used=$USED [json]" ok "$J" "$V"; }
    else
      [ -s "$SANDBOX/err" ] && grep -q BLOCKED "$SANDBOX/err" && S=ok || S=bad
      check "A: used=$USED [stderr has BLOCKED]" ok "$S" "$V"
    fi
  done
done

# =========================================================================
# B: fail-open sentinel shapes (engine-independent — sentinel parsing is
#    plain bash, not JSON).
# =========================================================================
echo
echo "=== B: sentinel fail-open cases =========================================="
NOW="$(date +%s)"

PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "this is not a valid sentinel" "###" "random garbage"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "B: malformed/unparseable sentinel -> fail open" 0 "$RC" full

PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 700))" "used_tokens=5000"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "B: stale sentinel (age>600s) would-deny value -> fail open" 0 "$RC" full

PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "B: sentinel with no usage numbers -> fail open" 0 "$RC" full

# =========================================================================
# C: unparseable stdin payload -> fail open, decided before any sentinel is
#    consulted. A hard-threshold sentinel is present to prove it is ignored.
# =========================================================================
echo
echo "=== C: unparseable stdin payload =========================================="
NOW="$(date +%s)"
for V in full nojq; do
  for FIX in garbage truncated; do
    PROJ="$(newproj)"
    write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=9999"
    run_gate "$PROJ" "$FX/$FIX.json" "$V" \
      CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
    check "C: $FIX stdin -> fail open [exit]" 0 "$RC" "$V"
    check "C: $FIX stdin -> fail open [stdout]" empty "$(stdout_state)" "$V"
  done
done

# =========================================================================
# D: a subagent dispatching a further agent (agent_id present) is untouched,
#    even under a hard-threshold sentinel. Also the "neither jq nor
#    python3" fail-open path.
# =========================================================================
echo
echo "=== D: subagent (agent_id present) untouched; no-parser fail-open ========"
NOW="$(date +%s)"
for V in full nojq; do
  PROJ="$(newproj)"
  write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=9999"
  run_gate "$PROJ" "$FX/agent-subagent.json" "$V" \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
  check "D: agent_id present -> untouched [exit]" 0 "$RC" "$V"
  check "D: agent_id present -> untouched [stdout]" empty "$(stdout_state)" "$V"
done

PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=9999"
run_gate "$PROJ" "$FX/agent-main-nosession.json" bare \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "D: neither jq nor python3 -> fail open" 0 "$RC" bare

# =========================================================================
# E: per-session sentinel resolution — per-session file preferred; NEVER
#    falls back to the generic file when a session id is present.
# =========================================================================
echo
echo "=== E: per-session sentinel resolution ===================================="
NOW="$(date +%s)"

# session_id present, only the GENERIC file exists (with a deny-level value):
# must allow — no fallback.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=9999"
run_gate "$PROJ" "$FX/agent-main.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "E: session_id present, no per-session file -> allow [exit]" 0 "$RC" full
check "E: session_id present, no per-session file -> allow [stdout]" empty "$(stdout_state)" full

# session_id present, per-session file (soft band) AND generic file (deny)
# both exist: per-session file must win.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=9999"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1500"
run_gate "$PROJ" "$FX/agent-main.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000
check "E: per-session file preferred over generic [exit]" 0 "$RC" full
check "E: per-session file preferred over generic [stdout]" nonempty "$(stdout_state)" full
{ json_ok && J=ok || J=bad; }; check "E: per-session file preferred over generic [json]" ok "$J" full

# =========================================================================
# F: threshold resolution order — env, then .claude/context-budget, then
#    mode defaults (sprint vs epic) driven by .claude/signals/active-epic.
# =========================================================================
echo
echo "=== F: threshold resolution order =========================================="
NOW="$(date +%s)"

# env beats the config file.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=550"
printf 'soft = 100000\nhard = 110000\n' > "$PROJ/.claude/context-budget"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=500 CONTEXT_BUDGET_HARD_TOKENS=600
check "F: env overrides config file [exit]" 0 "$RC" full
check "F: env overrides config file [stdout]" nonempty "$(stdout_state)" full

# config file beats mode defaults (no env set).
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=550"
printf 'soft = 500\nhard = 600\n' > "$PROJ/.claude/context-budget"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full
check "F: config file overrides mode defaults [exit]" 0 "$RC" full
check "F: config file overrides mode defaults [stdout]" nonempty "$(stdout_state)" full

# mode default: epic (no active-epic signal) -> soft=120000 hard=150000.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=130000"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full
check "F: epic mode default (soft band) [exit]" 0 "$RC" full
check "F: epic mode default (soft band) [stdout]" nonempty "$(stdout_state)" full
TXT="$(command -v jq > /dev/null 2>&1 && jq -r '.hookSpecificOutput.additionalContext' "$SANDBOX/out" \
  || python3 -c 'import json;print(json.load(open("'"$SANDBOX"'/out"))["hookSpecificOutput"]["additionalContext"])')"
case "$TXT" in *"dev-epic-workflow context budget"*) M=ok ;; *) M=bad ;; esac
check "F: epic mode default names the epic rule" ok "$M" full

# mode default: sprint (active-epic points at .claude/stories/) -> soft=150000
# hard=165000. used=155000 would DENY under epic defaults (hard=150000), so
# a soft-band allow here proves sprint mode, not just "some soft band", won.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=155000"
printf '.claude/stories/context-budget-gate/status\n' > "$PROJ/.claude/signals/active-epic"
run_gate "$PROJ" "$FX/agent-main-nosession.json" full
check "F: sprint mode default (soft band, not epic's hard) [exit]" 0 "$RC" full
check "F: sprint mode default (soft band) [stdout]" nonempty "$(stdout_state)" full
TXT="$(command -v jq > /dev/null 2>&1 && jq -r '.hookSpecificOutput.additionalContext' "$SANDBOX/out" \
  || python3 -c 'import json;print(json.load(open("'"$SANDBOX"'/out"))["hookSpecificOutput"]["additionalContext"])')"
case "$TXT" in *"dev-story-sprint rule 9"*) M=ok ;; *) M=bad ;; esac
check "F: sprint mode default names rule 9" ok "$M" full

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
