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

# ============================================================ SECTION G ===
# The approval gate (item 4) — the one real (non-dry-run) phase this build
# has. A REAL bare `origin` per case plus a real clone, exactly the shape
# `l2-dispatch-fixtures.sh` uses for the same reason: `git fetch` / `merge
# --ff-only` / `git mv` / `git push` are exercised for real, and only `gh`
# is faked. The fake `gh` backs `pr list` / `pr merge` / `api .../contents`
# by reading and writing the SAME bare origin through real `git`, so a
# "merge" really does move the base ref and a "contents" read really does
# come from the ref it names — nothing here is asserted against a scripted
# opinion of what `gh` would have said.
echo
echo "=== G. the approval gate — 3 verdicts x autonomy level ==========="

GH_STUB_G="$SANDBOX/gh-g"
cat > "$GH_STUB_G" <<'GHSTUB'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${EPIC_LOOP_FIX_CALLS:-/dev/null}"
case "$1" in
  pr)
    case "$2" in
      list)
        cat "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}" 2>/dev/null
        exit 0 ;;
      merge)
        PRNUM="$3"
        HEADBR="$(awk -v p="$PRNUM" '$1==p{print $2}' "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}" 2>/dev/null)"
        BASEBR="$(cat "${EPIC_LOOP_FIX_BASE_BRANCH:-/dev/null}" 2>/dev/null)"
        [ -n "$HEADBR" ] && [ -n "$BASEBR" ] || exit 1
        HSHA="$(git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" rev-parse "refs/heads/$HEADBR" 2>/dev/null)"
        [ -n "$HSHA" ] || exit 1
        git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" update-ref "refs/heads/$BASEBR" "$HSHA"
        exit $? ;;
      *) exit 0 ;;
    esac ;;
  api)
    URLPATH="$2"
    REF="${URLPATH##*ref=}"
    PPATH="${URLPATH#repos/*/contents/}"
    PPATH="${PPATH%%\?*}"
    git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" show "$REF:$PPATH" 2>/dev/null
    exit 0 ;;
  issue) exit 0 ;;
  *) exit 0 ;;
esac
GHSTUB
chmod +x "$GH_STUB_G"

G_SLUG="acme/gate-fixture"

# $1 = case name -> case dir on stdout. A fresh bare origin + clone, one
# base commit with an (empty) docs/epics/, pushed.
mkcase_g() {
  local D="$SANDBOX/g-$1"
  rm -rf "$D"
  mkdir -p "$D/home/.config/claude-intake/promotions"
  "$REAL_GIT" init -q --bare -b main "$D/origin.git"
  "$REAL_GIT" clone -q "$D/origin.git" "$D/repo"
  "$REAL_GIT" -C "$D/repo" config user.email fixture@test.local
  "$REAL_GIT" -C "$D/repo" config user.name fixture
  mkdir -p "$D/repo/docs/epics"
  : > "$D/repo/docs/epics/.gitkeep"
  "$REAL_GIT" -C "$D/repo" add -A
  "$REAL_GIT" -C "$D/repo" commit -q -m base
  "$REAL_GIT" -C "$D/repo" push -q -u origin main
  printf '%s' "$D"
}

# Cuts and pushes a proposal branch/plan.md carrying $4's Recommendation,
# then switches the clone back to `main` (the driver's own convention: its
# checkout stays on the integration branch). $1=case dir $2=issue $3=slug
# $4=recommendation. Writes open-prs.txt / base-branch.txt for the gh stub.
seed_proposal() {
  local D="$1" ISSUE="$2" PSLUG="$3" REC="$4" BR
  BR="intake/proposed-$ISSUE-$PSLUG"
  "$REAL_GIT" -C "$D/repo" switch -q -c "$BR"
  mkdir -p "$D/repo/docs/epics/proposed-$ISSUE-$PSLUG"
  {
    printf '%s\n\n' "# Epic: proposed epic for #$ISSUE"
    printf '%s\n' "**Status:** planning"
    printf '%s\n' "**Source:** GH #$ISSUE"
    printf '%s\n\n' "**Recommendation:** $REC"
    printf '%s\n\n' "## Work items"
    printf '%s\n' "### 1. first"
    printf '%s\n' '- **Branch:** `feat/first`'
  } > "$D/repo/docs/epics/proposed-$ISSUE-$PSLUG/plan.md"
  "$REAL_GIT" -C "$D/repo" add -A
  "$REAL_GIT" -C "$D/repo" commit -q -m "docs(intake): proposed epic for #$ISSUE"
  "$REAL_GIT" -C "$D/repo" push -q -u origin "$BR"
  "$REAL_GIT" -C "$D/repo" switch -q main
  printf '900 %s\n' "$BR" > "$D/open-prs.txt"
  printf 'main\n' > "$D/base-branch.txt"
}

# Writes an autonomy config + (for L1/L4) a valid promotion record granting
# $3 to $2, isolated under $1/home so cases never see each other's grants.
# L4's record also gets a ledger with 3 closed cycles, since above L2 the
# ledger is consulted too (autonomy.sh, `autonomy_ledger_cycles`).
grant_level() {
  local D="$1" SLUG="$2" LVL="$3" F
  [ "$LVL" = L0 ] && return 0
  cat > "$D/home/.config/claude-intake/autonomy" <<CFG
[$SLUG]
level = $LVL
max-files = 40
max-diff-lines = 800
CFG
  F="$D/home/.config/claude-intake/promotions/$(printf '%s' "$SLUG" | sed 's|/|__|g').$LVL"
  {
    printf 'repo: %s\n' "$SLUG"
    printf 'level: %s\n' "$LVL"
    printf 'granted: 2026-09-01T00:00:00Z\n'
    printf 'granted-by: jonathanstevenson\n'
    printf 'cycles: 3\n'
    printf 'ledger: %s/ledger.jsonl\n' "$D"
    printf 'evidence: fixture grant\n'
  } > "$F"
  if [ "$LVL" = L3 ] || [ "$LVL" = L4 ]; then
    {
      printf '{"ts":"2026-09-01T00:00:00Z","issue":1,"repo":"%s","from":"closing","to":"closed","detail":"fixture"}\n' "$SLUG"
      printf '{"ts":"2026-09-01T00:00:01Z","issue":2,"repo":"%s","from":"closing","to":"closed","detail":"fixture"}\n' "$SLUG"
      printf '{"ts":"2026-09-01T00:00:02Z","issue":3,"repo":"%s","from":"closing","to":"closed","detail":"fixture"}\n' "$SLUG"
    } > "$D/ledger.jsonl"
  fi
}

seed_state() { # $1=case dir $2=issue $3=slug
  mkdir -p "$1/repo/docs/epics/.intake/loop"
  cat > "$1/repo/docs/epics/.intake/loop/$2.json" <<EOF
{
  "issue": $2,
  "repo": "$3",
  "epic": "",
  "state": "awaiting-approval",
  "item": null,
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
}

# Runs the driver for real (no --dry-run) against case $1, slug $2. Sets
# G_OUT / G_RC / G_STATE (the per-issue state's own "state" field) /
# G_CALLS (the gh-stub's call log, for substring assertions).
run_gate() {
  local D="$1" SLUG="$2" ISSUE="$3"
  export HOME="$D/home"
  export INTAKE_GIT="$REAL_GIT"
  export INTAKE_GH="$GH_STUB_G"
  export INTAKE_REPO_SLUG_OVERRIDE="$SLUG"
  export INTAKE_STOP_FILE="$D/home/.config/claude-intake/STOP"
  export INTAKE_AUTONOMY_OVERRIDE="$D/home/.config/claude-intake/AUTONOMY-OFF"
  export INTAKE_PROMOTIONS_DIR="$D/home/.config/claude-intake/promotions"
  export INTAKE_AUTONOMY_FILE="$D/home/.config/claude-intake/autonomy"
  export EPIC_LOOP_FIX_OPEN_PRS="$D/open-prs.txt"
  export EPIC_LOOP_FIX_BASE_BRANCH="$D/base-branch.txt"
  export EPIC_LOOP_FIX_ORIGIN_GIT="$D/origin.git"
  export EPIC_LOOP_FIX_CALLS="$D/gh-calls.log"
  : > "$EPIC_LOOP_FIX_CALLS"
  G_OUT="$(bash "$SCRIPT" --repo "$D/repo" --once 2>&1)"; G_RC=$?
  G_STATE="$(grep -o '"state": "[^"]*"' "$D/repo/docs/epics/.intake/loop/$ISSUE.json" 2>/dev/null \
               | head -1 | sed -E 's/.*"([a-zA-Z-]+)"$/\1/')"
  G_CALLS="$(cat "$EPIC_LOOP_FIX_CALLS" 2>/dev/null)"
}

# --- G1/G2: ready(plan) at the L0/L1 boundary ------------------------------
G1="$(mkcase_g g1-ready-l0)"; seed_proposal "$G1" 601 widget-support plan
seed_state "$G1" 601 "$G_SLUG"; grant_level "$G1" "$G_SLUG" L0
run_gate "$G1" "$G_SLUG" 601
check "G1 ready+L0: exit 0 (parked, not a crash)"                   "0"      "$G_RC"
check "G1 ready+L0: state stays awaiting-approval"                  "awaiting-approval" "$G_STATE"
check_contains "G1 ready+L0: output says parked"                    1 "$G_OUT" "approval gate parked"
check_contains "G1 ready+L0: names may-approve/level as the reason" 1 "$G_OUT" "does not grant may-approve"
check "G1 ready+L0: gh pr merge was never called"                   "0" "$(grep -c '^gh pr merge' "$G1/gh-calls.log" | tr -d ' ')"
check "G1 ready+L0: origin/main carries no numbered epic folder"    "0" \
      "$("$REAL_GIT" --git-dir="$G1/origin.git" ls-tree -d --name-only main -- docs/epics 2>/dev/null | grep -c '^docs/epics/[0-9]' | tr -d ' ')"

G2="$(mkcase_g g2-ready-l1)"; seed_proposal "$G2" 602 widget-support plan
seed_state "$G2" 602 "$G_SLUG"; grant_level "$G2" "$G_SLUG" L1
run_gate "$G2" "$G_SLUG" 602
check "G2 ready+L1: exit 2 (approved, then the NEXT phase — approved -> dispatching — is still unimplemented; a real refusal, not a crash)" "2" "$G_RC"
check "G2 ready+L1: state advances to approved"                     "approved" "$G_STATE"
check_contains "G2 ready+L1: epic path recorded is the numbered folder" 1 \
      "$(cat "$G2/repo/docs/epics/.intake/loop/602.json")" "docs/epics/01-widget-support/plan.md"
check "G2 ready+L1: gh pr merge WAS called exactly once"            "1" "$(grep -c '^gh pr merge' "$G2/gh-calls.log" | tr -d ' ')"
check "G2 ready+L1: gh issue edit --add-label epic:planned was called" "1" \
      "$(grep -c 'epic:planned' "$G2/gh-calls.log" | tr -d ' ')"
G2_COMMENT="$(cat "$G2/gh-calls.log")"
check_contains "G2 ready+L1: the issue comment says Epic filed"     1 "$G2_COMMENT" "Epic filed: docs/epics/01-widget-support/plan.md"
check_contains "G2 ready+L1: the permalink names the repo slug"     1 "$G2_COMMENT" "https://github.com/$G_SLUG/blob/"
check "G2 ready+L1: origin/main's plan.md now reads Status: approved" "1" \
      "$("$REAL_GIT" --git-dir="$G2/origin.git" show main:docs/epics/01-widget-support/plan.md 2>/dev/null | grep -c '^\*\*Status:\*\* approved$' | tr -d ' ')"
check "G2 ready+L1: the OLD proposed- folder is gone from main"     "0" \
      "$("$REAL_GIT" --git-dir="$G2/origin.git" ls-tree --name-only main -- docs/epics/proposed-602-widget-support 2>/dev/null | grep -c . | tr -d ' ')"

# --- G3/G4: no-work and needs-decision at L1 (may-approve true, verdict not ready) ---
G3="$(mkcase_g g3-nowork-l1)"; seed_proposal "$G3" 603 other-thing no-work
seed_state "$G3" 603 "$G_SLUG"; grant_level "$G3" "$G_SLUG" L1
run_gate "$G3" "$G_SLUG" 603
check "G3 no-work+L1: exit 0 (parked)"                              "0" "$G_RC"
check "G3 no-work+L1: state stays awaiting-approval"                "awaiting-approval" "$G_STATE"
check_contains "G3 no-work+L1: names the recommendation as the reason" 1 "$G_OUT" "recommendation is no-work"
check "G3 no-work+L1: gh pr merge was never called"                 "0" "$(grep -c '^gh pr merge' "$G3/gh-calls.log" | tr -d ' ')"

G4="$(mkcase_g g4-decision-l1)"; seed_proposal "$G4" 604 hard-choice needs-decision
seed_state "$G4" 604 "$G_SLUG"; grant_level "$G4" "$G_SLUG" L1
run_gate "$G4" "$G_SLUG" 604
check "G4 needs-decision+L1: exit 0 (parked)"                       "0" "$G_RC"
check "G4 needs-decision+L1: state stays awaiting-approval"         "awaiting-approval" "$G_STATE"
check_contains "G4 needs-decision+L1: names the recommendation as the reason" 1 "$G_OUT" "recommendation is needs-decision"
check "G4 needs-decision+L1: gh pr merge was never called"          "0" "$(grep -c '^gh pr merge' "$G4/gh-calls.log" | tr -d ' ')"

# --- G5/G6/G7: L4 — the DoD's own line, "needs-decision at L4 still parks",
# plus the symmetric proof that L4 approves a `plan` and still parks a
# `no-work` regardless of level.
G5="$(mkcase_g g5-decision-l4)"; seed_proposal "$G5" 605 hard-choice needs-decision
seed_state "$G5" 605 "$G_SLUG"; grant_level "$G5" "$G_SLUG" L4
run_gate "$G5" "$G_SLUG" 605
check "G5 needs-decision+L4: exit 0 (parked — DoD: needs-decision at L4 still parks)" "0" "$G_RC"
check "G5 needs-decision+L4: state stays awaiting-approval"         "awaiting-approval" "$G_STATE"
check_contains "G5 needs-decision+L4: never auto-approved regardless of level" 1 "$G_OUT" "never auto-approved regardless of level"
check "G5 needs-decision+L4: gh pr merge was never called"          "0" "$(grep -c '^gh pr merge' "$G5/gh-calls.log" | tr -d ' ')"

G6="$(mkcase_g g6-ready-l4)"; seed_proposal "$G6" 606 widget-support plan
seed_state "$G6" 606 "$G_SLUG"; grant_level "$G6" "$G_SLUG" L4
run_gate "$G6" "$G_SLUG" 606
check "G6 ready+L4: exit 2 (approved, next phase still unimplemented)" "2" "$G_RC"
check "G6 ready+L4: state advances to approved"                     "approved" "$G_STATE"
check "G6 ready+L4: gh pr merge WAS called exactly once"            "1" "$(grep -c '^gh pr merge' "$G6/gh-calls.log" | tr -d ' ')"
check "G6 ready+L4: origin/main's plan.md now reads Status: approved" "1" \
      "$("$REAL_GIT" --git-dir="$G6/origin.git" show main:docs/epics/01-widget-support/plan.md 2>/dev/null | grep -c '^\*\*Status:\*\* approved$' | tr -d ' ')"

G7="$(mkcase_g g7-nowork-l4)"; seed_proposal "$G7" 607 other-thing no-work
seed_state "$G7" 607 "$G_SLUG"; grant_level "$G7" "$G_SLUG" L4
run_gate "$G7" "$G_SLUG" 607
check "G7 no-work+L4: exit 0 (parked — the verdict rules out approval before level is even asked)" "0" "$G_RC"
check "G7 no-work+L4: gh pr merge was never called"                 "0" "$(grep -c '^gh pr merge' "$G7/gh-calls.log" | tr -d ' ')"

# --- G8: a human already merged the PR and set Status: approved by hand —
# the scope's own words: "later cycles must detect the human's merge +
# `approved` edit and continue from there." No proposal PR exists at all
# here (open-prs.txt is never written), so a pass that reached `gh pr list`
# or `gh pr merge` would be reaching for something that plainly is not there.
G8="$(mkcase_g g8-human-approved)"
mkdir -p "$G8/repo/docs/epics/01-manual"
{
  printf '%s\n\n' "# Epic: manually approved"
  printf '%s\n' "**Status:** approved"
  printf '%s\n' "**Source:** GH #608"
} > "$G8/repo/docs/epics/01-manual/plan.md"
"$REAL_GIT" -C "$G8/repo" add -A
"$REAL_GIT" -C "$G8/repo" commit -q -m "docs(epic): file 01-manual — approved by hand"
"$REAL_GIT" -C "$G8/repo" push -q origin main
seed_state "$G8" 608 "$G_SLUG"; grant_level "$G8" "$G_SLUG" L0
run_gate "$G8" "$G_SLUG" 608
check "G8 human-approved: exit 2 (approved, next phase still unimplemented)" "2" "$G_RC"
check "G8 human-approved: state advances to approved without any grant at all" "approved" "$G_STATE"
check_contains "G8 human-approved: epic path is the human's own numbered folder" 1 \
      "$(cat "$G8/repo/docs/epics/.intake/loop/608.json")" "docs/epics/01-manual/plan.md"
check "G8 human-approved: gh was never called — nothing to list or merge" "0" \
      "$(grep -c '^gh ' "$G8/gh-calls.log" | tr -d ' ')"

# ============================================================ SECTION H ===
# The merge gate and the chain gate (item 6) — the plan's own DoD line: "a
# synthetic two-item epic at L4 lands both with merge commits, worktrees
# gone, checklist ticked; the same epic at L2 parks at item 1's PR."
#
# ONE case dir, run across several invocations in sequence — the realistic
# cadence a real cycle also has (state advances a little each time it's
# asked) — rather than one fresh sandbox per assertion. "Worktrees gone" is
# not re-proven here: dispatch.sh's own `_dispatch_cleanup_worktree` already
# removes the executor's worktree the instant its PR opens (l2-dispatch-
# fixtures.sh owns that proof), and this gate never creates one — it is
# git+gh in the driver's own main checkout only, per the plan's Risks line.
#
# The chain gate's dispatch step (H3) IS invoked for real, not stubbed out:
# `dispatch_repo` refuses structurally, before it ever provisions a worktree
# or could reach a `claude` invocation, because this sandbox sources no
# `worktree-provision.sh` (dispatch.sh's own line 636/1180 refusal) — so
# exercising it here costs nothing and risks nothing, and proves the chain
# gate really does hand item 2 to the real dispatch path rather than to a
# test double standing in for it.
echo
echo "=== H. the merge gate + chain gate (a two-item epic, L2 then L4) ="

GH_STUB_H="$SANDBOX/gh-h"
cat > "$GH_STUB_H" <<'GHSTUB'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${EPIC_LOOP_FIX_CALLS:-/dev/null}"
case "$1" in
  pr)
    case "$2" in
      list)
        cat "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}" 2>/dev/null
        exit 0 ;;
      merge)
        PRNUM="$3"
        HEADBR="$(awk -v p="$PRNUM" '$1==p{print $2}' "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}" 2>/dev/null)"
        BASEBR="$(cat "${EPIC_LOOP_FIX_BASE_BRANCH:-/dev/null}" 2>/dev/null)"
        [ -n "$HEADBR" ] && [ -n "$BASEBR" ] || exit 1
        HSHA="$(git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" rev-parse "refs/heads/$HEADBR" 2>/dev/null)"
        [ -n "$HSHA" ] || exit 1
        git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" update-ref "refs/heads/$BASEBR" "$HSHA" || exit 1
        # The merged PR leaves the open list, the same way a real merge
        # closes it — so a later `pr list` in the same case reflects reality.
        awk -v p="$PRNUM" '$1!=p' "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}" > "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}.tmp" 2>/dev/null \
          && mv "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}.tmp" "${EPIC_LOOP_FIX_OPEN_PRS:-/dev/null}"
        exit 0 ;;
      *) exit 0 ;;
    esac ;;
  api)
    URLPATH="$2"
    IS_PATCH=no; PREV_A=""
    for A in "$@"; do
      [ "$PREV_A" = --method ] && [ "$A" = PATCH ] && IS_PATCH=yes
      PREV_A="$A"
    done
    case "$URLPATH" in
      */comments/*)
        if [ "$IS_PATCH" = yes ]; then
          for A in "$@"; do
            case "$A" in body=*) printf '%s' "${A#body=}" > "${EPIC_LOOP_FIX_COMMENT_OUT:-/dev/null}" ;; esac
          done
          exit 0
        fi
        cat "${EPIC_LOOP_FIX_COMMENT_BODY:-/dev/null}" 2>/dev/null
        exit 0 ;;
      */comments)
        # This stub answers the LIST query directly with the seeded id rather
        # than interpreting the real `-q` jq filter text — a test double, not
        # a jq shim, and every case here seeds exactly one candidate comment.
        printf '%s' "${EPIC_LOOP_FIX_COMMENT_ID:-}"
        exit 0 ;;
      *)
        REF="${URLPATH##*ref=}"
        PPATH="${URLPATH#repos/*/contents/}"
        PPATH="${PPATH%%\?*}"
        git --git-dir="$EPIC_LOOP_FIX_ORIGIN_GIT" show "$REF:$PPATH" 2>/dev/null
        exit 0 ;;
    esac ;;
  issue) exit 0 ;;
  *) exit 0 ;;
esac
GHSTUB
chmod +x "$GH_STUB_H"

H_SLUG="acme/merge-fixture"
H_EPIC="01-two-item"
H_BR1="feat/h-item-1"
H_BR2="feat/h-item-2"

# Writes docs/epics/$H_EPIC/plan.md (two declared work items) on main and
# pushes it, then cuts+pushes $2 as a one-commit branch off the CURRENT main
# tip, leaving the clone back on main. $1=case dir $2=branch.
seed_item_branch() {
  local D="$1" BR="$2"
  "$REAL_GIT" -C "$D/repo" switch -q -c "$BR"
  printf '%s\n' "$BR" >> "$D/repo/docs/epics/$H_EPIC/plan.md"
  "$REAL_GIT" -C "$D/repo" commit -q -am "feat: $BR work"
  "$REAL_GIT" -C "$D/repo" push -q -u origin "$BR"
  "$REAL_GIT" -C "$D/repo" switch -q main
}

run_gate_h() { # $1=case dir $2=slug $3=issue
  local D="$1" SLUG="$2" ISSUE="$3"
  export HOME="$D/home"
  export INTAKE_GIT="$REAL_GIT"
  export INTAKE_GH="$GH_STUB_H"
  export INTAKE_REPO_SLUG_OVERRIDE="$SLUG"
  export INTAKE_STOP_FILE="$D/home/.config/claude-intake/STOP"
  export INTAKE_AUTONOMY_OVERRIDE="$D/home/.config/claude-intake/AUTONOMY-OFF"
  export INTAKE_PROMOTIONS_DIR="$D/home/.config/claude-intake/promotions"
  export INTAKE_AUTONOMY_FILE="$D/home/.config/claude-intake/autonomy"
  export EPIC_LOOP_FIX_OPEN_PRS="$D/open-prs.txt"
  export EPIC_LOOP_FIX_BASE_BRANCH="$D/base-branch.txt"
  export EPIC_LOOP_FIX_ORIGIN_GIT="$D/origin.git"
  export EPIC_LOOP_FIX_CALLS="$D/gh-calls.log"
  export EPIC_LOOP_FIX_COMMENT_ID="9001"
  export EPIC_LOOP_FIX_COMMENT_BODY="$D/comment-body.txt"
  export EPIC_LOOP_FIX_COMMENT_OUT="$D/comment-out.txt"
  : > "$EPIC_LOOP_FIX_CALLS"
  : > "$EPIC_LOOP_FIX_COMMENT_OUT"
  H_OUT="$(bash "$SCRIPT" --repo "$D/repo" --once 2>&1)"; H_RC=$?
  H_STATE="$(grep -o '"state": "[^"]*"' "$D/repo/docs/epics/.intake/loop/$ISSUE.json" 2>/dev/null \
               | head -1 | sed -E 's/.*"([a-zA-Z-]+)"$/\1/')"
  H_ITEM="$(grep -o '"item": "[^"]*"' "$D/repo/docs/epics/.intake/loop/$ISSUE.json" 2>/dev/null \
               | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  H_CALLS="$(cat "$EPIC_LOOP_FIX_CALLS" 2>/dev/null)"
}

H="$(mkcase_g h1-two-item)"
mkdir -p "$H/repo/docs/epics/$H_EPIC"
{
  printf '%s\n\n' "# Epic: two-item epic for #701"
  printf '%s\n' "**Status:** in flight (item 1 of 2)"
  printf '%s\n' "**Source:** GH #701"
  printf '\n## Work items\n\n'
  printf '%s\n' "### 1. first"
  printf '%s\n' "- **Branch:** \`$H_BR1\`"
  printf '%s\n' "### 2. second"
  printf '%s\n' "- **Branch:** \`$H_BR2\`"
} > "$H/repo/docs/epics/$H_EPIC/plan.md"
"$REAL_GIT" -C "$H/repo" add -A
"$REAL_GIT" -C "$H/repo" commit -q -m "docs(epic): file $H_EPIC"
"$REAL_GIT" -C "$H/repo" push -q origin main
seed_item_branch "$H" "$H_BR1"

mkdir -p "$H/repo/docs/epics/.intake/loop"
cat > "$H/repo/docs/epics/.intake/loop/701.json" <<EOF
{
  "issue": 701,
  "repo": "$H_SLUG",
  "epic": "docs/epics/$H_EPIC/plan.md",
  "state": "awaiting-merge",
  "item": "1",
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
printf 'main\n' > "$H/base-branch.txt"
printf '801 %s\n' "$H_BR1" > "$H/open-prs.txt"
{
  printf 'Epic filed: [docs/epics/%s/plan.md](https://example)\n\n' "$H_EPIC"
  printf 'Work items:\n'
  printf -- '- [ ] item 1: first (`%s`)\n' "$H_BR1"
  printf -- '- [ ] item 2: second (`%s`)\n' "$H_BR2"
} > "$H/comment-body.txt"

# --- H1: L2 — may-merge not granted (L3+ only). Parks at item 1's PR. -----
grant_level "$H" "$H_SLUG" L2
run_gate_h "$H" "$H_SLUG" 701
check "H1 L2: exit 0 (parked, not a crash)"                         "0" "$H_RC"
check "H1 L2: state stays awaiting-merge"                           "awaiting-merge" "$H_STATE"
check_contains "H1 L2: output names may-merge/level as the reason"  1 "$H_OUT" "may-merge not granted"
check "H1 L2: gh pr merge was never called"                         "0" "$(grep -c '^gh pr merge' "$H/gh-calls.log" | tr -d ' ')"
check "H1 L2: origin/main is still the pre-epic base (no advance)"  "0" \
      "$("$REAL_GIT" --git-dir="$H/origin.git" log --oneline main 2>/dev/null | grep -c "$H_BR1 work" | tr -d ' ')"

# --- H2/H3: promoted to L4 — item 1 merges, and the SAME invocation chains
# straight on to dispatching(2) — `merged` is not a stopping point any more
# than any other real transition in this file's phase loop is (section C's
# dry-run walk already demonstrates the same cascading-per-invocation shape).
# dispatch_repo then runs for real and refuses structurally (see the section
# header); the assertion that matters here is the CHAIN DECISION — item
# advances to 2 — not that a PR opened, which is dispatch.sh's own proof to
# carry, not this gate's.
grant_level "$H" "$H_SLUG" L4
run_gate_h "$H" "$H_SLUG" 701
check "H2 L4: exit 0 (merged item 1, chained, dispatch refused structurally — not a crash)" "0" "$H_RC"
check "H2 L4: cascades all the way to dispatching(2)"                "dispatching" "$H_STATE"
check "H2 L4: item advances to 2"                                    "2" "$H_ITEM"
check "H2 L4: gh pr merge WAS called exactly once"                   "1" "$(grep -c '^gh pr merge' "$H/gh-calls.log" | tr -d ' ')"
check "H2 L4: origin/main now carries item 1's commit"               "1" \
      "$("$REAL_GIT" --git-dir="$H/origin.git" log --oneline main 2>/dev/null | grep -c "$H_BR1 work" | tr -d ' ')"
check "H2 L4: item 1's branch is gone from origin"                   "1" \
      "$("$REAL_GIT" --git-dir="$H/origin.git" show-ref --verify --quiet "refs/heads/$H_BR1"; echo $?)"
check_contains "H2 L4: checklist PATCH ticks item 1"                 1 "$(cat "$H/comment-out.txt")" "- [x] item 1: first"
check_contains "H2 L4: checklist PATCH leaves item 2 untouched"      1 "$(cat "$H/comment-out.txt")" "- [ ] item 2: second"
check_contains "H2 L4: ledger recorded merged -> dispatching"        1 \
      "$(cat "$H/repo/docs/epics/.intake/loop/ledger.jsonl" 2>/dev/null)" \
      '"from":"merged","to":"dispatching"'
cp "$H/comment-out.txt" "$H/comment-body.txt"   # the tracker now reads as PATCHed

# --- H4: item 2 reaches awaiting-merge (verify's own concern, simulated by
# seeding state directly) and merges too — "lands BOTH". -------------------
seed_item_branch "$H" "$H_BR2"
cat > "$H/repo/docs/epics/.intake/loop/701.json" <<EOF
{
  "issue": 701,
  "repo": "$H_SLUG",
  "epic": "docs/epics/$H_EPIC/plan.md",
  "state": "awaiting-merge",
  "item": "2",
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
printf '802 %s\n' "$H_BR2" > "$H/open-prs.txt"
run_gate_h "$H" "$H_SLUG" 701
# Item 2 is the epic's LAST item, so this single invocation both merges it
# AND (the very next iteration of the same phase loop — `merged` is not a
# stopping point, exactly like every other real transition in this file)
# advances merged -> closing -> closed: item 7's close gate is real now, so
# the cascade runs all the way to the terminal state in one invocation, the
# same shape section C's dry-run walk already demonstrated for the happy
# path. Section I below exercises the close gate's own internals (ordering,
# scaffolding removal, the retro, the conditional issue-close) in isolation;
# this section only needs to prove the CASCADE reaches `closed` for real.
check "H4 L4 item 2: exit 0 (merged, cascaded through closing to closed)" "0" "$H_RC"
check "H4 L4 item 2: state advances all the way to closed"           "closed" "$H_STATE"
check "H4 L4 item 2: origin/main now carries item 2's commit"        "1" \
      "$("$REAL_GIT" --git-dir="$H/origin.git" log --oneline main 2>/dev/null | grep -c "$H_BR2 work" | tr -d ' ')"
check "H4 L4 item 2: item 2's branch is gone from origin"            "1" \
      "$("$REAL_GIT" --git-dir="$H/origin.git" show-ref --verify --quiet "refs/heads/$H_BR2"; echo $?)"
check_contains "H4 L4 item 2: checklist PATCH ticks item 2 as well"  1 "$(cat "$H/comment-out.txt")" "- [x] item 2: second"
check_contains "H4 L4 item 2: ledger recorded merged -> closing"     1 \
      "$(cat "$H/repo/docs/epics/.intake/loop/ledger.jsonl" 2>/dev/null)" \
      '"from":"merged","to":"closing"'
check_contains "H4 L4 item 2: ledger recorded closing -> closed"     1 \
      "$(cat "$H/repo/docs/epics/.intake/loop/ledger.jsonl" 2>/dev/null)" \
      '"from":"closing","to":"closed"'
check_contains "H4 L4 item 2: origin/main's plan.md now reads Status: closed" 1 \
      "$("$REAL_GIT" --git-dir="$H/origin.git" show "main:docs/epics/$H_EPIC/plan.md" 2>/dev/null)" \
      '**Status:** closed'

# ============================================================ SECTION I ===
# The close gate itself (item 7), in isolation — Section H above only proved
# the CASCADE reaches `closed`; this section seeds the per-issue state
# directly AT `closing` (the same "simulate the prior phase's own concern"
# shape H4 already used for `awaiting-merge`) and exercises
# epic_loop_close_gate's own internals: the landing order (GH #41), the
# scaffolding removal (`status/`, `CANCEL`, a conditionally-matched
# `active-epic` pointer, a conditionally-matched `handoff.md`), the retro
# comment built from the ledger, and the conditional `gh issue close`.
echo
echo "=== I. the close gate — landing order, scaffolding, retro, issue-close ="

GH_STUB_I="$SANDBOX/gh-i"
cat > "$GH_STUB_I" <<'GHSTUB'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "${EPIC_LOOP_FIX_CALLS:-/dev/null}"
case "$1" in
  issue)
    case "$2" in
      view)
        printf '%s' "${EPIC_LOOP_FIX_ISSUE_STATE:-OPEN}"
        exit 0 ;;
      comment)
        PREV_A=""
        for A in "$@"; do
          [ "$PREV_A" = --body ] && printf '%s' "$A" > "${EPIC_LOOP_FIX_RETRO_OUT:-/dev/null}"
          PREV_A="$A"
        done
        exit 0 ;;
      close) exit 0 ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac
GHSTUB
chmod +x "$GH_STUB_I"

I_SLUG="acme/close-fixture"

# Writes docs/epics/$2/plan.md (Status: in flight, or already closed when
# $5=yes — the human-already-closed-it path), a `status/` dir with one file,
# a `CANCEL` sentinel, pushes to origin, then seeds the per-issue state file
# AT `closing` and a two-line ledger for $3 (the transitions a real
# merged-item cascade would have appended). $1=case dir $2=epic dir name
# $3=issue $4=slug $5=already-closed(yes|no, default no).
seed_closing_epic() {
  local D="$1" EPIC="$2" ISSUE="$3" SLUG="$4" ALREADY="${5:-no}"
  mkdir -p "$D/repo/docs/epics/$EPIC/status"
  : > "$D/repo/docs/epics/$EPIC/status/some-branch.json"
  : > "$D/repo/docs/epics/$EPIC/CANCEL"
  {
    printf '%s\n\n' "# Epic: fixture close epic"
    if [ "$ALREADY" = yes ]; then printf '%s\n' "**Status:** closed"
    else printf '%s\n' "**Status:** in flight (item 2 of 2)"
    fi
    printf '%s\n' "**Source:** GH #$ISSUE"
  } > "$D/repo/docs/epics/$EPIC/plan.md"
  "$REAL_GIT" -C "$D/repo" add -A
  "$REAL_GIT" -C "$D/repo" commit -q -m "docs(epic): file $EPIC"
  "$REAL_GIT" -C "$D/repo" push -q origin main

  mkdir -p "$D/repo/docs/epics/.intake/loop"
  cat > "$D/repo/docs/epics/.intake/loop/$ISSUE.json" <<EOF
{
  "issue": $ISSUE,
  "repo": "$SLUG",
  "epic": "docs/epics/$EPIC/plan.md",
  "state": "closing",
  "item": null,
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
  {
    printf '{"ts":"1970-01-01T00:00:00Z","issue":%s,"repo":"%s","from":"awaiting-merge","to":"merged","detail":"item 2 PR 900 merged into main"}\n' "$ISSUE" "$SLUG"
    printf '{"ts":"1970-01-01T00:00:01Z","issue":%s,"repo":"%s","from":"merged","to":"closing","detail":"epic last item merged"}\n' "$ISSUE" "$SLUG"
  } > "$D/repo/docs/epics/.intake/loop/ledger.jsonl"
}

# $1=case dir $2=**Epic:** field value to write into docs/epics/handoff.md,
# committed and pushed (a TRACKED file, unlike status/CANCEL/active-epic).
seed_handoff() {
  local D="$1" EPICVAL="$2"
  {
    printf '%s\n\n' "# Session Handoff"
    printf '%s\n' "**Epic:** $EPICVAL"
  } > "$D/repo/docs/epics/handoff.md"
  "$REAL_GIT" -C "$D/repo" add -A
  "$REAL_GIT" -C "$D/repo" commit -q -m "chore(epic): session handoff seed"
  "$REAL_GIT" -C "$D/repo" push -q origin main
}

# $1=case dir $2=pointer content (gitignored — never committed, plain rm).
seed_active_epic_pointer() {
  mkdir -p "$1/repo/.claude/signals"
  printf '%s' "$2" > "$1/repo/.claude/signals/active-epic"
}

run_gate_i() { # $1=case dir $2=slug $3=issue
  local D="$1" SLUG="$2" ISSUE="$3"
  # `local` here, not a bare global export: a temporary `VAR=val
  # run_gate_i ...` prefix on ONE call must not leak into the next
  # (unprefixed) call in this same shell — function scope, unlike a plain
  # command's temporary environment, does not revert on its own.
  local EPIC_LOOP_FIX_ISSUE_STATE="${EPIC_LOOP_FIX_ISSUE_STATE:-OPEN}"
  export HOME="$D/home"
  export INTAKE_GIT="$REAL_GIT"
  export INTAKE_GH="$GH_STUB_I"
  export INTAKE_REPO_SLUG_OVERRIDE="$SLUG"
  export INTAKE_STOP_FILE="$D/home/.config/claude-intake/STOP"
  export INTAKE_AUTONOMY_OVERRIDE="$D/home/.config/claude-intake/AUTONOMY-OFF"
  export INTAKE_PROMOTIONS_DIR="$D/home/.config/claude-intake/promotions"
  export INTAKE_AUTONOMY_FILE="$D/home/.config/claude-intake/autonomy"
  export EPIC_LOOP_FIX_CALLS="$D/gh-calls.log"
  export EPIC_LOOP_FIX_ISSUE_STATE
  export EPIC_LOOP_FIX_RETRO_OUT="$D/retro-out.txt"
  : > "$EPIC_LOOP_FIX_CALLS"
  : > "$EPIC_LOOP_FIX_RETRO_OUT"
  I_OUT="$(bash "$SCRIPT" --repo "$D/repo" --once 2>&1)"; I_RC=$?
  I_STATE="$(grep -o '"state": "[^"]*"' "$D/repo/docs/epics/.intake/loop/$ISSUE.json" 2>/dev/null \
               | head -1 | sed -E 's/.*"([a-zA-Z-]+)"$/\1/')"
  I_CALLS="$(cat "$EPIC_LOOP_FIX_CALLS" 2>/dev/null)"
  I_RETRO="$(cat "$EPIC_LOOP_FIX_RETRO_OUT" 2>/dev/null)"
}

# --- I1: the full success path — status/CANCEL/pointer/handoff all match
# this epic, issue still open. Everything comes down, in order. ------------
I1="$(mkcase_g i1-full-success)"
seed_closing_epic "$I1" "09-fixture-close" 901 "$I_SLUG"
seed_handoff "$I1" "docs/epics/09-fixture-close"
seed_active_epic_pointer "$I1" "09-fixture-close"
EPIC_LOOP_FIX_ISSUE_STATE=OPEN run_gate_i "$I1" "$I_SLUG" 901
check "I1 exit 0 (closed, not a crash)"                              "0" "$I_RC"
check "I1 state advances to closed"                                  "closed" "$I_STATE"
check_contains "I1 origin/main's plan.md now reads Status: closed"   1 \
      "$("$REAL_GIT" --git-dir="$I1/origin.git" show main:docs/epics/09-fixture-close/plan.md 2>/dev/null)" \
      '**Status:** closed'
check "I1 status/ removed from the checkout"                         "0" "$([ -e "$I1/repo/docs/epics/09-fixture-close/status" ] && echo 1 || echo 0)"
check "I1 CANCEL removed from the checkout"                          "0" "$([ -e "$I1/repo/docs/epics/09-fixture-close/CANCEL" ] && echo 1 || echo 0)"
check "I1 active-epic pointer removed (it named this epic)"          "0" "$([ -e "$I1/repo/.claude/signals/active-epic" ] && echo 1 || echo 0)"
check "I1 handoff.md removed from the checkout (it named this epic)" "0" "$([ -e "$I1/repo/docs/epics/handoff.md" ] && echo 1 || echo 0)"
check "I1 handoff.md removed from origin/main too (tracked file)"    "0" \
      "$("$REAL_GIT" --git-dir="$I1/origin.git" ls-tree --name-only main -- docs/epics/handoff.md 2>/dev/null | grep -c . | tr -d ' ')"
check "I1 gh issue comment WAS called"                                "1" "$(grep -c '^gh issue comment 901' <<<"$I_CALLS" | tr -d ' ')"
check_contains "I1 retro names the epic and the issue"               1 "$I_RETRO" "09-fixture-close closed by epic-loop"
check_contains "I1 retro includes a ledger transition line"          1 "$I_RETRO" "merged -> closing"
check "I1 gh issue close WAS called (issue was still open)"          "1" "$(grep -c '^gh issue close 901' <<<"$I_CALLS" | tr -d ' ')"

# --- I2: the active-epic pointer names a DIFFERENT epic — left alone. -----
I2="$(mkcase_g i2-pointer-other-epic)"
seed_closing_epic "$I2" "09-fixture-close" 902 "$I_SLUG"
seed_active_epic_pointer "$I2" "05-some-other-epic"
run_gate_i "$I2" "$I_SLUG" 902
check "I2 exit 0"                                                    "0" "$I_RC"
check "I2 state advances to closed regardless"                       "closed" "$I_STATE"
check "I2 the OTHER epic's pointer is untouched"                     "05-some-other-epic" "$(cat "$I2/repo/.claude/signals/active-epic" 2>/dev/null)"

# --- I3: handoff.md names a DIFFERENT epic — left alone. -------------------
I3="$(mkcase_g i3-handoff-other-epic)"
seed_closing_epic "$I3" "09-fixture-close" 903 "$I_SLUG"
seed_handoff "$I3" "docs/epics/05-some-other-epic"
run_gate_i "$I3" "$I_SLUG" 903
check "I3 exit 0"                                                    "0" "$I_RC"
check "I3 state advances to closed regardless"                       "closed" "$I_STATE"
check "I3 the OTHER epic's handoff.md is untouched in the checkout"  "1" "$([ -e "$I3/repo/docs/epics/handoff.md" ] && echo 1 || echo 0)"
check "I3 the OTHER epic's handoff.md is untouched on origin"        "1" \
      "$("$REAL_GIT" --git-dir="$I3/origin.git" ls-tree --name-only main -- docs/epics/handoff.md 2>/dev/null | grep -c . | tr -d ' ')"

# --- I4: the issue is ALREADY closed (the final PR's own Closes #n) — no
# redundant `gh issue close`, but the retro still posts. --------------------
I4="$(mkcase_g i4-issue-already-closed)"
seed_closing_epic "$I4" "09-fixture-close" 904 "$I_SLUG"
EPIC_LOOP_FIX_ISSUE_STATE=CLOSED run_gate_i "$I4" "$I_SLUG" 904
check "I4 exit 0"                                                    "0" "$I_RC"
check "I4 state advances to closed"                                  "closed" "$I_STATE"
check "I4 gh issue close was NEVER called (already closed)"          "0" "$(grep -c '^gh issue close' <<<"$I_CALLS" | tr -d ' ')"
check "I4 gh issue comment WAS still called"                         "1" "$(grep -c '^gh issue comment' <<<"$I_CALLS" | tr -d ' ')"

# --- I5: a human already set Status: closed by hand — no redundant close
# commit, cleanup and retro/issue-close still run. --------------------------
I5="$(mkcase_g i5-already-closed-by-human)"
seed_closing_epic "$I5" "09-fixture-close" 905 "$I_SLUG" yes
run_gate_i "$I5" "$I_SLUG" 905
check "I5 exit 0"                                                    "0" "$I_RC"
check "I5 state advances to closed"                                  "closed" "$I_STATE"
check "I5 no redundant 'docs(epic): close' commit was pushed"        "0" \
      "$("$REAL_GIT" --git-dir="$I5/origin.git" log --oneline main 2>/dev/null | grep -c 'docs(epic): close 09-fixture-close' | tr -d ' ')"
check "I5 status/ still removed on the already-closed path"          "0" "$([ -e "$I5/repo/docs/epics/09-fixture-close/status" ] && echo 1 || echo 0)"
check "I5 gh issue close WAS still called"                           "1" "$(grep -c '^gh issue close 905' <<<"$I_CALLS" | tr -d ' ')"

# --- I6: no epic recorded on the state file — refuses cleanly, touches
# nothing, state stays `closing` for a later cycle. --------------------------
I6="$(mkcase_g i6-no-epic-recorded)"
mkdir -p "$I6/repo/docs/epics/.intake/loop"
cat > "$I6/repo/docs/epics/.intake/loop/906.json" <<EOF
{
  "issue": 906,
  "repo": "$I_SLUG",
  "epic": "",
  "state": "closing",
  "item": null,
  "detail": "seed",
  "updated": "1970-01-01T00:00:00Z"
}
EOF
run_gate_i "$I6" "$I_SLUG" 906
check "I6 exit 0 (error reported, not a crash)"                      "0" "$I_RC"
check "I6 state stays closing (nothing to advance from)"             "closing" "$I_STATE"
check "I6 gh was never called"                                       "0" "$(grep -c '^gh ' <<<"$I_CALLS" | tr -d ' ')"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
