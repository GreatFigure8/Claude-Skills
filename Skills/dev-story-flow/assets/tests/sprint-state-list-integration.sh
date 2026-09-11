#!/usr/bin/env bash
# Integration test for `sprint-state.sh list`'s field-5 done/total counter — runs against a
# throwaway git repo, no network. Usage: bash sprint-state-list-integration.sh (exit 0 = pass)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SS="$HERE/../bin/sprint-state.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q; export SPRINTS_DIR="$TMP/sprints"; cd "$TMP"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

S1="$("$SS" new --live main)"
"$SS" story add "$S1" create-home-page --title "Create the home page" --kind interactive >/dev/null
"$SS" story add "$S1" add-chat-endpoint --title "Chat endpoint" --kind service >/dev/null
"$SS" story set "$S1" create-home-page done --force >/dev/null

LINE="$("$SS" list | grep "^$S1")"
EXPECTED="$S1"$'\t'"drafting"$'\t'"-"$'\t'"-"$'\t'"1/2"

check "list line has 5 tab-separated fields"    '[ "$(printf "%s" "$LINE" | awk -F"\t" "{print NF}")" = 5 ]'
check "list line matches expected exactly"      '[ "$LINE" = "$EXPECTED" ]'

echo "sprint-state list integration: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
