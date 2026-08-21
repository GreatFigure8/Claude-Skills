#!/usr/bin/env bash
# Fixture harness for SUPPLIED HEADER FACTS (epic 09 item 2) in the unattended
# runner:  ../../bin/unattended-intake.sh
#
# THE DEFECT, MEASURED RATHER THAN RECALLED. Two of seven unattended proposals
# drafted for the LODE repo declared `**Live branch:** dev` when live is `main`
# and `dev` is the INTEGRATION branch (LODE #741, #739 — read from their merge
# commits 3fae7e32 and 03caa6d5). That is 29% of the sample, on the exact field
# the workflow's first invariant — the live branch is never written to — is
# written in terms of. The plan body was grounded in the repo; the header was
# filled in from recall, which is why excellent body and wrong header coexisted
# in one document.
#
# THE FIX UNDER TEST, in two halves:
#   1. `gh repo view --json defaultBranchRef` runs UNCONDITIONALLY. It used to
#      run only in the `else` arm of the base-branch resolution, so a repo with
#      a `|base` override in the repos list never resolved its live branch at
#      all — and a repo that overrides its base is exactly a repo whose live and
#      integration branches differ. LODE is that repo. Both bad headers came
#      from it.
#   2. The live branch, the integration branch and the epics directory are
#      injected into the drafter PROMPT as STATED FACTS, with an explicit
#      prohibition on inferring them, and `unknown` — never a plausible guess —
#      where a fact could not be resolved.
#
# Cases:
#   A  claude-skills shape (no override, default main) -> live=main integration=main
#   B  LODE shape (`|dev` override, default main)      -> live=main integration=dev
#      …and the default-branch query is OBSERVED to have run despite the override
#   C  the query fails / returns null -> live=unknown, logged, never a guess;
#      with and without a base override, and the integration branch keeps its
#      pre-item-2 behaviour in both
#   D  --dry-run reports both resolved values per repo and mutates nothing
#   E  two repos of different shapes in ONE run: each resolves its own facts
#   F  the prompt regressions: the five hard stops, Status: planning and item 1's
#      recommendation vocabulary all survive the insertion
#   G  MUTANT 1 (pre-item-2 resolution): make the query conditional again and
#      case B's `main` becomes `unknown`
#   H  MUTANT 2 (pre-item-2 prompt): remove the two supplied values and a
#      faithful drafter has nothing to copy — with the recall drafter this
#      REPRODUCES LODE #741's exact wrong header, and the fixed runner fixes it
#   I  the gh stub answers every verb the runner actually invokes
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT.
# It proves the runner RESOLVES both facts correctly for both configured repo
# shapes, SUPPLIES them, logs them, and degrades to `unknown` rather than to a
# guess — and that a drafter which honours the prompt therefore writes the
# header LODE #741 got wrong. It does NOT prove that a live model honours the
# prompt: case H shows a defiant "recall" drafter still writing `dev` against
# the FIXED runner, because nothing here can compel a model. That residual is
# the plan's own risk row ("header facts are passed in but the drafter
# overwrites them anyway"), and only a live draft per repo can retire it.
#
# THE STUB LESSON THIS HARNESS OBEYS (epic 09 item 1's post-mortem): a stub that
# cannot answer a query does not fail — it silently degrades, and the whole
# suite goes green while exercising a fallback path. So this gh stub answers
# every verb the runner invokes, EXITS LOUDLY on any verb it does not know, and
# case I compares the verb list against the script itself. Every live case also
# asserts positively that the work-in-progress check ran and came back clear,
# rather than assuming it did.
#
# SANDBOX DISCIPLINE (GH #15 is open and unfixed: a harness here has already
# escaped its sandbox and committed a real working tree). Everything — origins,
# checkouts, worktree root, config, logs, stubs — lives under one `mktemp -d`
# removed on exit; every destructive path goes through sandboxed(); the stubs
# refuse to run outside it; and the repo this file lives in is fingerprinted
# before and after. Fixing GH #15 is not this item's job; not tripping it is.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-header-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$(cd "$TESTS_DIR/../../bin" && pwd)/unattended-intake.sh"
SKILL_REFS="$(cd "$TESTS_DIR/../../../.." && pwd)/references"
[ -f "$RUNNER" ]     || { echo "ERROR: not found: $RUNNER" >&2; exit 1; }
[ -d "$SKILL_REFS" ] || { echo "ERROR: not found: $SKILL_REFS" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-header-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0

# Every path this harness writes to, inits or commits in MUST live under
# $SANDBOX. Without this guard one clobbered variable is enough to make the
# harness operate on the developer's own checkout — which is GH #15.
sandboxed() { # $1 = path about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

# The ONLY git entry point in this file. Nothing runs git without naming a -C
# path first, and that path is checked before git ever starts.
git_sb() { # $1 = repo dir (inside the sandbox), rest = git args
  sandboxed "$1"
  GS_DIR="$1"; shift
  git -C "$GS_DIR" -c user.email=fixture@example.com -c user.name=fixture \
      -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

check() { # $1 label  $2 expected  $3 actual  [$4 variant]
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then VERDICT="PASS"; else VERDICT="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-60s %-9s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "${4:-}" "$2" "$3" "$VERDICT"
}

yesno() { if "$@"; then printf 'yes'; else printf 'no'; fi; }

# A header value that LOOKS like a branch name is the failure mode; `unknown` is
# the safe one. This names the difference so a case can assert on it.
guess_or_safe() { # $1 = the value written into the header
  case "${1:-}" in
    main|dev|master|trunk|develop) printf 'guess' ;;
    *) printf 'safe' ;;
  esac
}

# -------------------------------------------------- GH #15 tripwire (read only)
HOST_REPO="$(git -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
host_fingerprint() {
  [ -n "$HOST_REPO" ] || { printf 'no-host-repo'; return; }
  printf '%s|%s' "$(git -C "$HOST_REPO" rev-parse HEAD 2>/dev/null)" \
                 "$(git -C "$HOST_REPO" status --porcelain 2>/dev/null | sort | cksum)"
}
HOST_BEFORE="$(host_fingerprint)"

GIT_REAL="$(command -v git)" || { echo "ERROR: no git" >&2; exit 1; }

echo "sandbox: $SANDBOX"
echo "runner:  $RUNNER"
echo "bash:    $(/bin/bash --version | head -1)"
echo "git:     $(git --version)"
echo

# ============================================================================
# Stubs. Neither can reach the network, and both refuse to act outside the
# sandbox.
# ============================================================================
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

# --- stub gh ---------------------------------------------------------------
# Answers per REPO, keyed on the directory the runner cd'd into, because the
# whole point of case E is that two repos in one run get different answers.
#   $OUT/default-branch.<repokey>   what `repo view --json defaultBranchRef`
#                                   returns: a branch name, the literal `null`,
#                                   or `FAIL` to make the query itself fail
#   $OUT/slug.<repokey>             what `repo view --json nameWithOwner` returns
# An unknown verb is a LOUD failure, never a shrug: a stub that cannot answer a
# query silently degrades the code under test (epic 09 item 1's post-mortem).
cat > "$BIN/gh" <<'GHSTUB'
#!/usr/bin/env bash
set -u
OUT="${FIXTURE_OUT:?FIXTURE_OUT unset}"
case "$OUT" in "${FIXTURE_SANDBOX:?}"/*) ;; *) echo "gh stub ABORT: out dir outside sandbox" >&2; exit 9 ;; esac
mkdir -p "$OUT"
RK="$(basename "$(pwd -P)")"
printf '%s\n' "${1:-} ${2:-} ${3:-}" >> "$OUT/gh-calls.log"
printf '%s | %s\n' "$RK" "$*" >> "$OUT/gh-calls-full.log"

arg_after() { # $1 = flag, rest = argv
  AA_WANT="$1"; shift
  while [ $# -gt 0 ]; do
    if [ "$1" = "$AA_WANT" ]; then printf '%s' "${2:-}"; return 0; fi
    shift
  done
  return 1
}
per_repo() { # $1 = kind, $2 = default
  if   [ -f "$OUT/$1.$RK" ]; then cat "$OUT/$1.$RK"
  elif [ -f "$OUT/$1" ];     then cat "$OUT/$1"
  else printf '%s\n' "$2"
  fi
}

case "${1:-} ${2:-}" in
  "repo view")
    case "$*" in
      *defaultBranchRef*)
        printf 'defaultBranchRef %s\n' "$RK" >> "$OUT/default-branch-queries.log"
        V="$(per_repo default-branch main | head -1)"
        [ "$V" = FAIL ] && { echo 'gh: could not resolve default branch' >&2; exit 1; }
        [ -n "$V" ] && printf '%s\n' "$V"
        ;;
      *nameWithOwner*) per_repo slug 'fixture/repo' | head -1 ;;
      *) echo "gh stub: unhandled repo view [$*]" >&2
         printf 'repo view %s\n' "$*" >> "$OUT/gh-unhandled.log"; exit 1 ;;
    esac ;;
  "label list")   printf 'claude-intake\tRun unattended intake\n' ;;
  "label create") printf 'label create %s\n' "$*" >> "$OUT/gh-unexpected.log" ;;
  "issue list")   per_repo issues '' ;;
  "issue view")   per_repo issue-title 'Fix the widget' ;;
  "issue comment") arg_after --body "$@" >> "$OUT/issue-comments.log" ;;
  "issue edit")   : ;;
  "api "*|"api")
    # The work-in-progress check's queries. Each api PATH is answered from its
    # own file and counted separately: a catch-all that answered every api call
    # with the timeline's answer file would have handed epic 09 item 7's branch
    # listing a list of PR numbers and called it a branch list — answering the
    # wrong question is the same defect as answering none (item 1's post-mortem),
    # it just looks greener. Both default to empty, which is the `clear` path
    # every case in this file means to be on.
    case "$*" in
      */issues/*/timeline*)
        printf 'x' >> "$OUT/api-calls"                 # item 3's timeline query
        cat "$OUT/timeline-prs.txt" 2>/dev/null || true ;;
      */branches*)
        printf 'x' >> "$OUT/branch-calls"              # item 7's branch listing
        cat "$OUT/origin-branches.txt" 2>/dev/null || true ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"
         printf 'gh stub: unhandled api path [%s]\n' "$*" >&2
         exit 1 ;;
    esac ;;
  "pr view")      cat "$OUT/wip-pr.txt" 2>/dev/null || true ;;
  "pr list")
    # The collision check's open-proposal enumeration (epic 09 item 4). Answered
    # DELIBERATELY, and deliberately EMPTY: none of the cases here has a second
    # open proposal, so the collision check finds nothing to rule out and this
    # suite stays about header facts. Answering it explicitly is the difference
    # between "no other proposal exists" and "nobody asked" — the second is the
    # silent degradation the `*)` arm below exists to prevent.
    #
    # The field set is pinned exactly, trailing space included, so a widened
    # query does not go on being answered in the old shape.
    case "$* " in
      *"--json number,headRefName "*) ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"
         printf 'gh stub: pr list field set not modelled [%s]\n' "$*" >&2
         exit 1 ;;
    esac
    printf '%s' "" ;;
  "pr create")
    arg_after --title "$@" > "$OUT/pr-title.txt"
    arg_after --body  "$@" > "$OUT/pr-body.txt"
    arg_after --base  "$@" > "$OUT/pr-base.txt"
    printf '%s %s\n' "$(arg_after --base "$@")" "$(arg_after --head "$@")" >> "$OUT/pr-creates.log"
    printf 'https://github.com/fixture/repo/pull/1\n' ;;
  *)
    # The lesson of epic 09 item 1: an unanswered query must be a failure, not a
    # quiet fallback. If a neighbouring item teaches the runner a new gh verb,
    # this fires instead of the suite going green on a degraded path.
    printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"
    printf 'gh stub: unhandled [%s]\n' "$*" >&2
    exit 1 ;;
esac
exit 0
GHSTUB

# --- stub claude (the drafter) ---------------------------------------------
# Two behaviours, chosen by FIXTURE_DRAFTER:
#   faithful  copies the SUPPLIED header facts out of the prompt into the plan
#             header — what a compliant drafter does, and the only thing the
#             runner can actually ask for
#   recall    ignores the prompt and writes `**Live branch:** dev` from memory —
#             LODE #741 / #739 reproduced exactly
# `MISSING-FACT` is written when the prompt carried no such fact at all, which
# is how the pre-item-2 prompt is told apart from a resolved `unknown`.
cat > "$BIN/claude" <<'CLSTUB'
#!/usr/bin/env bash
set -u
OUT="${FIXTURE_OUT:?FIXTURE_OUT unset}"
HERE="$(pwd -P)"
case "$HERE" in "${FIXTURE_SANDBOX:?}"/*) ;; *) echo "claude stub ABORT: cwd outside sandbox: $HERE" >&2; exit 9 ;; esac

PROMPT=""
while [ $# -gt 0 ]; do
  case "$1" in -p) PROMPT="${2:-}" ;; esac
  shift
done

PLANPATH="$(printf '%s' "$PROMPT" | grep -oE '[A-Za-z]+/[A-Za-z]+/proposed-[A-Za-z0-9._-]+/plan\.md' | head -1)"
[ -n "$PLANPATH" ] || { echo "claude stub: no plan path found in prompt" >&2; exit 9; }
case "$PLANPATH" in /*) echo "claude stub ABORT: absolute plan path" >&2; exit 9 ;; esac

PROPOSAL="$(basename "$(dirname "$PLANPATH")")"
printf '%s' "$PROMPT" > "$OUT/prompt.txt"
printf '%s' "$PROMPT" > "$OUT/prompt-$PROPOSAL.txt"

field() { # $1 = header label -> the supplied value, or MISSING-FACT
  V="$(printf '%s\n' "$PROMPT" | sed -n -E "s/^[[:space:]]*\\*\\*$1:\\*\\*[[:space:]]*//p" | head -1)"
  [ -n "$V" ] && printf '%s' "$V" || printf 'MISSING-FACT'
}

case "${FIXTURE_DRAFTER:-faithful}" in
  recall)
    # A drafter filling the header in from memory: LODE integrates on dev, and
    # `dev` is the branch it names as live. This is the observed defect.
    LIVE=dev
    INTEG=main ;;
  *)
    LIVE="$(field 'Live branch')"
    INTEG="$(field 'Integration branch')" ;;
esac

# Belt and braces against GH #15: the cwd check above is only trustworthy if the
# repository that cwd belongs to is also inside the sandbox. Checked before any
# write, because `git commit` from a stray cwd is the escape that defect names.
TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
case "$TOP" in "$FIXTURE_SANDBOX"/*) ;; *) echo "claude stub ABORT: repo outside sandbox: [$TOP]" >&2; exit 9 ;; esac

mkdir -p "$(dirname "$PLANPATH")"
{ printf '# Epic: fixture proposal\n\n'
  printf '**Status:** planning\n'
  printf '**Recommendation:** plan\n'
  printf '**Source:** GH #%s\n' "$(printf '%s' "$PROPOSAL" | sed -E 's/^proposed-([0-9]+)-.*/\\1/')"
  printf '**Live branch:** %s\n' "$LIVE"
  printf '**Integration branch:** %s\n' "$INTEG"
  printf '**Pre-epic tag:** n/a\n\n'
  printf '## Outcome\nA fixture proposal.\n'; } > "$PLANPATH"

git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    add "$PLANPATH" >/dev/null 2>&1 || exit 9
git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    commit -qm "docs: proposed epic plan (fixture drafter)" >/dev/null 2>&1 || exit 9
exit 0
CLSTUB

chmod +x "$BIN/gh" "$BIN/claude"
/bin/bash -n "$BIN/gh"     || { echo "ERROR: gh stub does not parse" >&2; exit 1; }
/bin/bash -n "$BIN/claude" || { echo "ERROR: claude stub does not parse" >&2; exit 1; }

# The two references the runner preflights on, copied so no run can depend on
# anything else in the real skill tree.
SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
cp "$SKILL_REFS/issue-intake.md" "$SKILL_REFS/plan-template.md" "$SKILL/references/"

ENVF="$SANDBOX/env"; sandboxed "$ENVF"
printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-not-a-real-token\n' > "$ENVF"
chmod 600 "$ENVF"

# ============================================================================
# Scenario plumbing
# ============================================================================
mk_repo() { # $1 = run dir, $2 = name, rest = extra branches to create on origin
  sandboxed "$1"
  MR_DIR="$1"; MR_NAME="$2"; shift 2
  mkdir -p "$MR_DIR/$MR_NAME.git" "$MR_DIR/$MR_NAME"
  git_sb "$MR_DIR/$MR_NAME.git" init -q --bare
  git_sb "$MR_DIR/$MR_NAME" init -q
  git_sb "$MR_DIR/$MR_NAME" checkout -q -b main 2>/dev/null || git_sb "$MR_DIR/$MR_NAME" branch -q -m main
  mkdir -p "$MR_DIR/$MR_NAME/docs/epics/01-existing"
  printf '# Epic: existing\n\n**Status:** closed\n' > "$MR_DIR/$MR_NAME/docs/epics/01-existing/plan.md"
  git_sb "$MR_DIR/$MR_NAME" add -A >/dev/null 2>&1
  git_sb "$MR_DIR/$MR_NAME" commit -qm "fixture base" >/dev/null 2>&1
  git_sb "$MR_DIR/$MR_NAME" remote add origin "$MR_DIR/$MR_NAME.git"
  git_sb "$MR_DIR/$MR_NAME" push -q -u origin main >/dev/null 2>&1
  # Extra branches DIVERGE from main by one commit, so "this branch was cut
  # from origin/dev" is an observable fact and not an accident of them being
  # the same commit.
  for B in "$@"; do
    git_sb "$MR_DIR/$MR_NAME" checkout -q -b "$B" main
    printf 'integration branch marker\n' > "$MR_DIR/$MR_NAME/.$B-marker"
    git_sb "$MR_DIR/$MR_NAME" add -A >/dev/null 2>&1
    git_sb "$MR_DIR/$MR_NAME" commit -qm "fixture: $B diverges from main" >/dev/null 2>&1
    git_sb "$MR_DIR/$MR_NAME" push -q origin "$B" >/dev/null 2>&1
    git_sb "$MR_DIR/$MR_NAME" checkout -q main
  done
}

# $1 = case id; then env: REPOS_LINES, plus per-repo out/ seed files
# Sets RUN_DIR and RUN_RC.
run_intake() { # $1 = case id, rest = extra runner args
  RUN_DIR="$SANDBOX/run-$1"; sandboxed "$RUN_DIR"
  RC_ID="$1"; shift
  INTAKE_GIT="$GIT_REAL" \
  INTAKE_GH="$BIN/gh" \
  INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_SKILL_DIR="$SKILL" \
  INTAKE_ENV_FILE="$ENVF" \
  INTAKE_REPO_LIST="$RUN_DIR/repos" \
  INTAKE_REPO_DIR="$RUN_DIR/nonexistent-fallback" \
  INTAKE_LOG="$RUN_DIR/intake.log" \
  INTAKE_LOCK="$RUN_DIR/lock" \
  INTAKE_WORKTREE_ROOT="$RUN_DIR/wt" \
  INTAKE_LABEL=claude-intake \
  FIXTURE_OUT="$RUN_DIR/out" \
  FIXTURE_SANDBOX="$SANDBOX" \
  FIXTURE_DRAFTER="${DRAFTER:-faithful}" \
  FIXTURE_ISSUE="${ISSUE:-757}" \
  HOME="$RUN_DIR/home" \
    /bin/bash "${RUNNER_UNDER_TEST:-$RUNNER}" --once "$@" > "$RUN_DIR/run.out" 2>&1
  RUN_RC=$?
}

new_run() { # $1 = case id -> a clean run dir with the standard single repo
  RUN_DIR="$SANDBOX/run-$1"; sandboxed "$RUN_DIR"
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR/out" "$RUN_DIR/wt" "$RUN_DIR/home"
}

out() { printf '%s' "$(cat "$RUN_DIR/out/$1" 2>/dev/null)"; }

# The plan as it was actually PUSHED — the artifact a reviewer reads, not the
# prompt we hoped it obeyed.
pushed_field() { # $1 = origin bare dir, $2 = branch, $3 = proposal dir, $4 = label
  git_sb "$1" show "$2:docs/epics/$3/plan.md" 2>/dev/null \
    | sed -n -E "s/^\\*\\*$4:\\*\\*[[:space:]]*//p" | head -1
}

ISSUE=757
SLUG="fix-the-widget"
PROPOSAL="proposed-${ISSUE}-${SLUG}"
BRANCH="intake/proposed-${ISSUE}-${SLUG}"

# One standard single-repo scenario. $1 = case id, $2 = base override ("" = none),
# $3 = what the default-branch query returns (branch | null | FAIL)
setup_one() {
  new_run "$1"
  mk_repo "$RUN_DIR" repo dev
  if [ -n "$2" ]; then printf '%s|%s\n' "$RUN_DIR/repo" "$2" > "$RUN_DIR/repos"
  else printf '%s\n' "$RUN_DIR/repo" > "$RUN_DIR/repos"; fi
  printf '%s\n' "$ISSUE" > "$RUN_DIR/out/issues"
  printf 'Fix the widget\n'  > "$RUN_DIR/out/issue-title"
  printf '%s\n' "$3"         > "$RUN_DIR/out/default-branch"
}

# Positive proof that the run took the path this suite thinks it took: the
# work-in-progress check RAN (twice, selection + pre-PR) and came back clear.
# Without this, a stub that stopped answering the timeline query would put every
# case on the degraded `unknown` path with the suite still green — which is
# exactly what happened to epic 09 item 1.
wip_ran_clear() { # -> "2 clear" when the check ran twice and never degraded
  printf '%s %s' "$(wc -c < "$RUN_DIR/out/api-calls" 2>/dev/null | tr -d ' ')" \
    "$(grep -q 'could not run' "$RUN_DIR/run.out" && echo degraded || echo clear)"
}

# Same guard for the second query the check makes (epic 09 item 7): a clear
# verdict means "no PR closes it, no PR is part of it, and no branch is named
# for it", and the third clause is only true if the branch listing was actually
# asked for. One call per evaluation, so twice per drafted issue.
wip_branch_query_ran() { # -> "2" when the branch listing was asked both times
  wc -c < "$RUN_DIR/out/branch-calls" 2>/dev/null | tr -d ' '
}

# ============================================================================
echo "=== A. claude-skills shape: no override, GitHub default main ==========="
echo "    (live and integration are the same branch here — and they are still"
echo "     two separate facts, both supplied)"
setup_one A "" main
run_intake A
check "runner exit status" "0" "$RUN_RC" "A"
check "the log states BOTH resolved branches" "1" \
      "$(grep -c 'live=main integration=main' "$RUN_DIR/run.out" | tr -d ' ')" "A"
check "prompt supplies the live branch" "main" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "A"
check "prompt supplies the integration branch" "main" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Integration branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "A"
check "prompt supplies the epics directory" "1" \
      "$(grep -c 'keeps its epics in docs/epics/' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "prompt forbids inferring the two values" "1" \
      "$(grep -c 'Do NOT infer, re-derive or improve those two branch values' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "prompt demands unknown rather than a plausible guess" "1" \
      "$(grep -c 'Never substitute a plausible-looking branch name' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "prompt leaves Pre-epic tag to the drafter" "1" \
      "$(grep -c 'Pre-epic tag:\*\* is NOT supplied' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "the PUSHED plan header reads live=main" "main" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "A"
check "the PUSHED plan header reads integration=main" "main" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Integration branch')" "A"
check "the PR is opened against the integration branch" "main" "$(out pr-base.txt)" "A"
check "the WIP check ran twice and came back clear" "2 clear" "$(wip_ran_clear)" "A"
check "…and its branch listing ran both times too" "2" "$(wip_branch_query_ran)" "A"
check "no gh verb went unanswered" "no" "$(yesno test -s "$RUN_DIR/out/gh-unhandled.log")" "A"

# ============================================================================
echo
echo "=== B. LODE shape: |dev override, GitHub default main =================="
echo "    (the case both known-bad headers came from: live main, integrate dev)"
setup_one B dev main
run_intake B
check "runner exit status" "0" "$RUN_RC" "B"
check "the log states BOTH resolved branches" "1" \
      "$(grep -c 'live=main integration=dev' "$RUN_DIR/run.out" | tr -d ' ')" "B"
check "the default-branch query RAN despite the base override" "1" \
      "$(grep -c 'defaultBranchRef' "$RUN_DIR/out/default-branch-queries.log" | tr -d ' ')" "B"
check "prompt supplies live=main" "main" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "B"
check "prompt supplies integration=dev" "dev" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Integration branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "B"
check "the PUSHED plan reads Live branch: main" "main" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "B"
check "…and NOT dev, which is what LODE #741 and #739 said" "no" \
      "$(yesno test "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" = dev)" "B"
check "the PUSHED plan reads Integration branch: dev" "dev" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Integration branch')" "B"
check "the PR is opened against dev, not main" "dev" "$(out pr-base.txt)" "B"
check "the proposal branch was cut from dev, not from main" "yes" \
      "$(yesno git_sb "$RUN_DIR/repo.git" merge-base --is-ancestor dev "$BRANCH")" "B"
check "the WIP check ran twice and came back clear" "2 clear" "$(wip_ran_clear)" "B"
check "…and its branch listing ran both times too" "2" "$(wip_branch_query_ran)" "B"
check "no gh verb went unanswered" "no" "$(yesno test -s "$RUN_DIR/out/gh-unhandled.log")" "B"

# ============================================================================
echo
echo "=== C. an unresolvable live branch is 'unknown', never a guess ========="
echo "    (and the INTEGRATION branch keeps its pre-item-2 behaviour: the"
echo "     override wins, and without one it still falls back to main)"
setup_one C-fail dev FAIL
run_intake C-fail
check "runner exit status" "0" "$RUN_RC" "C-fail"
check "the log says live=unknown" "1" \
      "$(grep -c 'live=unknown integration=dev' "$RUN_DIR/run.out" | tr -d ' ')" "C-fail"
check "the reason is logged, so it is never silent" "1" \
      "$(grep -c "WARN: could not resolve the live (default) branch" "$RUN_DIR/run.out" | tr -d ' ')" "C-fail"
check "the drafter is told unknown" "unknown" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "C-fail"
check "the PUSHED plan says unknown" "unknown" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "C-fail"
check "…and never a plausible branch name" "safe" \
      "$(guess_or_safe "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')")" "C-fail"
check "the integration branch is unaffected" "dev" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Integration branch')" "C-fail"

# `gh ... -q .defaultBranchRef.name` prints the literal string `null` when a
# repo has no default branch at all. That is normalised for the LIVE branch —
# it is not a branch name and must never reach a plan header — but the
# INTEGRATION path is left exactly as it was before this item: `null` is not a
# branch on origin, so the repo is skipped with a logged reason. Changing that
# would be turning a fail-closed into a fallback, which is not this item's call.
setup_one C-null "" null
run_intake C-null
check "a literal null default is not a live branch either" "1" \
      "$(grep -c "WARN: could not resolve the live (default) branch" "$RUN_DIR/run.out" | tr -d ' ')" "C-null"
check "…and the integration path still fails closed, unchanged" "1" \
      "$(grep -c "skip: base branch 'null' does not exist on origin" "$RUN_DIR/run.out" | tr -d ' ')" "C-null"
check "…without failing the run" "0" "$RUN_RC" "C-null"

setup_one C-nobase "" FAIL
run_intake C-nobase
check "no override + failed query: live is unknown" "unknown" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "C-nobase"
check "…and the integration branch still falls back to main (unchanged)" "main" \
      "$(out pr-base.txt)" "C-nobase"
check "…so a repo whose config says nothing still gets drafted" "0" "$RUN_RC" "C-nobase"

# ============================================================================
echo
echo "=== D. --dry-run reports both values and mutates nothing ==============="
setup_one D dev main
run_intake D --dry-run
check "runner exit status" "0" "$RUN_RC" "D"
check "both resolved branches are in the dry-run log" "1" \
      "$(grep -c 'live=main integration=dev' "$RUN_DIR/run.out" | tr -d ' ')" "D"
check "no PR was created" "no" "$(yesno test -f "$RUN_DIR/out/pr-creates.log")" "D"
check "no issue comment" "no" "$(yesno test -f "$RUN_DIR/out/issue-comments.log")" "D"
check "no label edit" "0" \
      "$(grep -c '^issue edit' "$RUN_DIR/out/gh-calls.log" | tr -d ' ')" "D"
check "the drafter never ran" "no" "$(yesno test -f "$RUN_DIR/out/prompt.txt")" "D"
check "no worktree was created" "" \
      "$(ls -A "$RUN_DIR/wt" 2>/dev/null)" "D"
check "no branch was created on origin" "" \
      "$(git_sb "$RUN_DIR/repo.git" for-each-ref --format='%(refname:short)' 'refs/heads/intake/*')" "D"
check "origin/main is where it was" \
      "$(git_sb "$RUN_DIR/repo" rev-parse main)" \
      "$(git_sb "$RUN_DIR/repo.git" rev-parse main)" "D"
check "not even a log file was written" "no" "$(yesno test -f "$RUN_DIR/intake.log")" "D"

# ============================================================================
echo
echo "=== E. two repos, two shapes, ONE run: each gets its OWN answer ========"
echo "    (repo1 resolves main; repo2's query fails and must come back unknown."
echo "     Nothing repo1 resolved may show up in repo2's prompt: a header value"
echo "     that came from a different repo is the defect, whatever produced it)"
new_run E
mk_repo "$RUN_DIR" repo1
mk_repo "$RUN_DIR" repo2 dev
{ printf '%s\n' "$RUN_DIR/repo1"; printf '%s|dev\n' "$RUN_DIR/repo2"; } > "$RUN_DIR/repos"
printf '758\n'  > "$RUN_DIR/out/issues.repo1"
printf '759\n'  > "$RUN_DIR/out/issues.repo2"
printf 'main\n' > "$RUN_DIR/out/default-branch.repo1"
printf 'FAIL\n' > "$RUN_DIR/out/default-branch.repo2"
printf 'fixture/one\n' > "$RUN_DIR/out/slug.repo1"
printf 'fixture/two\n' > "$RUN_DIR/out/slug.repo2"
run_intake E
check "runner exit status" "0" "$RUN_RC" "E"
check "repo1 resolves live=main integration=main" "1" \
      "$(grep -c 'fixture/one .* live=main integration=main' "$RUN_DIR/run.out" | tr -d ' ')" "E"
check "repo2 resolves live=unknown integration=dev" "1" \
      "$(grep -c 'fixture/two .* live=unknown integration=dev' "$RUN_DIR/run.out" | tr -d ' ')" "E"
check "repo2's prompt does not carry repo1's main" "unknown" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' \
           "$RUN_DIR/out/prompt-proposed-759-fix-the-widget.txt" | head -1)" "E"
check "repo1's prompt still says main" "main" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' \
           "$RUN_DIR/out/prompt-proposed-758-fix-the-widget.txt" | head -1)" "E"
check "both repos opened a PR, against their own bases" "$(printf 'main intake/proposed-758-fix-the-widget\ndev intake/proposed-759-fix-the-widget')" \
      "$(cat "$RUN_DIR/out/pr-creates.log" 2>/dev/null)" "E"

# ============================================================================
echo
echo "=== F. the insertion did not damage the rest of the prompt ============="
P="$SANDBOX/run-A/out/prompt.txt"
check "the five hard stops are still there" "5" \
      "$(grep -cE '^    - Do NOT ' "$P" | tr -d ' ')" "F"
check "Status: planning is still pinned (header + item 1's restatement)" "2" \
      "$(grep -c '\*\*Status:\*\* planning' "$P" | tr -d ' ')" "F"
check "item 1's vocabulary is untouched" "1" \
      "$(grep -c 'plan | no-work | needs-decision' "$P" | tr -d ' ')" "F"
check "…and its preferred-outputs sentence" "1" \
      "$(grep -c 'CORRECT, PREFERRED outputs' "$P" | tr -d ' ')" "F"
check "the plan path is still absolute-free and proposal-scoped" "1" \
      "$(grep -c 'docs/epics/proposed-757-fix-the-widget/plan.md' "$P" | tr -d ' ')" "F"
check "the recommendation still reached the PR title" \
      "intake: proposed epic for #757 — fix-the-widget" \
      "$(cat "$SANDBOX/run-A/out/pr-title.txt" 2>/dev/null)" "F"

# ============================================================================
echo
echo "=== G. MUTANT 1 — make the query conditional again (pre-item-2) ========"
echo "    (this is the bug: with a |base override the live branch is never"
echo "     resolved. Case B's 'main' becomes 'unknown', so case B is testing"
echo "     the unconditional fetch and nothing incidental. Note the degraded"
echo "     value is still 'unknown' and not a guess — that part fails safe.)"
MUT1="$SANDBOX/unattended-intake.conditional.sh"; sandboxed "$MUT1"
sed -e 's@^  DEFAULT_BRANCH="\$("\$GH_BIN" repo view@  [ -n "$BASE_OVERRIDE" ] || DEFAULT_BRANCH="$("$GH_BIN" repo view@' \
    "$RUNNER" > "$MUT1"
cmp -s "$RUNNER" "$MUT1" && {
  echo "ERROR: mutant 1 is identical to the runner — the query line moved, so" >&2
  echo "       case B would be proving nothing. Fix the sed above." >&2; exit 1; }
grep -q '\[ -n "$BASE_OVERRIDE" \] || DEFAULT_BRANCH=' "$MUT1" || {
  echo "ERROR: mutant 1 did not gain the override guard" >&2; exit 1; }
/bin/bash -n "$MUT1" || { echo "ERROR: mutant 1 does not parse" >&2; exit 1; }

RUNNER_UNDER_TEST="$MUT1"
setup_one G-lode dev main
run_intake G-lode
check "mutant: the LODE shape loses its live branch" "unknown" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "mutant1"
check "mutant: the default-branch query never ran" "no" \
      "$(yesno test -f "$RUN_DIR/out/default-branch-queries.log")" "mutant1"
check "mutant: so case B's expectation does NOT hold there" "differs" \
      "$([ "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" = main ] \
        && echo same || echo differs)" "mutant1"
check "mutant: the integration branch is still right (only live regressed)" "dev" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Integration branch')" "mutant1"
# …and the no-override shape must be IDENTICAL either way, so the mutant cannot
# be waved away as "it differs on everything".
setup_one G-plain "" main
run_intake G-plain
cp "$RUN_DIR/out/prompt.txt" "$SANDBOX/G-plain-mutant-prompt.txt"
RUNNER_UNDER_TEST="$RUNNER"
setup_one G-plain2 "" main
run_intake G-plain2
check "mutant and runner agree byte for byte with no override" "" \
      "$(diff "$SANDBOX/G-plain-mutant-prompt.txt" "$RUN_DIR/out/prompt.txt" | head -10)" "mutant1"

# ============================================================================
echo
echo "=== H. MUTANT 2 — the pre-item-2 prompt, and LODE #741 reproduced ======"
echo "    (strip the two supplied values from the prompt and the header is the"
echo "     drafter's to recall again. With the recall drafter that reproduces"
echo "     the exact wrong header from LODE #741/#739; the fixed runner plus a"
echo "     faithful drafter is what fixes it.)"
MUT2="$SANDBOX/unattended-intake.nofacts.sh"; sandboxed "$MUT2"
sed -e '/^    \*\*Live branch:\*\* ${LIVE_BRANCH}$/d' \
    -e '/^    \*\*Integration branch:\*\* ${BASE_BRANCH}$/d' "$RUNNER" > "$MUT2"
cmp -s "$RUNNER" "$MUT2" && {
  echo "ERROR: mutant 2 is identical to the runner — the supplied-fact lines" >&2
  echo "       moved, so cases A/B would be proving nothing. Fix the sed." >&2; exit 1; }
grep -q '\*\*Live branch:\*\* ${LIVE_BRANCH}' "$MUT2" && {
  echo "ERROR: mutant 2 still supplies the live branch" >&2; exit 1; }
/bin/bash -n "$MUT2" || { echo "ERROR: mutant 2 does not parse" >&2; exit 1; }

RUNNER_UNDER_TEST="$MUT2"
setup_one H-nofacts dev main
run_intake H-nofacts
check "mutant: the prompt carries no live-branch fact at all" "MISSING-FACT" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "mutant2"

# The defect itself: no supplied fact + a drafter working from recall.
DRAFTER=recall
setup_one H-741 dev main
run_intake H-741
check "REPRODUCED: LODE #741's header — Live branch: dev" "dev" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "mutant2"

# The fix: the same drafter, but honouring the supplied facts.
DRAFTER=faithful
RUNNER_UNDER_TEST="$RUNNER"
setup_one H-fixed dev main
run_intake H-fixed
check "FIXED: the same repo shape now reads Live branch: main" "main" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "fixed"

# And the honest limit of a hermetic fixture: the runner supplies the fact, it
# cannot compel a model to use it. This case is expected to be WRONG, and says
# so — it is the plan's residual risk row, and only a live draft retires it.
DRAFTER=recall
setup_one H-defiant dev main
run_intake H-defiant
check "a drafter that ignores the prompt is still wrong (not fixable here)" "dev" \
      "$(pushed_field "$RUN_DIR/repo.git" "$BRANCH" "$PROPOSAL" 'Live branch')" "residual"
check "…and the runner did supply the right value anyway" "main" \
      "$(sed -n -E 's/^[[:space:]]*\*\*Live branch:\*\*[[:space:]]*//p' "$RUN_DIR/out/prompt.txt" | head -1)" "residual"
DRAFTER=faithful

# ============================================================================
echo
echo "=== I. the stub answers every gh verb the runner actually invokes ======"
echo "    (epic 09 item 1's post-mortem: a stub that cannot answer a query does"
echo "     not fail, it silently degrades. If a neighbouring item teaches the"
echo "     runner a new verb, this check fails instead of the suite lying.)"
check "gh verbs in the runner" "api issue label pr repo" \
      "$(grep -oE '"\$GH_BIN" [a-z]+' "$RUNNER" | awk '{print $2}' | sort -u | tr '\n' ' ' | sed -e 's/ $//')" "I"
check "no case left a gh call unanswered" "" \
      "$(cat "$SANDBOX"/run-*/out/gh-unhandled.log 2>/dev/null | sort -u | head -5)" "I"
check "no unexpected mutating gh call (label create)" "" \
      "$(cat "$SANDBOX"/run-*/out/gh-unexpected.log 2>/dev/null | head -3)" "I"
check "the runner's gh calls are the known, non-merging set" "" \
      "$(cat "$SANDBOX"/run-*/out/gh-calls.log 2>/dev/null \
         | grep -vE '^(repo view|label list|issue list|issue view|issue comment|issue edit|pr create|pr view|pr list|api --paginate)' \
         | sort -u | head -5)" "I"

# ============================================================================
echo
echo "=== sandbox discipline (GH #15) ========================================"
check "the host repo did not move (HEAD + working tree)" "$HOST_BEFORE" "$(host_fingerprint)"
check "no stub ever had to abort (a sandbox escape would say so)" "" \
      "$(grep -h 'ABORT' "$SANDBOX"/run-*/run.out 2>/dev/null | sort -u | head -3)"
check "every worktree the runner made was cleaned up inside the sandbox" "" \
      "$(find "$SANDBOX"/run-*/wt -mindepth 1 -maxdepth 1 2>/dev/null | head -3)"
check "nothing was written to a real HOME" "" \
      "$(find "$SANDBOX"/run-*/home -mindepth 1 2>/dev/null | head -3)"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
