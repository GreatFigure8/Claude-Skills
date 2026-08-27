#!/usr/bin/env bash
# Drift fixture for the canonical output-discipline rule (GH #68, epic 12 item 2;
# extended by GH #75, epic 13 item 1):
#   ../../../../SKILL.md                                  ("Output discipline", Phase 3)
#   ../../agents/work-item-executor.md                     ("Communication discipline")
#
# Epic 12 item 1 stated the rule once in SKILL.md and pointed work-item-executor.md
# at it as the same rule rather than a second statement of it, replacing the old
# reader-facing rationale ("something Jonathan has to read past...") with the cost
# rationale (every self-narrating line is re-billed as input on every remaining turn
# of the agent's context). Epic 13 item 1 added pure-forward-announcement anti-examples
# (no recap prefix, unlike the epic-12 examples) and a disclaimer that the Forbidden
# phrasing block illustrates a pattern rather than an exhaustive blocklist. This
# harness has two jobs:
#
#   1. Assert BOTH real files still carry the three permitted exceptions verbatim
#      (a blocking question / a major issue / the completion return summary), and
#      that work-item-executor.md has not reacquired the reader-facing rationale.
#   2. Prove the assertion has teeth: every marker is also checked against a
#      throwaway mutated copy (marker line deleted, or "read past" reintroduced)
#      built in a sandbox, and the same detector is required to flip. A drift
#      fixture that cannot be shown failing is not a fixture.
#
# Nothing outside a fresh mktemp -d sandbox is ever written; the two real files are
# only ever read. Text-only assertions (grep -F), no jq/python3/git dependency.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/output-discipline-drift-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_MD="$HERE/../../../../SKILL.md"
EXEC_MD="$HERE/../../agents/work-item-executor.md"
for f in "$SKILL_MD" "$EXEC_MD"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 1; }
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/output-discipline-drift-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0

check() { # $1 label  $2 expected(0|1)  $3 actual(0|1)
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-70s exp=%s got=%s  %s\n' "$1" "$2" "$3" "$R"
}

has_text() { # $1 file  $2 literal substring -> prints 1 (present) or 0 (absent)
  if grep -qF -- "$2" "$1" 2>/dev/null; then printf '1'; else printf '0'; fi
}

remove_line() { # $1 src  $2 literal marker  $3 dest -> dest has every matching line dropped
  grep -v -F -- "$2" "$1" > "$3" 2>/dev/null || true
}

reintroduce_read_past() { # $1 src  $2 dest
  { cat "$1"; printf '\nEvery such line is something Jonathan has to read past to find the one that matters.\n'; } > "$2"
}

# --------------------------------------------------------------- the markers ----
# SKILL.md's Output discipline paragraph is a single line; each marker below is a
# literal substring of it. work-item-executor.md's exceptions are each their own
# line in the Communication discipline section.

SKILL_MARKERS=(
  "produces visible text in exactly three cases: a blocking question, a major issue worth flagging the moment it's found, or its return summary"
  "re-billed as input on every remaining turn of that agent's context"
)

EXEC_MARKERS=(
  "Produce visible text in exactly three cases:"
  "**A blocking question**"
  "**A major issue**"
  "**Your completion return summary**"
  "re-billed as input on every remaining turn of your"
  "Now let's implement."
  "Let's check if the tests still pass."
  "Now run gates: lint, typecheck, test, build."
  "illustrate a pattern, not an exhaustive blocklist"
)

FORBIDDEN='read past'

echo "sandbox:   $SANDBOX"
echo "SKILL.md:  $SKILL_MD"
echo "exec.md:   $EXEC_MD"
echo
echo "=== live files: the three-exception clause must still be present ========"

for m in "${SKILL_MARKERS[@]}"; do
  check "SKILL.md carries: ${m:0:52}..." 1 "$(has_text "$SKILL_MD" "$m")"
done
for m in "${EXEC_MARKERS[@]}"; do
  check "work-item-executor.md carries: ${m:0:52}..." 1 "$(has_text "$EXEC_MD" "$m")"
done

echo
echo "=== live files: the reader-facing rationale must not be back ============"

check "work-item-executor.md has no '$FORBIDDEN' wording" 0 "$(has_text "$EXEC_MD" "$FORBIDDEN")"
check "SKILL.md has no '$FORBIDDEN' wording" 0 "$(has_text "$SKILL_MD" "$FORBIDDEN")"

echo
echo "=== mutation regression: this fixture goes red if a marker is deleted ===="
echo "(each case mutates a THROWAWAY sandbox copy and re-runs the same detector;"
echo " a PASS here means: if the real file lost this marker, the block above"
echo " would flip from PASS to FAIL.)"

i=0
for m in "${SKILL_MARKERS[@]}"; do
  i=$((i + 1))
  MUT="$SANDBOX/skill-missing-$i.md"
  remove_line "$SKILL_MD" "$m" "$MUT"
  check "mutated SKILL.md (marker $i removed) reads as MISSING" 0 "$(has_text "$MUT" "$m")"
done

i=0
for m in "${EXEC_MARKERS[@]}"; do
  i=$((i + 1))
  MUT="$SANDBOX/exec-missing-$i.md"
  remove_line "$EXEC_MD" "$m" "$MUT"
  check "mutated work-item-executor.md (marker $i removed) reads as MISSING" 0 "$(has_text "$MUT" "$m")"
done

REINTRO="$SANDBOX/exec-read-past-reintroduced.md"
reintroduce_read_past "$EXEC_MD" "$REINTRO"
check "mutated work-item-executor.md (reader rationale reintroduced) reads as PRESENT" 1 "$(has_text "$REINTRO" "$FORBIDDEN")"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
