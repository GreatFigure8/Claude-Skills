#!/usr/bin/env bash
# Fixture harness for FAILURE-DRIVEN ISSUE FILING (epic 21 item 4):
# ../../bin/issue-filer.sh.
#
# WHAT THIS PROVES, mapped to the plan's own Definition of done and
# Verification lines ("a seeded failure produces exactly one filed issue;
# re-seeding the same failure produces zero new issues; fixture run
# demonstrates both cases"):
#
#   A  FINGERPRINT STABILITY — the same (check, evidence) pair hashes to the
#      same fingerprint every time, and a DIFFERENT pair hashes differently.
#      Incidental leading/trailing whitespace does not change it.
#   B  A SEEDED FAILURE WITH NO OPEN DUPLICATE — exactly one `gh issue create`
#      call, labelled `epic-loop-filed`, body names the discovering issue,
#      item, failing check and the evidence, and carries the fingerprint.
#   C  RE-SEEDING THE SAME FAILURE — an open issue already carries that
#      fingerprint -> zero `gh issue create` calls, a `skip` result naming the
#      duplicate's number.
#   D  A DIFFERENT FAILURE IS NOT DEDUPED AGAINST AN UNRELATED ONE — a
#      differently-fingerprinted open `epic-loop-filed` issue does not
#      suppress a new, distinct failure.
#   E  THE SEARCH ITSELF FAILING IS NOT READ AS "NO DUPLICATE" — a `gh issue
#      list` failure refuses (exit 2) rather than filing on unverified ground.
#
# Uses a STUB `gh` (no network, no tokens) so results are deterministic.
# Everything lives under one `mktemp -d` removed on exit.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/issue-filer-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
FILER="${INTAKE_FIXTURE_ISSUE_FILER:-$BIN_DIR/issue-filer.sh}"
[ -f "$FILER" ] || { echo "ERROR: not found: $FILER" >&2; exit 1; }
if ! grep -q '^ISSUE_FILER_CONTRACT=1$' "$FILER"; then
  echo "ERROR: $FILER carries no ISSUE_FILER_CONTRACT=1 — this suite tests" >&2
  echo "       epic 21 item 4. Against a tree that predates it there is" >&2
  echo "       nothing to test, and passing would be a lie. Aborting." >&2
  exit 1
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/issue-filer-fixtures.XXXXXX")" || exit 1
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
# Answers exactly the calls issue-filer.sh makes, from files the cases seed,
# and logs every call verbatim so a case can assert what was (or was not)
# invoked. Anything unanticipated exits 1, so a call this suite did not seed
# for is a visible failure rather than a silent empty answer.
mkdir -p "$SANDBOX/bin" "$SANDBOX/gh"
cat > "$SANDBOX/bin/gh" <<'GH_EOF'
#!/usr/bin/env bash
D="${GH_FIXTURE_DIR:?}"
printf '%s\n' "$*" >> "$D/calls.log"
case "${1:-}" in
  issue)
    case "${2:-}" in
      list) cat "$D/issue-list" 2>/dev/null; exit 0 ;;
      view)
        N="${3:-}"
        cat "$D/body-$N" 2>/dev/null; exit 0 ;;
      create)
        FAIL_FILE="$D/create-should-fail"
        if [ -e "$FAIL_FILE" ]; then
          echo "stub gh: issue create refused (fixture-seeded failure)" >&2
          exit 1
        fi
        # find --body-file's argument and stash a copy for the case to read
        PREV=""
        for A in "$@"; do
          if [ "$PREV" = "--body-file" ]; then cp "$A" "$D/last-created-body" 2>/dev/null; fi
          PREV="$A"
        done
        N="$(cat "$D/next-issue" 2>/dev/null || printf 501)"
        printf '%s\n' "$((N + 1))" > "$D/next-issue"
        printf 'https://github.com/fixture/repo/issues/%s\n' "$N"
        exit 0 ;;
    esac ;;
esac
echo "stub gh: unexpected call: $*" >&2
exit 1
GH_EOF
chmod +x "$SANDBOX/bin/gh"

export GH_FIXTURE_DIR="$SANDBOX/gh"
export INTAKE_GH="$SANDBOX/bin/gh"
: > "$SANDBOX/gh/calls.log"

filer() { bash "$FILER" "$@" 2>&1; }
create_call_count() { # exactly one line of output, always — no grep-rc-1-means-no-output surprises
  local N
  N="$(grep -c '^issue create ' "$SANDBOX/gh/calls.log" 2>/dev/null)"
  printf '%s' "${N:-0}"
}

echo "=== A. fingerprint stability ==="

FP1="$(filer --fingerprint --check "npm test" --evidence "FAIL src/foo.test.js")"
FP2="$(filer --fingerprint --check "npm test" --evidence "FAIL src/foo.test.js")"
FP3="$(filer --fingerprint --check "npm test" --evidence "FAIL src/bar.test.js")"
FP4="$(filer --fingerprint --check "  npm test  " --evidence "  FAIL src/foo.test.js  ")"
check "A1 same input -> same fingerprint"          "$FP1" "$FP2"
check "A2 different evidence -> different fingerprint" "yes" "$( [ "$FP1" != "$FP3" ] && printf yes || printf no )"
check "A3 incidental whitespace does not change it" "$FP1" "$FP4"
check "A4 fingerprint is non-empty"                 "yes" "$( [ -n "$FP1" ] && printf yes || printf no )"

echo
echo "=== B. a seeded failure with no open duplicate is filed exactly once ==="

printf '' > "$SANDBOX/gh/issue-list"     # no open epic-loop-filed issues at all
EVIDENCE_B="FAIL src/foo.test.js
  expect(1).toBe(2)"
FPB="$(filer --fingerprint --check "npm test" --evidence "$EVIDENCE_B")"
OUT="$(filer --file --slug fixture/repo --issue 7 --item 2 --check "npm test" --evidence "$EVIDENCE_B")"
check "B1 exit 0"                          "0" "$?"
check_contains "B2 result says filed"      1 "$OUT" "filed https://github.com/fixture/repo/issues/501"
check "B3 exactly one gh issue create call" "1" "$(create_call_count)"
check_contains "B4 body names the discovering issue" 1 "$(cat "$SANDBOX/gh/last-created-body")" "Issue: #7"
check_contains "B5 body names the discovering item"  1 "$(cat "$SANDBOX/gh/last-created-body")" "Item: 2"
check_contains "B6 body names the failing check"     1 "$(cat "$SANDBOX/gh/last-created-body")" 'npm test'
check_contains "B7 body carries the evidence"        1 "$(cat "$SANDBOX/gh/last-created-body")" "expect(1).toBe(2)"
check_contains "B8 body carries the fingerprint marker" 1 "$(cat "$SANDBOX/gh/last-created-body")" "epic-loop-fingerprint: $FPB"
check_contains "B9 create was labelled epic-loop-filed" 1 "$(tail -1 "$SANDBOX/gh/calls.log")" "--label epic-loop-filed"

echo
echo "=== C. re-seeding the same failure produces zero new issues ==="

: > "$SANDBOX/gh/calls.log"
printf '501\n' > "$SANDBOX/gh/issue-list"
cp "$SANDBOX/gh/last-created-body" "$SANDBOX/gh/body-501"
OUT="$(filer --file --slug fixture/repo --issue 7 --item 2 --check "npm test" --evidence "$EVIDENCE_B")"
check "C1 exit 0 (a correct skip, not a failure)" "0" "$?"
check_contains "C2 result says skip"              1 "$OUT" "skip #501"
check "C3 zero gh issue create calls"              "0" "$(create_call_count)"

echo
echo "=== D. a different failure is not deduped against an unrelated one ==="

: > "$SANDBOX/gh/calls.log"
OUT="$(filer --file --slug fixture/repo --issue 7 --item 2 --check "npm test" --evidence "FAIL src/bar.test.js")"
check "D1 exit 0"                    "0" "$?"
check_contains "D2 result says filed, not skip" 1 "$OUT" "filed https://github.com/fixture/repo/issues/502"
check "D3 exactly one gh issue create call"      "1" "$(create_call_count)"

echo
echo "=== E. the duplicate search failing is refused, never read as 'no duplicate' ==="

: > "$SANDBOX/gh/calls.log"
rm -f "$SANDBOX/gh/issue-list"   # stub still answers `issue list` with nothing but
                                  # this fixture asserts the FAILURE path, so make
                                  # the stub's `issue list` branch itself fail instead
mv "$SANDBOX/bin/gh" "$SANDBOX/bin/gh.real"
cat > "$SANDBOX/bin/gh" <<'GH_FAIL_EOF'
#!/usr/bin/env bash
D="${GH_FIXTURE_DIR:?}"
printf '%s\n' "$*" >> "$D/calls.log"
case "${1:-} ${2:-}" in
  "issue list") echo "stub gh: list refused (fixture-seeded failure)" >&2; exit 1 ;;
esac
echo "stub gh: unexpected call: $*" >&2
exit 1
GH_FAIL_EOF
chmod +x "$SANDBOX/bin/gh"
OUT="$(filer --file --slug fixture/repo --issue 7 --item 2 --check "npm test" --evidence "FAIL src/baz.test.js")"
check "E1 exit 2 (refused, not a clean file or skip)" "2" "$?"
check_contains "E2 the refusal names the list failure" 1 "$OUT" "could not list open"
check "E3 no issue was created"                        "0" "$(create_call_count)"
mv "$SANDBOX/bin/gh.real" "$SANDBOX/bin/gh"

echo
printf '%s case(s), %s failure(s)\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
