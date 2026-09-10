#!/usr/bin/env bash
# Fixture harness for THE SESSION-SCOPED ISSUE LOOP's deterministic half
# (epic 21 item 3): ../../bin/session-loop.sh.
#
# WHAT THIS PROVES, mapped to the plan's own Verification line ("dry-run
# against >= 2 seeded issues shows correct chaining and a clean stop") and to
# the epic's Invariants:
#
#   A  ADMISSION is the epic's invariant, checked against the BODY: an issue
#      needs human-authored requirements AND acceptance criteria with real
#      content. A `Derived acceptance criteria` section — Claude's half — does
#      not admit anything, and a one-line stub is not "detailed".
#   B  ONE REPO, ONE LOOP: a second --start naming a different checkout is
#      refused, not accommodated. (Plan: multi-repo is out of scope by name.)
#   C  CHAINING: --dry-run over TWO seeded admitted issues previews both, in
#      filing order, each with draft -> dispatch -> verify -> merge -> close.
#   D  A CLEAN STOP: after --stop, --next answers `stop` as its FIRST action
#      and the preview runs nothing.
#   E  THE HARM FLOOR IS REALLY CALLED: with STOP present, --next answers
#      `halt` and exits 3 — the brake lives in the driver, so a session cannot
#      skip it by forgetting.
#   F  NOT HEADLESS, MECHANICALLY: the driver contains no `claude` invocation.
#      This is the property that distinguishes epic 21's loop from the daemon
#      it replaced, and it is the one a future edit is most likely to break.
#   G  THE PER-ISSUE STATE MACHINE advances only through --record, and the loop
#      record lets go of an issue that reaches a terminal state.
#
# Uses a REAL git repo in a sandbox (the canonical-repo-root resolution is the
# thing being exercised) and a STUB `gh` (no network, no tokens, and the
# seeded issues have to be deterministic). Everything lives under one
# `mktemp -d` removed on exit.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-loop-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
LOOP="${INTAKE_FIXTURE_SESSION_LOOP:-$BIN_DIR/session-loop.sh}"
[ -f "$LOOP" ] || { echo "ERROR: not found: $LOOP" >&2; exit 1; }
if ! grep -q '^session_loop_next()' "$LOOP"; then
  echo "ERROR: $LOOP carries no session_loop_next() — this suite tests epic 21" >&2
  echo "       item 3. Against a tree that predates it there is nothing to test," >&2
  echo "       and passing would be a lie. Aborting." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "ERROR: git not on PATH" >&2; exit 1; }
REAL_GIT="$(command -v git)"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/session-loop-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s exp=[%s] got=[%s]  %s\n' "$1" "$2" "$3" "$R"
}
check_contains() { # $1 label  $2 expected(0|1 present)  $3 haystack  $4 needle
  CASES=$((CASES + 1))
  GOT=0
  case "$3" in *"$4"*) GOT=1 ;; esac
  if [ "$2" = "$GOT" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s exp=%s got=%s  %s\n' "$1" "$2" "$GOT" "$R"
}

# ------------------------------------------------------------- the stub `gh`
# Answers exactly the queries the driver makes, from files the cases seed.
# Anything else exits 1, so an unanticipated call is a visible failure rather
# than a silent empty answer.
mkdir -p "$SANDBOX/bin" "$SANDBOX/gh"
cat > "$SANDBOX/bin/gh" <<'GH_EOF'
#!/usr/bin/env bash
D="${GH_FIXTURE_DIR:?}"
case "${1:-}" in
  repo)   cat "$D/slug" 2>/dev/null; exit 0 ;;
  issue)
    case "${2:-}" in
      list) cat "$D/issue-list" 2>/dev/null; exit 0 ;;
      view)
        N="${3:-}"
        for A in "$@"; do case "$A" in body) cat "$D/body-$N" 2>/dev/null; exit 0 ;; esac; done
        cat "$D/labels-$N" 2>/dev/null; exit 0 ;;
    esac ;;
  pr)
    for A in "$@"; do case "$A" in --head) cat "$D/pr-head" 2>/dev/null; exit 0 ;; esac; done
    cat "$D/pr-list" 2>/dev/null; exit 0 ;;
  api)    cat "$D/branches" 2>/dev/null; exit 0 ;;
esac
echo "stub gh: unexpected call: $*" >&2
exit 1
GH_EOF
chmod +x "$SANDBOX/bin/gh"

export GH_FIXTURE_DIR="$SANDBOX/gh"
export INTAKE_GH="$SANDBOX/bin/gh"
export INTAKE_GIT="$REAL_GIT"
export INTAKE_STOP_FILE="$SANDBOX/NO-STOP"           # absent by default
export INTAKE_AUTONOMY_OVERRIDE="$SANDBOX/NO-OVERRIDE"
export INTAKE_AUTONOMY_FILE="$SANDBOX/no-autonomy-config"
export INTAKE_SESSION_LOOP_MARKER="$SANDBOX/session-loop-marker"

printf 'GreatFigure8/fixture-repo\n' > "$SANDBOX/gh/slug"

mkrepo() { # $1 = path
  mkdir -p "$1/docs/epics"
  "$REAL_GIT" -C "$1" init -q 2>/dev/null
  "$REAL_GIT" -C "$1" config user.email f@x >/dev/null 2>&1
  "$REAL_GIT" -C "$1" config user.name Fixture >/dev/null 2>&1
  : > "$1/README"
  "$REAL_GIT" -C "$1" add -A >/dev/null 2>&1
  "$REAL_GIT" -C "$1" commit -qm init >/dev/null 2>&1
}
REPO="$SANDBOX/repo"
REPO2="$SANDBOX/repo2"
mkrepo "$REPO"
mkrepo "$REPO2"

loop() { bash "$LOOP" "$@" 2>&1; }

echo "=== A. admission is checked against the body, not claimed by a label ==="

# Sourced so the body check is exercised on its own, with no gh in the way.
# shellcheck disable=SC1090
. "$LOOP"

# A here-doc, never a pipe: the function sets SESSION_LOOP_ADMIT_REASON, and a
# pipe would run it in a subshell where that reason dies (A5 exists to prove
# the driver itself does not make that mistake either).
ADMIT_OK() {
  session_loop_body_admits <<ADMIT_EOF && printf yes || printf no
$1
ADMIT_EOF
}

BODY_GOOD='## Human-authored

### Requirements
R1. The loop must admit only specified work.
R2. It must park everything else.

### Acceptance criteria
AC1. An issue with both sections is admitted.
AC2. An issue missing either is parked.
'
BODY_NO_AC='### Requirements
R1. Something.
R2. Something else.
'
BODY_DERIVED_ONLY='### Requirements
R1. Something.
R2. Something else.

### Derived acceptance criteria
- DAC1 -> R1: a machine wrote this.
- DAC2 -> R2: and this.
'
BODY_THIN='### Requirements
R1. Something.

### Acceptance criteria
AC1. One line only.
'
check "A1 both sections with content    -> admitted" "yes" "$(ADMIT_OK "$BODY_GOOD")"
check "A2 no acceptance criteria        -> parked"   "no"  "$(ADMIT_OK "$BODY_NO_AC")"
check "A3 DERIVED criteria only         -> parked"   "no"  "$(ADMIT_OK "$BODY_DERIVED_ONLY")"
check "A4 one line per section          -> parked"   "no"  "$(ADMIT_OK "$BODY_THIN")"
ADMIT_OK "$BODY_NO_AC" >/dev/null
check_contains "A5 the refusal names what is missing" 1 \
  "$SESSION_LOOP_ADMIT_REASON" "no detailed 'acceptance criteria' section"

echo
echo "=== B. one repo, one loop, one live session ==="

OUT="$(loop --start --repo "$REPO")"
check_contains "B1 --start binds the loop"              1 "$OUT" "state          running"
check_contains "B2 --start names the canonical root"    1 "$OUT" "$REPO"
loop --start --repo "$REPO2" >"$SANDBOX/b3.out" 2>&1
check "B3 a second --start on another repo is refused (exit 2)" "2" "$?"
check_contains "B4 and says why"                        1 "$(cat "$SANDBOX/b3.out")" "One loop, one repo"
# Same repo again is idempotent, not a refusal — a session restart must not be
# a failure state.
loop --start --repo "$REPO" >/dev/null 2>&1
check "B5 re-starting the SAME repo is allowed"          "0" "$?"

echo
echo "=== C. chaining: dry-run over two seeded admitted issues ==="

printf '%s\n' "$BODY_GOOD" > "$SANDBOX/gh/body-7"
printf '%s\n' "$BODY_GOOD" > "$SANDBOX/gh/body-42"
printf '%s\n' "$BODY_NO_AC" > "$SANDBOX/gh/body-99"
printf ',epic-loop-ready,bug,\n' > "$SANDBOX/gh/labels-7"
printf ',epic-loop-ready,\n'     > "$SANDBOX/gh/labels-42"
printf ',epic-loop-ready,\n'     > "$SANDBOX/gh/labels-99"
# Deliberately listed newest-first, to prove the loop re-orders to filing order.
{ printf '42\tsecond issue\n'; printf '7\tfirst issue\n'; printf '99\tunspecified issue\n'; } > "$SANDBOX/gh/issue-list"

DRY="$(loop --next --repo "$REPO" --dry-run)"
check_contains "C1 preview labels itself a preview"      1 "$DRY" "not a claim"
check_contains "C2 issue 7 previewed"                    1 "$DRY" "issue #7"
check_contains "C3 issue 42 previewed"                   1 "$DRY" "issue #42"
check_contains "C4 the unspecified issue is parked"      1 "$DRY" "no detailed 'acceptance criteria' section"
check_contains "C5 draft is previewed"                   1 "$DRY" "draft"
check_contains "C6 merge names the harm check"           1 "$DRY" "harm check against the real diff"
check_contains "C7 close is previewed"                   1 "$DRY" "close"
check_contains "C8 both admitted issues counted"         1 "$DRY" "2 admitted issue(s)"
# Filing order, not listing order: #7 must appear before #42 in the output.
POS7="$(printf '%s\n' "$DRY" | grep -n 'issue #7' | head -1 | cut -d: -f1)"
POS42="$(printf '%s\n' "$DRY" | grep -n 'issue #42' | head -1 | cut -d: -f1)"
check "C9 oldest issue is chained first" "yes" "$( [ "${POS7:-0}" -lt "${POS42:-0}" ] && printf yes || printf no )"

echo
echo "=== D. the live decision, and a clean stop ==="

OUT="$(loop --next --repo "$REPO")"
check_contains "D1 with no epic filed, the next action is draft" 1 "$OUT" "action         draft"
check_contains "D2 and it names the admitted issue"              1 "$OUT" "issue          7"

loop --stop --repo "$REPO" --detail "fixture stop" >/dev/null 2>&1
OUT="$(loop --next --repo "$REPO")"
check "D3 after --stop the FIRST action is stop" "stop" \
  "$(printf '%s\n' "$OUT" | awk '$1=="action"{print $2; exit}')"
check_contains "D4 the stop reason is carried"   1 "$OUT" "halts before the next action"
DRY="$(loop --next --repo "$REPO" --dry-run)"
check_contains "D5 the preview runs nothing after a stop" 1 "$DRY" "nothing below would run"
check_contains "D6 the preview does not chain issue 7"    0 "$DRY" "issue #7"
check_contains "D7 --status reports the stop"             1 "$(loop --status --repo "$REPO")" "stop           yes"

echo
echo "=== E. the harm floor is consulted by the driver, not by the session ==="

# Fresh loop record, and STOP present. The action must be `halt`, exit 3 —
# distinct from `blocked`, because STOP stops the machine and a denylist hit
# only stops one action.
rm -rf "$REPO/docs/epics/.intake"
loop --start --repo "$REPO" >/dev/null 2>&1
: > "$SANDBOX/STOP"
INTAKE_STOP_FILE="$SANDBOX/STOP" loop --next --repo "$REPO" > "$SANDBOX/e.out" 2>&1
check "E1 STOP present -> exit 3" "3" "$?"
check "E2 and the action is halt, not blocked" "halt" \
  "$(awk '$1=="action"{print $2; exit}' "$SANDBOX/e.out")"
check_contains "E3 the refusal names STOP"  1 "$(cat "$SANDBOX/e.out")" "STOP present"
rm -f "$SANDBOX/STOP"

echo
echo "=== F. not headless, mechanically ==="

check "F1 the driver declares itself non-invoking" "yes" \
  "$(grep -q '^SESSION_LOOP_INVOKES_CLAUDE=no$' "$LOOP" && printf yes || printf no)"
# Any `claude` INVOCATION — the word as a command with a flag after it. Comment
# lines are stripped first: this file's own header explains at length that it
# never calls claude, and that prose must not read as the thing it forbids.
CODE="$(grep -v '^[[:space:]]*#' "$LOOP")"
check "F2 no claude invocation in the driver" "0" \
  "$(printf '%s\n' "$CODE" | grep -cE '(^|[^-[:alnum:]_])claude([[:space:]]+-|_BIN|[[:space:]]*")' | tr -d ' ')"
check "F3 no CLAUDE_BIN variable in code" "0" \
  "$(printf '%s\n' "$CODE" | grep -c 'CLAUDE_BIN' | tr -d ' ')"

echo
echo "=== G. the per-issue state machine advances only through --record ==="

loop --record --repo "$REPO" --issue 7 --state dispatching --item 1 --branch feat/x >/dev/null 2>&1
check "G1 --record writes the issue state" "0" "$?"
OUT="$(loop --status --repo "$REPO")"
check_contains "G2 --status shows the active issue"      1 "$OUT" "issue          7"
check_contains "G3 --status shows its phase"             1 "$OUT" "issue-state    dispatching"
check_contains "G4 --status shows its branch"            1 "$OUT" "issue-branch   feat/x"
loop --record --repo "$REPO" --issue 7 --state closed --detail done >/dev/null 2>&1
OUT="$(loop --status --repo "$REPO")"
check_contains "G5 a terminal issue is released by the loop record" 1 "$OUT" "issue          <none>"
check "G6 the ledger recorded every transition" "yes" \
  "$( [ "$(grep -c . "$REPO/docs/epics/.intake/session-loop/ledger.jsonl" 2>/dev/null || printf 0)" -ge 3 ] && printf yes || printf no )"
check "G7 the state tree is git-invisible" "" \
  "$("$REAL_GIT" -C "$REPO" status --porcelain -- docs/epics 2>/dev/null | grep -c intake | sed 's/^0$//')"

echo
echo "=== H. the merge harm check fails CLOSED when its input is missing ==="

# The denylist half of the harm floor is only as strong as the path list fed
# to it, and an empty list clears it trivially. The merge gate builds that list
# with `git diff --name-only <integration>...<branch>`, and this driver never
# fetches — so the diff can fail outright. A failed diff and an empty diff both
# arrive as "", and neither may be read as "nothing harmful to find".
rm -rf "$REPO/docs/epics/.intake"
loop --start --repo "$REPO" >/dev/null 2>&1
INTEGRATION="$("$REAL_GIT" -C "$REPO" symbolic-ref --short HEAD 2>/dev/null)"

# The epic the merge gate needs: related to issue #7 by the `Source:` line the
# whole workflow already uses, never by a name convention.
mkdir -p "$REPO/docs/epics/07-fixture-epic"
cat > "$REPO/docs/epics/07-fixture-epic/plan.md" <<PLAN_EOF
# Fixture epic

**Source:** GH #7
**Integration branch:** \`$INTEGRATION\`
**Status:** approved
PLAN_EOF

# H1/H2 — the diff COMMAND FAILS: feat/ghost does not exist, so the range does
# not resolve and git exits non-zero.
loop --record --repo "$REPO" --issue 7 --state verified --item 1 --branch feat/ghost >/dev/null 2>&1
loop --next --repo "$REPO" > "$SANDBOX/h-ghost.out" 2>&1
check "H1 an unresolvable merge diff refuses (exit 3)" "3" "$?"
check "H2 and the action is blocked, not merge" "blocked" \
  "$(awk '$1=="action"{print $2; exit}' "$SANDBOX/h-ghost.out")"
check_contains "H3 the refusal names the missing input" 1 \
  "$(cat "$SANDBOX/h-ghost.out")" "merge harm check has no input"

# H4/H5 — the diff SUCCEEDS and names ZERO paths: a real branch at the same
# commit as the integration branch. rc 0, empty output — the case that used to
# clear the floor vacuously.
"$REAL_GIT" -C "$REPO" branch feat/no-op "$INTEGRATION" >/dev/null 2>&1
loop --record --repo "$REPO" --issue 7 --state verified --item 1 --branch feat/no-op >/dev/null 2>&1
loop --next --repo "$REPO" > "$SANDBOX/h-noop.out" 2>&1
check "H4 a zero-path merge diff refuses (exit 3)" "3" "$?"
check "H5 and the action is blocked, not merge" "blocked" \
  "$(awk '$1=="action"{print $2; exit}' "$SANDBOX/h-noop.out")"
check_contains "H6 the refusal says the diff named zero files" 1 \
  "$(cat "$SANDBOX/h-noop.out")" "zero changed files"

# H7 — THE CONTROL. A branch with a real, non-denylisted change still merges:
# the gate above must fail closed on missing input WITHOUT refusing real work.
"$REAL_GIT" -C "$REPO" checkout -q -b feat/real "$INTEGRATION" >/dev/null 2>&1
mkdir -p "$REPO/docs"
printf 'a real change\n' > "$REPO/docs/notes.md"
# Only the one file: `add -A` would sweep the untracked fixture plan.md into
# this branch, and checking back out would then delete the very epic the merge
# gate has to find.
"$REAL_GIT" -C "$REPO" add docs/notes.md >/dev/null 2>&1
"$REAL_GIT" -C "$REPO" commit -qm "fixture change" >/dev/null 2>&1
"$REAL_GIT" -C "$REPO" checkout -q "$INTEGRATION" >/dev/null 2>&1
loop --record --repo "$REPO" --issue 7 --state verified --item 1 --branch feat/real >/dev/null 2>&1
loop --next --repo "$REPO" > "$SANDBOX/h-real.out" 2>&1
check "H7 a real diff still reaches the merge action (exit 0)" "0" "$?"
check "H8 and the action is merge" "merge" \
  "$(awk '$1=="action"{print $2; exit}' "$SANDBOX/h-real.out")"
check_contains "H9 the merge action reports the harm check passing" 1 \
  "$(cat "$SANDBOX/h-real.out")" "harm-check     pass (merge)"

echo
printf '%s case(s), %s failure(s)\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
