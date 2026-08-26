#!/usr/bin/env bash
# Fixture harness for the drafter's **Touches:** block (epic 10 item 2) in the
# unattended runner:  ../../bin/unattended-intake.sh
#
# THE QUESTION THIS ITEM HAD TO ANSWER FIRST. `references/plan-template.md`
# (epic 10 item 1) now defines a per-work-item `**Touches:**` block, and the
# runner already points the drafter at that template for structure. Does the
# template alone propagate the field, or does the drafter need the field named
# explicitly, the way `**Live branch:**` and `**Integration branch:**` already
# are (epic 09 item 2, `intake-header-fixtures.sh`)? A hermetic stub cannot
# answer that empirically — it cannot "read" a template and decide on its own,
# and `references/stack-gates.md` keeps live-model calls out of CI on purpose
# ("it will fail for reasons unrelated to the change under review"). So this
# item took the same precautionary call epic 09 item 2 already made for the
# two branch facts: state the field explicitly in the PROMPT rather than trust
# propagation, because the plan's own Risks table rates silent non-propagation
# Medium likelihood and "item 2 silently ships nothing" as the blast radius.
#
# WHAT THIS HARNESS PROVES, AND WHAT IT DOES NOT. It proves the runner's
# PROMPT names the Touches field, its three rules and its unknowable-paths
# fallback verbatim, and that a drafter which honours the prompt therefore
# emits well-formed blocks (case A) and an honest gap instead of a guess where
# paths cannot be named (case B). Case C is the same mutant technique
# `intake-header-fixtures.sh` case H uses: strip the new instruction from the
# prompt and show the stub — which only emits Touches blocks when the prompt
# names the field, precisely so this suite cannot pass by coincidence — has
# nothing to copy. It does NOT prove a live model complies; only a live draft
# retires that residual, exactly as intake-header-fixtures.sh says of its own
# case H.
#
# SANDBOX DISCIPLINE (GH #15 is open and unfixed): the same tripwire
# `intake-header-fixtures.sh` uses — everything lives under one `mktemp -d`
# removed on exit, every destructive path goes through sandboxed(), the stubs
# refuse to run outside it, and the host repo is fingerprinted before and after.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-touches-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$(cd "$TESTS_DIR/../../bin" && pwd)/unattended-intake.sh"
SKILL_REFS="$(cd "$TESTS_DIR/../../../.." && pwd)/references"
[ -f "$RUNNER" ]     || { echo "ERROR: not found: $RUNNER" >&2; exit 1; }
[ -d "$SKILL_REFS" ] || { echo "ERROR: not found: $SKILL_REFS" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-touches-fixtures.XXXXXX")" || exit 1
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
echo

# ============================================================================
# Stubs.
# ============================================================================
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

# --- stub gh -----------------------------------------------------------------
# Same shape as intake-header-fixtures.sh's stub, trimmed to the verbs this
# harness's single-repo, single-issue scenario actually exercises. An
# unanswered verb is a loud failure, never a quiet degrade (epic 09 item 1's
# post-mortem) — case D below checks the unhandled log stays empty.
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
      *nameWithOwner*)    printf 'fixture/repo\n' ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"; exit 1 ;;
    esac ;;
  "label list")   printf 'claude-intake\tRun unattended intake\n' ;;
  "issue list")   cat "$OUT/issues" 2>/dev/null ;;
  "issue view")
    case "$* " in
      *"--json title,labels "*) ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"; exit 1 ;;
    esac
    printf ',,\n'
    printf 'Declare the paths a work item touches\n' ;;
  "issue comment") arg_after --body "$@" >> "$OUT/issue-comments.log" ;;
  "issue edit")   : ;;
  "api "*|"api")
    case "$*" in
      */issues/*/timeline*) printf 'x' >> "$OUT/api-calls" ;;
      */branches*)          printf 'x' >> "$OUT/branch-calls" ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"; exit 1 ;;
    esac ;;
  "pr view")      : ;;
  "pr list")
    case "$* " in
      *"--json number,headRefName "*) ;;
      *) printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"; exit 1 ;;
    esac
    printf '%s' "" ;;
  "pr create")
    arg_after --title "$@" > "$OUT/pr-title.txt"
    arg_after --base  "$@" > "$OUT/pr-base.txt"
    printf 'https://github.com/fixture/repo/pull/1\n' ;;
  *)
    printf '%s\n' "$*" >> "$OUT/gh-unhandled.log"
    exit 1 ;;
esac
exit 0
GHSTUB

# --- stub claude (the drafter) ----------------------------------------------
# Reads whether the PROMPT names the Touches field at all (the marker this
# item's edit added) before deciding what to write — a stub that emitted
# Touches blocks unconditionally would pass this suite whether or not the
# code change under test existed, which is exactly the failure mode epic 09
# item 1's post-mortem is about.
#
# The stub auto-detects via HAS_MARKER, a scan of the prompt for the
# plan-template.md heading text (no FIXTURE_DRAFTER env var involved):
#
#   HAS_MARKER=yes (the normal case, prompt built from the real template)
#     item 1 gets a well-formed Touches block, item 2 states in prose that
#     its paths are not determinable and gets no block — never a guess.
#   HAS_MARKER=no (a case whose runner mutates the prompt to strip the
#     instruction, simulating a stale/pre-fix template) the stub writes
#     neither item's Touches block — nothing to copy.
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

printf '%s' "$PROMPT" > "$OUT/prompt.txt"

TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
case "$TOP" in "$FIXTURE_SANDBOX"/*) ;; *) echo "claude stub ABORT: repo outside sandbox: [$TOP]" >&2; exit 9 ;; esac

HAS_MARKER=no
case "$PROMPT" in *"EACH WORK ITEM'S **Touches:** BLOCK"*) HAS_MARKER=yes ;; esac

mkdir -p "$(dirname "$PLANPATH")"
{
  printf '# Epic: fixture proposal\n\n'
  printf '**Status:** planning\n'
  printf '**Recommendation:** plan\n'
  printf '**Source:** GH #757\n'
  printf '**Live branch:** main\n'
  printf '**Integration branch:** main\n'
  printf '**Pre-epic tag:** n/a\n\n'
  printf '## Outcome\nA fixture proposal.\n\n'
  printf '## Work items\n\n'
  printf '### 1. Well-formed declaration\n'
  printf -- '- **Branch:** `feat/fixture-first`\n'
  printf -- '- **Scope:** a fixture item whose touched paths are known.\n'
  if [ "$HAS_MARKER" = yes ]; then
    printf -- '- **Touches:**\n'
    printf '  - `Skills/dev-epic-workflow/references/plan-template.md`\n'
    printf '  - `Skills/dev-epic-workflow/SKILL.md`\n'
  fi
  printf -- '- **Not in scope:** nothing else.\n'
  printf -- '- **Definition of done:** fixture.\n'
  printf -- '- **Verification:** fixture.\n'
  printf -- '- **Rollback:** revert.\n\n'
  printf '### 2. Paths not determinable\n'
  printf -- '- **Branch:** `feat/fixture-second`\n'
  if [ "$HAS_MARKER" = yes ]; then
    printf -- '- **Scope:** the paths this item will touch are not determinable from the issue alone;\n'
    printf '  investigation during Phase 0 grounding is required before they can be declared.\n'
  else
    printf -- '- **Scope:** a second fixture item.\n'
  fi
  printf -- '- **Not in scope:** nothing else.\n'
  printf -- '- **Definition of done:** fixture.\n'
  printf -- '- **Verification:** fixture.\n'
  printf -- '- **Rollback:** revert.\n'
} > "$PLANPATH"

git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    add "$PLANPATH" >/dev/null 2>&1 || exit 9
git -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    commit -qm "docs: proposed epic plan (fixture drafter)" >/dev/null 2>&1 || exit 9
exit 0
CLSTUB

chmod +x "$BIN/gh" "$BIN/claude"
/bin/bash -n "$BIN/gh"     || { echo "ERROR: gh stub does not parse" >&2; exit 1; }
/bin/bash -n "$BIN/claude" || { echo "ERROR: claude stub does not parse" >&2; exit 1; }

SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
cp "$SKILL_REFS/issue-intake.md" "$SKILL_REFS/plan-template.md" "$SKILL/references/"

ENVF="$SANDBOX/env"; sandboxed "$ENVF"
printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-not-a-real-token\n' > "$ENVF"
chmod 600 "$ENVF"

# ============================================================================
# Scenario plumbing — one repo, one issue, reused by every case.
# ============================================================================
mk_repo() { # $1 = run dir, $2 = name
  sandboxed "$1"
  MR_DIR="$1"; MR_NAME="$2"
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
}

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
  HOME="$RUN_DIR/home" \
    /bin/bash "${RUNNER_UNDER_TEST:-$RUNNER}" --once "$@" > "$RUN_DIR/run.out" 2>&1
  RUN_RC=$?
}

new_run() { # $1 = case id -> a clean run dir with the standard single repo + issue
  RUN_DIR="$SANDBOX/run-$1"; sandboxed "$RUN_DIR"
  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR/out" "$RUN_DIR/wt" "$RUN_DIR/home"
  mk_repo "$RUN_DIR" repo
  printf '%s\n' "$RUN_DIR/repo" > "$RUN_DIR/repos"
  printf '757\n' > "$RUN_DIR/out/issues"
}

ISSUE=757
SLUG="declare-the-paths-a-work-item-touches"
PROPOSAL="proposed-${ISSUE}-${SLUG}"
BRANCH="intake/proposed-${ISSUE}-${SLUG}"

pushed_plan() { # $1 = origin bare dir -> the plan.md as pushed
  git_sb "$1" show "$BRANCH:docs/epics/$PROPOSAL/plan.md" 2>/dev/null
}

# The canonical extraction: everything the consumers (item 3's gate, item 4's
# collision reader) will also need — the declared paths under one work item's
# **Touches:** block, backticks stripped, one per line.
touches_of_item() { # $1 = plan text (stdin), $2 = item number
  awk -v n="$2" '
    BEGIN { want = "### " n "\\."; in_item = 0; in_touches = 0 }
    /^### [0-9]+\./ { in_item = ($0 ~ ("^" want)); in_touches = 0; next }
    in_item && /\*\*Touches:\*\*/ { in_touches = 1; next }
    in_item && in_touches && /^  - `/ {
      line = $0
      sub(/^  - `/, "", line); sub(/`[[:space:]]*$/, "", line)
      print line
      next
    }
    in_item && in_touches { in_touches = 0 }
  '
}

# ============================================================================
echo "=== A. the PROMPT states the Touches field, its rules and its fallback ="
new_run A
run_intake A
check "runner exit status" "0" "$RUN_RC" "A"
check "the field is named by its plan-template.md heading" "1" \
      "$(grep -c "EACH WORK ITEM'S \*\*Touches:\*\* BLOCK" "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "one repo-root-relative path per line, declarations only" "1" \
      "$(grep -c 'one repo-root-relative' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "never a path the item merely reads or compares against" "1" \
      "$(grep -c 'never a path the item merely reads or compares' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "the unknowable-paths fallback is stated, not silent" "1" \
      "$(grep -c 'write NO block at all and say so' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "never a plausible-looking guess (same principle as the branch facts)" "1" \
      "$(grep -c 'never a plausible-looking' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"
check "the surrounding prompt is undamaged: still 5 hard stops" "5" \
      "$(grep -cE '^    - Do NOT ' "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "A"

# ============================================================================
echo
echo "=== B. a faithful drafter emits well-formed blocks, one path per line ==="
PLAN="$(pushed_plan "$RUN_DIR/repo.git")"
T1="$(printf '%s\n' "$PLAN" | touches_of_item - 1)"
check "item 1 declares exactly two paths" "2" "$(printf '%s\n' "$T1" | grep -c .)" "B"
check "…repo-root-relative (no leading slash)" "0" \
      "$(printf '%s\n' "$T1" | grep -c '^/' | tr -d ' ')" "B"
check "…one per line, so no comma-wrapped entry survives" "0" \
      "$(printf '%s\n' "$T1" | grep -c ',' | tr -d ' ')" "B"
check "…and the two paths are exactly the ones the stub wrote" \
      "$(printf 'Skills/dev-epic-workflow/references/plan-template.md\nSkills/dev-epic-workflow/SKILL.md')" \
      "$T1" "B"

# ============================================================================
echo
echo "=== C. paths genuinely unknowable -> no block, a prose statement ======="
T2="$(printf '%s\n' "$PLAN" | touches_of_item - 2)"
check "item 2 declares NO paths — not an empty guess, no block at all" "" "$T2" "C"
check "…and item 2's own Scope names the fixture's diagnostic sentinel" "1" \
      "$(printf '%s\n' "$PLAN" | grep -c 'not determinable from the issue alone')" "C"
check "item 2 heading itself says why, for a human reading the PR" "1" \
      "$(printf '%s\n' "$PLAN" | grep -c '### 2. Paths not determinable')" "C"

# ============================================================================
echo
echo "=== D. no gh call went unanswered (epic 09 item 1's post-mortem) ======="
check "no unhandled gh verb" "" "$(cat "$RUN_DIR/out/gh-unhandled.log" 2>/dev/null)" "D"

# ============================================================================
echo
echo "=== E. MUTANT — strip the instruction, and the stub has nothing to copy ="
echo "    (the same technique intake-header-fixtures.sh case H uses: this is"
echo "     what proves the wiring, not just the wording, is load-bearing)"
MUT="$SANDBOX/unattended-intake.notouches.sh"; sandboxed "$MUT"
awk '
  /^  EACH WORK ITEM.S \*\*Touches:\*\* BLOCK/ { skip = 1 }
  skip && /^  \*\*Pre-epic tag:\*\* is NOT supplied/ { skip = 0 }
  !skip { print }
' "$RUNNER" > "$MUT"
cmp -s "$RUNNER" "$MUT" && {
  echo "ERROR: mutant is identical to the runner — the instruction moved, so" >&2
  echo "       this case would be proving nothing. Fix the awk above." >&2; exit 1; }
grep -q "EACH WORK ITEM'S \*\*Touches:\*\* BLOCK" "$MUT" && {
  echo "ERROR: mutant still carries the Touches instruction" >&2; exit 1; }
grep -q '\*\*Pre-epic tag:\*\* is NOT supplied' "$MUT" || {
  echo "ERROR: mutant deleted more than the Touches paragraph" >&2; exit 1; }
/bin/bash -n "$MUT" || { echo "ERROR: mutant does not parse" >&2; exit 1; }

RUNNER_UNDER_TEST="$MUT"
new_run E
run_intake E
check "mutant: the prompt no longer names the field" "0" \
      "$(grep -c "EACH WORK ITEM'S \*\*Touches:\*\* BLOCK" "$RUN_DIR/out/prompt.txt" | tr -d ' ')" "mutant"
PLAN_E="$(pushed_plan "$RUN_DIR/repo.git")"
check "mutant: item 1 declares NO paths — nothing to copy" "" \
      "$(printf '%s\n' "$PLAN_E" | touches_of_item - 1)" "mutant"
check "mutant: so case B's expectation does NOT hold there" "differs" \
      "$([ -z "$(printf '%s\n' "$PLAN_E" | touches_of_item - 1)" ] && echo differs || echo same)" "mutant"
RUNNER_UNDER_TEST="$RUNNER"

# ============================================================================
echo
echo "=== sandbox discipline (GH #15) ========================================"
check "the host repo did not move (HEAD + working tree)" "$HOST_BEFORE" "$(host_fingerprint)"
check "no stub ever had to abort (a sandbox escape would say so)" "" \
      "$(grep -h 'ABORT' "$SANDBOX"/run-*/run.out 2>/dev/null | sort -u | head -3)"
check "nothing was written to a real HOME" "" \
      "$(find "$SANDBOX"/run-*/home -mindepth 1 2>/dev/null | head -3)"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
