#!/usr/bin/env bash
# Fixture harness for Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh
#
# Proves the hook's `-C <path>` cwd-resolution fix (git's `-C` composes onto tool_input.cwd
# only when present, falls back to tool_input.cwd otherwise) by driving the REAL hook script
# end to end: synthetic PostToolUse JSON piped to its stdin, `CLAUDE_SKILLS_LIVE` pointed at a
# sandboxed throwaway "live worktree" clone, and pass/fail decided by whether that clone's HEAD
# actually advances after a real push to a throwaway bare origin.
#
# SANDBOX IS THE POINT: every bare origin, clone, and reconstructed pre-fix script copy lives
# under a fresh mktemp -d removed on exit, and before any repo is created its path is resolved
# (dirname + realpath) and asserted NOT to sit under $HOME/.claude — if it does, the harness
# refuses to run rather than risk touching real Claude Code state. This harness never writes to
# $HOME/.claude. The synthetic `cwd` field for the "cwd unrelated to the repo" cases uses the
# real $HOME only as an inert string read once via a single `git -C "$HOME" rev-parse
# --git-common-dir` (read-only, no writes) to prove it does not resolve to the sandboxed repos.
#
# Usage: bash Skills/dev-story-sprint/assets/tests/refresh-live-post-push-fixtures.sh
# Exit:  0 = every case matched its expectation, 1 = at least one mismatch (or a setup failure).

set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$HERE/hooks/refresh-live-post-push.sh"
[ -f "$HOOK" ] || { echo "ERROR: not found: $HOOK" >&2; exit 1; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found — this harness (and the hook itself) needs it" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found" >&2
  exit 1
fi

REAL_HOME="$HOME"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/refresh-live-post-push-fixtures.XXXXXX")" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

# ------------------------------------------------------------ sandbox guard --

HOME_CLAUDE_REAL="$(python3 -c 'import os; print(os.path.realpath(os.path.expanduser("~/.claude")))')"

resolve_path() { # $1 path (may not exist yet) -> resolved absolute path (realpath of nearest existing ancestor)
  python3 -c '
import os, sys
p = os.path.abspath(sys.argv[1])
while not os.path.exists(p):
    parent = os.path.dirname(p)
    if parent == p:
        break
    p = parent
print(os.path.realpath(p))
' "$1"
}

assert_sandboxed() { # $1 label  $2 path
  local resolved
  resolved="$(resolve_path "$2")"
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
  printf '%-56s exp=%-40s got=%-40s %s\n' "$1" "$2" "$3" "$R"
}

check_prefix() { # $1 label  $2 expected-prefix  $3 actual
  CASES=$((CASES + 1))
  case "$3" in
    "$2"*) R="PASS" ;;
    *) R="FAIL"; FAILURES=$((FAILURES + 1)) ;;
  esac
  printf '%-56s exp-prefix=%-30s got=%-40s %s\n' "$1" "$2" "$3" "$R"
}

head_of() { git -C "$1" rev-parse HEAD 2>/dev/null || echo "<none>"; }
advanced() { [ "$1" != "$2" ] && echo yes || echo no; } # $1=before $2=after -> did HEAD change

new_commit() { # $1 repo dir  $2 filename  $3 label -> creates+commits a unique file
  printf 'fixture:%s\n' "$3" > "$1/$2"
  git -C "$1" add "$2" >/dev/null
  git -C "$1" commit -q -m "fixture: $3" >/dev/null
}

init_repo_identity() { # $1 repo dir -> local, no-GPG identity so commits never hang/prompt
  git -C "$1" config user.email "fixture@example.invalid"
  git -C "$1" config user.name "Fixture"
  git -C "$1" config commit.gpgsign false
  git -C "$1" config tag.gpgsign false
}

json_payload() { # $1 tool_name  $2 command  $3 cwd -> one-line JSON on stdout
  python3 -c '
import json, sys
print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"command": sys.argv[2]}, "cwd": sys.argv[3]}))
' "$1" "$2" "$3"
}

run_hook() { # $1 hook script  $2 live dir  $3 payload (may be empty) -> sets OUT, ERR, RC
  local errfile="$SANDBOX/last.err"
  OUT="$(printf '%s' "$3" | CLAUDE_SKILLS_LIVE="$2" bash "$1" 2>"$errfile")"
  RC=$?
  ERR="$(cat "$errfile" 2>/dev/null || true)"
}

# ------------------------------------------------------- throwaway git repos -

ORIGIN_BARE="$SANDBOX/origin.git"
SEED="$SANDBOX/seed"
LIVE="$SANDBOX/live"
LIVE_DEMO="$SANDBOX/live-demo"
CALLER="$SANDBOX/caller"
UNRELATED_BARE="$SANDBOX/unrelated-origin.git"
UNRELATED_SEED="$SANDBOX/unrelated-seed"
UNRELATED_CLONE="$SANDBOX/unrelated-clone"

for p in "$ORIGIN_BARE" "$SEED" "$LIVE" "$LIVE_DEMO" "$CALLER" "$UNRELATED_BARE" "$UNRELATED_SEED" "$UNRELATED_CLONE"; do
  assert_sandboxed "repo path" "$p"
done

git init --bare -q -b main "$ORIGIN_BARE"
git -C "$ORIGIN_BARE" symbolic-ref HEAD refs/heads/main

mkdir -p "$SEED"
git -C "$SEED" init -q -b main
init_repo_identity "$SEED"
git -C "$SEED" remote add origin "$ORIGIN_BARE"
new_commit "$SEED" "seed.txt" "seed"
git -C "$SEED" push -q -u origin main

git clone -q "$ORIGIN_BARE" "$LIVE"
git clone -q "$ORIGIN_BARE" "$LIVE_DEMO"
git clone -q "$ORIGIN_BARE" "$CALLER"
init_repo_identity "$CALLER"

git init --bare -q -b main "$UNRELATED_BARE"
git -C "$UNRELATED_BARE" symbolic-ref HEAD refs/heads/main
mkdir -p "$UNRELATED_SEED"
git -C "$UNRELATED_SEED" init -q -b main
init_repo_identity "$UNRELATED_SEED"
git -C "$UNRELATED_SEED" remote add origin "$UNRELATED_BARE"
new_commit "$UNRELATED_SEED" "seed.txt" "unrelated-seed"
git -C "$UNRELATED_SEED" push -q -u origin main
git clone -q "$UNRELATED_BARE" "$UNRELATED_CLONE"
init_repo_identity "$UNRELATED_CLONE"

BASELINE_HEAD="$(head_of "$LIVE")"
check "setup: LIVE and LIVE_DEMO start identical" "$BASELINE_HEAD" "$(head_of "$LIVE_DEMO")"

# ------------------------------------------------- reconstruct pre-fix hook --
# Per story.md AC1: prove the fix by reconstructing the immediate pre-fix version of the hook
# from git history (not by editing the real merged file) and showing it fails this one case.

REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
RELATIVE_HOOK="${HOOK#"$REPO_ROOT"/}"
FIX_COMMIT="$(git -C "$REPO_ROOT" log -1 --format=%H -- "$RELATIVE_HOOK" 2>/dev/null || true)"
PRE_FIX_HOOK="$SANDBOX/pre-fix-refresh-live-post-push.sh"
assert_sandboxed "pre-fix hook copy" "$PRE_FIX_HOOK"

if [ -n "$FIX_COMMIT" ] \
  && git -C "$REPO_ROOT" show "${FIX_COMMIT}^:$RELATIVE_HOOK" > "$PRE_FIX_HOOK" 2>/dev/null \
  && [ -s "$PRE_FIX_HOOK" ]; then
  chmod +x "$PRE_FIX_HOOK"
else
  echo "ERROR: could not reconstruct pre-fix hook script from git history (fix commit=$FIX_COMMIT)" >&2
  exit 1
fi

echo "sandbox: $SANDBOX"
echo "hook:    $HOOK"
echo "pre-fix: $PRE_FIX_HOOK (reconstructed from ${FIX_COMMIT}^)"
echo "home/.claude: $HOME_CLAUDE_REAL (asserted out of every case path)"
echo
echo "=== refresh-live-post-push.sh fixture cases ==============================="

# --- AC1 (pre-fix): git -C <caller> push, cwd unrelated (real $HOME) -> pre-fix must NOT advance
new_commit "$CALLER" "ac1.txt" "ac1"
git -C "$CALLER" push -q
ORIGIN_HEAD_1="$(git -C "$ORIGIN_BARE" rev-parse main)"
PAYLOAD_AC1="$(json_payload "Bash" "git -C $CALLER push" "$REAL_HOME")"

BEFORE_DEMO="$(head_of "$LIVE_DEMO")"
run_hook "$PRE_FIX_HOOK" "$LIVE_DEMO" "$PAYLOAD_AC1"
AFTER_DEMO="$(head_of "$LIVE_DEMO")"
check "AC1 pre-fix: git -C <caller> push (cwd unrelated) does NOT advance" "no" "$(advanced "$BEFORE_DEMO" "$AFTER_DEMO")"

# --- AC1 (post-fix): same payload against the real, merged hook -> MUST advance
BEFORE_1="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC1"
AFTER_1="$(head_of "$LIVE")"
check "AC1: git -C <caller> push (cwd unrelated) advances live" "yes" "$(advanced "$BEFORE_1" "$AFTER_1")"
check "AC1: live HEAD matches origin main" "$ORIGIN_HEAD_1" "$AFTER_1"
check_prefix "AC1: stdout announces refresh" "live skills refreshed:" "$OUT"
check "AC1: exit 0" "0" "$RC"

# --- AC2: cd <caller> && git push, cwd = caller -> unchanged working case ---
new_commit "$CALLER" "ac2.txt" "ac2"
(cd "$CALLER" && git push -q)
ORIGIN_HEAD_2="$(git -C "$ORIGIN_BARE" rev-parse main)"
PAYLOAD_AC2="$(json_payload "Bash" "cd $CALLER && git push" "$CALLER")"

BEFORE_2="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC2"
AFTER_2="$(head_of "$LIVE")"
check "AC2: cd <caller> && git push advances live" "yes" "$(advanced "$BEFORE_2" "$AFTER_2")"
check "AC2: live HEAD matches origin main" "$ORIGIN_HEAD_2" "$AFTER_2"
check "AC2: exit 0" "0" "$RC"

# --- AC3: plain git push, cwd = caller -> unchanged working case -----------
new_commit "$CALLER" "ac3.txt" "ac3"
(cd "$CALLER" && git push -q)
ORIGIN_HEAD_3="$(git -C "$ORIGIN_BARE" rev-parse main)"
PAYLOAD_AC3="$(json_payload "Bash" "git push" "$CALLER")"

BEFORE_3="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC3"
AFTER_3="$(head_of "$LIVE")"
check "AC3: plain git push (cwd=caller) advances live" "yes" "$(advanced "$BEFORE_3" "$AFTER_3")"
check "AC3: live HEAD matches origin main" "$ORIGIN_HEAD_3" "$AFTER_3"
check "AC3: exit 0" "0" "$RC"

# --- AC4: -C <unrelated repo>, cwd unrelated -> must NOT advance -----------
new_commit "$UNRELATED_CLONE" "ac4.txt" "ac4"
git -C "$UNRELATED_CLONE" push -q
PAYLOAD_AC4="$(json_payload "Bash" "git -C $UNRELATED_CLONE push" "$REAL_HOME")"

BEFORE_4="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC4"
AFTER_4="$(head_of "$LIVE")"
check "AC4: -C <unrelated repo> does NOT advance live" "no" "$(advanced "$BEFORE_4" "$AFTER_4")"
check "AC4: stdout empty (identity check silently fails)" "" "$OUT"
check "AC4: exit 0" "0" "$RC"

# --- AC5a: tool_name != Bash -> exit 0, no output, no advance --------------
new_commit "$CALLER" "ac5a.txt" "ac5a"
git -C "$CALLER" push -q
PAYLOAD_AC5A="$(json_payload "Read" "git -C $CALLER push" "$REAL_HOME")"

BEFORE_5A="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC5A"
AFTER_5A="$(head_of "$LIVE")"
check "AC5a: tool_name!=Bash does NOT advance live" "no" "$(advanced "$BEFORE_5A" "$AFTER_5A")"
check "AC5a: stdout empty" "" "$OUT"
check "AC5a: stderr empty" "" "$ERR"
check "AC5a: exit 0" "0" "$RC"

# --- AC5b: --dry-run -> exit 0, no output, no advance ----------------------
new_commit "$CALLER" "ac5b.txt" "ac5b"
git -C "$CALLER" push -q --dry-run
PAYLOAD_AC5B="$(json_payload "Bash" "git -C $CALLER push --dry-run" "$REAL_HOME")"

BEFORE_5B="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" "$PAYLOAD_AC5B"
AFTER_5B="$(head_of "$LIVE")"
check "AC5b: --dry-run does NOT advance live" "no" "$(advanced "$BEFORE_5B" "$AFTER_5B")"
check "AC5b: stdout empty" "" "$OUT"
check "AC5b: stderr empty" "" "$ERR"
check "AC5b: exit 0" "0" "$RC"

# --- AC5c: empty stdin -> exit 0, no output, no advance --------------------
BEFORE_5C="$(head_of "$LIVE")"
run_hook "$HOOK" "$LIVE" ""
AFTER_5C="$(head_of "$LIVE")"
check "AC5c: empty stdin does NOT advance live" "no" "$(advanced "$BEFORE_5C" "$AFTER_5C")"
check "AC5c: stdout empty" "" "$OUT"
check "AC5c: stderr empty" "" "$ERR"
check "AC5c: exit 0" "0" "$RC"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
