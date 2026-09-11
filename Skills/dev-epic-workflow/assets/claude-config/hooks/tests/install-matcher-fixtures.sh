#!/usr/bin/env bash
# Fixture harness for install.sh --user's settings.json merge (matcher shape
# + idempotence), specifically:
#   - context-budget-gate.sh's PreToolUse hook group carries an empty-string
#     matcher ("" == "all tools") straight through the merge.
#   - cancel-gate.sh's PreToolUse hook group has NO matcher key at all in the
#     source settings-hooks.json, and the merge must not add one.
#   - running install.sh --user twice against the same HOME produces a
#     byte-identical settings.json (idempotent).
#
# SANDBOX IS THE POINT: install.sh --user writes to $HOME/.claude/settings.json,
# so HOME is redirected to a fresh mktemp -d for the entire run. Before either
# install.sh invocation, the sandboxed HOME is resolved (dirname + realpath,
# following symlinks) and asserted NOT to sit under the real machine's
# $HOME/.claude — if it does, the harness refuses to run rather than risk
# touching a real settings.json. This harness never reads or writes the real
# $HOME/.claude/settings.json.
#
# Usage: bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/install-matcher-fixtures.sh
# Exit:  0 = every case matched its expectation, 1 = at least one mismatch
#        (or a setup / sandbox-guard failure).

set -u

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL="$HERE/install.sh"
[ -f "$INSTALL" ] || { echo "ERROR: not found: $INSTALL" >&2; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found — this harness needs it for JSON assertions" >&2
  exit 1
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/install-matcher-fixtures.XXXXXX")" || exit 1
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

FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME"
assert_sandboxed "FAKE_HOME/.claude/settings.json" "$FAKE_HOME/.claude/settings.json"

SETTINGS="$FAKE_HOME/.claude/settings.json"

# ------------------------------------------------------------------ helpers --

CASES=0
FAILURES=0
check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-64s exp=%-30s got=%-30s %s\n' "$1" "$2" "$3" "$R"
}

is_valid_json() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1; }
exists() { [ -f "$1" ] && echo yes || echo no; }
byte_identical() { cmp -s "$1" "$2" && echo yes || echo no; }

# matcher_shape: prints one of "empty-string" | "absent" | "<other>" for the
# PreToolUse hook group whose hooks[] contains a command ending in $1.
matcher_shape() { # $1 settings.json  $2 command-basename
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
suffix = sys.argv[2]
for g in d.get("hooks", {}).get("PreToolUse", []):
    for h in g.get("hooks", []):
        if h.get("command", "").endswith(suffix):
            if "matcher" not in g:
                print("absent")
            elif g["matcher"] == "":
                print("empty-string")
            else:
                print(repr(g["matcher"]))
            sys.exit(0)
print("<not-found>")
' "$1" "$2"
}

# ---------------------------------------------------------- source shapes ----
# What settings-hooks.json actually has, so the assertions below check that
# the merge preserves these shapes rather than asserting a guessed shape.
SRC_HOOKS="$HERE/settings-hooks.json"
[ -f "$SRC_HOOKS" ] || { echo "ERROR: not found: $SRC_HOOKS" >&2; exit 1; }
SRC_CBG_SHAPE="$(matcher_shape "$SRC_HOOKS" "context-budget-gate.sh")"
SRC_CG_SHAPE="$(matcher_shape "$SRC_HOOKS" "cancel-gate.sh")"

echo "sandbox:        $SANDBOX"
echo "fake HOME:      $FAKE_HOME"
echo "install.sh:     $INSTALL"
echo "home/.claude:   $HOME_CLAUDE_REAL (asserted out of every path used)"
echo "source shapes:  context-budget-gate.sh matcher=$SRC_CBG_SHAPE  cancel-gate.sh matcher=$SRC_CG_SHAPE"
echo
echo "=== install.sh --user matcher-preservation + idempotence ================="

# --- run 1 -------------------------------------------------------------------
OUT1="$(HOME="$FAKE_HOME" bash "$INSTALL" --user 2>&1)"
RC1=$?
check "run1: exit 0" "0" "$RC1"
check "run1: settings.json created" "yes" "$(exists "$SETTINGS")"
check "run1: valid json" "yes" "$(is_valid_json "$SETTINGS" && echo yes || echo no)"

check "run1: context-budget-gate.sh matcher shape == source ($SRC_CBG_SHAPE)" \
  "$SRC_CBG_SHAPE" "$(matcher_shape "$SETTINGS" "context-budget-gate.sh")"
check "run1: cancel-gate.sh matcher shape unchanged from source ($SRC_CG_SHAPE)" \
  "$SRC_CG_SHAPE" "$(matcher_shape "$SETTINGS" "cancel-gate.sh")"

cp "$SETTINGS" "$SANDBOX/after-run1.json"

# --- run 2 (idempotence) -----------------------------------------------------
OUT2="$(HOME="$FAKE_HOME" bash "$INSTALL" --user 2>&1)"
RC2=$?
check "run2: exit 0" "0" "$RC2"
check "run2: settings.json byte-identical to run1" "yes" \
  "$(byte_identical "$SANDBOX/after-run1.json" "$SETTINGS")"
check "run2: context-budget-gate.sh matcher still == source ($SRC_CBG_SHAPE)" \
  "$SRC_CBG_SHAPE" "$(matcher_shape "$SETTINGS" "context-budget-gate.sh")"
check "run2: cancel-gate.sh matcher still unchanged from source ($SRC_CG_SHAPE)" \
  "$SRC_CG_SHAPE" "$(matcher_shape "$SETTINGS" "cancel-gate.sh")"

# ---------------------------------------------------------- upgrade helpers --

get_command() { # $1 settings.json  $2 command-basename -> full command string (or empty)
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
suffix = sys.argv[2]
for g in d.get("hooks", {}).get("PreToolUse", []):
    for h in g.get("hooks", []):
        if h.get("command", "").endswith(suffix):
            print(h["command"])
            sys.exit(0)
' "$1" "$2"
}

count_groups_owning() { # $1 settings.json  $2 command-basename -> # PreToolUse groups owning it
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
suffix = sys.argv[2]
n = sum(
    1 for g in d.get("hooks", {}).get("PreToolUse", [])
    if any(h.get("command", "").endswith(suffix) for h in g.get("hooks", []))
)
print(n)
' "$1" "$2"
}

seed_group() { # $1 settings.json path  $2 command  $3 matcher(literal python repr, e.g. '"Bash"')
  python3 -c '
import json, sys
path, cmd, matcher_json = sys.argv[1], sys.argv[2], sys.argv[3]
group = {"hooks": [{"type": "command", "command": cmd}]}
group["matcher"] = json.loads(matcher_json)
settings = {"hooks": {"PreToolUse": [group]}}
json.dump(settings, open(path, "w"), indent=2)
' "$1" "$2" "$3"
}

CBG_CMD="$(get_command "$SETTINGS" "context-budget-gate.sh")"
CG_CMD="$(get_command "$SETTINGS" "cancel-gate.sh")"

echo
echo "=== install.sh --user upgrade: stale matcher reconciliation =============="

FAKE_HOME2="$SANDBOX/home-upgrade"
mkdir -p "$FAKE_HOME2/.claude"
assert_sandboxed "FAKE_HOME2/.claude/settings.json" "$FAKE_HOME2/.claude/settings.json"
SETTINGS2="$FAKE_HOME2/.claude/settings.json"
seed_group "$SETTINGS2" "$CBG_CMD" '"Bash"'

OUT3="$(HOME="$FAKE_HOME2" bash "$INSTALL" --user 2>&1)"
RC3=$?
check "upgrade: exit 0" "0" "$RC3"
check "upgrade: context-budget-gate.sh matcher reconciled to source ($SRC_CBG_SHAPE)" \
  "$SRC_CBG_SHAPE" "$(matcher_shape "$SETTINGS2" "context-budget-gate.sh")"
check "upgrade: exactly one PreToolUse group owns context-budget-gate.sh" \
  "1" "$(count_groups_owning "$SETTINGS2" "context-budget-gate.sh")"

cp "$SETTINGS2" "$SANDBOX/after-upgrade1.json"

# --- upgrade idempotence (second run against the same FAKE_HOME2) -----------
OUT4="$(HOME="$FAKE_HOME2" bash "$INSTALL" --user 2>&1)"
RC4=$?
check "upgrade run2: exit 0" "0" "$RC4"
check "upgrade run2: settings.json byte-identical to upgrade run1" "yes" \
  "$(byte_identical "$SANDBOX/after-upgrade1.json" "$SETTINGS2")"

echo
echo "=== install.sh --user upgrade: absent-matcher reconciliation =============="

FAKE_HOME3="$SANDBOX/home-absent"
mkdir -p "$FAKE_HOME3/.claude"
assert_sandboxed "FAKE_HOME3/.claude/settings.json" "$FAKE_HOME3/.claude/settings.json"
SETTINGS3="$FAKE_HOME3/.claude/settings.json"
seed_group "$SETTINGS3" "$CG_CMD" '"Bash"'

OUT5="$(HOME="$FAKE_HOME3" bash "$INSTALL" --user 2>&1)"
RC5=$?
check "absent: exit 0" "0" "$RC5"
check "absent: cancel-gate.sh matcher reconciled to source ($SRC_CG_SHAPE)" \
  "$SRC_CG_SHAPE" "$(matcher_shape "$SETTINGS3" "cancel-gate.sh")"
check "absent: exactly one PreToolUse group owns cancel-gate.sh" \
  "1" "$(count_groups_owning "$SETTINGS3" "cancel-gate.sh")"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
