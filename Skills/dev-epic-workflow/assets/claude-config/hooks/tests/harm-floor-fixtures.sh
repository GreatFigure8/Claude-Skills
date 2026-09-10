#!/usr/bin/env bash
# Fixture harness for THE HARM FLOOR (epic 21 item 2):
# ../../bin/autonomy.sh's `autonomy_harm_check` and its two new guards,
# `autonomy_deny_irreversible_op` and `autonomy_deny_cross_epic_collision`.
#
# WHAT THIS PROVES: each of the five guards the plan's own Verification line
# names — denylist hit, size ceiling exceeded, STOP present, force-push
# attempt, cross-epic collision — fires on its own trigger, stays silent when
# that trigger is absent, and is checked in the STOP-first, cheapest-first
# order the function's own header states (case F). It also proves the ONE
# well-known entry point, `autonomy.sh --harm-check`, actually calls the same
# function rather than a parallel copy (case G), and the stdin caveat the
# function's header names — a here-string survives the pipe-subshell trap a
# plain pipe does not (case H).
#
# Uses REAL git in a sandbox (same choice declared-paths-gate-fixtures.sh
# makes): the irreversible-op guard's whole job is reading a real
# `refs/remotes/origin/<branch>`, so a stubbed git would not test the seam
# that matters. Everything lives under one `mktemp -d` removed on exit.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/harm-floor-fixtures.sh
#         INTAKE_FIXTURE_AUTONOMY_LIB=/path/to/other-autonomy.sh bash ...
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
LIB="${INTAKE_FIXTURE_AUTONOMY_LIB:-$BIN_DIR/autonomy.sh}"
[ -f "$LIB" ] || { echo "ERROR: not found: $LIB" >&2; exit 1; }
if ! grep -q '^autonomy_harm_check()' "$LIB"; then
  echo "ERROR: $LIB carries no autonomy_harm_check() — this suite tests epic 21" >&2
  echo "       item 2. Against a tree that predates it there is nothing to test," >&2
  echo "       and passing would be a lie. Aborting." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "ERROR: git not on PATH" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/harm-floor-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-64s exp=[%s] got=[%s]  %s\n' "$1" "$2" "$3" "$R"
}
check_contains() { # $1 label  $2 expected(0|1 present)  $3 haystack  $4 needle
  CASES=$((CASES + 1))
  local GOT=0
  case "$3" in *"$4"*) GOT=1 ;; esac
  if [ "$2" = "$GOT" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-64s exp=%s got=%s  %s\n' "$1" "$2" "$GOT" "$R"
}

# ------------------------------------------------------------------- repo
REPO="$SANDBOX/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email fixture@test.local
git -C "$REPO" config user.name fixture
: > "$REPO/f.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m base
# `main` is "shared" WITHOUT a real remote: point refs/remotes/origin/main at
# HEAD directly, the same disk fact `git fetch` would leave behind, so the
# irreversible-op guard's `show-ref --verify refs/remotes/origin/main` has a
# real ref to read. `scratch` deliberately gets no such ref — it is a purely
# local branch nobody has pushed, so the guard must have nothing to say
# about it.
git -C "$REPO" update-ref refs/remotes/origin/main "$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" branch scratch

# ------------------------------------------------------------- epics tree
EPICS="$SANDBOX/epics"
mkdir -p "$EPICS/21-mine/status" "$EPICS/09-other/status" "$EPICS/13-closed/status"
printf '# Epic: mine\n**Status:** in flight\n'   > "$EPICS/21-mine/plan.md"
printf '# Epic: other\n**Status:** in flight\n'  > "$EPICS/09-other/plan.md"
printf '# Epic: closed\n**Status:** closed\n'    > "$EPICS/13-closed/plan.md"
printf '{"item":"1","branch":"feat/shared-thing","state":"implementing"}\n' \
  > "$EPICS/09-other/status/feat-shared-thing.json"
printf '{"item":"1","branch":"feat/old-claim","state":"pr-opened"}\n' \
  > "$EPICS/13-closed/status/feat-old-claim.json"

# ------------------------------------------------------------------ control files
CTRL="$SANDBOX/ctrl"; mkdir -p "$CTRL"
export INTAKE_AUTONOMY_FILE="$CTRL/autonomy"
export INTAKE_AUTONOMY_OVERRIDE="$CTRL/AUTONOMY-OFF"
export INTAKE_STOP_FILE="$CTRL/STOP"
: > "$INTAKE_AUTONOMY_FILE"
rm -f "$INTAKE_AUTONOMY_OVERRIDE" "$INTAKE_STOP_FILE"

echo "library: $LIB"
echo "sandbox: $SANDBOX"
echo "bash:    $(/bin/bash --version | head -1)"
echo

# hc: run autonomy_harm_check in a fresh subshell that sources the library,
# so no state (AUTONOMY_MAX_FILES etc.) leaks between cases. Prints
# "<rc>|<reason>" on one line. stdin (case $1... no — see below) is passed
# through via a 9th fd trick avoided by keeping this a plain function whose
# OWN stdin is the harm check's stdin — callers redirect into `hc`, never
# pipe into it, matching the function's own documented caveat.
hc() { # remaining args = flags to autonomy_harm_check -> stdout "<rc>|<reason>"
  /bin/bash -c '
    set -u
    . "$1"; shift
    autonomy_resolve "'"$REPO"'" fixture/repo
    autonomy_harm_check "$@" >/dev/null
    printf "%s|%s" "$?" "$AUTONOMY_HARM_REASON"
  ' hc "$LIB" "$@"
}

echo "=== A. STOP — refuses everything, and only this guard is checked first ==="
touch "$INTAKE_STOP_FILE"
OUT="$(hc --repo "$REPO" --files 1 --lines 1 </dev/null)"
check "A1: STOP present -> rc 1"          "1"    "${OUT%%|*}"
check_contains "A2: reason names STOP"    1 "$OUT" "STOP present at"
rm -f "$INTAKE_STOP_FILE"
OUT="$(hc --repo "$REPO" --files 1 --lines 1 </dev/null)"
check "A3: STOP absent -> rc 0, clean run" "0" "${OUT%%|*}"

echo
echo "=== B. denylist — a floor path refuses, a clean path does not =========="
OUT="$(hc --repo "$REPO" --files 1 --lines 1 <<<".github/workflows/ci.yml")"
check "B1: floor path denied -> rc 1"            "1" "${OUT%%|*}"
check_contains "B2: reason names the pattern"     1  "$OUT" ".github/*"
OUT="$(hc --repo "$REPO" --files 1 --lines 1 <<<"src/app.ts")"
check "B3: an ordinary path -> rc 0"             "0" "${OUT%%|*}"

echo
echo "=== C. size ceiling — over the line refuses, at the line does not ======"
cat > "$INTAKE_AUTONOMY_FILE" <<CFG
[$REPO]
max-files = 5
max-diff-lines = 100
CFG
OUT="$(hc --repo "$REPO" --files 10 --lines 50 </dev/null)"
check "C1: files over ceiling -> rc 1"        "1" "${OUT%%|*}"
check_contains "C2: reason names the ceiling"  1  "$OUT" "the ceiling is 5"
OUT="$(hc --repo "$REPO" --files 5 --lines 100 </dev/null)"
check "C3: exactly at the ceiling -> rc 0"    "0" "${OUT%%|*}"
: > "$INTAKE_AUTONOMY_FILE"

echo
echo "=== D. irreversible op — force-push/hard-reset a SHARED branch refuses =="
OUT="$(hc --repo "$REPO" --branch main --git-op "push --force origin main" --files 1 --lines 1 </dev/null)"
check "D1: force-push to a branch known on origin -> rc 1"  "1" "${OUT%%|*}"
check_contains "D2: reason names it shared"                  1  "$OUT" "exists on origin"
OUT="$(hc --repo "$REPO" --branch main --git-op "reset --hard HEAD~1" --files 1 --lines 1 </dev/null)"
check "D3: hard-reset targeting a shared branch -> rc 1"    "1" "${OUT%%|*}"
OUT="$(hc --repo "$REPO" --branch scratch --git-op "push --force origin scratch" --files 1 --lines 1 </dev/null)"
check "D4: force-push to a branch NOT on origin -> rc 0"    "0" "${OUT%%|*}"
OUT="$(hc --repo "$REPO" --branch main --git-op "push origin main" --files 1 --lines 1 </dev/null)"
check "D5: an ordinary (non-force) push -> rc 0"            "0" "${OUT%%|*}"
OUT="$(hc --repo "$REPO" --git-op "push --force origin main" --files 1 --lines 1 </dev/null)"
check "D6: force-push with NO --branch declared -> refused, not guessed" "1" "${OUT%%|*}"

echo
echo "=== E. cross-epic collision — another in-flight epic's own claim ======="
OUT="$(hc --repo "$REPO" --branch feat/shared-thing --epics-root "$EPICS" --epic-dir 21-mine --files 1 --lines 1 </dev/null)"
check "E1: branch claimed by another in-flight epic -> rc 1"  "1" "${OUT%%|*}"
check_contains "E2: reason names the OTHER epic"               1  "$OUT" "09-other"
OUT="$(hc --repo "$REPO" --branch feat/old-claim --epics-root "$EPICS" --epic-dir 21-mine --files 1 --lines 1 </dev/null)"
check "E3: same branch claimed only by a CLOSED epic -> rc 0" "0" "${OUT%%|*}"
OUT="$(hc --repo "$REPO" --branch feat/shared-thing --epics-root "$EPICS" --epic-dir 09-other --files 1 --lines 1 </dev/null)"
check "E4: an epic never collides with its OWN claim -> rc 0" "0" "${OUT%%|*}"
OUT="$(hc --repo "$REPO" --branch feat/unclaimed --epics-root "$EPICS" --epic-dir 21-mine --files 1 --lines 1 </dev/null)"
check "E5: an unclaimed branch -> rc 0"                        "0" "${OUT%%|*}"

echo
echo "=== F. ordering — STOP beats every other guard, cheapest-first ========="
touch "$INTAKE_STOP_FILE"
OUT="$(hc --repo "$REPO" --branch main --git-op "push --force origin main" \
          --epics-root "$EPICS" --epic-dir 21-mine --files 999 --lines 999 \
          <<<".github/workflows/ci.yml")"
check "F1: every guard would fire — still rc 1" "1" "${OUT%%|*}"
check_contains "F2: STOP is the reason reported, not a later guard" 1 "$OUT" "STOP present at"
rm -f "$INTAKE_STOP_FILE"

echo
echo "=== G. the CLI entry point calls the SAME function ====================="
CLI_OUT="$(bash "$LIB" --harm-check --repo "$REPO" --slug fixture/repo --files 1 --lines 1 </dev/null)"
CLI_RC=$?
check "G1: CLI --harm-check exits 0 on a clean run" "0" "$CLI_RC"
check_contains "G2: CLI reports PASS" 1 "$CLI_OUT" "harm-check      PASS"
touch "$INTAKE_STOP_FILE"
CLI_OUT="$(bash "$LIB" --harm-check --repo "$REPO" --slug fixture/repo --files 1 --lines 1 </dev/null)"
CLI_RC=$?
check "G3: CLI --harm-check exits 1 when STOP is present" "1" "$CLI_RC"
check_contains "G4: CLI's own refusal line names STOP, from the same function" 1 "$CLI_OUT" "STOP present at"
rm -f "$INTAKE_STOP_FILE"

echo
echo "=== H. the stdin caveat — a here-string survives, a bare pipe does not =="
# Sourced directly (not through hc's subshell wrapper) so the pipe-subshell
# trap the function's own header warns about is observable in THIS shell.
(
  set -u
  . "$LIB"
  autonomy_resolve "$REPO" fixture/repo
  AUTONOMY_HARM_REASON=""
  printf '.github/workflows/ci.yml\n' | autonomy_harm_check --repo "$REPO" --files 1 --lines 1 >/dev/null
  PIPE_RC=$?
  PIPE_REASON="${AUTONOMY_HARM_REASON:-}"
  autonomy_harm_check --repo "$REPO" --files 1 --lines 1 <<<".github/workflows/ci.yml" >/dev/null
  HERESTRING_RC=$?
  HERESTRING_REASON="${AUTONOMY_HARM_REASON:-}"
  printf 'PIPE_RC=%s PIPE_REASON_EMPTY=%s HERESTRING_RC=%s HERESTRING_REASON_EMPTY=%s\n' \
    "$PIPE_RC" "$([ -z "$PIPE_REASON" ] && echo yes || echo no)" \
    "$HERESTRING_RC" "$([ -z "$HERESTRING_REASON" ] && echo yes || echo no)"
) > "$SANDBOX/h.out"
H="$(cat "$SANDBOX/h.out")"
check_contains "H1: both forms still refuse (rc 1) — the exit code survives either way" 1 "$H" "PIPE_RC=1"
check_contains "H2: a bare pipe loses AUTONOMY_HARM_REASON in the caller's shell (documented, not a bug)" 1 "$H" "PIPE_REASON_EMPTY=yes"
check_contains "H3: a here-string keeps AUTONOMY_HARM_REASON in the caller's shell" 1 "$H" "HERESTRING_RC=1"
check_contains "H4: ...and the reason text is NOT empty" 1 "$H" "HERESTRING_REASON_EMPTY=no"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
