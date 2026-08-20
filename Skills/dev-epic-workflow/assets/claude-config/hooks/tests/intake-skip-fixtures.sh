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
#   skip when a PR referencing the issue is OPEN or MERGED and was NOT opened
#   by this runner (runner-authored = the intake/proposed- branch prefix the
#   script itself constructs; the GitHub actor is the same account for attended
#   and unattended work, so the actor proves nothing).
#
#   a CLOSED-unmerged PR does NOT block — abandoned work is not work in flight.
#
# and it is evaluated TWICE: at selection, and again immediately before the
# proposal is published, because the window in which #758 merged was under four
# minutes wide.
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
#
# SANDBOX DISCIPLINE (GH #15 is open: a fixture harness in this repo has
# already escaped its sandbox and committed a real working tree). This harness:
#   - creates everything under one mktemp -d, removed on exit
#   - never invokes real git or real gh against anything: git, gh and claude are
#     all STUBS on disk, and the stubs refuse to touch a path outside the
#     sandbox and refuse `git add` / `git commit` outright
#   - never reaches the network: the gh stub answers from files
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
    # repos/<owner>/<name>/issues/<n>/timeline?per_page=100
    P=""
    for A in "$@"; do case "$A" in */issues/*/timeline*) P="$A" ;; esac; done
    N="${P#*/issues/}"; N="${N%%/*}"
    [ -f "$CASE/timeline-fail" ] && { echo '{"message":"Not Found"}'; exit 1; }
    F="$(pick timeline "$N")"
    [ -n "$F" ] && cat "$F"
    exit 0 ;;
  pr)
    case "${2:-}" in
      view)   F="$(pick pr "${3:-}")"
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

pr() { # $1 = case dir, $2 = number, $3 = state, $4 = head branch
  sandboxed "$1"
  printf '%s %s https://example.invalid/pull/%s\n' "$3" "$4" "$2" > "$1/pr/$2"
}

late_pr() { # same, for the post-draft phase
  sandboxed "$1"
  printf '%s %s https://example.invalid/pull/%s\n' "$3" "$4" "$2" > "$1/late-pr/$2"
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
pr   "$D" 758 MERGED "docs/757-bind-python-skills"
pr   "$D" 761 CLOSED "intake/proposed-757-claude-md-should-bind"
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
check "A: no worktree was created"      "no"  "$(yesno called "$D" '^git worktree add')"
check "A: the drafter never ran"        "no"  "$(yesno called "$D" '^claude ')"
check "A: no PR was opened"             "no"  "$(yesno called "$D" '^gh pr create')"
check "A: nothing was pushed"           "no"  "$(yesno called "$D" ' push ')"

echo
echo "=== B. an OPEN non-runner PR blocks too ================================"
D="$(mkcase B)"
set_issues "$D" 770
refs "$D" 770 771
pr   "$D" 771 OPEN "feat/attended-fix"
RC="$(run_intake "$D")"
check "B: verdict"                      "skipped-selection" "$(verdict_of "$D")"
check "B: exit code"                    "0" "$RC"
check "B: the open PR is named"         "yes" \
      "$(yesno grep -q 'PR #771 is open and references this issue' "$D/comments.log")"
check "B: label removed"                "yes" \
      "$(yesno called "$D" '^gh issue edit 770 --remove-label claude-intake')"

echo
echo "=== C. a CLOSED-unmerged PR does NOT block ============================="
echo "    (abandoned work is not work in flight)"
D="$(mkcase C)"
set_issues "$D" 780
refs "$D" 780 781
pr   "$D" 781 CLOSED "fix/abandoned-attempt"
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
pr   "$D" 791 OPEN   "intake/proposed-790-something"
pr   "$D" 792 MERGED "intake/proposed-790-something-older"
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
late_pr   "$D" 801 MERGED "fix/attended-landed-during-the-draft"
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
pr   "$D" 812 MERGED "docs/already-landed"
refs "$D" 811
RC="$(run_intake "$D" --dry-run)"
check "F: exit code"                    "0" "$RC"
check "F: the blocked issue is classified SKIP with its reason" "yes" \
      "$(yesno grep -q 'DRY-RUN: #810 classified SKIP — PR #812 is already merged' "$D/stdout.log")"
check "F: the clear issue is classified DRAFT with its reason"  "yes" \
      "$(yesno grep -q 'DRY-RUN: #811 classified DRAFT — no open or merged non-runner PR' "$D/stdout.log")"
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
pr   "$D" 832 MERGED "docs/already-landed"
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
pr   "$D" 758 MERGED "docs/757-bind-python-skills"
pr   "$D" 761 CLOSED "intake/proposed-757-claude-md-should-bind"
RC="$(run_intake "$D")"
check "K: the open-only mutant drafts the wasted proposal" "drafted" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"
D="$(mkcase K2)"
set_issues "$D" 770
refs "$D" 770 771
pr   "$D" 771 OPEN "feat/attended-fix"
SCRIPT_UNDER_TEST="$MUTANT"
RC="$(run_intake "$D")"
check "K: and still skips an OPEN one, so the mutant is not just broken" \
      "skipped-selection" "$(verdict_of "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== sandbox discipline (GH #15) ========================================"
ESCAPES="$(grep -l 'STUB REFUSED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no stub ever had to refuse a git add/commit" "" "$ESCAPES"
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
