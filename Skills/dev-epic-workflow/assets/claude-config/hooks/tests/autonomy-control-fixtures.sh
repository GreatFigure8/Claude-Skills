#!/usr/bin/env bash
# Fixture harness for THE AUTONOMY CONTROL SURFACE (epic 11 item 1), across both
# halves of the mechanism:
#   ../../bin/autonomy.sh            — parses and validates the config, resolves
#                                      a per-repo level, checks the promotion
#                                      record, and answers the admission policy
#   ../../bin/unattended-intake.sh   — honours the cycle stop file, reports a
#                                      refused config and the global override,
#                                      and logs the resolved level WITHOUT
#                                      acting on it
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT.
# It proves the MECHANISM: that every control parses, that every malformed input
# is refused with a message naming the problem, that the stop file stops a cycle
# before anything else happens, that the global override pins a configured level
# to L0 while leaving drafting running, that the denylist refuses a real diff and
# names the path — and, above all, that a machine with no autonomy configuration
# produces BYTE-IDENTICAL output to the runner as it stood before this item.
# It does NOT prove that any of it governs a dispatch, because in this item
# nothing does: `AUTONOMY_ENFORCED=no` and case P asserts it. Epic 11 item 3 is
# what wires the switchboard, and its own fixtures are what will prove that.
#
# THE NEGATIVE CONTROL, BUILT BRITTLE ON PURPOSE (epic 09 items 4, 6, 7 and 8 all
# do this and it is why they were trustworthy). A suite that passes against the
# code as it stood BEFORE the item is a suite that tests nothing:
#   - it hard-errors at startup if the library is absent or does not carry the
#     `AUTONOMY_ENFORCED=` contract marker, rather than skipping quietly
#   - case K reconstructs the PRE-ITEM-1 runner by deleting the item's own 83
#     added lines and REQUIRES the reconstruction to be exactly 83 lines shorter,
#     to still parse, and to differ — if the blocks move, the suite stops rather
#     than proving nothing
#   - case L runs the stop-file scenario against that pre-item-1 runner and
#     requires the cycle to RUN, so the passing case is discriminating
#   - cases Q1–Q3 are library mutants (a shrunken denylist floor, an advisory
#     override, a pass-through promotion check) that must each break a case that
#     passes on the shipped library
#
# SANDBOXING (GH #15 is open and unfixed: a harness in this repo has already
# escaped its sandbox and committed a real working tree). Everything — the
# "GitHub" origin, the checkout, the worktree root, the config, the logs, the
# stub binaries — lives under one `mktemp -d` removed on exit, and every
# destructive path goes through sandboxed(). No git command here or in any stub
# names the repo this file lives in. Nothing is installed.
#
# IT NEVER READS OR WRITES ~/.config/claude-intake. Every one of the four
# control files is redirected through INTAKE_AUTONOMY_FILE,
# INTAKE_AUTONOMY_OVERRIDE, INTAKE_STOP_FILE and INTAKE_PROMOTIONS_DIR, and HOME
# itself is redirected into the sandbox, so a machine running a live unattended
# timer is untouched by this suite and this suite is unaffected by it.
#
# THE STUB LESSON, ENFORCED RATHER THAN REMEMBERED. A `gh` stub that does not
# answer a query the script newly makes does not fail — it silently degrades,
# and the suite goes green while exercising the wrong path. That cost epic 09
# five separate corrections. This item adds no new gh query at all, which is
# itself an assertion (case P), and the STUB UNANSWERED tripwire at the end is
# what would catch it if a later edit added one.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/autonomy-control-fixtures.sh
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-unattended-intake.sh bash ...
#         INTAKE_FIXTURE_AUTONOMY_LIB=/path/to/other-autonomy.sh bash ...
#           (both overrides exist so this suite can be pointed at a PRE-ITEM-1
#            tree as a negative control; it must NOT pass there)
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/unattended-intake.sh}"
LIB="${INTAKE_FIXTURE_AUTONOMY_LIB:-$BIN_DIR/autonomy.sh}"

# ---------------------------------------- the negative control's tripwire
# Not a skip, not a warning: an abort. Pointed at a pre-item-1 tree this suite
# must stop with a message, because a suite that "passes" where the feature does
# not exist is worse than no suite.
[ -f "$SCRIPT" ] || { echo "ERROR: not found: $SCRIPT" >&2; exit 1; }
if [ ! -f "$LIB" ]; then
  echo "ERROR: no autonomy control surface at $LIB." >&2
  echo "       This suite tests epic 11 item 1. Against a tree that predates it" >&2
  echo "       there is nothing to test, and passing would be a lie. Aborting." >&2
  exit 1
fi
if ! grep -q '^AUTONOMY_ENFORCED=' "$LIB"; then
  echo "ERROR: $LIB carries no AUTONOMY_ENFORCED= contract marker." >&2
  echo "       Either it is not the control surface, or the marker was removed —" >&2
  echo "       and the marker IS the inertness claim. Aborting." >&2
  exit 1
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/autonomy-control-fixtures.XXXXXX")" || exit 1
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
  printf '%-64s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$2" "$3" "$VERDICT"
}
contains() { # $1 haystack  $2 needle -> yes/no
  case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
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

# ------------------------------------------------------------------- stubs
# Modelled directly on intake-collision-fixtures.sh, which already answers every
# query a full cycle makes. Kept in the same shape deliberately: this item adds
# no gh query, and a stub that drifted from that one would hide the fact.
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
  repo)
    case "$FLAT" in
      *nameWithOwner*)    printf '%s\n' "${FIXTURE_REPO_SLUG:-fixture/repo}" ;;
      *defaultBranchRef*) printf '%s\n' "${FIXTURE_DEFAULT_BRANCH:-main}" ;;
      *) unanswered "repo field set not modelled" ;;
    esac ;;
  label)
    case "${2:-}" in
      list)   printf '%s\tfixture label\n' "${FIXTURE_LABEL:-claude-intake}" ;;
      create) : ;;
      *)      unanswered "label verb not modelled" ;;
    esac ;;
  issue)
    case "${2:-}" in
      list)    [ -f "$CASE/issues" ] && cat "$CASE/issues"; exit 0 ;;
      view)    case "$FLAT" in
                 *"--json title,labels "*) ;;
                 *) unanswered "issue view field set changed" ;;
               esac
               printf ',,\n'
               printf 'fixture issue %s\n' "${3:-0}"; exit 0 ;;
      comment) for A in "$@"; do LAST="$A"; done
               { printf '<<<comment on %s>>>\n' "${3:-0}"; printf '%s\n' "$LAST"; } \
                 >> "$CASE/comment-bodies.log"
               printf 'https://example.invalid/issues/%s#comment\n' "${3:-0}"; exit 0 ;;
      edit)    exit 0 ;;
      *)       unanswered "issue verb not modelled" ;;
    esac ;;
  api)
    P=""
    for A in "$@"; do
      case "$A" in */issues/*/timeline*|*/contents/*|*/branches*) P="$A" ;; esac
    done
    [ -n "$P" ] || unanswered "api path not modelled"
    case "$P" in
      */branches*)
        case "$FLAT" in *--paginate*) ;; *) unanswered "branch query is not paginated" ;; esac
        [ -f "$CASE/branches" ] && cat "$CASE/branches"
        exit 0 ;;
      */issues/*/timeline*)
        N="${P#*/issues/}"; N="${N%%/*}"
        [ -f "$CASE/timeline/$N" ] && cat "$CASE/timeline/$N"
        exit 0 ;;
      */contents/*)
        case "$FLAT" in
          *"Accept: application/vnd.github.raw"*) ;;
          *) unanswered "contents fetched without the raw Accept header" ;;
        esac
        REF="${P##*\?ref=}"
        KEY="$(printf '%s' "$REF" | tr '/' '_')"
        [ -f "$CASE/contents/$KEY" ] || { echo 'Not Found' >&2; exit 1; }
        cat "$CASE/contents/$KEY"
        exit 0 ;;
    esac ;;
  pr)
    case "${2:-}" in
      list)
        case "$FLAT" in
          *"--json number,headRefName "*) ;;
          *) unanswered "pr list field set changed" ;;
        esac
        [ -f "$CASE/proposals" ] && cat "$CASE/proposals"
        exit 0 ;;
      view)
        case "$FLAT" in
          *"--json state,headRefName,url,closingIssuesReferences,body "*) ;;
          *) unanswered "pr view field set changed" ;;
        esac
        F="$CASE/pr/${3:-}"
        [ -f "$F" ] || { echo 'no such PR' >&2; exit 1; }
        cat "$F"; exit 0 ;;
      create) printf 'https://example.invalid/pull/999\n'; exit 0 ;;
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
                printf 'git WORKTREE-REMOVED %s\n' "$WT" >> "$CASE/calls.log"
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

PLANS="$SANDBOX/plans"; sandboxed "$PLANS"; mkdir -p "$PLANS"
cat > "$PLANS/ordinary.md" <<'PLAN'
# Epic: a fixture epic

**Status:** planning
**Source:** GH #90
**Recommendation:** plan

## Work items

### 1. Do the thing
- **Branch:** `feat/the-thing`
- **Scope:** `src/thing.ts`
PLAN

# ------------------------------------------------------------------ helpers
mkcase() { # $1 = case name -> case dir on stdout
  D="$SANDBOX/$1"; sandboxed "$D"
  rm -rf "$D"
  mkdir -p "$D/repo/.git" "$D/worktrees" "$D/home" "$D/timeline" "$D/pr" \
           "$D/contents" "$D/promotions"
  : > "$D/calls.log"; : > "$D/comment-bodies.log"; : > "$D/proposals"
  printf '%s\n' "$D/repo" > "$D/repos"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$D/env"
  chmod 600 "$D/env"
  cp "$PLANS/ordinary.md" "$D/draft.md"
  printf '%s' "$D"
}

set_issues() { D="$1"; shift; sandboxed "$D"; : > "$D/issues"
  for I in "$@"; do printf '%s\n' "$I" >> "$D/issues"; done; }

SCRIPT_UNDER_TEST="$SCRIPT"
LIB_UNDER_TEST="$LIB"

run_intake() { # $1 = case dir, rest = extra args -> exit code on stdout
  D="$1"; shift; sandboxed "$D"
  INTAKE_GIT="$BIN/git" INTAKE_GH="$BIN/gh" INTAKE_CLAUDE="$BIN/claude" \
  INTAKE_SKILL_DIR="$SKILL" INTAKE_ENV_FILE="$D/env" \
  INTAKE_REPO_LIST="$D/repos" INTAKE_REPO_DIR="$D/repo" \
  INTAKE_LOG="$D/intake.log" INTAKE_LOCK="$D/.lock" \
  INTAKE_WORKTREE_ROOT="$D/worktrees" \
  INTAKE_AUTONOMY_LIB="$LIB_UNDER_TEST" \
  INTAKE_AUTONOMY_FILE="$D/autonomy" INTAKE_AUTONOMY_OVERRIDE="$D/AUTONOMY-OFF" \
  INTAKE_STOP_FILE="$D/STOP" INTAKE_PROMOTIONS_DIR="$D/promotions" \
  FIXTURE_CASE_DIR="$D" FIXTURE_SANDBOX="$SANDBOX" FIXTURE_REPO_SLUG="fixture/repo" \
  HOME="$D/home" \
    /bin/bash "$SCRIPT_UNDER_TEST" "$@" > "$D/stdout.log" 2> "$D/stderr.log"
  printf '%s' "$?"
}

# Run a snippet with the library sourced, in its own process, with every control
# file redirected into the case directory. stdin passes straight through so the
# denylist can be fed a real `git diff --name-only` stream.
libsh() { # $1 = case dir, $2 = repo path, $3 = repo slug, $4 = snippet
  D="$1"; sandboxed "$D"
  RP="$2" RS="$3" \
  INTAKE_AUTONOMY_FILE="$D/autonomy" \
  INTAKE_AUTONOMY_OVERRIDE="$D/AUTONOMY-OFF" \
  INTAKE_STOP_FILE="$D/STOP" \
  INTAKE_PROMOTIONS_DIR="$D/promotions" \
  AUTONOMY_LIB_UNDER_TEST="$LIB_UNDER_TEST" \
  HOME="$D/home" \
    /bin/bash -c "set -u; . \"\$AUTONOMY_LIB_UNDER_TEST\"; $4" 2>&1
}

# The full log with the timestamps removed, which is what "byte-identical" has
# to mean for a stream whose first field is the current second.
detimestamp() { sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| //'; }

# For the byte-identity proof, three things have to be normalised away because
# they are properties of the HARNESS and not of the code: the timestamp, the
# case directory (`K-before` vs `K-after` — the two runs cannot share one), and
# the sandbox path, whose mktemp name literally contains the string
# "autonomy-control-fixtures". Everything else is compared byte for byte.
normalise() { # $1 = case dir
  sed -E -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| //' \
         -e "s|$1|<CASE>|g" -e "s|$SANDBOX|<SANDBOX>|g"
}

# Every variable here is prefixed, because the suite's own case directories live
# in $D, $F and friends and an unprefixed assignment inside a helper silently
# retargets the case that called it. That is not hypothetical: it is what the
# first run of this file did, and every case in section F failed identically.
grant() { # $1 = case dir, $2 = slug, $3 = level, rest = key:value overrides
  GRANT_D="$1"; GRANT_SLUG="$2"; GRANT_LVL="$3"; shift 3; sandboxed "$GRANT_D"
  GRANT_F="$GRANT_D/promotions/$(printf '%s' "$GRANT_SLUG" | sed 's|/|__|g').$GRANT_LVL"
  {
    printf 'repo: %s\n' "$GRANT_SLUG"
    printf 'level: %s\n' "$GRANT_LVL"
    printf 'granted: 2026-08-21T10:00:00Z\n'
    printf 'granted-by: jonathanstevenson\n'
    printf 'cycles: 3\n'
    printf 'ledger: /fixture/ledger.jsonl\n'
    printf 'evidence: cycles 41,42,43 clean\n'
  } > "$GRANT_F"
  for GRANT_KV in "$@"; do
    GRANT_K="${GRANT_KV%%:*}"
    if [ "$GRANT_K" = DELETE ]; then
      sed -i.bak "/^${GRANT_KV#DELETE:}:/d" "$GRANT_F" && rm -f "$GRANT_F.bak"
    else
      sed -i.bak "s|^$GRANT_K:.*|$GRANT_KV|" "$GRANT_F" && rm -f "$GRANT_F.bak"
    fi
  done
  printf '%s' "$GRANT_F"
}

echo "sandbox: $SANDBOX"
echo "runner:  $SCRIPT"
echo "library: $LIB"
echo "bash:    $(/bin/bash --version | head -1)"
echo

# =========================================================================
echo "=== A. the config parses, and every value survives the round trip ======="
A="$(mkcase A)"
cat > "$A/autonomy" <<CFG
# a fixture config
[global]
budget.max-items      = 2
budget.max-wall-clock = 45m

[$A/repo]
level          = L2
require-labels = epic:planned, needs triage
forbid-labels  = do-not-automate
deny-paths     = alembic/*, api/config.py
max-files      = 40
max-diff-lines = 800

[other/repo]
level = L0
CFG
grant "$A" fixture/repo L2 >/dev/null
check "A: the file is accepted"             "yes" "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_load && printf yes || printf no')"
check "A: budget.max-items"                 "2"    "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_load; printf "%s" "$AUTONOMY_BUDGET_MAX_ITEMS"')"
check "A: budget.max-wall-clock -> seconds" "2700" "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_load; printf "%s" "$AUTONOMY_BUDGET_MAX_SECONDS"')"
check "A: the path section resolves the level" "L2" "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "A: require-labels round trip" "epic:planned, needs triage" \
      "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REQUIRE_LABELS"')"
check "A: forbid-labels round trip"  "do-not-automate" \
      "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_FORBID_LABELS"')"
check "A: deny-paths round trip"     "alembic/*, api/config.py" \
      "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_DENY_PATHS"')"
check "A: max-files round trip"      "40"  "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_MAX_FILES"')"
check "A: max-diff-lines round trip" "800" "$(libsh "$A" "$A/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_MAX_DIFF_LINES"')"
check "A: a SLUG section resolves too" "L0" \
      "$(libsh "$A" "$A/elsewhere" other/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "A: and says it was configured, not merely absent" "configured L0" \
      "$(libsh "$A" "$A/elsewhere" other/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')"
check "A: the library is safe to source under set -e" "L2" \
      "$(RPX="$A/repo" /bin/bash -c "set -eu; INTAKE_AUTONOMY_FILE='$A/autonomy' INTAKE_AUTONOMY_OVERRIDE='$A/AUTONOMY-OFF' INTAKE_STOP_FILE='$A/STOP' INTAKE_PROMOTIONS_DIR='$A/promotions'; export INTAKE_AUTONOMY_FILE INTAKE_AUTONOMY_OVERRIDE INTAKE_STOP_FILE INTAKE_PROMOTIONS_DIR; . '$LIB_UNDER_TEST'; autonomy_resolve '$A/repo' fixture/repo; printf '%s' \"\$AUTONOMY_LEVEL\"" 2>&1)"

echo
echo "=== B. malformed input is refused, and the message names the problem ===="
bad_case() { # $1 = name, $2 = config body -> case dir
  D="$(mkcase "B-$1")"; printf '%s\n' "$2" > "$D/autonomy"; printf '%s' "$D"
}
bad_check() { # $1 = label, $2 = case dir, $3 = phrase the error must contain
  BC_ERR="$(libsh "$2" "$2/repo" fixture/repo 'autonomy_load >/dev/null 2>&1; printf "%s" "$AUTONOMY_CONFIG_ERRORS"')"
  check "B: $1 — refused"        "no"  "$(libsh "$2" "$2/repo" fixture/repo 'autonomy_load >/dev/null 2>&1; printf "%s" "$AUTONOMY_CONFIG_OK"')"
  check "B: $1 — names it"       "yes" "$(contains "$BC_ERR" "$3")"
  check "B: $1 — resolves to L0" "L0"  "$(libsh "$2" "$2/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
}
D="$(bad_case level '[fix/repo]
level = L7
max-files = 1
max-diff-lines = 1')"
bad_check "an unknown level" "$D" "level must be one of L0 L1 L2 L3 L4, got 'L7'"
D="$(bad_case items '[global]
budget.max-items = zero')"
bad_check "a non-numeric item budget" "$D" "budget.max-items must be an integer >= 1, got 'zero'"
D="$(bad_case clock '[global]
budget.max-wall-clock = 45x')"
bad_check "a bad duration" "$D" "budget.max-wall-clock must be a positive duration"
D="$(bad_case orphan 'level = L2')"
bad_check "a key outside any section" "$D" "key outside any [section]"
D="$(bad_case unknown '[global]
budget.max-widgets = 3')"
bad_check "an unknown global key" "$D" "unknown key 'budget.max-widgets' in [global]"
D="$(bad_case misplaced1 '[global]
level = L2')"
bad_check "a per-repo key in [global]" "$D" "'level' is a per-repo key and does not belong in [global]"
D="$(bad_case misplaced2 '[fix/repo]
budget.max-items = 2')"
bad_check "a global key in a repo section" "$D" "'budget.max-items' is a global key and does not belong in"
D="$(bad_case dupsec '[fix/repo]
level = L0

[fix/repo]
level = L0')"
bad_check "a duplicate section" "$D" "duplicate section [fix/repo]"
D="$(bad_case dupkey '[fix/repo]
level = L0
level = L0')"
bad_check "a duplicate key" "$D" "duplicate key 'level' in [fix/repo]"
D="$(bad_case notarepo '[justaword]
level = L0')"
bad_check "a section that is neither a path nor a slug" "$D" "is neither a path (starts with / or ~) nor an owner/name slug"
D="$(bad_case toodeep '[a/b/c]
level = L0')"
bad_check "a section with too many slashes" "$D" "is neither a path (starts with / or ~) nor an owner/name slug"
D="$(bad_case emptyval '[fix/repo]
level =')"
bad_check "an empty value" "$D" "'level' has an empty value"
D="$(bad_case garbage '[fix/repo]
this is not a config line')"
bad_check "a line that is not a key = value" "$D" "not a comment, a [section] header, or a key = value line"
D="$(bad_case nofiles '[fix/repo]
level = L2
max-diff-lines = 800')"
bad_check "a level above L0 with no max-files" "$D" "level L2 requires max-files to be declared"
D="$(bad_case nolines '[fix/repo]
level = L2
max-files = 40')"
bad_check "a level above L0 with no max-diff-lines" "$D" "level L2 requires max-diff-lines to be declared"
D="$(bad_case badglob '[fix/repo]
level = L0
deny-paths = src/(a|b)')"
bad_check "a deny-paths pattern that is not a glob" "$D" "contains a character that is not allowed in a glob"

echo
echo "=== C. an unconfigured repo: L0, and NOTHING to say about it ============"
C="$(mkcase C)"
check "C: no config file at all -> L0" "L0" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "C: and the reason is 'unconfigured'" "unconfigured" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')"
check "C: and AUTONOMY_LOG is EMPTY — the whole inertness claim" "" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LOG"')"
printf '[other/repo]\nlevel = L0\n' > "$C/autonomy"
check "C: a config that does not mention this repo is still silent" "" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LOG"')"
printf '[%s]\n' "$C/repo" > "$C/autonomy"
check "C: a section declared with NO keys is still a section" "configured L0" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')"

echo
echo "=== D. the global override pins ANY configured level to L0 =============="
DD="$(mkcase D)"
cat > "$DD/autonomy" <<CFG
[$DD/repo]
level = L2
max-files = 40
max-diff-lines = 800
CFG
grant "$DD" fixture/repo L2 >/dev/null
check "D: without the override, the record grants L2" "L2" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
touch "$DD/AUTONOMY-OFF"
check "D: with it present, L0" "L0" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "D: it beats a VALID promotion record, which is the point" "yes" \
      "$(contains "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "global override present at")"
check "D: and the log says drafting continues" "yes" \
      "$(contains "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LOG"')" "unattended drafting continues")"
check "D: presence is the whole signal — an EMPTY file still pins" "L0" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "D: the override is NOT the stop file" "no" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'if autonomy_stop_requested; then printf yes; else printf no; fi')"
rm "$DD/AUTONOMY-OFF"
touch "$DD/STOP"
check "D: and the stop file is NOT the override" "L2" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
rm "$DD/STOP"

echo
echo "=== E. a level above the ceiling is refused, never clamped =============="
for LV in L3 L4; do
  E="$(mkcase "E-$LV")"
  cat > "$E/autonomy" <<CFG
[$E/repo]
level = $LV
max-files = 40
max-diff-lines = 800
CFG
  grant "$E" fixture/repo "$LV" >/dev/null
  check "E: $LV resolves to L0 even WITH a promotion record" "L0" \
        "$(libsh "$E" "$E/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
  check "E: $LV names the ceiling in the refusal" "yes" \
        "$(contains "$(libsh "$E" "$E/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "this build implements no rung above L2")"
done

echo
echo "=== F. the promotion record: every refusal names what is missing ======="
newF() { # $1 = name -> case dir with an L2 config
  D="$(mkcase "F-$1")"
  cat > "$D/autonomy" <<CFG
[$D/repo]
level = L2
max-files = 40
max-diff-lines = 800
CFG
  printf '%s' "$D"
}
F="$(newF absent)"
check "F: no record at all -> L0" "L0" \
      "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "F: and it names the path it looked for" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "promotions/fixture__repo.L2")"
F="$(newF valid)"; grant "$F" fixture/repo L2 >/dev/null
check "F: a complete record grants the level" "L2" \
      "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "F: the filename is owner__name.LEVEL, so ls reads as a sentence" "yes" \
      "$(yesno test -f "$F/promotions/fixture__repo.L2")"
for FIELD in repo level granted granted-by cycles ledger evidence; do
  F="$(newF "miss-$FIELD")"; grant "$F" fixture/repo L2 "DELETE:$FIELD" >/dev/null
  check "F: a record missing '$FIELD' is refused, naming it" "yes" \
        "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "missing required field(s): $FIELD")"
done
F="$(newF wrongrepo)"; grant "$F" fixture/repo L2 "repo: someone/else" >/dev/null
check "F: a record for another repo is refused, naming both" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "names repo 'someone/else', not 'fixture/repo'")"
F="$(newF wronglevel)"; grant "$F" fixture/repo L2 "level: L1" >/dev/null
check "F: a record granting a different level is refused" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "grants 'L1', not 'L2'")"
F="$(newF badtime)"; grant "$F" fixture/repo L2 "granted: last tuesday" >/dev/null
check "F: a record without an ISO-8601 UTC timestamp is refused" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "not an ISO-8601 UTC timestamp")"
for WHO in unattended-intake claude claude-code automation runner intake; do
  F="$(newF "self-$WHO")"; grant "$F" fixture/repo L2 "granted-by: $WHO" >/dev/null
  check "F: a record granted-by '$WHO' is refused — it is a human act" "yes" \
        "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "which names the automation")"
done
F="$(newF zerocycles)"; grant "$F" fixture/repo L2 "cycles: 0" >/dev/null
check "F: a record attesting zero cycles is refused" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "attests 0 clean cycle(s); L2 requires 1")"
F="$(newF nan)"; grant "$F" fixture/repo L2 "cycles: lots" >/dev/null
check "F: a non-numeric cycle count is refused" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "not a non-negative integer")"
F="$(newF raisebar)"
cat > "$F/autonomy" <<CFG
[global]
promotion.min-cycles.L2 = 5
[$F/repo]
level = L2
max-files = 40
max-diff-lines = 800
CFG
grant "$F" fixture/repo L2 >/dev/null
check "F: the bar is configurable UPWARD — 3 cycles against a bar of 5" "yes" \
      "$(contains "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_REASON"')" "attests 3 clean cycle(s); L2 requires 5")"
check "F: and 5 satisfies it" "L2" \
      "$(grant "$F" fixture/repo L2 "cycles: 5" >/dev/null; libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"

echo
echo "=== G. the denylist, checked against a REAL diff and nothing else ======="
G="$(mkcase G)"
cat > "$G/autonomy" <<CFG
[$G/repo]
level = L2
deny-paths = alembic/*, api/config.py
max-files = 40
max-diff-lines = 800
CFG
grant "$G" fixture/repo L2 >/dev/null
deny() { printf '%s\n' "$@" | libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; autonomy_deny_diff_paths'; }
denyrc() { printf '%s\n' "$@" | libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_deny_diff_paths >/dev/null; then printf clean; else printf refused; fi'; }
check "G: a clean diff is clean"      "clean"   "$(denyrc src/app.ts docs/readme.md)"
check "G: and prints nothing"         ""        "$(deny src/app.ts docs/readme.md)"
check "G: a workflow file is refused" "refused" "$(denyrc .github/workflows/ci.yml)"
check "G: and the PATH is named, with the pattern that caught it" \
      ".github/workflows/ci.yml	.github/*" "$(deny .github/workflows/ci.yml)"
check "G: install.sh"            "install.sh	install.sh"                     "$(deny install.sh)"
check "G: a nested installer"    "tools/install.sh	*/install.sh"             "$(deny tools/install.sh)"
check "G: the control-plane hooks themselves" \
      "Skills/x/assets/claude-config/hooks/cancel-gate.sh	*/claude-config/hooks/*" \
      "$(deny Skills/x/assets/claude-config/hooks/cancel-gate.sh)"
check "G: the unattended runner itself" \
      "Skills/x/assets/claude-config/bin/unattended-intake.sh	*/claude-config/bin/*" \
      "$(deny Skills/x/assets/claude-config/bin/unattended-intake.sh)"
check "G: installed hook wiring"  ".claude/settings.json	.claude/settings.json" "$(deny .claude/settings.json)"
check "G: a launchd job"          "com.x.job.plist	*.plist"                    "$(deny com.x.job.plist)"
check "G: credential material"    "web/.env	*/.env"                           "$(deny web/.env)"
check "G: a private key"          "certs/server.pem	*.pem"                    "$(deny certs/server.pem)"
check "G: a secrets directory"    "infra/secrets/prod.yaml	*/secrets/*"       "$(deny infra/secrets/prod.yaml)"
check "G: registry credentials"   ".npmrc	.npmrc"                             "$(deny .npmrc)"
check "G: the repo's OWN declared addition" "api/config.py	api/config.py"     "$(deny api/config.py)"
check "G: a declared glob"        "alembic/versions/0001_x.py	alembic/*"      "$(deny alembic/versions/0001_x.py)"
check "G: every denied path is reported, not just the first" \
      "api/config.py	api/config.py
.github/workflows/ci.yml	.github/*" "$(deny api/config.py src/ok.ts .github/workflows/ci.yml)"
check "G: the FLOOR applies with NO config at all" "refused" \
      "$(printf '%s\n' .github/workflows/ci.yml | libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_deny_diff_paths >/dev/null; then printf clean; else printf refused; fi')"
check "G: there is NO config key that shrinks the floor" "0" \
      "$(grep -cE '^(allow-paths|deny-paths-only|no-floor|floor)[[:space:]]*=' "$LIB" | tr -d ' ')"
check "G: the floor is defined exactly once" "1" \
      "$(grep -c "^AUTONOMY_DENY_FLOOR='" "$LIB" | tr -d ' ')"
check "G: it takes its input from stdin and NOWHERE else — a path argument is ignored" "" \
      "$(libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; autonomy_deny_diff_paths /fixture/plan.md < /dev/null')"
check "G: blank lines in the diff stream are skipped, not matched" "clean" \
      "$(printf 'src/a.ts\n\n\nsrc/b.ts\n' | libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_deny_diff_paths >/dev/null; then printf clean; else printf refused; fi')"

echo
echo "=== H. the size ceiling, read off a real --numstat ======================"
NUMSTAT='12	4	src/a.ts
3	0	src/b.ts
-	-	assets/logo.png'
check "H: --numstat -> files and lines, with binary counted as a file only" "3 19" \
      "$(printf '%s\n' "$NUMSTAT" | libsh "$G" "$G/repo" fixture/repo 'autonomy_diff_size')"
check "H: under both ceilings is admitted" "ok" \
      "$(libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_check_size 3 19; then printf ok; else printf "$AUTONOMY_REFUSAL"; fi')"
check "H: exactly at the ceilings is admitted" "ok" \
      "$(libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_check_size 40 800; then printf ok; else printf "$AUTONOMY_REFUSAL"; fi')"
check "H: one file over is refused, naming the ceiling" "diff touches 41 files; the ceiling is 40" \
      "$(libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; autonomy_check_size 41 10; printf "%s" "$AUTONOMY_REFUSAL"')"
check "H: one line over is refused, naming the ceiling" "diff changes 801 lines; the ceiling is 800" \
      "$(libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; autonomy_check_size 1 801; printf "%s" "$AUTONOMY_REFUSAL"')"

echo
echo "=== I. required and forbidden labels ==================================="
I="$(mkcase I)"
cat > "$I/autonomy" <<CFG
[$I/repo]
level = L2
require-labels = epic:planned, needs triage
forbid-labels  = do-not-automate
max-files = 40
max-diff-lines = 800
CFG
grant "$I" fixture/repo L2 >/dev/null
adm() { libsh "$I" "$I/repo" fixture/repo "autonomy_resolve \"\$RP\" \"\$RS\"; if autonomy_admit_labels '$1'; then printf admitted; else printf \"\$AUTONOMY_REFUSAL\"; fi"; }
check "I: both required labels present" "admitted"                            "$(adm ',epic:planned,needs triage,bug,')"
check "I: one missing"                  "required label 'needs triage' is absent" "$(adm ',epic:planned,')"
check "I: a forbidden label present"    "forbidden label 'do-not-automate' is present" \
      "$(adm ',epic:planned,needs triage,do-not-automate,')"
check "I: a label with a SPACE is one label, not two" "admitted"              "$(adm ',needs triage,epic:planned,')"
check "I: the fence stops a prefix match — epic:planned-later is not epic:planned" \
      "required label 'epic:planned' is absent" "$(adm ',epic:planned-later,needs triage,')"
check "I: an unfenced list is fenced for you" "admitted"                      "$(adm 'epic:planned,needs triage')"
check "I: no policy means nothing is required" "admitted" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_admit_labels ",,"; then printf admitted; else printf "$AUTONOMY_REFUSAL"; fi')"

echo
echo "=== J. the per-cycle budget ============================================"
check "J: default max-items is 1 — 'one item at a time' is an invariant" "1" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; printf "%s" "$AUTONOMY_BUDGET_MAX_ITEMS"')"
check "J: default max-wall-clock is 3600s" "3600" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; printf "%s" "$AUTONOMY_BUDGET_MAX_SECONDS"')"
check "J: the first item is allowed" "yes" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; if autonomy_budget_allows_item 0; then printf yes; else printf no; fi')"
check "J: the second is not, and it says why" "per-cycle item budget reached (1)" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; autonomy_budget_allows_item 1; printf "%s" "$AUTONOMY_REFUSAL"')"
check "J: wall-clock inside the budget" "yes" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; if autonomy_budget_allows_time 3599; then printf yes; else printf no; fi')"
check "J: wall-clock at the budget stops NEW work" "per-cycle wall-clock budget reached (3600s)" \
      "$(libsh "$C" "$C/repo" fixture/repo 'autonomy_load; autonomy_budget_allows_time 3600; printf "%s" "$AUTONOMY_REFUSAL"')"
for D_IN in 90:90 90s:90 45m:2700 2h:7200; do
  check "J: duration ${D_IN%%:*} -> ${D_IN##*:}s" "${D_IN##*:}" \
        "$(libsh "$C" "$C/repo" fixture/repo "autonomy_parse_duration '${D_IN%%:*}'")"
done
for BADD in 0 -5 45x '' 1.5; do
  check "J: duration '$BADD' is refused" "refused" \
        "$(libsh "$C" "$C/repo" fixture/repo "if autonomy_parse_duration '$BADD' >/dev/null; then printf ok; else printf refused; fi")"
done

echo
echo "=== K. THE INERTNESS PROOF: identical to the pre-item-1 runner =========="
# Reconstruct the runner as it stood before this item by deleting exactly the
# lines the item added. Brittle ON PURPOSE: if the blocks move, the line count
# stops matching and this stops rather than proving nothing.
PRE="$SANDBOX/unattended-intake.pre-item-1.sh"; sandboxed "$PRE"
line_of() { grep -nF -m1 -- "$2" "$1" | cut -d: -f1; }
S1="$(line_of "$SCRIPT" '# ------------------------------------------- the cycle stop file (epic 11 item 1)')"
E1="$(line_of "$SCRIPT" '# --------------------------------------------------------------- preflight')"
S2="$(line_of "$SCRIPT" '# The autonomy config is validated ONCE per run, not once per repo, and it is')"
E2="$(grep -n '^FAILED=0$' "$SCRIPT" | head -1 | cut -d: -f1)"
S3="$(line_of "$SCRIPT" '  # The repo'"'"'s autonomy level: RESOLVED AND LOGGED, NEVER ACTED ON. Nothing')"
E3="$(line_of "$SCRIPT" '  # Repos disagree on the case of the epics directory')"
for V in "$S1" "$E1" "$S2" "$E2" "$S3" "$E3"; do
  case "$V" in ''|*[!0-9]*)
    echo "ERROR: an anchor for the pre-item-1 reconstruction did not match." >&2
    echo "       The item-1 blocks moved, so case K would prove nothing. Fix the anchors." >&2
    exit 1 ;;
  esac
done
sed -e "${S3},$((E3 - 1))d" -e "${S2},$((E2 - 1))d" -e "${S1},$((E1 - 1))d" "$SCRIPT" > "$PRE"
chmod +x "$PRE"
REMOVED=$(( $(wc -l < "$SCRIPT") - $(wc -l < "$PRE") ))
check "K: the reconstruction removes exactly the item's 83 added lines" "83" "$REMOVED"
if [ "$REMOVED" -ne 83 ]; then
  echo "ERROR: the pre-item-1 reconstruction is $REMOVED lines, not 83. Either the" >&2
  echo "       item grew or the anchors rotted; either way case K is not a proof." >&2
  exit 1
fi
cmp -s "$SCRIPT" "$PRE" && { echo "ERROR: the reconstruction is identical to the script" >&2; exit 1; }
/bin/bash -n "$PRE" || { echo "ERROR: the pre-item-1 reconstruction does not parse" >&2; exit 1; }
check "K: and it carries no trace of the control surface"   "0" \
      "$(grep -c 'AUTONOMY' "$PRE" | tr -d ' ')"
check "K: while the shipped runner does"                    "yes" \
      "$(yesno grep -q 'AUTONOMY_LIB' "$SCRIPT")"

KA="$(mkcase K-after)";  set_issues "$KA" 90
KB="$(mkcase K-before)"; set_issues "$KB" 90
RC_A="$(run_intake "$KA")"
SCRIPT_UNDER_TEST="$PRE"
RC_B="$(run_intake "$KB")"
SCRIPT_UNDER_TEST="$SCRIPT"
check "K: both runs succeeded"                       "0|0"  "$RC_A|$RC_B"
check "K: an unconfigured run opens its PR, as today" "yes" "$(yesno grep -q 'gh pr create' "$KA/calls.log")"
check "K: the gh/git/claude call stream is BYTE-IDENTICAL" \
      "$(normalise "$KB" < "$KB/calls.log" | cksum)" "$(normalise "$KA" < "$KA/calls.log" | cksum)"
check "K: the log is BYTE-IDENTICAL" \
      "$(normalise "$KB" < "$KB/intake.log" | cksum)" "$(normalise "$KA" < "$KA/intake.log" | cksum)"
check "K: stdout is BYTE-IDENTICAL" \
      "$(normalise "$KB" < "$KB/stdout.log" | cksum)" "$(normalise "$KA" < "$KA/stdout.log" | cksum)"
check "K: stderr is identical (both empty)" \
      "$(cksum < "$KB/stderr.log")" "$(cksum < "$KA/stderr.log")"
check "K: the issue comments a human receives are identical" \
      "$(normalise "$KB" < "$KB/comment-bodies.log" | cksum)" \
      "$(normalise "$KA" < "$KA/comment-bodies.log" | cksum)"
check "K: the drafted plan is identical" \
      "$(cksum < "$KB/removed-worktree/docs/epics/proposed-90-fixture-issue-90/plan.md" 2>/dev/null)" \
      "$(cksum < "$KA/removed-worktree/docs/epics/proposed-90-fixture-issue-90/plan.md" 2>/dev/null)"
check "K: and not one extra line was logged" "0" \
      "$(( $(wc -l < "$KA/intake.log") - $(wc -l < "$KB/intake.log") ))"
check "K: the word 'autonomy' never appears in an unconfigured run's log" "0" \
      "$(normalise "$KA" < "$KA/intake.log" | grep -ci autonomy | tr -d ' ')"

echo
echo "=== L. the cycle stop file stops a cycle, loudly ========================"
L="$(mkcase L)"; set_issues "$L" 90
touch "$L/STOP"
RC="$(run_intake "$L")"
check "L: exit 0 — a stop is an order obeyed, not a failure" "0" "$RC"
check "L: it names the file"                        "yes" "$(yesno grep -q "STOP: cycle stop file present at $L/STOP" "$L/intake.log")"
check "L: it says how to undo it"                   "yes" "$(yesno grep -q "rm '$L/STOP'" "$L/intake.log")"
check "L: it says drafting stopped too, not just dispatch" "yes" \
      "$(yesno grep -q 'not even L0 drafting' "$L/intake.log")"
check "L: NO GitHub call was made at all"           "0"   "$(grep -c '^gh ' "$L/calls.log" | tr -d ' ')"
check "L: no PR was created"                        "no"  "$(yesno grep -q 'gh pr create' "$L/calls.log")"
check "L: no lock was taken"                        "no"  "$(yesno test -d "$L/.lock")"
check "L: no worktree was created"                  "no"  "$(yesno test -n "$(ls -A "$L/worktrees" 2>/dev/null)")"
check "L: no drafter was invoked"                   "no"  "$(yesno grep -q '^claude ' "$L/calls.log")"
# It works when the machine does not: no credential file, and it still stops.
LC="$(mkcase L-nocred)"; set_issues "$LC" 90; touch "$LC/STOP"; rm -f "$LC/env"
RC="$(run_intake "$LC")"
check "L: it stops even with the credential file GONE" "0" "$RC"
check "L: and it is the stop that spoke, not the credential check" "yes" \
      "$(yesno grep -q 'cycle stop file present' "$LC/stdout.log")"
LD="$(mkcase L-dry)"; set_issues "$LD" 90; touch "$LD/STOP"
RC="$(run_intake "$LD" --dry-run)"
check "L: --dry-run honours it too"        "0"   "$RC"
check "L: and reports it rather than pretending it would run" "yes" \
      "$(yesno grep -q 'cycle stop file present' "$LD/stdout.log")"
# THE DISCRIMINATING CONTROL: without the file, the same case runs to a PR.
LE="$(mkcase L-nostop)"; set_issues "$LE" 90
RC="$(run_intake "$LE")"
check "L: without the file the SAME case runs to a PR" "yes" "$(yesno grep -q 'gh pr create' "$LE/calls.log")"
check "L: so the stop is what stopped it"              "0"   "$RC"
# ...and against the pre-item-1 runner the stop file does NOTHING.
LF="$(mkcase L-pre)"; set_issues "$LF" 90; touch "$LF/STOP"
SCRIPT_UNDER_TEST="$PRE"
RC="$(run_intake "$LF")"
SCRIPT_UNDER_TEST="$SCRIPT"
check "L: NEGATIVE CONTROL — the pre-item-1 runner ignores the stop file" "yes" \
      "$(yesno grep -q 'gh pr create' "$LF/calls.log")"
check "L: which is why the passing case above is a proof and not a tautology" "no" \
      "$(yesno grep -q 'cycle stop file present' "$LF/stdout.log")"

echo
echo "=== M. the override stops DISPATCH and leaves DRAFTING running =========="
M="$(mkcase M)"; set_issues "$M" 90
cat > "$M/autonomy" <<CFG
[$M/repo]
level = L2
max-files = 40
max-diff-lines = 800
CFG
grant "$M" fixture/repo L2 >/dev/null
touch "$M/AUTONOMY-OFF"
RC="$(run_intake "$M")"
check "M: the cycle still runs"                 "0"   "$RC"
check "M: and still drafts a proposal PR"       "yes" "$(yesno grep -q 'gh pr create' "$M/calls.log")"
check "M: the run announces the override once"  "1" \
      "$(grep -c 'autonomy: global override present at' "$M/intake.log" | tr -d ' ')"
check "M: and the repo line says it is pinned to L0" "yes" \
      "$(yesno grep -q "autonomy: fixture/repo pinned to L0" "$M/intake.log")"
check "M: and that drafting continues"          "yes" \
      "$(yesno grep -q 'unattended drafting continues' "$M/intake.log")"
rm "$M/AUTONOMY-OFF"
M2="$(mkcase M2)"; set_issues "$M2" 90
cp "$M/autonomy" "$M2/autonomy"
sed -i.bak "s|$M/repo|$M2/repo|" "$M2/autonomy" && rm -f "$M2/autonomy.bak"
grant "$M2" fixture/repo L2 >/dev/null
RC="$(run_intake "$M2")"
check "M2: without the override the repo logs its resolved level" "yes" \
      "$(yesno grep -q 'autonomy: fixture/repo resolves to L2' "$M2/intake.log")"
check "M2: and says out loud that nothing acts on it"             "yes" \
      "$(yesno grep -q 'NOTHING ACTS ON THIS — AUTONOMY_ENFORCED=no' "$M2/intake.log")"
check "M2: and the cycle behaves exactly as at L0 — it still drafts and stops" "yes" \
      "$(yesno grep -q 'gh pr create' "$M2/calls.log")"

echo
echo "=== N. a malformed config is loud, refuses everything, drafts anyway ===="
N="$(mkcase N)"; set_issues "$N" 90
printf '[global]\nbudget.max-items = zero\n' > "$N/autonomy"
RC="$(run_intake "$N")"
check "N: the cycle still completes"      "0"   "$RC"
check "N: the refusal is in the log"      "yes" "$(yesno grep -q 'autonomy config REFUSED' "$N/intake.log")"
check "N: naming the offending value"     "yes" "$(yesno grep -q "budget.max-items must be an integer >= 1, got 'zero'" "$N/intake.log")"
check "N: and saying what it costs"       "yes" "$(yesno grep -q 'every repo resolves L0 until' "$N/intake.log")"
check "N: L0 drafting is untouched"       "yes" "$(yesno grep -q 'gh pr create' "$N/calls.log")"

echo
echo "=== O. the switchboard is wired to nothing =============================="
check "O: the library declares itself inert"     "AUTONOMY_ENFORCED=no" \
      "$(grep -m1 '^AUTONOMY_ENFORCED=' "$LIB")"
# Comments are stripped first. The runner's comments SAY that nothing reads the
# level, and an assertion that counts its own documentation is an assertion that
# passes when the documentation is a lie.
code_only() { grep -v '^[[:space:]]*#' "$1"; }
check "O: the runner never reads the resolved LEVEL to decide anything" "0" \
      "$(code_only "$SCRIPT" | grep -c 'AUTONOMY_LEVEL' | tr -d ' ')"
check "O: nor the policy"                        "0" \
      "$(code_only "$SCRIPT" | grep -cE 'AUTONOMY_(DENY_PATHS|MAX_FILES|MAX_DIFF_LINES|REQUIRE_LABELS|FORBID_LABELS|BUDGET_)' | tr -d ' ')"
check "O: nor calls a single policy function"    "0" \
      "$(code_only "$SCRIPT" | grep -cE 'autonomy_(admit_labels|deny_diff_paths|check_size|diff_size|budget_allows|promotion_check)' | tr -d ' ')"
check "O: the only library calls it makes are load, resolve and override_active" "3" \
      "$(code_only "$SCRIPT" | grep -oE 'autonomy_[a-z_]+' | sort -u | grep -c .)"
check "O: the library NEVER writes a file"       "0" \
      "$(grep -cE '(^|[^0-9<>])>>?[[:space:]]*"?\$' "$LIB" | tr -d ' ')"
check "O: the library never mkdir/touch/rm/mv"   "0" \
      "$(grep -cE '(^|[[:space:]])(mkdir|touch|rm|mv|cp|tee)[[:space:]]' "$LIB" | tr -d ' ')"
check "O: the library never runs git or gh to change anything" "0" \
      "$(grep -cE '(^|[[:space:]])(git|gh)[[:space:]]+(commit|push|merge|edit|create|delete)' "$LIB" | tr -d ' ')"
check "O: nothing ever writes the promotions directory" "0" \
      "$(grep -cE '>[[:space:]]*"?\$(AUTONOMY_PROMOTIONS_DIR|\{AUTONOMY_PROMOTIONS_DIR)' "$LIB" "$SCRIPT" | grep -v ':0$' | wc -l | tr -d ' ')"
check "O: no eval anywhere — config never becomes code" "0" \
      "$(code_only "$LIB" | grep -cE '(^|[[:space:]])eval[[:space:]]' | tr -d ' ')"
check "O: the runner still never merges a PR"    "0" "$(grep -c 'pr merge' "$SCRIPT" | tr -d ' ')"
check "O: still never closes an issue"           "0" "$(grep -c 'issue close' "$SCRIPT" | tr -d ' ')"
check "O: still never edits a PR"                "0" "$(grep -c 'pr edit' "$SCRIPT" | tr -d ' ')"
check "O: still never dispatches an executor"    "0" "$(grep -c 'work-item-executor' "$SCRIPT" | tr -d ' ')"
check "O: this item adds no new gh query"        "yes" \
      "$(yesno test "$(grep -c '"\$GH_BIN"' "$SCRIPT")" -eq "$(grep -c '"\$GH_BIN"' "$PRE")")"
# Control flow: the stop check comes before EVERYTHING that could fail first.
LN_STOP="$(grep -n 'STOP: cycle stop file present' "$SCRIPT" | head -1 | cut -d: -f1)"
LN_BINS="$(grep -n '^for B in "\$GIT_BIN"' "$SCRIPT" | head -1 | cut -d: -f1)"
LN_CRED="$(grep -n '^\[ -f "\$ENV_FILE" \]' "$SCRIPT" | head -1 | cut -d: -f1)"
LN_LOCK="$(grep -n 'mkdir "\$LOCK_DIR"' "$SCRIPT" | head -1 | cut -d: -f1)"
LN_SRC="$(grep -n 'if . "\$AUTONOMY_LIB"' "$SCRIPT" | head -1 | cut -d: -f1)"
check "O: the stop check precedes the binary preflight"  "yes" "$(yesno test "$LN_STOP" -lt "$LN_BINS")"
check "O: precedes the credential read"                  "yes" "$(yesno test "$LN_STOP" -lt "$LN_CRED")"
check "O: precedes the lock"                             "yes" "$(yesno test "$LN_STOP" -lt "$LN_LOCK")"
check "O: and precedes even sourcing the library"        "yes" "$(yesno test "$LN_STOP" -lt "$LN_SRC")"
check "O: the stop path default is stated once in the runner"  "1" \
      "$(grep -c '\$HOME/.config/claude-intake/STOP' "$SCRIPT" | tr -d ' ')"
check "O: and once in the library, identically"                "1" \
      "$(grep -c '\$HOME/.config/claude-intake/STOP' "$LIB" | tr -d ' ')"
check "O: sourcing the library can never kill the run" "yes" \
      "$(yesno grep -q 'if . "\$AUTONOMY_LIB" 2>/dev/null; then AUTONOMY_AVAILABLE=yes; fi' "$SCRIPT")"
BROKEN="$SANDBOX/broken-autonomy.sh"; sandboxed "$BROKEN"; printf 'oops() {\n' > "$BROKEN"
OB="$(mkcase O-broken)"; set_issues "$OB" 90
LIB_UNDER_TEST="$BROKEN"; RC="$(run_intake "$OB")"; LIB_UNDER_TEST="$LIB"
check "O: proven — a library that does not parse leaves the cycle intact" "0" "$RC"
check "O: and it still drafts its PR"                                     "yes" \
      "$(yesno grep -q 'gh pr create' "$OB/calls.log")"
OM="$(mkcase O-missing)"; set_issues "$OM" 90
LIB_UNDER_TEST="$SANDBOX/does-not-exist.sh"; RC="$(run_intake "$OM")"; LIB_UNDER_TEST="$LIB"
check "O: and a MISSING library is today's behaviour exactly" \
      "$(normalise "$KB" < "$KB/intake.log" | cksum)" "$(normalise "$OM" < "$OM/intake.log" | cksum)"

echo
echo "=== P. the read-only CLI ================================================"
P="$(mkcase P)"
cp "$A/autonomy" "$P/autonomy"
sed -i.bak "s|$A/repo|$P/repo|" "$P/autonomy" && rm -f "$P/autonomy.bak"
grant "$P" fixture/repo L2 >/dev/null
cli() { INTAKE_AUTONOMY_FILE="$P/autonomy" INTAKE_AUTONOMY_OVERRIDE="$P/AUTONOMY-OFF" \
        INTAKE_STOP_FILE="$P/STOP" INTAKE_PROMOTIONS_DIR="$P/promotions" HOME="$P/home" \
        /bin/bash "$LIB_UNDER_TEST" "$@" 2>&1; }
BEFORE="$(find "$P" -type f | sort | xargs cksum 2>/dev/null | cksum)"
OUT="$(cli --check --repo "$P/repo" --slug fixture/repo)"
check "P: --check reports the ceiling and that nothing acts" "yes" "$(contains "$OUT" "ceiling         L2     enforced=no")"
check "P: reports the resolved level"                        "yes" "$(contains "$OUT" "level         L2")"
check "P: reports the budget"                                "yes" "$(contains "$OUT" "max-items=2 max-wall-clock=2700s")"
check "P: names the config file even when it is absent"      "yes" \
      "$(contains "$(INTAKE_AUTONOMY_FILE="$P/none" INTAKE_AUTONOMY_OVERRIDE="$P/AUTONOMY-OFF" INTAKE_STOP_FILE="$P/STOP" INTAKE_PROMOTIONS_DIR="$P/promotions" HOME="$P/home" /bin/bash "$LIB_UNDER_TEST" --check)" "absent — every repo is L0 and today is unchanged")"
check "P: says so when the stop file is present" "yes" \
      "$(touch "$P/STOP"; contains "$(cli --check)" "PRESENT — no cycle will start")"
check "P: and when the override is present"      "yes" \
      "$(rm -f "$P/STOP"; touch "$P/AUTONOMY-OFF"; contains "$(cli --check)" "PRESENT — every repo pinned to L0, drafting continues")"
rm -f "$P/AUTONOMY-OFF"
check "P: it mutated nothing" "$BEFORE" "$(find "$P" -type f | sort | xargs cksum 2>/dev/null | cksum)"
printf '%s\n' "$P/repo|main" > "$P/repos"
check "P: --repos reads the runner's own list format" "yes" \
      "$(contains "$(cli --check --repos "$P/repos")" "path          $P/repo")"
printf '%s\n' "$P/we|ird|main" > "$P/repos"
check "P: and splits on the LAST pipe, exactly as the runner does" "yes" \
      "$(contains "$(cli --check --repos "$P/repos")" "path          $P/we|ird")"
check "P: --deny-paths refuses from stdin and names the pattern" \
      ".github/x.yml	.github/*" \
      "$(printf '.github/x.yml\n' | cli --deny-paths --repo "$P/repo" --slug fixture/repo | grep '\.github')"

echo
echo "=== Q1. MUTANT: shrink the denylist floor =============================="
MQ1="$SANDBOX/autonomy.no-floor.sh"; sandboxed "$MQ1"
awk "/^AUTONOMY_DENY_FLOOR='/{print \"AUTONOMY_DENY_FLOOR='nothing-matches-this'\"; skip=1; next}
     skip==1 && /^\.netrc\|host credentials'\$/{skip=0; next}
     skip==1{next}
     {print}" "$LIB" > "$MQ1"
cmp -s "$LIB" "$MQ1" && { echo "ERROR: the no-floor mutant is identical — the floor moved" >&2; exit 1; }
/bin/bash -n "$MQ1" || { echo "ERROR: mutant Q1 does not parse" >&2; exit 1; }
LIB_UNDER_TEST="$MQ1"
check "Q1: with the floor gone a workflow file stops being refused" "clean" \
      "$(printf '.github/workflows/ci.yml\n' | libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_deny_diff_paths >/dev/null; then printf clean; else printf refused; fi')"
check "Q1: and it is not just broken — the repo's OWN pattern still bites" "refused" \
      "$(printf 'api/config.py\n' | libsh "$G" "$G/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; if autonomy_deny_diff_paths >/dev/null; then printf clean; else printf refused; fi')"
LIB_UNDER_TEST="$LIB"

echo
echo "=== Q2. MUTANT: make the global override advisory ======================"
MQ2="$SANDBOX/autonomy.advisory-override.sh"; sandboxed "$MQ2"
awk '/^  if autonomy_override_active; then$/{skip=1}
     skip==1 && /^    return 0$/{skip=2; next}
     skip==2 && /^  fi$/{skip=0; next}
     skip>=1{next}
     {print}' "$LIB" > "$MQ2"
cmp -s "$LIB" "$MQ2" && { echo "ERROR: the advisory-override mutant is identical" >&2; exit 1; }
/bin/bash -n "$MQ2" || { echo "ERROR: mutant Q2 does not parse" >&2; exit 1; }
LIB_UNDER_TEST="$MQ2"
touch "$DD/AUTONOMY-OFF"
check "Q2: with the pin removed, AUTONOMY-OFF stops pinning" "L2" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
rm -f "$DD/AUTONOMY-OFF"
check "Q2: and it is not just broken — L2 still resolves without it" "L2" \
      "$(libsh "$DD" "$DD/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
LIB_UNDER_TEST="$LIB"

echo
echo "=== Q3. MUTANT: a pass-through promotion check ========================="
MQ3="$SANDBOX/autonomy.no-evidence.sh"; sandboxed "$MQ3"
awk '{print}
     /^autonomy_promotion_check\(\) \{ # \$1 = repo slug, \$2 = level$/{print "  AUTONOMY_PROMOTION_DETAIL=mutant; return 0"}' "$LIB" > "$MQ3"
cmp -s "$LIB" "$MQ3" && { echo "ERROR: the no-evidence mutant is identical" >&2; exit 1; }
/bin/bash -n "$MQ3" || { echo "ERROR: mutant Q3 does not parse" >&2; exit 1; }
LIB_UNDER_TEST="$MQ3"
F="$(newF mutant)"
check "Q3: without the evidence check, a bare config edit reaches L2" "L2" \
      "$(libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
check "Q3: which is exactly what the shipped library refuses" "L0" \
      "$(LIB_UNDER_TEST="$LIB"; libsh "$F" "$F/repo" fixture/repo 'autonomy_resolve "$RP" "$RS"; printf "%s" "$AUTONOMY_LEVEL"')"
LIB_UNDER_TEST="$LIB"

echo
echo "=== sandbox discipline (GH #15) ========================================"
ESCAPES="$(grep -l 'STUB REFUSED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no stub ever had to refuse a git or gh mutation" "" "$ESCAPES"
UNANSWERED="$(grep -l 'STUB UNANSWERED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no gh query went unanswered (silent degradation)" "" "$UNANSWERED"
check "the host repo did not move (HEAD + working tree)" "$HOST_BEFORE" "$(host_fingerprint)"
check "every run redirects HOME into the sandbox" "2" \
      "$(grep -c 'HOME="\$D/home"' "$0" | tr -d ' ')"
check "and redirects all four control files away from the live config" "4" \
      "$(grep -oE 'INTAKE_(AUTONOMY_FILE|AUTONOMY_OVERRIDE|STOP_FILE|PROMOTIONS_DIR)=' "$0" | sort -u | grep -c .)"

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
