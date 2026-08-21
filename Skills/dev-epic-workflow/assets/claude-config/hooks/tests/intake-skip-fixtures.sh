#!/usr/bin/env bash
# Fixture harness for the work-in-progress check in the unattended runner:
#   ../../bin/unattended-intake.sh
#
# The rule under test (epic 09 item 3) is deliberately NOT the obvious one, and
# the obvious one is what these fixtures exist to rule out.
#
# LODE #757, timed from gh rather than remembered:
#   19:50:58Z  issue #757 filed and labelled
#   19:58:37Z  attended PR #758 opened
#   20:00:12Z  PR #758 MERGED
#   20:02:46Z  the runner selected #757          <- no OPEN PR existed here
#   20:06:10Z  wasted proposal PR #761 opened
#   20:16:24Z  issue #757 closed by hand
#
# At selection there was no open PR and the issue was still open, so "skip an
# issue that has an open PR referencing it" would have caught nothing. The rule
# is therefore:
#
#   skip when a PR that DECLARES IT CLOSES the issue is OPEN or MERGED and was
#   NOT opened by this runner (runner-authored = the intake/proposed- branch
#   prefix the script itself constructs; the GitHub actor is the same account
#   for attended and unattended work, so the actor proves nothing).
#
#   a CLOSED-unmerged PR does NOT block — abandoned work is not work in flight.
#
# and it is evaluated TWICE: at selection, and again immediately before the
# proposal is published, because the window in which #758 merged was under four
# minutes wide.
#
# THE NARROWING (epic 09 item 6) is the "declares it closes" clause, and it was
# added after item 3 shipped and was measured. Item 3 blocked on any timeline
# `cross-referenced` event whose source was a PR, which classified four of four
# open issues on this repo as SKIP on passing mentions — including #48, blocked
# by the body of PR #52, the PR that had just recorded #48 as clear. A skip
# REMOVES the label, so a false positive retires an issue from unattended intake
# until a human relabels it. Cases L-R are that narrowing; A-K are item 3's and
# every one of them still has to hold.
#
# Closing linkage is read from two places, in order of authority:
#   1. `closingIssuesReferences` — GitHub's own link (case N)
#   2. a closing keyword in the PR description — the fallback (cases A, Q).
# The fallback is load-bearing: GitHub records a closing link only for PRs based
# on the repository's DEFAULT branch, and LODE integrates on `dev`, so #758 —
# whose body ends "Closes #757", the race this check exists for — has an EMPTY
# closingIssuesReferences list. Verified against live gh on 2026-08-20.
#
# Cases:
#   A  the #757 timeline replayed: merged non-runner PR -> SKIPPED, #758 named
#   B  an OPEN non-runner PR                            -> SKIPPED, PR named
#   C  only a CLOSED-unmerged PR                        -> DRAFTED
#   D  only the runner's own intake/proposed- PRs       -> DRAFTED
#   E  a PR that merges AFTER selection                 -> caught by the re-check
#   F  --dry-run classifies both ways and mutates nothing, anywhere
#   G  the query itself fails -> drafts anyway, and says so (never silent)
#   H  one skip does not stop the run: the next issue is still drafted
#   I  the jq filter itself, run by real jq over a RECORDED live timeline
#   J  the branch prefix is one constant, so detection cannot drift from
#      construction
#   K  mutant: delete the MERGED arm and case A drafts again — proof that case
#      A tests merged-blocking and not something incidental
#   L  THE SELF-REFERENCE CASE: #48 mentioned in the body of PR #52, the PR
#      that recorded #48 as clear -> DRAFTED (and DRAFTED under --dry-run)
#   M  a merged close-out PR naming several issues in prose -> all DRAFTED
#   N  `closingIssuesReferences` with no keyword anywhere -> SKIPPED; and a
#      list containing 410 does not block issue 41
#   O  a closing keyword aimed at a DIFFERENT issue       -> DRAFTED
#   P  lexical near-misses end to end: #480/#4890/`prefixes` -> DRAFTED;
#      `Fixed: #48` -> SKIPPED
#   Q  the closing-keyword regex itself, replayed by real grep over a table
#   R  mutant: delete the linkage gate and case L skips again — proof that L
#      tests the narrowing and not something incidental
#
# SANDBOX DISCIPLINE (GH #15 is open: a fixture harness in this repo has
# already escaped its sandbox and committed a real working tree). This harness:
#   - creates everything under one mktemp -d, removed on exit
#   - never invokes real git or real gh against anything: git, gh and claude are
#     all STUBS on disk, and the stubs refuse to touch a path outside the
#     sandbox and refuse `git add` / `git commit` outright
#   - never reaches the network: the gh stub answers from files
#   - FAILS LOUDLY rather than degrading when the runner asks a question the
#     stub does not model. Item 1's stub did not answer the timeline query item
#     3 had just added, so its whole suite silently exercised item 3's degraded
#     `unknown` path while reporting green. A stub that cannot answer a query
#     does not fail — it silently degrades. See STUB UNANSWERED below.
#   - takes a before/after fingerprint of the repo it lives in and fails loudly
#     if a single byte of it moved
# Fixing GH #15 is not in this item's scope; not tripping it is.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-skip-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$(cd "$TESTS_DIR/../../bin" && pwd)/unattended-intake.sh"
[ -f "$SCRIPT" ] || { echo "ERROR: not found: $SCRIPT" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-skip-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0

# Every path this harness writes to MUST live under $SANDBOX. Without this
# guard one clobbered variable is enough to make the harness operate on the
# developer's own checkout — which is precisely GH #15.
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
  printf '%-62s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$2" "$3" "$VERDICT"
}

# -------------------------------------------------- GH #15 tripwire (read only)
# The repo this file lives in, fingerprinted before and after. Nothing below may
# move it. `git status` here is a READ; no fixture path ever writes to it.
HOST_REPO="$(git -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
host_fingerprint() {
  [ -n "$HOST_REPO" ] || { printf 'no-host-repo'; return; }
  printf '%s|%s' "$(git -C "$HOST_REPO" rev-parse HEAD 2>/dev/null)" \
                 "$(git -C "$HOST_REPO" status --porcelain 2>/dev/null | sort | cksum)"
}
HOST_BEFORE="$(host_fingerprint)"

# ------------------------------------------------------------------- stubs
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

# gh: answers from files in the case directory. Never a socket, never a token.
# Which "phase" it answers in is decided by a marker the claude stub drops when
# the headless draft runs — that is how case E makes the world change UNDER the
# runner, between its two checks.
cat > "$BIN/gh" <<'GH_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
FLAT="$(printf '%s ' "$@" | tr '\n' ' ')"
printf 'gh %s\n' "$FLAT" >> "$CASE/calls.log"

PHASE=selection
[ -f "$CASE/late" ] && PHASE=late

pick() { # $1 = kind (timeline|pr), $2 = key -> path of the answer file, if any
  if [ "$PHASE" = late ] && [ -f "$CASE/late-$1/$2" ]; then printf '%s' "$CASE/late-$1/$2"
  elif [ -f "$CASE/$1/$2" ]; then printf '%s' "$CASE/$1/$2"
  fi
}

case "${1:-}" in
  repo)
    case "$FLAT" in
      *nameWithOwner*)    printf '%s\n' "${FIXTURE_REPO_SLUG:-fixture/repo}" ;;
      *defaultBranchRef*) printf '%s\n' "${FIXTURE_DEFAULT_BRANCH:-main}" ;;
    esac ;;
  label)
    printf '%s\tfixture label\n' "${FIXTURE_LABEL:-claude-intake}" ;;
  issue)
    case "${2:-}" in
      list)    [ -f "$CASE/issues" ] && cat "$CASE/issues" ;;
      view)    printf 'fixture issue %s\n' "${3:-0}" ;;
      comment) printf '%s\n' "$FLAT" >> "$CASE/comments.log"
               printf 'https://example.invalid/issues/%s#comment\n' "${3:-0}" ;;
      edit)    : ;;
    esac ;;
  api)
    # Two api paths are modelled, and NOTHING else:
    #   repos/<owner>/<name>/issues/<n>/timeline?per_page=100   (item 3)
    #   repos/<owner>/<name>/branches?per_page=100              (item 7)
    P=""; BR=""
    for A in "$@"; do
      case "$A" in
        */issues/*/timeline*) P="$A" ;;
        */branches*)          BR="$A" ;;
      esac
    done
    if [ -n "$BR" ]; then
      # Pin the exact query, the way `pr view` pins its field set below: if the
      # runner ever asks for something else, answering a bare name list would
      # hand it "no branches" — i.e. DRAFT — for every case in this file.
      case "$FLAT" in
        *"--paginate "*) ;;
        *) printf 'gh STUB UNANSWERED (branch query is not paginated): %s\n' "$FLAT" >> "$CASE/calls.log"
           echo 'stub does not model this branch query' >&2; exit 1 ;;
      esac
      case "$FLAT" in
        *"-q .[].name "*) ;;
        *) printf 'gh STUB UNANSWERED (branch query field changed): %s\n' "$FLAT" >> "$CASE/calls.log"
           echo 'stub does not model this branch query' >&2; exit 1 ;;
      esac
      [ -f "$CASE/branch-fail" ] && { echo '{"message":"Bad credentials"}'; exit 1; }
      BF="$CASE/branches"
      [ "$PHASE" = late ] && [ -f "$CASE/late-branches" ] && BF="$CASE/late-branches"
      # An ABSENT branch list is a harness bug, not "this repo has no branches".
      # mkcase creates the file empty, so absence means a case was built by hand
      # and forgot it — and answering an empty list would DRAFT, silently.
      [ -f "$BF" ] || {
        printf 'gh STUB UNANSWERED (branch list not modelled): %s\n' "$FLAT" >> "$CASE/calls.log"
        echo 'stub cannot answer this api call' >&2; exit 1; }
      cat "$BF"
      exit 0
    fi
    # A stub that cannot answer a query does not fail, it silently degrades —
    # and here the degraded answer is item 3's `unknown` path, which DRAFTS.
    # Refuse audibly instead. See "STUB UNANSWERED" at the end of the suite.
    [ -n "$P" ] || {
      printf 'gh STUB UNANSWERED (api path not modelled): %s\n' "$FLAT" >> "$CASE/calls.log"
      echo 'stub cannot answer this api call' >&2; exit 1; }
    N="${P#*/issues/}"; N="${N%%/*}"
    [ -f "$CASE/timeline-fail" ] && { echo '{"message":"Not Found"}'; exit 1; }
    F="$(pick timeline "$N")"
    [ -n "$F" ] && cat "$F"
    exit 0 ;;
  pr)
    case "${2:-}" in
      view)   # The answer files below model EXACTLY the field set the runner
              # asks for. If that field set ever changes, answering the old
              # shape would hand the runner an empty closing-refs column and an
              # empty body — i.e. "nothing declares closure", i.e. DRAFT — for
              # every case in this file, silently. So refuse.
              # The trailing space is load-bearing: FLAT separates every arg
              # with one, so it pins the EXACT field set. Without it, adding a
              # field to the query would still match this prefix and the stub
              # would go on answering the old shape — which is the whole bug.
              case "$FLAT" in
                *"--json state,headRefName,url,closingIssuesReferences,body "*) ;;
                *) printf 'gh STUB UNANSWERED (pr view field set changed): %s\n' "$FLAT" >> "$CASE/calls.log"
                   echo 'stub does not model this pr view field set' >&2; exit 1 ;;
              esac
              F="$(pick pr "${3:-}")"
              [ -n "$F" ] || { echo 'no such PR' >&2; exit 1; }
              cat "$F" ;;
      create) printf 'https://example.invalid/pull/999\n' ;;
    esac ;;
esac
exit 0
GH_STUB

# git: does no version control at all. It refuses `add` and `commit` outright
# and refuses to create or delete anything outside the sandbox, so a bug in this
# harness cannot become a commit in a real repo.
cat > "$BIN/git" <<'GIT_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
FLAT="$(printf '%s ' "$@" | tr '\n' ' ')"
printf 'git %s\n' "$FLAT" >> "$CASE/calls.log"

inside() { case "${1:-}" in "$FIXTURE_SANDBOX"/*) return 0 ;; *) return 1 ;; esac; }

# strip a leading -C <dir>
if [ "${1:-}" = "-C" ]; then shift 2; fi

# Nothing this runner does needs history to change. Anything that COULD commit,
# stage or move a real tree is refused and recorded, so an escape is a visible
# failure rather than a silent commit (GH #15).
case "${1:-}" in
  add|commit|rm|mv|checkout|switch|reset|merge|rebase|clean)
    printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"
    exit 99 ;;
esac

case "${1:-}" in
  ls-remote) exit 0 ;;                                  # base branch exists
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
              [ -n "${WT:-}" ] && inside "$WT" && rm -rf "$WT"
              exit 0 ;;
    esac
    exit 0 ;;
esac
exit 0
GIT_STUB

# claude: the headless drafter. Produces no plan (the git stub reports a commit
# either way) and drops the marker that flips the gh stub into its `late` phase,
# which is how a PR "merges while the drafter is working".
cat > "$BIN/claude" <<'CLAUDE_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
printf 'claude -p <prompt>\n' >> "$CASE/calls.log"
: > "$CASE/late"
exit 0
CLAUDE_STUB

chmod +x "$BIN/gh" "$BIN/git" "$BIN/claude"

# A skill dir with only the two files the runner preflights on — the real skill
# tree is never read, and never written.
SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
printf 'fixture issue-intake reference\n'  > "$SKILL/references/issue-intake.md"
printf 'fixture plan-template reference\n' > "$SKILL/references/plan-template.md"

# ------------------------------------------------------------------ helpers
mkcase() { # $1 = case name -> case dir on stdout
  D="$SANDBOX/$1"; sandboxed "$D"
  rm -rf "$D"
  mkdir -p "$D/repo/.git" "$D/worktrees" "$D/home" "$D/timeline" "$D/pr" \
           "$D/late-timeline" "$D/late-pr"
  : > "$D/calls.log"; : > "$D/comments.log"
  # Every case models its branch list, even when the list is empty — see
  # "branch list not modelled" in the gh stub for why absence is a failure.
  : > "$D/branches"
  printf '%s\n' "$D/repo" > "$D/repos"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$D/env"
  chmod 600 "$D/env"
  printf '%s' "$D"
}

set_issues() { # $1 = case dir, rest = issue numbers
  D="$1"; shift; sandboxed "$D"
  : > "$D/issues"
  for I in "$@"; do printf '%s\n' "$I" >> "$D/issues"; done
}

refs() { # $1 = case dir, $2 = issue, rest = PR numbers referencing it (selection)
  D="$1"; I="$2"; shift 2; sandboxed "$D"
  : > "$D/timeline/$I"
  for P in "$@"; do printf '%s\n' "$P" >> "$D/timeline/$I"; done
}

late_refs() { # same, but as the world looks AFTER the drafter has run
  D="$1"; I="$2"; shift 2; sandboxed "$D"
  : > "$D/late-timeline/$I"
  for P in "$@"; do printf '%s\n' "$P" >> "$D/late-timeline/$I"; done
}

# A PR answer file is the runner's own two-part shape: the field line first
# (state, head branch, url, comma-FENCED closingIssuesReferences), then the
# description. Both linkage inputs are explicit at every call site on purpose —
# there is no "declares closure by default", because the whole item is that
# being mentioned is not the same as being closed.
#   $5 = closing issue refs, comma separated, "" for none (GitHub's own link)
#   $6 = the PR description
pr() { # $1 = case dir, $2 = number, $3 = state, $4 = head branch, $5 = closes, $6 = body
  sandboxed "$1"
  printf '%s %s https://example.invalid/pull/%s ,%s,\n%s\n' \
    "$3" "$4" "$2" "${5:-}" "${6:-}" > "$1/pr/$2"
}

late_pr() { # same, for the post-draft phase
  sandboxed "$1"
  printf '%s %s https://example.invalid/pull/%s ,%s,\n%s\n' \
    "$3" "$4" "$2" "${5:-}" "${6:-}" > "$1/late-pr/$2"
}

# The branch heads on origin, as `gh api .../branches -q .[].name` returns them.
# Written explicitly at every call site that needs one, for the same reason the
# two linkage inputs above are: there is no "has a branch by default".
branches() { # $1 = case dir, rest = branch names
  D="$1"; shift; sandboxed "$D"
  : > "$D/branches"
  for B in "$@"; do printf '%s\n' "$B" >> "$D/branches"; done
}

late_branches() { # same, as origin looks AFTER the drafter has run
  D="$1"; shift; sandboxed "$D"
  : > "$D/late-branches"
  for B in "$@"; do printf '%s\n' "$B" >> "$D/late-branches"; done
}

SCRIPT_UNDER_TEST="$SCRIPT"      # case K swaps in the open-PR-only mutant

run_intake() { # $1 = case dir, rest = extra args -> exit code on stdout
  D="$1"; shift; sandboxed "$D"
  INTAKE_GIT="$BIN/git" INTAKE_GH="$BIN/gh" INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_SKILL_DIR="$SKILL" INTAKE_ENV_FILE="$D/env" \
  INTAKE_REPO_LIST="$D/repos" INTAKE_REPO_DIR="$D/repo" \
  INTAKE_LOG="$D/intake.log" INTAKE_LOCK="$D/.lock" \
  INTAKE_WORKTREE_ROOT="$D/worktrees" \
  FIXTURE_CASE_DIR="$D" FIXTURE_SANDBOX="$SANDBOX" FIXTURE_REPO_SLUG="fixture/repo" \
  HOME="$D/home" \
    /bin/bash "$SCRIPT_UNDER_TEST" "$@" > "$D/stdout.log" 2> "$D/stderr.log"
  printf '%s' "$?"
}

# The whole contract as one comparable token.
verdict_of() { # $1 = case dir
  if grep -q 'SKIP #.*(selection)' "$1/stdout.log"; then printf 'skipped-selection'
  elif grep -q 'SKIP #.*(pre-PR re-check)' "$1/stdout.log"; then printf 'skipped-pre-PR'
  elif grep -q '^gh pr create ' "$1/calls.log"; then printf 'drafted'
  else printf 'none'
  fi
}

called() { grep -q "$2" "$1/calls.log"; }
yesno()  { if "$@"; then printf 'yes'; else printf 'no'; fi; }

echo "sandbox: $SANDBOX"
echo "script:  $SCRIPT"
echo "bash:    $(/bin/bash --version | head -1)"
echo

# ============================================================================
echo "=== A. the #757 timeline: a MERGED non-runner PR blocks ================"
echo "    (issue open, label present, PR #758 merged 2m34s before selection,"
echo "     PR #761 is the runner's own earlier proposal)"
D="$(mkcase A)"
set_issues "$D" 757
refs "$D" 757 758 761
# #758's real closingIssuesReferences is EMPTY — it is based on `dev`, not on
# LODE's default branch — so the keyword in its description is the only signal
# there is. #761 is given a declaring body too, so the ONLY thing keeping the
# runner's own proposal from blocking it is the branch prefix.
pr   "$D" 758 MERGED "docs/757-bind-python-skills" "" "Closes #757."
pr   "$D" 761 CLOSED "intake/proposed-757-claude-md-should-bind" "" "Closes #757."
RC="$(run_intake "$D")"
check "A: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "A: exit code (a skip is not a failure)" "0" "$RC"
check "A: the merged PR is named in the issue comment" "yes" \
      "$(yesno grep -q 'PR #758 is already merged' "$D/comments.log")"
check "A: the comment names the branch as evidence" "yes" \
      "$(yesno grep -q 'docs/757-bind-python-skills' "$D/comments.log")"
check "A: the label is removed so it cannot spin" "yes" \
      "$(yesno called "$D" '^gh issue edit 757 --remove-label claude-intake')"
check "A: the comment does not advise a relabelling loop" "yes" \
      "$(yesno grep -q 'Re-applying it produces this same skip' "$D/comments.log")"
check "A: it is in the runner log too (never silent)" "yes" \
      "$(yesno grep -q 'SKIP #757 (selection): already addressed or in flight' "$D/stdout.log")"
# Item 7: WHICH signal fired, and therefore which remedy. #757 was genuinely
# finished by #758, so the answer a reader needs is "close it" — the opposite of
# what an in-flight skip must say. Cases S and T assert the other half.
check "A: the log names the signal"     "yes" \
      "$(yesno grep -q 'SKIP #757 (selection).*\[signal: already-done\]' "$D/stdout.log")"
check "A: the comment says the work is already done" "yes" \
      "$(yesno grep -q 'Signal: the work is already \*\*done\*\*' "$D/comments.log")"
check "A: and tells the reader to CLOSE the issue" "yes" \
      "$(yesno grep -q 'close this issue' "$D/comments.log")"
check "A: it does not tell the reader to wait"     "no" \
      "$(yesno grep -q 'Do not close this issue' "$D/comments.log")"
check "A: no worktree was created"      "no"  "$(yesno called "$D" '^git worktree add')"
check "A: the drafter never ran"        "no"  "$(yesno called "$D" '^claude ')"
check "A: no PR was opened"             "no"  "$(yesno called "$D" '^gh pr create')"
check "A: nothing was pushed"           "no"  "$(yesno called "$D" ' push ')"

echo
echo "=== B. an OPEN non-runner PR blocks too ================================"
D="$(mkcase B)"
set_issues "$D" 770
refs "$D" 770 771
pr   "$D" 771 OPEN "feat/attended-fix" "" "Fixes #770 — attended work already underway."
RC="$(run_intake "$D")"
check "B: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "B: exit code"                    "0" "$RC"
check "B: the open PR is named, with the linkage as evidence" "yes" \
      "$(yesno grep -q 'PR #771 is open and its description declares it closes this issue' "$D/comments.log")"
check "B: label removed"                "yes" \
      "$(yesno called "$D" '^gh issue edit 770 --remove-label claude-intake')"

echo
echo "=== C. a CLOSED-unmerged PR does NOT block ============================="
echo "    (abandoned work is not work in flight)"
D="$(mkcase C)"
set_issues "$D" 780
refs "$D" 780 781
# It DOES declare closure. State is the only thing excluding it.
pr   "$D" 781 CLOSED "fix/abandoned-attempt" "780" "Closes #780."
RC="$(run_intake "$D")"
check "C: verdict"                      "drafted" "$(verdict_of "$D")"
check "C: exit code"                    "0" "$RC"
check "C: the drafter ran"              "yes" "$(yesno called "$D" '^claude ')"
check "C: the branch was pushed"        "yes" "$(yesno called "$D" ' push -q -u origin intake/proposed-780')"
check "C: no skip comment was posted"   "no"  "$(yesno grep -q 'skipped this issue' "$D/comments.log")"

echo
echo "=== D. the runner's OWN proposal PRs never block it ===================="
echo "    (same GitHub account, so authorship is the intake/proposed- prefix)"
D="$(mkcase D)"
set_issues "$D" 790
refs "$D" 790 791 792
# Both declare closure, by BOTH signals. The branch prefix is the only thing
# excluding them, which is what this case is for.
pr   "$D" 791 OPEN   "intake/proposed-790-something" "790" "Closes #790."
pr   "$D" 792 MERGED "intake/proposed-790-something-older" "790" "Closes #790."
RC="$(run_intake "$D")"
check "D: verdict"                      "drafted" "$(verdict_of "$D")"
check "D: exit code"                    "0" "$RC"
check "D: a PR was opened"              "yes" "$(yesno called "$D" '^gh pr create')"

echo
echo "=== E. a PR that merges AFTER selection is caught by the re-check ======"
echo "    (#757's real window between the two points was under four minutes)"
D="$(mkcase E)"
set_issues "$D" 800
refs "$D" 800                       # clear at selection: nothing references it
late_refs "$D" 800 801              # by the time the draft is done, #801 exists
late_pr   "$D" 801 MERGED "fix/attended-landed-during-the-draft" "" "Fixes #800"
RC="$(run_intake "$D")"
check "E: verdict"                      "skipped-pre-PR" "$(verdict_of "$D")"
check "E: exit code"                    "0" "$RC"
check "E: selection let it through (the drafter ran)" "yes" "$(yesno called "$D" '^claude ')"
check "E: the late PR is named"         "yes" \
      "$(yesno grep -q 'PR #801 is already merged' "$D/comments.log")"
check "E: the stage is reported as the re-check" "yes" \
      "$(yesno grep -q 'Checked at: pre-PR re-check' "$D/comments.log")"
check "E: nothing was published — no push"       "no" "$(yesno called "$D" ' push ')"
check "E: nothing was published — no PR"         "no" "$(yesno called "$D" '^gh pr create')"
check "E: the worktree was cleaned up"           "yes" "$(yesno called "$D" '^git worktree remove --force')"
check "E: the branch was deleted"                "yes" "$(yesno called "$D" '^git branch -D intake/proposed-800')"
check "E: label removed"                         "yes" \
      "$(yesno called "$D" '^gh issue edit 800 --remove-label claude-intake')"

echo
echo "=== F. --dry-run classifies BOTH ways and mutates nothing =============="
D="$(mkcase F)"
set_issues "$D" 810 811
refs "$D" 810 812
pr   "$D" 812 MERGED "docs/already-landed" "" "Closes #810."
refs "$D" 811
RC="$(run_intake "$D" --dry-run)"
check "F: exit code"                    "0" "$RC"
check "F: the blocked issue is classified SKIP with its reason" "yes" \
      "$(yesno grep -q 'DRY-RUN: #810 classified SKIP — PR #812 is already merged' "$D/stdout.log")"
check "F: and the classification names WHICH signal fired" "yes" \
      "$(yesno grep -q 'DRY-RUN: #810 classified SKIP .*\[signal: already-done\]' "$D/stdout.log")"
# The DRAFT reason states the rule in force. When item 7 widened the rule this
# line had to change with it: a message still claiming only closing linkage was
# checked would be a lie about what the runner just did.
check "F: the clear issue is classified DRAFT with its reason"  "yes" \
      "$(yesno grep -q 'DRY-RUN: #811 classified DRAFT — no open or merged non-runner PR closes it or declares itself part of it, and no branch on origin is named for it' "$D/stdout.log")"
check "F: no issue comment"             "no"  "$(yesno called "$D" '^gh issue comment')"
check "F: no label edit"                "no"  "$(yesno called "$D" '^gh issue edit')"
check "F: no PR"                        "no"  "$(yesno called "$D" '^gh pr create')"
check "F: no worktree"                  "no"  "$(yesno called "$D" '^git worktree add')"
check "F: no push"                      "no"  "$(yesno called "$D" ' push ')"
check "F: no drafter run"               "no"  "$(yesno called "$D" '^claude ')"
check "F: not even a log file"          "no"  "$(yesno test -f "$D/intake.log")"

echo
echo "=== G. a check that cannot run drafts anyway, and says so =============="
echo "    (a GitHub blip must not stop a runner that worked yesterday, but the"
echo "     unchecked draft is never silent)"
D="$(mkcase G)"
set_issues "$D" 820
: > "$D/timeline-fail"
RC="$(run_intake "$D")"
check "G: verdict"                      "drafted" "$(verdict_of "$D")"
check "G: exit code"                    "0" "$RC"
check "G: the selection check says it could not run" "yes" \
      "$(yesno grep -q 'WARN #820: work-in-progress check could not run' "$D/stdout.log")"
check "G: so does the pre-PR re-check"  "yes" \
      "$(yesno grep -q 'WARN #820: pre-PR work-in-progress re-check could not run' "$D/stdout.log")"

echo
echo "=== H. one skip does not stop the run =================================="
D="$(mkcase H)"
set_issues "$D" 830 831
refs "$D" 830 832
pr   "$D" 832 MERGED "docs/already-landed" "" "Closes #830."
refs "$D" 831
RC="$(run_intake "$D")"
check "H: exit code"                    "0" "$RC"
check "H: #830 skipped"                 "yes" "$(yesno grep -q 'SKIP #830' "$D/stdout.log")"
check "H: #831 still drafted"           "yes" "$(yesno called "$D" 'origin intake/proposed-831')"
check "H: exactly one PR opened"        "1" \
      "$(grep -c '^gh pr create' "$D/calls.log" | tr -d ' ')"

echo
echo "=== I. the jq filter itself, over a RECORDED live timeline ============="
echo "    (the gh stub returns PR numbers, so nothing above exercises the"
echo "     filter that produces them; this replays the real #757 payload)"
PAYLOAD="$SANDBOX/timeline-757.json"; sandboxed "$PAYLOAD"
cat > "$PAYLOAD" <<'PAYLOAD_EOF'
[
  {"event":"labeled","label":{"name":"claude-intake"}},
  {"event":"referenced","commit_id":"deadbeef"},
  {"event":"cross-referenced","actor":{"login":"jstevenson81"},
   "source":{"type":"issue","issue":{"number":758,"state":"closed",
     "title":"docs: bind the six Python skills to this repo's stack",
     "pull_request":{"merged_at":"2026-08-20T20:00:12Z"}}}},
  {"event":"cross-referenced","actor":{"login":"jstevenson81"},
   "source":{"type":"issue","issue":{"number":900,"state":"open",
     "title":"a plain ISSUE mentioning this one — not a PR, must not match"}}},
  {"event":"cross-referenced","actor":{"login":"jstevenson81"},
   "source":{"type":"issue","issue":{"number":761,"state":"closed",
     "title":"intake: proposed epic for #757","pull_request":{"merged_at":null}}}},
  {"event":"closed"}
]
PAYLOAD_EOF
FILTER="$(sed -n "s/^TIMELINE_PR_JQ='\(.*\)'$/\1/p" "$SCRIPT")"
check "I: the filter is defined once in the script" "1" \
      "$(grep -c "^TIMELINE_PR_JQ='" "$SCRIPT" | tr -d ' ')"
if command -v jq >/dev/null 2>&1; then
  check "I: it selects the two PRs and excludes the plain issue" "758 761" \
        "$(jq -r "$FILTER" "$PAYLOAD" 2>/dev/null | tr '\n' ' ' | sed -e 's/ $//')"
else
  echo "    (jq not installed — filter replay skipped, not failed)"
fi

echo
echo "=== J. detection cannot drift from construction ========================"
echo "    (the proposal branch prefix is ONE constant, used by both)"
check "J: the branch is built from the constant" "yes" \
      "$(yesno grep -qF 'BRANCH="${PROPOSAL_BRANCH_PREFIX}${N}-${SLUG}"' "$SCRIPT")"
check "J: the check compares against the same constant" "yes" \
      "$(yesno grep -qF 'case "$WIP_HEAD" in "$PROPOSAL_BRANCH_PREFIX"*)' "$SCRIPT")"
check "J: no literal intake/proposed- left in the check" "0" \
      "$(sed -n '/check_work_in_progress() {/,/^  }$/p' "$SCRIPT" | grep -c 'intake/proposed-' | tr -d ' ')"

echo
echo "=== K. mutant: an OPEN-only rule does NOT catch the #757 race =========="
echo "    (delete the MERGED arm and case A drafts again — which is what the"
echo "     obvious rule would have done on the day)"
MUTANT="$SANDBOX/unattended-intake.open-only.sh"; sandboxed "$MUTANT"
sed -e '/^        MERGED) BLOCKING_PR=/d' "$SCRIPT" > "$MUTANT"
chmod +x "$MUTANT"
cmp -s "$SCRIPT" "$MUTANT" && {
  echo "ERROR: the open-only mutant is identical to the script — the MERGED arm" >&2
  echo "       moved, so case K proves nothing. Fix the sed above." >&2
  exit 1
}
/bin/bash -n "$MUTANT" || { echo "ERROR: mutant does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUTANT"
D="$(mkcase K)"
set_issues "$D" 757
refs "$D" 757 758 761
# #758's real closingIssuesReferences is EMPTY — it is based on `dev`, not on
# LODE's default branch — so the keyword in its description is the only signal
# there is. #761 is given a declaring body too, so the ONLY thing keeping the
# runner's own proposal from blocking it is the branch prefix.
pr   "$D" 758 MERGED "docs/757-bind-python-skills" "" "Closes #757."
pr   "$D" 761 CLOSED "intake/proposed-757-claude-md-should-bind" "" "Closes #757."
RC="$(run_intake "$D")"
check "K: the open-only mutant drafts the wasted proposal" "drafted" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"
D="$(mkcase K2)"
set_issues "$D" 770
refs "$D" 770 771
pr   "$D" 771 OPEN "feat/attended-fix" "" "Fixes #770"
SCRIPT_UNDER_TEST="$MUTANT"
RC="$(run_intake "$D")"
check "K: and still skips an OPEN one, so the mutant is not just broken" \
      "skipped-selection" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== L. THE SELF-REFERENCE CASE: PR #52 vs issue #48 ===================="
echo "    PR #52's body contains the sentence '#48 classified DRAFT — no open"
echo "    or merged non-runner PR references it'. Under item 3's rule that"
echo "    sentence is itself a cross-reference, so the PR that recorded #48 as"
echo "    clear is what made it un-draftable. Reproduced from the live bodies."
SELF_REF_BODY='## Verification

- A live `--dry-run` over every open issue in both configured repos:
  #12 classified SKIP, #15 classified SKIP, #39 classified SKIP,
  #48 classified DRAFT — no open or merged non-runner PR references it.

Part of #39.'
D="$(mkcase L)"
set_issues "$D" 48
refs "$D" 48 50 52
pr   "$D" 50 OPEN   "intake/proposed-48-telemetry-resolution-treats-a-planning" "" "Part of #48."
pr   "$D" 52 MERGED "fix/intake-skip-addressed-issues" "" "$SELF_REF_BODY"
RC="$(run_intake "$D")"
check "L: verdict — a mention is not a claim"  "drafted" "$(verdict_of "$D")"
check "L: exit code"                           "0" "$RC"
check "L: no skip comment was posted"          "no" \
      "$(yesno grep -q 'skipped this issue' "$D/comments.log")"
check "L: the drafter ran"                     "yes" "$(yesno called "$D" '^claude ')"
# The path assertions. Without these, a stub that answered nothing would look
# identical to a correct narrowing: both DRAFT.
check "L: the timeline WAS queried (not the degraded path)" "yes" \
      "$(yesno called "$D" 'repos/fixture/repo/issues/48/timeline')"
check "L: the check did not fall back to unknown"          "no" \
      "$(yesno grep -q 'WARN #48: work-in-progress check could not run' "$D/stdout.log")"
check "L: PR #52 WAS inspected, with the closing-linkage fields" "yes" \
      "$(yesno called "$D" '^gh pr view 52 --repo fixture/repo --json state,headRefName,url,closingIssuesReferences,body')"
check "L: PR #50 was inspected too"            "yes" \
      "$(yesno called "$D" '^gh pr view 50 --repo fixture/repo --json state,headRefName,url,closingIssuesReferences,body')"

D="$(mkcase L2)"
set_issues "$D" 48
refs "$D" 48 50 52
pr   "$D" 50 OPEN   "intake/proposed-48-telemetry-resolution-treats-a-planning" "" "Part of #48."
pr   "$D" 52 MERGED "fix/intake-skip-addressed-issues" "" "$SELF_REF_BODY"
RC="$(run_intake "$D" --dry-run)"
check "L: --dry-run classifies #48 DRAFT"      "yes" \
      "$(yesno grep -q 'DRY-RUN: #48 classified DRAFT' "$D/stdout.log")"
check "L: --dry-run mutated nothing"           "no" \
      "$(yesno called "$D" '^gh issue edit')"

echo
echo "=== M. a close-out PR naming several issues in prose blocks none ======="
echo "    (the measured #12 / #15 pair, both blocked by merged PR #38)"
D="$(mkcase M)"
set_issues "$D" 12 15
refs "$D" 12 38
refs "$D" 15 38
pr   "$D" 38 MERGED "docs/close-epic-06" "" \
     "Epic 06 closes here. Two discoveries were filed rather than addressed: #12 (branch-name cancel selectors) and #15 (fixture harnesses escape their sandbox). Neither is touched by this PR."
RC="$(run_intake "$D")"
check "M: exit code"                    "0" "$RC"
check "M: #12 was not skipped"          "no"  "$(yesno grep -q 'SKIP #12' "$D/stdout.log")"
check "M: #15 was not skipped"          "no"  "$(yesno grep -q 'SKIP #15' "$D/stdout.log")"
check "M: both were drafted"            "2" \
      "$(grep -c '^gh pr create' "$D/calls.log" | tr -d ' ')"

echo
echo "=== N. GitHub's own closing link blocks, with no keyword anywhere ======"
echo "    (a PR linked through the sidebar; closingIssuesReferences is the"
echo "     authoritative signal and it is checked first)"
D="$(mkcase N)"
set_issues "$D" 41
refs "$D" 41 45
pr   "$D" 45 MERGED "docs/phase5-close-order-status-first" "41" \
     "Linked to the issue through the GitHub sidebar. This description never uses a closing keyword at all."
RC="$(run_intake "$D")"
check "N: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "N: the evidence says GitHub recorded the link" "yes" \
      "$(yesno grep -q 'PR #45 is already merged and GitHub records it as closing this issue' "$D/comments.log")"

D="$(mkcase N2)"
set_issues "$D" 41
refs "$D" 41 46
pr   "$D" 46 MERGED "docs/other-epic" "410,4100" \
     "Closes #410 and #4100. Issue #41 is unrelated."
RC="$(run_intake "$D")"
check "N: a closing list of 410,4100 does not block issue 41" "drafted" "$(verdict_of "$D")"

echo
echo "=== O. a closing keyword aimed at a DIFFERENT issue does not block ====="
D="$(mkcase O)"
set_issues "$D" 757
refs "$D" 757 999
pr   "$D" 999 MERGED "fix/something-else" "" \
     "Closes #740. Related prior art in #757, which this does not resolve. See also: Closes #740, #757 is NOT closed by that form either — GitHub needs a keyword per issue."
RC="$(run_intake "$D")"
check "O: verdict"                      "drafted" "$(verdict_of "$D")"
check "O: no skip comment"              "no" \
      "$(yesno grep -q 'skipped this issue' "$D/comments.log")"

echo
echo "=== P. lexical near-misses, end to end ================================="
D="$(mkcase P)"
set_issues "$D" 48
refs "$D" 48 60
pr   "$D" 60 MERGED "docs/near-miss" "" \
     "Prefixes #480 and #4890 were renamed. See also #48 for context."
RC="$(run_intake "$D")"
check "P: #480 / #4890 / 'Prefixes' do not block #48" "drafted" "$(verdict_of "$D")"

D="$(mkcase P2)"
set_issues "$D" 48
refs "$D" 48 61
pr   "$D" 61 MERGED "fix/the-real-thing" "" "Fixed: #48"
RC="$(run_intake "$D")"
check "P: but 'Fixed: #48' does block it"             "skipped-selection" "$(verdict_of "$D")"

echo
echo "=== Q. the closing-keyword regex itself, replayed by real grep ========="
echo "    (nothing above exercises the pattern in isolation; this pins the"
echo "     keyword list and both number guards to the constant in the script)"
check "Q: the regex is defined once in the script" "1" \
      "$(grep -c "^CLOSING_KEYWORD_RE='" "$SCRIPT" | tr -d ' ')"
check "Q: the PR field query is defined once too"  "1" \
      "$(grep -c "^PR_VIEW_JQ='" "$SCRIPT" | tr -d ' ')"
check "Q: the check appends the issue number and a non-digit guard" "yes" \
      "$(yesno grep -qF 'grep -Eiq "${CLOSING_KEYWORD_RE}$1([^0-9]|\$)"' "$SCRIPT")"
CKRE="$(sed -n "s/^CLOSING_KEYWORD_RE='\(.*\)'$/\1/p" "$SCRIPT")"
RE_TAIL='([^0-9]|$)'      # the same tail the line asserted just above appends
kw() { # $1 = body, $2 = issue -> match|no
  if printf '%s\n' "$1" | grep -Eiq "${CKRE}$2${RE_TAIL}"; then printf 'match'; else printf 'no'; fi
}
check "Q: Closes #757."        "match" "$(kw 'Closes #757.' 757)"
check "Q: closes #757"         "match" "$(kw 'closes #757' 757)"
check "Q: Closed #757"         "match" "$(kw 'Closed #757' 757)"
check "Q: Fix #757"            "match" "$(kw 'Fix #757' 757)"
check "Q: Fixes #757"          "match" "$(kw 'Fixes #757' 757)"
check "Q: Fixed: #757"         "match" "$(kw 'Fixed: #757' 757)"
check "Q: Resolve #757"        "match" "$(kw 'Resolve #757' 757)"
check "Q: RESOLVES #757"       "match" "$(kw 'RESOLVES #757' 757)"
check "Q: resolved #757"       "match" "$(kw 'resolved #757' 757)"
check "Q: keyword on a later line of a long body" "match" \
      "$(kw '## Summary

Some prose that mentions nothing at all.

Closes #757' 757)"
check "Q: See #757"            "no"    "$(kw 'See #757' 757)"
check "Q: Part of #757"        "no"    "$(kw 'Part of #757' 757)"
check "Q: the self-reference sentence" "no" \
      "$(kw '#757 classified DRAFT — no open or merged non-runner PR references it' 757)"
check "Q: Closes #7570 (longer number)" "no"   "$(kw 'Closes #7570' 7570 >/dev/null; kw 'Closes #7570' 757)"
check "Q: Closes #75 (shorter number)"  "no"   "$(kw 'Closes #75' 757)"
check "Q: prefixes #757 (keyword inside a word)" "no" "$(kw 'prefixes #757' 757)"
check "Q: unresolved #757 (keyword inside a word)" "no" "$(kw 'unresolved #757' 757)"
check "Q: Closes #740, #757 (one keyword, two issues)" "no" "$(kw 'Closes #740, #757' 757)"
check "Q: Closes #740 alone"   "no"    "$(kw 'Closes #740' 757)"
check "Q: an empty body"       "no"    "$(kw '' 757)"
# Found by this suite writing its own close-out prose and being skipped by it.
# The fallback deliberately inherits GitHub's keyword semantics rather than
# trying to out-read them: GitHub would auto-close #12 on this sentence too, so
# a runner that disagreed with GitHub would be the surprising one.
check "Q: 'filed rather than fixed: #12' matches, as it does on GitHub" "match" \
      "$(kw 'Two discoveries were filed rather than fixed: #12 and #15.' 12)"

echo
echo "=== R. mutant: without the linkage gate, the self-reference case skips =="
echo "    (delete one line and the check reverts to item 3's any-cross-"
echo "     reference rule — which is exactly how #48 became un-draftable)"
MUTANT2="$SANDBOX/unattended-intake.any-reference.sh"; sandboxed "$MUTANT2"
sed -e '/^      declares_closing /d' "$SCRIPT" > "$MUTANT2"
chmod +x "$MUTANT2"
cmp -s "$SCRIPT" "$MUTANT2" && {
  echo "ERROR: the any-reference mutant is identical to the script — the" >&2
  echo "       linkage gate moved, so case R proves nothing. Fix the sed." >&2
  exit 1
}
/bin/bash -n "$MUTANT2" || { echo "ERROR: mutant does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUTANT2"
D="$(mkcase R)"
set_issues "$D" 48
refs "$D" 48 50 52
pr   "$D" 50 OPEN   "intake/proposed-48-telemetry-resolution-treats-a-planning" "" "Part of #48."
pr   "$D" 52 MERGED "fix/intake-skip-addressed-issues" "" "$SELF_REF_BODY"
RC="$(run_intake "$D")"
check "R: the any-reference mutant skips #48 on PR #52" "skipped-selection" "$(verdict_of "$D")"
D="$(mkcase R2)"
set_issues "$D" 780
refs "$D" 780 781
pr   "$D" 781 CLOSED "fix/abandoned-attempt" "780" "Closes #780."
RC="$(run_intake "$D")"
check "R: and still drafts on a CLOSED PR, so it is not just broken" \
      "drafted" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

# ============================================================================
# Cases S-Z are epic 09 item 7: the WIDENING. Item 6's narrowing above is the
# right rule for ALREADY DONE and every one of its cases still has to hold. It
# is blind to ALREADY IN FLIGHT, because a multi-item epic's work-item PRs say
# `Part of #N` by design and declare no closure until the final item. Measured
# across both repos on 2026-08-21 (n=11 open issues): LODE #811 was open with an
# open PR, a merged PR and a branch named for it, and the runner would have
# drafted a duplicate proposal over all three.
# ============================================================================

echo
echo "=== S. LODE #811: 'Part of #811' on an OPEN and a MERGED PR ============"
echo "    Neither PR closes anything — an epic's items do not, until the last"
echo "    one. No branch is modelled here, so the Part-of signal is the ONLY"
echo "    thing that can produce a skip."
D="$(mkcase S)"
set_issues "$D" 811
refs "$D" 811 813 814
pr   "$D" 813 MERGED "feat/811-finish-tool-settles-the-turn"      "" "Part of #811."
pr   "$D" 814 OPEN   "feat/811-reconcile-claim-against-ledger"    "" "Part of #811"
branches "$D" main dev docs/unrelated-work
RC="$(run_intake "$D")"
check "S: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "S: exit code (a skip is not a failure)" "0" "$RC"
check "S: the first declaring PR is named" "yes" \
      "$(yesno grep -q "PR #813 is already merged and its description declares it is part of this issue's work" "$D/comments.log")"
check "S: the log names the in-flight-pr signal" "yes" \
      "$(yesno grep -q 'SKIP #811 (selection).*\[signal: in-flight-pr\]' "$D/stdout.log")"
check "S: the comment says the work is in flight" "yes" \
      "$(yesno grep -q 'Signal: the work is already \*\*in flight\*\*' "$D/comments.log")"
# The whole reason the signal is named. The already-done remedy would lose the
# epic: closing #811 with four items still to deliver throws the tracker item away.
check "S: it tells the reader NOT to close the issue" "yes" \
      "$(yesno grep -q 'Do not close this issue' "$D/comments.log")"
check "S: it explains multi-item epics rather than just refusing" "yes" \
      "$(yesno grep -q 'part of this issue.s work rather than the end of it' "$D/comments.log")"
check "S: label removed"                "yes" \
      "$(yesno called "$D" '^gh issue edit 811 --remove-label claude-intake')"
check "S: nothing was drafted"          "no"  "$(yesno called "$D" '^claude ')"
check "S: no PR was opened"             "no"  "$(yesno called "$D" '^gh pr create')"
# Path assertions: without these a stub answering nothing looks identical.
check "S: the branch list was NOT needed (a PR already answered)" "no" \
      "$(yesno called "$D" 'branches?per_page=100')"
check "S: the check did not fall back to unknown" "no" \
      "$(yesno grep -q 'WARN #811: work-in-progress check could not run' "$D/stdout.log")"

echo
echo "=== S2. claude-skills #39: five merged 'Part of #39' PRs, epic 09 ======"
echo "    This epic's own issue. Every item's PR says 'Part of #39' and none"
echo "    says Closes, so under item 6's rule alone #39 reads as draftable"
echo "    while five of its items are merged and two are in flight."
D="$(mkcase S2)"
set_issues "$D" 39
refs "$D" 39 47 51 52 53 55 56
pr   "$D" 47 MERGED "docs/approve-epic-08" "" \
     "Epic 08 is closed on its NO-GO verdict. Its remediations are re-filed as #39."
pr   "$D" 51 MERGED "docs/approve-epic-09"                "" "Part of #39."
pr   "$D" 52 MERGED "fix/intake-skip-addressed-issues"    "" "Part of #39."
pr   "$D" 53 MERGED "feat/intake-nonapproval-outcomes"    "" "Part of #39."
pr   "$D" 55 MERGED "fix/intake-header-from-config"       "" "Part of #39."
pr   "$D" 56 MERGED "fix/intake-reference-narrowing"      "" "Part of #39."
branches "$D" main
RC="$(run_intake "$D")"
check "S2: verdict"                     "skipped-selection" "$(verdict_of "$D")"
# #47 comes first in the timeline and only MENTIONS #39 — under item 6's rule it
# is a passing mention and must stay one. The skip has to come from #51.
check "S2: the passing mention in #47 is not what blocked it" "no" \
      "$(yesno grep -q 'PR #47' "$D/comments.log")"
check "S2: the first Part-of PR is what blocked it" "yes" \
      "$(yesno grep -q 'PR #51 is already merged' "$D/comments.log")"
check "S2: reported as in flight, not as done" "yes" \
      "$(yesno grep -q 'SKIP #39 (selection).*\[signal: in-flight-pr\]' "$D/stdout.log")"

echo
echo "=== T. the BRANCH signal alone: no PR exists yet ======================="
echo "    The earliest moment work is visible. Nothing references the issue at"
echo "    all, so every PR signal is silent and the branch is the only evidence."
D="$(mkcase T)"
set_issues "$D" 811
refs "$D" 811                                   # no PR references it at all
branches "$D" main dev \
         feat/8111-a-longer-number \
         feat/1811-a-longer-prefix \
         docs/diagram-mcp-811 \
         feat/811-reconcile-claim-against-ledger
RC="$(run_intake "$D")"
check "T: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "T: exit code"                    "0" "$RC"
check "T: the branch is named as the evidence" "yes" \
      "$(yesno grep -q 'branch .feat/811-reconcile-claim-against-ledger. on origin is named for this issue' "$D/comments.log")"
check "T: the log names the in-flight-branch signal" "yes" \
      "$(yesno grep -q 'SKIP #811 (selection).*\[signal: in-flight-branch\]' "$D/stdout.log")"
check "T: the remedy is to wait, not to close" "yes" \
      "$(yesno grep -q 'Do not close this issue' "$D/comments.log")"
check "T: the remedy covers an abandoned branch" "yes" \
      "$(yesno grep -q 'If that branch is abandoned, delete it on .origin.' "$D/comments.log")"
check "T: the branch list WAS actually queried" "yes" \
      "$(yesno called "$D" 'repos/fixture/repo/branches?per_page=100')"
check "T: nothing was drafted"          "no"  "$(yesno called "$D" '^claude ')"

echo
echo "=== T2. branch near-misses do NOT block ================================"
echo "    Same list as T minus the real one: a longer number either side of the"
echo "    issue, and the number at the END of a name with no trailing dash."
D="$(mkcase T2)"
set_issues "$D" 811
refs "$D" 811
branches "$D" main dev \
         feat/8111-a-longer-number \
         feat/1811-a-longer-prefix \
         docs/diagram-mcp-811 \
         release/811 \
         intake/proposed-811-something-the-runner-cut-itself
RC="$(run_intake "$D")"
check "T2: verdict — none of these is work in flight" "drafted" "$(verdict_of "$D")"
check "T2: no skip comment"             "no" \
      "$(yesno grep -q 'skipped this issue' "$D/comments.log")"
# The runner's own proposal branch is excluded by the SAME constant the PR path
# uses, so a re-applied label cannot make the runner block on its own branch.
check "T2: the runner's own branch did not block it" "no" \
      "$(yesno grep -q 'intake/proposed-811' "$D/comments.log")"

echo
echo "=== U. already-done OUTRANKS in-flight, whatever the timeline order ===="
echo "    LODE #766: earlier PRs are only part of it, a later one closes it."
echo "    The remedies are opposites, so reporting the first match would tell a"
echo "    human to wait for work that has already landed."
D="$(mkcase U)"
set_issues "$D" 766
refs "$D" 766 800 806 808                       # in timeline order
pr   "$D" 800 MERGED "feat/766-first-slice"  "" "Part of #766."
pr   "$D" 806 OPEN   "feat/766-second-slice" "" "Part of #766."
pr   "$D" 808 MERGED "feat/766-last-slice"   "" "Closes #766."
branches "$D" main dev
RC="$(run_intake "$D")"
check "U: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "U: the CLOSING PR is what is reported" "yes" \
      "$(yesno grep -q 'PR #808 is already merged and its description declares it closes this issue' "$D/comments.log")"
check "U: the earlier Part-of PRs are not"    "no" \
      "$(yesno grep -q 'PR #800' "$D/comments.log")"
check "U: reported as already-done"     "yes" \
      "$(yesno grep -q 'SKIP #766 (selection).*\[signal: already-done\]' "$D/stdout.log")"
check "U: the reader is told to close the issue" "yes" \
      "$(yesno grep -q 'close this issue' "$D/comments.log")"
check "U: exactly one signal is reported, not two" "1" \
      "$(grep -c 'Signal: the work is' "$D/comments.log" | tr -d ' ')"

echo
echo "=== V. item 6's flips are NOT undone ==================================="
echo "    PR #55 mentions #54 in prose and carries 'Part of #39' — one PR, two"
echo "    issues, opposite verdicts. #54 is a passing mention and must stay"
echo "    draftable; #39 is the epic that PR is an item of and must skip."
PR55_BODY='## Work item

Epic: L1 preconditions — `docs/epics/09-l1-preconditions/plan.md`
Item: 2 — header metadata read from repo config

## Deliberately not in scope

- `session-start-fixtures.sh` fails 2/125 on this machine (#54). Pre-existing,
  environment-dependent, and not caused by this change — left open.

Part of #39.'
D="$(mkcase V)"
set_issues "$D" 54 39
refs "$D" 54 55
refs "$D" 39 55
pr   "$D" 55 MERGED "fix/intake-header-from-config" "" "$PR55_BODY"
branches "$D" main
RC="$(run_intake "$D")"
check "V: #54 was NOT skipped (a mention is still not a claim)" "no" \
      "$(yesno grep -q 'SKIP #54' "$D/stdout.log")"
check "V: #54 was drafted"              "yes" "$(yesno called "$D" 'origin intake/proposed-54')"
check "V: #39 WAS skipped, by the same PR body" "yes" \
      "$(yesno grep -q 'SKIP #39' "$D/stdout.log")"
check "V: exactly one PR was opened"    "1" \
      "$(grep -c '^gh pr create' "$D/calls.log" | tr -d ' ')"
check "V: the branch list WAS queried for the drafted issue" "yes" \
      "$(yesno called "$D" 'repos/fixture/repo/branches?per_page=100')"
check "V: no unknown fallback"          "no" \
      "$(yesno grep -q 'could not run' "$D/stdout.log")"

echo
echo "=== W. the Part-of regex itself, replayed by real grep ================="
echo "    (mirrors case Q for the other keyword; pins the pattern and both"
echo "     number guards to the constant in the script)"
check "W: the regex is defined once in the script" "1" \
      "$(grep -c "^PART_OF_RE='" "$SCRIPT" | tr -d ' ')"
check "W: the branch-list query is defined once too" "1" \
      "$(grep -c "^BRANCH_LIST_JQ='" "$SCRIPT" | tr -d ' ')"
check "W: the check appends the issue number and a non-digit guard" "yes" \
      "$(yesno grep -qF 'grep -Eiq "${PART_OF_RE}$1([^0-9]|\$)"' "$SCRIPT")"
PORE="$(sed -n "s/^PART_OF_RE='\(.*\)'$/\1/p" "$SCRIPT")"
po() { # $1 = body, $2 = issue -> match|no
  if printf '%s\n' "$1" | grep -Eiq "${PORE}$2${RE_TAIL}"; then printf 'match'; else printf 'no'; fi
}
check "W: Part of #39."        "match" "$(po 'Part of #39.' 39)"
check "W: Part of #39"         "match" "$(po 'Part of #39' 39)"
check "W: part of #39"         "match" "$(po 'part of #39' 39)"
check "W: PART OF #39"         "match" "$(po 'PART OF #39' 39)"
check "W: Part of: #39"        "match" "$(po 'Part of: #39' 39)"
check "W: Part  of  #39"       "match" "$(po 'Part  of  #39' 39)"
check "W: on a later line of a long body" "match" \
      "$(po '## Summary

Some prose that mentions nothing at all.

Part of #39' 39)"
check "W: Part of #390 (longer number)"  "no" "$(po 'Part of #390' 39)"
check "W: Part of #3 (shorter number)"   "no" "$(po 'Part of #3' 39)"
check "W: apart of #39 (keyword inside a word)" "no" "$(po 'apart of #39' 39)"
check "W: Parts of #39"        "no"    "$(po 'Parts of #39' 39)"
check "W: See #39"             "no"    "$(po 'See #39' 39)"
check "W: an empty body"       "no"    "$(po '' 39)"
# The two signals must not read each other's evidence, or naming which one fired
# would be arbitrary. Q already asserts the closing regex ignores 'Part of'.
check "W: Closes #39 is NOT a Part-of declaration" "no" "$(po 'Closes #39' 39)"
check "W: Part of #39 is NOT a closing declaration" "no" "$(kw 'Part of #39' 39)"
# Deliberate and documented: the signal fails SAFE. A body arguing an issue is
# NOT part of the work still blocks, and the skip comment says wait — cheap and
# reversible, where the alternative is drafting over live work.
check "W: 'not part of #39' matches too (fails safe)" "match" \
      "$(po 'This is deliberately not part of #39.' 39)"

echo
echo "=== X. the branch glob cannot drift from the runner's own prefix ======="
echo "    (mirrors case J: one constant builds the proposal branch and the same"
echo "     constant excludes it from every signal)"
check "X: the branch check excludes the runner's own prefix" "yes" \
      "$(yesno grep -qF 'case "$WIP_BR" in "$PROPOSAL_BRANCH_PREFIX"*) continue ;; esac' "$SCRIPT")"
check "X: it matches on */<issue>- and nothing looser" "yes" \
      "$(yesno grep -qF 'case "$WIP_BR" in */"$1"-*) WIP_BRANCH="$WIP_BR"; return 0 ;; esac' "$SCRIPT")"
check "X: no literal intake/proposed- in the branch helper" "0" \
      "$(sed -n '/branch_named_for_issue() {/,/^  }$/p' "$SCRIPT" | grep -c 'intake/proposed-' | tr -d ' ')"

echo
echo "=== Y. mutant: without the branch gate, case T drafts =================="
echo "    (the branch signal is the only evidence in case T, so deleting the"
echo "     one line that turns a named branch into a block must un-skip it —"
echo "     which is what proves T is testing the branch and nothing incidental)"
MUTANT3="$SANDBOX/unattended-intake.no-branch-signal.sh"; sandboxed "$MUTANT3"
sed -e '/^    WIP_SIGNAL="in-flight-branch"; WIP_STATUS="blocked"$/d' "$SCRIPT" > "$MUTANT3"
chmod +x "$MUTANT3"
cmp -s "$SCRIPT" "$MUTANT3" && {
  echo "ERROR: the no-branch-signal mutant is identical to the script — the" >&2
  echo "       branch gate moved, so case Y proves nothing. Fix the sed." >&2
  exit 1
}
/bin/bash -n "$MUTANT3" || { echo "ERROR: mutant does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUTANT3"
D="$(mkcase Y)"
set_issues "$D" 811
refs "$D" 811
branches "$D" main dev feat/811-reconcile-claim-against-ledger
RC="$(run_intake "$D")"
check "Y: the no-branch-signal mutant drafts over the branch" "drafted" "$(verdict_of "$D")"
D="$(mkcase Y2)"
set_issues "$D" 811
refs "$D" 811 813
pr   "$D" 813 MERGED "feat/811-finish-tool-settles-the-turn" "" "Part of #811."
branches "$D" main dev feat/811-reconcile-claim-against-ledger
RC="$(run_intake "$D")"
check "Y: and still skips on a Part-of PR, so it is not just broken" \
      "skipped-selection" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== Z. mutant: without the Part-of gate, case S drafts ================="
echo "    (the two in-flight signals are independent — neither case passes"
echo "     because the other signal quietly caught it)"
MUTANT4="$SANDBOX/unattended-intake.no-part-of-signal.sh"; sandboxed "$MUTANT4"
sed -e '/^      WIP_SIGNAL="in-flight-pr"; WIP_STATUS="blocked"$/d' "$SCRIPT" > "$MUTANT4"
chmod +x "$MUTANT4"
cmp -s "$SCRIPT" "$MUTANT4" && {
  echo "ERROR: the no-part-of mutant is identical to the script — the in-flight" >&2
  echo "       PR gate moved, so case Z proves nothing. Fix the sed." >&2
  exit 1
}
/bin/bash -n "$MUTANT4" || { echo "ERROR: mutant does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUTANT4"
D="$(mkcase Z)"
set_issues "$D" 811
refs "$D" 811 813 814
pr   "$D" 813 MERGED "feat/811-finish-tool-settles-the-turn"   "" "Part of #811."
pr   "$D" 814 OPEN   "feat/811-reconcile-claim-against-ledger" "" "Part of #811"
branches "$D" main dev docs/unrelated-work
RC="$(run_intake "$D")"
check "Z: the no-part-of mutant drafts over the epic" "drafted" "$(verdict_of "$D")"
D="$(mkcase Z2)"
set_issues "$D" 757
refs "$D" 757 758
pr   "$D" 758 MERGED "docs/757-bind-python-skills" "" "Closes #757."
branches "$D" main
RC="$(run_intake "$D")"
check "Z: and still skips on closing linkage, so it is not just broken" \
      "skipped-selection" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== sandbox discipline (GH #15) ========================================"
ESCAPES="$(grep -l 'STUB REFUSED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no stub ever had to refuse a git add/commit" "" "$ESCAPES"
# The item-1 lesson, enforced rather than remembered: if the runner asked gh
# something these fixtures do not model, every case above was measuring a
# degraded path and the greens meant nothing.
UNANSWERED="$(grep -l 'STUB UNANSWERED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no gh query went unanswered (silent degradation)" "" "$UNANSWERED"
check "the host repo did not move (HEAD + working tree)" "$HOST_BEFORE" "$(host_fingerprint)"

echo
echo "=== stderr from the runner (empty unless it errored on its own) ========"
for E in "$SANDBOX"/*/stderr.log; do
  [ -s "$E" ] || continue
  printf '%s:\n' "$E"; head -5 "$E"
done

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
