#!/usr/bin/env bash
# Fixture tests for assets/bin/sprint-state.sh — runs in a throwaway git repo, no network.
# Usage: bash sprint-state-fixtures.sh   (exit 0 = all pass)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SS="$HERE/../bin/sprint-state.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q; export SPRINTS_DIR="$TMP/sprints"; cd "$TMP"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }
field(){ python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"m": m}))' "$SPRINTS_DIR/$1/sprint.json" "$2"; }

# --- new -----------------------------------------------------------------------------------
S1="$("$SS" new --live main)"
check "new prints YYYY-MM-DD-001"           '[[ "$S1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-001$ ]]'
check "new writes manifest"                 '[ -f "$SPRINTS_DIR/$S1/sprint.json" ]'
check "new status drafting"                 '[ "$(field "$S1" "m[\"status\"]")" = drafting ]'
check "new default integration"             '[ "$(field "$S1" "m[\"branch\"][\"integration\"]")" = "sprint/$S1" ]'
S2="$("$SS" new --integration none)"
check "second new increments index"         '[[ "$S2" =~ -002$ ]]'
check "integration none honoured"           '[ "$(field "$S2" "m[\"branch\"][\"integration\"]")" = none ]'

# --- list ----------------------------------------------------------------------------------
check "list shows both"                     '[ "$("$SS" list | wc -l | tr -d " ")" = 2 ]'
check "list filters by status"              '[ "$("$SS" list drafting | wc -l | tr -d " ")" = 2 ] && [ -z "$("$SS" list planned)" ]'
check "list rejects unknown status"         '! "$SS" list bogus 2>/dev/null'

# --- story add -----------------------------------------------------------------------------
check "story add ok"                        '"$SS" story add "$S1" create-home-page --title "Create the home page" --kind interactive >/dev/null'
check "story add with issue"                '"$SS" story add "$S1" add-chat-endpoint --title "Chat endpoint" --kind service --issue 42 >/dev/null'
check "story issue stored as int"           '[ "$(field "$S1" "m[\"stories\"][1][\"issue\"]")" = 42 ]'
check "story add rejects dup slug"          '! "$SS" story add "$S1" create-home-page --title x --kind service 2>/dev/null'
check "story add rejects bad kind"          '! "$SS" story add "$S1" other --title x --kind ui 2>/dev/null'
check "story add rejects bad slug"          '! "$SS" story add "$S1" Bad_Slug --title x --kind service 2>/dev/null'

# --- sprint transitions --------------------------------------------------------------------
check "illegal jump refused"                '! "$SS" set "$S1" complete 2>/dev/null'
check "drafting -> ready-to-plan"           '"$SS" set "$S1" ready-to-plan --by creator >/dev/null'
check "story add refused after drafting"    '! "$SS" story add "$S1" late --title x --kind service 2>/dev/null'
check "ready-to-plan -> planning claims"    '"$SS" set "$S1" planning --by planner-x >/dev/null && [ "$(field "$S1" "m[\"claim\"][\"by\"]")" = planner-x ]'
check "history appended"                    '[ "$(field "$S1" "len(m[\"history\"])")" = 3 ]'
check "stale with 0h is stale (exit 0)"     '"$SS" stale "$S1" 0 >/dev/null'
check "stale with 6h is fresh (exit 1)"     '! "$SS" stale "$S1" 6 >/dev/null'
check "story drafted -> planned w/ plan"    '"$SS" story set "$S1" create-home-page planned --plan create-home-page/create-home-page-plan.md >/dev/null && [ "$(field "$S1" "m[\"stories\"][0][\"plan\"]")" = create-home-page/create-home-page-plan.md ]'
check "planning -> planned clears claim"    '"$SS" set "$S1" planned >/dev/null && [ "$(field "$S1" "m[\"claim\"]")" = None ]'
check "list planned finds it"               '[ "$("$SS" list planned | cut -f1)" = "$S1" ]'
check "planned -> executing claims"         '"$SS" set "$S1" executing --by coder-y >/dev/null && [ "$(field "$S1" "m[\"claim\"][\"by\"]")" = coder-y ]'
check "stale: no claim exits 1"             '! "$SS" stale "$S2" 0 >/dev/null'

# --- story fix loop ------------------------------------------------------------------------
check "story planned -> executing"          '"$SS" story set "$S1" create-home-page executing >/dev/null'
check "story executing -> validating"       '"$SS" story set "$S1" create-home-page validating >/dev/null'
check "validating -> executing bumps"       '"$SS" story set "$S1" create-home-page executing --bump-attempts --detail "AC-B1 failed" >/dev/null && [ "$(field "$S1" "m[\"stories\"][0][\"attempts\"]")" = 1 ]'
check "detail recorded"                     '[ "$(field "$S1" "m[\"stories\"][0][\"detail\"]")" = "AC-B1 failed" ]'
check "story illegal jump refused"          '! "$SS" story set "$S1" create-home-page done 2>/dev/null'
check "story --force allows jump"           '"$SS" story set "$S1" create-home-page done --force >/dev/null'
check "story set unknown slug refused"      '! "$SS" story set "$S1" nope done 2>/dev/null'

# --- completion / blocked / force ----------------------------------------------------------
check "executing -> blocked clears claim"   '"$SS" set "$S1" blocked >/dev/null && [ "$(field "$S1" "m[\"claim\"]")" = None ]'
check "blocked -> planned re-admits"        '"$SS" set "$S1" planned --force >/dev/null'
check "forced flag recorded when illegal"   '"$SS" set "$S2" complete --force >/dev/null && [ "$(field "$S2" "m[\"history\"][-1].get(\"forced\")")" = True ]'
check "complete is terminal"                '! "$SS" set "$S2" executing 2>/dev/null'
check "get prints json"                     '"$SS" get "$S1" | python3 -c "import json,sys; json.load(sys.stdin)"'
check "get unknown sprint exits 2"          '"$SS" get nope 2>/dev/null; [ $? = 2 ]'

echo "sprint-state fixtures: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
