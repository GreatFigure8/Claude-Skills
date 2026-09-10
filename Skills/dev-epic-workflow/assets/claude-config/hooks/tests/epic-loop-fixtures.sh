#!/usr/bin/env bash
# Fixtures for the epic-loop driver skeleton — dev-epic-workflow, epic 19
# item 1: ../../bin/epic-loop.sh
#
# WHAT THIS PROVES, against the item's own DoD:
#
#   A. `dispatch.sh`'s external CLI interface is pinned (A3, the plan's
#      Grounding). This section touches nothing about epic-loop.sh at all —
#      it is a tripwire on dispatch.sh ITSELF, so that epic 16's internal
#      replacement of its `claude -p` call (in flight, item 3 of 4 as this
#      was written) trips this suite the moment the shape it wraps changes,
#      rather than being discovered later inside epic-loop.sh's own tests.
#      Deliberately uses ONLY `--plan` mode, which reads a plan.md and calls
#      neither `git` nor `gh` nor `claude` — no stub, no network, no sandbox
#      git repo required for this section.
#   B. The per-issue state transition table (`epic_loop_next_state`) is
#      correct for every state in the plan's arrow chain, including the one
#      branch (`merged` -> `dispatching` vs `closing`, on whether another
#      item exists).
#   C. `--dry-run` walks a synthetic issue through EVERY state of a two-item
#      epic across repeated invocations — the realistic cadence (a driver
#      invoked on a timer) — with the phase command logged at each step,
#      the item number advancing 1 then 2, and `claude` never invoked.
#   D. `STOP` halts the driver before the next phase runs, exit 0, and the
#      per-issue state file is BYTE-IDENTICAL to what it was before that
#      invocation — proven for a mid-flight state, not just before a cycle
#      starts.
#   E. A non-dry-run invocation refuses cleanly (exit 2) rather than
#      pretending to run a phase this build has no implementation for.
#   F. Usage errors (`--repo` missing, not a directory) exit 1 before
#      anything is touched.
#
# SANDBOXING, same choice this repo's other fixtures make: everything lives
# under one `mktemp -d` removed on exit, `HOME` is redirected into it so
# nothing here ever reads or writes `~/.config/claude-intake`, and `git`,
# `gh`, `claude` are resolved through INTAKE_GIT / INTAKE_GH / INTAKE_CLAUDE
# so the sandbox never depends on what happens to be on PATH.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/epic-loop-fixtures.sh
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-epic-loop.sh bash ...
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch,
#         2 = the tree under test is not what this suite expects (abort).

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/epic-loop.sh}"
DISPATCH_LIB="$BIN_DIR/dispatch.sh"
REAL_GIT="$(command -v git 2>/dev/null || printf '/usr/bin/git')"

# ------------------------------------------------------- the abort tripwires
for F in "$SCRIPT" "$DISPATCH_LIB" "$BIN_DIR/autonomy.sh" "$BIN_DIR/intake-status.sh"; do
  [ -r "$F" ] || { echo "ERROR: missing $F — this is not an epic 19 item 1 tree. Aborting." >&2; exit 2; }
done
if ! grep -q '^EPIC_LOOP_CONTRACT=1' "$SCRIPT"; then
  echo "ERROR: $SCRIPT carries no EPIC_LOOP_CONTRACT=1 marker." >&2
  exit 2
fi
if ! grep -q '^EPIC_LOOP_INVOKES_CLAUDE=no' "$SCRIPT"; then
  echo "ERROR: $SCRIPT does not declare EPIC_LOOP_INVOKES_CLAUDE=no — either this build now" >&2
  echo "       invokes claude (out of item 1's scope) or the marker moved; aborting rather" >&2
  echo "       than silently trusting Section C/D's 'claude never invoked' assertions." >&2
  exit 2
fi
if ! grep -q '^DISPATCH_ENFORCED=' "$DISPATCH_LIB"; then
  echo "ERROR: $DISPATCH_LIB carries no DISPATCH_ENFORCED= contract marker — Section A" >&2
  echo "       would be pinning nothing. Aborting." >&2
  exit 2
fi

FAILURES=0
CASES=0

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s exp=%-10s got=%-10s %s\n' "$1" "$2" "$3" "$R"
}

check_contains() { # $1 label  $2 expected(0|1 present)  $3 haystack  $4 needle
  CASES=$((CASES + 1))
  local GOT=0
  case "$3" in *"$4"*) GOT=1 ;; esac
  if [ "$2" = "$GOT" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s exp=%-10s got=%-10s %s\n' "$1" "$2" "$GOT" "$R"
}

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/epic-loop-fixtures.XXXXXX")" || exit 2
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 2 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

echo "script:   $SCRIPT"
echo "dispatch: $DISPATCH_LIB"
echo "sandbox:  $SANDBOX"
echo

# ============================================================ SECTION A ===
# dispatch.sh's CLI interface, pinned (A3). No git, no gh, no claude — a
# plan.md and `--plan` mode only.
echo "=== A. dispatch.sh --plan interface (A3 pin) ==================="

PLAN_A="$SANDBOX/pin-plan.md"
{
  printf '%s\n' '# Epic: pin fixture'
  printf '%s\n' ''
  printf '%s\n' '**Status:** approved'
  printf '%s\n' ''
  printf '%s\n' '## Work items'
  printf '%s\n' ''
  printf '%s\n' '### 1. first'
  printf '%s\n' '- **Branch:** `feat/first`'
  printf '%s\n' ''
  printf '%s\n' '### 2. second'
  printf '%s\n' '- **Branch:** `feat/second`'
  printf '%s\n' '- **Depends on:** 1'
} > "$PLAN_A"

A_OUT="$("$DISPATCH_LIB" --plan "$PLAN_A" 2>&1)"; A_RC=$?
check "A1 --plan exits 0 on a readable plan" 0 "$A_RC"
check_contains "A2 --plan reports the epic's status" 1 "$A_OUT" "status          approved"
check_contains "A3 --plan lists item 1 with its declared branch" 1 "$A_OUT" "item 1"
check_contains "A4 --plan item 1's branch field is feat/first" 1 "$A_OUT" "branch=feat/first"
check_contains "A5 --plan lists item 2 depending on 1" 1 "$A_OUT" "depends=1"

A_MISS_OUT="$("$DISPATCH_LIB" --plan "$SANDBOX/does-not-exist.md" 2>&1)"; A_MISS_RC=$?
check "A6 --plan exits nonzero on an unreadable plan" 1 "$([ "$A_MISS_RC" -ne 0 ] && echo 1 || echo 0)"

A_HELP_OUT="$("$DISPATCH_LIB" -h 2>&1)"; A_HELP_RC=$?
check "A7 -h exits 0" 0 "$A_HELP_RC"
check_contains "A8 -h prints the file's own header (usage documented in place)" 1 "$A_HELP_OUT" "L2 dispatch"

check_contains "A9 DISPATCH_LEVEL is L2 (the ceiling epic-loop item 1 must not touch)" 1 \
  "$(grep -m1 '^DISPATCH_LEVEL=' "$DISPATCH_LIB")" "DISPATCH_LEVEL=L2"
A10_LINE="$(grep -m1 '^DISPATCH_FS=' "$DISPATCH_LIB")"
check_contains "A10 DISPATCH_FS is still defined (the field separator epic-loop.sh reads)" 1 "$A10_LINE" 'DISPATCH_FS='
check_contains "A10b DISPATCH_FS is still built from printf (unit separator, not a literal)" 1 "$A10_LINE" 'printf'

# ============================================================ SECTION B ===
# The transition table, unit-tested by sourcing the script (guarded main()
# never runs when sourced — same guard dispatch.sh and autonomy.sh use).
echo
echo "=== B. epic_loop_next_state — the transition table ============="

# shellcheck disable=SC1090
. "$SCRIPT"

check "B1  picked -> drafting"                     "drafting"           "$(epic_loop_next_state picked)"
check "B2  drafting -> awaiting-approval"           "awaiting-approval"  "$(epic_loop_next_state drafting)"
check "B3  awaiting-approval -> approved"           "approved"           "$(epic_loop_next_state awaiting-approval)"
check "B4  approved -> dispatching"                 "dispatching"        "$(epic_loop_next_state approved)"
check "B5  dispatching -> awaiting-verify"          "awaiting-verify"    "$(epic_loop_next_state dispatching)"
check "B6  awaiting-verify -> awaiting-merge"       "awaiting-merge"     "$(epic_loop_next_state awaiting-verify)"
check "B7  awaiting-merge -> merged"                "merged"             "$(epic_loop_next_state awaiting-merge)"
check "B8  merged (another item) -> dispatching"    "dispatching"        "$(epic_loop_next_state merged yes)"
check "B9  merged (no more items) -> closing"       "closing"            "$(epic_loop_next_state merged no)"
check "B10 merged (unspecified) defaults to closing" "closing"           "$(epic_loop_next_state merged)"
check "B11 closing -> closed"                       "closed"             "$(epic_loop_next_state closing)"
check "B12 closed is terminal (no next state)"      ""                   "$(epic_loop_next_state closed)"
check "B13 blocked is terminal"                     "1"                  "$(epic_loop_is_terminal blocked && echo 1 || echo 0)"
check "B14 refused is terminal"                     "1"                  "$(epic_loop_is_terminal refused && echo 1 || echo 0)"
check "B15 closed is terminal"                      "1"                  "$(epic_loop_is_terminal closed && echo 1 || echo 0)"
check "B16 dispatching is NOT terminal"              "0"                 "$(epic_loop_is_terminal dispatching && echo 1 || echo 0)"

# ============================================================ SECTION C ===
# The full walk, on a real (empty) git repo — dry-run, repeated invocations,
# a two-item plan so the `merged -> dispatching(next)` branch is exercised
# for real rather than only at the unit level above.
echo
echo "=== C. --dry-run walks every state, claude never invoked ========"

REPO="$SANDBOX/repo"
mkdir -p "$REPO/docs/epics/93-fixture-epic"
"$REAL_GIT" -C "$REPO" init -q 2>/dev/null || { "$REAL_GIT" init -q "$REPO"; }
"$REAL_GIT" -C "$REPO" config user.email fixture@test.local
"$REAL_GIT" -C "$REPO" config user.name fixture

{
  printf '%s\n' '# Epic: fixture epic'
  printf '%s\n' ''
  printf '%s\n' '**Status:** approved'
  printf '%s\n' ''
  printf '%s\n' '## Work items'
  printf '%s\n' ''
  printf '%s\n' '### 1. first item'
  printf '%s\n' '- **Branch:** `feat/first-item`'
  printf '%s\n' ''
  printf '%s\n' '### 2. second item'
  printf '%s\n' '- **Branch:** `feat/second-item`'
  printf '%s\n' '- **Depends on:** 1'
} > "$REPO/docs/epics/93-fixture-epic/plan.md"
"$REAL_GIT" -C "$REPO" add -A
"$REAL_GIT" -C "$REPO" commit -q -m fixture-base

CLAUDE_STUB="$SANDBOX/claude"
CLAUDE_MARKER="$SANDBOX/claude-invoked.marker"
cat > "$CLAUDE_STUB" <<EOF
#!/usr/bin/env bash
printf 'INVOKED %s\n' "\$*" >> "$CLAUDE_MARKER"
exit 1
EOF
chmod +x "$CLAUDE_STUB"

GH_STUB="$SANDBOX/gh"
GH_MARKER="$SANDBOX/gh-invoked.marker"
cat > "$GH_STUB" <<EOF
#!/usr/bin/env bash
printf 'INVOKED %s\n' "\$*" >> "$GH_MARKER"
exit 1
EOF
chmod +x "$GH_STUB"

STATE_DIR="$REPO/docs/epics/.intake/loop"
mkdir -p "$STATE_DIR"
ISSUE=101
cat > "$STATE_DIR/$ISSUE.json" <<EOF
{
  "issue": $ISSUE,
  "repo": "acme/fixture",
  "epic": "docs/epics/93-fixture-epic/plan.md",
  "state": "picked",
  "item": null,
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF

export HOME="$SANDBOX/home"
mkdir -p "$HOME/.config/claude-intake"
export INTAKE_GIT="$REAL_GIT"
export INTAKE_GH="$GH_STUB"
export INTAKE_CLAUDE="$CLAUDE_STUB"
export INTAKE_STOP_FILE="$HOME/.config/claude-intake/STOP"
export INTAKE_AUTONOMY_OVERRIDE="$HOME/.config/claude-intake/AUTONOMY-OFF"
export INTAKE_PROMOTIONS_DIR="$HOME/.config/claude-intake/promotions"
export INTAKE_AUTONOMY_FILE="$HOME/.config/claude-intake/autonomy"
export INTAKE_REPO_SLUG_OVERRIDE="acme/fixture"

C_OUT=""
C_RUNS=0
C_ALL_RC_ZERO=yes
while :; do
  C_RUNS=$((C_RUNS + 1))
  C_ONE="$(bash "$SCRIPT" --repo "$REPO" --dry-run --once 2>&1)"; C_ONE_RC=$?
  [ "$C_ONE_RC" -eq 0 ] || C_ALL_RC_ZERO=no
  C_OUT="$C_OUT
$C_ONE"
  STATE_NOW="$(grep -o '"state": "[^"]*"' "$STATE_DIR/$ISSUE.json" | head -1 | sed -E 's/.*"([a-zA-Z-]+)"$/\1/')"
  [ "$STATE_NOW" = closed ] && break
  if [ "$C_RUNS" -gt 8 ]; then echo "ERROR: walk did not reach closed within 8 invocations" >&2; break; fi
done

check "C1 the walk reaches 'closed' within a bounded number of invocations" "closed" "$STATE_NOW"
check "C2 it took exactly two invocations (budget caps one dispatch each)" "2" "$C_RUNS"
check "C2b every invocation of the walk exited 0 (a preview is never a failure)" "yes" "$C_ALL_RC_ZERO"

LEDGER_TEXT="$(cat "$STATE_DIR/ledger.jsonl" 2>/dev/null)"
# `picked` is the issue's SEEDED starting state — this fixture writes it
# directly, bypassing the bootstrap path, so the ledger has no "to":"picked"
# line (nothing ever transitioned INTO it this run). It is proven instead by
# the very next line's "from":"picked", which only exists if the walk began
# there.
check_contains "C3 ledger recorded the walk beginning FROM 'picked'" 1 "$LEDGER_TEXT" '"from":"picked"'
for S in drafting awaiting-approval approved dispatching awaiting-verify awaiting-merge merged closing closed; do
  check_contains "C3 ledger recorded a transition TO '$S'" 1 "$LEDGER_TEXT" "\"to\":\"$S\""
done

check_contains "C4 dispatching(item 1) command names dispatch.sh --select" 1 "$C_OUT" "dispatch.sh --select"
check_contains "C5 awaiting-verify(item 1) command names verify-item.sh --item 1" 1 "$C_OUT" "verify-item.sh --item 1"
check_contains "C6 the second item's phase command names --item 2" 1 "$C_OUT" "verify-item.sh --item 2"
check_contains "C7 drafting's command names phase-session.sh" 1 "$C_OUT" "phase-session.sh"

check "C8 claude was never invoked" "0" "$([ -f "$CLAUDE_MARKER" ] && echo 1 || echo 0)"
check "C9 gh was never invoked (fully offline dry-run — INTAKE_REPO_SLUG_OVERRIDE short-circuits it)" "0" "$([ -f "$GH_MARKER" ] && echo 1 || echo 0)"

# ============================================================ SECTION D ===
# STOP, mid-flight — not just "before a cycle starts". Seed a NON-terminal
# state directly (bypassing the script), record it byte-for-byte, then prove
# STOP prevents the next phase from running at all.
echo
echo "=== D. STOP halts between phases, state file untouched =========="

ISSUE2=202
cat > "$STATE_DIR/$ISSUE2.json" <<EOF
{
  "issue": $ISSUE2,
  "repo": "acme/fixture",
  "epic": "docs/epics/93-fixture-epic/plan.md",
  "state": "awaiting-verify",
  "item": "1",
  "detail": "mid-flight, pre-STOP",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
BEFORE_SHA="$(shasum -a 256 "$STATE_DIR/$ISSUE2.json" 2>/dev/null | awk '{print $1}')"

: > "$INTAKE_STOP_FILE"
D_OUT="$(bash "$SCRIPT" --repo "$REPO" --dry-run --max-issues 5 --once 2>&1)"; D_RC=$?
AFTER_SHA="$(shasum -a 256 "$STATE_DIR/$ISSUE2.json" 2>/dev/null | awk '{print $1}')"
rm -f "$INTAKE_STOP_FILE"

check "D1 exit code is 0 (a stop obeyed, not a failure)" "0" "$D_RC"
check_contains "D2 output names STOP" 1 "$D_OUT" "STOP"
check "D3 issue #202's state file is byte-identical to before this invocation" "$BEFORE_SHA" "$AFTER_SHA"
check_contains "D4 issue #202's state is unchanged (still awaiting-verify)" 1 "$(cat "$STATE_DIR/$ISSUE2.json")" '"state": "awaiting-verify"'

# ============================================================ SECTION E ===
# A non-dry-run invocation: refuses cleanly rather than pretending to run a
# phase this build has no implementation for.
echo
echo "=== E. non-dry-run refuses cleanly (nothing in this build runs for real) ==="

ISSUE3=303
cat > "$STATE_DIR/$ISSUE3.json" <<EOF
{
  "issue": $ISSUE3,
  "repo": "acme/fixture",
  "epic": "",
  "state": "drafting",
  "item": null,
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
BEFORE3_SHA="$(shasum -a 256 "$STATE_DIR/$ISSUE3.json" 2>/dev/null | awk '{print $1}')"
# Three issues are now seeded (#101 closed, #202 awaiting-verify, #303
# drafting), visited in numeric order. `--max-issues 5` is comfortably above
# the count so this invocation reaches #303: #101 says "nothing to do"
# (terminal), #202 refuses for real (exit 2, same as #303 would), and the
# run's overall exit code is 2 because at least one issue refused.
E_OUT="$(bash "$SCRIPT" --repo "$REPO" --max-issues 5 --once 2>&1)"; E_RC=$?
AFTER3_SHA="$(shasum -a 256 "$STATE_DIR/$ISSUE3.json" 2>/dev/null | awk '{print $1}')"

check "E1 exit code is 2 (a deliberate refusal, not a crash)" "2" "$E_RC"
check_contains "E2 output says real execution is not implemented in this build" 1 "$E_OUT" "not implemented in this build"
check_contains "E3 output points at the epic that fills the gap" 1 "$E_OUT" "epic 19"
check "E4 issue #303's state file is untouched by the refusal" "$BEFORE3_SHA" "$AFTER3_SHA"
check "E5 claude was still never invoked" "0" "$([ -f "$CLAUDE_MARKER" ] && echo 1 || echo 0)"

# ============================================================ SECTION F ===
# Usage errors.
echo
echo "=== F. usage errors exit 1 before anything is touched ==========="

F1_OUT="$(bash "$SCRIPT" --dry-run 2>&1)"; F1_RC=$?
check "F1 missing --repo exits 1" "1" "$F1_RC"

F2_OUT="$(bash "$SCRIPT" --repo "$SANDBOX/does-not-exist" --dry-run 2>&1)"; F2_RC=$?
check "F2 --repo naming a nonexistent directory exits 1" "1" "$F2_RC"

F3_OUT="$(bash "$SCRIPT" --repo "$REPO" --max-issues notanumber --dry-run 2>&1)"; F3_RC=$?
check "F3 non-numeric --max-issues exits 1" "1" "$F3_RC"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
