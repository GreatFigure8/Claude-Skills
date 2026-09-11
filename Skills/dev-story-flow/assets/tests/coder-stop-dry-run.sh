#!/usr/bin/env bash
# Dry-runs the "Stopping point at 160k" procedure from references/dev-story-coder.md against a
# throwaway git repo with a real bare remote — no network, no clear-prompt skill invocation.
# Usage: bash coder-stop-dry-run.sh (exit 0 = pass)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SS="$HERE/../bin/sprint-state.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/work"
REMOTE="$TMP/remote.git"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1" >&2; }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

git init -q -b main "$WORK"
git init -q --bare "$REMOTE"
git -C "$WORK" config user.email "dry-run@example.com"
git -C "$WORK" config user.name "Dry Run"
git -C "$WORK" remote add origin "$REMOTE"
cd "$WORK"

# 1. Fresh sprint manifest via the helper (matches its own schema, no hand-rolled JSON).
S1="$("$SS" new --live main)"
"$SS" story add "$S1" dummy-story --title "Dummy story" --kind service >/dev/null
"$SS" set "$S1" ready-to-plan >/dev/null
"$SS" set "$S1" planning >/dev/null
"$SS" story set "$S1" dummy-story planned >/dev/null
"$SS" set "$S1" planned >/dev/null
"$SS" set "$S1" executing --by dry-runner >/dev/null
"$SS" story set "$S1" dummy-story executing >/dev/null

CLAIM_BEFORE="$("$SS" get "$S1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["claim"]))')"

# 2. One story into executing with a fake pushed-but-unmerged branch.
BRANCH="feat/dummy-story-fake-not-merged"

# 3. The exact command the coder doc's "Stopping point at 160k" subsection specifies:
#   $SS story set <sprint> <slug> executing --detail "branch <b> pushed, not merged"
"$SS" story set "$S1" dummy-story executing --detail "branch $BRANCH pushed, not merged" >/dev/null

git -C "$WORK" add docs/sprints
git -C "$WORK" commit -q -m "chore(sprint): dry-run stop at 160k"
git -C "$WORK" push -q -u origin main

# 4. Assertions: sprint still executing with claim intact, story detail names the branch.
GET_OUT="$("$SS" get "$S1")"
STATUS="$(printf '%s' "$GET_OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')"
CLAIM_AFTER="$(printf '%s' "$GET_OUT" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["claim"]))')"
DETAIL="$(printf '%s' "$GET_OUT" | python3 -c 'import json,sys
m = json.load(sys.stdin)
s = next(s for s in m["stories"] if s["slug"] == "dummy-story")
print(s["detail"])')"

check "sprint status is still executing"        '[ "$STATUS" = "executing" ]'
check "sprint claim is unchanged"                '[ "$CLAIM_AFTER" = "$CLAIM_BEFORE" ]'
check "story detail contains the pushed branch"  'printf "%s" "$DETAIL" | grep -qF "$BRANCH"'
check "commit landed on the bare remote"         'git -C "$REMOTE" log -1 --format=%s main | grep -q "dry-run stop at 160k"'

echo "coder stop-at-160k dry run: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
