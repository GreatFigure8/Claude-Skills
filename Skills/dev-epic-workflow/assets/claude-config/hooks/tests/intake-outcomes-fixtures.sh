#!/usr/bin/env bash
# Fixture harness for NON-APPROVAL OUTCOMES (epic 09 item 1) across both halves
# of the mechanism:
#   ../../bin/unattended-intake.sh     — reads `**Recommendation:**` back out of
#                                        the drafted plan and carries it into the
#                                        PR title, the PR body and the issue comment
#   ../session-start-context.sh        — renders the three values as queue lines
#
# The contract is references/issue-intake.md: a proposal declares exactly one
# terminal outcome — `plan` | `no-work` | `needs-decision` — and `no-work` and
# `needs-decision` are correct, preferred outputs rather than failures. Absent
# means `plan`; a value outside the vocabulary is logged verbatim and treated as
# `needs-decision` rather than silently read as an approvable plan.
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT.
# It proves the MECHANISM: that a declared outcome survives intact from the plan
# header to the PR, the issue and the session injection; that every outcome still
# opens a PR (one shape for all three); that an ordinary `plan` proposal is
# byte-identical to what the runner produced before this change; and that the
# five hard stops are untouched on a non-plan run.
# It does NOT prove that a live drafter, given a hard brief, actually chooses
# `no-work` over inventing a plan. That is a property of the model, not of this
# code, and no hermetic fixture can establish it — the drafter here is a stub
# replaying a canned draft. Measuring the real rate is epic 09 item 5's job.
#
# SANDBOXING (GH #15 is open and unfixed: a harness that escapes commits the
# developer's real working tree). Everything — the "GitHub" origin, the checkout,
# the worktree root, the config, the logs, the stub binaries — lives under one
# `mktemp -d` removed on exit. Every destructive path goes through sandboxed().
# No git command in this file, or in any stub it writes, ever names the repo the
# file lives in: the stubs refuse to run at all if their cwd is outside the
# sandbox, which is the exact point where an escape would otherwise commit real
# work. Nothing is installed; ~/.claude and ~/.config are never read or written.
#
# The runner is driven entirely through its INTAKE_* overrides, with stub `gh`
# and stub `claude` binaries, so no network call and no model call is possible.
# INTAKE_REPO_LIST is pointed at a nonexistent file for the hook cases too, so
# the injection is identical on a machine that has configured unattended intake
# and one that has not.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-outcomes-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$HOOKS_DIR/session-start-context.sh"
RUNNER="$(cd "$HOOKS_DIR/../bin" && pwd)/unattended-intake.sh"
SKILL_REFS="$(cd "$HOOKS_DIR/../../.." && pwd)/references"
[ -f "$HOOK" ]   || { echo "ERROR: not found: $HOOK" >&2; exit 1; }
[ -f "$RUNNER" ] || { echo "ERROR: not found: $RUNNER" >&2; exit 1; }
[ -d "$SKILL_REFS" ] || { echo "ERROR: not found: $SKILL_REFS" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-outcomes-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0

# Every path this harness writes to, inits, commits in, or points a tool at MUST
# live under $SANDBOX. Without this guard one mistyped or clobbered variable is
# enough for `git -C "" add -A` (git treats an empty -C as "stay here") to commit
# the developer's own checkout — which is what GH #15 records happening.
sandboxed() { # $1 = path that is about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

# The ONLY git entry point in this file. Nothing may run git without naming a
# -C path first, and that path is checked before git ever starts.
git_sb() { # $1 = repo dir (must be inside the sandbox), rest = git args
  sandboxed "$1"
  GS_DIR="$1"; shift
  git -C "$GS_DIR" -c user.email=fixture@example.com -c user.name=fixture \
      -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

check() { # $1 label  $2 expected  $3 actual  $4 variant
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then VERDICT="PASS"; else VERDICT="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-58s %-7s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$4" "$2" "$3" "$VERDICT"
}

GIT_REAL="$(command -v git)" || { echo "ERROR: no git" >&2; exit 1; }

echo "sandbox: $SANDBOX"
echo "runner:  $RUNNER"
echo "hook:    $HOOK"
echo "bash:    $(/bin/bash --version | head -1)"
echo "git:     $(git --version)"
echo

# ============================================================================
# Stub binaries. Both refuse to do anything outside the sandbox.
# ============================================================================
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

# --- stub gh ---------------------------------------------------------------
# Records every invocation, answers the handful of queries the runner makes, and
# captures the two artifacts under test: the PR title/body and the issue comment.
# It can create nothing and reach nothing; there is no network path out of it.
cat > "$BIN/gh" <<'GHSTUB'
#!/usr/bin/env bash
set -u
OUT="${FIXTURE_OUT:?FIXTURE_OUT unset}"
case "$OUT" in "${FIXTURE_SANDBOX:?}"/*) ;; *) echo "gh stub ABORT: out dir outside sandbox" >&2; exit 9 ;; esac
mkdir -p "$OUT"
printf '%s\n' "${1:-} ${2:-} ${3:-}" >> "$OUT/gh-calls.log"

arg_after() { # $1 = flag, rest = argv
  AA_WANT="$1"; shift
  while [ $# -gt 0 ]; do
    if [ "$1" = "$AA_WANT" ]; then printf '%s' "${2:-}"; return 0; fi
    shift
  done
  return 1
}

case "${1:-} ${2:-}" in
  "repo view")
    case "$*" in
      *defaultBranchRef*) printf 'main\n' ;;
      *) printf 'fixture/repo\n' ;;
    esac ;;
  "label list")   printf 'claude-intake\tRun unattended intake\n' ;;
  "issue list")   cat "$OUT/issues.txt" 2>/dev/null ;;
  "issue view")   cat "$OUT/issue-title.txt" 2>/dev/null ;;
  "issue comment")
    arg_after --body "$@" > "$OUT/issue-comment.txt" ;;
  "issue edit")   : ;;
  "pr create")
    arg_after --title "$@" > "$OUT/pr-title.txt"
    arg_after --body  "$@" > "$OUT/pr-body.txt"
    arg_after --base  "$@" > "$OUT/pr-base.txt"
    printf 'https://github.com/fixture/repo/pull/1\n' ;;
  *) printf 'gh stub: unhandled [%s]\n' "$*" >&2; exit 1 ;;
esac
exit 0
GHSTUB

# --- stub claude (the drafter) ---------------------------------------------
# Stands in for the headless model run: it captures the PROMPT it was handed,
# finds the plan path the prompt names, writes the canned draft there and commits
# it — which is exactly the contract the real drafter is held to. It writes only
# relative to its cwd, and aborts if that cwd is not inside the sandbox.
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
printf '%s' "$PROMPT" > "$OUT/prompt.txt"

PLANPATH="$(printf '%s' "$PROMPT" | grep -oE '[A-Za-z]+/[A-Za-z]+/proposed-[A-Za-z0-9._-]+/plan\.md' | head -1)"
[ -n "$PLANPATH" ] || { echo "claude stub: no plan path found in prompt" >&2; exit 9; }
case "$PLANPATH" in /*) echo "claude stub ABORT: absolute plan path" >&2; exit 9 ;; esac

# Belt and braces against GH #15: the cwd check above can only be trusted if the
# repository that cwd belongs to is also inside the sandbox. Check it before any
# write, because `git commit` from a stray cwd is the escape that defect names.
TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
case "$TOP" in "$FIXTURE_SANDBOX"/*) ;; *) echo "claude stub ABORT: repo outside sandbox: [$TOP]" >&2; exit 9 ;; esac

mkdir -p "$(dirname "$PLANPATH")"
cat "${FIXTURE_DRAFT:?}" > "$PLANPATH"
git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    add "$PLANPATH" >/dev/null 2>&1 || exit 9
git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    commit -qm "docs: proposed epic plan (fixture drafter)" >/dev/null 2>&1 || exit 9
exit 0
CLSTUB

chmod +x "$BIN/gh" "$BIN/claude"
/bin/bash -n "$BIN/gh"     || { echo "ERROR: gh stub does not parse" >&2; exit 1; }
/bin/bash -n "$BIN/claude" || { echo "ERROR: claude stub does not parse" >&2; exit 1; }

# A skill dir with just the two references the runner preflights on. Copied, so
# the run cannot depend on anything else in the real skill tree.
SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
cp "$SKILL_REFS/issue-intake.md" "$SKILL_REFS/plan-template.md" "$SKILL/references/"

ENVF="$SANDBOX/env"; sandboxed "$ENVF"
printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-not-a-real-token\n' > "$ENVF"
chmod 600 "$ENVF"

# ============================================================================
# One complete runner scenario, from labelled issue to PR.
# ============================================================================
ISSUE=757
ISSUE_TITLE="Fix the widget"
SLUG="fix-the-widget"
PROPOSAL="docs/epics/proposed-${ISSUE}-${SLUG}"

# $1 = case id, $2 = the draft plan.md content (a file under $SANDBOX)
# Sets: RUN_DIR (all artifacts), RUN_RC (runner exit code)
run_intake() {
  RUN_DIR="$SANDBOX/run-$1"; sandboxed "$RUN_DIR"
  rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR/out" "$RUN_DIR/wt"

  # A local bare repo standing in for GitHub, and a checkout of it.
  git_sb_init "$RUN_DIR"

  printf '%s|main\n' "$RUN_DIR/checkout" > "$RUN_DIR/repos"
  printf '%s\n' "$ISSUE"       > "$RUN_DIR/out/issues.txt"
  printf '%s\n' "$ISSUE_TITLE" > "$RUN_DIR/out/issue-title.txt"

  INTAKE_GIT="$GIT_REAL" \
  INTAKE_GH="$BIN/gh" \
  INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_SKILL_DIR="$SKILL" \
  INTAKE_ENV_FILE="$ENVF" \
  INTAKE_REPO_LIST="$RUN_DIR/repos" \
  INTAKE_LOG="$RUN_DIR/intake.log" \
  INTAKE_LOCK="$RUN_DIR/lock" \
  INTAKE_WORKTREE_ROOT="$RUN_DIR/wt" \
  INTAKE_LABEL=claude-intake \
  FIXTURE_OUT="$RUN_DIR/out" \
  FIXTURE_DRAFT="$2" \
  FIXTURE_SANDBOX="$SANDBOX" \
    /bin/bash "${RUNNER_UNDER_TEST:-$RUNNER}" --once > "$RUN_DIR/run.out" 2>&1
  RUN_RC=$?
}

git_sb_init() { # $1 = run dir: creates <dir>/origin.git and <dir>/checkout
  sandboxed "$1"
  mkdir -p "$1/origin.git"
  git_sb "$1/origin.git" init -q --bare
  mkdir -p "$1/checkout"
  git_sb "$1/checkout" init -q
  git_sb "$1/checkout" checkout -q -b main 2>/dev/null || git_sb "$1/checkout" branch -q -m main
  mkdir -p "$1/checkout/docs/epics/01-existing"
  printf '# Epic: existing\n\n**Status:** closed\n' > "$1/checkout/docs/epics/01-existing/plan.md"
  git_sb "$1/checkout" add -A >/dev/null 2>&1
  git_sb "$1/checkout" commit -qm "fixture base" >/dev/null 2>&1
  git_sb "$1/checkout" remote add origin "$1/origin.git"
  git_sb "$1/checkout" push -q -u origin main >/dev/null 2>&1
}

out() { printf '%s' "$(cat "$RUN_DIR/out/$1" 2>/dev/null)"; }

# --- the canned drafts -----------------------------------------------------
DRAFTS="$SANDBOX/drafts"; sandboxed "$DRAFTS"; mkdir -p "$DRAFTS"

# #757's shape, as a drafter that did its job would return it: the work was
# already done by an attended PR that merged before the runner even selected the
# issue, so there is nothing for an approved epic to dispatch, and the evidence
# is named. NOT a plan at Status: planning pretending there is work.
cat > "$DRAFTS/no-work.md" <<'EOF'
# Epic: telemetry resolution for #757

**Status:** planning
**Recommendation:** no-work (already fixed by #758)
**Source:** GH #757
**Live branch:** main
**Integration branch:** main

## Outcome
Nothing. The behaviour this issue reports was fixed by PR #758, which merged
before this run selected the issue. There is no work here to dispatch.

## Grounding
- Verified: PR #758 merged 2m34s before selection and contains the fix.
EOF

cat > "$DRAFTS/plan.md" <<'EOF'
# Epic: fix the widget

**Status:** planning
**Recommendation:** plan
**Source:** GH #757

## Outcome
The widget stops dropping every second event.
EOF

cat > "$DRAFTS/needs-decision.md" <<'EOF'
# Epic: fix the widget

**Status:** planning
**Recommendation:** needs-decision
**Source:** GH #757

## Outcome
Undecided. Two incompatible fixes are available and the choice is a human's.

## The decision
- Option A: drop the cache. Costs a rewrite of the reader.
- Option B: version the cache key. Costs a migration.
Not resolved here, deliberately.
EOF

# No Recommendation line at all — a proposal drafted before the field existed.
cat > "$DRAFTS/absent.md" <<'EOF'
# Epic: fix the widget

**Status:** planning
**Source:** GH #757

## Outcome
The widget stops dropping every second event.
EOF

# Outside the vocabulary.
cat > "$DRAFTS/garbage.md" <<'EOF'
# Epic: fix the widget

**Status:** planning
**Recommendation:** maybe? ask Jonathan
**Source:** GH #757

## Outcome
Unclear.
EOF

# Emphasis, case and trailing whitespace variations that must still read no-work.
printf '# Epic: x\n\n**Status:** planning\n_Recommendation:_   NO-WORK   \n**Source:** GH #757\n\n## Outcome\nx\n' \
  > "$DRAFTS/shouty.md"

# A Recommendation BELOW the 10-line header window: not a header field, ignored.
{ printf '# Epic: x\n\n**Status:** planning\n**Source:** GH #757\n'
  printf '\n## Outcome\nline6\nline7\nline8\nline9\nline10\n'
  printf '**Recommendation:** no-work\n'; } > "$DRAFTS/late.md"

# --- the pre-change expectations, copied from the runner as it was before this
# --- item. A `plan` proposal must still produce exactly these.
EXPECT_TITLE_PLAIN="intake: proposed epic for #${ISSUE} — ${SLUG}"
cat > "$SANDBOX/expect-comment-plain.txt" <<EOF
Unattended intake drafted a proposed epic plan: https://github.com/fixture/repo/pull/1

  It is at \`Status: planning\` — not approved, not dispatchable. Review the PR; approve by merging it and setting \`Status: approved\`.
EOF
cat > "$SANDBOX/expect-body-plain.txt" <<EOF
Proposed epic plan drafted by **unattended intake** from #${ISSUE}.

  **This is a proposal, not a filed epic.** The plan is at \`**Status:** planning\`, which is never dispatchable. Approving means merging this PR **and** setting \`**Status:** approved\` — until that edit lands it is a draft that happens to be version-controlled.

  No epic number is claimed here. Phase 1 assigns the number **at approval** — rename \`${PROPOSAL}/\` to \`docs/epics/<NN>-<slug>/\` when you approve, and set \`Status: approved\`.

  Nothing was approved, dispatched, merged, or closed by this run. No code outside \`${PROPOSAL}/\` was touched.

  Part of #${ISSUE}
EOF

# ============================================================================
echo "=== A. an ordinary proposal is UNCHANGED, byte for byte ================"
echo "    (Recommendation: plan — the title, body and issue comment must equal"
echo "     the strings the runner produced before this item existed)"
run_intake plan "$DRAFTS/plan.md"
check "runner exit status" "0" "$RUN_RC" "plan"
check "PR title is the pre-change title" "$EXPECT_TITLE_PLAIN" "$(out pr-title.txt)" "plan"
check "PR body is the pre-change body" "$(cat "$SANDBOX/expect-body-plain.txt")" \
      "$(out pr-body.txt)" "plan"
check "issue comment is the pre-change comment" "$(cat "$SANDBOX/expect-comment-plain.txt")" \
      "$(out issue-comment.txt)" "plan"
check "no Recommendation paragraph in the body" "0" \
      "$(out pr-body.txt | grep -c 'Recommendation:' | tr -d ' ')" "plan"
check "the resolved outcome is logged" "1" \
      "$(grep -c "#${ISSUE}: recommendation=plan" "$RUN_DIR/intake.log" | tr -d ' ')" "plan"
check "PR opened against the configured base" "main" "$(out pr-base.txt)" "plan"

# ============================================================================
echo
echo "=== B. no Recommendation at all reads as \`plan\` ========================"
echo "    (the field is additive: a proposal drafted before it existed must"
echo "     produce output identical to case A's, not a different shape)"
PLAN_TITLE="$(out pr-title.txt)"; PLAN_BODY="$(out pr-body.txt)"; PLAN_COMMENT="$(out issue-comment.txt)"
run_intake absent "$DRAFTS/absent.md"
check "runner exit status" "0" "$RUN_RC" "absent"
check "PR title identical to the plan case" "$PLAN_TITLE" "$(out pr-title.txt)" "absent"
check "PR body identical to the plan case" "$PLAN_BODY" "$(out pr-body.txt)" "absent"
check "issue comment identical to the plan case" "$PLAN_COMMENT" "$(out issue-comment.txt)" "absent"
check "logged as plan" "1" \
      "$(grep -c "#${ISSUE}: recommendation=plan" "$RUN_DIR/intake.log" | tr -d ' ')" "absent"

# ============================================================================
echo
echo "=== C. #757 replayed: no-work reaches the PR and the issue ============="
echo "    (the draft concludes the work was already done by #758 and names it;"
echo "     the outcome must survive into the title, the body and the comment,"
echo "     and the PR must still be opened — one shape for every outcome)"
run_intake no-work "$DRAFTS/no-work.md"
check "runner exit status" "0" "$RUN_RC" "no-work"
check "PR title carries the outcome" "intake: [no-work] proposed epic for #${ISSUE} — ${SLUG}" \
      "$(out pr-title.txt)" "no-work"
check "a PR was opened at all (no-work still opens one)" "yes" \
      "$([ -s "$RUN_DIR/out/pr-title.txt" ] && echo yes || echo no)" "no-work"
check "PR body states the recommendation" "1" \
      "$(out pr-body.txt | grep -c '\*\*Recommendation: no-work\*\*' | tr -d ' ')" "no-work"
check "PR body still carries Part of #${ISSUE}" "1" \
      "$(out pr-body.txt | grep -c "^  Part of #${ISSUE}$" | tr -d ' ')" "no-work"
check "PR body never says Closes" "0" \
      "$(out pr-body.txt | grep -ci 'closes #' | tr -d ' ')" "no-work"
check "issue comment states the recommendation" "1" \
      "$(out issue-comment.txt | grep -c 'Recommendation: `no-work`' | tr -d ' ')" "no-work"
check "issue comment drops the approve-by-merging advice" "0" \
      "$(out issue-comment.txt | grep -c 'approve by merging' | tr -d ' ')" "no-work"
check "logged as no-work" "1" \
      "$(grep -c "#${ISSUE}: recommendation=no-work" "$RUN_DIR/intake.log" | tr -d ' ')" "no-work"
# The duplicate is named in the artifact that gets reviewed, not just in a log.
check "the pushed plan names the duplicate PR" "yes" \
      "$(git_sb "$RUN_DIR/origin.git" show "intake/proposed-${ISSUE}-${SLUG}:${PROPOSAL}/plan.md" \
         2>/dev/null | grep -q '#758' && echo yes || echo no)" "no-work"
check "the pushed plan is NOT at Status: approved" "0" \
      "$(git_sb "$RUN_DIR/origin.git" show "intake/proposed-${ISSUE}-${SLUG}:${PROPOSAL}/plan.md" \
         2>/dev/null | grep -ci '^\*\*Status:\*\* approved' | tr -d ' ')" "no-work"

echo
echo "--- and the five hard stops still hold on a no-work run ----------------"
check "the branch touches ONLY the proposal folder" "${PROPOSAL}/plan.md" \
      "$(git_sb "$RUN_DIR/origin.git" diff --name-only "main..intake/proposed-${ISSUE}-${SLUG}" 2>/dev/null)" "no-work"
# …and the log is not empty, or the line above would pass by saying nothing.
check "the run really did call gh (pr create, exactly once)" "1" \
      "$(grep -c '^pr create' "$RUN_DIR/out/gh-calls.log" | tr -d ' ')" "no-work"
check "no merge, no close, no review: gh calls are the known set" "" \
      "$(grep -vE '^(repo view|label list|issue list|issue view|issue comment|issue edit|pr create)' \
           "$RUN_DIR/out/gh-calls.log" | head -5)" "no-work"
check "main on origin is untouched by the run" \
      "$(git_sb "$RUN_DIR/checkout" rev-parse main)" \
      "$(git_sb "$RUN_DIR/origin.git" rev-parse main)" "no-work"

# ============================================================================
echo
echo "=== D. needs-decision reaches the PR and the issue ======================"
run_intake needs-decision "$DRAFTS/needs-decision.md"
check "runner exit status" "0" "$RUN_RC" "decision"
check "PR title carries the outcome" "intake: [needs-decision] proposed epic for #${ISSUE} — ${SLUG}" \
      "$(out pr-title.txt)" "decision"
check "PR body states the recommendation" "1" \
      "$(out pr-body.txt | grep -c '\*\*Recommendation: needs-decision\*\*' | tr -d ' ')" "decision"
check "PR body says it is not approvable as it stands" "1" \
      "$(out pr-body.txt | grep -c 'not approvable as it stands' | tr -d ' ')" "decision"
check "issue comment states the recommendation" "1" \
      "$(out issue-comment.txt | grep -c 'Recommendation: `needs-decision`' | tr -d ' ')" "decision"
check "logged as needs-decision" "1" \
      "$(grep -c "#${ISSUE}: recommendation=needs-decision" "$RUN_DIR/intake.log" | tr -d ' ')" "decision"

# ============================================================================
echo
echo "=== E. reading the field: case, emphasis, trailing text, window ========"
run_intake shouty "$DRAFTS/shouty.md"
check "_Recommendation:_ NO-WORK (case + emphasis + spaces)" \
      "intake: [no-work] proposed epic for #${ISSUE} — ${SLUG}" "$(out pr-title.txt)" "shouty"
check "trailing text after the value is ignored (no-work (already fixed by #758))" \
      "1" "$(grep -c "#${ISSUE}: recommendation=no-work" "$SANDBOX/run-no-work/intake.log" | tr -d ' ')" "trailing"

run_intake late "$DRAFTS/late.md"
check "a Recommendation below the header window is NOT a header field" \
      "$EXPECT_TITLE_PLAIN" "$(out pr-title.txt)" "late"
check "…and reads as plan" "1" \
      "$(grep -c "#${ISSUE}: recommendation=plan" "$RUN_DIR/intake.log" | tr -d ' ')" "late"

# ============================================================================
echo
echo "=== F. a value outside the vocabulary is NOT read as an approvable plan ="
echo "    (a malformed terminal outcome is exactly what a human should look at,"
echo "     so it is logged verbatim and shown as needs-decision)"
run_intake garbage "$DRAFTS/garbage.md"
check "runner exit status" "0" "$RUN_RC" "garbage"
check "PR title is tagged needs-decision" "intake: [needs-decision] proposed epic for #${ISSUE} — ${SLUG}" \
      "$(out pr-title.txt)" "garbage"
check "the raw value is logged verbatim" "1" \
      "$(grep -c 'unrecognised Recommendation \[maybe? ask Jonathan\]' "$RUN_DIR/intake.log" | tr -d ' ')" "garbage"
check "and it is NOT the plain title" "differs" \
      "$([ "$(out pr-title.txt)" = "$EXPECT_TITLE_PLAIN" ] && echo same || echo differs)" "garbage"

# ============================================================================
echo
echo "=== G. the drafter is TOLD the vocabulary, and told it is not a failure ="
echo "    (the prompt the runner actually built, as the drafter received it)"
P="$SANDBOX/run-plan/out/prompt.txt"
check "prompt names all three values" "1" \
      "$(grep -c 'plan | no-work | needs-decision' "$P" | tr -d ' ')" "prompt"
check "prompt says the non-plan values are preferred, not failures" "1" \
      "$(grep -c 'CORRECT, PREFERRED outputs' "$P" | tr -d ' ')" "prompt"
check "prompt forbids resolving a needs-decision" "1" \
      "$(grep -c 'Do NOT resolve it' "$P" | tr -d ' ')" "prompt"
check "prompt still carries the five hard stops" "5" \
      "$(grep -cE '^    - Do NOT ' "$P" | tr -d ' ')" "prompt"
check "prompt still pins Status: planning" "yes" \
      "$(grep -q '\*\*Status:\*\* planning' "$P" && echo yes || echo no)" "prompt"

# ============================================================================
echo
echo "=== H. MUTATION CHECK: drop the title tag and case C must fail =========="
MUT_RUNNER="$SANDBOX/unattended-intake.notag.sh"; sandboxed "$MUT_RUNNER"
sed -e 's/[$]{REC_TITLE_TAG}//' "$RUNNER" > "$MUT_RUNNER"
cmp -s "$RUNNER" "$MUT_RUNNER" && {
  echo "ERROR: the mutant is identical to the runner — the title tag moved," >&2
  echo "       so case C would be proving nothing. Fix the sed above." >&2; exit 1; }
/bin/bash -n "$MUT_RUNNER" || { echo "ERROR: mutant runner does not parse" >&2; exit 1; }
RUNNER_UNDER_TEST="$MUT_RUNNER"
run_intake mutant "$DRAFTS/no-work.md"
RUNNER_UNDER_TEST="$RUNNER"
check "mutant drops the outcome from the title" "$EXPECT_TITLE_PLAIN" "$(out pr-title.txt)" "mutant"
check "so case C's title expectation does NOT hold there" "differs" \
      "$([ "$(out pr-title.txt)" = "intake: [no-work] proposed epic for #${ISSUE} — ${SLUG}" ] \
         && echo same || echo differs)" "mutant"

# ============================================================================
# The SessionStart injection. Same sandbox discipline; no runner involved.
# ============================================================================
echo
echo "=== I. the injection renders all three values ==========================="

# A PATH with no jq and no python3 — and no gh/curl/nc at all, so anything
# reaching for a JSON parser or the network fails loudly instead of quietly
# working on the developer's machine. The stricter builtin-only PATHs (no
# grep/sed/head/tr, no sort) are already proved by session-start-fixtures.sh.
BIN_BARE="$SANDBOX/bin-bare"; sandboxed "$BIN_BARE"; mkdir -p "$BIN_BARE"
for t in cat grep sed head tr cut sort wc git ls mkdir rm mv dirname basename date printf env find touch sleep pgrep kill mktemp; do
  p="$(command -v "$t" 2>/dev/null)" || continue
  case "$p" in /*) ln -sf "$p" "$BIN_BARE/$t" ;; esac
done

path_for() { case "$1" in bare) printf '%s' "$BIN_BARE" ;; *) printf '%s' "$PATH" ;; esac; }

mkrepo() { # $1 = repo dir (a git repo with NO remote, so no tracker call)
  sandboxed "$1"
  rm -rf "$1"; mkdir -p "$1"
  git_sb "$1" init -q
  git_sb "$1" checkout -q -b main 2>/dev/null || git_sb "$1" branch -q -m main
  printf 'fixture\n' > "$1/README.md"
  git_sb "$1" add -A >/dev/null 2>&1
  git_sb "$1" commit -qm fixture >/dev/null 2>&1
}

plan_file() { # $1 = epic dir, $2 = Status, $3 = Recommendation ("" = no such line)
  sandboxed "$1"
  mkdir -p "$1"
  { printf '# Epic: fixture\n\n**Status:** %s\n' "$2"
    [ -n "$3" ] && printf '**Recommendation:** %s\n' "$3"
    printf '**Source:** GH #0\n\n## Outcome\nfixture\n'; } > "$1/plan.md"
}

run_hook() { # $1 project dir  $2 variant
  sandboxed "$1"
  printf '{"source":"startup","session_id":"s","cwd":"%s","hook_event_name":"SessionStart"}' "$1" \
    | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$2")" \
      INTAKE_REPO_LIST="$SANDBOX/no-such-repos-file" \
      /bin/bash "${HOOK_UNDER_TEST:-$HOOK}" 2>> "$SANDBOX/hook-stderr.log"
}

line_matching() { # $1 project dir  $2 variant  $3 pattern
  L="$(run_hook "$1" "$2" | grep -- "$3" || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}
queue_block() { # every queue line, in emitted order
  L="$(run_hook "$1" "$2" | grep -E '^- [0-9]+ (epic|proposal)' || true)"
  [ -n "$L" ] && printf '%s' "$L" || printf '<none>'
}

EXPECT_NOWORK="- 1 proposal recommending no work: 06-nowork — read the evidence, then close it or say why it is wrong. Never dispatch one."
EXPECT_DECISION="- 1 proposal awaiting a decision: 07-decide — it states a choice it deliberately did not make; decide it, then re-draft. Not approvable as it stands."
EXPECT_APPROVAL="- 1 epic awaiting approval: 05-real — approve before dispatch; \`planning\` is never dispatchable."

for V in full bare; do
  R="$SANDBOX/I1-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-real" "planning" "plan"
  check "I1 Recommendation: plan -> awaiting APPROVAL, unchanged" "$EXPECT_APPROVAL" \
        "$(line_matching "$R" "$V" 'awaiting approval')" "$V"
  check "I1 …and no proposal line at all" "<none>" \
        "$(line_matching "$R" "$V" 'proposal')" "$V"

  R="$SANDBOX/I2-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/06-nowork" "planning" "no-work (duplicate of #758)"
  check "I2 no-work -> its own line" "$EXPECT_NOWORK" \
        "$(line_matching "$R" "$V" 'recommending no work')" "$V"
  check "I2 …and never under awaiting approval" "<none>" \
        "$(line_matching "$R" "$V" 'awaiting approval')" "$V"
  check "I2 …and never under awaiting dispatch" "<none>" \
        "$(line_matching "$R" "$V" 'awaiting dispatch')" "$V"

  R="$SANDBOX/I3-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/07-decide" "planning" "needs-decision"
  check "I3 needs-decision -> its own line" "$EXPECT_DECISION" \
        "$(line_matching "$R" "$V" 'awaiting a decision')" "$V"
  check "I3 …and never under awaiting approval" "<none>" \
        "$(line_matching "$R" "$V" 'awaiting approval')" "$V"

  R="$SANDBOX/I4-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-real" "planning" ""
  check "I4 no Recommendation line -> awaiting APPROVAL, unchanged" "$EXPECT_APPROVAL" \
        "$(line_matching "$R" "$V" 'awaiting approval')" "$V"

  R="$SANDBOX/I5-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-real" "planning" "sideways"
  check "I5 an unrecognised value stays in the approval bucket" "$EXPECT_APPROVAL" \
        "$(line_matching "$R" "$V" 'awaiting approval')" "$V"

  # A human wrote `approved`. That overtakes the recommendation, which is spent.
  R="$SANDBOX/I6-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/05-ready" "approved" "no-work"
  check "I6 approved + no-work -> still awaiting DISPATCH" \
        "- 1 epic awaiting dispatch: 05-ready." "$(line_matching "$R" "$V" 'awaiting dispatch')" "$V"
  check "I6 …and no proposal line" "<none>" "$(line_matching "$R" "$V" 'proposal')" "$V"

  R="$SANDBOX/I7-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/03-done"    "closed"                "no-work"
  plan_file "$R/docs/epics/04-running" "in flight (item 1 of 2)" "needs-decision"
  check "I7 closed / in flight are still invisible whatever they recommend" "<none>" \
        "$(queue_block "$R" "$V")" "$V"
done

echo
echo "=== J. all four lines together: order, adjacency, plural, cap =========="
for V in full bare; do
  R="$SANDBOX/J1-$V"; mkrepo "$R"
  plan_file "$R/docs/epics/04-ready"  "approved" ""
  plan_file "$R/docs/epics/05-real"   "planning" "plan"
  plan_file "$R/docs/epics/06-nowork" "planning" "no-work (duplicate of #758)"
  plan_file "$R/docs/epics/07-decide" "planning" "needs-decision"
  check "J1 four buckets, in order: dispatch, approval, decision, no-work" \
        "$(printf '%s\n%s\n%s\n%s' \
             "- 1 epic awaiting dispatch: 04-ready." \
             "$EXPECT_APPROVAL" "$EXPECT_DECISION" "$EXPECT_NOWORK")" \
        "$(queue_block "$R" "$V")" "$V"
  check "J1 the four lines are adjacent (one markdown list)" "3" \
        "$(run_hook "$R" "$V" | grep -nE '^- [0-9]+ (epic|proposal)' | cut -d: -f1 \
           | awk 'NR==1{f=$1} {l=$1} END{print l-f}')" "$V"

  R="$SANDBOX/J2-$V"; mkrepo "$R"
  for N in 08 06 07; do plan_file "$R/docs/epics/$N-nw$N" "planning" "no-work"; done
  check "J2 plural + folder order" \
        "- 3 proposals recommending no work: 06-nw06, 07-nw07, 08-nw08 — read the evidence, then close them or say why they are wrong. Never dispatch one." \
        "$(line_matching "$R" "$V" 'recommending no work')" "$V"

  R="$SANDBOX/J3-$V"; mkrepo "$R"
  for N in 01 02 03 04 05 06 07; do plan_file "$R/docs/epics/$N-d$N" "planning" "needs-decision"; done
  check "J3 the cap applies to the decision line too" \
        "- 7 proposals awaiting a decision: 01-d01, 02-d02, 03-d03, 04-d04, 05-d05 (+2 more) — each states a choice it deliberately did not make; decide it, then re-draft. Not approvable as they stand." \
        "$(line_matching "$R" "$V" 'awaiting a decision')" "$V"
done

echo
echo "=== K. header parsing: case, emphasis, CRLF, and the window ============"
R="$SANDBOX/K1"; mkrepo "$R"
plan_file "$R/docs/epics/06-nowork" "planning" "No-Work"
check "K1 mixed case" "$EXPECT_NOWORK" "$(line_matching "$R" full 'recommending no work')" "full"

R="$SANDBOX/K2"; mkrepo "$R"; sandboxed "$R/docs/epics/06-nowork"; mkdir -p "$R/docs/epics/06-nowork"
printf '# Epic: fixture\r\n\r\n**Status:** planning\r\n**Recommendation:** no-work\r\n' \
  > "$R/docs/epics/06-nowork/plan.md"
check "K2 CRLF" "$EXPECT_NOWORK" "$(line_matching "$R" full 'recommending no work')" "full"

R="$SANDBOX/K3"; mkrepo "$R"; sandboxed "$R/docs/epics/06-nowork"; mkdir -p "$R/docs/epics/06-nowork"
printf '_Recommendation:_   no-work   \n**Status:** planning\n' > "$R/docs/epics/06-nowork/plan.md"
check "K3 underscore emphasis, padding, field order reversed" "$EXPECT_NOWORK" \
      "$(line_matching "$R" full 'recommending no work')" "full"

R="$SANDBOX/K4"; mkrepo "$R"; sandboxed "$R/docs/epics/05-real"; mkdir -p "$R/docs/epics/05-real"
{ printf '# Epic: fixture\n\n**Status:** planning\n**Source:** GH #0\n'
  printf '\n## Outcome\nl6\nl7\nl8\nl9\nl10\n**Recommendation:** no-work\n'; } \
  > "$R/docs/epics/05-real/plan.md"
check "K4 below the 10-line window: not a header field" "$EXPECT_APPROVAL" \
      "$(line_matching "$R" full 'awaiting approval')" "full"
check "K4 …and no no-work line" "<none>" "$(line_matching "$R" full 'recommending no work')" "full"

R="$SANDBOX/K5"; mkrepo "$R"; sandboxed "$R/docs/epics/05-real"; mkdir -p "$R/docs/epics/05-real"
: > "$R/docs/epics/05-real/plan.md"
check "K5 an empty plan is still listed, never hidden" "$EXPECT_APPROVAL" \
      "$(line_matching "$R" full 'awaiting approval')" "full"

echo
echo "=== L. MUTATION CHECK: the new lines fail on the pre-item-1 hook ========"
echo "    (the mutant sends both recommendation buckets back to 'approval',"
echo "     which is exactly what the hook did before this item)"
MUT_HOOK="$SANDBOX/session-start-context.norec.sh"; sandboxed "$MUT_HOOK"
sed -e 's/EQ_QUEUE="no-work"/EQ_QUEUE="approval"/' \
    -e 's/EQ_QUEUE="decision"/EQ_QUEUE="approval"/' "$HOOK" > "$MUT_HOOK"
cmp -s "$HOOK" "$MUT_HOOK" && {
  echo "ERROR: the mutant is identical to the hook — the bucket assignment moved," >&2
  echo "       so cases I2/I3 would be proving nothing. Fix the sed above." >&2; exit 1; }
grep -qE 'EQ_QUEUE="(no-work|decision)"' "$MUT_HOOK" && {
  echo "ERROR: the mutant still assigns a recommendation bucket" >&2; exit 1; }
/bin/bash -n "$MUT_HOOK" || { echo "ERROR: mutant hook does not parse" >&2; exit 1; }

HOOK_UNDER_TEST="$MUT_HOOK"
R="$SANDBOX/L1"; mkrepo "$R"
plan_file "$R/docs/epics/06-nowork" "planning" "no-work"
check "L pre-item-1: a no-work proposal is called awaiting APPROVAL" \
      "- 1 epic awaiting approval: 06-nowork — approve before dispatch; \`planning\` is never dispatchable." \
      "$(line_matching "$R" full 'awaiting approval')" "mutant"
check "L pre-item-1: emits NO no-work line, so I2 does not hold there" "<none>" \
      "$(line_matching "$R" full 'recommending no work')" "mutant"

R="$SANDBOX/L2"; mkrepo "$R"
plan_file "$R/docs/epics/07-decide" "planning" "needs-decision"
check "L pre-item-1: emits NO decision line, so I3 does not hold there" "<none>" \
      "$(line_matching "$R" full 'awaiting a decision')" "mutant"

# …and the case that must be IDENTICAL either way, so the mutation check cannot
# be waved away as "the mutant differs on everything".
R="$SANDBOX/L3"; mkrepo "$R"
plan_file "$R/docs/epics/04-ready" "approved" ""
plan_file "$R/docs/epics/05-real"  "planning" "plan"
run_hook "$R" full > "$SANDBOX/L3.mutant"
HOOK_UNDER_TEST="$HOOK"
run_hook "$R" full > "$SANDBOX/L3.hook"
check "L no recommendation in play: mutant and hook agree byte for byte" "" \
      "$(diff "$SANDBOX/L3.mutant" "$SANDBOX/L3.hook" | head -20)" "mutant"

echo
echo "=== hook stderr (empty unless the hook errored on its own) ============="
[ -s "$SANDBOX/hook-stderr.log" ] && head -20 "$SANDBOX/hook-stderr.log"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
