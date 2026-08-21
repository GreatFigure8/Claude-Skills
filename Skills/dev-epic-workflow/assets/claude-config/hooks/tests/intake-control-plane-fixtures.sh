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
