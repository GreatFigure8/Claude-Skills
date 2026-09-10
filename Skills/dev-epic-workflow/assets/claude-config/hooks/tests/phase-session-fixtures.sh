#!/usr/bin/env bash
# Fixtures for the phase-session harness and handoff bridge — dev-epic-workflow,
# epic 19 (epic-loop) item 3: ../../bin/phase-session.sh
#
# WHAT THIS PROVES, against the item's own DoD:
#
#   A. Usage errors (missing brief, unreadable brief, bad --repo, bad
#      --timeout) exit 1 before `claude` is ever invoked.
#   B. `phase_session_handoff_valid` — the validity gate — accepts a fully
#      correct handoff and rejects one missing EACH of its three required
#      parts in turn. Section B3 is the fixture the plan's DoD specifically
#      calls out: "the validity check rejects a handoff missing Exact next
#      action."
#   C. The prompt this harness builds always names the handoff's ABSOLUTE
#      path explicitly (A1 mitigation) and always carries the real
#      `/handoff` command body, not a paraphrase of it.
#   D. End to end, sandboxed (a stub `claude`, no network, no real model):
#      D1 a session that writes a fully valid handoff -> harness reports
#         source=session, does not touch what the session wrote.
#      D2 a session that writes an INVALID handoff (missing Exact next
#         action) -> harness overwrites it with a valid deterministic
#         fallback derived from the seeded per-issue state file.
#      D3 a session that writes NOTHING -> same fallback path, same result.
#   E. THE TWO-SESSION CHAIN, the plan's other DoD line: session 2's own
#      transcript (its captured stdout/stderr — the "log" phase-session.sh
#      names) demonstrably reflects having READ session 1's handoff, not
#      merely that the file exists by the time session 2 runs. Session 2's
#      stub reads the exact absolute path this harness named explicitly in
#      ITS OWN prompt (never told to it any other way — proving the A1
#      mitigation actually reaches the session), extracts a marker from
#      session 1's handoff content, and echoes it to its own transcript.
#
# SANDBOXING, the same choice every other fixture in this tree makes:
# everything lives under one `mktemp -d` removed on exit, `HOME` redirected
# into it, `claude`/`git` resolved through INTAKE_CLAUDE / INTAKE_GIT so the
# sandbox never depends on what happens to be on PATH or what the real
# `claude` binary would actually do (which is a LIVE PROBE, run once,
# separately, and recorded in docs/epics/16-*/item-1-hook-firing-findings.md
# rather than re-run here on every invocation of this suite).
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/phase-session-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch,
#         2 = the tree under test is not what this suite expects (abort).

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/phase-session.sh}"
EPIC_LOOP_LIB="$BIN_DIR/epic-loop.sh"
STATUS_LIB="$BIN_DIR/intake-status.sh"
HANDOFF_CMD="$BIN_DIR/../commands/handoff.md"
REAL_GIT="$(command -v git 2>/dev/null || printf '/usr/bin/git')"

for F in "$SCRIPT" "$EPIC_LOOP_LIB" "$STATUS_LIB" "$HANDOFF_CMD"; do
  [ -r "$F" ] || { echo "ERROR: missing $F — this is not an epic 19 item 3 tree. Aborting." >&2; exit 2; }
done
if ! grep -q '^PHASE_SESSION_CONTRACT=1' "$SCRIPT"; then
  echo "ERROR: $SCRIPT carries no PHASE_SESSION_CONTRACT=1 marker." >&2
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

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/phase-session-fixtures.XXXXXX")" || exit 2
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 2 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

export HOME="$SANDBOX/home"
mkdir -p "$HOME"
export INTAKE_GIT="$REAL_GIT"

echo "script:  $SCRIPT"
echo "sandbox: $SANDBOX"
echo

REPO="$SANDBOX/repo"
mkdir -p "$REPO/docs/epics/.intake/loop"
"$REAL_GIT" -C "$REPO" init -q 2>/dev/null || "$REAL_GIT" init -q "$REPO"
"$REAL_GIT" -C "$REPO" config user.email fixture@test.local
"$REAL_GIT" -C "$REPO" config user.name fixture
: > "$REPO/README.md"
"$REAL_GIT" -C "$REPO" add -A
"$REAL_GIT" -C "$REPO" commit -q -m fixture-base

BRIEF="$SANDBOX/brief.md"
printf 'You are the phase session. This is a fixture brief. Do the thing.\n' > "$BRIEF"

# ============================================================ SECTION A ===
echo "=== A. usage errors exit 1 before claude is ever invoked ========"

A_NOARGS_RC=1
bash "$SCRIPT" >/dev/null 2>&1 || A_NOARGS_RC=$?
check "A1 no arguments exits 1" "1" "$A_NOARGS_RC"

A_MISSING_RC=0
bash "$SCRIPT" "$SANDBOX/does-not-exist.md" >/dev/null 2>&1 || A_MISSING_RC=$?
check "A2 unreadable brief file exits 1" "1" "$A_MISSING_RC"

A_BADREPO_RC=0
bash "$SCRIPT" "$BRIEF" --repo "$SANDBOX/no-such-dir" >/dev/null 2>&1 || A_BADREPO_RC=$?
check "A3 --repo naming a nonexistent directory exits 1" "1" "$A_BADREPO_RC"

A_BADTIMEOUT_RC=0
bash "$SCRIPT" "$BRIEF" --repo "$REPO" --timeout notanumber >/dev/null 2>&1 || A_BADTIMEOUT_RC=$?
check "A4 non-numeric --timeout exits 1" "1" "$A_BADTIMEOUT_RC"

A_HELP_OUT="$(bash "$SCRIPT" -h 2>&1)"; A_HELP_RC=$?
check "A5 -h exits 0" "0" "$A_HELP_RC"
check_contains "A6 -h prints the file's own header (usage documented in place)" 1 "$A_HELP_OUT" "phase-session.sh"

# ============================================================ SECTION B ===
# Unit-test the validity gate directly (guarded main() never runs when
# sourced, same convention epic-loop.sh's own fixtures rely on).
echo
echo "=== B. phase_session_handoff_valid — the validity gate =========="

# shellcheck disable=SC1090
. "$SCRIPT"

VALID_H="$SANDBOX/valid-handoff.md"
cat > "$VALID_H" <<'EOF'
# Session Handoff — fixture / work item 1

**Written:** 2026-09-10T00:00:00Z
**Epic:** docs/epics/93-fixture-epic
**Branch:** main (pushed: yes)
**Last commit:** abc123 init
**Worktree:** main checkout

## Verified this session
- nothing

## Claimed but NOT yet verified
- something

## Exact next action
- do the next thing
EOF
check "B1 a fully correct handoff is valid" "0" "$(phase_session_handoff_valid "$VALID_H"; echo $?)"

check "B2 a missing file is invalid" "1" "$(phase_session_handoff_valid "$SANDBOX/nope.md"; echo $?)"

NO_EPIC_H="$SANDBOX/no-epic.md"
grep -v '\*\*Epic:\*\*' "$VALID_H" > "$NO_EPIC_H"
check "B3 missing **Epic:** field is invalid" "1" "$(phase_session_handoff_valid "$NO_EPIC_H"; echo $?)"

# THE DoD LINE: "the validity check rejects a handoff missing Exact next action".
NO_NEXT_H="$SANDBOX/no-next-action.md"
awk '/^## Exact next action$/{skip=1; next} /^## /{skip=0} !skip' "$VALID_H" > "$NO_NEXT_H"
check "B4 missing '## Exact next action' section is invalid (DoD fixture)" "1" "$(phase_session_handoff_valid "$NO_NEXT_H"; echo $?)"
check_contains "B4b the fixture actually removed the section (sanity check on the fixture itself)" 0 "$(cat "$NO_NEXT_H")" "Exact next action"

NO_CLAIMED_H="$SANDBOX/no-claimed.md"
awk '/^## Claimed but NOT yet verified$/{skip=1; next} /^## /{skip=0} !skip' "$VALID_H" > "$NO_CLAIMED_H"
check "B5 missing '## Claimed but NOT yet verified' section is invalid" "1" "$(phase_session_handoff_valid "$NO_CLAIMED_H"; echo $?)"

CASE_H="$SANDBOX/case-insensitive.md"
sed -e 's/Claimed but NOT yet verified/claimed but not yet verified/' -e 's/Exact next action/exact next action/' "$VALID_H" > "$CASE_H"
check "B6 headings are matched case-insensitively (or equivalent, per the plan)" "0" "$(phase_session_handoff_valid "$CASE_H"; echo $?)"

# ============================================================ SECTION C ===
echo
echo "=== C. the prompt names the handoff's absolute path and the real /handoff body ==="

ABS_HANDOFF="$REPO/docs/epics/handoff.md"
PROMPT="$(phase_session_build_prompt "$BRIEF" "$ABS_HANDOFF")"
check_contains "C1 prompt carries the brief's own content" 1 "$PROMPT" "This is a fixture brief"
check_contains "C2 prompt names the handoff's ABSOLUTE path explicitly (A1 mitigation)" 1 "$PROMPT" "$ABS_HANDOFF"
check_contains "C3 prompt says not to rely on automatic injection" 1 "$PROMPT" "SessionStart hook firing"
CMD_BODY_FIRST_LINE="$(phase_session_handoff_cmd_body | sed -n '2p')"
check_contains "C4 prompt carries the real /handoff command body, not a paraphrase" 1 "$PROMPT" "${CMD_BODY_FIRST_LINE:-UNSET}"

# ============================================================ SECTION D ===
echo
echo "=== D. end to end with a stubbed claude (session / invalid / silent) ==="

ISSUE=101
cat > "$REPO/docs/epics/.intake/loop/$ISSUE.json" <<EOF
{
  "issue": $ISSUE,
  "repo": "acme/fixture",
  "epic": "docs/epics/93-fixture-epic/plan.md",
  "state": "drafting",
  "item": null,
  "detail": "mid-flight, seeded for fixture D",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
STATE_FILE="$REPO/docs/epics/.intake/loop/$ISSUE.json"

_write_stub() { # $1 = stub path  $2 = stub body
  printf '%s' "$2" > "$1"
  chmod +x "$1"
}

# D1: the stub writes a fully valid handoff.
CLAUDE_D1="$SANDBOX/claude-d1"
_write_stub "$CLAUDE_D1" '#!/usr/bin/env bash
ARGS="$*"
HPATH="$(printf "%s" "$ARGS" | grep -oE "/[^ ]*docs/epics/handoff\.md" | head -1)"
mkdir -p "$(dirname "$HPATH")"
cat > "$HPATH" <<HOFF
# Session Handoff — fixture / work item 1

**Written:** 2026-09-10T00:00:00Z
**Epic:** docs/epics/93-fixture-epic
**Branch:** main (pushed: yes)
**Last commit:** abc123 init
**Worktree:** main checkout

## Verified this session
- nothing

## Claimed but NOT yet verified
- MARKER-D1-VALID

## Exact next action
- do the next thing
HOFF
exit 0
'
rm -f "$ABS_HANDOFF"
D1_OUT="$(INTAKE_CLAUDE="$CLAUDE_D1" bash "$SCRIPT" "$BRIEF" --repo "$REPO" --state-file "$STATE_FILE" 2>&1)"; D1_RC=$?
check "D1a exit code 0 (a real session's valid handoff is accepted)" "0" "$D1_RC"
check_contains "D1b result line says source=session" 1 "$D1_OUT" "source=session"
check_contains "D1c the harness did not overwrite what the session wrote" 1 "$(cat "$ABS_HANDOFF")" "MARKER-D1-VALID"

# D2: the stub writes an INVALID handoff (missing Exact next action).
CLAUDE_D2="$SANDBOX/claude-d2"
_write_stub "$CLAUDE_D2" '#!/usr/bin/env bash
ARGS="$*"
HPATH="$(printf "%s" "$ARGS" | grep -oE "/[^ ]*docs/epics/handoff\.md" | head -1)"
mkdir -p "$(dirname "$HPATH")"
cat > "$HPATH" <<HOFF
# Session Handoff — incomplete
**Epic:** docs/epics/93-fixture-epic
## Claimed but NOT yet verified
- MARKER-D2-INVALID, no next-action section below
HOFF
exit 0
'
rm -f "$ABS_HANDOFF"
D2_OUT="$(INTAKE_CLAUDE="$CLAUDE_D2" bash "$SCRIPT" "$BRIEF" --repo "$REPO" --state-file "$STATE_FILE" 2>&1)"; D2_RC=$?
check "D2a exit code 0 (never fails outright on a bad session)" "0" "$D2_RC"
check_contains "D2b result line says source=fallback" 1 "$D2_OUT" "source=fallback"
check_contains "D2c the fallback OVERWROTE the invalid handoff (marker gone)" 0 "$(cat "$ABS_HANDOFF")" "MARKER-D2-INVALID"
check_contains "D2d the fallback names the seeded issue" 1 "$(cat "$ABS_HANDOFF")" "issue 101"
check_contains "D2e the fallback carries the seeded state" 1 "$(cat "$ABS_HANDOFF")" "state=drafting"
check "D2f the fallback itself is valid (passes the same gate)" "0" "$(phase_session_handoff_valid "$ABS_HANDOFF"; echo $?)"

# D3: the stub writes NOTHING at all.
CLAUDE_D3="$SANDBOX/claude-d3"
_write_stub "$CLAUDE_D3" '#!/usr/bin/env bash
exit 0
'
rm -f "$ABS_HANDOFF"
D3_OUT="$(INTAKE_CLAUDE="$CLAUDE_D3" bash "$SCRIPT" "$BRIEF" --repo "$REPO" --state-file "$STATE_FILE" 2>&1)"; D3_RC=$?
check "D3a exit code 0 (no handoff at all is also recovered via fallback)" "0" "$D3_RC"
check_contains "D3b result line says source=fallback" 1 "$D3_OUT" "source=fallback"
check "D3c the fallback is valid" "0" "$(phase_session_handoff_valid "$ABS_HANDOFF"; echo $?)"

# ============================================================ SECTION E ===
# THE CHAIN: session 1 writes a real handoff with a unique marker; session 2's
# own transcript demonstrably shows it READ that handoff (not merely that the
# file exists), because session 2's stub only learns the marker by reading
# the exact absolute path phase-session.sh named in ITS OWN prompt.
echo
echo "=== E. two chained sessions — session 2's transcript reflects reading session 1's handoff ==="

rm -f "$ABS_HANDOFF"
BRIEF2="$SANDBOX/brief-session2.md"
printf 'You are session 2, a fresh context boundary with no memory of session 1.\n' > "$BRIEF2"

CLAUDE_E1="$SANDBOX/claude-e1"
_write_stub "$CLAUDE_E1" '#!/usr/bin/env bash
ARGS="$*"
HPATH="$(printf "%s" "$ARGS" | grep -oE "/[^ ]*docs/epics/handoff\.md" | head -1)"
mkdir -p "$(dirname "$HPATH")"
cat > "$HPATH" <<HOFF
# Session Handoff — fixture / work item 1

**Written:** 2026-09-10T00:00:00Z
**Epic:** docs/epics/93-fixture-epic
**Branch:** main (pushed: yes)
**Last commit:** abc123 init
**Worktree:** main checkout

## Verified this session
- nothing

## Claimed but NOT yet verified
- MARKER-CHAIN-9f2a1c wrote by session 1, only readable from the handoff file itself

## Exact next action
- session 2 continues from here
HOFF
exit 0
'
E1_LOG="$SANDBOX/session1.log"
E1_OUT="$(INTAKE_CLAUDE="$CLAUDE_E1" bash "$SCRIPT" "$BRIEF" --repo "$REPO" --log "$E1_LOG" 2>&1)"; E1_RC=$?
check "E1 session 1 exits 0 and reports source=session" "0" "$E1_RC"
check_contains "E1b" 1 "$E1_OUT" "source=session"

# Session 2's stub is told NOTHING about the marker directly — it only
# discovers it by grepping the exact absolute handoff path out of its own
# prompt (proving the A1 mitigation reached it) and reading that file.
CLAUDE_E2="$SANDBOX/claude-e2"
_write_stub "$CLAUDE_E2" '#!/usr/bin/env bash
ARGS="$*"
HPATH="$(printf "%s" "$ARGS" | grep -oE "/[^ ]*docs/epics/handoff\.md" | head -1)"
if [ -n "$HPATH" ] && [ -r "$HPATH" ]; then
  MARK="$(grep -o "MARKER-CHAIN-[A-Za-z0-9]*" "$HPATH" | head -1)"
  printf "SESSION2-READ-HANDOFF: saw %s from %s\n" "${MARK:-NONE}" "$HPATH"
else
  printf "SESSION2-READ-HANDOFF: could not find or read a handoff path in my own prompt\n"
fi
mkdir -p "$(dirname "$HPATH")"
cat > "$HPATH" <<HOFF
# Session Handoff — fixture / work item 1 (session 2)

**Written:** 2026-09-10T00:05:00Z
**Epic:** docs/epics/93-fixture-epic
**Branch:** main (pushed: yes)
**Last commit:** abc123 init
**Worktree:** main checkout

## Verified this session
- read the prior handoff and found MARKER-CHAIN-9f2a1c

## Claimed but NOT yet verified
- session 2 own claim

## Exact next action
- done
HOFF
exit 0
'
E2_LOG="$SANDBOX/session2.log"
E2_OUT="$(INTAKE_CLAUDE="$CLAUDE_E2" bash "$SCRIPT" "$BRIEF2" --repo "$REPO" --log "$E2_LOG" 2>&1)"; E2_RC=$?
check "E2 session 2 exits 0" "0" "$E2_RC"
E2_TRANSCRIPT="$(cat "$E2_LOG" 2>/dev/null)"
check_contains "E3 session 2's OWN TRANSCRIPT shows it read session 1's marker (not just that the file exists)" 1 "$E2_TRANSCRIPT" "MARKER-CHAIN-9f2a1c"
check_contains "E4 session 2's own new handoff also reflects having read it" 1 "$(cat "$ABS_HANDOFF")" "MARKER-CHAIN-9f2a1c"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
