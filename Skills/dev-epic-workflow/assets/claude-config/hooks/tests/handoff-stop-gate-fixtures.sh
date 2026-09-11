#!/usr/bin/env bash
# Fixture harness for the dev-epic-workflow hand-off Stop gate:
#   ../handoff-stop-gate.sh   (Stop — block the turn from ending ONCE past the
#                               STOP threshold when the hand-off has not been
#                               produced; allow SILENTLY on every other path;
#                               fail open on anything it cannot parse)
#
# Runs the REPO copy of the hook against synthetic Stop hook-input JSON and
# synthetic .claude/signals/* files in a throwaway sandbox. Every project dir
# this suite touches is a fresh `mktemp -d` under the sandbox: nothing is ever
# written into this repo or into ~/.claude, and `CLAUDE_PROJECT_DIR` is the
# only thing that ever points the hook at one.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/handoff-stop-gate-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# The hook needs only `cat`, `date`, and (jq OR python3). Three tool
# availabilities are exercised:
#   full  — normal PATH (jq present)
#   nojq  — curated PATH with python3 but no jq
#   bare  — curated PATH with neither jq nor python3 (must fail open)
# `env -i` is used for every hook invocation so no ambient CONTEXT_BUDGET_*
# variable, or PATH entry, leaks in from the machine running this suite.
#
# NOTE on session ids: the curated nojq/bare PATHs deliberately omit `tr` and
# `cut`, which context-budget-lib.sh's session_slug_for needs. A payload WITH
# a session_id therefore fails open under those variants by design (same as
# context-budget-gate.sh). Session-scoped rows are exercised on `full`; the
# nojq/bare rows use the no-session payloads, which fall back to the generic
# .claude/signals/context-usage and .claude/signals/handoff-stop-gate names.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$HOOKS_DIR/handoff-stop-gate.sh"
[ -f "$GATE" ] || { echo "ERROR: not found: $GATE" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/handoff-stop-gate-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0

# ---------------------------------------------------------------- sandbox ----

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

sprint_signal() { printf '.claude/stories/2026-09-11-002/status\n' > "$1/.claude/signals/active-epic"; }

# --------------------------------------------------------------- fixtures ----

FX="$SANDBOX/fx"; mkdir -p "$FX"

# A normal Stop: session known, not a continuation of a previous block.
cat > "$FX/stop.json" <<'EOF'
{"session_id":"sess-1","transcript_path":"/tmp/t.jsonl","cwd":"/tmp",
 "hook_event_name":"Stop","permission_mode":"default","stop_hook_active":false,
 "last_assistant_message":"Done."}
EOF

# The same Stop with no session_id at all -> generic signal filenames.
cat > "$FX/stop-nosession.json" <<'EOF'
{"transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"Stop",
 "permission_mode":"default","stop_hook_active":false,
 "last_assistant_message":"Done."}
EOF

# A Stop that is itself the continuation of a previous block (row 1).
cat > "$FX/stop-active.json" <<'EOF'
{"session_id":"sess-1","transcript_path":"/tmp/t.jsonl","cwd":"/tmp",
 "hook_event_name":"Stop","permission_mode":"default","stop_hook_active":true,
 "last_assistant_message":"Still going."}
EOF

cat > "$FX/stop-active-nosession.json" <<'EOF'
{"transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"Stop",
 "permission_mode":"default","stop_hook_active":true,
 "last_assistant_message":"Still going."}
EOF

# stop_hook_active omitted entirely — must behave exactly like false.
cat > "$FX/stop-noflag-nosession.json" <<'EOF'
{"transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"Stop",
 "last_assistant_message":"Done."}
EOF

printf 'not json at all\n' > "$FX/garbage.json"
printf '%s' '{"session_id":"sess-1","hook_event_name":"Stop"' > "$FX/truncated.json"

# ---------------------------------------------------------------- helpers ----

run_hook() { # $1=proj  $2=fixture  $3=variant  $4..=EXTRA_ENV KEY=VALUE
  local proj="$1" fixture="$2" variant="$3"; shift 3
  env -i PATH="$(path_for "$variant")" CLAUDE_PROJECT_DIR="$proj" "$@" \
    /bin/bash "$GATE" < "$fixture" > "$SANDBOX/out" 2> "$SANDBOX/err"
  RC=$?
}

stdout_state() { [ -s "$SANDBOX/out" ] && echo nonempty || echo empty; }

# A well-formed TOP-LEVEL block decision on $SANDBOX/out — explicitly asserts
# the fields are NOT nested under hookSpecificOutput, which a Stop hook ignores.
block_json_ok() {
  if command -v jq > /dev/null 2>&1; then
    jq -e '.decision == "block"
           and (.reason | type == "string") and (.reason | length > 0)
           and (has("hookSpecificOutput") | not)' \
      "$SANDBOX/out" > /dev/null 2>&1
  else
    SANDBOX="$SANDBOX" python3 -c '
import json, os
d = json.load(open(os.path.join(os.environ["SANDBOX"], "out")))
assert d["decision"] == "block"
assert isinstance(d["reason"], str) and d["reason"]
assert "hookSpecificOutput" not in d
' > /dev/null 2>&1
  fi
}

reason_text() {
  if command -v jq > /dev/null 2>&1; then
    jq -r '.reason // ""' "$SANDBOX/out" 2> /dev/null
  else
    SANDBOX="$SANDBOX" python3 -c '
import json, os
try: print(json.load(open(os.path.join(os.environ["SANDBOX"], "out"))).get("reason", ""))
except Exception: print("")
' 2> /dev/null
  fi
}

check() { # $1 label  $2 expected  $3 actual  $4 tag
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s %-5s exp=%-8s got=%-8s %s\n' "$1" "${4:-}" "$2" "$3" "$R"
}

# Asserts a silent allow: exit 0, empty stdout, and no marker left behind.
check_allow() { # $1 label  $2 proj  $3 variant  $4 marker-name
  check "$1 [exit]" 0 "$RC" "$3"
  check "$1 [stdout]" empty "$(stdout_state)" "$3"
  if [ -e "$2/.claude/signals/$4" ]; then MK=present; else MK=absent; fi
  check "$1 [no marker written]" absent "$MK" "$3"
}

echo "sandbox: $SANDBOX"
echo "hook:    $GATE"
echo "bash:    $(/bin/bash --version | head -1)"
echo

# =========================================================================
# A: row 7 — the block itself. Sprint mode, env thresholds soft=1000
#    stop=1500 hard=2000, used=1600 (>= STOP). No hand-off on disk, no
#    marker -> BLOCK: top-level decision JSON, exit 0, marker written.
# =========================================================================
echo "=== A: block past STOP with no hand-off =================================="
NOW="$(date +%s)"
for V in full nojq; do
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
  run_hook "$PROJ" "$FX/stop-nosession.json" "$V" \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
  check "A: used=1600 -> block [exit]" 0 "$RC" "$V"
  check "A: used=1600 -> block [stdout]" nonempty "$(stdout_state)" "$V"
  block_json_ok && J=ok || J=bad
  check "A: used=1600 -> top-level decision=block [json]" ok "$J" "$V"
  case "$(reason_text)" in "This turn may not end yet: Context budget: this session is at 1600 tokens, past the STOP threshold of 1500 (hard stop 2000)."*) M=ok ;; *) M=bad ;; esac
  check "A: reason carries the prefix + stop-band text" ok "$M" "$V"
  case "$(reason_text)" in *"dev-story-sprint rule 9"*) M=ok ;; *) M=bad ;; esac
  check "A: reason names the sprint rule" ok "$M" "$V"
  [ -f "$PROJ/.claude/signals/handoff-stop-gate" ] && MK=present || MK=absent
  check "A: marker written on block" present "$MK" "$V"
done

# `bare` (no jq, no python3) must fail open even at a would-block count.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" bare \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "A: bare (no jq/python3) -> fail open" "$PROJ" bare handoff-stop-gate

# =========================================================================
# B: row 1 — stop_hook_active true is the loop guard, checked FIRST. A
#    would-block sentinel is present to prove it is never consulted.
# =========================================================================
echo
echo "=== B: row 1 — stop_hook_active -> allow ================================="
NOW="$(date +%s)"
for V in full nojq; do
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
  run_hook "$PROJ" "$FX/stop-active-nosession.json" "$V" \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
  check_allow "B: stop_hook_active=true -> allow" "$PROJ" "$V" handoff-stop-gate
done

# Per-session payload, full PATH only (session_slug_for needs tr/cut).
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-active.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "B: stop_hook_active=true, session id -> allow" "$PROJ" full handoff-stop-gate-sess-1

# stop_hook_active ABSENT must behave like false, i.e. still block.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-noflag-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "B: stop_hook_active absent -> still blocks [exit]" 0 "$RC" full
check "B: stop_hook_active absent -> still blocks [stdout]" nonempty "$(stdout_state)" full

# =========================================================================
# C: row 2 — the once-per-session marker. Two Stop calls for the SAME
#    project: the first blocks and writes the marker, the second allows
#    silently. This is the "one forced retry, never a loop" mechanism.
# =========================================================================
echo
echo "=== C: row 2 — one block per session, then silence ======================="
NOW="$(date +%s)"

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "C: 1st Stop (session) -> block [exit]" 0 "$RC" full
check "C: 1st Stop (session) -> block [stdout]" nonempty "$(stdout_state)" full
[ -f "$PROJ/.claude/signals/handoff-stop-gate-sess-1" ] && MK=present || MK=absent
check "C: 1st Stop writes per-session marker" present "$MK" full

# Second Stop, same project, same session, sentinel still over STOP.
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "C: 2nd Stop (marker present) -> allow [exit]" 0 "$RC" full
check "C: 2nd Stop (marker present) -> allow [stdout]" empty "$(stdout_state)" full

# An EMPTY marker file counts too ("any content").
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
: > "$PROJ/.claude/signals/handoff-stop-gate"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "C: pre-existing empty marker -> allow [exit]" 0 "$RC" full
check "C: pre-existing empty marker -> allow [stdout]" empty "$(stdout_state)" full

# A marker for a DIFFERENT session must not suppress this session's block.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
: > "$PROJ/.claude/signals/handoff-stop-gate-sess-9"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "C: other session's marker -> still blocks [stdout]" nonempty "$(stdout_state)" full

# =========================================================================
# D: row 3 — no fresh sentinel. Missing, stale, unparseable, no usage
#    numbers, future epoch. Sentinel parsing is plain bash, but both JSON
#    engines are exercised on the missing-sentinel row.
# =========================================================================
echo
echo "=== D: row 3 — no fresh sentinel -> allow ================================"
NOW="$(date +%s)"

for V in full nojq bare; do
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  run_hook "$PROJ" "$FX/stop-nosession.json" "$V" \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
  check_allow "D: no sentinel -> allow" "$PROJ" "$V" handoff-stop-gate
done

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 700))" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "D: stale sentinel (age>600s) -> allow" "$PROJ" full handoff-stop-gate

# Staleness window is configurable by the same env var the PreToolUse gate uses.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 700))" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_MAX_AGE_SECONDS=1200 \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "D: MAX_AGE=1200 makes the 700s sentinel fresh -> block" nonempty "$(stdout_state)" full

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW + 700))" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "D: future-dated sentinel (clock skew) -> allow" "$PROJ" full handoff-stop-gate

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "this is not a sentinel" "###"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "D: unparseable sentinel -> allow" "$PROJ" full handoff-stop-gate

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "D: sentinel with no usage numbers -> allow" "$PROJ" full handoff-stop-gate

# session_id present but only the GENERIC sentinel exists: no fallback, allow.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "D: session id, only generic sentinel -> allow (no fallback)" "$PROJ" full handoff-stop-gate-sess-1

# =========================================================================
# E: row 4 — USED < STOP. Boundary at STOP-1 (allow) vs STOP (block), in
#    sprint mode and epic mode, both parsing engines where meaningful.
# =========================================================================
echo
echo "=== E: row 4 — STOP boundary ============================================"
NOW="$(date +%s)"
for V in full nojq; do
  for ROW in "1499:empty" "1500:nonempty" "1999:nonempty" "5000:nonempty"; do
    USED="${ROW%%:*}"; EXP="${ROW#*:}"
    PROJ="$(newproj)"; sprint_signal "$PROJ"
    write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=$USED"
    run_hook "$PROJ" "$FX/stop-nosession.json" "$V" \
      CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
    check "E: used=$USED [exit]" 0 "$RC" "$V"
    check "E: used=$USED [stdout]" "$EXP" "$(stdout_state)" "$V"
  done
done

# Sprint mode defaults (no env, no config file): STOP=160000, HARD=165000.
for ROW in "159999:empty" "160000:nonempty"; do
  USED="${ROW%%:*}"; EXP="${ROW#*:}"
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=$USED"
  run_hook "$PROJ" "$FX/stop-nosession.json" full
  check "E: sprint default used=$USED [stdout]" "$EXP" "$(stdout_state)" full
done

# Epic mode defaults (no active-epic): STOP falls back to HARD=150000.
for ROW in "149999:empty" "150000:nonempty"; do
  USED="${ROW%%:*}"; EXP="${ROW#*:}"
  PROJ="$(newproj)"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=$USED"
  run_hook "$PROJ" "$FX/stop-nosession.json" full
  check "E: epic default used=$USED [stdout]" "$EXP" "$(stdout_state)" full
done

# stop= resolved from .claude/context-budget rather than env.
for ROW in "1499:empty" "1500:nonempty"; do
  USED="${ROW%%:*}"; EXP="${ROW#*:}"
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  printf 'soft = 1000\nhard = 2000\nstop = 1500\n' > "$PROJ/.claude/context-budget"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=$USED"
  run_hook "$PROJ" "$FX/stop-nosession.json" full
  check "E: file stop=1500, used=$USED [stdout]" "$EXP" "$(stdout_state)" full
done

# A misconfigured threshold pair never blocks a turn from ending.
for ENVPAIR in "CONTEXT_BUDGET_STOP_TOKENS=500" "CONTEXT_BUDGET_STOP_TOKENS=2500" "CONTEXT_BUDGET_STOP_TOKENS=nope"; do
  PROJ="$(newproj)"; sprint_signal "$PROJ"
  write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
  run_hook "$PROJ" "$FX/stop-nosession.json" full \
    CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 "$ENVPAIR"
  check_allow "E: bad ordering ($ENVPAIR) -> allow" "$PROJ" full handoff-stop-gate
done

# =========================================================================
# F: row 5 — sprint mode, .claude/signals/prep-for-clear-<slug>.md exists.
#    Needs a session id (the file is session-scoped), so: full PATH.
# =========================================================================
echo
echo "=== F: row 5 — sprint prep-for-clear already posted ====================="
NOW="$(date +%s)"

PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
printf '# prep for clear\n' > "$PROJ/.claude/signals/prep-for-clear-sess-1.md"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "F: sprint + prep-for-clear-sess-1.md -> allow" "$PROJ" full handoff-stop-gate-sess-1

# Without the file, the identical setup blocks — proves the file is the cause.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "F: sprint, no prep-for-clear -> block [stdout]" nonempty "$(stdout_state)" full

# Another session's prep-for-clear must not count.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
printf '# someone else\n' > "$PROJ/.claude/signals/prep-for-clear-sess-9.md"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "F: other session's prep-for-clear -> block [stdout]" nonempty "$(stdout_state)" full

# In EPIC mode a prep-for-clear file is not the epic hand-off: still blocks.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage-sess-1" "epoch=$NOW" "used_tokens=1600"
printf '# prep for clear\n' > "$PROJ/.claude/signals/prep-for-clear-sess-1.md"
run_hook "$PROJ" "$FX/stop.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "F: epic + prep-for-clear (wrong hand-off) -> block [stdout]" nonempty "$(stdout_state)" full
case "$(reason_text)" in *"docs/epics/handoff.md"*) M=ok ;; *) M=bad ;; esac
check "F: epic block names the docs/epics/handoff.md hand-off" ok "$M" full

# =========================================================================
# G: row 6 — epic mode, docs/epics/handoff.md newer than the sentinel epoch.
#    An OLDER handoff.md is last session's file and must NOT suppress the
#    block. mtime is read with date -r / stat -f / stat -c.
# =========================================================================
echo
echo "=== G: row 6 — epic handoff.md vs sentinel epoch ========================"
NOW="$(date +%s)"

# handoff.md written now, sentinel epoch 300s ago -> handoff is newer: allow.
PROJ="$(newproj)"
mkdir -p "$PROJ/docs/epics"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 300))" "used_tokens=1600"
printf '# handoff\n' > "$PROJ/docs/epics/handoff.md"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "G: epic + handoff.md newer than epoch -> allow" "$PROJ" full handoff-stop-gate

# handoff.md backdated well before the sentinel epoch -> stale: block.
PROJ="$(newproj)"
mkdir -p "$PROJ/docs/epics"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
printf '# old handoff\n' > "$PROJ/docs/epics/handoff.md"
touch -t 202001010000 "$PROJ/docs/epics/handoff.md" 2> /dev/null
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "G: epic + STALE handoff.md -> block [exit]" 0 "$RC" full
check "G: epic + STALE handoff.md -> block [stdout]" nonempty "$(stdout_state)" full

# No handoff.md at all -> block.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "G: epic + no handoff.md -> block [stdout]" nonempty "$(stdout_state)" full

# In SPRINT mode a fresh docs/epics/handoff.md is the wrong hand-off: block.
PROJ="$(newproj)"; sprint_signal "$PROJ"
mkdir -p "$PROJ/docs/epics"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 300))" "used_tokens=1600"
printf '# handoff\n' > "$PROJ/docs/epics/handoff.md"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check "G: sprint + fresh docs/epics/handoff.md -> still blocks [stdout]" nonempty "$(stdout_state)" full

# Same epic case under nojq (mtime path is engine-independent, but prove it).
PROJ="$(newproj)"
mkdir -p "$PROJ/docs/epics"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$((NOW - 300))" "used_tokens=1600"
printf '# handoff\n' > "$PROJ/docs/epics/handoff.md"
run_hook "$PROJ" "$FX/stop-nosession.json" nojq \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "G: epic + fresh handoff.md (nojq) -> allow" "$PROJ" nojq handoff-stop-gate

# =========================================================================
# H: unparseable stdin -> fail open, decided before anything on disk is
#    read. A would-block sentinel is present to prove it is ignored.
# =========================================================================
echo
echo "=== H: unparseable stdin payload ========================================"
NOW="$(date +%s)"
for V in full nojq; do
  for FIX in garbage truncated; do
    PROJ="$(newproj)"; sprint_signal "$PROJ"
    write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
    run_hook "$PROJ" "$FX/$FIX.json" "$V" \
      CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
    check_allow "H: $FIX stdin -> fail open" "$PROJ" "$V" handoff-stop-gate
  done
done

# Empty stdin parses as nothing -> fail open too.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
: > "$SANDBOX/empty.json"
run_hook "$PROJ" "$SANDBOX/empty.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
check_allow "H: empty stdin -> fail open" "$PROJ" full handoff-stop-gate

# =========================================================================
# I: the block's reason text — handoff_sentence, same as the PreToolUse
#    gate's stop band, and the mandated "This turn may not end yet: " prefix.
# =========================================================================
echo
echo "=== I: reason text / handoff_sentence ==================================="
NOW="$(date +%s)"

# Sprint mode with a matching manifest at status=executing.
PROJ="$(newproj)"; sprint_signal "$PROJ"
mkdir -p "$PROJ/docs/sprints/2026-09-11-002"
printf '{\n  "sprint": "2026-09-11-002",\n  "status": "executing"\n}\n' \
  > "$PROJ/docs/sprints/2026-09-11-002/sprint.json"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
case "$(reason_text)" in \
  *'Skill({skill: "clear-prompt", args: "dev-story-flow execute 2026-09-11-002"})'*) M=ok ;; \
  *) M=bad ;; \
esac
check "I: sprint+executing manifest -> clear-prompt execute sentence" ok "$M" full

# Sprint mode, no manifest -> plain dev-story-sprint caller.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
case "$(reason_text)" in \
  *'Skill({skill: "clear-prompt", args: "dev-story-sprint 2026-09-11-002"})'*) M=ok ;; \
  *) M=bad ;; \
esac
check "I: sprint, no manifest -> dev-story-sprint clear-prompt sentence" ok "$M" full

# Epic mode -> the docs/epics/handoff.md sentence, no Skill() call.
PROJ="$(newproj)"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
case "$(reason_text)" in \
  *"Then write docs/epics/handoff.md per dev-epic-workflow's /handoff and commit it.") M=ok ;; \
  *) M=bad ;; \
esac
check "I: epic mode -> docs/epics/handoff.md sentence, last" ok "$M" full
case "$(reason_text)" in "This turn may not end yet: "*) M=ok ;; *) M=bad ;; esac
check "I: reason starts with the mandated prefix" ok "$M" full

# Estimated usage (used_percentage only) is labelled as such in the reason.
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_percentage=90"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=200000 CONTEXT_BUDGET_STOP_TOKENS=1500
case "$(reason_text)" in *"~180000 tokens (ESTIMATED from 90% of a 200000-token window)"*) M=ok ;; *) M=bad ;; esac
check "I: used_percentage -> ESTIMATED measure in the reason" ok "$M" full

# =========================================================================
# J: stderr is never used to speak to the model, and a block leaves nothing
#    on stderr either — a Stop hook's only channel is the stdout JSON.
# =========================================================================
echo
echo "=== J: stderr stays empty ==============================================="
NOW="$(date +%s)"
PROJ="$(newproj)"; sprint_signal "$PROJ"
write_sentinel "$PROJ/.claude/signals/context-usage" "epoch=$NOW" "used_tokens=1600"
run_hook "$PROJ" "$FX/stop-nosession.json" full \
  CONTEXT_BUDGET_SOFT_TOKENS=1000 CONTEXT_BUDGET_HARD_TOKENS=2000 CONTEXT_BUDGET_STOP_TOKENS=1500
[ -s "$SANDBOX/err" ] && E=nonempty || E=empty
check "J: block writes nothing to stderr" empty "$E" full

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
