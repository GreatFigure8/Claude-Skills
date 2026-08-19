#!/usr/bin/env bash
# Fixture harness for the EPICS-AWAITING-DISPATCH line in the SessionStart hook:
#   ../session-start-context.sh
#
# The rule under test (GH #11, epic 04 item 2): a fresh session must be able to
# see which epics are FILED BUT NOT STARTED, and in what order they should be
# picked up. The line is emitted only when such epics exist:
#
#   - 2 epics awaiting dispatch: 05-<slug>, 06-<slug> — dispatch the lowest number first.
#
# "Awaiting dispatch" = Status is neither `closed` nor `in flight …`; order is
# FOLDER NUMBER (Phase 1's implementation sequence), never mtime.
#
# Everything here is local filesystem work: the sandboxes have no GitHub remote,
# so the tracker/backlog section never runs and every assertion below is about
# the epic-queue section alone. A PATH stub proves no network tool is invoked.
#
# Runs the REPO copy of the hook against synthetic hook-input JSON in a throwaway
# sandbox: every git repo and epic folder lives under a fresh mktemp -d removed
# on exit. Never installs anything, never touches a real repo, ~/.claude, or any
# real epic folder.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/session-start-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# Variants, because the line must not depend on a JSON parser being installed:
#   full  — normal PATH (jq present)
#   bare  — neither jq nor python3 (head/grep/sed/tr/sort/cut only)

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$HOOKS_DIR/session-start-context.sh"
[ -f "$HOOK" ] || { echo "ERROR: not found: $HOOK" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/session-start-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0

git_q() { git -c user.email=fixture@example.com -c user.name=fixture \
              -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }

# Every path this harness writes to, inits, commits in, or points the hook at
# MUST live under $SANDBOX. Without this guard a single mistyped or clobbered
# variable makes `git -C "" add -A` (git treats an empty -C as "stay here")
# commit the developer's own checkout — which is exactly what happened while
# this harness was being written. Abort loudly instead.
sandboxed() { # $1 = path that is about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

check() { # $1 label  $2 expected  $3 actual  $4 variant
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then VERDICT="PASS"; else VERDICT="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-56s %-5s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$4" "$2" "$3" "$VERDICT"
}

# A PATH with no jq and no python3 — and no network tool at all. gh/curl/nc are
# deliberately absent, so anything reaching for the network fails loudly instead
# of silently succeeding on the developer's machine.
BIN_BARE="$SANDBOX/bin-bare"       # no jq, no python3, no gh/curl/nc
BIN_MIN="$SANDBOX/bin-min"         # bare minus grep/sed/head/tr, and
BIN_NOSORT="$SANDBOX/bin-nosort"   # bare minus sort: the section is builtin
mkdir -p "$BIN_BARE" "$BIN_MIN" "$BIN_NOSORT"   # -only, so neither may matter.
for t in cat grep sed head tr cut wc git ls mkdir rm mv dirname basename date printf env sort find touch sleep pgrep kill mktemp; do
  p="$(command -v "$t" 2>/dev/null)" || continue
  case "$p" in /*) ;; *) continue ;; esac    # builtins/aliases: a bare name here
  ln -sf "$p" "$BIN_BARE/$t"                 # would make a DANGLING symlink and
  case "$t" in grep|sed|head|tr) ;; *) ln -sf "$p" "$BIN_MIN/$t" ;; esac
  case "$t" in sort) ;; *) ln -sf "$p" "$BIN_NOSORT/$t" ;; esac
done
[ -x "$BIN_BARE/grep" ] || { echo "ERROR: bare PATH has no working grep" >&2; exit 1; }
[ -e "$BIN_MIN/grep" ] && { echo "ERROR: min PATH still has grep" >&2; exit 1; }
[ -e "$BIN_NOSORT/sort" ] && { echo "ERROR: nosort PATH still has sort" >&2; exit 1; }
PATH_FULL="$PATH"
path_for() {
  case "$1" in
    bare)   printf '%s' "$BIN_BARE" ;;
    min)    printf '%s' "$BIN_MIN" ;;
    nosort) printf '%s' "$BIN_NOSORT" ;;
    *)      printf '%s' "$PATH_FULL" ;;
  esac
}

plan_file() { # $1 = epic dir, $2 = Status value ("" = no Status line at all)
  sandboxed "$1"
  mkdir -p "$1"
  if [ -n "$2" ]; then
    printf '# Epic: fixture\n\n**Status:** %s\n**Source:** GH #0\n\n## Outcome\nfixture\n' "$2" > "$1/plan.md"
  else
    printf '# Epic: fixture with no status header\n\nnothing parseable here\n' > "$1/plan.md"
  fi
}

mkrepo() { # $1 = repo dir (empty git repo, NO github remote)
  sandboxed "$1"
  rm -rf "$1"; mkdir -p "$1"
  git_q -C "$1" init -q
  git_q -C "$1" checkout -q -b main 2>/dev/null || git_q -C "$1" branch -q -m main
}

commit_all() {
  sandboxed "$1"
  git_q -C "$1" add -A >/dev/null 2>&1
  git_q -C "$1" commit -qm fixture >/dev/null 2>&1
}

run_hook() { # $1 project dir  $2 variant -> full stdout
  sandboxed "$1"
  printf '{"source":"startup","session_id":"sess-1","cwd":"%s","hook_event_name":"SessionStart"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$2")" /bin/bash "$HOOK" 2>> "$SANDBOX/stderr.log"
}

queue_line() { # $1 project dir  $2 variant -> the awaiting-dispatch line, or <none>
  L="$(run_hook "$1" "$2" | grep 'awaiting dispatch' || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}

echo "sandbox: $SANDBOX"
echo "hook:    $HOOK"
echo "bash:    $(/bin/bash --version | head -1)"
echo "git:     $(git --version)"
echo

# ============================================================================
echo "=== A. the queued epics are named, in FOLDER-NUMBER order =============="
echo "    (03 closed, 04 in flight, 05 + 06 approved; 06 touched last so mtime"
echo "     order and folder order disagree)"
for V in full bare; do
  R="$SANDBOX/A-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/03-done-epic"    "closed"
  plan_file "$R/docs/epics/04-running-epic" "in flight (items 1-2 of 2, parallel)"
  plan_file "$R/docs/epics/05-next-epic"    "approved"
  plan_file "$R/docs/epics/06-later-epic"   "approved"
  commit_all "$R"
  sleep 1; touch "$R/docs/epics/06-later-epic/plan.md"   # newest by mtime
  NEWEST="$(ls -t "$R"/docs/epics/*/plan.md | head -1)"
  check "precondition: newest by mtime IS 06" "docs/epics/06-later-epic/plan.md" \
        "${NEWEST#$R/}" "$V"
  check "names exactly 05 then 06" \
        "- 2 epics awaiting dispatch: 05-next-epic, 06-later-epic — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
  check "the closed epic is not named" "0" \
        "$(queue_line "$R" "$V" | grep -c '03-done-epic' | tr -d ' ')" "$V"
  check "the in-flight epic is not named" "0" \
        "$(queue_line "$R" "$V" | grep -c '04-running-epic' | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== B. nothing awaiting dispatch -> NO line, rest byte-identical ======="
echo "    (the whole injection is captured twice — once with nothing queued and"
echo "     once with one epic queued — from the SAME file set, SAME newest plan"
echo "     and SAME single commit, so the only admissible difference is the"
echo "     queue block itself: strip it back out and the two must be identical)"
norm_sha() { sed -e 's/^[0-9a-f]\{7,\} fixture$/<sha> fixture/' "$1"; }
for V in full bare; do
  R="$SANDBOX/B-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/03-done-epic"    "closed"
  sleep 1                                        # 1s mtime granularity: 04 is newest
  plan_file "$R/docs/epics/04-running-epic" "in flight (item 1 of 2)"
  commit_all "$R"
  run_hook "$R" "$V" > "$SANDBOX/B-$V.none"
  check "no awaiting-dispatch line at all" "<none>" "$(queue_line "$R" "$V")" "$V"
  check "no stray 'awaiting dispatch' wording anywhere" "0" \
        "$(grep -c 'awaiting dispatch' "$SANDBOX/B-$V.none" | tr -d ' ')" "$V"
  check "every other section still emitted" "1" \
        "$(grep -c '^### Git state' "$SANDBOX/B-$V.none" | tr -d ' ')" "$V"

  # Flip the in-flight epic to approved IN PLACE and amend, so file set, newest
  # plan, commit count and clean-tree status are all unchanged.
  plan_file "$R/docs/epics/04-running-epic" "approved"
  git_q -C "$R" add -A >/dev/null 2>&1
  git_q -C "$R" commit -q --amend -m fixture >/dev/null 2>&1
  run_hook "$R" "$V" > "$SANDBOX/B-$V.one"
  check "one queued epic -> singular phrasing" \
        "- 1 epic awaiting dispatch: 04-running-epic." "$(queue_line "$R" "$V")" "$V"

  # Strip the queue block (its line, then the blank line it added) back out.
  grep -v 'awaiting dispatch' "$SANDBOX/B-$V.one" | sed -e '${/^$/d;}' > "$SANDBOX/B-$V.stripped"
  norm_sha "$SANDBOX/B-$V.none"     > "$SANDBOX/B-$V.none.norm"
  norm_sha "$SANDBOX/B-$V.stripped" > "$SANDBOX/B-$V.stripped.norm"
  check "injection is byte-identical apart from the queue block" "" \
        "$(diff "$SANDBOX/B-$V.none.norm" "$SANDBOX/B-$V.stripped.norm" | head -20)" "$V"
done

echo
echo "=== C. no docs/epics directory at all =================================="
for V in full bare; do
  R="$SANDBOX/C-$V"; mkrepo "$R"
  printf 'hello\n' > "$R/README.md"; commit_all "$R"
  OUT="$(run_hook "$R" "$V")"; RC=$?
  check "exit status 0" "0" "$RC" "$V"
  check "no awaiting-dispatch line" "<none>" "$(queue_line "$R" "$V")" "$V"
  check "the rest of the injection still emitted" "1" \
        "$(printf '%s' "$OUT" | grep -c '^## Session grounding' | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== D. outside a git repo: silent, exit 0 =============================="
for V in full bare; do
  R="$SANDBOX/D-$V"; sandboxed "$R"; rm -rf "$R"; mkdir -p "$R/docs/epics"
  plan_file "$R/docs/epics/05-next-epic" "approved"
  # A directory that is not inside any git repo (the sandbox itself is not one).
  OUT="$(run_hook "$R" "$V")"; RC=$?
  check "exit status 0" "0" "$RC" "$V"
  check "no output whatsoever" "" "$OUT" "$V"
done

# ============================================================================
echo
echo "=== E. malformed / Status-less plans do not break the injection ========"
for V in full bare; do
  R="$SANDBOX/E-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-no-status" ""                  # no Status line
  mkdir -p "$R/docs/epics/06-binary-ish"
  printf '\001\002\003 not text at all\n' > "$R/docs/epics/06-binary-ish/plan.md"
  mkdir -p "$R/docs/epics/07-empty"; : > "$R/docs/epics/07-empty/plan.md"
  mkdir -p "$R/docs/epics/08-no-plan-file"                   # folder with no plan.md
  commit_all "$R"
  OUT="$(run_hook "$R" "$V")"; RC=$?
  check "exit status 0" "0" "$RC" "$V"
  check "unparseable Status counts as awaiting dispatch" \
        "- 3 epics awaiting dispatch: 05-no-status, 06-binary-ish, 07-empty — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
  check "a folder with no plan.md is not named" "0" \
        "$(queue_line "$R" "$V" | grep -c '08-no-plan-file' | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== F. the documented Status vocabulary, and variations on it =========="
# references/plan-template.md: planning | approved | in flight (item N of M) | closed
for V in full bare; do
  for S in "approved:yes" "planning:yes" "Approved:yes" "APPROVED:yes" \
           "closed:no" "Closed:no" "CLOSED:no" "closed (superseded):no" \
           "in flight (item 1 of 3):no" "in flight (items 1-2 of 2, parallel):no" \
           "In Flight (item 2 of 4):no" "in-flight:no" "in flight:no"; do
    STATUS="${S%:*}"; WANT="${S##*:}"
    R="$SANDBOX/F-$V"; mkrepo "$R"
    plan_file "$R/docs/epics/05-subject" "$STATUS"
    commit_all "$R"
    GOT="$(queue_line "$R" "$V")"
    case "$GOT" in *05-subject*) LISTED="yes" ;; *) LISTED="no" ;; esac
    check "Status [$STATUS] listed?" "$WANT" "$LISTED" "$V"
  done
  # CRLF line endings must not defeat the match
  R="$SANDBOX/Fcrlf-$V"; mkrepo "$R"; mkdir -p "$R/docs/epics/05-crlf"
  printf '# Epic: fixture\r\n\r\n**Status:** closed\r\n\r\n' > "$R/docs/epics/05-crlf/plan.md"
  commit_all "$R"
  check "CRLF closed plan is still closed" "<none>" "$(queue_line "$R" "$V")" "$V"
done

# ============================================================================
echo
echo "=== G. ordering and the cap ============================================"
for V in full bare; do
  R="$SANDBOX/G-$V"; mkrepo "$R"
  for N in 09 08 07 06 05 04 12 10; do
    plan_file "$R/docs/epics/$N-epic$N" "approved"
    sleep 0                                  # creation order is deliberately reversed
  done
  plan_file "$R/docs/epics/unnumbered-epic" "approved"
  commit_all "$R"
  check "lowest number first, capped at 5, +N more, unnumbered last" \
        "- 9 epics awaiting dispatch: 04-epic04, 05-epic05, 06-epic06, 07-epic07, 08-epic08 (+4 more) — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
  # 10 must sort after 09, not lexically between 01 and 02
  R="$SANDBOX/G2-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/9-nine" "approved"
  plan_file "$R/docs/epics/10-ten" "approved"
  commit_all "$R"
  check "9 before 10 (numeric, not lexical)" \
        "- 2 epics awaiting dispatch: 9-nine, 10-ten — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
done

# ============================================================================
echo
echo "=== H. no network work: no tracker call, no network tool on PATH ======="
# The bare PATH has no gh/curl/nc at all, and the sandbox repo has no remote.
# The line must still be produced, and nothing may be written to stderr.
: > "$SANDBOX/stderr.log"
R="$SANDBOX/H"; mkrepo "$R"
plan_file "$R/docs/epics/05-next-epic" "approved"
plan_file "$R/docs/epics/06-later-epic" "approved"
commit_all "$R"
T0="$(date +%s)"
check "queue line emitted with no network tool available" \
      "- 2 epics awaiting dispatch: 05-next-epic, 06-later-epic — dispatch the lowest number first." \
      "$(queue_line "$R" bare)" "bare"
T1="$(date +%s)"
check "run took under 2s (no tracker wait)" "yes" \
      "$([ $((T1 - T0)) -lt 2 ] && echo yes || echo no)" "bare"
check "nothing on stderr" "" "$(cat "$SANDBOX/stderr.log")" "bare"

# ============================================================================
echo
echo "=== I. a real-shaped repo: worktree checkout sees the same queue ======="
R="$SANDBOX/I"; mkrepo "$R"
plan_file "$R/docs/epics/04-running-epic" "in flight (item 1 of 2)"
plan_file "$R/docs/epics/05-next-epic" "approved"
commit_all "$R"
git_q -C "$R" worktree add -q -b feat/item "$SANDBOX/I-wt" main >/dev/null 2>&1
check "same line from the linked worktree" \
      "- 1 epic awaiting dispatch: 05-next-epic." "$(queue_line "$SANDBOX/I-wt" full)" "full"

echo
echo "=== J. no external tool is used at all ================================="
echo "    (parse and ordering are both shell builtins, so stripping grep, sed,"
echo "     head, tr and even sort out of PATH changes nothing about the line)"
R="$SANDBOX/J"; mkrepo "$R"
plan_file "$R/docs/epics/03-done-epic"    "closed"
plan_file "$R/docs/epics/04-running-epic" "in flight (item 1 of 2)"
plan_file "$R/docs/epics/05-next-epic"    "approved"
plan_file "$R/docs/epics/06-later-epic"   "approved"
commit_all "$R"
EXPECT_J="- 2 epics awaiting dispatch: 05-next-epic, 06-later-epic — dispatch the lowest number first."
check "bare PATH (no jq/python3)" "$EXPECT_J" "$(queue_line "$R" bare)" "bare"
check "no grep/sed/head/tr: identical line" "$EXPECT_J" "$(queue_line "$R" min)" "min"
check "no sort either: identical line" "$EXPECT_J" "$(queue_line "$R" nosort)" "nosort"
check "no sort: exit status still 0" "0" \
      "$(run_hook "$R" nosort >/dev/null 2>&1; echo $?)" "nosort"
check "no sort: the rest of the injection survives" "1" \
      "$(run_hook "$R" nosort 2>/dev/null | grep -c '^### Git state' | tr -d ' ')" "nosort"

echo
echo "=== hook stderr (empty unless the hook errored on its own) ============="
[ -s "$SANDBOX/stderr.log" ] && head -20 "$SANDBOX/stderr.log"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
