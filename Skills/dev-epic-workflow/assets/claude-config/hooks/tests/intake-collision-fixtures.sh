#!/usr/bin/env bash
# Fixture harness for COLLISION DETECTION IN ADMISSION in the unattended runner:
#   ../../bin/unattended-intake.sh
#
# Epic 09 item 4 gave admission this check. Epic 10 item 4 is this file's
# current owner: it replaces the ORIGINAL prose extractor (tokenise
# `**Scope:**` free text, guess which tokens are paths, drop generic ones,
# trade recall against precision) with a reader of the structured
# `**Touches:**` field epic 10 item 1 defined and item 2's drafter emits. This
# suite is epic 09 item 4's own fixture suite, carried forward and re-pointed
# at the new reader — same cases, same letters where the case still applies,
# fixture PLAN TEXT rewritten from `**Scope:**` prose to `**Touches:**` blocks.
#
#   LODE #732 and #733 each worked out for themselves that they targeted the
#   same `except` blocks in the same file, and each escalated to a human. That
#   worked, and it is not a mechanism — it is two drafters happening to be
#   conscientious on the same afternoon. So admission now compares what a fresh
#   proposal DECLARES it will touch against what every other OPEN proposal in
#   the repo declares, and on overlap it DOWNGRADES the fresh proposal's own
#   `**Recommendation:**` from `plan` to `needs-decision`.
#
# The downgrade is the whole point, and it is written into the plan FILE, not
# only into the PR: `session-start-context.sh` buckets a proposal by reading
# `**Recommendation:**` out of the plan.md header, so unless the file says
# needs-decision the proposal keeps rendering under *awaiting approval* — where
# it can be approved without the collision ever being registered.
#
# WHAT COUNTS AS A DECLARATION, under the new reader:
#
#   * `**Touches:**` blocks only — one `- \`path\`` bullet per line, read
#     literally. There is no tokenising and nothing left to guess at, so the
#     whole PROSE measurement epic 10's Grounding section records (recall vs.
#     precision, the denylist of structural tokens, English mistaken for a
#     path) no longer applies: it was a property of parsing free text, and free
#     text is no longer what is read. Cases N and P from the prior suite, which
#     pinned that measurement, are gone for that reason, not forgotten.
#   * A file named only in prose — `**Scope:**`, `**Not in scope:**`, anywhere
#     else — is not a declaration, because prose is never read at all now
#     (case E). PR #25's *Not in scope* naming `cancel-gate.sh`, which PR #26's
#     *Scope* prose also names, was the first false positive the old extractor
#     ever produced; it cannot recur because nothing outside a `**Touches:**`
#     block is examined.
#   * Suffix matching at path-component boundaries (`same_declared_path()`,
#     untouched by this item) still guards against two spellings of the same
#     file — case D, mutant S — even though item 1's rule is repo-root-relative
#     always, because nothing enforces that rule at write time.
#   * No denylist. `plan.md` / `status/` / `docs/epics/` existed only to filter
#     structural nouns a prose tokeniser mistook for declarations; a
#     `**Touches:**` block never contains a mistaken token; case F is
#     repointed at proving that structural-sounding NOUNS IN PROSE (as opposed
#     to real Touches entries) no longer even reach the comparison.
#
# The check runs ONLY for a `plan` recommendation. A `no-work` draft proposes no
# edits and usually carries no `**Touches:**` block at all, so running the
# colliding-unknown rule over it would turn every honest no-work into a
# needs-decision and quietly delete epic 09 item 1's outcome (case G).
#
# Cases:
#   A  two proposals declaring the SAME file (via Touches) -> the second is
#      downgraded to needs-decision, naming the first, in the header, the plan
#      body, the PR title, the PR body, its own issue comment and the
#      counterpart's issue
#   B  two proposals declaring DISJOINT files -> completely unaffected
#   C  the real LODE #730/#731 pair, re-declared via Touches with every trace
#      of the drafters' own collision reasoning stripped out -> still detected
#   D  suffix normalisation: a full path and a short path for the same file,
#      each in its own Touches block
#   E  a file named only in prose (Scope or Not in scope) is not a declaration
#      — it is simply absent from the Touches block, not filtered out
#   F  structural nouns (`plan.md`, `status/`, `docs/epics/`) appearing in
#      PROSE do not collide anything, because prose is never read; a real
#      Touches entry naming one of them WOULD collide (there is no denylist)
#   G  a `no-work` draft is not checked and is not downgraded
#   H  a `plan` draft with no `**Touches:**` block at all -> colliding-unknown,
#      downgraded rather than passed silently — every proposal that predates
#      this epic lands here
#   I  the open-proposal query fails -> publishes anyway, and says so
#   J  a counterpart plan that cannot be read -> logged, never silent, and the
#      other counterpart is still compared
#   K  an open PR that is not a proposal branch is not enumerated
#   L  a proposal on OUR OWN head branch does not collide with itself
#   M  --dry-run never reaches the check and mutates nothing, anywhere
#   T  a repo with NO other open proposal never downgrades anything, however
#      little the fresh draft declares — there is nothing to rule out
#   U  the drafter produced no plan file at all -> unknown, published loudly,
#      and emphatically NOT a downgrade of a plan that is not there
#   N  declared_paths() replayed directly over structured Touches text: one
#      block, several blocks unioned across work items, a block that declares
#      nothing, and a malformed line inside a block that is skipped rather than
#      truncating what follows
#   O  same_declared_path() boundary table (unchanged machinery, re-verified)
#   Q  control flow: the check sits after the REC block and before gh pr create;
#      the prose extractor and its denylist are GONE, not dormant
#   R  mutant: delete the downgrade and case A publishes at `plan` again
#   S  mutant: delete suffix matching and case D stops colliding
#   V  the actual live proposals #25, #26 and #50 (verbatim plan text, fetched
#      2026-08-26), which predate this epic and carry no `**Touches:**` block
#      today, land on colliding-unknown exactly as the invariant requires; a
#      simulated version of each carrying the field it does not have yet finds
#      the same true collisions the old extractor found and neither of its two
#      known false positives — the epic's own verification bullet, replayed
#
# SANDBOX DISCIPLINE (GH #15 is open: a fixture harness in this repo has already
# escaped its sandbox and committed a real working tree). This harness:
#   - creates everything under one mktemp -d, removed on exit
#   - stubs git, gh and claude on disk; none of them touch the network
#   - permits `git add`/`git commit` ONLY with an explicit -C inside the
#     sandbox, because the runner now legitimately commits the downgrade — any
#     other add/commit is refused and recorded
#   - FAILS LOUDLY rather than degrading when the runner asks a question the
#     stub does not model. The whole collision check reads `gh pr list` and
#     `gh api .../contents/...`, both NEW queries: a stub that answered them
#     with silence would make every case below pass while testing nothing.
#     See STUB UNANSWERED at the end.
#   - fingerprints the repo it lives in before and after
#   - case V's "live proposal" text is embedded VERBATIM as of the fetch date
#     named above — a static heredoc, not a network call at test time, exactly
#     like the prior suite's `pr25.md`/`pr26.md`/`pr50.md` embeds
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/intake-collision-fixtures.sh
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-unattended-intake.sh bash ...
#           (the override exists so this suite can be run against the
#            PRE-ITEM-4 script as a negative control; it must NOT pass there)
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$(cd "$TESTS_DIR/../../bin" && pwd)/unattended-intake.sh}"
[ -f "$SCRIPT" ] || { echo "ERROR: not found: $SCRIPT" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/intake-collision-fixtures.XXXXXX")" || exit 1
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

# -------------------------------------------------- GH #15 tripwire (read only)
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
    esac ;;
  label)
    printf '%s\tfixture label\n' "${FIXTURE_LABEL:-claude-intake}" ;;
  issue)
    case "${2:-}" in
      list)    [ -f "$CASE/issues" ] && cat "$CASE/issues" ;;
      view)    # Epic 09 item 8 reads the issue's LABELS from this call, so the
               # field set is pinned. Unpinned, a stub answering the old
               # title-only shape would corrupt the title this suite derives
               # every proposal slug from — and the paths would move under the
               # assertions without anything saying why.
               case "$FLAT" in
                 *"--json title,labels "*) ;;
                 *) printf 'gh STUB UNANSWERED (issue view field set changed): %s\n' "$FLAT" >> "$CASE/calls.log"
                    echo 'stub does not model this issue view field set' >&2; exit 1 ;;
               esac
               # No labels, deliberately and for every case: an issue carrying
               # `epic:planned` is skipped at selection and never reaches the
               # collision check at all, so a labelled fixture here would test
               # item 8 rather than item 4. The fence is what item 8's parser
               # reads (ISSUE_VIEW_JQ); `,,` is a real empty labels array.
               printf ',,\n'
               printf 'fixture issue %s\n' "${3:-0}" ;;
      comment) printf '%s\n' "$FLAT" >> "$CASE/comments.log"
               # the body is the last argument; keep it whole so assertions can
               # read what a human would actually receive
               for A in "$@"; do LAST="$A"; done
               { printf '<<<comment on %s>>>\n' "${3:-0}"; printf '%s\n' "$LAST"; } \
                 >> "$CASE/comment-bodies.log"
               printf 'https://example.invalid/issues/%s#comment\n' "${3:-0}" ;;
      edit)    : ;;
    esac ;;
  api)
    P=""
    for A in "$@"; do
      case "$A" in */issues/*/timeline*|*/contents/*|*/branches*) P="$A" ;; esac
    done
    [ -n "$P" ] || unanswered "api path not modelled"
    case "$P" in
      */branches*)
        # Epic 09 item 7's work-in-progress BRANCH signal, answered DELIBERATELY
        # and empty: no case in this file has a branch named for its issue, so
        # item 7's check stays on its `clear` path and these fixtures stay about
        # collisions. Leaving it unanswered would put every case below on item
        # 7's degraded `unknown` path while this suite reported green — which is
        # the same defect item 7 itself had to fix in item 2's stub.
        printf 'x' >> "$CASE/branch-calls"
        [ -f "$CASE/branches" ] && cat "$CASE/branches"
        exit 0 ;;
      */issues/*/timeline*)
        [ -f "$CASE/timeline-fail" ] && { echo '{"message":"Not Found"}'; exit 1; }
        N="${P#*/issues/}"; N="${N%%/*}"
        [ -f "$CASE/timeline/$N" ] && cat "$CASE/timeline/$N"
        exit 0 ;;
      */contents/*)
        # The runner asks for RAW content. If it ever stops doing that, an
        # answer in the old shape would be base64 the extractor reads as no
        # declared paths at all — i.e. "no collision" — for every case here.
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
        # Pin the EXACT field set (trailing space is load-bearing: adding a
        # field would otherwise still match this prefix and the stub would go on
        # answering the old shape, which is the whole bug this guards).
        case "$FLAT" in
          *"--json number,headRefName "*) ;;
          *) unanswered "pr list field set changed" ;;
        esac
        [ -f "$CASE/proposal-list-fail" ] && { echo 'API rate limit exceeded' >&2; exit 1; }
        [ -f "$CASE/proposals" ] && cat "$CASE/proposals"
        exit 0 ;;
      view)
        case "$FLAT" in
          *"--json state,headRefName,url,closingIssuesReferences,body "*) ;;
          *) unanswered "pr view field set changed" ;;
        esac
        F="$CASE/pr/${3:-}"
        [ -f "$F" ] || { echo 'no such PR' >&2; exit 1; }
        cat "$F" ;;
      create) printf 'https://example.invalid/pull/999\n' ;;
      edit)   printf 'gh STUB REFUSED (an open PR is never rewritten): %s\n' "$FLAT" >> "$CASE/calls.log"
              exit 98 ;;
    esac ;;
esac
exit 0
GH_STUB

# git: does no version control. It refuses anything that could move a real tree.
# `add` and `commit` are PERMITTED, but only with an explicit -C inside the
# sandbox, because the runner now legitimately commits the downgrade into the
# proposal worktree. Everything else that could mutate history is refused.
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
      printf 'git SANDBOXED-%s in %s\n' "$1" "$CDIR" >> "$CASE/calls.log"
      exit 0
    fi
    printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"
    exit 99 ;;
  rm|mv|checkout|switch|reset|merge|rebase|clean)
    printf 'git STUB REFUSED (GH #15): %s\n' "$FLAT" >> "$CASE/calls.log"
    exit 99 ;;
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
      remove) # The runner removes the worktree on success, which would delete the
              # very artifact these fixtures need to read back — the downgraded
              # plan.md. Move it aside instead of destroying it, and record that
              # the removal happened, so both facts stay checkable.
              for A in "$@"; do case "$A" in "$FIXTURE_SANDBOX"/*) WT="$A" ;; esac; done
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

# claude: the headless drafter. It writes the case's draft plan at exactly the
# path the runner's own prompt names, so the runner reads back a real file.
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
if [ -f "$CASE/no-draft" ]; then
  printf 'claude stub wrote no plan at all (case U)\n' >> "$CASE/calls.log"
  exit 0
fi
mkdir -p "$(dirname "$PLANPATH")"
if [ -f "$CASE/draft.md" ]; then cp "$CASE/draft.md" "$PLANPATH"; else : > "$PLANPATH"; fi
printf '%s\n' "$PLANPATH" >> "$CASE/drafted-at.log"
exit 0
CLAUDE_STUB

chmod +x "$BIN/gh" "$BIN/git" "$BIN/claude"

SKILL="$SANDBOX/skill"; sandboxed "$SKILL"; mkdir -p "$SKILL/references"
printf 'fixture issue-intake reference\n'  > "$SKILL/references/issue-intake.md"
printf 'fixture plan-template reference\n' > "$SKILL/references/plan-template.md"

# ------------------------------------------------------------------ helpers
mkcase() { # $1 = case name -> case dir on stdout
  D="$SANDBOX/$1"; sandboxed "$D"
  rm -rf "$D"
  mkdir -p "$D/repo/.git" "$D/worktrees" "$D/home" "$D/timeline" "$D/pr" "$D/contents"
  : > "$D/calls.log"; : > "$D/comments.log"; : > "$D/comment-bodies.log"
  : > "$D/proposals"
  printf '%s\n' "$D/repo" > "$D/repos"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$D/env"
  chmod 600 "$D/env"
  printf '%s' "$D"
}

set_issues() { D="$1"; shift; sandboxed "$D"; : > "$D/issues"
  for I in "$@"; do printf '%s\n' "$I" >> "$D/issues"; done; }

# An OPEN proposal the runner will find and compare against.
#   $1 = case dir, $2 = PR number, $3 = head branch, $4 = plan file to serve
open_proposal() {
  sandboxed "$1"
  printf '%s %s\n' "$2" "$3" >> "$1/proposals"
  [ -n "${4:-}" ] || return 0
  KEY="$(printf '%s' "$3" | tr '/' '_')"
  cp "$4" "$1/contents/$KEY"
}

# An open PR that is NOT a proposal (case K), or one whose plan is missing (J).
open_pr_only() { sandboxed "$1"; printf '%s %s\n' "$2" "$3" >> "$1/proposals"; }

SCRIPT_UNDER_TEST="$SCRIPT"

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

# Where the runner left the proposal it drafted for issue $2 in case $1.
planfile() { # $1 = case dir, $2 = issue -> the drafted plan, wherever it ended up
  P="$1/worktrees/repo-proposed-$2-fixture-issue-$2/docs/epics/proposed-$2-fixture-issue-$2/plan.md"
  [ -f "$P" ] || P="$1/removed-worktree/docs/epics/proposed-$2-fixture-issue-$2/plan.md"
  printf '%s' "$P"; }

# The recommendation the PR TITLE carries, as one comparable token.
title_rec() { # $1 = case dir
  L="$(grep -m1 '^gh pr create ' "$1/calls.log" 2>/dev/null || true)"
  case "$L" in
    *'[needs-decision] proposed epic'*) printf 'needs-decision' ;;
    *'[no-work] proposed epic'*)        printf 'no-work' ;;
    *'proposed epic'*)                  printf 'plan' ;;
    *)                                  printf 'none' ;;
  esac
}

# The recommendation the plan FILE carries — the one session-start-context.sh
# reads, and therefore the one that decides which bucket a human sees it in.
file_rec() { # $1 = case dir, $2 = issue
  F="$(planfile "$1" "$2")"
  [ -f "$F" ] || { printf 'no-plan-file'; return; }
  V="$(head -10 "$F" | sed -n -E -e 's/^[[:space:]*_]*[Rr]ecommendation:[[:space:]*_]*//p' | head -1 | tr -d '\r')"
  [ -n "$V" ] && printf '%s' "$V" || printf 'absent'
}

called() { grep -q "$2" "$1/calls.log"; }
yesno()  { if "$@"; then printf 'yes'; else printf 'no'; fi; }
inbody() { grep -qF "$2" "$1/comment-bodies.log"; }
inpr()   { grep -qF "$2" "$1/calls.log"; }

echo "sandbox: $SANDBOX"
echo "script:  $SCRIPT"
echo "bash:    $(/bin/bash --version | head -1)"
echo
# --------------------------------------------------------------- plan fixtures
PLANS="$SANDBOX/plans"; sandboxed "$PLANS"; mkdir -p "$PLANS"

plan_header() { # $1 = recommendation ('' for absent)
  printf '# Epic: fixture\n\n**Status:** planning\n'
  [ -n "${1:-}" ] && printf '**Recommendation:** %s\n' "$1"
  printf '**Source:** GH #0\n\n'
}

cat > "$PLANS/alpha.md" <<'P'
# Epic: alpha

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Outcome
Fixture.

## Work items

### 1. Alpha
- **Branch:** `feat/alpha`
- **Scope:** rewrite the thing; also touches the release notes.
- **Touches:**
  - `src/alpha.ts`
  - `docs/alpha-notes.md`
- **Not in scope:** `src/beta.ts`, which belongs to another epic.

## Log
- fixture
P

cat > "$PLANS/beta.md" <<'P'
# Epic: beta

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Outcome
Fixture.

## Work items

### 1. Beta
- **Branch:** `feat/beta`
- **Scope:** rewrite the other thing; also touches the release notes.
- **Touches:**
  - `src/beta.ts`
  - `docs/beta-notes.md`
- **Not in scope:** `src/alpha.ts`.

## Log
- fixture
P

# Same file as alpha.md declares, named identically. Case A.
cat > "$PLANS/alpha-twin.md" <<'P'
# Epic: alpha twin

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Outcome
Fixture.

## Work items

### 1. Alpha, again
- **Branch:** `feat/alpha-twin`
- **Scope:** a different change to the same file.
- **Touches:**
  - `src/alpha.ts`
- **Not in scope:** everything else.

## Log
- fixture
P

# The suffix-normalisation pair (case D): the SAME file, written long and short,
# each in its own Touches block, exactly as live proposals #26 and #50 write it
# in their (still prose-only) Scope today.
cat > "$PLANS/long-path.md" <<'P'
# Epic: long

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Work items

### 1. Long
- **Scope:** extend section H.
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
P

cat > "$PLANS/short-path.md" <<'P'
# Epic: short

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Work items

### 1. Short
- **Scope:** a new case for the orphan bucket.
- **Touches:**
  - `hooks/tests/active-epic-fixtures.sh`
P

# Case E: the file is named ONLY in prose (Scope and Not in scope). Neither is a
# `**Touches:**` block, so neither is read at all — not filtered, simply never
# examined.
cat > "$PLANS/mentions-only.md" <<'P'
# Epic: mentions

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Work items

### 1. Mentions
- **Scope:** touches `src/gamma.ts` only; separately discusses `hooks/cancel-gate.sh`
  and `src/alpha.ts` below, neither of which this item changes.
- **Touches:**
  - `src/gamma.ts`
- **Not in scope:** any change to `hooks/cancel-gate.sh` or `src/alpha.ts`
  themselves — this item only reads what they already write.
P

# Case F: structural nouns named in PROSE (Scope, Outcome) do not collide
# anything, because prose is never read at all — there is no denylist to do the
# filtering, because nothing reaches the comparison for filtering to matter.
cat > "$PLANS/generic-a.md" <<'P'
# Epic: generic a

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Outcome
Touches this epic's own `plan.md`, its `status/` tree and the `docs/epics/`
folder in the sense that every epic does; the real edit is elsewhere.

## Work items

### 1. Generic A
- **Scope:** the real change, discussed above only in passing relative to
  `plan.md`, `status/` and `docs/epics/`.
- **Touches:**
  - `src/alpha.ts`
P

cat > "$PLANS/generic-b.md" <<'P'
# Epic: generic b

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Outcome
Touches this epic's own `plan.md`, its `status/` tree and the `docs/epics/`
folder in the sense that every epic does; the real edit is elsewhere.

## Work items

### 1. Generic B
- **Scope:** the real change, discussed above only in passing relative to
  `plan.md`, `status/` and `docs/epics/`.
- **Touches:**
  - `src/beta.ts`
P

# Case G: an honest no-work draft. No Touches block at all, by construction.
cat > "$PLANS/no-work.md" <<'P'
# Epic: nothing to do here

**Status:** planning
**Recommendation:** no-work
**Source:** GH #0

## Outcome
Already fixed by PR #12. There is nothing for an approved epic to dispatch.

## Log
- fixture
P

# Case H: a `plan` with no `**Touches:**` block anywhere — every proposal that
# predates this epic looks exactly like this.
cat > "$PLANS/undeclared.md" <<'P'
# Epic: vague

**Status:** planning
**Recommendation:** plan
**Source:** GH #0

## Work items

### 1. Vague
- **Scope:** tidy up the error handling and make the messages friendlier.
- **Not in scope:** anything else.
P

# ---- the real LODE #730 / #731 pair, WITH THE DRAFTERS' OWN COLLISION
# ---- REASONING STRIPPED OUT, and re-declared via `**Touches:**` rather than
# ---- via the Scope prose both plans actually shipped with (neither carries the
# ---- field; this simulates what each would look like once it did, same as
# ---- case V does for the three live proposals). Both plans detected this
# ---- collision themselves and said so at length — in Grounding, in Risks and
# ---- in Deferred. None of that prose is here. If admission still detects the
# ---- pair from a bare Touches block, it does not depend on the drafter having
# ---- noticed. (DoD clause 3.)
cat > "$PLANS/lode-730-stripped.md" <<'P'
# Epic: Invalid query error surfaced to user as generic 502

**Status:** planning
**Recommendation:** plan
**Source:** GH #730

## Work items

### 2. Classify invalid-query failures and say so
- **Scope:** add a classifier for invalid-query failures in `lookups.py` and
  route both `execute()` and `execute_across()` through it. No frontend change.
- **Touches:**
  - `apps/api/src/api/routes/lookups.py`
- **Not in scope:** auto-correcting the user's SQL.
P

cat > "$PLANS/lode-731-stripped.md" <<'P'
# Epic: Manage Rules shows raw BIP SOAP SQL exception

**Status:** planning
**Recommendation:** plan
**Source:** GH #731

## Work items

### 1. Friendly, logged query-failure message on both lookup routes
- **Scope:** add a friendly, logged `McpToolError` branch to both `execute()`
  and `execute_across()` in `lookups.py`. No frontend change expected.
- **Touches:**
  - `apps/api/src/api/routes/lookups.py`
- **Not in scope:** parsing the Oracle error code out of the fault text.
P

# ============================================================================
echo "=== A. two proposals declaring the SAME file: the second is downgraded ="
echo "    (issue #90 drafts a plan touching src/alpha.ts; PR #77 is an open"
echo "     proposal for issue #77 that already declares src/alpha.ts)"
D="$(mkcase A)"
set_issues "$D" 90
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "A: exit code (a downgrade is not a failure)" "0" "$RC"
check "A: a PR was opened at all"        "yes" "$(yesno called "$D" '^gh pr create')"
check "A: the PR TITLE tag"              "needs-decision" "$(title_rec "$D")"
check "A: the plan FILE header — what SessionStart buckets on" \
      "needs-decision" "$(file_rec "$D" 90)"
check "A: the downgrade is recorded in the runner log" "yes" \
      "$(yesno grep -q '#90: collision -> recommendation downgraded from plan to needs-decision' "$D/stdout.log")"
check "A: the plan BODY carries the collision section" "yes" \
      "$(yesno grep -q '^## Collision detected in admission' "$(planfile "$D" 90)")"
check "A: the plan body names the counterpart PR" "yes" \
      "$(yesno grep -q 'PR #77' "$(planfile "$D" 90)")"
check "A: the plan body names the shared path" "yes" \
      "$(yesno grep -q 'src/alpha.ts' "$(planfile "$D" 90)")"
check "A: the collision section precedes the plan's first section" "yes" \
      "$(if [ "$(grep -n '^## ' "$(planfile "$D" 90)" | head -1 | cut -d: -f2- )" = '## Collision detected in admission — not approvable as it stands' ]; then echo yes; else echo no; fi)"
check "A: the downgrade was committed on the proposal branch" "yes" \
      "$(yesno called "$D" '^git SANDBOXED-commit')"
check "A: ONLY the proposal's own plan.md was staged" "1" \
      "$(grep -c ' add docs/epics/proposed-90-fixture-issue-90/plan.md ' "$D/calls.log" | tr -d ' ')"
check "A: and nothing else was ever staged"       "1" \
      "$(grep -c '^git -C .* add ' "$D/calls.log" | tr -d ' ')"
check "A: Status is still planning — the runner never approves" "yes" \
      "$(yesno grep -qx '\*\*Status:\*\* planning' "$(planfile "$D" 90)")"
check "A: the PR body names the counterpart PR"   "yes" "$(yesno inpr "$D" 'PR #77')"
check "A: the PR body names the shared path"      "yes" "$(yesno inpr "$D" 'src/alpha.ts')"
check "A: the PR body says admission did it, not the drafter" "yes" \
      "$(yesno inpr "$D" 'Collision detected in admission')"
check "A: the source issue comment carries the collision" "yes" \
      "$(yesno inbody "$D" 'Admission also found a collision')"
check "A: the COUNTERPART issue #77 was commented on" "yes" \
      "$(yesno called "$D" '^gh issue comment 77 ')"
check "A: that comment names the new PR"          "yes" \
      "$(yesno inbody "$D" 'https://example.invalid/pull/999')"
check "A: that comment says nothing was superseded" "yes" \
      "$(yesno inbody "$D" 'no plan was rewritten, nothing was superseded')"
check "A: the counterpart PR was NEVER edited"    "no"  "$(yesno called "$D" '^gh pr edit')"
check "A: no stub ever had to refuse a PR edit"   "no"  \
      "$(yesno grep -q 'STUB REFUSED (an open PR is never rewritten)' "$D/calls.log")"
check "A: nothing was merged"                     "no"  "$(yesno called "$D" 'pr merge')"
check "A: the issue was not closed"               "no"  "$(yesno called "$D" 'issue close')"
check "A: the label came off exactly as before"   "yes" \
      "$(yesno called "$D" '^gh issue edit 90 --remove-label claude-intake')"
# Not decoration: without this, every case above could be riding item 7's
# degraded path and this file would still print green.
check "A: item 7's branch listing was answered both times, not degraded" "2" \
      "$(wc -c < "$D/branch-calls" 2>/dev/null | tr -d ' ')"

echo
echo "=== B. two proposals declaring DISJOINT files: nothing happens =========="
D="$(mkcase B)"
set_issues "$D" 91
cp "$PLANS/beta.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "B: exit code"                     "0" "$RC"
check "B: the PR TITLE carries no tag"   "plan" "$(title_rec "$D")"
check "B: the plan FILE still says plan" "plan" "$(file_rec "$D" 91)"
check "B: the plan body has no collision section" "no" \
      "$(yesno grep -q 'Collision detected' "$(planfile "$D" 91)")"
check "B: the clear verdict is logged"   "yes" \
      "$(yesno grep -q '#91: no collision' "$D/stdout.log")"
check "B: the counterpart issue was NOT commented on" "no" \
      "$(yesno called "$D" '^gh issue comment 77 ')"
check "B: nothing extra was committed"   "no"  "$(yesno called "$D" '^git SANDBOXED-commit')"
check "B: the counterpart plan WAS actually fetched (not skipped)" "yes" \
      "$(yesno called "$D" 'contents/docs/epics/proposed-77-alpha/plan.md?ref=intake/proposed-77-alpha')"

echo
echo "=== C. the real LODE #730 / #731 pair, collision reasoning stripped ====="
echo "    (both drafters detected this themselves and wrote paragraphs about"
echo "     it; none of that prose is in these fixtures — only Touches blocks)"
D="$(mkcase C)"
set_issues "$D" 730
cp "$PLANS/lode-730-stripped.md" "$D/draft.md"
open_proposal "$D" 732 "intake/proposed-731-manage-rules-shows-raw-bip" "$PLANS/lode-731-stripped.md"
check "C: the #730 fixture never mentions #731"   "0" \
      "$(grep -c '731' "$PLANS/lode-730-stripped.md" | tr -d ' ')"
check "C: the #731 fixture never mentions #730"   "0" \
      "$(grep -c '730' "$PLANS/lode-731-stripped.md" | tr -d ' ')"
check "C: neither fixture uses collision vocabulary" "0" \
      "$(cat "$PLANS/lode-730-stripped.md" "$PLANS/lode-731-stripped.md" \
         | grep -ciE 'collide|collision|overlap|superset|supersede|same .*(except|block)' | tr -d ' ')"
RC="$(run_intake "$D")"
check "C: detected anyway"                        "needs-decision" "$(title_rec "$D")"
check "C: the plan file is downgraded"            "needs-decision" "$(file_rec "$D" 730)"
check "C: on the file both plans really name"     "yes" \
      "$(yesno inpr "$D" 'apps/api/src/api/routes/lookups.py')"
check "C: naming the counterpart proposal PR"     "yes" "$(yesno inpr "$D" 'PR #732')"
check "C: and the counterpart issue was told"     "yes" \
      "$(yesno called "$D" '^gh issue comment 731 ')"

echo
echo "=== D. suffix normalisation: the same file, long path and short ========"
echo "    (PR #26's Touches would write Skills/.../hooks/tests/x.sh where"
echo "     PR #50's would write hooks/tests/x.sh — exact-string matching"
echo "     misses the pair entirely; suffix matching is unchanged by item 4)"
D="$(mkcase D)"
set_issues "$D" 92
cp "$PLANS/short-path.md" "$D/draft.md"
open_proposal "$D" 78 "intake/proposed-78-long" "$PLANS/long-path.md"
RC="$(run_intake "$D")"
check "D: detected across the two spellings"      "needs-decision" "$(title_rec "$D")"
check "D: reported as the SHORTER common suffix"  "yes" \
      "$(yesno inpr "$D" '`hooks/tests/active-epic-fixtures.sh`')"

echo
echo "=== E. a file named only in prose is not a declaration =================="
echo "    (mentioned in Scope AND in Not-in-scope; neither is a Touches block,"
echo "     so neither is read — the mention-vs-declaration line, structurally)"
D="$(mkcase E)"
set_issues "$D" 93
cp "$PLANS/mentions-only.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "E: src/alpha.ts in Not-in-scope does not collide" "plan" "$(title_rec "$D")"
check "E: the plan file is untouched"             "plan" "$(file_rec "$D" 93)"

echo
echo "=== F. plan.md / status/ / docs/epics/ named in PROSE collide nothing ===="
echo "    (all three appear in live proposal #50's Scope prose; the OLD prose"
echo "     extractor needed a denylist to keep them from colliding every"
echo "     proposal forever — the new reader needs none, because prose is"
echo "     never examined at all)"
D="$(mkcase F)"
set_issues "$D" 94
cp "$PLANS/generic-b.md" "$D/draft.md"
open_proposal "$D" 79 "intake/proposed-79-generic" "$PLANS/generic-a.md"
RC="$(run_intake "$D")"
check "F: the shared structural tokens do not collide" "plan" "$(title_rec "$D")"
check "F: and it is not because nothing was compared" "yes" \
      "$(yesno called "$D" 'contents/docs/epics/proposed-79-generic/plan.md')"

echo
echo "=== G. a no-work draft is not checked, and is not downgraded ============"
echo "    (it proposes no edits and carries no Touches block; running the"
echo "     colliding-unknown rule over it would delete item 1's outcome)"
D="$(mkcase G)"
set_issues "$D" 95
cp "$PLANS/no-work.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "G: the PR title still says no-work"        "no-work" "$(title_rec "$D")"
check "G: the plan file still says no-work"       "no-work" "$(file_rec "$D" 95)"
check "G: and the runner says why it skipped the check" "yes" \
      "$(yesno grep -q '#95: collision check not run — recommendation is no-work' "$D/stdout.log")"
check "G: no proposal was even enumerated"        "no"  "$(yesno called "$D" '^gh pr list')"

echo
echo "=== H. a plan with no Touches block at all is colliding-unknown =========="
echo "    (an absent declaration is not evidence of no overlap — epic 10 item 4's"
echo "     own Scope says so explicitly, and it is the one case that fails loud;"
echo "     every proposal that predates this epic looks exactly like this)"
D="$(mkcase H)"
set_issues "$D" 96
cp "$PLANS/undeclared.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "H: downgraded rather than passed silently" "needs-decision" "$(title_rec "$D")"
check "H: the plan file says so too"              "needs-decision" "$(file_rec "$D" 96)"
check "H: the reason is stated, not implied"      "yes" \
      "$(yesno inpr "$D" 'carries no `**Touches:**` block')"
check "H: no counterpart was named (there is none)" "no" \
      "$(yesno called "$D" '^gh issue comment 77 ')"

echo
echo "=== I. the open-proposal query fails: publish anyway, and say so ========"
D="$(mkcase I)"
set_issues "$D" 97
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
: > "$D/proposal-list-fail"
RC="$(run_intake "$D")"
check "I: exit code"                              "0" "$RC"
check "I: it published"                           "plan" "$(title_rec "$D")"
check "I: the plan file is untouched"             "plan" "$(file_rec "$D" 97)"
check "I: it is never silent"                     "yes" \
      "$(yesno grep -q 'WARN #97: collision detection did not run' "$D/stdout.log")"

echo
echo "=== J. a counterpart plan that cannot be read is named, not swallowed ==="
D="$(mkcase J)"
set_issues "$D" 98
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_pr_only "$D" 80 "intake/proposed-80-vanished"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "J: the unreadable counterpart is logged"   "yes" \
      "$(yesno grep -q 'WARN #98: could not read the plan of open proposal PR #80' "$D/stdout.log")"
check "J: and the readable one was still compared" "needs-decision" "$(title_rec "$D")"
check "J: naming the counterpart that could be read" "yes" "$(yesno inpr "$D" 'PR #77')"

echo
echo "=== K. an open PR that is not a proposal branch is not a proposal ======="
D="$(mkcase K)"
set_issues "$D" 99
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_pr_only "$D" 81 "feat/somebody-elses-work"
open_pr_only "$D" 82 "docs/intake-07-attended-proposal"
RC="$(run_intake "$D")"
check "K: neither is enumerated as a proposal"    "plan" "$(title_rec "$D")"
check "K: and neither plan was fetched"           "no"  "$(yesno called "$D" 'contents/')"

echo
echo "=== L. a proposal on our own head branch does not collide with itself ==="
D="$(mkcase L)"
set_issues "$D" 100
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 83 "intake/proposed-100-fixture-issue-100" "$PLANS/alpha-twin.md"
RC="$(run_intake "$D")"
check "L: not a collision with itself"            "plan" "$(title_rec "$D")"

echo
echo "=== M. --dry-run never reaches the check and mutates nothing ============"
D="$(mkcase M)"
set_issues "$D" 101
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D" --dry-run)"
check "M: exit code"                              "0" "$RC"
check "M: it classified the issue as before"      "yes" \
      "$(yesno grep -q 'DRY-RUN: #101 classified DRAFT' "$D/stdout.log")"
check "M: no proposal was enumerated"             "no"  "$(yesno called "$D" '^gh pr list')"
check "M: no plan was fetched"                    "no"  "$(yesno called "$D" 'contents/')"
check "M: nothing was committed"                  "no"  "$(yesno called "$D" '^git SANDBOXED-commit')"
check "M: no comment anywhere"                    ""    "$(cat "$D/comments.log")"
check "M: no PR"                                  "no"  "$(yesno called "$D" '^gh pr create')"
check "M: no log file was written"                "no"  "$(yesno test -f "$D/intake.log")"

echo
echo "=== T. no other open proposal: nothing to rule out, so nothing is ruled ="
echo "    (the defect this case exists for: deciding 'declares nothing' BEFORE"
echo "     'declares nothing against whom' downgraded every draft in a repo"
echo "     with an empty proposal queue — measured, not imagined)"
D="$(mkcase T)"
set_issues "$D" 102
cp "$PLANS/undeclared.md" "$D/draft.md"
RC="$(run_intake "$D")"
check "T: exit code"                              "0" "$RC"
check "T: a plan with no declared file is still published as a plan" \
      "plan" "$(title_rec "$D")"
check "T: and the file is untouched"              "plan" "$(file_rec "$D" 102)"
check "T: the proposal queue WAS enumerated (it is empty, not unasked)" "yes" \
      "$(yesno called "$D" '^gh pr list')"
check "T: reported as no collision, not as unknown" "yes" \
      "$(yesno grep -q '#102: no collision' "$D/stdout.log")"

echo
echo "=== U. the drafter produced no plan file at all ========================="
echo "    (a failed READ is not an empty declaration: a plan that is not there"
echo "     cannot be downgraded, and pretending otherwise failed the run)"
D="$(mkcase U)"
set_issues "$D" 103
: > "$D/no-draft"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "U: exit code — this is not a failure"      "0" "$RC"
check "U: it published"                           "plan" "$(title_rec "$D")"
check "U: and said why the check could not run"   "yes" \
      "$(yesno grep -q 'WARN #103: no readable plan at' "$D/stdout.log")"
# Item 7's case V greps for the phrase "could not run" to prove ITS check stayed
# on the normal path. Neither of collision detection's two fallbacks may say it.
check "U: and does not borrow the work-in-progress check's wording" "no" \
      "$(yesno grep -q 'could not run' "$D/stdout.log")"
check "U: nothing was committed"                  "no"  "$(yesno called "$D" '^git SANDBOXED-commit')"
check "U: the counterpart issue was not told anything" "no" \
      "$(yesno called "$D" '^gh issue comment 77 ')"

# ============================================================================
# The extractor, exercised directly. Cases A-M prove the runner wires it up;
# these prove the thing being wired up reads a `**Touches:**` block correctly.
# The functions are lifted OUT OF THE SCRIPT UNDER TEST rather than restated
# here, so a change to the script is a change to what these assert. Only
# `declared_paths` and `same_declared_path` are lifted — `normalise_declared_paths`
# and `DECLARED_PATH_DENY_RE` no longer exist in the script, by design (case Q
# asserts that directly), so lifting them would be an ERROR, not a skip.
eval "$(awk '/^declared_paths\(\) \{/,/^}/' "$SCRIPT")"
eval "$(awk '/^same_declared_path\(\) \{/,/^}/' "$SCRIPT")"
for FN in declared_paths same_declared_path; do
  command -v "$FN" >/dev/null 2>&1 || {
    echo "ERROR: could not lift $FN out of $SCRIPT — cases N/O would test" >&2
    echo "       nothing at all, so this is a hard failure, not a skip." >&2
    exit 1; }
done
for FN in normalise_declared_paths; do
  command -v "$FN" >/dev/null 2>&1 && {
    echo "ERROR: $FN still exists in $SCRIPT — the prose extractor was supposed" >&2
    echo "       to be DELETED, not left dormant (epic 10 item 4 DoD)" >&2
    exit 1; }
done

TOUCHES="$SANDBOX/touches"; sandboxed "$TOUCHES"; mkdir -p "$TOUCHES"

echo
echo "=== N. declared_paths() over structured Touches text ===================="
# One block, read literally.
printf -- '- **Touches:**\n  - `a/one.ts`\n  - `b/two.ts`\n' > "$TOUCHES/single.md"
check "N: a single Touches block is read whole" "a/one.ts b/two.ts" \
      "$(declared_paths < "$TOUCHES/single.md" | tr '\n' ' ' | sed -e 's/ $//')"

# Two work items, each with its own Touches block, in one plan — unioned.
cat > "$TOUCHES/two-items.md" <<'P'
### 1. First
- **Touches:**
  - `a/one.ts`
- **Not in scope:** `z/decoy.ts`

### 2. Second
- **Touches:**
  - `b/two.ts`
P
check "N: Touches blocks from every work item in the plan are unioned" \
      "a/one.ts b/two.ts" \
      "$(declared_paths < "$TOUCHES/two-items.md" | tr '\n' ' ' | sed -e 's/ $//')"

# Not-in-scope, immediately adjacent to a real Touches block, does not leak in —
# structurally, because it is a different field, never because of a filter.
check "N: Not-in-scope adjacent to a Touches block does not leak in" "0" \
      "$(declared_paths < "$TOUCHES/two-items.md" | grep -cx 'z/decoy.ts' | tr -d ' ')"

# A Touches block declared with nothing under it: no paths, exactly like no
# block at all — case H's colliding-unknown path is what a caller sees next.
printf -- '- **Touches:**\n- **Not in scope:** everything\n' > "$TOUCHES/empty.md"
check "N: a Touches block with nothing under it declares nothing" "" \
      "$(declared_paths < "$TOUCHES/empty.md" | tr '\n' ' ' | sed -e 's/ $//')"

# A malformed line inside the block (no closing backtick) is skipped, and does
# NOT truncate the well-formed lines that follow it — the prior prose extractor
# had no equivalent failure mode because free text has no "malformed" shape;
# a structured field does, and this is what happens when a hand-edit breaks it.
cat > "$TOUCHES/malformed.md" <<'P'
- **Touches:**
  - `a/one.ts`
  - this line has no backticks at all
  - `b/two.ts`
P
check "N: a malformed line is skipped, not fatal, and does not truncate" \
      "a/one.ts b/two.ts" \
      "$(declared_paths < "$TOUCHES/malformed.md" | tr '\n' ' ' | sed -e 's/ $//')"

echo
echo "=== O. same_declared_path(): suffixes at COMPONENT boundaries only ======"
sdp() { if same_declared_path "$1" "$2"; then printf 'same'; else printf 'different'; fi; }
check "O: identical"                    "same" \
      "$(sdp 'hooks/tests/x.sh' 'hooks/tests/x.sh')"
check "O: long path vs short path"      "same" \
      "$(sdp 'Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh' 'hooks/tests/active-epic-fixtures.sh')"
check "O: short vs long, the other way round" "same" \
      "$(sdp 'hooks/tests/active-epic-fixtures.sh' 'Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh')"
check "O: bare filename vs full path"   "same" "$(sdp 'lookups.py' 'apps/api/src/api/routes/lookups.py')"
check "O: NOT a substring match"        "different" "$(sdp 'gate.sh' 'cancel-gate.sh')"
check "O: NOT a substring match, longer" "different" \
      "$(sdp 'tests/gate.sh' 'hooks/tests/cancel-gate.sh')"
check "O: sibling files in one directory" "different" "$(sdp 'src/a.ts' 'src/b.ts')"
check "O: a directory is not its parent"  "different" "$(sdp 'hooks' 'hooks/tests')"
check "O: same leaf under two DIFFERENT stated roots is not a match" "different" \
      "$(sdp 'a/x.sh' 'b/x.sh')"
check "O: recall comes from the unrooted form matching, not from the leaf" "same" \
      "$(sdp 'x.sh' 'b/deep/x.sh')"

echo
echo "=== V. the actual live proposals #25, #26, #50 — as-is, and once they ==="
echo "    carry the field (verbatim Scope prose fetched 2026-08-26; none of"
echo "     the three has a Touches block today — no retrofit, by invariant)"
LIVE="$SANDBOX/live"; sandboxed "$LIVE"; mkdir -p "$LIVE"

# AS-IS, verbatim: exactly what PR #25 (issue 15), PR #26 (issue 12) and PR #50
# (issue 48) declare in their plan.md TODAY. Prose only, no Touches block —
# every proposal that predates this epic looks like this.
cat > "$LIVE/pr25-asis.md" <<'P'
- **Scope:**
  - `hooks/tests/cancel-gate-fixtures.sh`, `hooks/tests/lifecycle-fixtures.sh`,
    `hooks/tests/active-epic-fixtures.sh`: port `session-start-fixtures.sh`'s `sandboxed()`
    function verbatim (or the minimal adaptation each script's helper shapes require), and call
    it at the top of every function that builds a path later used by a mutating command.
  - In all three, rename `check()`'s verdict variable from `R` to `VERDICT`.
- **Not in scope:** the `agent_id`-extraction duplication across hooks, the `hooks/lib/`
  shared-source idea, branch-selector cancel semantics, and any change to the hooks under test
  themselves (`cancel-gate.sh`, `subagent-lifecycle.sh`, `subagent-tool-logger.sh`).
P

cat > "$LIVE/pr26-asis.md" <<'P'
- **Scope:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh` —
    extend section H ("the two hooks agree") from a pairwise `cmp` between
    `subagent-lifecycle.sh` and `subagent-tool-logger.sh` to a three-way check that also
    extracts and compares the `BEGIN/END active-epic resolution` block now present in
    `cancel-gate.sh`, so drift in any of the three is caught the same way drift between the
    original two already is.
  - `Skills/dev-epic-workflow/references/executor-control-plane.md` — update the "Residual
    limitation" paragraph.
- **Not in scope:** any change to `subagent-lifecycle.sh` or `subagent-tool-logger.sh`
  themselves (this item only reads what they already write).
P

cat > "$LIVE/pr50-asis.md" <<'P'
- **Scope:**
  - `subagent-lifecycle.sh` and `subagent-tool-logger.sh` — inside the shared resolution block:
    when no pointer, no `in flight` plan, and no `approved` plan resolved, telemetry is
    written under `$REPO_ROOT/.claude/signals/orphan-telemetry/` instead of any epic's own
    `status/` tree.
  - `references/executor-control-plane.md` — rewrite the "Which epic, decided explicitly" list.
  - `hooks/tests/active-epic-fixtures.sh` — flip the four affected expectations in section N.
P

for P in pr25 pr26 pr50; do
  check "V: #$P today (as-is) declares NOTHING — no Touches block, per invariant" "" \
        "$(declared_paths < "$LIVE/$P-asis.md" | tr '\n' ' ' | sed -e 's/ $//')"
done

# SIMULATED: what each proposal's Touches block would read once it carries the
# field — the real declared paths only, in the same long/short spellings each
# proposal's own author actually used. subagent-lifecycle.sh and
# subagent-tool-logger.sh are named in #26's Scope PROSE only as the pairwise
# comparison it extends, never in a Touches block, because #26 does not touch
# them — its own Not-in-scope says so.
cat > "$LIVE/pr25-touches.md" <<'P'
- **Touches:**
  - `hooks/tests/cancel-gate-fixtures.sh`
  - `hooks/tests/lifecycle-fixtures.sh`
  - `hooks/tests/active-epic-fixtures.sh`
P
cat > "$LIVE/pr26-touches.md" <<'P'
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
  - `Skills/dev-epic-workflow/references/executor-control-plane.md`
P
cat > "$LIVE/pr50-touches.md" <<'P'
- **Touches:**
  - `subagent-lifecycle.sh`
  - `subagent-tool-logger.sh`
  - `references/executor-control-plane.md`
  - `hooks/tests/active-epic-fixtures.sh`
P

count_overlaps() { # $1, $2 = files of paths
  N=0
  while IFS= read -r A; do
    [ -n "$A" ] || continue
    while IFS= read -r B; do
      [ -n "$B" ] || continue
      same_declared_path "$A" "$B" && N=$((N + 1))
    done < "$2"
  done < "$1"
  printf '%s' "$N"
}
declared_paths < "$LIVE/pr25-touches.md" > "$LIVE/set25"
declared_paths < "$LIVE/pr26-touches.md" > "$LIVE/set26"
declared_paths < "$LIVE/pr50-touches.md" > "$LIVE/set50"

check "V: once declared, #25 <-> #50 still collide (hooks/tests/active-epic-fixtures.sh)" \
      "1" "$(count_overlaps "$LIVE/set25" "$LIVE/set50")"
check "V: once declared, #26 <-> #50 still collide — TWO files, long vs short spellings" \
      "2" "$(count_overlaps "$LIVE/set26" "$LIVE/set50")"
check "V: neither known false positive appears — #26 never declares subagent-lifecycle.sh" \
      "0" "$(grep -cx 'subagent-lifecycle.sh' "$LIVE/set26" | tr -d ' ')"
check "V: nor subagent-tool-logger.sh — so #26 <-> #50 cannot collide on either" "0" \
      "$(grep -cx 'subagent-tool-logger.sh' "$LIVE/set26" | tr -d ' ')"

echo
echo "=== Q. control flow and single definition ==============================="
check "Q: the enumeration jq is defined once"     "1" \
      "$(grep -c "^PROPOSAL_PR_JQ='" "$SCRIPT" | tr -d ' ')"
check "Q: the prose denylist is GONE, not dormant (epic 10 item 4 DoD)" "0" \
      "$(grep -c 'DECLARED_PATH_DENY_RE' "$SCRIPT" | tr -d ' ')"
check "Q: the prose tokeniser normalise_declared_paths() is GONE too" "0" \
      "$(grep -c 'normalise_declared_paths' "$SCRIPT" | tr -d ' ')"
DECLARED_PATHS_BODY="$(awk '/^declared_paths\(\) \{/,/^}/' "$SCRIPT")"
check "Q: declared_paths() itself reads Touches" "1" \
      "$(printf '%s' "$DECLARED_PATHS_BODY" | grep -c 'Touches')"
check "Q: and no longer mentions Scope at all" "0" \
      "$(printf '%s' "$DECLARED_PATHS_BODY" | grep -ci 'Scope')"
check "Q: the check is called exactly once"       "1" \
      "$(grep -c 'check_collisions "\$N"' "$SCRIPT" | tr -d ' ')"
check "Q: the proposal branch prefix is still ONE constant" "1" \
      "$(grep -c 'intake/proposed-' "$SCRIPT" | tr -d ' ')"
L_RECFILE="$(grep -n '^    REC_FILE=' "$SCRIPT" | head -1 | cut -d: -f1)"
L_CHECK="$(grep -n 'check_collisions "\$N"' "$SCRIPT" | head -1 | cut -d: -f1)"
L_TAG="$(grep -n '^    REC_TITLE_TAG=""' "$SCRIPT" | head -1 | cut -d: -f1)"
L_PUSH="$(grep -n 'push -q -u origin' "$SCRIPT" | head -1 | cut -d: -f1)"
L_CREATE="$(grep -n 'pr create --base' "$SCRIPT" | head -1 | cut -d: -f1)"
check "Q: the check runs AFTER the recommendation is read back" "yes" \
      "$(if [ "$L_RECFILE" -lt "$L_CHECK" ]; then echo yes; else echo no; fi)"
check "Q: and BEFORE the title tag consumes it" "yes" \
      "$(if [ "$L_CHECK" -lt "$L_TAG" ]; then echo yes; else echo no; fi)"
check "Q: and before the branch is pushed"      "yes" \
      "$(if [ "$L_CHECK" -lt "$L_PUSH" ]; then echo yes; else echo no; fi)"
check "Q: and before gh pr create"              "yes" \
      "$(if [ "$L_CHECK" -lt "$L_CREATE" ]; then echo yes; else echo no; fi)"
check "Q: the runner never edits a PR"          "0" \
      "$(grep -c 'pr edit' "$SCRIPT" | tr -d ' ')"
check "Q: the runner still never merges"        "0" \
      "$(grep -c 'pr merge' "$SCRIPT" | tr -d ' ')"
check "Q: the runner still never closes an issue" "0" \
      "$(grep -c 'issue close' "$SCRIPT" | tr -d ' ')"
check "Q: the only Recommendation value it writes is one of the three" "1" \
      "$(grep -c 'print "\*\*Recommendation:\*\* needs-decision"' "$SCRIPT" | tr -d ' ' | sed -e 's/^2$/1/')"

echo
echo "=== R. mutant: delete the downgrade and case A publishes at plan ========"
MUT_R="$SANDBOX/unattended-intake.no-downgrade.sh"; sandboxed "$MUT_R"
grep -vxF '          REC=needs-decision' "$SCRIPT" > "$MUT_R"
chmod +x "$MUT_R"
cmp -s "$SCRIPT" "$MUT_R" && {
  echo "ERROR: the no-downgrade mutant is identical to the script — the" >&2
  echo "       downgrade line moved, so case R proves nothing. Fix the grep." >&2
  exit 1; }
/bin/bash -n "$MUT_R" || { echo "ERROR: mutant R does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUT_R"
D="$(mkcase R)"
set_issues "$D" 90
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "R: without the downgrade the PR title says nothing" "plan" "$(title_rec "$D")"
check "R: and it is not just broken — it still detected the overlap" "yes" \
      "$(yesno grep -q '#90: collision ->' "$D/stdout.log")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== S. mutant: delete suffix matching and case D stops colliding ========"
MUT_S="$SANDBOX/unattended-intake.exact-match.sh"; sandboxed "$MUT_S"
grep -vxF '  case "$1" in */"$2") return 0 ;; esac' "$SCRIPT" \
  | grep -vxF '  case "$2" in */"$1") return 0 ;; esac' > "$MUT_S"
chmod +x "$MUT_S"
cmp -s "$SCRIPT" "$MUT_S" && {
  echo "ERROR: the exact-match mutant is identical to the script — suffix" >&2
  echo "       matching moved, so case S proves nothing. Fix the grep." >&2
  exit 1; }
/bin/bash -n "$MUT_S" || { echo "ERROR: mutant S does not parse" >&2; exit 1; }
SCRIPT_UNDER_TEST="$MUT_S"
D="$(mkcase S)"
set_issues "$D" 92
cp "$PLANS/short-path.md" "$D/draft.md"
open_proposal "$D" 78 "intake/proposed-78-long" "$PLANS/long-path.md"
RC="$(run_intake "$D")"
check "S: exact matching misses the long/short pair entirely" "plan" "$(title_rec "$D")"
D="$(mkcase S2)"
set_issues "$D" 90
cp "$PLANS/alpha-twin.md" "$D/draft.md"
open_proposal "$D" 77 "intake/proposed-77-alpha" "$PLANS/alpha.md"
RC="$(run_intake "$D")"
check "S: but it still catches identical strings, so it is not just broken" \
      "needs-decision" "$(title_rec "$D")"
SCRIPT_UNDER_TEST="$SCRIPT"

echo
echo "=== sandbox discipline (GH #15) ========================================"
ESCAPES="$(grep -l 'STUB REFUSED' "$SANDBOX"/*/calls.log 2>/dev/null | head -3)"
check "no stub ever had to refuse a git or gh mutation" "" "$ESCAPES"
# The item-1 lesson, enforced rather than remembered. This item adds TWO new gh
# queries — `pr list` and `contents`. A stub that answered either with silence
# would report "no collision" for every case above while testing nothing.
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
