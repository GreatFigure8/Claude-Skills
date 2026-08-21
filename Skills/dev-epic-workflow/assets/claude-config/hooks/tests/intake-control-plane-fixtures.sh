#!/usr/bin/env bash
# Fixture harness for ONE CONTROL PLANE (epic 11 item 2), across all three
# halves of the mechanism:
#   ../../bin/intake-status.sh          — the telemetry library: where records go,
#                                         what shape they are, and what it refuses
#   ../../bin/unattended-intake.sh      — the runner, which now reports every cycle
#                                         and every issue into that control plane
#   ../session-start-context.sh         — the reader, which tells ANY session that
#                                         opens that a cycle is in flight
#
# THE DEFECT THIS CLOSES, counted on 2026-08-21 rather than supposed. There were
# two telemetry universes and only one of them was visible from a session: the
# orchestrated executor wrote status.json milestones and an agent log into the
# canonical status tree, while the unattended runner made ZERO control-plane
# writes and this hook contained ZERO references to a running cycle. Watching the
# runner draft nine proposals meant knowing ~/.config/claude-intake/intake.log
# exists and `tail -f`-ing it by hand. An automation nobody can see is not
# automation, it is a background process.
#
# WHAT THIS PROVES.
#   - a cycle and each of its issues get a status.json-SHAPED record and an
#     agent-style log in the canonical tree, resolved as the hooks resolve it, so
#     a worktree cannot split it (section A, with a REAL git worktree)
#   - the reserved tree can never be mistaken for an epic — GUARANTEE 2 here
#     (a plan.md in it is REFUSED), GUARANTEE 1 in active-epic-fixtures.sh
#     section O against the real resolver, GUARANTEE 3 by there being no code
#     that writes the pointer (section B)
#   - the target path is VISIBLE AT THE CALL SITE and a write outside the bound
#     tree is refused rather than performed correctly-but-invisibly (GH #63,
#     section E)
#   - `unknown` exists as an out-of-band value and is never rendered as progress
#     (sections E and H)
#   - a cycle killed mid-flight leaves a record that says so rather than one that
#     looks finished — SIGTERM through the trap, SIGKILL by inference (section G)
#   - every transition appears EXACTLY ONCE in ledger.jsonl (section F)
#   - a session opened mid-cycle is told which issue and how many remain, with no
#     tail and no prior knowledge (section H)
#   - a repo with NO autonomy configuration still reports, because L0 drafting is
#     what runs unattended today and it is the thing that most needs watching
#     (section F)
#
# WHAT IT DOES NOT PROVE. Nothing here is about what the runner DOES. Item 2
# changes only what it reports, and section I is the assertion: with the library
# removed the runner's log, its call stream, its stdout and the plan it drafts are
# BYTE-IDENTICAL, which is the same thing as saying no decision reads telemetry.
#
# THE NEGATIVE CONTROL, BUILT BRITTLE ON PURPOSE. A suite that passes against the
# code as it stood BEFORE the item tests nothing:
#   - it HARD-ERRORS at startup if bin/intake-status.sh is absent or carries no
#     INTAKE_STATUS_CONTRACT= marker, and if the SessionStart hook has no
#     intake_cycle_section — it does not skip, it does not warn, it aborts
#   - section J reconstructs the PRE-ITEM-2 hook by deleting exactly the lines
#     the item added, requires the reconstruction to be exactly that many lines
#     shorter and to still parse, and then requires it to say NOTHING about a
#     live cycle. If the block moves, the suite stops rather than proving nothing
#   - section I runs the whole runner with the library REMOVED and requires the
#     control plane to be entirely absent, which is precisely the universe the
#     defect describes
#
# SANDBOXING (GH #15 is open and unfixed: a harness in this repo has already
# escaped its sandbox and committed a real working tree). Every repo, worktree,
# config, log and stub lives under one `mktemp -d` removed on exit, every
# destructive path goes through sandboxed(), and the host repo's HEAD and
# porcelain status are fingerprinted before and after.
#
# IT NEVER READS OR WRITES ~/.config/claude-intake. INTAKE_LOG, INTAKE_LOCK,
# INTAKE_REPO_LIST and every control file are redirected into the sandbox and
# HOME itself is moved, so a machine running a live unattended timer is untouched
# by this suite and this suite is unaffected by it.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-control-plane-fixtures.sh
#         INTAKE_FIXTURE_STATUS_LIB=/path/to/other-intake-status.sh bash ...
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-unattended-intake.sh bash ...
#         INTAKE_FIXTURE_SESSION_HOOK=/path/to/other-session-start-context.sh bash ...
#           (the overrides exist so this suite can be pointed at a PRE-ITEM-2
#            tree as a negative control; it must NOT pass there, it must ABORT)
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$TESTS_DIR/.." && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
LIB="${INTAKE_FIXTURE_STATUS_LIB:-$BIN_DIR/intake-status.sh}"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/unattended-intake.sh}"
HOOK="${INTAKE_FIXTURE_SESSION_HOOK:-$HOOKS_DIR/session-start-context.sh}"
AUTONOMY_LIB="$BIN_DIR/autonomy.sh"
# Epic 11 item 3's dispatch library, passed EXPLICITLY for the same reason
# INTAKE_AUTONOMY_LIB is: the runner resolves it relative to its OWN path, so any
# reconstruction that lives in the sandbox would silently lose it while the
# shipped copy kept it, and a byte-identity proof would then be about two
# variables instead of one. Items 1 and 2b's suites carry the identical line.
CP_DISPATCH_LIB="${INTAKE_FIXTURE_DISPATCH_LIB:-$BIN_DIR/dispatch.sh}"

# ---------------------------------------- the negative control's tripwires
# Not skips, not warnings: aborts. Pointed at a pre-item-2 tree this suite must
# stop with a message, because a suite that "passes" where the feature does not
# exist is worse than no suite at all.
[ -f "$SCRIPT" ] || { echo "ERROR: not found: $SCRIPT" >&2; exit 1; }
[ -f "$HOOK" ]   || { echo "ERROR: not found: $HOOK" >&2; exit 1; }
if [ ! -f "$LIB" ]; then
  echo "ERROR: no intake control plane at $LIB." >&2
  echo "       This suite tests epic 11 item 2. Against a tree that predates it" >&2
  echo "       there is nothing to test, and passing would be a lie. Aborting." >&2
  exit 1
fi
if ! grep -q '^INTAKE_STATUS_CONTRACT=' "$LIB"; then
  echo "ERROR: $LIB carries no INTAKE_STATUS_CONTRACT= marker." >&2
  echo "       Either it is not the telemetry library, or the marker was removed." >&2
  exit 1
fi
if ! grep -q 'intake_cycle_section' "$HOOK"; then
  echo "ERROR: $HOOK has no intake_cycle_section." >&2
  echo "       The runner would be reporting into a control plane that no session" >&2
  echo "       reads, which is the defect item 2 exists to close. Aborting." >&2
  exit 1
fi
if ! grep -q 'intake_status_open' "$SCRIPT"; then
  echo "ERROR: $SCRIPT never opens a control plane." >&2
  echo "       This is the pre-item-2 runner: zero status writes. Aborting." >&2
  exit 1
fi

RESERVED="$(sed -n 's/^INTAKE_STATUS_RESERVED_DIR="\(.*\)"$/\1/p' "$LIB" | head -1)"
case "$RESERVED" in
  .?*) ;;
  *) echo "ERROR: the reserved dir is [$RESERVED] and does not begin with a dot." >&2
     echo "       GUARANTEE 1 is that a shell * cannot match it. Aborting." >&2
     exit 1 ;;
esac
UNTRUSTED="$(sed -n 's/^INTAKE_STATUS_UNTRUSTED_STATE="\(.*\)"$/\1/p' "$LIB" | head -1)"
[ -n "$UNTRUSTED" ] || {
  echo "ERROR: $LIB defines no INTAKE_STATUS_UNTRUSTED_STATE." >&2
  echo "       The status contract needs a defined out-of-band value for 'this" >&2
  echo "       record is untrustworthy' (GH #63). Aborting." >&2
  exit 1
}

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-control-plane-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0

sandboxed() { # $1 = path about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then VERDICT="PASS"; else VERDICT="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-66s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$2" "$3" "$VERDICT"
}
contains() { case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac; }
yesno() { if "$@"; then printf 'yes'; else printf 'no'; fi; }

REAL_GIT="$(command -v git)"
git_q() { "$REAL_GIT" -c user.email=fixture@example.com -c user.name=fixture \
                      -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }

# -------------------------------------------------- GH #15 tripwire (read only)
HOST_REPO="$("$REAL_GIT" -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
host_fingerprint() {
  [ -n "$HOST_REPO" ] || { printf 'no-host-repo'; return; }
  printf '%s|%s' "$("$REAL_GIT" -C "$HOST_REPO" rev-parse HEAD 2>/dev/null)" \
                 "$("$REAL_GIT" -C "$HOST_REPO" status --porcelain 2>/dev/null | sort | cksum)"
}
HOST_BEFORE="$(host_fingerprint)"

echo "sandbox: $SANDBOX"
echo "library: $LIB   (reserved dir [$RESERVED], untrusted state [$UNTRUSTED])"
echo "runner:  $SCRIPT"
echo "hook:    $HOOK"
echo "bash:    $(/bin/bash --version | head -1)"
echo "git:     $("$REAL_GIT" --version)"
echo
# ============================================================================
# A REAL git repo with a REAL linked worktree. The whole point of resolving the
# canonical root with --git-common-dir is that a worktree cannot split the
# control plane, and a stubbed git could not prove that.
mkrepo() { # $1 = base -> $1/main (checkout) + $1/wt (linked worktree)
  sandboxed "$1"
  rm -rf "$1"; mkdir -p "$1/main/docs/epics"
  printf 'fixture\n' > "$1/main/README.md"
  git_q -C "$1/main" init -q
  git_q -C "$1/main" checkout -q -b main 2>/dev/null || git_q -C "$1/main" branch -q -m main
  git_q -C "$1/main" add -A >/dev/null 2>&1
  git_q -C "$1/main" commit -qm fixture >/dev/null 2>&1
  git_q -C "$1/main" worktree add -q -b proposed/x "$1/wt" main >/dev/null 2>&1
}

# Run a snippet with the library sourced, in its own process, with the REAL git.
libsh() { # $1 = snippet
  INTAKE_STATUS_GIT="$REAL_GIT" /bin/bash -c '
set -u
. "$0"
'"$1" "$LIB"
}

echo "=== A. the canonical tree, resolved as the hooks resolve it ============="
A="$SANDBOX/A"; mkrepo "$A"
# Opened from INSIDE the linked worktree. If it resolved --show-toplevel, or the
# cwd, the records would land in $A/wt and no session would ever see them.
libsh '
intake_status_open "'"$A"'/wt" "owner/repo" "docs/epics" "'"$A"'/lock"
printf "%s\n" "$INTAKE_STATUS_DIR" > "'"$A"'/resolved"
INTAKE_STATUS_TOTAL=3; INTAKE_STATUS_DONE=1; INTAKE_STATUS_ISSUE=42
intake_status_cycle drafting "drafting #42"
intake_status_issue 42 "proposed/42-a-thing" drafting "headless drafter running"
'
check "A: opened from a WORKTREE, resolved to the MAIN checkout" \
      "$A/main/docs/epics/$RESERVED/status" "$(cat "$A/resolved" 2>/dev/null)"
check "A: the worktree got no status tree of its own" "no" \
      "$(yesno test -d "$A/wt/docs/epics/$RESERVED")"
check "A: the cycle record exists" "yes" \
      "$(yesno test -f "$A/main/docs/epics/$RESERVED/status/cycle.json")"
check "A: the per-issue record is named as an executor's is" "yes" \
      "$(yesno test -f "$A/main/docs/epics/$RESERVED/status/proposed-42-a-thing.json")"
check "A: an agent-style log was written" "1" \
      "$(ls "$A/main/docs/epics/$RESERVED/status"/agent-*.log 2>/dev/null | wc -l | tr -d ' ')"
check "A: the log opens with the same bracket shape the lifecycle hook writes" "yes" \
      "$(yesno grep -q '── INTAKE CYCLE START' "$A/main/docs/epics/$RESERVED/status"/agent-*.log)"
check "A: the ledger exists underneath" "yes" \
      "$(yesno test -f "$A/main/docs/epics/$RESERVED/status/ledger.jsonl")"
# status.json-SHAPED: the first six keys, in the order an executor's status file
# has them, so one reader reads both.
check "A: the cycle record is status.json-shaped (first six keys, in order)" \
      "item branch state detail commit updated" \
      "$(sed -n 's/^  "\([a-z]*\)":.*/\1/p' "$A/main/docs/epics/$RESERVED/status/cycle.json" | head -6 | tr '\n' ' ' | sed 's/ $//')"
check "A: branch and commit are null, never a plausible guess" "null|null" \
      "$(sed -n 's/^  "branch": \(.*\),$/\1/p;' "$A/main/docs/epics/$RESERVED/status/cycle.json")|$(sed -n 's/^  "commit": \(.*\),$/\1/p' "$A/main/docs/epics/$RESERVED/status/cycle.json")"
check "A: it carries the queue counts a reader needs" "3|1|2" \
      "$(sed -n 's/^  "total": \(.*\),$/\1/p' "$A/main/docs/epics/$RESERVED/status/cycle.json")|$(sed -n 's/^  "done": \(.*\),$/\1/p' "$A/main/docs/epics/$RESERVED/status/cycle.json")|$(sed -n 's/^  "queued": \(.*\),$/\1/p' "$A/main/docs/epics/$RESERVED/status/cycle.json")"

echo
echo "=== B. it is a control plane, not an epic, and not a dirty checkout ====="
check "B: GUARANTEE 2 — it contains no plan.md" "no" \
      "$(yesno test -e "$A/main/docs/epics/$RESERVED/plan.md")"
check "B: and the tree carries a self-ignoring .gitignore" "*" \
      "$(cat "$A/main/docs/epics/$RESERVED/.gitignore" 2>/dev/null)"
check "B: so the target checkout stays CLEAN — the runner never dirties a repo" "" \
      "$(git_q -C "$A/main" status --porcelain 2>/dev/null)"
check "B: it says in the tree itself that it is not an epic" "yes" \
      "$(yesno grep -q 'THIS IS NOT AN EPIC' "$A/main/docs/epics/$RESERVED/README")"
check "B: and that status is a convenience view, not the truth" "yes" \
      "$(yesno grep -q 'THE REPO IS THE TRUTH' "$A/main/docs/epics/$RESERVED/README")"
check "B: GUARANTEE 3 — no code in the library writes the active-epic pointer" "0" \
      "$(grep -v '^[[:space:]]*#' "$LIB" | grep -c 'signals/active-epic' | tr -d ' ')"
check "B: nor does the runner's item-2 wiring" "0" \
      "$(grep -v '^[[:space:]]*#' "$SCRIPT" | grep -c 'signals/active-epic' | tr -d ' ')"
# GUARANTEE 2, ENFORCED rather than assumed: plant a plan.md and the library
# REFUSES the tree outright. Losing telemetry is recoverable; GH #9 was not.
B2="$SANDBOX/B2"; mkrepo "$B2"
mkdir -p "$B2/main/docs/epics/$RESERVED"
printf '# Epic: not really\n\n**Status:** in flight (item 1 of 1)\n' > "$B2/main/docs/epics/$RESERVED/plan.md"
libsh '
intake_status_open "'"$B2"'/main" "owner/repo" "docs/epics" "'"$B2"'/lock"
printf "[%s]\n" "$INTAKE_STATUS_DIR" > "'"$B2"'/resolved"
printf "%s\n" "$INTAKE_STATUS_LAST_ERROR" > "'"$B2"'/err"
intake_status_cycle drafting "should never be written"
'
check "B: a plan.md in the reserved tree makes the library REFUSE it" "[]" \
      "$(cat "$B2/resolved" 2>/dev/null)"
check "B: and it names the reason" "yes" \
      "$(yesno grep -q 'contains a plan.md' "$B2/err")"
check "B: no record was written into a tree that could be resolved as an epic" "no" \
      "$(yesno test -e "$B2/main/docs/epics/$RESERVED/status/cycle.json")"
check "B: a refused tree is silent, not fatal — the caller never branches on it" "0" \
      "$(libsh 'intake_status_open "'"$B2"'/main" r d "'"$B2"'/lock"; printf "%s" "$?"')"

echo
echo "=== C. arbitrary human text is a boundary, not a nicety ================="
# Issue titles go straight into these records. An embedded newline would split
# one key across two lines and break every reader; a quote would break the JSON.
C="$SANDBOX/C"; mkrepo "$C"
CD="$C/main/docs/epics/$RESERVED/status"
libsh '
intake_status_open "'"$C"'/main" "owner/repo" "docs/epics" "'"$C"'/lock"
intake_status_cycle drafting "$(printf "a \"quoted\" title\nwith a newline\tand a tab \\\\ backslash")"
'
check "C: the record is still one key per line" "1" \
      "$(grep -c '^  "detail":' "$CD/cycle.json" | tr -d ' ')"
check "C: the newline was FOLDED, not emitted — it appears on ONE line" "1" \
      "$(grep -c 'with a newline' "$CD/cycle.json" | tr -d ' ')"
check "C: ...and that line is the detail line" "yes" \
      "$(yesno grep -q '^  "detail": .*with a newline' "$CD/cycle.json")"
check "C: so every line of the record is still a key or a brace" "0" \
      "$(grep -vc '^\(  "\|[{}]\)' "$CD/cycle.json" | tr -d ' ')"
check "C: quotes are escaped" "yes" \
      "$(yesno grep -q '\\"quoted\\"' "$CD/cycle.json")"
check "C: the ledger line survives it too — still exactly one line per write" "1" \
      "$(grep -c . "$CD/ledger.jsonl" | tr -d ' ')"
if command -v python3 >/dev/null 2>&1; then
  check "C: and the record is genuinely parseable JSON" "ok" \
        "$(python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("ok")' "$CD/cycle.json" 2>&1 | tail -1)"
  check "C: so is the ledger line" "ok" \
        "$(python3 -c 'import json,sys
[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
print("ok")' "$CD/ledger.jsonl" 2>&1 | tail -1)"
fi

echo
echo "=== D. a record is named exactly as an orchestrated executor's is ======="
check "D: slashes become dashes, as <branch-slug>.json does" "proposed-91-a-thing" \
      "$(libsh 'intake_status_branch_slug "proposed/91-a-thing"')"
check "D: a branchless record still gets a stable name" "yes" \
      "$(D2="$SANDBOX/D2"; mkrepo "$D2"
         libsh 'intake_status_open "'"$D2"'/main" r docs/epics "'"$D2"'/lock"
                intake_status_issue 91 "" skipped "no branch was ever cut"' >/dev/null
         yesno test -f "$D2/main/docs/epics/$RESERVED/status/issue-91.json")"

echo
echo "=== E. GH #63: the target path is VISIBLE, and a stray write is REFUSED ="
# The incident: an executor clobbered a SIBLING EPIC's status.json through a
# helper whose command line did not show the target. The invariant is not
# "validate the payload" — the payload was fine — it is that the target path
# must be visible at the call site. Here the writer resolves NOTHING and refuses
# anything that is not a direct child of the tree it bound to.
E="$SANDBOX/E"; mkrepo "$E"
mkdir -p "$E/main/docs/epics/05-a-sibling-epic/status"
printf '{"state":"implementing","item":"someone elses work"}\n' \
  > "$E/main/docs/epics/05-a-sibling-epic/status/feat-theirs.json"
SIB_BEFORE="$(cksum < "$E/main/docs/epics/05-a-sibling-epic/status/feat-theirs.json")"
libsh '
intake_status_open "'"$E"'/main" "owner/repo" "docs/epics" "'"$E"'/lock"
intake_status_cycle scanning "a legitimate write, for contrast"
intake_status_write "'"$E"'/main/docs/epics/05-a-sibling-epic/status/feat-theirs.json" "{}"
printf "%s\n" "$?" > "'"$E"'/rc-sibling"
intake_status_write "$INTAKE_STATUS_DIR/../../05-a-sibling-epic/status/feat-theirs.json" "{}"
printf "%s\n" "$?" >> "'"$E"'/rc-sibling"
intake_status_write "$INTAKE_STATUS_DIR/sub/dir/thing.json" "{}"
printf "%s\n" "$?" >> "'"$E"'/rc-sibling"
printf "%s\n" "$INTAKE_STATUS_LAST_ERROR" > "'"$E"'/err"
'
check "E: a write aimed at a SIBLING EPIC's status.json is refused" "1
1
1" "$(cat "$E/rc-sibling")"
check "E: and the sibling's file is byte-identical afterwards" "$SIB_BEFORE" \
      "$(cksum < "$E/main/docs/epics/05-a-sibling-epic/status/feat-theirs.json")"
check "E: the refusal names BOTH paths, so the mistake is legible" "yes" \
      "$(yesno grep -q 'not a direct child of the bound control plane' "$E/err")"
check "E: refusals are recorded in the agent log, not swallowed" "3" \
      "$(grep -c 'REFUSED a status write' "$E/main/docs/epics/$RESERVED/status"/agent-*.log | tr -d ' ')"
check "E: and every ACCEPTED write logs the path it wrote" "yes" \
      "$(yesno grep -q "wrote $E/main/docs/epics/$RESERVED/status/cycle.json" "$E/main/docs/epics/$RESERVED/status"/agent-*.log)"
# An UNBOUND reporter must refuse everything: with INTAKE_STATUS_DIR empty the
# prefix test would degrade to "/*" and admit every absolute path on the machine.
check "E: an unbound reporter refuses an absolute path outright" "1" \
      "$(libsh 'INTAKE_STATUS_DIR=""; intake_status_write "/tmp/anything.json" "{}"; printf "%s" "$?"')"
# The reason has to survive the call, and it did not while the body arrived on
# stdin: `printf … | intake_status_write` runs the FUNCTION in a subshell, so
# every global it sets dies with the pipeline and a refusal was silent about why.
check "E: and the reason SURVIVES the call — no subshell eats it" "yes" \
      "$(libsh 'INTAKE_STATUS_DIR=""; intake_status_write "/tmp/x.json" "{}"
                case "$INTAKE_STATUS_LAST_ERROR" in ?*) printf yes ;; *) printf no ;; esac')"

echo
echo "=== E2. the out-of-band value: a record that says it cannot be trusted =="
# A wrong-but-plausible status is worse than an obviously-broken one, because a
# reader ACTS on the plausible one. So a write that did not land says so, in a
# value that is deliberately not a milestone.
E2="$SANDBOX/E2"; mkrepo "$E2"
libsh '
intake_status_open "'"$E2"'/main" "owner/repo" "docs/epics" "'"$E2"'/lock"
INTAKE_STATUS_TOTAL=4; INTAKE_STATUS_DONE=2; INTAKE_STATUS_ISSUE=91
intake_status_cycle drafting "drafting #91"
# A mutant slug: the only realistic way a per-issue write leaves the tree.
intake_status_branch_slug() { printf "sub/dir/escape"; }
intake_status_issue 91 "proposed/91-x" pr-opened "https://example.invalid/pull/1"
'
E2D="$E2/main/docs/epics/$RESERVED/status"
check "E2: a per-issue write that could not land marks the CYCLE untrustworthy" "$UNTRUSTED" \
      "$(sed -n 's/^  "state": "\(.*\)",$/\1/p' "$E2D/cycle.json")"
check "E2: it is NOT one of the milestone states" "no" \
      "$(contains "scanning drafting publishing finished failed stopped interrupted" "$UNTRUSTED")"
check "E2: and it says why, naming the issue" "yes" \
      "$(yesno grep -q 'a record for #91 could not be written' "$E2D/cycle.json")"
check "E2: it points the reader at what IS authoritative" "yes" \
      "$(yesno grep -q 'the branches, the PRs and ledger.jsonl are the truth' "$E2D/cycle.json")"
check "E2: no record landed outside the tree" "no" \
      "$(yesno test -e "$E2D/sub/dir/escape.json")"
# Untrustworthy is TERMINAL: a later, cheerier write must not paper over it.
libsh '
intake_status_open "'"$E2"'/main" "owner/repo" "docs/epics" "'"$E2"'/lock"
INTAKE_STATUS_STATE="'"$UNTRUSTED"'"
intake_status_close finished "all done, nothing to see here"
'
check "E2: a later 'finished' cannot overwrite it" "$UNTRUSTED" \
      "$(sed -n 's/^  "state": "\(.*\)",$/\1/p' "$E2D/cycle.json")"

# ============================================================================
# ---------------------------------------------------------------- stubs ----
# Modelled on intake-collision-fixtures.sh and autonomy-control-fixtures.sh,
# which already answer every query a full cycle makes, and kept in the same
# shape deliberately: this item adds NO gh query at all, and a stub that drifted
# from those would hide the fact rather than reveal it. A stub that cannot answer
# a query says STUB UNANSWERED and exits 1 — a silent degradation is how a suite
# goes green while exercising the wrong path, and that cost epic 09 five
# corrections.
#
# The git stub DELEGATES rev-parse to the real git against a real repo, because
# canonical-root resolution is the thing under test and a stub that faked it
# would be asserting its own answer.
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

cat > "$BIN/gh" <<'GH_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
FLAT="$(printf '%s ' "$@" | tr '\n' ' ')"
printf 'gh %s\n' "$FLAT" >> "$CASE/calls.log"
unanswered() {
  printf 'gh STUB UNANSWERED (%s): %s\n' "$1" "$FLAT" >> "$CASE/calls.log"
  printf 'stub cannot answer: %s\n' "$1" >&2
  exit 1
}
case "${1:-}" in
  repo) case "$FLAT" in
          *nameWithOwner*)    printf '%s\n' "${FIXTURE_REPO_SLUG:-fixture/repo}" ;;
          *defaultBranchRef*) printf '%s\n' "${FIXTURE_DEFAULT_BRANCH:-main}" ;;
          *) unanswered "repo field set not modelled" ;;
        esac ;;
  label) case "${2:-}" in
           list)   printf '%s\tfixture label\n' "${FIXTURE_LABEL:-claude-intake}" ;;
           create) : ;;
           *)      unanswered "label verb not modelled" ;;
         esac ;;
  issue) case "${2:-}" in
           list)    [ -f "$CASE/issues" ] && cat "$CASE/issues"; exit 0 ;;
           view)    case "$FLAT" in *"--json title,labels "*) ;; *) unanswered "issue view field set changed" ;; esac
                    printf ',,\n'; printf 'fixture issue %s\n' "${3:-0}"; exit 0 ;;
           comment) for A in "$@"; do LAST="$A"; done
                    { printf '<<<comment on %s>>>\n' "${3:-0}"; printf '%s\n' "$LAST"; } >> "$CASE/comment-bodies.log"
                    printf 'https://example.invalid/issues/%s#comment\n' "${3:-0}"; exit 0 ;;
           edit)    exit 0 ;;
           *)       unanswered "issue verb not modelled" ;;
         esac ;;
  api) P=""
       for A in "$@"; do case "$A" in */issues/*/timeline*|*/contents/*|*/branches*) P="$A" ;; esac; done
       [ -n "$P" ] || unanswered "api path not modelled"
       case "$P" in
         */branches*) case "$FLAT" in *--paginate*) ;; *) unanswered "branch query is not paginated" ;; esac
                      [ -f "$CASE/branches" ] && cat "$CASE/branches"; exit 0 ;;
         */issues/*/timeline*) N="${P#*/issues/}"; N="${N%%/*}"
                      [ -f "$CASE/timeline/$N" ] && cat "$CASE/timeline/$N"; exit 0 ;;
         */contents/*) case "$FLAT" in *"Accept: application/vnd.github.raw"*) ;; *) unanswered "contents fetched without the raw Accept header" ;; esac
                      REF="${P##*\?ref=}"; KEY="$(printf '%s' "$REF" | tr '/' '_')"
                      [ -f "$CASE/contents/$KEY" ] || { echo 'Not Found' >&2; exit 1; }
                      cat "$CASE/contents/$KEY"; exit 0 ;;
       esac ;;
  pr) case "${2:-}" in
        list)   case "$FLAT" in *"--json number,headRefName "*) ;; *) unanswered "pr list field set changed" ;; esac
                [ -f "$CASE/proposals" ] && cat "$CASE/proposals"; exit 0 ;;
        view)   case "$FLAT" in *"--json state,headRefName,url,closingIssuesReferences,body "*) ;; *) unanswered "pr view field set changed" ;; esac
                F="$CASE/pr/${3:-}"; [ -f "$F" ] || { echo 'no such PR' >&2; exit 1; }; cat "$F"; exit 0 ;;
        create) printf 'https://example.invalid/pull/%s\n' "${FIXTURE_PR_N:-999}"; exit 0 ;;
        merge)  printf 'gh STUB REFUSED (the runner never merges): %s\n' "$FLAT" >> "$CASE/calls.log"; exit 98 ;;
        edit)   printf 'gh STUB REFUSED (an open PR is never rewritten): %s\n' "$FLAT" >> "$CASE/calls.log"; exit 98 ;;
        *)      unanswered "pr verb not modelled" ;;
      esac ;;
  *) unanswered "verb not modelled" ;;
esac
exit 0
GH_STUB

cat > "$BIN/git" <<'GIT_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
FLAT="$(printf '%s ' "$@" | tr '\n' ' ')"
printf 'git %s\n' "$FLAT" >> "$CASE/calls.log"
inside() { case "${1:-}" in "$FIXTURE_SANDBOX"/*) return 0 ;; *) return 1 ;; esac; }
CDIR=""
if [ "${1:-}" = "-C" ]; then CDIR="${2:-}"; shift 2; fi
case "${1:-}" in
  add|commit)
    if [ -n "$CDIR" ] && inside "$CDIR"; then
      printf 'git SANDBOXED-%s in %s\n' "$1" "$CDIR" >> "$CASE/calls.log"; exit 0
    fi
    printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"; exit 99 ;;
  rm|mv|checkout|switch|reset|merge|rebase|clean)
    printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"; exit 99 ;;
esac
case "${1:-}" in
  # DELEGATED, not faked: canonical-root resolution is the thing under test.
  # Refused outright outside the sandbox, so delegation can never reach the
  # host repo (GH #15).
  rev-parse)
    if [ -n "$CDIR" ] && ! inside "$CDIR"; then
      printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"; exit 99
    fi
    if [ -n "$CDIR" ]; then exec "$FIXTURE_REAL_GIT" -C "$CDIR" "$@"; else exec "$FIXTURE_REAL_GIT" "$@"; fi ;;
  ls-remote) exit 0 ;;
  ls-files)  printf 'docs/epics/01-fixture/plan.md\n'; exit 0 ;;
  fetch)     exit 0 ;;
  log)       printf 'f1x7ure fixture: drafted plan\n'; exit 0 ;;
  push)      exit 0 ;;
  branch)    exit 0 ;;
  worktree)
    case "${2:-}" in
      add)    for A in "$@"; do case "$A" in "$FIXTURE_SANDBOX"/*) WT="$A" ;; esac; done
              [ -n "${WT:-}" ] || { echo 'worktree outside sandbox' >&2; exit 1; }
              inside "$WT" || exit 1
              mkdir -p "$WT" && exit 0 ;;
      remove) for A in "$@"; do case "$A" in "$FIXTURE_SANDBOX"/*) WT="$A" ;; esac; done
              if [ -n "${WT:-}" ] && inside "$WT" && [ -d "$WT" ]; then
                rm -rf "$CASE/removed-worktree"
                mv "$WT" "$CASE/removed-worktree" 2>/dev/null || rm -rf "$WT"
              fi
              exit 0 ;;
    esac
    exit 0 ;;
esac
exit 0
GIT_STUB

cat > "$BIN/claude" <<'CLAUDE_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
printf 'claude -p <prompt>\n' >> "$CASE/calls.log"
PROMPT=""
while [ $# -gt 0 ]; do
  case "$1" in -p) PROMPT="${2:-}"; shift ;; esac
  shift
done
# The window a mid-cycle reader needs. Only when the case asks for it.
[ -f "$CASE/slow" ] && sleep "$(cat "$CASE/slow")"
PLANPATH="$(printf '%s' "$PROMPT" \
  | grep -oE '[A-Za-z]+/[A-Za-z]+/proposed-[A-Za-z0-9._-]+/plan\.md' | head -1)"
if [ -z "$PLANPATH" ]; then
  printf 'claude STUB UNANSWERED (no plan path in the prompt)\n' >> "$CASE/calls.log"
  exit 1
fi
mkdir -p "$(dirname "$PLANPATH")"
if [ -f "$CASE/draft.md" ]; then cp "$CASE/draft.md" "$PLANPATH"; else : > "$PLANPATH"; fi
exit 0
CLAUDE_STUB
chmod +x "$BIN/gh" "$BIN/git" "$BIN/claude"

SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
printf 'fixture issue-intake reference\n'  > "$SKILL/references/issue-intake.md"
printf 'fixture plan-template reference\n' > "$SKILL/references/plan-template.md"

DRAFT="$SANDBOX/ordinary.md"
cat > "$DRAFT" <<'PLAN'
# Epic: a fixture epic

**Status:** planning
**Source:** GH #90
**Recommendation:** plan

## Work items

### 1. Do the thing
- **Branch:** `feat/the-thing`
- **Scope:** `src/thing.ts`
PLAN

mkcase() { # $1 = case name -> case dir on stdout
  D="$SANDBOX/$1"; sandboxed "$D"
  rm -rf "$D"
  mkdir -p "$D/repo" "$D/worktrees" "$D/home" "$D/timeline" "$D/pr" "$D/contents"
  # A REAL repo, so --git-common-dir has something true to say.
  git_q -C "$D/repo" init -q
  printf 'fixture\n' > "$D/repo/README.md"
  git_q -C "$D/repo" add -A >/dev/null 2>&1
  git_q -C "$D/repo" commit -qm fixture >/dev/null 2>&1
  : > "$D/calls.log"; : > "$D/comment-bodies.log"; : > "$D/proposals"
  printf '%s\n' "$D/repo" > "$D/repos"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$D/env"
  chmod 600 "$D/env"
  cp "$DRAFT" "$D/draft.md"
  printf '%s' "$D"
}
set_issues() { D="$1"; shift; sandboxed "$D"; : > "$D/issues"
  for I in "$@"; do printf '%s\n' "$I" >> "$D/issues"; done; }

STATUS_LIB_UNDER_TEST="$LIB"
intake_env() { # $1 = case dir -> the environment every run shares
  D="$1"
  printf '%s\n' \
    "INTAKE_GIT=$BIN/git" "INTAKE_GH=$BIN/gh" "INTAKE_CLAUDE=$BIN/claude" \
    "INTAKE_SKILL_DIR=$SKILL" "INTAKE_ENV_FILE=$D/env" \
    "INTAKE_REPO_LIST=$D/repos" "INTAKE_REPO_DIR=$D/repo" \
    "INTAKE_LOG=$D/intake.log" "INTAKE_LOCK=$D/.lock" \
    "INTAKE_WORKTREE_ROOT=$D/worktrees" \
    "INTAKE_AUTONOMY_LIB=$AUTONOMY_LIB" "INTAKE_STATUS_LIB=$STATUS_LIB_UNDER_TEST" \
    "INTAKE_DISPATCH_LIB=$CP_DISPATCH_LIB" \
    "INTAKE_AUTONOMY_FILE=$D/autonomy" "INTAKE_AUTONOMY_OVERRIDE=$D/AUTONOMY-OFF" \
    "INTAKE_STOP_FILE=$D/STOP" "INTAKE_PROMOTIONS_DIR=$D/promotions" \
    "FIXTURE_CASE_DIR=$D" "FIXTURE_SANDBOX=$SANDBOX" "FIXTURE_REPO_SLUG=fixture/repo" \
    "FIXTURE_REAL_GIT=$REAL_GIT" "HOME=$D/home"
}
run_intake() { # $1 = case dir, rest = extra args -> exit code on stdout
  D="$1"; shift; sandboxed "$D"
  env $(intake_env "$D" | tr '\n' ' ') \
    /bin/bash "$SCRIPT" "$@" > "$D/stdout.log" 2> "$D/stderr.log"
  printf '%s' "$?"
}
run_intake_bg() { # $1 = case dir -> pid on stdout
  D="$1"; sandboxed "$D"
  env $(intake_env "$D" | tr '\n' ' ') \
    /bin/bash "$SCRIPT" > "$D/stdout.log" 2> "$D/stderr.log" &
  printf '%s' "$!"
}
# POLL, do not `wait`. This function is called inside a $( ), so the job it
# starts is a child of THAT subshell and `wait` in this shell returns instantly
# with "not a child of this shell" — which reads exactly like a process that
# exited, and made the first version of section G assert against a record the
# runner had not written yet. Same class of mistake as the two the library had.
await_exit() { # $1 = pid, $2 = seconds to allow
  AW_N=0; AW_MAX=$(( ${2:-30} * 5 ))
  while [ "$AW_N" -lt "$AW_MAX" ]; do
    kill -0 "$1" 2>/dev/null || return 0
    sleep 0.2 2>/dev/null || sleep 1
    AW_N=$((AW_N + 1))
  done
  return 1
}
await_state() { # $1 = cycle.json, $2 = state, $3 = seconds
  AS_N=0; AS_MAX=$(( ${3:-30} * 5 ))
  while [ "$AS_N" -lt "$AS_MAX" ]; do
    [ -f "$1" ] && [ "$(field "$1" state)" = "$2" ] && return 0
    sleep 0.2 2>/dev/null || sleep 1
    AS_N=$((AS_N + 1))
  done
  return 1
}
# Where a case's control plane lands, resolved the way the runner resolves it.
cp_dir() { printf '%s' "$1/repo/docs/epics/$RESERVED/status"; }
# The per-issue record's file name, derived from the RUNNER's own branch prefix
# rather than spelled again here: rename the prefix and this stops matching, out
# loud, instead of quietly asserting something about a file nothing writes.
PROPOSAL_PREFIX="$(sed -n 's/^PROPOSAL_BRANCH_PREFIX="${INTAKE_PROPOSAL_PREFIX:-\(.*\)}"$/\1/p' "$SCRIPT" | head -1)"
[ -n "$PROPOSAL_PREFIX" ] || { echo "ERROR: could not read PROPOSAL_BRANCH_PREFIX from $SCRIPT" >&2; exit 1; }
issue_rec() { # $1 = case dir, $2 = issue number -> the per-issue record path
  printf '%s/%s%s-fixture-issue-%s.json' "$(cp_dir "$1")" \
         "$(printf '%s' "$PROPOSAL_PREFIX" | tr '/' '-')" "$2" "$2"
}
field() { # $1 = json file, $2 = key -> the value, quotes stripped
  V="$(sed -n 's/^  "'"$2"'": \(.*\)$/\1/p' "$1" 2>/dev/null | head -1)"
  V="${V%,}"
  case "$V" in '"'*'"') V="${V#\"}"; V="${V%\"}" ;; esac
  printf '%s' "$V"
}

echo
echo "=== F. a real cycle reports itself, and reports itself ONCE ============="
# No autonomy config anywhere in this case: L0 drafting is what runs unattended
# today and it is the thing that most needs watching, so reporting is gated on
# nothing — not a level, not a config file, not a label.
F="$(mkcase F)"; set_issues "$F" 90 91
check "F: precondition — this repo has NO autonomy configuration" "no" \
      "$(yesno test -e "$F/autonomy")"
RC="$(run_intake "$F")"
FD="$(cp_dir "$F")"
check "F: the cycle ran to completion"                  "0"   "$RC"
check "F: and it opened its PRs, exactly as before"     "2"   "$(grep -c 'gh pr create' "$F/calls.log" | tr -d ' ')"
check "F: an UNCONFIGURED repo still reports its cycle" "yes" "$(yesno test -f "$FD/cycle.json")"
check "F: the cycle record is terminal, not left mid-flight" "finished" "$(field "$FD/cycle.json" state)"
check "F: it says how many issues it processed"         "2"   "$(field "$FD/cycle.json" done)"
check "F: nothing is left queued"                       "0"   "$(field "$FD/cycle.json" queued)"
check "F: one record per issue, named as an executor's <branch-slug>.json" "yes|yes" \
      "$(yesno test -f "$(issue_rec "$F" 90)")|$(yesno test -f "$(issue_rec "$F" 91)")"
check "F: each issue's record ends at pr-opened"        "pr-opened|pr-opened" \
      "$(field "$(issue_rec "$F" 90)" state)|$(field "$(issue_rec "$F" 91)" state)"
check "F: and carries the PR url, not a promise of one" "yes" \
      "$(yesno grep -q 'https://example.invalid/pull/999' "$(issue_rec "$F" 90)")"
check "F: and the recommendation the proposal reached"  "plan" \
      "$(field "$(issue_rec "$F" 90)" recommendation)"
check "F: the record names the branch it is about"      "${PROPOSAL_PREFIX}90-fixture-issue-90" \
      "$(field "$(issue_rec "$F" 90)" branch)"
check "F: one agent-style log for the cycle, not one per issue" "1" \
      "$(ls "$FD"/agent-*.log 2>/dev/null | wc -l | tr -d ' ')"
check "F: bracketed START and END, like a subagent's log" "1|1" \
      "$(grep -c 'INTAKE CYCLE START' "$FD"/agent-*.log | tr -d ' ')|$(grep -c 'INTAKE CYCLE END' "$FD"/agent-*.log | tr -d ' ')"
# EXACTLY ONCE. Written from one place per transition so this is a property of
# the call graph rather than of anyone remembering.
check "F: the ledger holds every transition"            "yes" "$(yesno test -f "$FD/ledger.jsonl")"
check "F: ...and each issue's pr-opened appears EXACTLY once" "1|1" \
      "$(grep -c '"issue":90,"detail":"https' "$FD/ledger.jsonl" | tr -d ' ')|$(grep -c '"issue":91,"detail":"https' "$FD/ledger.jsonl" | tr -d ' ')"
check "F: no ledger line is a duplicate of another"     "0" \
      "$(cut -d, -f2- "$FD/ledger.jsonl" | sort | uniq -d | grep -c . | tr -d ' ')"
check "F: the cycle reached the terminal state exactly once" "1" \
      "$(grep -c '"kind":"cycle","state":"finished"' "$FD/ledger.jsonl" | tr -d ' ')"
# The flat log survives underneath, and now NAMES where the records are, so a
# human who still tails it is told where to look instead.
check "F: the flat log still exists — the audit trail is not replaced" "yes" \
      "$(yesno test -s "$F/intake.log")"
check "F: and it names the resolved control plane, once per repo" "1" \
      "$(grep -c "control plane: $FD" "$F/intake.log" | tr -d ' ')"
check "F: the target repo is NOT dirtied by any of it" "" \
      "$(git_q -C "$F/repo" status --porcelain 2>/dev/null)"
check "F: no stub was left unanswered"                 "0" \
      "$(grep -c 'STUB UNANSWERED' "$F/calls.log" | tr -d ' ')"
check "F: nothing was merged, and nothing tried"       "0" \
      "$(grep -c 'gh pr merge' "$F/calls.log" | tr -d ' ')"

echo
echo "=== F2. a skipped or failed issue leaves a record that says which ======="
F2="$(mkcase F2)"; set_issues "$F2" 92
# Work on this issue is already cut: a branch on origin is named for it, which
# is the `in-flight-branch` signal. The runner skips, and the point here is that
# the SKIP is reported as a skip rather than vanishing.
printf 'feat/92-someone-is-already-on-it\n' > "$F2/branches"
RC="$(run_intake "$F2")"
F2D="$(cp_dir "$F2")"
check "F2: the cycle still finished"                   "0" "$RC"
check "F2: no PR was created for the skipped issue"    "0" \
      "$(grep -c 'gh pr create' "$F2/calls.log" | tr -d ' ')"
check "F2: the issue's record says skipped, not drafting" "skipped" \
      "$(field "$F2D/issue-92.json" state 2>/dev/null)"
check "F2: and carries the machine-readable skip signal" "yes" \
      "$(yesno grep -q 'signal:' "$F2D/issue-92.json")"
check "F2: the cycle counted it as done, not still queued" "1|0" \
      "$(field "$F2D/cycle.json" done)|$(field "$F2D/cycle.json" queued)"
check "F2: exactly one ledger line for it — a skip is one transition" "1" \
      "$(grep -c '"issue":92' "$F2D/ledger.jsonl" | tr -d ' ')"
check "F2: and it is not recorded as a failure"       "finished" \
      "$(field "$F2D/cycle.json" state)"

echo
echo "=== F3. --dry-run reports; it must not CREATE a control plane ==========="
F3="$(mkcase F3)"; set_issues "$F3" 90
RC="$(run_intake "$F3" --dry-run)"
check "F3: --dry-run exits clean"                      "0"  "$RC"
check "F3: and creates no status tree anywhere"        "no" \
      "$(yesno test -e "$F3/repo/docs/epics/$RESERVED")"
check "F3: 'mutate nothing, anywhere' includes telemetry" "no" \
      "$(yesno test -e "$(cp_dir "$F3")/cycle.json")"

echo
echo "=== G. a cycle killed mid-flight says so; it must not look finished ====="
# THE FAILURE MODE THIS CLOSES: a record reading `drafting` forever is
# indistinguishable from a cycle still working, and one reading `finished` when
# the process died is worse — wrong AND plausible, which is the one a reader
# acts on.
#
# THREE DEATHS, THREE DIFFERENT TRUTHS, and they are not interchangeable:
#   SIGHUP  — untrapped, kills the shell, and the EXIT trap still runs: the
#             runner closes its own record as `interrupted`
#   SIGKILL — runs nothing at all: the record must stay NON-TERMINAL rather than
#             claim anything, and the reader infers it (section H3)
#   SIGTERM — trapped, and the handler RETURNS, so the runner carries on exactly
#             as it did before this item. The signal is recorded; the cycle is
#             not falsely closed.
G="$(mkcase G)"; set_issues "$G" 90
printf '6\n' > "$G/slow"                # a window to interrupt inside
GPID="$(run_intake_bg "$G")"
GD="$(cp_dir "$G")"
await_state "$GD/cycle.json" drafting 30
check "G: precondition — the cycle really is mid-draft"  "drafting" "$(field "$GD/cycle.json" state)"
check "G: ...on the issue it is drafting"                "90"       "$(field "$GD/cycle.json" issue)"
check "G: ...and the lock it recorded is really held"    "yes"      "$(yesno test -d "$G/.lock")"
pkill -P "$GPID" 2>/dev/null || true
kill -HUP "$GPID" 2>/dev/null
check "G: the runner is gone"                            "0" "$(await_exit "$GPID" 30; printf '%s' "$?")"
check "G: a fatal signal leaves a record that says INTERRUPTED" "interrupted" \
      "$(field "$GD/cycle.json" state)"
check "G: it does NOT say finished"                      "no" \
      "$(contains "$(field "$GD/cycle.json" state)" "finished")"
check "G: and it says what happened, in one line"        "yes" \
      "$(yesno grep -q 'did not finish' "$GD/cycle.json")"
check "G: it points at the records stopping where it stopped" "yes" \
      "$(yesno grep -q 'its records stop where it stopped' "$GD/cycle.json")"
check "G: the lock was released on the way out"          "no"  "$(yesno test -d "$G/.lock")"
check "G: the interruption is in the ledger exactly once" "1" \
      "$(grep -c '"state":"interrupted"' "$GD/ledger.jsonl" | tr -d ' ')"
check "G: the log is bracketed closed EXACTLY once"      "1" \
      "$(grep -c 'INTAKE CYCLE END' "$GD"/agent-*.log | tr -d ' ')"
check "G: the issue's own record still says drafting, honestly" "drafting" \
      "$(field "$(issue_rec "$G" 90)" state)"
check "G: no PR was opened for it"                       "0" \
      "$(grep -c 'gh pr create' "$G/calls.log" | tr -d ' ')"

# SIGKILL: no trap runs at all, so the record CANNOT say anything. What matters
# is that it does not LIE — it stays non-terminal, and keeps the pid and lock a
# reader needs to tell a dead cycle from a live one.
G2="$(mkcase G2)"; set_issues "$G2" 90
printf '6\n' > "$G2/slow"
G2PID="$(run_intake_bg "$G2")"
G2D="$(cp_dir "$G2")"
await_state "$G2D/cycle.json" drafting 30
check "G2: precondition — mid-draft again"  "drafting" "$(field "$G2D/cycle.json" state)"
pkill -P "$G2PID" 2>/dev/null || true
kill -KILL "$G2PID" 2>/dev/null
await_exit "$G2PID" 30
check "G2: SIGKILL leaves the record NON-TERMINAL, never 'finished'" "drafting" \
      "$(field "$G2D/cycle.json" state)"
check "G2: the recorded pid is gone"        "no"  "$(yesno kill -0 "$G2PID")"
check "G2: the record kept the pid, so a reader can tell" "$G2PID" \
      "$(field "$G2D/cycle.json" pid)"
check "G2: and the lock it names, which no trap removed" "yes" \
      "$(yesno test -d "$(field "$G2D/cycle.json" lock)")"
check "G2: no CYCLE END was written — nothing ran to write one" "0" \
      "$(grep -c 'INTAKE CYCLE END' "$G2D"/agent-*.log | tr -d ' ')"

# SIGTERM: the handler returns and the runner carries on — that was true before
# this item and item 2 does not change what the runner DOES. So the signal is
# noted and the cycle is not falsely closed; the `finished` it ends at is TRUE.
G3="$(mkcase G3)"; set_issues "$G3" 90
printf '3\n' > "$G3/slow"
G3PID="$(run_intake_bg "$G3")"
G3D="$(cp_dir "$G3")"
await_state "$G3D/cycle.json" drafting 30
kill -TERM "$G3PID" 2>/dev/null
check "G3: the runner survived SIGTERM and ran on, as it always has" "0" \
      "$(await_exit "$G3PID" 60; printf '%s' "$?")"
await_state "$G3D/cycle.json" finished 30
check "G3: the signal is RECORDED"                      "1" \
      "$(grep -c '"kind":"signal","state":"TERM"' "$G3D/ledger.jsonl" | tr -d ' ')"
check "G3: and named in the agent log"                  "1" \
      "$(grep -c 'SIGNAL TERM received' "$G3D"/agent-*.log | tr -d ' ')"
check "G3: the cycle was NOT falsely closed by it"      "0" \
      "$(grep -c '"state":"interrupted"' "$G3D/ledger.jsonl" | tr -d ' ')"
check "G3: it ends at finished, which is TRUE — the PR was opened" "finished|1" \
      "$(field "$G3D/cycle.json" state)|$(grep -c 'gh pr create' "$G3/calls.log" | tr -d ' ')"
check "G3: and the log is bracketed closed exactly once" "1" \
      "$(grep -c 'INTAKE CYCLE END' "$G3D"/agent-*.log | tr -d ' ')"

echo "=== H. ANY session that opens is told, with no tail and no knowledge ===="
run_hook() { # $1 = project dir  $2 = PATH -> the hook's stdout
  printf '{"source":"startup","session_id":"s","cwd":"%s","hook_event_name":"SessionStart"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" INTAKE_REPO_LIST=/nonexistent PATH="$2" \
      /bin/bash "$HOOK" 2>> "$SANDBOX/hook-stderr.log"
}
# The two PATHs the other hook suites use: a full one, and one with neither jq
# nor python3 — this section must not depend on a JSON parser being installed.
BIN_BARE="$SANDBOX/bin-bare"; mkdir -p "$BIN_BARE"
for t in cat grep sed head tr cut wc git ls mkdir rm mv dirname basename date printf env sort find touch sleep pgrep kill mktemp; do
  bp="$(command -v "$t" 2>/dev/null)" || continue
  case "$bp" in /*) ln -sf "$bp" "$BIN_BARE/$t" ;; esac
done
[ -x "$BIN_BARE/grep" ] || { echo "ERROR: bare PATH has no working grep" >&2; exit 1; }

# H1. A REAL cycle, read WHILE IT RUNS. Not a synthesised record: the runner is
#     mid-draft and a session opens on the same repo.
H="$(mkcase H)"; set_issues "$H" 90 91 92
printf '6\n' > "$H/slow"
HPID="$(run_intake_bg "$H")"
HD="$(cp_dir "$H")"
await_state "$HD/cycle.json" drafting 30
for V in full bare; do
  case "$V" in full) HP="$PATH" ;; bare) HP="$BIN_BARE" ;; esac
  OUT="$(run_hook "$H/repo" "$HP")"
  check "H1 [$V]: the session is told a cycle is IN FLIGHT" "yes" \
        "$(contains "$OUT" "a drafting cycle is IN FLIGHT right now")"
  check "H1 [$V]: it names WHICH issue"                    "yes" \
        "$(contains "$OUT" "issue #90")"
  check "H1 [$V]: it says how many are done and queued"    "yes" \
        "$(contains "$OUT" "0 of 3 done, 3 still queued")"
  check "H1 [$V]: it names the repo"                       "yes" \
        "$(contains "$OUT" "fixture/repo")"
  check "H1 [$V]: it says where to watch, with the command" "yes" \
        "$(contains "$OUT" "tail -f $HD/agent-")"
  check "H1 [$V]: it states the hard stop — drafting only"  "yes" \
        "$(contains "$OUT" "never approves a plan, dispatches an item, merges a PR")"
  check "H1 [$V]: and that status is a CONVENIENCE, not the truth" "yes" \
        "$(contains "$OUT" "CONVENIENCE VIEW; the branches, the PRs and the ledger are the truth")"
  check "H1 [$V]: no 'did not finish' warning while it IS running" "no" \
        "$(contains "$OUT" "DID NOT FINISH")"
done
await_exit "$HPID" 60
await_state "$HD/cycle.json" finished 30

# H2. The same repo, after the cycle finished: one line, not a banner.
OUT="$(run_hook "$H/repo" "$PATH")"
check "H2: a finished cycle is one line, and says when"  "yes" \
      "$(contains "$OUT" "last cycle **finished**")"
check "H2: with the count"                               "yes" \
      "$(contains "$OUT" "3 of 3 issues")"
check "H2: and it is no longer announced as in flight"   "no" \
      "$(contains "$OUT" "IN FLIGHT right now")"

# H3. The SIGKILLed cycle from G2: the reader infers what the writer could not
#     record. This is the case that must never read as progress.
OUT="$(run_hook "$G2/repo" "$PATH")"
check "H3: a SIGKILLed cycle is reported as DID NOT FINISH" "yes" \
      "$(contains "$OUT" "the last cycle DID NOT FINISH")"
check "H3: it says the process is gone"                  "yes" \
      "$(contains "$OUT" "but the process is gone")"
check "H3: it does NOT claim the cycle is running"       "no" \
      "$(contains "$OUT" "IN FLIGHT right now")"
check "H3: nor that it finished"                         "no" \
      "$(contains "$OUT" "last cycle **finished**")"
check "H3: and it points at what IS authoritative"       "yes" \
      "$(contains "$OUT" "Reconcile against the branches and PRs")"

# H4. The SIGHUPed cycle from G: `interrupted` is terminal, so it is reported as
#     the last cycle rather than as a live one — and it says interrupted.
OUT="$(run_hook "$G/repo" "$PATH")"
check "H4: a fatally-signalled cycle reads as interrupted, not finished" "yes" \
      "$(contains "$OUT" "last cycle **interrupted**")"
check "H4: and never as finished" "no" \
      "$(contains "$OUT" "last cycle **finished**")"

# H5. The out-of-band value is rendered as a WARNING, never as progress.
H5="$(mkcase H5)"; set_issues "$H5" 90
RC="$(run_intake "$H5")"
H5D="$(cp_dir "$H5")"
INTAKE_STATUS_GIT="$REAL_GIT" /bin/bash -c '
set -u
. "$0"
intake_status_open "$1" "fixture/repo" "docs/epics" "$2"
intake_status_unknown "a record for #90 could not be written; these records may be stale"
' "$LIB" "$H5/repo" "$H5/.lock" >/dev/null 2>&1
OUT="$(run_hook "$H5/repo" "$PATH")"
check "H5: an untrustworthy record is announced as UNTRUSTWORTHY" "yes" \
      "$(contains "$OUT" "record is UNTRUSTWORTHY")"
check "H5: it quotes the out-of-band value verbatim"     "yes" \
      "$(contains "$OUT" "state: $UNTRUSTED")"
check "H5: it says do not read it as progress"           "yes" \
      "$(contains "$OUT" "Do not read it as progress")"
check "H5: it is NOT rendered as a running cycle"        "no" \
      "$(contains "$OUT" "IN FLIGHT right now")"
check "H5: nor as a finished one"                        "no" \
      "$(contains "$OUT" "last cycle **finished**")"

# H6. A repo that has never run a cycle says NOTHING. A repo that does not use
#     unattended intake must not grow a nag line.
H6="$(mkcase H6)"
OUT="$(run_hook "$H6/repo" "$PATH")"
check "H6: a repo with no cycle record says nothing about intake cycles" "no" \
      "$(contains "$OUT" "Unattended intake:")"
check "H6: and nothing about a cycle in flight"          "no" \
      "$(contains "$OUT" "IN FLIGHT")"
check "H6: the hook still exits 0"                       "0" \
      "$(run_hook "$H6/repo" "$PATH" >/dev/null; printf '%s' "$?")"
# ...and an unreadable or truncated record is silence, not an error.
mkdir -p "$(cp_dir "$H6")"
printf 'not json at all\n' > "$(cp_dir "$H6")/cycle.json"
OUT="$(run_hook "$H6/repo" "$PATH")"
check "H6: a garbage record produces NO output rather than noise" "no" \
      "$(contains "$OUT" "Unattended intake")"
check "H6: and still exits 0"                            "0" \
      "$(run_hook "$H6/repo" "$PATH" >/dev/null; printf '%s' "$?")"

# H7. Read from a linked WORKTREE of the same repo: the session is told about
#     the cycle even though the worktree has no status tree of its own.
H7="$(mkcase H7)"; set_issues "$H7" 90
RC="$(run_intake "$H7")"
git_q -C "$H7/repo" worktree add -q -b some/feature "$H7/wt" >/dev/null 2>&1
check "H7: precondition — the worktree has no status tree of its own" "no" \
      "$(yesno test -e "$H7/wt/docs/epics/$RESERVED")"
OUT="$(run_hook "$H7/wt" "$PATH")"
check "H7: a session in a WORKTREE is told about the cycle anyway" "yes" \
      "$(contains "$OUT" "last cycle **finished**")"

echo
echo "=== I. INERTNESS: it changes what the runner REPORTS, not what it DOES ==="
# The claim is testable rather than promised: run the same case twice, once with
# the telemetry library and once without it, and require every observable except
# the telemetry itself to be identical. With the library gone every entry point
# falls back to the no-ops the runner declares before loading it, which is
# precisely the pre-item-2 universe: ZERO control-plane writes.
normalise() { sed -E -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| //' \
                     -e "s|$1|<CASE>|g" -e "s|$SANDBOX|<SANDBOX>|g"; }
IA="$(mkcase I-with)";    set_issues "$IA" 90
IB="$(mkcase I-without)"; set_issues "$IB" 90
RC_A="$(run_intake "$IA")"
STATUS_LIB_UNDER_TEST="$SANDBOX/there-is-no-library-here.sh"
RC_B="$(run_intake "$IB")"
STATUS_LIB_UNDER_TEST="$LIB"
check "I: both runs succeeded"                          "0|0"  "$RC_A|$RC_B"
check "I: precondition — the library really was absent" "no" \
      "$(yesno test -e "$SANDBOX/there-is-no-library-here.sh")"
check "I: NEGATIVE CONTROL — with no library there is NO control plane" "no" \
      "$(yesno test -e "$IB/repo/docs/epics/$RESERVED")"
check "I: ...which is exactly the defect: zero status writes"  "no" \
      "$(yesno test -e "$(cp_dir "$IB")/cycle.json")"
check "I: ...and zero agent logs"                       "0" \
      "$(ls "$(cp_dir "$IB")"/agent-*.log 2>/dev/null | wc -l | tr -d ' ')"
check "I: while the shipped runner writes one"          "yes" \
      "$(yesno test -e "$(cp_dir "$IA")/cycle.json")"
# THE DECLARED DIFFERENCE, stated before it is subtracted: the library asks the
# repo where its canonical root is, once per repo. That is a read-only local
# `git rev-parse`; it makes no network call, mutates nothing, and no branch is
# taken on its answer. Everything else must be identical, and the assertion
# below pins the added calls to exactly that one shape.
check "I: the ONLY calls the library adds are canonical-root lookups" "yes" \
      "$(yesno test -z "$(diff <(normalise "$IB" < "$IB/calls.log") \
                               <(normalise "$IA" < "$IA/calls.log") \
                            | grep '^>' | grep -v 'rev-parse --path-format=absolute --git-common-dir')")"
check "I: it adds no gh call at all"                    "0" \
      "$(( $(grep -c '^gh ' "$IA/calls.log") - $(grep -c '^gh ' "$IB/calls.log") ))"
check "I: nor a single drafter invocation"              "0" \
      "$(( $(grep -c '^claude ' "$IA/calls.log") - $(grep -c '^claude ' "$IB/calls.log") ))"
check "I: the call stream is BYTE-IDENTICAL once those are subtracted" \
      "$(normalise "$IB" < "$IB/calls.log" | grep -v 'rev-parse --path-format' | cksum)" \
      "$(normalise "$IA" < "$IA/calls.log" | grep -v 'rev-parse --path-format' | cksum)"
check "I: stdout differs by the same one declared line, and nothing else" \
      "$(normalise "$IB" < "$IB/stdout.log" | cksum)" \
      "$(normalise "$IA" < "$IA/stdout.log" | grep -v '^control plane: ' | cksum)"
check "I: stderr is identical (both empty)"             \
      "$(cksum < "$IB/stderr.log")" "$(cksum < "$IA/stderr.log")"
check "I: the issue comments a human receives are identical" \
      "$(normalise "$IB" < "$IB/comment-bodies.log" | cksum)" \
      "$(normalise "$IA" < "$IA/comment-bodies.log" | cksum)"
check "I: the drafted plan is identical" \
      "$(cksum < "$IB/removed-worktree/docs/epics/proposed-90-fixture-issue-90/plan.md" 2>/dev/null)" \
      "$(cksum < "$IA/removed-worktree/docs/epics/proposed-90-fixture-issue-90/plan.md" 2>/dev/null)"
# The flat log differs by EXACTLY ONE LINE per repo, and it is declared: the line
# that names where the records are. Anything else appearing here is a regression.
check "I: the flat log differs by exactly one line"     "1" \
      "$(( $(wc -l < "$IA/intake.log") - $(wc -l < "$IB/intake.log") ))"
check "I: and that line is the control-plane path, nothing else" "1" \
      "$(diff <(normalise "$IB" < "$IB/intake.log") <(normalise "$IA" < "$IA/intake.log") \
          | grep -c '^> control plane: ' | tr -d ' ')"
check "I: no OTHER line was added, changed or removed"  "1" \
      "$(diff <(normalise "$IB" < "$IB/intake.log") <(normalise "$IA" < "$IA/intake.log") \
          | grep -cE '^[<>]' | tr -d ' ')"
# And the structural version of the same claim: every condition in the runner
# that reads a telemetry variable guards a LOG line. Not one guards a decision.
check "I: every condition reading a telemetry variable guards a log line" "0" \
      "$(grep -nE '(if|while|until|\[\[?)[^#]*INTAKE_STATUS_' "$SCRIPT" \
          | grep -v 'INTAKE_STATUS_LIB' | grep -vc 'log "control plane' | tr -d ' ')"
check "I: and no control-flow keyword is ever reached through one" "0" \
      "$(grep -E 'INTAKE_STATUS_[A-Z_]+' "$SCRIPT" | grep -v '^[[:space:]]*#' \
          | grep -cE '(continue|exit|return|break|die) ' | tr -d ' ')"

echo
echo "=== J. NEGATIVE CONTROL: the PRE-ITEM-2 hook says nothing about a cycle ="
# Reconstruct the SessionStart hook as it stood before this item by deleting
# exactly the lines the item added. Brittle ON PURPOSE: if the block moves, the
# line count stops matching and this section STOPS rather than proving nothing.
PRE_HOOK="$SANDBOX/session-start-context.pre-item-2.sh"; sandboxed "$PRE_HOOK"
J_S="$(grep -nF -m1 '# Unattended intake: is a DRAFTING CYCLE RUNNING RIGHT NOW? (epic 11 item 2)' "$HOOK" | cut -d: -f1)"
J_E="$(grep -nF -m1 '# Unattended intake config for THIS repo' "$HOOK" | cut -d: -f1)"
for J_V in "$J_S" "$J_E"; do
  case "$J_V" in ''|*[!0-9]*)
    echo "ERROR: an anchor for the pre-item-2 reconstruction did not match." >&2
    echo "       The item-2 block moved, so section J would prove nothing." >&2
    exit 1 ;;
  esac
done
sed -e "${J_S},$((J_E - 1))d" "$HOOK" > "$PRE_HOOK"
chmod +x "$PRE_HOOK"
J_REMOVED=$(( $(wc -l < "$HOOK") - $(wc -l < "$PRE_HOOK") ))
check "J: the reconstruction removes exactly the item's 143 added lines" "143" "$J_REMOVED"
if [ "$J_REMOVED" -ne 143 ]; then
  echo "ERROR: the pre-item-2 reconstruction is $J_REMOVED lines, not 143. Either" >&2
  echo "       the item grew or the anchors rotted; either way J is not a proof." >&2
  exit 1
fi
cmp -s "$HOOK" "$PRE_HOOK" && { echo "ERROR: the reconstruction is identical to the hook" >&2; exit 1; }
/bin/bash -n "$PRE_HOOK" || { echo "ERROR: the pre-item-2 reconstruction does not parse" >&2; exit 1; }
check "J: and it carries no trace of the cycle section" "0" \
      "$(grep -c 'intake_cycle_section' "$PRE_HOOK" | tr -d ' ')"
check "J: while the shipped hook does"                  "2" \
      "$(grep -c 'intake_cycle_section' "$HOOK" | tr -d ' ')"

# A REAL cycle, in flight, read by both hooks. The shipped one announces it; the
# pre-item-2 one is silent — which is why the passing case is a proof and not a
# tautology, and is also exactly the measured defect: zero references.
J="$(mkcase J)"; set_issues "$J" 90 91
printf '6\n' > "$J/slow"
JPID="$(run_intake_bg "$J")"
JD="$(cp_dir "$J")"
await_state "$JD/cycle.json" drafting 30
J_NEW="$(run_hook "$J/repo" "$PATH")"
J_OLD="$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$J/repo" INTAKE_REPO_LIST=/nonexistent \
           /bin/bash "$PRE_HOOK" 2>>"$SANDBOX/hook-stderr.log")"
check "J: the shipped hook announces the cycle in flight" "yes" \
      "$(contains "$J_NEW" "IN FLIGHT right now")"
check "J: NEGATIVE CONTROL — the pre-item-2 hook says nothing at all" "no" \
      "$(contains "$J_OLD" "IN FLIGHT")"
check "J: it does not mention the cycle, the issue, or the queue" "no|no|no" \
      "$(contains "$J_OLD" "drafting cycle")|$(contains "$J_OLD" "issue #90")|$(contains "$J_OLD" "still queued")"
check "J: and it has no reference to the control plane at all" "no" \
      "$(contains "$J_OLD" "$RESERVED")"
# Everything the pre-item-2 hook DID say, it still says: the section is additive.
J_LOST=0
while IFS= read -r JL; do
  [ -n "$JL" ] || continue
  case "$J_NEW" in *"$JL"*) ;; *) J_LOST=$((J_LOST + 1)) ;; esac
done <<J_OLD_LINES
$J_OLD
J_OLD_LINES
check "J: every pre-item-2 line survives verbatim — the section is ADDITIVE" "0" "$J_LOST"
await_exit "$JPID" 60

echo
echo "=== K. the hard stops: this item reports, it never acts ================="
# Item 2 owns telemetry. If a line of it ever approved a plan, dispatched an
# item, merged a PR or closed an issue, that would be a defect and not a feature
# — so it is asserted here rather than promised in a comment.
check "K: the library never calls gh"                   "0" \
      "$(grep -v '^[[:space:]]*#' "$LIB" | grep -cE '(^|[^a-z_])gh ' | tr -d ' ')"
check "K: nor merges anything"                          "0" \
      "$(grep -v '^[[:space:]]*#' "$LIB" | grep -c 'pr merge' | tr -d ' ')"
check "K: nor closes an issue"                          "0" \
      "$(grep -v '^[[:space:]]*#' "$LIB" | grep -cE 'issue (close|edit)' | tr -d ' ')"
check "K: nor writes anything outside the tree it bound to" "yes" \
      "$(yesno grep -q 'not a direct child of the bound control plane' "$LIB")"
check "K: the reader in the hook makes no network call"  "0" \
      "$(sed -n '/^intake_cycle_section()/,/^intake_cycle_section$/p' "$HOOK" \
          | grep -cE '(^|[^a-z_])(gh|curl|nc|wget) ' | tr -d ' ')"
# TWO git calls, and the second is a fallback that runs only when the first
# fails — the same pair every control-plane hook uses. Everything else in the
# section is parameter expansion, one glob, a capped read and the kill builtin,
# so there is nothing here to time out.
check "K: and forks nothing but the two git lookups for the root" "2" \
      "$(sed -n '/^intake_cycle_section()/,/^intake_cycle_section$/p' "$HOOK" \
          | grep -c 'git rev-parse' | tr -d ' ')"
check "K: liveness is decided by a BUILTIN, not by a fork"  "1" \
      "$(sed -n '/^intake_cycle_section()/,/^intake_cycle_section$/p' "$HOOK" \
          | grep -c 'kill -0' | tr -d ' ')"
check "K: it never writes — a reader that mutates is not a reader" "0" \
      "$(sed -n '/^intake_cycle_section()/,/^intake_cycle_section$/p' "$HOOK" \
          | grep -cE '(>>?[[:space:]]*"?\$IY_|rm |mkdir |mv |touch )' | tr -d ' ')"
# The whole cycle, end to end, never touched the live branch or merged anything.
check "K: across every run above, nothing was ever merged" "0" \
      "$(cat "$SANDBOX"/*/calls.log 2>/dev/null | grep -c 'gh pr merge' | tr -d ' ')"
check "K: and no branch was ever pushed to main"        "0" \
      "$(cat "$SANDBOX"/*/calls.log 2>/dev/null | grep -cE 'git push .* (origin )?main( |$)' | tr -d ' ')"

echo
echo "=== the host repo is untouched (GH #15) ================================"
HOST_AFTER="$(host_fingerprint)"
check "the host repo's HEAD and porcelain status are unchanged" "$HOST_BEFORE" "$HOST_AFTER"

echo
echo "=== stderr from the runner and the hook (empty unless one errored) ======"
# `Terminated: 15` is this suite killing its own runs in sections G and G3 and
# is filtered out; anything else here is a real error and is shown.
for L in "$SANDBOX"/*/stderr.log "$SANDBOX/hook-stderr.log"; do
  [ -s "$L" ] || continue
  LEFT="$(grep -vE '^(Terminated|Hangup|Killed)' "$L" 2>/dev/null | grep -v '^$' || true)"
  [ -n "$LEFT" ] || continue
  echo "--- $L"; printf '%s\n' "$LEFT" | head -10
done

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
