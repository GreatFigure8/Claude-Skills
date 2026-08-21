#!/usr/bin/env bash
# Fixtures for L2 dispatch — dev-epic-workflow, epic 11 item 3.
#
# THE ITEM UNDER TEST IS THE ONLY ONE IN THIS EPIC THAT CHANGES WHAT THE MACHINE
# MAY DO WITHOUT A HUMAN, so this suite is built to be believed rather than to be
# green. Four things make it that:
#
#   1. IT ABORTS RATHER THAN SKIPS. No dispatch library, no `DISPATCH_ENFORCED=`
#      contract marker, no `--agent work-item-executor` invocation — any of those
#      and this file exits 2 instead of passing 200 cases about nothing.
#   2. SECTION K IS THE INERTNESS PROOF, and it is run twice. First: the shipped
#      runner against a reconstruction of the PRE-ITEM-3 runner, built by deleting
#      exactly the lines this item added and refusing to run if the count is
#      wrong, compared byte for byte on an unconfigured repo. That pair alone
#      would pass on a runner that does nothing, so the SAME pair runs again
#      against a repo configured at L2, where the shipped runner must dispatch and
#      the reconstruction must be blind to the whole idea.
#   3. SECTION H IS THE INVARIANT, stated as a fixture rather than as a promise: a
#      COMPLETED L2 cycle leaves the pull request OPEN, the issue OPEN, and
#      nothing merged. It asserts the absence of `gh pr merge`, `gh issue close`,
#      `gh issue edit` and `git push` to the integration branch in the whole call
#      stream of a successful run.
#   4. SECTION M IS MUTANTS. Each is a change somebody could genuinely make
#      believing it harmless — an advisory denylist, a PR opened without reading
#      the executor's milestone, a retry after `blocked`, a level check that
#      passes at L0 — and each must break a case that passes on the shipped
#      library.
#
# THE REPOSITORY IS REAL, THE WORLD IS NOT. The sandbox holds an actual bare
# `origin` and an actual clone, so `git worktree add`, `git push`, `git diff
# --name-only` and `git diff --numstat` are the real commands answering about
# real commits — the denylist and the size ceiling are checked against a diff git
# produced, not against a string this file wrote. Only `gh` and `claude` are
# stubs, and the `gh` stub answers the branch list FROM the bare repo so the
# fixture cannot disagree with itself.
#
# SANDBOXING (GH #15 is open and unfixed: a harness in this repo has already
# escaped its sandbox and committed a real working tree). Everything lives under
# one `mktemp -d` removed on exit, every destructive path goes through
# sandboxed(), and no git command here or in any stub names the repo this file
# lives in.
#
# IT NEVER READS OR WRITES ~/.config/claude-intake. HOME is redirected into the
# sandbox and every control file — the autonomy config, the override, the stop
# file, the promotions directory, the provisioning file, the log and the lock —
# is pointed at the case directory on every single invocation.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/l2-dispatch-fixtures.sh
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-unattended-intake.sh bash ...
#         INTAKE_FIXTURE_DISPATCH_LIB=/path/to/other-dispatch.sh bash ...

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/unattended-intake.sh}"
LIB="${INTAKE_FIXTURE_DISPATCH_LIB:-$BIN_DIR/dispatch.sh}"
AUTONOMY_LIB_PATH="$BIN_DIR/autonomy.sh"
PROVISION_LIB_PATH="$BIN_DIR/worktree-provision.sh"
STATUS_LIB_PATH="$BIN_DIR/intake-status.sh"
REAL_GIT="$(command -v git 2>/dev/null || printf '/usr/bin/git')"

# ------------------------------------------------------- the abort tripwires
# Not skips, not warnings: aborts. Pointed at a pre-item-3 tree this suite must
# STOP, because a suite that quietly passes against the code as it stood before
# the item is a suite that tests nothing.
for F in "$SCRIPT" "$LIB" "$AUTONOMY_LIB_PATH" "$PROVISION_LIB_PATH" "$STATUS_LIB_PATH"; do
  [ -r "$F" ] || { echo "ERROR: missing $F — this is not an epic 11 item 3 tree. Aborting." >&2; exit 2; }
done
if ! grep -q '^DISPATCH_ENFORCED=' "$LIB"; then
  echo "ERROR: $LIB carries no DISPATCH_ENFORCED= contract marker." >&2
  echo "       Either this is not the dispatch library or the marker was removed." >&2
  exit 2
fi
if ! grep -q -- '--agent work-item-executor' "$LIB"; then
  echo "ERROR: $LIB never invokes the executor by name. There is nothing to test." >&2
  exit 2
fi
if ! grep -q 'DISPATCH_LIB' "$SCRIPT"; then
  echo "ERROR: $SCRIPT does not source a dispatch library: this is the PRE-ITEM-3" >&2
  echo "       runner. Every case below would pass by doing nothing. Aborting." >&2
  exit 2
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/l2-dispatch-fixtures.XXXXXX")" || exit 1
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

# -------------------------------------------------- GH #15 tripwire (read only)
HOST_REPO="$("$REAL_GIT" -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
host_fingerprint() {
  [ -n "$HOST_REPO" ] || { printf 'no-host-repo'; return; }
  printf '%s|%s' "$("$REAL_GIT" -C "$HOST_REPO" rev-parse HEAD 2>/dev/null)" \
                 "$("$REAL_GIT" -C "$HOST_REPO" status --porcelain 2>/dev/null | sort | cksum)"
}
HOST_BEFORE="$(host_fingerprint)"

# ------------------------------------------------------------------- stubs
BIN="$SANDBOX/bin"; sandboxed "$BIN"; mkdir -p "$BIN"

# `git` is REAL — wrapped only to record what was asked. The denylist, the size
# ceiling and the diffstat in the pull request body are all answered by git
# itself against real commits, which is the only version of those checks worth
# asserting.
cat > "$BIN/git" <<GIT_STUB
#!/usr/bin/env bash
set -u
printf 'git %s\n' "\$(printf '%s ' "\$@")" >> "\$FIXTURE_CASE_DIR/calls.log"
exec "$REAL_GIT" "\$@"
GIT_STUB

cat > "$BIN/gh" <<'GH_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
printf 'gh %s\n' "$(printf '%s ' "$@")" >> "$CASE/calls.log"
FLAT="$(printf '%s ' "$@" | tr '\n' ' ')"

# WHICH REPO IS BEING ASKED ABOUT. A cycle spans several repos and the budget
# invariant is about ALL of them, so the stub cannot hold one repo's world: it
# resolves the slug from `--repo`, else from the `repos/<owner>/<name>/` path of
# an api call, else from the working directory the runner cd'd into.
NAME=""
PREV=""
for A in "$@"; do
  case "$PREV" in --repo) NAME="${A##*/}" ;; esac
  case "$A" in repos/*/*) B="${A#repos/}"; B="${B#*/}"; NAME="${B%%/*}"; NAME="${NAME%%\?*}" ;; esac
  PREV="$A"
done
[ -n "$NAME" ] || NAME="$(basename "$PWD")"

case " $FLAT " in
  *" repo view "*" nameWithOwner "*)    printf 'fixture/%s\n' "$(basename "$PWD")"; exit 0 ;;
  *" repo view "*" defaultBranchRef "*) cat "$CASE/default-branch" 2>/dev/null || printf 'main\n'; exit 0 ;;
  *" label list "*)                     exit 0 ;;
  *" label create "*)                   exit 0 ;;
  *" issue list "*)                     cat "$CASE/issues" 2>/dev/null; exit 0 ;;
  # THE BRANCH LIST COMES FROM THE BARE REPO, not from a file this suite keeps in
  # step by hand. A fixture whose idea of the world can drift from the world is a
  # fixture that eventually tests the drift.
  *" api "*"/branches"*)
      if [ -f "$CASE/$NAME-branches-fail" ]; then exit 1; fi
      if [ -f "$CASE/$NAME-branches-empty" ]; then exit 0; fi
      git --git-dir="$CASE/$NAME-origin.git" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
      exit 0 ;;
  *" pr list "*" --state all "*)
      if [ -f "$CASE/$NAME-prs-fail" ]; then exit 1; fi
      # Emitted in the shape the -q filter would have produced: "<STATE> <head>".
      grep -E '^(OPEN|MERGED) ' "$CASE/$NAME-prs" 2>/dev/null
      exit 0 ;;
  *" pr list "*)                        exit 0 ;;
  *" issue view "*" labels "*)          cat "$CASE/issue-labels" 2>/dev/null || printf ',,\n'; exit 0 ;;
  *" issue view "*)                     printf ',,\n'; printf 'fixture issue\n'; exit 0 ;;
  *" pr create "*)
      if [ -f "$CASE/pr-create-fail" ]; then exit 1; fi
      # The body is captured whole so the fixture can read what a human would.
      PREV=""
      for A in "$@"; do
        case "$PREV" in --body)  printf '%s\n' "$A" > "$CASE/$NAME-pr-body.md" ;; esac
        case "$PREV" in --title) printf '%s\n' "$A" > "$CASE/$NAME-pr-title" ;; esac
        PREV="$A"
      done
      printf 'https://example.invalid/%s/pull/777\n' "$NAME"; exit 0 ;;
  *" api "*)                            exit 0 ;;
esac
printf 'gh STUB UNANSWERED: %s\n' "$FLAT" >> "$CASE/calls.log"
printf 'stub cannot answer: %s\n' "$FLAT" >&2
exit 1
GH_STUB

# THE EXECUTOR STUB. It is the one place this suite pretends, so it pretends
# exactly and visibly: it does real work in the real worktree with real git, and
# writes a real status record into the canonical repo root the way an executor
# does. `$CASE/executor.conf` says which executor this run gets.
cat > "$BIN/claude" <<'CLAUDE_STUB'
#!/usr/bin/env bash
set -u
CASE="$FIXTURE_CASE_DIR"
printf 'claude %s\n' "$(printf '%s ' "$@")" >> "$CASE/calls.log"
# The whole invocation, so the allowlist can be asserted rather than assumed.
ROOT0="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
NAME="$(basename "$(dirname "$ROOT0")")"
printf '%s\n' "$*" > "$CASE/$NAME-claude-argv"
printf '%s\n' "$*" > "$CASE/claude-argv"
for A in "$@"; do printf '%s\n' "$A"; done > "$CASE/claude-args"

MODE=normal; STATE=gates-passed; FILES="src/thing.txt"; RC=0; LINES=3
[ -f "$CASE/executor.conf" ] && . "$CASE/executor.conf"

[ "$MODE" = silent ] && exit "$RC"          # produced nothing at all

BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
i=0
for F in $FILES; do
  mkdir -p "$(dirname "$F")" 2>/dev/null || true
  i=0
  while [ "$i" -lt "$LINES" ]; do printf 'executor line %s\n' "$i" >> "$F"; i=$((i + 1)); done
done
git add -A >/dev/null 2>&1
git -c user.name=fixture -c user.email=fixture@example.invalid \
    commit -q -m "feat: work item done by the fixture executor" >/dev/null 2>&1
[ "$MODE" = nopush ] || git push -q -u origin "$BR" >/dev/null 2>&1

if [ "$MODE" != nostatus ]; then
  ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  ROOT="$(dirname "$ROOT")"
  SDIR="$ROOT/$(cat "$CASE/epics-dir" 2>/dev/null || printf 'docs/epics')/$(cat "$CASE/$NAME-epic-folder")/status"
  mkdir -p "$SDIR" 2>/dev/null || true
  SLUG="$(printf '%s' "$BR" | tr '/' '-')"
  cat > "$SDIR/$SLUG.json" <<JSON
{
  "item": "fixture work item",
  "branch": "$BR",
  "state": "$STATE",
  "detail": "written by the fixture executor",
  "commit": "$(git rev-parse --short HEAD 2>/dev/null)",
  "updated": "1970-01-01T00:00:00Z"
}
JSON
fi
exit "$RC"
CLAUDE_STUB
chmod +x "$BIN/git" "$BIN/gh" "$BIN/claude"

# The runner refuses to start without its skill references. Stubbed in the
# sandbox rather than pointed at the real ones, so the reconstruction in case K —
# which lives in the sandbox and cannot resolve them relatively — starts on equal
# terms.
SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references" "$SKILL/agents"
printf 'fixture issue-intake reference\n'  > "$SKILL/references/issue-intake.md"
printf 'fixture plan-template reference\n' > "$SKILL/references/plan-template.md"
printf 'fixture executor contract\n'       > "$SKILL/agents/work-item-executor.md"

# ------------------------------------------------------------------ helpers
# A case is a real bare `origin`, a real clone of it, and the seven control files
# every invocation redirects away from ~/.config/claude-intake.
mkcase() { # $1 = case name [, $2 = integration branch] -> case dir on stdout
  MK_D="$SANDBOX/$1"; sandboxed "$MK_D"
  MK_BASE="${2:-main}"
  rm -rf "$MK_D"
  mkdir -p "$MK_D/worktrees" "$MK_D/home" "$MK_D/promotions"
  : > "$MK_D/calls.log"; : > "$MK_D/issues"
  printf ',,\n' > "$MK_D/issue-labels"
  printf '%s\n' "$MK_BASE" > "$MK_D/default-branch"
  printf 'docs/epics\n' > "$MK_D/epics-dir"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$MK_D/env"
  chmod 600 "$MK_D/env"

  : > "$MK_D/repos"
  add_repo "$MK_D" repo "$MK_BASE"
  printf '%s' "$MK_D"
}

# One more real repository in the same case: a real bare origin and a real clone,
# listed in the repos file. A cycle spans repos, and the budget invariant — one
# item at a time, across ALL of them — cannot be asserted on one.
add_repo() { # $1 = case dir, $2 = repo name, $3 = integration branch
  AR_D="$1"; AR_N="$2"; AR_BASE="${3:-main}"; sandboxed "$AR_D"
  : > "$AR_D/$AR_N-prs"
  "$REAL_GIT" init -q --bare -b "$AR_BASE" "$AR_D/$AR_N-origin.git" 2>/dev/null
  "$REAL_GIT" -c init.defaultBranch="$AR_BASE" init -q "$AR_D/$AR_N" 2>/dev/null
  (
    cd "$AR_D/$AR_N" || exit 1
    "$REAL_GIT" symbolic-ref HEAD "refs/heads/$AR_BASE" 2>/dev/null
    mkdir -p docs/epics src
    printf 'seed\n' > src/seed.txt
    printf 'docs/epics/*/status/\ndocs/epics/.intake\n.env\n' > .gitignore
    "$REAL_GIT" add -A >/dev/null 2>&1
    "$REAL_GIT" -c user.name=fixture -c user.email=fixture@example.invalid \
        commit -q -m "seed" >/dev/null 2>&1
    "$REAL_GIT" remote add origin "$AR_D/$AR_N-origin.git" 2>/dev/null
    "$REAL_GIT" push -q -u origin "$AR_BASE" >/dev/null 2>&1
  )
  printf '%s\n' "$AR_D/$AR_N" >> "$AR_D/repos"
}

# Commit an epic plan into the case's repo and push it, so the runner reads it
# from a real checkout.
add_plan() { # $1 = case dir, $2 = epic folder [, $3 = repo name], body on stdin
  AP_D="$1"; AP_N="${3:-repo}"; sandboxed "$AP_D"
  mkdir -p "$AP_D/$AP_N/$(cat "$AP_D/epics-dir")/$2"
  cat > "$AP_D/$AP_N/$(cat "$AP_D/epics-dir")/$2/plan.md"
  printf '%s\n' "$2" > "$AP_D/$AP_N-epic-folder"
  (
    cd "$AP_D/$AP_N" || exit 1
    "$REAL_GIT" add -A >/dev/null 2>&1
    "$REAL_GIT" -c user.name=fixture -c user.email=fixture@example.invalid \
        commit -q -m "docs: file $2" >/dev/null 2>&1
    "$REAL_GIT" push -q origin HEAD >/dev/null 2>&1
  )
}

# The autonomy config for a repo at a given level, plus the promotion record that
# a level above L0 is refused without.
configure_l2() { # $1 = case dir [, $2 = level, $3 = repo name]
  CL_D="$1"; CL_LEVEL="${2:-L2}"; CL_N="${3:-repo}"; sandboxed "$CL_D"
  cat >> "$CL_D/autonomy" <<CFG
[$CL_D/$CL_N]
level          = $CL_LEVEL
max-files      = 40
max-diff-lines = 800
CFG
  cat > "$CL_D/promotions/fixture__$CL_N.$CL_LEVEL" <<REC
repo: fixture/$CL_N
level: $CL_LEVEL
granted: 2026-08-21T10:00:00Z
granted-by: jonathanstevenson
cycles: 3
ledger: /fixture/ledger.jsonl
evidence: cycles 41,42,43 clean
REC
}

# A provisioning declaration. `smoke` is required of any section that declares
# anything, and a repo that declares no `gates.<type>` is refused at L2 — both
# are item 2b's rules, consumed here rather than restated.
configure_gates() { # $1 = case dir [, $2 = smoke command, $3 = repo name]
  CG_D="$1"; CG_N="${3:-repo}"; sandboxed "$CG_D"
  cat >> "$CG_D/provisioning" <<CFG
[$CG_D/$CG_N]
smoke      = ${2:-true}
gates.unit = true
CFG
  chmod 600 "$CG_D/provisioning"
}

SCRIPT_UNDER_TEST="$SCRIPT"
LIB_UNDER_TEST="$LIB"

run_intake() { # $1 = case dir, rest = extra args -> exit code on stdout
  RI_D="$1"; shift; sandboxed "$RI_D"
  INTAKE_GIT="$BIN/git" INTAKE_GH="$BIN/gh" INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_SKILL_DIR="$SKILL" INTAKE_ENV_FILE="$RI_D/env" \
  INTAKE_REPO_LIST="$RI_D/repos" INTAKE_REPO_DIR="$RI_D/repo" \
  INTAKE_LOG="$RI_D/intake.log" INTAKE_LOCK="$RI_D/.lock" \
  INTAKE_WORKTREE_ROOT="$RI_D/worktrees" \
  INTAKE_AUTONOMY_LIB="$AUTONOMY_LIB_PATH" INTAKE_PROVISION_LIB="$PROVISION_LIB_PATH" \
  INTAKE_STATUS_LIB="$STATUS_LIB_PATH" INTAKE_DISPATCH_LIB="$LIB_UNDER_TEST" \
  INTAKE_AUTONOMY_FILE="$RI_D/autonomy" INTAKE_AUTONOMY_OVERRIDE="$RI_D/AUTONOMY-OFF" \
  INTAKE_STOP_FILE="$RI_D/STOP" INTAKE_PROMOTIONS_DIR="$RI_D/promotions" \
  INTAKE_PROVISION_FILE="$RI_D/provisioning" \
  INTAKE_DISPATCH_TIMEOUT="${FIXTURE_TIMEOUT:-120}" \
  FIXTURE_CASE_DIR="$RI_D" FIXTURE_SANDBOX="$SANDBOX" FIXTURE_REPO_SLUG="fixture/repo" \
  HOME="$RI_D/home" \
    /bin/bash "$SCRIPT_UNDER_TEST" "$@" > "$RI_D/stdout.log" 2> "$RI_D/stderr.log"
  printf '%s' "$?"
}

# Run a snippet with the dispatch library and its two siblings sourced, in its
# own process, with every control file redirected into the case directory.
libsh() { # $1 = case dir, $2 = snippet
  LS_D="$1"; sandboxed "$LS_D"
  INTAKE_GIT="$BIN/git" INTAKE_GH="$BIN/gh" INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_AUTONOMY_FILE="$LS_D/autonomy" INTAKE_AUTONOMY_OVERRIDE="$LS_D/AUTONOMY-OFF" \
  INTAKE_STOP_FILE="$LS_D/STOP" INTAKE_PROMOTIONS_DIR="$LS_D/promotions" \
  INTAKE_PROVISION_FILE="$LS_D/provisioning" \
  D_LIB="$LIB_UNDER_TEST" A_LIB="$AUTONOMY_LIB_PATH" P_LIB="$PROVISION_LIB_PATH" \
  FIXTURE_CASE_DIR="$LS_D" FIXTURE_REPO_SLUG="fixture/repo" \
  HOME="$LS_D/home" \
    /bin/bash -c 'set -u; . "$A_LIB"; . "$P_LIB"; . "$D_LIB"; '"$2" 2>&1
}

# The full log with the timestamps removed, plus the two things that are
# properties of the HARNESS and not of the code: the case directory (two runs of
# a byte-identity pair cannot share one) and the sandbox path, whose mktemp name
# literally contains the string "l2-dispatch-fixtures".
normalise() { # $1 = case dir
  sed -E -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| //' \
         -e "s|$1|<CASE>|g" -e "s|$SANDBOX|<SANDBOX>|g"
}

PLAN_ONE_ITEM='# Epic: a fixture epic

**Status:** approved
**Source:** GH #90

## Work items

### 1. Do the thing
- **Branch:** `feat/the-thing`
- **Depends on:** none
- **Gates:** unit
- **Scope:** `src/thing.txt`
'

echo "sandbox:    $SANDBOX"
echo "runner:     $SCRIPT"
echo "library:    $LIB"
echo "git:        $REAL_GIT ($("$REAL_GIT" --version))"
echo "bash:       $(/bin/bash --version | head -1)"
echo
# =========================================================================
echo "=== A. the plan is machine-readable, and the prose never is ============="
A="$(mkcase A)"
cat > "$A/plan.md" <<'PLAN'
# Epic: reading a real plan

**Status:** in flight (item 2 of 5 — item 1 landed)
**Source:** GH #891 (sev:high, area:source-intake)

## Outcome
Prose that mentions a `- **Branch:** `feat/not-a-real-item`` inline.

## Work items

### 1. HDL emits only the columns that were mapped — DONE (PR #893)
- **Branch:** `fix/891-hdl-emits-only-mapped-columns`
- **Depends on:** none

### 2. The sample shows the HDL line
- **Branch:** `feat/178-the-sample-shows-hdl`
- **Depends on:** 1 — the sample must show the *corrected* output
- **Gates:** web

### 2b. A parallel sibling
- **Branch:** `feat/891-a-parallel-sibling`
- **Depends on:** 1

### 3. A rejected row says why
- **Branch:** `feat/866-the-rejection-points-at-the-mapping`
- **Depends on:** none (independent of 1 and 2)

## Retro

### Deferred
- **Branch:** `feat/this-is-not-a-work-item`

### What was submitted, and what it did to DEV-1
Nothing here is a work item either.
PLAN
ITEMS="$(libsh "$A" 'dispatch_work_items < "$FIXTURE_CASE_DIR/plan.md" | tr "\037" "|"')"
check "A: the status vocabulary reads the first TWO words"  "in-flight" \
      "$(libsh "$A" 'dispatch_plan_state "$FIXTURE_CASE_DIR/plan.md"')"
check "A: the source ref is read, trailing prose and all"   "gh 891" \
      "$(libsh "$A" 'dispatch_plan_source "$FIXTURE_CASE_DIR/plan.md"; printf "%s %s" "$DISPATCH_SOURCE_KIND" "$DISPATCH_SOURCE_NUM"')"
check "A: exactly the four work items, and nothing else"    "4" \
      "$(printf '%s\n' "$ITEMS" | grep -c . | tr -d ' ')"
check "A: '### Deferred' in a later section is NOT a work item" "0" \
      "$(printf '%s\n' "$ITEMS" | grep -c 'this-is-not-a-work-item' | tr -d ' ')"
check "A: a Branch: mentioned in prose is not a work item"  "0" \
      "$(printf '%s\n' "$ITEMS" | grep -c 'not-a-real-item' | tr -d ' ')"
check "A: item ids keep their letters"                      "1|2|2b|3" \
      "$(printf '%s\n' "$ITEMS" | cut -d'|' -f1 | tr '\n' '|' | sed -e 's/|$//')"
check "A: THE PROSE 'DONE (PR #893)' IS NEVER READ AS DONE" "yes" \
      "$(contains "$ITEMS" 'DONE (PR #893)')"
check "A: ...it survives only as the item's TITLE"          "1" \
      "$(printf '%s\n' "$ITEMS" | awk -F'|' '$5 ~ /DONE \(PR #893\)/' | grep -c . | tr -d ' ')"
check "A: an empty middle field does not shift the later ones" "unit-less" \
      "$(printf '%s\n' "$ITEMS" | awk -F'|' '$1 == "1" { print ($3 == "" ? "unit-less" : "SHIFTED:" $3) }')"
check "A: the optional Gates: line is read when present"    "web" \
      "$(printf '%s\n' "$ITEMS" | awk -F'|' '$1 == "2" { print $3 }')"
check "A: 'Depends on: none (independent of 1 and 2)' means NONE" "" \
      "$(libsh "$A" 'dispatch_depends_ids "none (independent of 1 and 2)" | tr "\n" " "' | sed -e 's/ *$//')"
check "A: 'Depends on: 1 — prose' stops at the prose"       "1" \
      "$(libsh "$A" 'dispatch_depends_ids "1 — the sample must show the *corrected* output" | tr "\n" " "' | sed -e 's/ *$//')"
check "A: 'Depends on: 1, 2 and 2b' reads all three"        "1 2 2b" \
      "$(libsh "$A" 'dispatch_depends_ids "1, 2 and 2b" | tr "\n" " "' | sed -e 's/ *$//')"
for S in "**Status:** approved|approved" "**Status:** planning|planning" \
         "**Status:** closed|closed" "**Status:** in flight (item 3 of 4)|in-flight" \
         "**Status:** in flight (items 1-2 of 2, parallel)|in-flight" \
         "**Status:** APPROVED|approved" "**Status:** in|unknown" "nothing at all|unknown"; do
  printf '%s\n' "${S%%|*}" > "$A/state.md"
  check "A: status [${S%%|*}]" "${S##*|}" "$(libsh "$A" 'dispatch_plan_state "$FIXTURE_CASE_DIR/state.md"')"
done
check "A: a branch name with a space is refused, never sanitised" "1" \
      "$(libsh "$A" 'dispatch_branch_ok "deferred to **epic 180 item 5**"; printf "%s" "$?"')"
check "A: ...and a legitimate one is accepted"              "0" \
      "$(libsh "$A" 'dispatch_branch_ok "feat/891-a-thing_here.2"; printf "%s" "$?"')"
check "A: a branch name that could reach the shell is refused" "1" \
      "$(libsh "$A" 'dispatch_branch_ok "feat/x;rm -rf /"; printf "%s" "$?"')"

echo
echo "=== B. epics are ordered NUMERICALLY, and in-flight beats approved ======"
B="$(mkcase B)"
printf '%s' "$PLAN_ONE_ITEM" | sed -e 's|feat/the-thing|feat/e99|' > /dev/null
add_plan "$B" 99-ninety-nine <<'PLAN'
# Epic: ninety-nine
**Status:** approved
**Source:** GH #99
## Work items
### 1. Item of 99
- **Branch:** `feat/e99-item-1`
PLAN
add_plan "$B" 100-one-hundred <<'PLAN'
# Epic: one hundred
**Status:** approved
**Source:** GH #100
## Work items
### 1. Item of 100
- **Branch:** `feat/e100-item-1`
PLAN
add_plan "$B" 07-in-flight <<'PLAN'
# Epic: seven, in flight
**Status:** in flight (item 1 of 1)
**Source:** GH #7
## Work items
### 1. Item of 7
- **Branch:** `feat/e07-item-1`
PLAN
add_plan "$B" 05-closed <<'PLAN'
# Epic: five, closed
**Status:** closed
**Source:** GH #5
## Work items
### 1. Item of 5
- **Branch:** `feat/e05-item-1`
PLAN
add_plan "$B" 06-planning <<'PLAN'
# Epic: six, a proposal
**Status:** planning
**Source:** GH #6
## Work items
### 1. Item of 6
- **Branch:** `feat/e06-item-1`
PLAN
SELECT_B='dispatch_load_signals fixture/repo && dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics && printf "%s %s" "$DISPATCH_EPIC" "$DISPATCH_BRANCH"'
check "B: the in-flight epic is taken before any approved one" "07-in-flight feat/e07-item-1" \
      "$(libsh "$B" "$SELECT_B")"
# With the in-flight epic's only item dispatched, 99 must come before 100.
"$REAL_GIT" --git-dir="$B/repo-origin.git" branch feat/e07-item-1 HEAD >/dev/null 2>&1
check "B: then approved epics in NUMERIC order — 99 before 100" "99-ninety-nine feat/e99-item-1" \
      "$(libsh "$B" "$SELECT_B")"
"$REAL_GIT" --git-dir="$B/repo-origin.git" branch feat/e99-item-1 HEAD >/dev/null 2>&1
check "B: then 100"                                          "100-one-hundred feat/e100-item-1" \
      "$(libsh "$B" "$SELECT_B")"
"$REAL_GIT" --git-dir="$B/repo-origin.git" branch feat/e100-item-1 HEAD >/dev/null 2>&1
check "B: a CLOSED epic is never selected"                   "" "$(libsh "$B" "$SELECT_B")"
check "B: and neither is a PLANNING one — that rung is L1, and this is not it" "0" \
      "$(libsh "$B" "$SELECT_B" | grep -c 'e06' | tr -d ' ')"
# The reserved intake tree cannot be reached: `*/plan.md` does not match a dot.
mkdir -p "$B/repo/docs/epics/.intake"
cat > "$B/repo/docs/epics/.intake/plan.md" <<'PLAN'
# Epic: I am not an epic
**Status:** in flight (item 1 of 1)
**Source:** GH #999
## Work items
### 1. Should never be selected
- **Branch:** `feat/from-the-intake-tree`
PLAN
check "B: an 'in flight' plan.md INSIDE the reserved intake tree is invisible" "" \
      "$(libsh "$B" "$SELECT_B")"

echo
echo "=== C. dispatched means branch-on-origin or open-or-merged PR ==========="
C="$(mkcase C)"
add_plan "$C" 11-fixture <<'PLAN'
# Epic: dispatchability
**Status:** approved
**Source:** GH #90
## Work items
### 1. First
- **Branch:** `feat/c-one`
### 2. Second
- **Branch:** `feat/c-two`
### 3. Third
- **Branch:** `feat/c-three`
PLAN
SELECT_C='dispatch_load_signals fixture/repo && dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics && printf "%s" "$DISPATCH_BRANCH"'
check "C: with nothing on origin the first item is next"     "feat/c-one" "$(libsh "$C" "$SELECT_C")"
"$REAL_GIT" --git-dir="$C/repo-origin.git" branch feat/c-one HEAD >/dev/null 2>&1
check "C: a BRANCH on origin marks it dispatched"            "feat/c-two" "$(libsh "$C" "$SELECT_C")"
printf 'OPEN feat/c-two\n' > "$C/repo-prs"
check "C: an OPEN pull request marks it dispatched too"      "feat/c-three" "$(libsh "$C" "$SELECT_C")"
printf 'OPEN feat/c-two\nMERGED feat/c-three\n' > "$C/repo-prs"
check "C: so does a MERGED one, whose branch was deleted"    "" "$(libsh "$C" "$SELECT_C")"
printf 'OPEN feat/c-two\nCLOSED feat/c-three\n' > "$C/repo-prs"
check "C: a CLOSED-unmerged PR does NOT — abandoned work is not delivered" "feat/c-three" \
      "$(libsh "$C" "$SELECT_C")"
: > "$C/repo-prs"
touch "$C/repo-branches-fail"
check "C: a failed branch query REFUSES rather than guessing" "yes" \
      "$(contains "$(libsh "$C" 'dispatch_load_signals fixture/repo || printf "%s" "$DISPATCH_REFUSAL"')" "refusing rather than guessing")"
rm -f "$C/repo-branches-fail"; touch "$C/repo-branches-empty"
check "C: an EMPTY branch list is read as a failed query, not as no branches" "yes" \
      "$(contains "$(libsh "$C" 'dispatch_load_signals fixture/repo || printf "%s" "$DISPATCH_REFUSAL"')" "came back empty")"
rm -f "$C/repo-branches-empty"; touch "$C/repo-prs-fail"
check "C: a failed PR query refuses too"                     "yes" \
      "$(contains "$(libsh "$C" 'dispatch_load_signals fixture/repo || printf "%s" "$DISPATCH_REFUSAL"')" "refusing rather than guessing")"
rm -f "$C/repo-prs-fail"

echo
echo "=== D. a missing or unusable Branch: line is REFUSED, never guessed ====="
D="$(mkcase D)"
add_plan "$D" 12-fixture <<'PLAN'
# Epic: the refusals
**Status:** approved
**Source:** GH #90
## Work items
### 1. Fine
- **Branch:** `feat/d-one`
### 2. CANCELLED — no branch was ever cut
- **Depends on:** none
### 3. Would be next if 2 were skipped
- **Branch:** `feat/d-three`
PLAN
"$REAL_GIT" --git-dir="$D/repo-origin.git" branch feat/d-one HEAD >/dev/null 2>&1
OUT="$(libsh "$D" 'dispatch_load_signals fixture/repo && { dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics || printf "%s" "$DISPATCH_REFUSAL"; }')"
check "D: an item with no Branch: line refuses"              "yes" \
      "$(contains "$OUT" "carries no \`- **Branch:**\` line")"
check "D: ...naming the item"                                "yes" "$(contains "$OUT" "item 2")"
check "D: ...and saying it is refused, not guessed at"       "yes" \
      "$(contains "$OUT" "refused, not guessed at")"
check "D: NO LATER ITEM OF THAT EPIC IS CONSIDERED"          "0" \
      "$(printf '%s' "$OUT" | grep -c 'feat/d-three' | tr -d ' ')"
D2="$(mkcase D2)"
add_plan "$D2" 12-fixture <<'PLAN'
# Epic: a branch field that is prose
**Status:** approved
**Source:** GH #90
## Work items
### 1. Deferred elsewhere
- **Branch:** deferred to **epic 180 item 5**
PLAN
OUT="$(libsh "$D2" 'dispatch_load_signals fixture/repo && { dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics || printf "%s" "$DISPATCH_REFUSAL"; }')"
check "D2: a Branch: field that is prose is refused"         "yes" \
      "$(contains "$OUT" "not a usable git branch name")"
check "D2: ...rather than sanitised into something the plan did not say" "yes" \
      "$(contains "$OUT" "refused rather than sanitised")"

echo
echo "=== E. a dependency must be MERGED, not merely dispatched ==============="
E="$(mkcase E)"
add_plan "$E" 13-fixture <<'PLAN'
# Epic: sequencing
**Status:** approved
**Source:** GH #90
## Work items
### 1. First
- **Branch:** `feat/e-one`
- **Depends on:** none
### 2. Second
- **Branch:** `feat/e-two`
- **Depends on:** 1
### 2b. Parallel with 2
- **Branch:** `feat/e-two-b`
- **Depends on:** 1
PLAN
"$REAL_GIT" --git-dir="$E/repo-origin.git" branch feat/e-one HEAD >/dev/null 2>&1
printf 'OPEN feat/e-one\n' > "$E/repo-prs"
OUT="$(libsh "$E" 'dispatch_load_signals fixture/repo && { dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics || printf "%s" "$DISPATCH_REFUSAL"; }')"
check "E: item 1 dispatched but UNMERGED blocks item 2"      "yes" \
      "$(contains "$OUT" "has no MERGED pull request")"
check "E: ...and says why, in terms of the integration branch" "yes" \
      "$(contains "$OUT" "does not contain its dependency")"
check "E: ...and calls it a wait rather than a failure"      "yes" \
      "$(contains "$OUT" "this is a wait, not a failure")"
printf 'MERGED feat/e-one\n' > "$E/repo-prs"
check "E: once item 1 is MERGED, item 2 is next"             "feat/e-two" \
      "$(libsh "$E" 'dispatch_load_signals fixture/repo && dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics && printf "%s" "$DISPATCH_BRANCH"')"
"$REAL_GIT" --git-dir="$E/repo-origin.git" branch feat/e-two HEAD >/dev/null 2>&1
check "E: 2b depends on 1 only, so an unmerged 2 does not block it" "feat/e-two-b" \
      "$(libsh "$E" 'dispatch_load_signals fixture/repo && dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics && printf "%s" "$DISPATCH_BRANCH"')"
E2="$(mkcase E2)"
add_plan "$E2" 13-fixture <<'PLAN'
# Epic: an unresolvable dependency
**Status:** approved
**Source:** GH #90
## Work items
### 1. Depends on something that is not here
- **Branch:** `feat/e2-one`
- **Depends on:** 4
PLAN
OUT="$(libsh "$E2" 'dispatch_load_signals fixture/repo && { dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics || printf "%s" "$DISPATCH_REFUSAL"; }')"
check "E2: a dependency the plan does not contain refuses"   "yes" \
      "$(contains "$OUT" "which this plan does not contain")"
E3="$(mkcase E3)"
add_plan "$E3" 13-fixture <<'PLAN'
# Epic: an out-of-order dependency
**Status:** approved
**Source:** GH #90
## Work items
### 1. Depends on a LATER item
- **Branch:** `feat/e3-one`
- **Depends on:** 2
### 2. Written after the item that needs it
- **Branch:** `feat/e3-two`
PLAN
OUT="$(libsh "$E3" 'dispatch_load_signals fixture/repo && { dispatch_select "$FIXTURE_CASE_DIR/repo" docs/epics || printf "%s" "$DISPATCH_REFUSAL"; }')"
check "E3: an out-of-order dependency refuses rather than picking a reading" "yes" \
      "$(contains "$OUT" "does not reason about out-of-order sequencing")"

echo
echo "=== F. admission: the level, the labels, and the budget ================="
mk_dispatchable() { # $1 = case dir [, $2 = extra work-item lines]
  MD_D="$1"; sandboxed "$MD_D"
  add_plan "$MD_D" 11-fixture <<PLAN
# Epic: a dispatchable fixture epic

**Status:** approved
**Source:** GH #90

## Work items

### 1. Do the thing
- **Branch:** \`feat/the-thing\`
- **Depends on:** none
- **Gates:** unit
- **Scope:** \`src/thing.txt\`
${2:-}
PLAN
  configure_l2 "$MD_D"
  configure_gates "$MD_D"
}

F="$(mkcase F)"; mk_dispatchable "$F"
rm -f "$F/autonomy" "$F/promotions/fixture__repo.L2"
RC="$(run_intake "$F")"
check "F: with NO autonomy config nothing is dispatched"     "0" \
      "$(grep -c 'L2' "$F/intake.log" | tr -d ' ')"
check "F: ...and the cycle still exits 0"                    "0" "$RC"
F2="$(mkcase F2)"; mk_dispatchable "$F2"
rm -f "$F2/promotions/fixture__repo.L2"
RC="$(run_intake "$F2")"
check "F2: L2 without a promotion record resolves L0"        "yes" \
      "$(yesno grep -q 'pinned to L0' "$F2/intake.log")"
check "F2: ...so no executor is invoked"                     "0" \
      "$(grep -c '^claude ' "$F2/calls.log" | tr -d ' ')"
F3="$(mkcase F3)"; mk_dispatchable "$F3"
printf 'require-labels = epic:planned\n' >> "$F3/autonomy"
printf ',bug,\n' > "$F3/issue-labels"
RC="$(run_intake "$F3")"
check "F3: a required label the source issue lacks refuses"  "yes" \
      "$(yesno grep -q "required label 'epic:planned' is absent" "$F3/intake.log")"
check "F3: ...before any worktree exists"                    "0" \
      "$(ls -A "$F3/worktrees" 2>/dev/null | grep -c . | tr -d ' ')"
F4="$(mkcase F4)"; mk_dispatchable "$F4"
printf 'forbid-labels = do-not-automate\n' >> "$F4/autonomy"
printf ',do-not-automate,\n' > "$F4/issue-labels"
RC="$(run_intake "$F4")"
check "F4: a forbidden label on the source issue refuses"    "yes" \
      "$(yesno grep -q "forbidden label 'do-not-automate' is present" "$F4/intake.log")"
# THE BUDGET SPANS THE WHOLE CYCLE, NOT ONE REPO. "One item at a time" is an
# epic 11 invariant, so the assertion needs two repositories that are BOTH
# dispatchable: the first must be dispatched and the second must be refused by
# the budget, naming it.
F5="$(mkcase F5)"
add_repo "$F5" repo2 main
mk_dispatchable "$F5"
configure_l2 "$F5" L2 repo2
configure_gates "$F5" true repo2
add_plan "$F5" 11-fixture repo2 <<'PLAN'
# Epic: the second repo's epic
**Status:** approved
**Source:** GH #91
## Work items
### 1. Do the other thing
- **Branch:** `feat/the-other-thing`
- **Depends on:** none
- **Gates:** unit
PLAN
RC="$(run_intake "$F5")"
check "F5: the cycle exits 0"                                "0" "$RC"
check "F5: the FIRST repo's item is dispatched"              "1"       "$(grep -c 'L2: fixture/repo — next undispatched item' "$F5/intake.log" | tr -d ' ')"
check "F5: ...and reaches an open pull request"              "yes"       "$(yesno grep -q 'https://example.invalid/repo/pull/777' "$F5/intake.log")"
check "F5: THE SECOND REPO IS STOPPED BY THE BUDGET, and says so" "yes"       "$(yesno grep -q 'per-cycle item budget reached (1)' "$F5/intake.log")"
check "F5: ...so exactly ONE executor ran in the whole cycle" "1"       "$(grep -c '^claude ' "$F5/calls.log" | tr -d ' ')"
# Anchored at the start of the line: the brief the runner hands the executor
# CONTAINS the string `gh pr create` — it is telling the executor it does not
# have that tool — and the stub logs the brief verbatim into the call stream.
check "F5: ...and exactly ONE pull request was created"      "1" "$(grep -c '^gh pr create' "$F5/calls.log" | tr -d ' ')"
check "F5: the second repo's branch was never cut on its origin" "0"       "$("$REAL_GIT" --git-dir="$F5/repo2-origin.git" for-each-ref --format='%(refname:short)' refs/heads | grep -c 'the-other-thing' | tr -d ' ')"
F6="$(mkcase F6)"; mk_dispatchable "$F6"
{ printf '[global]\nbudget.max-wall-clock = 1s\n\n'; cat "$F6/autonomy"; } > "$F6/autonomy.new"
mv "$F6/autonomy.new" "$F6/autonomy"
check "F6: an exhausted wall-clock budget stops a dispatch, and says so" "yes" \
      "$(contains "$(libsh "$F6" 'autonomy_resolve "$FIXTURE_CASE_DIR/repo" fixture/repo; DISPATCH_CYCLE_START=1; dispatch_repo "$FIXTURE_CASE_DIR/repo" fixture/repo docs/epics main "$FIXTURE_CASE_DIR/worktrees" no /nonexistent')" "per-cycle wall-clock budget reached (1s)")"

echo
echo "=== G. L2 requires a DECLARED gate set — a hope is not a gate ==========="
G="$(mkcase G)"; mk_dispatchable "$G"
rm -f "$G/provisioning"
RC="$(run_intake "$G")"
check "G: a repo declaring no gates is refused at L2"        "yes" \
      "$(yesno grep -q 'L2 dispatch requires the repo to declare gates' "$G/intake.log")"
check "G: ...before any executor runs"                       "0" \
      "$(grep -c '^claude ' "$G/calls.log" | tr -d ' ')"
check "G: ...and L0 drafting is explicitly unaffected"       "0" "$RC"
G2="$(mkcase G2)"; mk_dispatchable "$G2"
cat > "$G2/provisioning" <<CFG
[$G2/repo]
smoke      = true
gates.api  = echo api-gate
gates.web  = echo web-gate
CFG
chmod 600 "$G2/provisioning"
RC="$(run_intake "$G2")"
check "G2: an item naming an UNDECLARED type is refused"     "yes" \
      "$(yesno grep -q "no gate set named 'unit' is declared" "$G2/intake.log")"
check "G2: ...naming what IS declared, so a human can fix it" "yes" \
      "$(yesno grep -q 'declared: api web' "$G2/intake.log")"
check "G2: ...and never falls back to the repo's usual gate" "0" \
      "$(grep -c '^claude ' "$G2/calls.log" | tr -d ' ')"
G3="$(mkcase G3)"; mk_dispatchable "$G3"
sed -i.bak '/- \*\*Gates:\*\* unit/d' "$G3/repo/docs/epics/11-fixture/plan.md" && rm -f "$G3/repo/docs/epics/11-fixture/plan.md.bak"
( cd "$G3/repo" && "$REAL_GIT" add -A >/dev/null 2>&1 && "$REAL_GIT" -c user.name=f -c user.email=f@e.invalid commit -q -m x >/dev/null 2>&1 && "$REAL_GIT" push -q origin HEAD >/dev/null 2>&1 )
cat > "$G3/provisioning" <<CFG
[$G3/repo]
smoke      = true
gates.web  = echo web-gate
gates.api  = echo api-gate
CFG
chmod 600 "$G3/provisioning"
RC="$(run_intake "$G3")"
check "G3: an item naming NO type gets EVERY declared gate"  "yes" \
      "$(contains "$(cat "$G3/claude-argv" 2>/dev/null)" "1. echo web-gate")"
check "G3: ...in DECLARATION order, not sorted"              "yes" \
      "$(contains "$(cat "$G3/claude-argv" 2>/dev/null)" "2. echo api-gate")"
check "G3: ...and the brief forbids substituting an equivalent" "yes" \
      "$(contains "$(cat "$G3/claude-argv" 2>/dev/null)" "Do NOT substitute a gate you believe is equivalent")"
G4="$(mkcase G4)"; mk_dispatchable "$G4"
rm -f "$G4/provisioning"; configure_gates "$G4" "false"
RC="$(run_intake "$G4")"
check "G4: A FAILING SMOKE CHECK REFUSES THE DISPATCH"       "yes" \
      "$(yesno grep -q 'THE SMOKE CHECK FAILED' "$G4/intake.log")"
check "G4: ...loudly, saying no dispatch may proceed"        "yes" \
      "$(yesno grep -q 'worktree provisioning refused this dispatch' "$G4/intake.log")"
check "G4: ...and no executor is invoked into a worktree that cannot run" "0" \
      "$(grep -c '^claude ' "$G4/calls.log" | tr -d ' ')"
check "G4: ...leaving NOTHING on origin, so a transient failure does not retire the item" "0" \
      "$("$REAL_GIT" --git-dir="$G4/repo-origin.git" for-each-ref --format='%(refname:short)' refs/heads | grep -c 'feat/the-thing' | tr -d ' ')"
check "G4: ...and no worktree behind"                        "0" \
      "$(ls -A "$G4/worktrees" 2>/dev/null | grep -c . | tr -d ' ')"

echo
echo "=== H. A COMPLETED L2 CYCLE STOPS AT AN OPEN PULL REQUEST ==============="
# THE INVARIANT THIS ITEM EXISTS TO PRESERVE, stated as a fixture rather than as
# a promise: the cycle runs all the way through, and at the end the pull request
# is OPEN, the issue is OPEN, and nothing is merged. Everything else in this
# suite is a refusal; this is the one case that succeeds, which is exactly why it
# is the one that has to be pinned.
H="$(mkcase H)"; mk_dispatchable "$H"
RC="$(run_intake "$H")"
check "H: the cycle exits 0"                                 "0" "$RC"
check "H: the item was selected from the Branch: line"       "yes" \
      "$(yesno grep -q 'next undispatched item is 11-fixture item 1 (Do the thing) on branch feat/the-thing' "$H/intake.log")"
check "H: the branch was pushed BEFORE the executor ran"     "yes" \
      "$(yesno grep -q 'the item is now marked dispatched whatever happens next' "$H/intake.log")"
check "H: the executor was invoked by name"                   "yes" \
      "$(contains "$(cat "$H/claude-argv")" "--agent work-item-executor")"
# ONE file, because the item touched one. The runner's own executor log lives in
# the worktree's admin directory precisely so it cannot end up in this number.
check "H: the diff was admitted, with its real numbers"      "yes" \
      "$(yesno grep -q 'L2: diff admitted — 1 file(s), 3 line(s), no denylisted path' "$H/intake.log")"
check "H: a pull request was opened"                         "1" \
      "$(grep -c '^gh pr create' "$H/calls.log" | tr -d ' ')"
check "H: ...against the INTEGRATION branch"                 "yes" \
      "$(yesno grep -q '^gh pr create --repo fixture/repo --base main --head feat/the-thing' "$H/calls.log")"
check "H: ...and the log carries its URL"                    "yes" \
      "$(yesno grep -q 'https://example.invalid/repo/pull/777' "$H/intake.log")"
check "H: the branch really is on origin, with the work on it" "1" \
      "$("$REAL_GIT" --git-dir="$H/repo-origin.git" for-each-ref --format='%(refname:short)' refs/heads | grep -c '^feat/the-thing$' | tr -d ' ')"
check "H: ...and it is AHEAD of the integration branch"      "yes" \
      "$(yesno test "$("$REAL_GIT" --git-dir="$H/repo-origin.git" rev-parse feat/the-thing)" != "$("$REAL_GIT" --git-dir="$H/repo-origin.git" rev-parse main)")"

# ---- THE HARD STOPS, asserted against the CALL STREAM of a SUCCESSFUL run.
check "H: NOTHING WAS MERGED — no pr merge in the whole cycle" "0" \
      "$(grep -c '^gh pr merge' "$H/calls.log" | tr -d ' ')"
check "H: NO ISSUE WAS CLOSED"                               "0" \
      "$(grep -c '^gh issue close' "$H/calls.log" | tr -d ' ')"
check "H: NO ISSUE WAS EDITED — not even a label"            "0" \
      "$(grep -c '^gh issue edit' "$H/calls.log" | tr -d ' ')"
check "H: NO ISSUE WAS COMMENTED ON"                         "0" \
      "$(grep -c '^gh issue comment' "$H/calls.log" | tr -d ' ')"
check "H: NO PULL REQUEST WAS EDITED, REVIEWED OR APPROVED"  "0" \
      "$(grep -cE '^gh pr (edit|review|ready|close)' "$H/calls.log" | tr -d ' ')"
check "H: THE INTEGRATION BRANCH WAS NEVER PUSHED TO"        "0" \
      "$(grep -cE '^git .* push .*(HEAD:|:)?main( |$)' "$H/calls.log" | tr -d ' ')"
check "H: ...and origin/main is exactly where it started"    "yes" \
      "$(yesno test "$("$REAL_GIT" --git-dir="$H/repo-origin.git" rev-parse main)" = "$("$REAL_GIT" -C "$H/repo" rev-parse main)")"
check "H: THE PLAN WAS NOT EDITED"                           "" \
      "$("$REAL_GIT" -C "$H/repo" status --porcelain -- docs/epics/11-fixture/plan.md)"
check "H: ...and still reads Status: approved, not approved-by-a-machine" "approved" \
      "$(libsh "$H" 'dispatch_plan_state "$FIXTURE_CASE_DIR/repo/docs/epics/11-fixture/plan.md"')"
check "H: the executor's worktree was removed, credentials and all" "0" \
      "$(ls -A "$H/worktrees" 2>/dev/null | grep -c . | tr -d ' ')"

# ---- what a human reads: the pull request body.
BODY="$(cat "$H/repo-pr-body.md" 2>/dev/null)"
check "H: the PR says a machine opened it and nobody read the diff" "yes" \
      "$(contains "$BODY" "Opened by an unattended L2 dispatch cycle. No human has read this diff.")"
check "H: it carries 'Part of #90' EXACTLY once"             "1" \
      "$(printf '%s\n' "$BODY" | grep -c 'Part of #90' | tr -d ' ')"
check "H: and NO closing keyword — a merge here closes nothing" "0" \
      "$(printf '%s\n' "$BODY" | grep -ciE '(clos(e|es|ed)|fix(es|ed)?|resolv(e|es|ed))[[:space:]]*:?[[:space:]]*#90' | tr -d ' ')"
check "H: it names the epic and the item"                    "yes" \
      "$(contains "$BODY" "Item: 1 — Do the thing")"
check "H: it pastes the real diff numbers, not a description" "yes" \
      "$(contains "$BODY" "**1 file(s)**, **3 line(s)** added+deleted")"
check "H: it reports the executor's own milestone verbatim"  "yes" \
      "$(contains "$BODY" '**`gates-passed`**')"
check "H: it states plainly that the runner did NOT re-run the gates" "yes" \
      "$(contains "$BODY" "Not verified by the runner, stated plainly")"
check "H: the title marks it unattended, so a PR list shows it" "yes" \
      "$(contains "$(cat "$H/repo-pr-title" 2>/dev/null)" "[unattended]")"

# ---- the control plane: the runner reports where the orchestrator looks.
HREC="$H/repo/docs/epics/.intake/status/dispatch-feat-the-thing.json"
check "H: a dispatch record was written into the reserved intake tree" "yes" \
      "$(yesno test -f "$HREC")"
check "H: ...and it ends at pr-opened"                       "yes" \
      "$(yesno grep -q '"state": "pr-opened"' "$HREC")"
check "H: ...carrying the PR url"                            "yes" \
      "$(yesno grep -q 'https://example.invalid/repo/pull/777' "$HREC")"
check "H: ...named dispatch-*, so it cannot be read as the executor's own record" "0" \
      "$(ls "$H/repo/docs/epics/.intake/status/" 2>/dev/null | grep -c '^feat-the-thing.json$' | tr -d ' ')"
check "H: every transition is in the ledger"                 "yes" \
      "$(yesno grep -q '"kind":"dispatch"' "$H/repo/docs/epics/.intake/status/ledger.jsonl")"
check "H: ...exactly once for pr-opened"                     "1" \
      "$(grep -c '"kind":"dispatch","state":"pr-opened"' "$H/repo/docs/epics/.intake/status/ledger.jsonl" | tr -d ' ')"
check "H: the executor's OWN status file is in the EPIC's tree, not this one" "yes" \
      "$(yesno test -f "$H/repo/docs/epics/11-fixture/status/feat-the-thing.json")"

# ---- the second cycle does not do it again.
printf 'OPEN feat/the-thing\n' > "$H/repo-prs"
RC="$(run_intake "$H")"
check "H: A SECOND CYCLE DOES NOT RE-DISPATCH THE SAME ITEM"  "1" \
      "$(grep -c '^claude ' "$H/calls.log" | tr -d ' ')"
check "H: ...it reports there is nothing left to dispatch"    "yes" \
      "$(yesno grep -q 'no approved or in-flight epic has an undispatched work item' "$H/intake.log")"
check "H: ...and opened no second pull request"               "1" \
      "$(grep -c '^gh pr create' "$H/calls.log" | tr -d ' ')"

echo
echo "=== I. after the executor returns, the diff is checked and can REFUSE ==="
I1="$(mkcase I1)"; mk_dispatchable "$I1"
printf 'FILES=".github/workflows/ci.yml"\n' > "$I1/executor.conf"
RC="$(run_intake "$I1")"
check "I1: A DENYLISTED PATH IN THE REAL DIFF REFUSES THE PR"  "0" \
      "$(grep -c '^gh pr create' "$I1/calls.log" | tr -d ' ')"
check "I1: ...naming the path AND the pattern that caught it"  "yes" \
      "$(yesno grep -q '.github/workflows/ci.yml (matched .github/\*)' "$I1/intake.log")"
check "I1: ...and the branch is LEFT for a human, not deleted" "1" \
      "$("$REAL_GIT" --git-dir="$I1/repo-origin.git" for-each-ref --format='%(refname:short)' refs/heads | grep -c '^feat/the-thing$' | tr -d ' ')"
check "I1: ...with the executor's work actually on it"        "yes" \
      "$(yesno test "$("$REAL_GIT" --git-dir="$I1/repo-origin.git" rev-parse feat/the-thing)" != "$("$REAL_GIT" --git-dir="$I1/repo-origin.git" rev-parse main)")"
check "I1: ...and the record says refused"                    "yes" \
      "$(yesno grep -q '"state": "refused"' "$I1/repo/docs/epics/.intake/status/dispatch-feat-the-thing.json")"
check "I1: THE DENYLIST WAS CHECKED AGAINST THE DIFF, so the plan's prose is irrelevant" "yes" \
      "$(yesno grep -q 'sensitive-path denylist' "$I1/intake.log")"
I1B="$(mkcase I1B)"; mk_dispatchable "$I1B"
printf 'FILES="install.sh"\n' > "$I1B/executor.conf"
RC="$(run_intake "$I1B")"
check "I1B: the floor covers install.sh too, and no config shrinks it" "yes" \
      "$(yesno grep -q 'install.sh (matched install.sh)' "$I1B/intake.log")"
I2="$(mkcase I2)"; mk_dispatchable "$I2"
sed -i.bak 's/^max-diff-lines = 800/max-diff-lines = 2/' "$I2/autonomy" && rm -f "$I2/autonomy.bak"
RC="$(run_intake "$I2")"
check "I2: a diff over the size ceiling refuses the PR"      "0" \
      "$(grep -c '^gh pr create' "$I2/calls.log" | tr -d ' ')"
check "I2: ...naming the number and the ceiling"             "yes" \
      "$(yesno grep -q 'diff changes 3 lines; the ceiling is 2' "$I2/intake.log")"
I3="$(mkcase I3)"; mk_dispatchable "$I3"
printf 'STATE=blocked\n' > "$I3/executor.conf"
RC="$(run_intake "$I3")"
check "I3: an executor that returns blocked opens NO pull request" "0" \
      "$(grep -c '^gh pr create' "$I3/calls.log" | tr -d ' ')"
check "I3: ...and says the epic is left alone"               "yes" \
      "$(yesno grep -q 'the epic is left alone' "$I3/intake.log")"
check "I3: ...and that it is NOT retried"                    "yes" \
      "$(yesno grep -q 'this is NOT retried' "$I3/intake.log")"
check "I3: ...recorded as blocked, not as failed"            "yes" \
      "$(yesno grep -q '"state": "blocked"' "$I3/repo/docs/epics/.intake/status/dispatch-feat-the-thing.json")"
RC="$(run_intake "$I3")"
check "I3: THE NEXT CYCLE DOES NOT RETRY IT — the branch on origin says so" "1" \
      "$(grep -c '^claude ' "$I3/calls.log" | tr -d ' ')"
I4="$(mkcase I4)"; mk_dispatchable "$I4"
printf 'MODE=nostatus\n' > "$I4/executor.conf"
RC="$(run_intake "$I4")"
check "I4: an executor that wrote NO milestone gets no pull request" "0" \
      "$(grep -c '^gh pr create' "$I4/calls.log" | tr -d ' ')"
check "I4: ...and the refusal names the failure it is preventing" "yes" \
      "$(yesno grep -q "gates reported skipped, PR opened anyway" "$I4/intake.log")"
I5="$(mkcase I5)"; mk_dispatchable "$I5"
printf 'STATE=implementing\n' > "$I5/executor.conf"
RC="$(run_intake "$I5")"
check "I5: an executor that stopped short of gates-passed gets no PR" "0" \
      "$(grep -c '^gh pr create' "$I5/calls.log" | tr -d ' ')"
check "I5: ...naming the milestone it actually reached"      "yes" \
      "$(yesno grep -q "last milestone was \`implementing\`" "$I5/intake.log")"
I6="$(mkcase I6)"; mk_dispatchable "$I6"
printf 'RC=7\n' > "$I6/executor.conf"
RC="$(run_intake "$I6")"
check "I6: an executor that exits nonzero gets no pull request" "0" \
      "$(grep -c '^gh pr create' "$I6/calls.log" | tr -d ' ')"
check "I6: ...and the cycle reports the failure honestly"    "4" "$RC"
check "I6: ...naming the exit code"                          "yes" \
      "$(yesno grep -q 'the executor exited 7' "$I6/intake.log")"
I7="$(mkcase I7)"; mk_dispatchable "$I7"
printf 'MODE=silent\n' > "$I7/executor.conf"
RC="$(run_intake "$I7")"
check "I7: an executor that changed nothing gets no pull request" "0" \
      "$(grep -c '^gh pr create' "$I7/calls.log" | tr -d ' ')"
check "I7: ...and the refusal says there is nothing to propose" "yes" \
      "$(yesno grep -q 'wrote no status record at all' "$I7/intake.log")"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
