#!/usr/bin/env bash
# Fixture harness for Skills/dev-story-sprint/assets/merge-settings.sh
#
# Runs the repo copy of merge-settings.sh against synthetic settings.json /
# allow.json fixtures inside a throwaway sandbox. SANDBOX IS THE POINT: every
# settings.json, allow.json and case directory lives under a fresh mktemp -d
# removed on exit, and before any case runs each computed settings path is
# resolved (dirname + realpath, following symlinks) and asserted NOT to sit
# under $HOME/.claude — if it does, the harness refuses to run rather than
# risk touching a real settings.json. This harness never reads or writes
# $HOME/.claude/settings.json.
#
# Usage: bash Skills/dev-story-sprint/assets/tests/merge-settings-fixtures.sh
# Exit:  0 = every case matched its expectation, 1 = at least one mismatch
#        (or a setup / sandbox-guard failure).

set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$HERE/merge-settings.sh"
[ -f "$MERGE" ] || { echo "ERROR: not found: $MERGE" >&2; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found — this harness needs it for JSON assertions" >&2
  exit 1
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/merge-settings-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

# ------------------------------------------------------------ sandbox guard --

HOME_CLAUDE_REAL="$(python3 -c 'import os; print(os.path.realpath(os.path.expanduser("~/.claude")))')"

resolve_dir() { # $1 path (file or dir, may not exist yet) -> resolved absolute parent dir
  python3 -c '
import os, sys
p = sys.argv[1]
d = os.path.dirname(p) or "."
print(os.path.realpath(d))
' "$1"
}

assert_sandboxed() { # $1 label  $2 path (a settings-file path, existing or not)
  local resolved
  resolved="$(resolve_dir "$2")"
  case "$resolved" in
    "$HOME_CLAUDE_REAL"|"$HOME_CLAUDE_REAL"/*)
      echo "ERROR: refusing to run — $1 ($2 -> $resolved) resolves under \$HOME/.claude" >&2
      exit 1 ;;
  esac
}

assert_sandboxed "SANDBOX" "$SANDBOX/probe"

# ------------------------------------------------------------------ helpers --

CASES=0
FAILURES=0
check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-56s exp=%-46s got=%-46s %s\n' "$1" "$2" "$3" "$R"
}

is_valid_json() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1; }

allow_list() { # $1 settings.json -> comma-joined permissions.allow, empty on any error
  python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(",".join(d.get("permissions", {}).get("allow", [])))
except Exception:
    print("<error>")
' "$1"
}

hook_count() { # $1 settings.json  $2 hook command -> count of matching PostToolUse entries
  python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    post = d.get("hooks", {}).get("PostToolUse", [])
    n = sum(1 for e in post for h in e.get("hooks", []) if h.get("command") == sys.argv[2])
    print(n)
except Exception:
    print("<error>")
' "$1" "$2"
}

get_value() { # $1 settings.json  $2 dotted key path -> json.dumps of the value (or "null")
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
cur = d
for k in sys.argv[2].split("."):
    cur = cur.get(k) if isinstance(cur, dict) else None
print(json.dumps(cur))
' "$1" "$2"
}

byte_identical() { cmp -s "$1" "$2" && echo yes || echo no; } # $1 $2 -> yes/no
exists() { [ -f "$1" ] && echo yes || echo no; }               # $1 -> yes/no
nonzero() { [ "$1" -ne 0 ] && echo yes || echo no; }            # $1=rc -> yes/no

# ------------------------------------------------------------------ fixtures -

FX="$SANDBOX/fx"; mkdir -p "$FX"
ALLOW="$FX/allow.json"
cat > "$ALLOW" <<'EOF'
{"allow": ["Bash(git fetch:*)", "Bash(git push:*)", "Bash(mkdir:*)"]}
EOF
HOOK_CMD="/fake/hooks/refresh-live-post-push.sh"
WANTED_ORDER="Bash(git fetch:*),Bash(git push:*),Bash(mkdir:*)"

echo "sandbox:      $SANDBOX"
echo "merge script: $MERGE"
echo "home/.claude: $HOME_CLAUDE_REAL (asserted out of every case path)"
echo
echo "=== merge-settings.sh fixture cases ======================================"

# --- case 1: settings.json absent -------------------------------------------
C1="$SANDBOX/case1"; mkdir -p "$C1"
S1="$C1/settings.json"
assert_sandboxed "case1 settings" "$S1"
bash "$MERGE" "$S1" "$ALLOW" "$HOOK_CMD" > "$C1/out.log" 2> "$C1/err.log"
RC=$?
check "case1: created from absent, exit 0" "0" "$RC"
check "case1: file exists" "yes" "$(exists "$S1")"
check "case1: valid json" "yes" "$(is_valid_json "$S1" && echo yes || echo no)"
check "case1: allow entries" "$WANTED_ORDER" "$(allow_list "$S1")"
check "case1: hook registered once" "1" "$(hook_count "$S1" "$HOOK_CMD")"

# --- case 2: unrelated keys + partial allow + existing sub-keys -------------
C2="$SANDBOX/case2"; mkdir -p "$C2"
S2="$C2/settings.json"
assert_sandboxed "case2 settings" "$S2"
cat > "$S2" <<EOF
{
  "unrelatedTop": "keep-me",
  "permissions": {
    "allow": ["Bash(git fetch:*)"],
    "deny": ["Bash(rm -rf:*)"]
  }
}
EOF
OUT2="$(bash "$MERGE" "$S2" "$ALLOW" "$HOOK_CMD" 2> "$C2/err.log")"
RC=$?
check "case2: exit 0" "0" "$RC"
check "case2: missing entries appended, order preserved" "$WANTED_ORDER" "$(allow_list "$S2")"
check "case2: unrelated top-level key survives" '"keep-me"' "$(get_value "$S2" unrelatedTop)"
check "case2: existing permissions.deny survives" '["Bash(rm -rf:*)"]' "$(get_value "$S2" permissions.deny)"
check "case2: hook added" "1" "$(hook_count "$S2" "$HOOK_CMD")"
check "case2: valid json" "yes" "$(is_valid_json "$S2" && echo yes || echo no)"

# --- case 3: second run is a no-op ------------------------------------------
C3="$SANDBOX/case3"; mkdir -p "$C3"
S3="$C3/settings.json"
assert_sandboxed "case3 settings" "$S3"
cp "$S2" "$S3"
cp "$S3" "$C3/before.json"
OUT3="$(bash "$MERGE" "$S3" "$ALLOW" "$HOOK_CMD" 2> "$C3/err.log")"
RC=$?
EXPECT3="ok:        permissions.allow has all 3 sprint entries
ok:        PostToolUse hook registered: $HOOK_CMD"
check "case3: exit 0" "0" "$RC"
check "case3: prints the two ok: lines" "$EXPECT3" "$OUT3"
check "case3: file byte-identical" "yes" "$(byte_identical "$C3/before.json" "$S3")"

# --- case 4: --quiet on a no-op prints nothing ------------------------------
C4="$SANDBOX/case4"; mkdir -p "$C4"
S4="$C4/settings.json"
assert_sandboxed "case4 settings" "$S4"
cp "$S2" "$S4"
cp "$S4" "$C4/before.json"
OUT4="$(bash "$MERGE" --quiet "$S4" "$ALLOW" "$HOOK_CMD" 2> "$C4/err.log")"
RC=$?
check "case4: exit 0" "0" "$RC"
check "case4: quiet no-op prints nothing" "" "$OUT4"
check "case4: file byte-identical" "yes" "$(byte_identical "$C4/before.json" "$S4")"

# --- case 5: --quiet on a change prints exactly one merged: line -----------
C5="$SANDBOX/case5"; mkdir -p "$C5"
S5="$C5/settings.json"
assert_sandboxed "case5 settings" "$S5"
OUT5="$(bash "$MERGE" --quiet "$S5" "$ALLOW" "$HOOK_CMD" 2> "$C5/err.log")"
RC=$?
check "case5: exit 0" "0" "$RC"
check "case5: single line" "1" "$(printf '%s\n' "$OUT5" | wc -l | tr -d ' ')"
check "case5: line starts with merged:" "merged:" "$(printf '%s\n' "$OUT5" | cut -c1-7)"
check "case5: valid json result" "yes" "$(is_valid_json "$S5" && echo yes || echo no)"

# --- case 6: hook already registered -> not duplicated ----------------------
C6="$SANDBOX/case6"; mkdir -p "$C6"
S6="$C6/settings.json"
assert_sandboxed "case6 settings" "$S6"
cat > "$S6" <<EOF
{
  "permissions": {"allow": ["Bash(git fetch:*)", "Bash(git push:*)", "Bash(mkdir:*)"]},
  "hooks": {"PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "$HOOK_CMD"}]}]}
}
EOF
OUT6="$(bash "$MERGE" "$S6" "$ALLOW" "$HOOK_CMD" 2> "$C6/err.log")"
RC=$?
check "case6: exit 0" "0" "$RC"
check "case6: hook count stays 1 (no duplicate)" "1" "$(hook_count "$S6" "$HOOK_CMD")"
check "case6: valid json" "yes" "$(is_valid_json "$S6" && echo yes || echo no)"

# --- case 7: invalid JSON settings.json -> non-zero exit, file untouched ---
C7="$SANDBOX/case7"; mkdir -p "$C7"
S7="$C7/settings.json"
assert_sandboxed "case7 settings" "$S7"
printf '{ not valid json' > "$S7"
cp "$S7" "$C7/before.json"
bash "$MERGE" "$S7" "$ALLOW" "$HOOK_CMD" > "$C7/out.log" 2> "$C7/err.log"
RC=$?
check "case7: non-zero exit" "yes" "$(nonzero "$RC")"
check "case7: file left byte-identical" "yes" "$(byte_identical "$C7/before.json" "$S7")"

# --- case 8: missing allow file -> non-zero exit ----------------------------
C8="$SANDBOX/case8"; mkdir -p "$C8"
S8="$C8/settings.json"
assert_sandboxed "case8 settings" "$S8"
MISSING_ALLOW="$C8/does-not-exist.json"
bash "$MERGE" "$S8" "$MISSING_ALLOW" "$HOOK_CMD" > "$C8/out.log" 2> "$C8/err.log"
RC=$?
check "case8: non-zero exit" "yes" "$(nonzero "$RC")"
check "case8: settings.json not created" "no" "$(exists "$S8")"

# --- case 9: wrong arg count -> non-zero exit with usage line --------------
ERR9="$(bash "$MERGE" 2>&1 1>/dev/null)"
RC=$?
check "case9: non-zero exit" "yes" "$(nonzero "$RC")"
check "case9: usage line on stderr" "yes" "$(printf '%s' "$ERR9" | grep -q '^usage: merge-settings.sh' && echo yes || echo no)"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
