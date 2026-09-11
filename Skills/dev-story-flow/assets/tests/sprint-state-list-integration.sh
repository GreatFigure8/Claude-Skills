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

# TTY case: `list` under a pseudo-terminal should emit the bold escape code for the
# done/total counter. Use python3's pty.spawn (not macOS `script`, whose flags differ
# from GNU script and aren't portable here) to give the child a real pty on stdout.
TTY_OUT="$TMP/tty_out.bin"
python3 - "$TTY_OUT" "$SS" list <<'PY'
import pty, sys, os

outfile, cmd = sys.argv[1], sys.argv[2:]
with open(outfile, "wb") as f:
    def read(fd):
        data = os.read(fd, 1024)
        f.write(data)
        return data
    pty.spawn(cmd, read)
PY

if grep -q $'\x1b\[1m' "$TTY_OUT"; then ok; else bad "list under a pty includes ESC[1m bold styling"; fi

echo "sprint-state list integration: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
