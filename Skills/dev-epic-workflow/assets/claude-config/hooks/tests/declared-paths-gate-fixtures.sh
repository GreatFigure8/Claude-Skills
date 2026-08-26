#!/usr/bin/env bash
# Fixture harness for THE PR GATE COMPARES DECLARATION AGAINST DIFF
# (epic 10 item 3): ../../bin/declared-paths-gate.sh
#
# WHAT THIS PROVES. That the gate reports BOTH mismatch directions —
# declared-but-untouched (did less than declared) and touched-but-undeclared
# (did more than declared) — independently and correctly labelled; that an
# item with no `**Touches:**` block reports "not declared" and exits 0 rather
# than failing; that a lookup error (unknown item, missing plan) exits 2
# rather than being read as either a clean pass or a mismatch; and that v1
# never blocks — a mismatch is exit 1, never a nonzero the caller would read
# as "the PR must not open."
#
# THE NEGATIVE CONTROL (case N), BUILT BRITTLE ON PURPOSE, same pattern epic
# 09 and epic 11's own suites use: a case that only proves something if it can
# be shown FAILING against a broken implementation. Here the break is the
# literal defect the plan calls out — the two comparison directions swapped —
# built as a throwaway mutated copy of the script in the sandbox. The
# under-reach case's assertion (that `c.txt` is reported under
# declared-but-untouched) is REQUIRED to fail against that mutant, proving the
# assertion is checking the label and not just "something was reported."
#
# Uses real git in a sandbox (the same choice worktree-provision-fixtures.sh
# makes): a worktree diff is the thing under test, so a fake diff would not
# test the seam that matters. Everything lives under one `mktemp -d` removed
# on exit; no path outside the sandbox is ever written to.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/declared-paths-gate-fixtures.sh
#         INTAKE_FIXTURE_GATE_SCRIPT=/path/to/other-declared-paths-gate.sh bash ...
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
GATE="${INTAKE_FIXTURE_GATE_SCRIPT:-$BIN_DIR/declared-paths-gate.sh}"
[ -f "$GATE" ] || { echo "ERROR: not found: $GATE" >&2; exit 1; }

command -v git >/dev/null 2>&1 || { echo "ERROR: git not on PATH" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/declared-paths-gate-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

REPO="$SANDBOX/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email fixture@test.local
git -C "$REPO" config user.name fixture

FAILURES=0
CASES=0

check() { # $1 label  $2 expected(int)  $3 actual(int)
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-62s exp=%s got=%s  %s\n' "$1" "$2" "$3" "$R"
}

check_contains() { # $1 label  $2 expected(0|1 present)  $3 haystack  $4 needle
  CASES=$((CASES + 1))
  local GOT=0
  case "$3" in *"$4"*) GOT=1 ;; esac
  if [ "$2" = "$GOT" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-62s exp=%s got=%s  %s\n' "$1" "$2" "$GOT" "$R"
}

PLAN="$REPO/plan.md"
cat_plan() {
  {
    printf '%s\n' '# Epic: fixture'
    printf '%s\n' ''
    printf '%s\n' '## Work items'
    printf '%s\n' ''
    printf '%s\n' '### 1. exact match'
    printf '%s\n' '- **Scope:** does stuff'
    printf '%s\n' '- **Touches:**'
    printf '%s\n' '  - `a.txt`'
    printf '%s\n' '  - `b.txt`'
    printf '%s\n' '- **Not in scope:** nothing'
    printf '%s\n' ''
    printf '%s\n' '### 2. under-and-over'
    printf '%s\n' '- **Scope:** does stuff'
    printf '%s\n' '- **Touches:**'
    printf '%s\n' '  - `a.txt`'
    printf '%s\n' '  - `c.txt`'
    printf '%s\n' '- **Not in scope:** nothing'
    printf '%s\n' ''
    printf '%s\n' '### 3. no touches block'
    printf '%s\n' '- **Scope:** does stuff'
    printf '%s\n' '- **Not in scope:** nothing'
    printf '%s\n' ''
    printf '%s\n' '### 4. malformed touches line'
    printf '%s\n' '- **Scope:** does stuff'
    printf '%s\n' '- **Touches:**'
    printf '%s\n' '  - `a.txt`'
    printf '%s\n' '  - `foo.sh` (renamed from bar.sh)'
    printf '%s\n' '  - `e.txt`'
    printf '%s\n' '- **Not in scope:** nothing'
  } > "$PLAN"
}
cat_plan
git -C "$REPO" add -A
git -C "$REPO" commit -q -m base
git -C "$REPO" tag basepoint

mk_branch() { # $1 = branch name, remaining args = files to create
  local NAME="$1"; shift
  git -C "$REPO" checkout -q -b "$NAME" basepoint
  local F
  for F in "$@"; do : > "$REPO/$F"; done
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "$NAME"
}

# exact: item 1 declares a.txt, b.txt; branch touches exactly those
mk_branch exact-branch a.txt b.txt
# underreach: item 2 declares a.txt, c.txt; branch touches only a.txt (c.txt
# never landed — declared-but-untouched)
mk_branch underreach-branch a.txt
# both: item 2 declares a.txt, c.txt; branch touches a.txt, d.txt (c.txt
# under-reach, d.txt over-reach, at the same time)
mk_branch both-branch a.txt d.txt
# malformed: item 4 declares a.txt, (a malformed bullet), e.txt; branch
# touches exactly a.txt and e.txt — proves a malformed continuation line
# (a `path` bullet with a trailing annotation, matching no strict pattern)
# does not silently truncate extraction and drop e.txt from the declared set
mk_branch malformed-branch a.txt e.txt

run_gate() { # $1 script  $2 item  $3 head-branch -> stdout+stderr combined, sets RC
  GATE_OUT="$("$1" --plan "$PLAN" --item "$2" --base basepoint --head "$3" --repo "$REPO" 2>&1)"
  RC=$?
}

echo "gate:   $GATE"
echo "sandbox: $SANDBOX"
echo
echo "=== A. exact match — clean, exit 0 ============================"
run_gate "$GATE" 1 exact-branch
check "A1 exit 0 on exact match" 0 "$RC"
check_contains "A2 reports 'match'" 1 "$GATE_OUT" "match: every declared path was touched"

echo
echo "=== B. declared-but-untouched only — WARN, exit 1 =============="
run_gate "$GATE" 2 underreach-branch
check "B1 exit 1 on under-reach" 1 "$RC"
check_contains "B2 names c.txt under declared-but-untouched" 1 "$GATE_OUT" \
'declared-but-untouched (declared, never touched — did LESS than declared):
    - c.txt'
check_contains "B3 does not report touched-but-undeclared" 0 "$GATE_OUT" "touched-but-undeclared"

echo
echo "=== C. both directions at once — WARN, exit 1 =================="
run_gate "$GATE" 2 both-branch
check "C1 exit 1 on both-direction mismatch" 1 "$RC"
check_contains "C2 names c.txt under declared-but-untouched" 1 "$GATE_OUT" "- c.txt"
check_contains "C3 names d.txt under touched-but-undeclared" 1 "$GATE_OUT" "- d.txt"
check_contains "C4 states v1 does not block" 1 "$GATE_OUT" "WARN only — v1 does not block the PR"

echo
echo "=== D. no Touches block — 'not declared', exit 0 ================"
run_gate "$GATE" 3 exact-branch
check "D1 exit 0 on absent field" 0 "$RC"
check_contains "D2 reports 'not declared'" 1 "$GATE_OUT" "not declared"

echo
echo "=== E. lookup errors — exit 2, never read as clean or WARN ======"
run_gate "$GATE" 99 exact-branch
check "E1 unknown item number exits 2" 2 "$RC"
run_gate "$GATE" "" exact-branch
check "E2 missing --item exits 2" 2 "$RC"
GATE_OUT="$("$GATE" --plan "$REPO/no-such-plan.md" --item 1 --base basepoint --head exact-branch --repo "$REPO" 2>&1)"; RC=$?
check "E3 missing plan file exits 2" 2 "$RC"

echo
echo "=== F. malformed Touches line — warns, does not silently truncate ==="
run_gate "$GATE" 4 malformed-branch
check "F1 exit 0 — e.txt still counted as declared and touched" 0 "$RC"
check_contains "F2 warns about the unparsed line on stderr" 1 "$GATE_OUT" \
  "warning: item 4 has an unparsed line in its Touches block"
check_contains "F3 does not report e.txt as touched-but-undeclared" 0 "$GATE_OUT" \
  "touched-but-undeclared"
check_contains "F4 does not report e.txt as declared-but-untouched" 0 "$GATE_OUT" \
  "declared-but-untouched"

echo
echo "=== N. negative control: directions swapped must be CAUGHT ======"
echo "(a throwaway mutant with the two comparison directions inverted; the"
echo " under-reach assertion above is required to FAIL against it — a PASS"
echo " here means this suite actually discriminates, not just checks output"
echo " is nonempty)"

MUTANT="$SANDBOX/declared-paths-gate.inverted.sh"
sed \
  -e 's/UNDER="\$(_declared_paths_gate_diff_set "\$DECLARED" "\$DIFF")"/UNDER="$(_declared_paths_gate_diff_set "$DIFF" "$DECLARED")"/' \
  -e 's/OVER="\$(_declared_paths_gate_diff_set "\$DIFF" "\$DECLARED")"/OVER="$(_declared_paths_gate_diff_set "$DECLARED" "$DIFF")"/' \
  "$GATE" > "$MUTANT"
chmod +x "$MUTANT"
if ! diff -q "$GATE" "$MUTANT" >/dev/null 2>&1; then :; else
  echo "ERROR: mutant is byte-identical to $GATE — the sed patterns did not match; aborting" >&2
  exit 1
fi

run_gate "$MUTANT" 2 underreach-branch
MUTANT_HAS_CORRECT_LABEL=0
case "$GATE_OUT" in
  *'declared-but-untouched (declared, never touched — did LESS than declared):
    - c.txt'*) MUTANT_HAS_CORRECT_LABEL=1 ;;
esac
check "N1 mutant still exits 1 (a mismatch exists either way)" 1 "$RC"
check "N2 mutant reports c.txt under the WRONG direction (inversion caught)" 0 "$MUTANT_HAS_CORRECT_LABEL"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
