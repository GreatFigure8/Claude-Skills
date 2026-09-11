#!/usr/bin/env bash
# Integration test for `sprint-state.sh assert-branch` — runs against a throwaway git repo, no
# network. Usage: bash sprint-state-assert-branch-integration.sh (exit 0 = pass)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SS="$HERE/../bin/sprint-state.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q; export SPRINTS_DIR="$TMP/sprints"; cd "$TMP"
# `git checkout -b` only creates a real branch ref once a commit exists — an unborn HEAD just
# moves the pointer. Commit first so every branch we cut below is a real, checkout-able ref.
git commit -q --allow-empty -m init
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

# Explicit branch names throughout — never rely on git's default init branch.
LIVE_BRANCH="livebranch"
git checkout -q -b "$LIVE_BRANCH"

S1="$("$SS" new --live "$LIVE_BRANCH")"
INTEGRATION_BRANCH="sprint/$S1"
git checkout -q -b "$INTEGRATION_BRANCH"
git checkout -q -b elsewhere

OUT="$TMP/out.txt"; ERR="$TMP/err.txt"

# --target integration (default), on the correct branch: exit 0, no output.
git checkout -q "$INTEGRATION_BRANCH"
"$SS" assert-branch "$S1" >"$OUT" 2>"$ERR"; RC=$?
check "assert-branch integration: correct branch exits 0"        '[ "$RC" = 0 ]'
check "assert-branch integration: correct branch empty stdout"   '[ ! -s "$OUT" ]'
check "assert-branch integration: correct branch empty stderr"   '[ ! -s "$ERR" ]'

# --target integration, on an unrelated branch: exit 1, stderr names both branches.
git checkout -q elsewhere
"$SS" assert-branch "$S1" >"$OUT" 2>"$ERR"; RC=$?
check "assert-branch integration: unrelated branch exits 1"           '[ "$RC" = 1 ]'
check "assert-branch integration: stderr names expected branch"       'grep -q -- "$INTEGRATION_BRANCH" "$ERR"'
check "assert-branch integration: stderr names actual branch"         'grep -q -- "elsewhere" "$ERR"'

# --target live, on the correct branch: exit 0, no output.
git checkout -q "$LIVE_BRANCH"
"$SS" assert-branch "$S1" --target live >"$OUT" 2>"$ERR"; RC=$?
check "assert-branch live: correct branch exits 0"        '[ "$RC" = 0 ]'
check "assert-branch live: correct branch empty stdout"   '[ ! -s "$OUT" ]'
check "assert-branch live: correct branch empty stderr"   '[ ! -s "$ERR" ]'

# --target live, on an unrelated branch: exit 1, stderr names both branches.
git checkout -q elsewhere
"$SS" assert-branch "$S1" --target live >"$OUT" 2>"$ERR"; RC=$?
check "assert-branch live: unrelated branch exits 1"             '[ "$RC" = 1 ]'
check "assert-branch live: stderr names expected branch"         'grep -q -- "$LIVE_BRANCH" "$ERR"'
check "assert-branch live: stderr names actual branch"           'grep -q -- "elsewhere" "$ERR"'

echo "sprint-state assert-branch integration: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
