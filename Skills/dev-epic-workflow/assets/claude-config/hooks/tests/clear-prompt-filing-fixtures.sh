#!/usr/bin/env bash
# Drift fixture for the filing-ends-with-clear-prompt contract (GH #94, epic 20):
#   ../../../../SKILL.md                    (Phase 1 filing step, Session mode coding trigger)
#   ../../commands/intake.md                (/intake step 6)
#   ../../../../references/issue-intake.md  (Pickup path step 5)
#   ../../../../../clear-prompt/SKILL.md    (caller table)
#
# Epic 20 item 1 made filing end with "run clear-prompt, post the block, then stop" on
# all three dev-epic-workflow filing surfaces, and added a pasted `dev-epic-workflow
# prep-for-clear` block to Session mode's coding-session triggers. Item 2 made
# clear-prompt/SKILL.md name dev-epic-workflow as a second caller (the "epic filed,
# nothing dispatched" shape, distinct from mid-epic `/handoff`). This harness has two jobs:
#
#   1. Assert all five markers are present verbatim in the four real files, and
#   2. Prove the assertion has teeth: every marker is also checked against a throwaway
#      mutated copy (marker line dropped) built in a sandbox, and the same detector is
#      required to flip. A drift fixture that cannot be shown failing is not a fixture.
#
# Nothing outside a fresh mktemp -d sandbox is ever written; the four real files are
# only ever read. Text-only assertions (grep -F), no jq/python3/git dependency. This
# fixture tests prose drift only — it does not test hook behaviour and does not run
# any skill.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/clear-prompt-filing-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_MD="$HERE/../../../../SKILL.md"
INTAKE_MD="$HERE/../../commands/intake.md"
ISSUE_INTAKE_MD="$HERE/../../../../references/issue-intake.md"
CLEAR_PROMPT_MD="$HERE/../../../../../clear-prompt/SKILL.md"
for f in "$SKILL_MD" "$INTAKE_MD" "$ISSUE_INTAKE_MD" "$CLEAR_PROMPT_MD"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 1; }
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/clear-prompt-filing-fixtures.XXXXXX")" || exit 1
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

# --------------------------------------------------------------- the markers ----
# Each marker is a literal substring of a single line in the named file (grep -F is
# not multiline), taken verbatim from the current text.

SKILL_MARKERS=(
  "Filing has one more step after that, in the same turn: run \`clear-prompt\` with caller"
  "something; by resuming or continuing an in-flight epic; by a pasted \`dev-epic-workflow"
  "prep-for-clear\` block; or by Jonathan opening with \"this is a coding session.\" Scope is Phase 2"
)

INTAKE_MARKERS=(
  "- Run \`clear-prompt\` with caller \`dev-epic-workflow\`, post the block, then stop. Nothing"
)

ISSUE_INTAKE_MARKERS=(
  "even to a subagent (dev-epic-workflow's Session mode). Run \`clear-prompt\` with caller"
)

CLEAR_PROMPT_MARKERS=(
  "\`dev-story-sprint\` mid-sprint, \`dev-epic-workflow\` right after filing, before anything is dispatched"
)

echo "sandbox:          $SANDBOX"
echo "SKILL.md:         $SKILL_MD"
echo "intake.md:        $INTAKE_MD"
echo "issue-intake.md:  $ISSUE_INTAKE_MD"
echo "clear-prompt.md:  $CLEAR_PROMPT_MD"
echo
echo "=== live files: the five filing-contract markers must be present ========"

for m in "${SKILL_MARKERS[@]}"; do
  check "SKILL.md carries: ${m:0:52}..." 1 "$(has_text "$SKILL_MD" "$m")"
done
for m in "${INTAKE_MARKERS[@]}"; do
  check "intake.md carries: ${m:0:52}..." 1 "$(has_text "$INTAKE_MD" "$m")"
done
for m in "${ISSUE_INTAKE_MARKERS[@]}"; do
  check "issue-intake.md carries: ${m:0:52}..." 1 "$(has_text "$ISSUE_INTAKE_MD" "$m")"
done
for m in "${CLEAR_PROMPT_MARKERS[@]}"; do
  check "clear-prompt/SKILL.md carries: ${m:0:52}..." 1 "$(has_text "$CLEAR_PROMPT_MD" "$m")"
done

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
for m in "${INTAKE_MARKERS[@]}"; do
  i=$((i + 1))
  MUT="$SANDBOX/intake-missing-$i.md"
  remove_line "$INTAKE_MD" "$m" "$MUT"
  check "mutated intake.md (marker $i removed) reads as MISSING" 0 "$(has_text "$MUT" "$m")"
done

i=0
for m in "${ISSUE_INTAKE_MARKERS[@]}"; do
  i=$((i + 1))
  MUT="$SANDBOX/issue-intake-missing-$i.md"
  remove_line "$ISSUE_INTAKE_MD" "$m" "$MUT"
  check "mutated issue-intake.md (marker $i removed) reads as MISSING" 0 "$(has_text "$MUT" "$m")"
done

i=0
for m in "${CLEAR_PROMPT_MARKERS[@]}"; do
  i=$((i + 1))
  MUT="$SANDBOX/clear-prompt-missing-$i.md"
  remove_line "$CLEAR_PROMPT_MD" "$m" "$MUT"
  check "mutated clear-prompt/SKILL.md (marker $i removed) reads as MISSING" 0 "$(has_text "$MUT" "$m")"
done

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
