#!/usr/bin/env bash
# Fixture harness for the EPIC-QUEUE lines in the SessionStart hook:
#   ../session-start-context.sh
#
# The original rule (GH #11, epic 04 item 2): a fresh session must be able to
# see which epics are FILED BUT NOT STARTED, and in what order they should be
# picked up. Order is FOLDER NUMBER (Phase 1's implementation sequence), never
# mtime, and a line is emitted only when it has something to name.
#
# The rule added here (GH #16, epic 05 item 1): that queue means two different
# things and they are not interchangeable, so it is TWO lines:
#
#   - 2 epics awaiting dispatch: 05-<slug>, 06-<slug> — dispatch the lowest number first.
#   - 1 epic awaiting approval: 07-<slug> — approve before dispatch; `planning` is never dispatchable.
#
#   Status `approved`                 -> awaiting dispatch
#   Status `planning`                 -> awaiting approval
#   Status unparseable / absent       -> awaiting approval (listed, never hidden;
#                                        the bucket whose error is harmless)
#   Status `closed` / `in flight …`   -> neither line
#
# Unattended intake (references/issue-intake.md) opens PRs carrying plans at
# `planning`, so `planning` epics now arrive without a human having read them.
# Calling those "awaiting dispatch" is the exact mistake the approval gate
# exists to prevent, which is why case L re-runs the new cases against the
# pre-split (single-queue) implementation and requires them to FAIL.
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
UNSPLIT_HOOK="$SANDBOX/session-start-context.unsplit.sh"
sandboxed "$UNSPLIT_HOOK"
sed -e 's/EQ_QUEUE="approval"/EQ_QUEUE="dispatch"/' "$HOOK" > "$UNSPLIT_HOOK"
chmod +x "$UNSPLIT_HOOK"
cmp -s "$HOOK" "$UNSPLIT_HOOK" && {
  echo "ERROR: the unsplit mutant is identical to the hook — the bucket assignment" >&2
  echo "       moved, so cases B and L would be proving nothing. Fix the sed above." >&2
  exit 1
}
grep -q 'EQ_QUEUE="approval"' "$UNSPLIT_HOOK" && {
  echo "ERROR: the unsplit mutant still has an approval bucket" >&2; exit 1
}
/bin/bash -n "$UNSPLIT_HOOK" || { echo "ERROR: unsplit mutant does not parse" >&2; exit 1; }

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

HOOK_UNDER_TEST="$HOOK"          # cases B and L swap this for the pre-split hook

run_hook() { # $1 project dir  $2 variant -> full stdout
  sandboxed "$1"
  printf '{"source":"startup","session_id":"sess-1","cwd":"%s","hook_event_name":"SessionStart"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$2")" /bin/bash "$HOOK_UNDER_TEST" 2>> "$SANDBOX/stderr.log"
}

queue_line() { # $1 project dir  $2 variant -> the awaiting-DISPATCH line, or <none>
  L="$(run_hook "$1" "$2" | grep 'awaiting dispatch' || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}

approval_line() { # $1 project dir  $2 variant -> the awaiting-APPROVAL line, or <none>
  L="$(run_hook "$1" "$2" | grep 'awaiting approval' || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}

queue_block() { # $1 project dir  $2 variant -> both queue lines, in emitted order
  L="$(run_hook "$1" "$2" | grep -E 'awaiting (dispatch|approval)' || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}

# Which bucket an epic folder landed in, as one word — the whole contract in a
# single comparable token.
bucket_of() { # $1 project dir  $2 variant  $3 epic folder name
  B="$(run_hook "$1" "$2" | grep -E 'awaiting (dispatch|approval)' | grep -F "$3" || true)"
  case "$B" in
    *"awaiting dispatch"*"awaiting approval"*) printf 'BOTH' ;;
    *"awaiting dispatch"*) printf 'dispatch' ;;
    *"awaiting approval"*) printf 'approval' ;;
    *) printf 'none' ;;
  esac
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
echo "=== B. nothing queued -> NO lines, rest byte-identical ================="
echo "    (the whole injection is captured twice — once with nothing queued and"
echo "     once with one epic queued — from the SAME file set, SAME newest plan"
echo "     and SAME single commit, so the only admissible difference is the"
echo "     queue block itself: strip it back out and the two must be identical."
echo "     Then the empty case is diffed against the PRE-SPLIT hook, which is"
echo "     the epic-05 requirement: with both queues empty the injection must be"
echo "     byte-identical to what epic 04 item 2 shipped — not merely similar)"
norm_sha() { sed -e 's/^[0-9a-f]\{7,\} fixture$/<sha> fixture/' "$1"; }
for V in full bare; do
  R="$SANDBOX/B-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/03-done-epic"    "closed"
  sleep 1                                        # 1s mtime granularity: 04 is newest
  plan_file "$R/docs/epics/04-running-epic" "in flight (item 1 of 2)"
  commit_all "$R"
  run_hook "$R" "$V" > "$SANDBOX/B-$V.none"
  check "neither queue line at all" "<none>" "$(queue_block "$R" "$V")" "$V"
  check "no stray 'awaiting …' wording anywhere" "0" \
        "$(grep -cE 'awaiting (dispatch|approval)' "$SANDBOX/B-$V.none" | tr -d ' ')" "$V"
  check "every other section still emitted" "1" \
        "$(grep -c '^### Git state' "$SANDBOX/B-$V.none" | tr -d ' ')" "$V"

  # THE byte-identity proof: same repo, same run conditions, pre-split hook.
  # Nothing is normalised away here — an empty diff is an empty diff.
  HOOK_UNDER_TEST="$UNSPLIT_HOOK"
  run_hook "$R" "$V" > "$SANDBOX/B-$V.presplit"
  HOOK_UNDER_TEST="$HOOK"
  check "both queues empty: byte-identical to the PRE-SPLIT hook" "" \
        "$(diff "$SANDBOX/B-$V.presplit" "$SANDBOX/B-$V.none" | head -20)" "$V"

  # Flip the in-flight epic to approved IN PLACE and amend, so file set, newest
  # plan, commit count and clean-tree status are all unchanged.
  plan_file "$R/docs/epics/04-running-epic" "approved"
  git_q -C "$R" add -A >/dev/null 2>&1
  git_q -C "$R" commit -q --amend -m fixture >/dev/null 2>&1
  run_hook "$R" "$V" > "$SANDBOX/B-$V.one"
  check "one queued epic -> singular phrasing" \
        "- 1 epic awaiting dispatch: 04-running-epic." "$(queue_line "$R" "$V")" "$V"

  # Strip the queue block (its lines, then the blank line it added) back out.
  grep -vE 'awaiting (dispatch|approval)' "$SANDBOX/B-$V.one" | sed -e '${/^$/d;}' > "$SANDBOX/B-$V.stripped"
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
  check "neither queue line" "<none>" "$(queue_block "$R" "$V")" "$V"
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
  # Epic 04's decision — list it, never hide it — is unchanged. Epic 05 only
  # decides WHICH queue it lands in: approval, the bucket whose error is
  # harmless. An unreadable header must never make a plan look dispatchable.
  check "unparseable Status counts as awaiting APPROVAL" \
        "- 3 epics awaiting approval: 05-no-status, 06-binary-ish, 07-empty — approve before dispatch; \`planning\` is never dispatchable." \
        "$(approval_line "$R" "$V")" "$V"
  check "and never as awaiting dispatch" "<none>" "$(queue_line "$R" "$V")" "$V"
  check "a folder with no plan.md is not named" "0" \
        "$(queue_block "$R" "$V" | grep -c '08-no-plan-file' | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== F. the documented Status vocabulary, and variations on it =========="
# references/plan-template.md: planning | approved | in flight (item N of M) | closed
# Each expectation is now the BUCKET, not a yes/no: dispatch | approval | none.
for V in full bare; do
  for S in "approved:dispatch" "Approved:dispatch" "APPROVED:dispatch" \
           "approved (rev 2):dispatch" \
           "planning:approval" "Planning:approval" "PLANNING:approval" \
           "planning (draft from #16):approval" \
           "closed:none" "Closed:none" "CLOSED:none" "closed (superseded):none" \
           "in flight (item 1 of 3):none" "in flight (items 1-2 of 2, parallel):none" \
           "In Flight (item 2 of 4):none" "in-flight:none" "in flight:none"; do
    STATUS="${S%:*}"; WANT="${S##*:}"
    R="$SANDBOX/F-$V"; mkrepo "$R"
    plan_file "$R/docs/epics/05-subject" "$STATUS"
    commit_all "$R"
    check "Status [$STATUS] -> which queue?" "$WANT" \
          "$(bucket_of "$R" "$V" 05-subject)" "$V"
  done
  # CRLF line endings must not defeat the match
  R="$SANDBOX/Fcrlf-$V"; mkrepo "$R"; mkdir -p "$R/docs/epics/05-crlf"
  printf '# Epic: fixture\r\n\r\n**Status:** closed\r\n\r\n' > "$R/docs/epics/05-crlf/plan.md"
  commit_all "$R"
  check "CRLF closed plan is still closed" "<none>" "$(queue_block "$R" "$V")" "$V"
  # CRLF must not push `planning` into the wrong bucket either: the trailing \r
  # is stripped before the bucket match, so `planning\r` is still `planning`.
  R="$SANDBOX/Fcrlf2-$V"; mkrepo "$R"; sandboxed "$R/docs/epics/05-crlf-planning"
  mkdir -p "$R/docs/epics/05-crlf-planning"
  printf '# Epic: fixture\r\n\r\n**Status:** planning\r\n\r\n' > "$R/docs/epics/05-crlf-planning/plan.md"
  commit_all "$R"
  check "CRLF planning plan awaits APPROVAL" "approval" \
        "$(bucket_of "$R" "$V" 05-crlf-planning)" "$V"
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
check "and no approval line, the plan being approved" "<none>" \
      "$(approval_line "$SANDBOX/I-wt" full)" "full"

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

# ============================================================================
echo
echo "=== K. THE SPLIT: two queues, two gates ================================"
echo "    (planning only / approved only / both / neither, plus ordering,"
echo "     capping and emission order within the split)"

EXPECT_K_D5="- 1 epic awaiting dispatch: 05-ready."
EXPECT_K_A6="- 1 epic awaiting approval: 06-proposed — approve before dispatch; \`planning\` is never dispatchable."

for V in full bare; do
  # --- K1. approved only -> dispatch line ONLY ------------------------------
  R="$SANDBOX/K1-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-ready" "approved"
  commit_all "$R"
  check "K1 approved only: dispatch line" "$EXPECT_K_D5" "$(queue_line "$R" "$V")" "$V"
  check "K1 approved only: NO approval line" "<none>" "$(approval_line "$R" "$V")" "$V"

  # --- K2. planning only -> approval line ONLY ------------------------------
  R="$SANDBOX/K2-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/06-proposed" "planning"
  commit_all "$R"
  check "K2 planning only: approval line" "$EXPECT_K_A6" "$(approval_line "$R" "$V")" "$V"
  check "K2 planning only: NO dispatch line" "<none>" "$(queue_line "$R" "$V")" "$V"

  # --- K3. both -> both lines, dispatch first, one blank line above ---------
  R="$SANDBOX/K3-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-ready"    "approved"
  plan_file "$R/docs/epics/06-proposed" "planning"
  commit_all "$R"
  check "K3 both: dispatch line, then approval line" \
        "$(printf '%s\n%s' "$EXPECT_K_D5" "$EXPECT_K_A6")" \
        "$(queue_block "$R" "$V")" "$V"
  # The two lines are ONE markdown list: adjacent, with exactly one blank line
  # before the pair and no blank line between them.
  check "K3 both: the two lines are adjacent" "1" \
        "$(run_hook "$R" "$V" | grep -n 'awaiting' | cut -d: -f1 | tr '\n' ' ' \
           | awk '{print ($2 - $1)}')" "$V"
  # ...preceded by exactly one blank line: the section above ends non-blank,
  # then one blank, then the pair. Two blanks would mean each line emitted its
  # own separator instead of sharing one.
  check "K3 both: exactly one blank line above the pair" "nonblank|blank" \
        "$(run_hook "$R" "$V" | grep -B2 'awaiting dispatch' | head -2 \
           | awk '{ printf "%s%s", (NR>1 ? "|" : ""), (length($0) ? "nonblank" : "blank") }')" "$V"

  # --- K4. neither (all closed / in flight) -> no queue output at all -------
  R="$SANDBOX/K4-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/03-done"    "closed"
  plan_file "$R/docs/epics/04-running" "in flight (item 1 of 2)"
  commit_all "$R"
  check "K4 neither: no queue output" "<none>" "$(queue_block "$R" "$V")" "$V"

  # --- K5. interleaved numbers: each line keeps FOLDER order independently --
  R="$SANDBOX/K5-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/04-a" "planning"
  plan_file "$R/docs/epics/05-b" "approved"
  plan_file "$R/docs/epics/06-c" "planning"
  plan_file "$R/docs/epics/07-d" "approved"
  plan_file "$R/docs/epics/08-e" "closed"
  plan_file "$R/docs/epics/09-f" "in flight (items 1-2 of 2, parallel)"
  commit_all "$R"
  sleep 1; touch "$R/docs/epics/04-a/plan.md"        # mtime order != folder order
  check "K5 dispatch line in folder order" \
        "- 2 epics awaiting dispatch: 05-b, 07-d — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
  check "K5 approval line in folder order" \
        "- 2 epics awaiting approval: 04-a, 06-c — approve before dispatch; \`planning\` is never dispatchable." \
        "$(approval_line "$R" "$V")" "$V"

  # --- K6. the cap applies to each line independently -----------------------
  R="$SANDBOX/K6-$V"; mkrepo "$R"
  for N in 01 02 03 04 05 06 07; do plan_file "$R/docs/epics/$N-app$N" "approved"; done
  for N in 11 12 13 14 15 16; do plan_file "$R/docs/epics/$N-pln$N" "planning"; done
  commit_all "$R"
  check "K6 dispatch capped at 5 named (+2 more)" \
        "- 7 epics awaiting dispatch: 01-app01, 02-app02, 03-app03, 04-app04, 05-app05 (+2 more) — dispatch the lowest number first." \
        "$(queue_line "$R" "$V")" "$V"
  check "K6 approval capped at 5 named (+1 more)" \
        "- 6 epics awaiting approval: 11-pln11, 12-pln12, 13-pln13, 14-pln14, 15-pln15 (+1 more) — approve before dispatch; \`planning\` is never dispatchable." \
        "$(approval_line "$R" "$V")" "$V"

  # --- K7. the unattended-intake shape: a planning plan sitting on main -----
  # A merged intake PR puts docs/epics/NN/plan.md at `planning` on the
  # integration branch. It is committed, clean, and still NOT dispatchable.
  R="$SANDBOX/K7-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/07-from-ci" "planning"
  commit_all "$R"
  check "K7 committed planning plan is awaiting APPROVAL" "approval" \
        "$(bucket_of "$R" "$V" 07-from-ci)" "$V"
  check "K7 and the word 'dispatch' never precedes its name" "0" \
        "$(queue_line "$R" "$V" | grep -c '07-from-ci' | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== L. MUTATION CHECK: the new cases fail on the PRE-SPLIT hook ========"
echo "    (same fixtures, run against the single-queue implementation. Every"
echo "     row below must read PASS, and each one asserts that the pre-split"
echo "     hook gets the split WRONG — so these cases can actually detect a"
echo "     regression that silently un-splits the queue.)"
HOOK_UNDER_TEST="$UNSPLIT_HOOK"

R="$SANDBOX/L1"; mkrepo "$R"
plan_file "$R/docs/epics/06-proposed" "planning"
commit_all "$R"
check "L pre-split: emits NO approval line for a planning plan" "<none>" \
      "$(approval_line "$R" full)" "mutant"
check "L pre-split: calls the planning plan 'awaiting dispatch'" \
      "- 1 epic awaiting dispatch: 06-proposed." "$(queue_line "$R" full)" "mutant"
check "L pre-split: K2's expectation therefore does NOT hold" "differs" \
      "$([ "$(approval_line "$R" full)" = "$EXPECT_K_A6" ] && echo same || echo differs)" "mutant"

R="$SANDBOX/L2"; mkrepo "$R"
plan_file "$R/docs/epics/05-ready"    "approved"
plan_file "$R/docs/epics/06-proposed" "planning"
commit_all "$R"
check "L pre-split: both epics collapse into ONE dispatch line" \
      "- 2 epics awaiting dispatch: 05-ready, 06-proposed — dispatch the lowest number first." \
      "$(queue_line "$R" full)" "mutant"
check "L pre-split: K3's two-line block therefore does NOT hold" "differs" \
      "$([ "$(queue_block "$R" full)" = "$(printf '%s\n%s' "$EXPECT_K_D5" "$EXPECT_K_A6")" ] \
         && echo same || echo differs)" "mutant"

R="$SANDBOX/L3"; mkrepo "$R"
plan_file "$R/docs/epics/05-no-status" ""
commit_all "$R"
check "L pre-split: a Status-less plan is called dispatchable" \
      "- 1 epic awaiting dispatch: 05-no-status." "$(queue_line "$R" full)" "mutant"

# And the case that must be IDENTICAL either way — the empty-queue injection —
# so the mutation check cannot be dismissed as "the mutant just differs always".
R="$SANDBOX/L4"; mkrepo "$R"
plan_file "$R/docs/epics/03-done"    "closed"
plan_file "$R/docs/epics/04-running" "in flight (item 1 of 2)"
commit_all "$R"
run_hook "$R" full > "$SANDBOX/L4.presplit"
HOOK_UNDER_TEST="$HOOK"
run_hook "$R" full > "$SANDBOX/L4.split"
check "L both queues empty: mutant and hook agree byte for byte" "" \
      "$(diff "$SANDBOX/L4.presplit" "$SANDBOX/L4.split" | head -20)" "mutant"

echo
echo "=== hook stderr (empty unless the hook errored on its own) ============="
[ -s "$SANDBOX/stderr.log" ] && head -20 "$SANDBOX/stderr.log"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
