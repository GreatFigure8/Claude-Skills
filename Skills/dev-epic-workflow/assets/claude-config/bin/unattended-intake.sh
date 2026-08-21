#!/usr/bin/env bash
# Unattended intake runner — dev-epic-workflow Tier 2.
#
# Turns issues labelled `claude-intake` into PROPOSAL pull requests carrying an
# epic plan at `**Status:** planning`. It runs Phase 0 grounding and Phase 1
# drafting headlessly, and then stops. The contract it enforces lives in
# references/issue-intake.md; the hard stops, restated because this is the file
# that could violate them:
#
#   never approves · never dispatches an executor · never writes code
#   never merges · never closes an issue
#
# Approval stays human: Jonathan merges the PR and sets `Status: approved`.
#
# Auth: a subscription-backed CLAUDE_CODE_OAUTH_TOKEN (`claude setup-token`),
# read from a 0600 file OUTSIDE any repo. Never the Keychain, never an API key.
# The token is sourced into the environment and passed to `claude` that way —
# never as an argument (argv is world-readable via ps) and never logged.
#
# Usage:
#   unattended-intake.sh [--dry-run] [--issue N] [--repo owner/name] [--once]
#
#   --dry-run   report what would happen; mutate nothing, anywhere
#   --issue N   process only this issue (still requires the label unless --force-issue)
#   --force-issue  with --issue, skip the label check (for exercising the mechanism)
#   --repo      override repo detection
#
# Exit codes: 0 ok (including "nothing to do") · 1 usage/config · 2 lock held
#             3 credential problem · 4 one or more issues failed

set -u

# ---------------------------------------------------------------- environment
# launchd gives a minimal PATH, so resolve everything explicitly. Overridable
# for testing, but defaulted to absolute paths that exist on this machine.
GIT_BIN="${INTAKE_GIT:-/usr/bin/git}"
GH_BIN="${INTAKE_GH:-/opt/homebrew/bin/gh}"
CLAUDE_BIN="${INTAKE_CLAUDE:-$HOME/.local/bin/claude}"

# The agent must be told exactly where its own contract is. This script lives at
# <skill>/assets/claude-config/bin/, so the skill root is three levels up — true
# for both the in-repo copy launchd runs and an install.sh --user copy. Without
# an absolute path the agent hunts for the reference and escalates to `find /`,
# which walks TCC-protected directories and prompts a run nobody is watching
# (GH #34).
SKILL_DIR="${INTAKE_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

ENV_FILE="${INTAKE_ENV_FILE:-$HOME/.config/claude-intake/env}"
REPO_DIR="${INTAKE_REPO_DIR:-$HOME/Source/claude-skills}"   # fallback when no list
REPO_LIST="${INTAKE_REPO_LIST:-$HOME/.config/claude-intake/repos}"
LOG_FILE="${INTAKE_LOG:-$HOME/.config/claude-intake/intake.log}"
LOCK_DIR="${INTAKE_LOCK:-$HOME/.config/claude-intake/.lock}"
LABEL="${INTAKE_LABEL:-claude-intake}"

# The branch prefix every proposal this runner opens is cut on. It is also how
# the work-in-progress check below recognises the runner's OWN pull requests:
# attended and unattended work run as the same GitHub account, so the actor
# says nothing useful and the branch name is the only honest signal.
PROPOSAL_BRANCH_PREFIX="${INTAKE_PROPOSAL_PREFIX:-intake/proposed-}"

# How "a pull request mentions this issue" is asked of GitHub. The issue
# timeline is the same thing GitHub renders under the issue itself, and a
# cross-reference is recorded whether the mention came from the PR body or from
# a comment on it. `.source.issue.pull_request` is present only when the
# referring item is a PR, which is what separates a PR reference from a plain
# issue-to-issue mention.
#
# This is the CANDIDATE list, not the answer. A cross-reference is only a
# mention, and a mention is not a claim that the issue is being worked — see
# CLOSING_KEYWORD_RE below for the narrowing that turns a candidate into a
# blocker.
TIMELINE_PR_JQ='.[] | select(.event == "cross-referenced") | select(.source.issue.pull_request != null) | .source.issue.number'

# What is read back about each candidate PR, in ONE call. jq emits the field
# line FIRST and the body AFTER it, so newlines in the body cannot corrupt the
# fields and an empty body is simply no further lines. The closing-issue list
# is fenced in commas (`,41,`, or `,` alone when empty) so membership is one
# glob match and `41` can never match `410`.
PR_VIEW_JQ='"\(.state) \(.headRefName) \(.url) ,\((((.closingIssuesReferences // []) | map(.number|tostring)) | join(",")))," ,(.body // "")'

# The narrowing (epic 09 item 6). Item 3 blocked an issue on ANY cross-reference
# from a PR, which is far broader than "this issue is being worked": measured
# cold on this repo, four of four open issues were blocked by a passing mention,
# and one of them (#48) was blocked by the very PR whose body recorded that #48
# was clear. The PR documenting that an issue is draftable made it undraftable.
#
# So a PR blocks only when it DECLARES that it resolves the issue. Two signals,
# in order of authority:
#
#   1. `closingIssuesReferences` — GitHub's own closing link, authoritative
#      when it is there.
#   2. this regex over the PR description — the documented fallback, and it is
#      not an edge case. Measured 2026-08-20: GitHub records a closing link
#      only for a PR whose base is the repository's DEFAULT branch. LODE
#      integrates on `dev`, so all 25 of its most recent PRs report
#      `closingIssuesReferences: []` — including #758, whose body ends
#      "Closes #757" and which is the exact race this whole check exists for.
#      Without the fallback the one true positive we have stops being detected.
#
# The keyword list is GitHub's own (close/closes/closed, fix/fixes/fixed,
# resolve/resolves/resolved). The leading guard stops `prefixes #12` matching;
# the caller appends the issue number and a trailing non-digit guard so `#12`
# cannot match `#120`.
CLOSING_KEYWORD_RE='(^|[^[:alnum:]_])(clos(e|es|ed)|fix(es|ed)?|resolv(e|es|ed))[[:space:]]*:?[[:space:]]*#'

# THE WIDENING (epic 09 item 7). Item 6's narrowing above is the right rule for
# ALREADY DONE and is left exactly as it is. It is the wrong rule for ALREADY IN
# FLIGHT: a multi-item epic's pull requests say `Part of #<n>` BY DESIGN and
# deliberately declare no closure until the final item, so an issue whose epic is
# halfway delivered reads as clear and the runner drafts a second proposal over
# live work. Measured across both repos on 2026-08-21 (n=11 open issues): LODE
# #811 had an open PR, a merged PR and a branch named for it, and the runner
# would have drafted over all three. So two further signals sit BESIDE the
# closing-linkage one — never replacing it, because the remedy differs. Already
# done means close the issue. Already in flight means wait.
#
# (b) A PR whose description declares it is part of the issue's work. The string
#     is not a guess: references/issue-intake.md makes `Part of #<n>` THE linkage
#     a work-item PR carries, with `Closes #<n>` reserved for an epic's final
#     item — which is exactly why the closing signal cannot see an epic midway.
#     Same guards as CLOSING_KEYWORD_RE: a leading non-word guard so `apart of`
#     does not match, and the caller appends the number and a non-digit guard.
PART_OF_RE='(^|[^[:alnum:]_])part[[:space:]]+of[[:space:]]*:?[[:space:]]*#'

# (c) A branch on `origin` named for the issue — `<anything>/<issue>-<anything>`,
#     the shape references/git-conventions.md produces and the shape every
#     measured in-flight branch had (`feat/811-reconcile-claim-against-ledger`,
#     `fix/581-empty-database-list`, `docs/110-wi3-outcome`). It is asked of
#     GitHub rather than of `git ls-remote` because REPO_SLUG and REPO_DIR are
#     not always the same repository (`--repo` overrides the slug for every
#     entry), and because a local checkout's remote refs are only as fresh as
#     its last fetch. One call, one field.
BRANCH_LIST_JQ='.[].name'

# ---------------------------------------------- THE DECLARATION (epic 09 item 8)
# Signals (a), (b) and (c) above all INFER what a human already wrote down.
# references/issue-intake.md's linking contract has required, since long before
# any of them existed, that the tracker item be labelled when an epic is filed
# for it:
#
#   Plan filed (Phase 1 approval)  ->  label `epic:planned`
#   First dispatch (Phase 3)       ->  label `epic:in-progress` (replaces it)
#
# and this runner read no label but its own `claude-intake` trigger. Read from
# LODE #757's own timeline rather than reasoned about: `epic:planned` was applied
# at 19:54:21Z, `epic:in-progress` at 19:54:26Z, and this runner selected the
# issue at 20:02:46Z — 8m25s later, and four minutes before the competing PR
# #758 was opened at all. One label read would have prevented the founding race
# before any of the three inferred signals had anything to see.
#
# So the label is asked FIRST and short-circuits: no timeline query, no per-PR
# reads, no branch listing. A declaration outranks an inference.
#
# The other three signals are DEMOTED, never deleted, and the reason is measured
# rather than tidy. A label is a declaration and depends on human discipline; a
# merged closing PR is evidence and does not. This repo is the proof discipline
# fails — GH #39 went through six merged work items of the epic it is the Source
# of carrying no label at all, while LODE was 8 of 8 correct. Closing linkage
# also covers attended work that never becomes an epic and so never earns a
# label. Precedence, not replacement.
#
# Space-separated because it is iterated, and matched against a comma-FENCED
# label list so `epic:planned` can never match `epic:planned-later`.
EPIC_STATE_LABELS="${INTAKE_EPIC_LABELS:-epic:planned epic:in-progress}"

# What is read back about the selected issue, in ONE call — the same call that
# already fetched the title for the log line, so the label signal costs no extra
# API request at selection. Same two-part shape as PR_VIEW_JQ and for the same
# reason: the fenced single-line field comes FIRST so a title containing a
# newline cannot corrupt it, and the title is whatever follows.
ISSUE_VIEW_JQ='",\((((.labels // []) | map(.name)) | join(","))),"  ,(.title // "")'

# How many lines of a drafted plan count as its header. The SAME window the
# SessionStart hook uses (session-start-context.sh: EPIC_QUEUE_HEADER_LINES), so
# the runner and the injection can never disagree about what the header said.
PLAN_HEADER_LINES=10

# ------------------------------------------------ collision detection (item 4)
# How the OPEN proposals of a repo are enumerated. Only two fields are needed:
# the PR number, and the head branch — which carries BOTH the counterpart issue
# number (the digits after the prefix) and the path of its plan
# (<EPICS_DIR>/proposed-<rest>/plan.md). One list call answers the whole
# question, and the runner's own PROPOSAL_BRANCH_PREFIX is what identifies a
# proposal, so detection can never drift from construction.
PROPOSAL_PR_JQ='.[] | "\(.number) \(.headRefName)"'

# Tokens that are the SHAPE of a plan rather than the subject of one. `plan.md`,
# `status/` and `docs/epics/` appear as Scope tokens in live proposals (PR #50
# declares all three), and under the suffix matching below they would collide
# universally — every proposal against every other, forever. That is not high
# recall, it is no signal at all, so they are excluded. Exactly the three the
# epic 09 plan names, and no others invented here.
#
# Matched case-INSENSITIVELY on purpose: the epics directory's casing is a
# per-repo fact this runner already has to ask about rather than assert
# (docs/epics here, DOCS/EPICS on Oracle-Simple-Convert).
DECLARED_PATH_DENY_RE='^(plan\.md|status|docs/epics)$'
# The ONE directory this runner may create anything in. Not "wherever the repo
# happens to live" — an unattended process on a timer should have a filesystem
# footprint you can verify by reading a single line.
WORKTREE_ROOT="${INTAKE_WORKTREE_ROOT:-$HOME/Source}"

DRY_RUN=no
ONLY_ISSUE=""
FORCE_ISSUE=no
REPO_OVERRIDE=""

# ---------------------------------------------------------------------- args
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=yes ;;
    --issue) ONLY_ISSUE="${2:-}"; shift ;;
    --force-issue) FORCE_ISSUE=yes ;;
    --repo) REPO_OVERRIDE="${2:-}"; shift ;;
    --once) : ;;                        # accepted, single-pass is the only mode
    -h|--help) sed -n '1,30p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

# ------------------------------------------------------------------- logging
# Redaction is not optional: anything token-shaped is scrubbed before it can
# reach the log, whether it came from us or from a subprocess's error text.
redact() {
  sed -E -e 's/(sk-ant-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]+/\1[REDACTED]/g' \
         -e 's/(CLAUDE_CODE_OAUTH_TOKEN=)[^[:space:]]+/\1[REDACTED]/g' \
         -e 's/(ANTHROPIC_API_KEY=)[^[:space:]]+/\1[REDACTED]/g'
}

log() {
  MSG="$(printf '%s | %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | redact)"
  printf '%s\n' "$MSG"
  [ "$DRY_RUN" = yes ] || printf '%s\n' "$MSG" >> "$LOG_FILE" 2>/dev/null || true
}

die() { log "FATAL: $*"; exit "${2:-1}"; }

# --------------------------------------------------------------- preflight
for B in "$GIT_BIN" "$GH_BIN" "$CLAUDE_BIN"; do
  [ -x "$B" ] || die "not executable: $B (launchd has a minimal PATH; set INTAKE_GIT/INTAKE_GH/INTAKE_CLAUDE)" 1
done

# The prompt hands the agent these two paths as fact. If they are wrong the agent
# has no contract to read and starts searching the disk, so fail here instead.
for R in issue-intake plan-template; do
  [ -f "$SKILL_DIR/references/$R.md" ] || die "skill reference missing: $SKILL_DIR/references/$R.md (set INTAKE_SKILL_DIR to the dev-epic-workflow skill root)" 1
done

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Credential: must exist, be non-empty, and be no looser than 0600. A loose
# credential file is a hard stop, not a warning — the whole point of moving off
# the Keychain was to be deliberate about this one file.
[ -f "$ENV_FILE" ] || die "credential file missing: $ENV_FILE — run 'claude setup-token' and put CLAUDE_CODE_OAUTH_TOKEN=... in it (chmod 600)" 3
PERMS="$(stat -f '%Lp' "$ENV_FILE" 2>/dev/null || echo '???')"
case "$PERMS" in
  600|400) ;;
  *) die "credential file $ENV_FILE has mode $PERMS; require 600 (chmod 600 '$ENV_FILE')" 3 ;;
esac

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || die "could not source $ENV_FILE" 3
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || die "CLAUDE_CODE_OAUTH_TOKEN is empty in $ENV_FILE — run 'claude setup-token'" 3
export CLAUDE_CODE_OAUTH_TOKEN

# ------------------------------------------------------------------- locking
# mkdir is atomic on every filesystem we care about; no flock dependency.
if [ "$DRY_RUN" = no ]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "another run holds the lock ($LOCK_DIR) — exiting"
    exit 2
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
fi

# --------------------------------------------------------------------- repos
# Repos join the poller by being LISTED, never by existing on disk — the same
# opt-in principle the claude-intake label uses at the issue level. A missing or
# empty list falls back to the single-repo default, so an existing setup keeps
# working untouched.
REPOS=""
if [ -f "$REPO_LIST" ] && [ -r "$REPO_LIST" ]; then
  while IFS= read -r RLINE || [ -n "$RLINE" ]; do
    RLINE="${RLINE%"${RLINE##*[![:space:]]}"}"
    RLINE="${RLINE#"${RLINE%%[![:space:]]*}"}"
    case "$RLINE" in ''|'#'*) continue ;; esac
    case "$RLINE" in '~'*) RLINE="$HOME${RLINE#\~}" ;; esac
    REPOS="$REPOS
$RLINE"
  done < "$REPO_LIST"
fi
if [ -z "$(printf '%s' "$REPOS" | tr -d '[:space:]')" ]; then
  REPOS="$REPO_DIR"
  log "no repo list at $REPO_LIST — falling back to $REPO_DIR"
fi

log "unattended intake starting — label=$LABEL dry-run=$DRY_RUN repos=$(printf '%s' "$REPOS" | grep -c . )"

FAILED=0

# ------------------------------------------------ collision detection (item 4)
# Two proposals that would edit the same file are a HUMAN DECISION, and this is
# where that is noticed. LODE #732 and #733 each worked out for themselves that
# they targeted the same `except` blocks in the same file, and each escalated —
# which is the behaviour this replaces, because it is not a mechanism, it is two
# drafters happening to be conscientious on the same afternoon.
#
# WHAT COUNTS AS A DECLARATION, and this is the whole difficulty:
#
#   * `**Scope:**` blocks ONLY. Including `**Not in scope:**` manufactures a
#     false positive on the first real pair we have: PR #25's *Not in scope*
#     names `cancel-gate.sh`, which PR #26's *Scope* declares. "The tempting
#     adjacent thing this deliberately skips" is the opposite of a declaration.
#
#   * SUFFIX MATCHING at path-component boundaries, not exact strings and not
#     basenames. Measured on the live proposals: PR #26 writes
#     `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
#     where PR #50 writes `hooks/tests/active-epic-fixtures.sh` for the same
#     file, so exact matching misses the pair entirely. Basename-only is the
#     opposite error and collides everything on `plan.md`.
#
#   * RECALL OVER PRECISION, chosen deliberately and measured both ways on the
#     five live proposals before being written down:
#       - reading every path-like token in a Scope block finds all three real
#         pairs (25<->26, 25<->50, 26<->50) and the LODE 730<->731 pair;
#       - restricting to the token that LEADS a Scope bullet removes the two
#         known false positives but drops 25<->50 to ZERO overlaps, losing a
#         genuine shared file, because PR #25's declaration is a comma list
#         wrapped across two lines.
#     The cost of recall is stated rather than hidden: a mention is not a
#     declaration, and PR #26's Scope names `subagent-lifecycle.sh` and
#     `subagent-tool-logger.sh` only as files it compares AGAINST — its own
#     *Not in scope* says so — yet they are reported. Measured, that noise never
#     changed a verdict (#26 and #50 already collide truly on two other paths);
#     it only adds names to a report a human is reading anyway. A missed
#     collision costs two epics editing one file; a spare path name costs a
#     reader ten seconds. The structured declaration field that would delete
#     this heuristic outright is parked in the epic's Deferred list.
#
# Sets, for the caller:
#   COLLISION_STATUS   clear | collided | undeclared | unknown
#   COLLISION_SUMMARY  one line, for the log and the PR heading
#   COLLISION_DETAIL   markdown naming each counterpart PR and the shared paths
#   COLLISION_PARTNERS one "<pr> <issue>" line per colliding counterpart, so the
#                      caller can annotate the other side BY COMMENT. The
#                      counterpart proposal is never rewritten: an open PR is
#                      not edited from under a reviewer.
#
# `unknown` (the enumeration query itself failed) publishes anyway and says so,
# exactly as the work-in-progress check does: a GitHub blip must not stop a
# runner that worked yesterday. `undeclared` — the proposal names no files at
# all — does NOT pass silently; it is colliding-unknown and returns the same
# needs-decision, because an empty declaration is the one case where overlap
# cannot be ruled out.
#
# REPO_SLUG and EPICS_DIR are read at call time from the repo loop below, the
# same way the work-in-progress helper defined inside that loop reads REPO_SLUG.
COLLISION_STATUS=""
COLLISION_SUMMARY=""
COLLISION_DETAIL=""
COLLISION_PARTNERS=""

# One candidate token per line on stdin -> the ones that are plausibly a path,
# normalised. The two structural tests, and why prose fails them:
#   a trailing `/` in the raw token  -> an explicit directory (`hooks/lib/`)
#   a leaf of <stem>.<ext>           -> a file (`lookups.py`, `cancel-gate.sh`)
# with stem >= 2 characters and ext 1-6 starting with a letter. That is what
# keeps `and/or`, `e.g.`, `i.e.` and `4.5` out — every one of which appears in a
# real Scope block, and any of which would otherwise collide two proposals that
# share nothing but English.
normalise_declared_paths() {
  while IFS= read -r TOK; do
    [ -n "$TOK" ] || continue
    case "$TOK" in *[A-Za-z]*) ;; *) continue ;; esac
    DIRISH=no
    case "$TOK" in */) DIRISH=yes ;; esac
    while :; do
      case "$TOK" in
        */) TOK="${TOK%/}" ;;
        *.) TOK="${TOK%.}" ;;
        *)  break ;;
      esac
    done
    TOK="${TOK#./}"
    [ -n "$TOK" ] || continue
    if [ "$DIRISH" = yes ]; then printf '%s\n' "$TOK"; continue; fi
    LEAF="${TOK##*/}"
    case "$LEAF" in *.*) ;; *) continue ;; esac
    STEM="${LEAF%.*}"
    EXT="${LEAF##*.}"
    case "$STEM" in ''|?) continue ;; esac
    case "$EXT" in
      [A-Za-z] \
      |[A-Za-z][A-Za-z0-9] \
      |[A-Za-z][A-Za-z0-9][A-Za-z0-9] \
      |[A-Za-z][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9] \
      |[A-Za-z][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9] \
      |[A-Za-z][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]) ;;
      *) continue ;;
    esac
    printf '%s\n' "$TOK"
  done
}

# A plan.md on stdin -> the files and modules it DECLARES, one per line, sorted.
# The awk reads `**Scope:**` and its indented continuation lines, and stops at
# the next `- **Field:**` bullet — which is how `**Not in scope:**` is excluded
# without needing to name it. Backticks become separators before tokenising, so
# `mkrepo`/`mkorch` is two identifiers and not one path.
declared_paths() {
  awk '
    BEGIN { in_scope = 0 }
    {
      if (match($0, /^[[:space:]]*[-*][[:space:]]+\*\*[Ss]cope:\*\*/)) {
        in_scope = 1
        print substr($0, RSTART + RLENGTH)
        next
      }
      if (!in_scope) next
      if (match($0, /^[[:space:]]*[-*][[:space:]]+\*\*[^*]+:\*\*/)) { in_scope = 0; next }
      if ($0 ~ /^[[:space:]]*$/)     { in_scope = 0; next }
      if ($0 ~ /^#/)                 { in_scope = 0; next }
      if ($0 ~ /^[^[:space:]]/)      { in_scope = 0; next }
      print
    }' 2>/dev/null \
    | sed -e 's/`/ /g' -e 's![^A-Za-z0-9._/*$-]! !g' \
    | tr ' ' '\n' \
    | normalise_declared_paths \
    | grep -vEi "$DECLARED_PATH_DENY_RE" \
    | sort -u
}

# Do two declared paths name the same file? Equal, or one is a suffix of the
# other AT A PATH-COMPONENT BOUNDARY — so `hooks/tests/x.sh` matches `x.sh` but
# `cancel-gate.sh` never matches `gate.sh`.
same_declared_path() { # $1, $2 = normalised paths
  [ "$1" = "$2" ] && return 0
  case "$1" in */"$2") return 0 ;; esac
  case "$2" in */"$1") return 0 ;; esac
  return 1
}

# Write the downgrade into the PROPOSAL ITSELF. The runner's in-memory REC is
# not enough and this is not a detail: `session-start-context.sh` buckets a
# proposal by reading `**Recommendation:**` out of the first
# EPIC_QUEUE_HEADER_LINES lines of the plan.md on disk, so unless the FILE says
# needs-decision the proposal keeps rendering under *awaiting approval* — where
# it can be approved without the collision ever being registered, which is the
# exact failure the downgrade exists to prevent.
#
# The header field may be absent (it reads as `plan`, and such a proposal can
# still collide), so there are two cases: substitute the first Recommendation
# line inside the header window, or insert one directly under Status.
#
# This writes inside <EPICS_DIR>/proposed-<n>-<slug>/ and nowhere else — the one
# directory this runner may create anything in, and the same one the hard stop
# is written in terms of.
#   $1 = plan file
# Returns non-zero if the rewrite did not land, and the caller treats that as a
# failure rather than publishing a PR whose title and header disagree.
downgrade_plan_recommendation() { # $1 = plan file
  DPR_TMP="$1.intake-downgrade.$$"
  if head -"$PLAN_HEADER_LINES" "$1" 2>/dev/null | grep -qiE '^[[:space:]*_]*recommendation:'; then
    awk -v lim="$PLAN_HEADER_LINES" '
      function bare(s) { gsub(/^[ \t*_]+/, "", s); return tolower(s) }
      !done && NR <= lim && bare($0) ~ /^recommendation:/ {
        print "**Recommendation:** needs-decision"; done = 1; next
      }
      { print }
    ' "$1" > "$DPR_TMP" 2>/dev/null || { rm -f "$DPR_TMP"; return 1; }
  else
    awk -v lim="$PLAN_HEADER_LINES" '
      function bare(s) { gsub(/^[ \t*_]+/, "", s); return tolower(s) }
      { print }
      !done && NR <= lim && bare($0) ~ /^status:/ {
        print "**Recommendation:** needs-decision"; done = 1
      }
      END { if (!done) exit 3 }
    ' "$1" > "$DPR_TMP" 2>/dev/null || { rm -f "$DPR_TMP"; return 1; }
  fi
  [ -s "$DPR_TMP" ] || { rm -f "$DPR_TMP"; return 1; }
  mv "$DPR_TMP" "$1" 2>/dev/null || { rm -f "$DPR_TMP"; return 1; }
  head -"$PLAN_HEADER_LINES" "$1" 2>/dev/null \
    | grep -qiE '^[[:space:]*_]*recommendation:[[:space:]*_]*needs-decision' || return 1
  return 0
}

# The collision goes in the plan BODY too, not only in the PR — the plan is the
# artifact that survives, and six months from now the PR conversation is not
# what anyone reads. It is inserted directly under the header block, before the
# first `## ` section, because a decision buried under two hundred lines of
# Grounding is a decision nobody makes. If the plan has no section heading at
# all it is appended, which is never wrong, only less prominent.
#   $1 = plan file, $2 = the markdown block to insert
insert_plan_collision_section() {
  IPC_TMP="$1.intake-collision.$$"
  awk -v blockfile="$2" '
    BEGIN { while ((getline l < blockfile) > 0) block = block l "\n" }
    !done && /^## / { printf "%s", block; done = 1 }
    { print }
    END { if (!done) printf "%s", block }
  ' "$1" > "$IPC_TMP" 2>/dev/null || { rm -f "$IPC_TMP"; return 1; }
  [ -s "$IPC_TMP" ] || { rm -f "$IPC_TMP"; return 1; }
  mv "$IPC_TMP" "$1" 2>/dev/null || { rm -f "$IPC_TMP"; return 1; }
  return 0
}

check_collisions() { # $1 = issue number, $2 = the fresh draft's plan.md, $3 = its branch
  COLLISION_STATUS=clear
  COLLISION_SUMMARY=""
  COLLISION_DETAIL=""
  COLLISION_PARTNERS=""

  # Our own plan must be readable before anything can be said about it. If the
  # drafter produced no file, that is a failed READ, not an empty declaration —
  # `unknown`, published loudly, never a downgrade of a plan that is not there.
  if [ ! -r "$2" ]; then
    COLLISION_STATUS=unknown
    # Worded so it cannot be confused with the work-in-progress check's own
    # fallback: two subsystems both logging "could not run" into one stream is
    # ambiguous to a reader, and item 7's suite greps for that exact phrase to
    # prove ITS check did not degrade.
    log "WARN #$1: no readable plan at $2 — collision detection did not run, nothing was compared"
    return 0
  fi

  if ! OPEN_PROPOSALS="$("$GH_BIN" pr list --repo "$REPO_SLUG" --state open --limit 100 \
        --json number,headRefName -q "$PROPOSAL_PR_JQ" 2>/dev/null)"; then
    COLLISION_STATUS=unknown
    return 0
  fi

  # WHO could this collide with, decided BEFORE what it declares. Order matters
  # and getting it wrong is not academic: deciding `undeclared` first made a
  # proposal with no Scope block collide with an empty world, which downgraded
  # every draft in a repo that has no open proposals at all. There is nothing to
  # rule out when there is nothing to rule it out against.
  CANDIDATES=""
  while IFS=' ' read -r CPR CHEAD; do
    case "${CPR:-}" in ''|*[!0-9]*) continue ;; esac
    [ -n "${CHEAD:-}" ] || continue
    # A proposal is what this runner's own prefix says it is. Attended proposals
    # on `docs/intake-<NN>-<slug>` are invisible here; that gap is real, small,
    # and parked in the epic's Deferred list rather than guessed at.
    case "$CHEAD" in "$PROPOSAL_BRANCH_PREFIX"*) ;; *) continue ;; esac
    [ "$CHEAD" = "$3" ] && continue
    CANDIDATES="$CANDIDATES
$CPR $CHEAD"
  done <<ALLOPEN
$OPEN_PROPOSALS
ALLOPEN
  CANDIDATES="${CANDIDATES#
}"
  if [ -z "$CANDIDATES" ]; then
    return 0                       # COLLISION_STATUS is already `clear`
  fi

  CANDIDATE_COUNT="$(printf '%s\n' "$CANDIDATES" | grep -c . )"
  MINE="$(declared_paths < "$2" 2>/dev/null)"
  if [ -z "$MINE" ]; then
    # Colliding-unknown, and only now that a counterpart actually exists. An
    # empty declaration is not evidence of no overlap — see the epic's Risks
    # table, which chose this over passing silently.
    COLLISION_STATUS=undeclared
    COLLISION_SUMMARY="this proposal declares no files or modules in any Scope block, so an overlap with the $CANDIDATE_COUNT other open proposal(s) cannot be ruled out"
    COLLISION_DETAIL="  - No \`**Scope:**\` block in this plan names a file or a module, so there was nothing to compare against the $CANDIDATE_COUNT other open proposal(s) in this repository. An empty declaration is not evidence of no overlap."
    return 0
  fi

  COLLIDED_WITH=0
  while IFS=' ' read -r CPR CHEAD; do
    [ -n "${CPR:-}" ] || continue
    CREST="${CHEAD#"$PROPOSAL_BRANCH_PREFIX"}"
    CISSUE="${CREST%%-*}"
    case "$CISSUE" in ''|*[!0-9]*) CISSUE="?" ;; esac
    CPLAN="$EPICS_DIR/proposed-$CREST/plan.md"
    if ! CTEXT="$("$GH_BIN" api "repos/$REPO_SLUG/contents/$CPLAN?ref=$CHEAD" \
                    -H "Accept: application/vnd.github.raw" 2>/dev/null)"; then
      # Named, not swallowed. One unreadable counterpart is a query failure, the
      # same class as the timeline blip above, so it does not by itself force a
      # decision — but it is never silent.
      log "WARN #$1: could not read the plan of open proposal PR #$CPR ($CPLAN@$CHEAD) — its declared files were not compared"
      continue
    fi
    THEIRS="$(printf '%s\n' "$CTEXT" | declared_paths)"
    [ -n "$THEIRS" ] || {
      log "WARN #$1: open proposal PR #$CPR declares no files in any Scope block — no comparison was possible"
      continue
    }
    HITS=""
    while IFS= read -r MP; do
      [ -n "$MP" ] || continue
      while IFS= read -r TP; do
        [ -n "$TP" ] || continue
        same_declared_path "$MP" "$TP" || continue
        # Report the SHORTER form: it is the common suffix, i.e. the file both
        # plans are actually naming.
        if [ "${#MP}" -le "${#TP}" ]; then HITS="$HITS $MP"; else HITS="$HITS $TP"; fi
      done <<THEIRPATHS
$THEIRS
THEIRPATHS
    done <<MYPATHS
$MINE
MYPATHS
    [ -n "$HITS" ] || continue
    HITS="$(printf '%s\n' $HITS | sort -u | tr '\n' ' ')"
    HITS="${HITS%"${HITS##*[![:space:]]}"}"
    COLLIDED_WITH=$((COLLIDED_WITH + 1))
    COLLISION_PARTNERS="$COLLISION_PARTNERS
$CPR $CISSUE $HITS"
    CLIST=""
    for H in $HITS; do CLIST="$CLIST \`$H\`,"; done
    CLIST="${CLIST% ,}"; CLIST="${CLIST%,}"
    COLLISION_DETAIL="$COLLISION_DETAIL
  - **PR #$CPR** (the open proposal for #$CISSUE, branch \`$CHEAD\`) declares:$CLIST"
  done <<PROPOSALS
$CANDIDATES
PROPOSALS

  if [ "$COLLIDED_WITH" -gt 0 ]; then
    COLLISION_STATUS=collided
    if [ "$COLLIDED_WITH" = 1 ]; then
      COLLISION_SUMMARY="1 other open proposal declares a file this one declares"
    else
      COLLISION_SUMMARY="$COLLIDED_WITH other open proposals declare a file this one declares"
    fi
    COLLISION_DETAIL="${COLLISION_DETAIL#
}"
  fi
  return 0
}


# Each repo is processed in full isolation: its own label check, its own issue
# list, its own epic folder and worktrees. One repo failing is logged and
# skipped — it must never stop the others. The lock is held across the WHOLE
# run, not per repo, so two repos are never processed concurrently.
while IFS= read -r RENTRY; do
  [ -n "$RENTRY" ] || continue
  # "<path>" or "<path>|<base-branch>". Split on the LAST pipe: checkout paths
  # here contain spaces, so whitespace is not a safe separator.
  case "$RENTRY" in
    *\|*) REPO_DIR="${RENTRY%|*}"; BASE_OVERRIDE="${RENTRY##*|}" ;;
    *)     REPO_DIR="$RENTRY";      BASE_OVERRIDE="" ;;
  esac
  REPO_DIR="${REPO_DIR%"${REPO_DIR##*[![:space:]]}"}"
  BASE_OVERRIDE="${BASE_OVERRIDE#"${BASE_OVERRIDE%%[![:space:]]*}"}"
  BASE_OVERRIDE="${BASE_OVERRIDE%"${BASE_OVERRIDE##*[![:space:]]}"}"
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "skip: not a git repo -> $REPO_DIR"
    continue
  fi
  cd "$REPO_DIR" || { log "skip: cannot cd -> $REPO_DIR"; continue; }
  REPO_SLUG="${REPO_OVERRIDE:-$("$GH_BIN" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)}"
  if [ -z "$REPO_SLUG" ]; then
    log "skip: no GitHub remote (or gh unauthenticated) -> $REPO_DIR"
    continue
  fi
  # TWO branch facts per repo, and they are not the same fact:
  #
  #   LIVE_BRANCH  the branch that must keep working — GitHub's default branch
  #   BASE_BRANCH  the INTEGRATION branch: what work items merge into, and the
  #                base of every PR this runner opens
  #
  # This repo has both on main; LODE is live on main and integrates on dev. An
  # explicit base in the repos list sets the integration branch; the GitHub
  # default is only its fallback. Never assume 'main' for either.
  #
  # The default-branch query is UNCONDITIONAL, and that is the whole of epic 09
  # item 2. It used to live in the `else` arm below, so a repo carrying a
  # `|base` override — exactly LODE's shape — never resolved its live branch at
  # all. Both values are handed to the drafter as stated facts in the prompt,
  # because a drafter filling them in from recall got them wrong on 2 of 7
  # proposals: LODE #741 and #739 both declared `**Live branch:** dev`, which is
  # LODE's INTEGRATION branch.
  #
  # Initialised before use rather than trusted to be assigned below. These are
  # loop variables in a `set -u` script, and the failure mode this whole block
  # exists to remove is a header value that came from somewhere other than this
  # repo — so no path through here may leave either of them carrying one.
  LIVE_BRANCH=""
  DEFAULT_BRANCH=""
  DEFAULT_BRANCH="$("$GH_BIN" repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)"
  case "$DEFAULT_BRANCH" in
    ''|null)
      # Unavailable is itself a fact, and it is passed on as one. `unknown` in a
      # plan header is a question a human answers in seconds; a plausible wrong
      # branch reads as correct and survives review — which is how this defect
      # reached production twice. The reason is logged so it is never silent.
      LIVE_BRANCH=unknown
      log "WARN: could not resolve the live (default) branch for $REPO_SLUG — the drafter is told 'unknown', never a guess" ;;
    *) LIVE_BRANCH="$DEFAULT_BRANCH" ;;
  esac
  if [ -n "$BASE_OVERRIDE" ]; then
    BASE_BRANCH="$BASE_OVERRIDE"
  else
    BASE_BRANCH="$DEFAULT_BRANCH"
    [ -n "$BASE_BRANCH" ] || BASE_BRANCH=main
  fi
  if ! "$GIT_BIN" ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1; then
    log "skip: base branch '$BASE_BRANCH' does not exist on origin -> $REPO_DIR"
    continue
  fi
  WT_ROOT="$WORKTREE_ROOT"
  if [ ! -d "$WT_ROOT" ]; then
    log "skip: worktree root does not exist: $WT_ROOT"
    continue
  fi
  log "== repo $REPO_SLUG ($REPO_DIR) live=$LIVE_BRANCH integration=$BASE_BRANCH"

  # Repos disagree on the case of the epics directory (this repo uses
  # docs/epics, Oracle-Simple-Convert uses DOCS/EPICS). Ask the repo instead of
  # asserting, or the agent burns turns rediscovering it (GH #34). Resolved from
  # the checkout, not the worktree, so --dry-run reports the same path a real
  # run would use.
  EPICS_DIR=$("$GIT_BIN" -C "$REPO_DIR" ls-files 2>/dev/null \
    | grep -iEm1 '^docs/epics/' | cut -d/ -f1-2)
  [ -n "$EPICS_DIR" ] || EPICS_DIR="docs/epics"

  # Ensure the label exists so a first run does not fail on a missing label.
  if ! "$GH_BIN" label list --limit 200 2>/dev/null | grep -q "^${LABEL}[[:space:]]"; then
    if [ "$DRY_RUN" = yes ]; then
      log "DRY-RUN: would create missing label '$LABEL'"
    else
      "$GH_BIN" label create "$LABEL" --color "5319E7" \
        --description "Run unattended intake: draft an epic plan as a proposal PR" >/dev/null 2>&1 \
        && log "created missing label '$LABEL'"
    fi
  fi

  # ------------------------------------------------------------------- select
  if [ -n "$ONLY_ISSUE" ]; then
    if [ "$FORCE_ISSUE" = yes ]; then
      ISSUES="$ONLY_ISSUE"
    else
      ISSUES="$("$GH_BIN" issue list --state open --label "$LABEL" --limit 100 \
                  --json number -q '.[].number' 2>/dev/null | grep -x "$ONLY_ISSUE" || true)"
      [ -n "$ISSUES" ] || { log "issue #$ONLY_ISSUE is not open with label '$LABEL' here"; continue; }
    fi
  else
    ISSUES="$("$GH_BIN" issue list --state open --label "$LABEL" --limit 100 \
                --json number -q '.[].number' 2>/dev/null || true)"
  fi

  if [ -z "$ISSUES" ]; then
    log "nothing labelled '$LABEL' — nothing to do"
    continue
  fi

  log "issues to process: $(printf '%s' "$ISSUES" | tr '\n' ' ')"

  # ------------------------------------------------------------------ process
  # Every failure exits the same way: say why on the issue, drop the label so a
  # deterministic failure cannot retry forever, and leave nothing half-built.
  fail_issue() { # $1 = issue number, $2 = reason, $3 = worktree (optional), $4 = branch (optional)
    log "ERROR #$1: $2"
    "$GH_BIN" issue comment "$1" --body "Unattended intake failed: $2

  The \`$LABEL\` label has been removed so this does not retry automatically. Re-apply it to try again." >/dev/null 2>&1 || true
    "$GH_BIN" issue edit "$1" --remove-label "$LABEL" >/dev/null 2>&1 || true
    [ -n "${3:-}" ] && "$GIT_BIN" worktree remove --force "$3" 2>/dev/null || true
    [ -n "${4:-}" ] && "$GIT_BIN" branch -D "$4" 2>/dev/null || true
    FAILED=1
  }

  # ------------------------------------------------ work in progress check
  # Never draft work that is already done or already in flight.
  #
  # The rule is NOT "skip an issue that has an open PR" — that rule was
  # measured against the race it was supposed to prevent and does not catch it.
  # LODE #757, timed from gh: issue filed 19:50:58Z, attended PR #758 opened
  # 19:58:37Z, #758 MERGED 20:00:12Z, this runner selected #757 at 20:02:46Z,
  # wasted proposal PR #761 opened 20:06:10Z. At the moment of selection there
  # was no open PR and the issue was still open. MERGED-not-open is the case
  # that actually bit us.
  #
  # So a PR blocks when it is OPEN or MERGED, was not opened by this runner,
  # and DECLARES THAT IT CLOSES the issue.
  # A CLOSED-unmerged PR does not block: abandoned work is not work in flight.
  #
  # That third axis is epic 09 item 6, and it is not a nicety. Item 3 blocked on
  # any cross-reference, and measured cold on this repo that blocked four of
  # four open issues on passing mentions — including #48, blocked by the body of
  # PR #52, which was the PR that recorded #48 as clear. Because a skip REMOVES
  # the label, a false positive does not defer an issue, it retires it from
  # unattended intake until a human relabels. See CLOSING_KEYWORD_RE.
  #
  # FOUR signals, evaluated in that order of authority (epic 09 item 7 adds the
  # third and fourth, item 8 the first; see EPIC_STATE_LABELS, PART_OF_RE and
  # BRANCH_LIST_JQ):
  #
  #   epic-filed         the ISSUE ITSELF is labelled `epic:planned` /
  #                      `epic:in-progress` — the declaration the linking
  #                      contract already mandates, read instead of inferred
  #   already-done       a non-runner open-or-merged PR declares it CLOSES it
  #   in-flight-pr       a non-runner open-or-merged PR declares it is PART OF it
  #   in-flight-branch   a non-runner branch on origin is NAMED for it
  #
  # The first outranks the rest because it is the only one that is stated rather
  # than deduced, and it short-circuits: when it fires, NO GitHub query is made
  # by this check at all. The rest outrank each other for the reason below.
  #
  # Already-done outranks the other two on purpose, and not for tidiness: the
  # skip comment tells a human what to do about it, and the two answers are
  # opposites. Already done means close this issue. In flight means leave it
  # open and wait. LODE #766 is the live case that needs the ordering — it has
  # both a merged PR that closes it and earlier PRs that are only part of it.
  #
  # Sets WIP_STATUS to one of:
  #   clear    nothing that closes this issue, or is under way on it, blocks it
  #   blocked  BLOCKING_PR holds the evidence, naming the specific label, PR or
  #            branch, and WIP_SIGNAL says which of the four fired
  #   unknown  a query itself failed (offline, rate limited, issue gone)
  # `unknown` proceeds to draft, loudly: a GitHub blip must not stop a runner
  # that worked yesterday, and an unchecked draft is a wasted PR, not a wrong
  # one. It is logged so it is never silent.
  BLOCKING_PR=""
  WIP_STATUS=""
  WIP_SIGNAL=""
  WIP_LINKAGE=""
  WIP_EPIC_LABEL=""
  WIP_FLIGHT_PR=""
  WIP_BRANCH=""
  WIP_UNKNOWN_REASON=""

  # Does this issue DECLARE that an epic has already been filed for it — i.e.
  # does it carry the label the linking contract mandates (epic 09 item 8)?
  #   $1 = comma-FENCED label list of the issue (`,bug,epic:planned,`, or `,,`)
  # Sets WIP_EPIC_LABEL to the label that matched and returns 0; returns 1 and
  # leaves it empty otherwise. The fence is what makes `epic:planned` unable to
  # match a label merely starting with it, exactly as the closing-refs fence
  # stops `41` matching `410`.
  declares_epic_filed() {
    WIP_EPIC_LABEL=""
    for WIP_EL in $EPIC_STATE_LABELS; do
      case "$1" in *",$WIP_EL,"*) WIP_EPIC_LABEL="$WIP_EL"; return 0 ;; esac
    done
    return 1
  }

  # Does this pull request DECLARE that it resolves the issue, or does it only
  # mention it? This is the whole of epic 09 item 6 (see CLOSING_KEYWORD_RE).
  #   $1 = issue number
  #   $2 = comma-fenced closingIssuesReferences of the PR (`,41,` or `,`)
  #   $3 = the PR description
  # Returns 0 and sets WIP_LINKAGE to the evidence kind (`linked` for GitHub's
  # own closing link, `declared` for the keyword in the description); returns 1
  # and leaves WIP_LINKAGE empty for a passing mention, which does NOT block.
  declares_closing() {
    WIP_LINKAGE=""
    case "$2" in *",$1,"*) WIP_LINKAGE="linked"; return 0 ;; esac
    if printf '%s\n' "$3" | grep -Eiq "${CLOSING_KEYWORD_RE}$1([^0-9]|\$)"; then
      WIP_LINKAGE="declared"
      return 0
    fi
    return 1
  }

  # Does this pull request declare it is PART OF the issue's work — i.e. the
  # issue is an epic being delivered right now (epic 09 item 7, signal b)?
  #   $1 = issue number, $2 = the PR description
  # There is no GitHub-side equivalent to fall back on here: GitHub has no
  # concept of a non-closing link, which is precisely why `Part of #<n>` is a
  # convention this workflow writes into every work-item PR body and why the
  # description is the only place it can be read from.
  declares_part_of() { # $1 = issue number, $2 = the PR description
    printf '%s\n' "$2" | grep -Eiq "${PART_OF_RE}$1([^0-9]|\$)"
  }

  # Record — do not yet act on — a PR that declares itself part of this issue's
  # work. Deferred rather than returned because ALREADY DONE outranks ALREADY IN
  # FLIGHT and may be declared by a PR further down the same timeline; acting on
  # the first match would tell a human to wait for work that has already landed.
  # Only the first is kept: the evidence names one PR, and a second adds nothing
  # a reader of the first cannot see. Reads the loop's current PR from the same
  # variables the closing path uses, so the two can never disagree about which
  # PR they are looking at.
  #   $1 = issue number
  note_in_flight_pr() {
    [ -z "$WIP_FLIGHT_PR" ] || return 0
    declares_part_of "$1" "$WIP_BODY" || return 0
    # The state axis is item 3's and is unchanged: only OPEN or MERGED counts,
    # because a closed-unmerged PR is abandoned work, not work in flight. The
    # phrasing is deliberately repeated rather than shared with the closing path
    # below — fixture cases K and R pin that path's exact lines to prove the
    # merged arm and the linkage gate are load-bearing, and refactoring it would
    # quietly turn both mutants into tests of nothing.
    case "$WIP_STATE" in
      OPEN)   WIP_FLIGHT_PR="PR #$WIP_PR is open and its description declares it is part of this issue's work ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
      MERGED) WIP_FLIGHT_PR="PR #$WIP_PR is already merged and its description declares it is part of this issue's work ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
    esac
  }

  # Is a branch named for this issue already cut on origin (item 7, signal c)?
  # Sets WIP_BRANCH to the first match.
  #   returns 0 = found  ·  1 = none  ·  2 = the query itself failed
  # The glob is `*/<issue>-*`: the number must sit immediately after a `/` and
  # be followed immediately by a `-`, so `feat/811-x` matches while `feat/1811-x`,
  # `feat/8111-x` and `docs/diagram-mcp-811` do not. Same exclusion as the PR
  # path, from the same constant: a branch this runner cut for its own proposal
  # is not somebody else's work in flight.
  branch_named_for_issue() { # $1 = issue number
    WIP_BRANCH=""
    WIP_BRANCHES="$("$GH_BIN" api --paginate \
          "repos/$REPO_SLUG/branches?per_page=100" \
          -H "Accept: application/vnd.github+json" \
          -q "$BRANCH_LIST_JQ" 2>/dev/null)" || return 2
    for WIP_BR in $WIP_BRANCHES; do
      case "$WIP_BR" in "$PROPOSAL_BRANCH_PREFIX"*) continue ;; esac
      case "$WIP_BR" in */"$1"-*) WIP_BRANCH="$WIP_BR"; return 0 ;; esac
    done
    return 1
  }

  check_work_in_progress() { # $1 = issue number, $2 = its comma-fenced labels
    BLOCKING_PR=""
    WIP_STATUS="clear"
    WIP_SIGNAL=""
    WIP_LINKAGE=""
    WIP_EPIC_LABEL=""
    WIP_FLIGHT_PR=""
    WIP_BRANCH=""
    WIP_UNKNOWN_REASON=""

    # SIGNAL ZERO, and it short-circuits everything below it: the issue itself
    # says an epic has been filed for it. This is the only signal that reads a
    # DECLARATION rather than inferring one, so it is asked first and it returns
    # before the timeline query, the per-PR reads and the branch listing are made
    # at all — see EPIC_STATE_LABELS for why it earns that position, and why the
    # three inferred signals stay behind it rather than being deleted.
    #
    # An unreadable or unfetched label list arrives here as `,,` and simply does
    # not fire, which drops through to item 7's three signals — today's exact
    # behaviour. That degradation is deliberate and is the safe direction: it
    # costs the queries this signal would have saved, and it is NOT `unknown`,
    # because `unknown` drafts unchecked.
    if declares_epic_filed "${2:-,,}"; then
      BLOCKING_PR="the issue carries the \`$WIP_EPIC_LABEL\` label, which this workflow applies to an issue once an epic has been filed for it (references/issue-intake.md, the linking contract)"
      WIP_SIGNAL="epic-filed"; WIP_STATUS="blocked"
      return 0
    fi

    if ! WIP_PRS="$("$GH_BIN" api --paginate \
          "repos/$REPO_SLUG/issues/$1/timeline?per_page=100" \
          -H "Accept: application/vnd.github+json" \
          -q "$TIMELINE_PR_JQ" 2>/dev/null)"; then
      WIP_STATUS="unknown"
      WIP_UNKNOWN_REASON="timeline query failed"
      return 0
    fi
    for WIP_PR in $WIP_PRS; do
      case "$WIP_PR" in ''|*[!0-9]*) continue ;; esac
      # state is OPEN | CLOSED | MERGED — CLOSED here means closed-unmerged,
      # because gh reports a merged PR as MERGED and never as CLOSED.
      WIP_VIEW="$("$GH_BIN" pr view "$WIP_PR" --repo "$REPO_SLUG" \
                    --json state,headRefName,url,closingIssuesReferences,body \
                    -q "$PR_VIEW_JQ" 2>/dev/null)" || continue
      WIP_LINE="$(printf '%s\n' "$WIP_VIEW" | head -1)"
      WIP_BODY="$(printf '%s\n' "$WIP_VIEW" | tail -n +2)"
      WIP_STATE=""; WIP_HEAD=""; WIP_URL=""; WIP_CLOSES=""
      read -r WIP_STATE WIP_HEAD WIP_URL WIP_CLOSES <<WIPLINE
$WIP_LINE
WIPLINE
      # Our own proposal never blocks us. Today the label is removed after a
      # successful draft so the runner never re-selects its own issue; this
      # costs nothing and stops it tripping over itself if the label is ever
      # re-applied by hand.
      case "$WIP_HEAD" in "$PROPOSAL_BRANCH_PREFIX"*) continue ;; esac
      # THE NARROWING (item 6), and the only axis item 6 touches. The state
      # gate below and the runner-authored gate above are item 3's, unchanged.
      # What changed is that being MENTIONED by an open-or-merged non-runner PR
      # is no longer enough: the PR has to say it CLOSES the issue. Removing
      # just the next line reverts the check to item 3's any-cross-reference
      # rule — which is exactly the mutant fixture case R runs.
      #
      # Item 7 adds only the tail: a PR that does not close the issue may still
      # declare it is PART OF it, which is the signal a mid-flight epic gives.
      # It is banked and the loop continues, because a later PR may close it and
      # already-done outranks in-flight.
      declares_closing "$1" "$WIP_CLOSES" "$WIP_BODY" || { note_in_flight_pr "$1"; continue; }
      case "$WIP_LINKAGE" in
        linked) WIP_EVIDENCE="GitHub records it as closing this issue" ;;
        *)      WIP_EVIDENCE="its description declares it closes this issue" ;;
      esac
      case "$WIP_STATE" in
        OPEN)   BLOCKING_PR="PR #$WIP_PR is open and $WIP_EVIDENCE ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
        MERGED) BLOCKING_PR="PR #$WIP_PR is already merged and $WIP_EVIDENCE ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
        *)      continue ;;
      esac
      WIP_SIGNAL="already-done"
      WIP_STATUS="blocked"
      return 0
    done

    # Reaching here means nothing declares this issue DONE — the closing path
    # above returns the moment anything does. So the in-flight signals are read
    # second, and only ever reported when already-done did not fire.
    if [ -n "$WIP_FLIGHT_PR" ]; then
      BLOCKING_PR="$WIP_FLIGHT_PR"
      WIP_SIGNAL="in-flight-pr"; WIP_STATUS="blocked"
      return 0
    fi

    # The branch signal is asked last because it costs a second API call and is
    # the weakest evidence of the three — a branch is somebody starting, not
    # somebody declaring anything. It is still the only signal that fires before
    # a PR exists at all, which is the earliest the runner can see work begin.
    branch_named_for_issue "$1"
    WIP_BRANCH_RC=$?
    if [ "$WIP_BRANCH_RC" = 2 ]; then
      # A check that could only half run reports `unknown`, never `clear`: the
      # PR signals passing is not evidence of anything when the third query
      # never answered. `unknown` still drafts, and still says so out loud.
      WIP_STATUS="unknown"
      WIP_UNKNOWN_REASON="branch listing query failed"
      return 0
    fi
    [ "$WIP_BRANCH_RC" = 0 ] || return 0
    BLOCKING_PR="branch \`$WIP_BRANCH\` on origin is named for this issue (\`*/$1-*\`), so work on it is already cut"
    WIP_SIGNAL="in-flight-branch"; WIP_STATUS="blocked"
    return 0
  }

  # A skip is never silent (epic 09 invariant): the evidence goes on the issue
  # naming the specific PR or branch, the label comes off so the next poll
  # cannot spin on it, and it is logged. A skip is also NOT a failure — the
  # runner did the right thing — so FAILED is untouched and the run still
  # exits 0.
  #
  # WHICH signal fired is stated, not implied (epic 09 item 7), because the
  # answers a reader needs are opposites and the evidence sentence alone does
  # not distinguish them: already done means CLOSE this issue, in flight means
  # LEAVE IT OPEN and wait. A comment that only says "skipped" invites the wrong
  # one, and the wrong one on an in-flight epic loses the issue.
  #
  # Item 8 adds a third answer with a third remedy: already PLANNED means a
  # human filed an epic for this issue, so the epic — not this runner and not a
  # reader of this comment — owns it from here. Its remedy is the only one that
  # says how to make the runner draft it after all, because it is the only
  # signal a human can be wrong about by hand: remove a label that should not
  # have been there.
  skip_issue() { # $1 = issue, $2 = stage, $3 = signal, $4 = evidence, $5 = worktree (opt), $6 = branch (opt)
    case "$3" in
      epic-filed)
        SKIP_VERDICT="already **planned**"
        SKIP_SUBJECT="label"
        SKIP_REMEDY="That label is applied when an epic has been filed for this issue (\`epic:planned\`) or dispatched (\`epic:in-progress\`), so a plan for it already exists and a drafted proposal would compete with it. **Do not close this issue** — the epic that owns it closes it when it lands. If the label is wrong — no epic exists, or one was abandoned — remove it, then re-apply \`$LABEL\`." ;;
      already-done)
        SKIP_VERDICT="already **done**"
        SKIP_SUBJECT="pull request"
        SKIP_REMEDY="If that pull request does resolve this issue, **close this issue** — it is finished. If it does not, its closing link or wording is wrong; correct that and re-apply the label." ;;
      in-flight-pr)
        SKIP_VERDICT="already **in flight**"
        SKIP_SUBJECT="pull request"
        SKIP_REMEDY="That pull request declares it is part of this issue's work rather than the end of it, which is what a multi-item epic's work-item PRs say. **Do not close this issue** — wait for the epic to finish, then re-apply the label only if something is genuinely left to draft." ;;
      *)
        SKIP_VERDICT="already **in flight**"
        SKIP_SUBJECT="branch"
        SKIP_REMEDY="A branch named for this issue is already cut, so somebody has started. **Do not close this issue** — wait for that work to land. If that branch is abandoned, delete it on \`origin\` and re-apply the label." ;;
    esac
    log "SKIP #$1 ($2): already addressed or in flight — $4 [signal: $3]"
    "$GH_BIN" issue comment "$1" --body "Unattended intake skipped this issue: $4

  Signal: the work is $SKIP_VERDICT. Drafting a proposal here would duplicate work that is already merged or already in flight, so nothing was drafted. Checked at: $2.

  $SKIP_REMEDY

  The \`$LABEL\` label has been removed so this does not retry automatically. Re-applying it produces this same skip while that $SKIP_SUBJECT stands." >/dev/null 2>&1 || true
    "$GH_BIN" issue edit "$1" --remove-label "$LABEL" >/dev/null 2>&1 || true
    [ -n "${5:-}" ] && "$GIT_BIN" worktree remove --force "$5" 2>/dev/null || true
    [ -n "${6:-}" ] && "$GIT_BIN" branch -D "$6" 2>/dev/null || true
  }


  for N in $ISSUES; do
    # ONE call, two answers, and this is why the label signal costs no extra
    # API request at selection: the title was already being fetched here for the
    # log line, so the labels ride along in the same request. Line 1 is the
    # comma-fenced label list, the rest is the title (see ISSUE_VIEW_JQ).
    ISSUE_VIEW="$("$GH_BIN" issue view "$N" --json title,labels -q "$ISSUE_VIEW_JQ" 2>/dev/null || true)"
    ISSUE_LABELS="$(printf '%s\n' "$ISSUE_VIEW" | head -1)"
    TITLE="$(printf '%s\n' "$ISSUE_VIEW" | tail -n +2 | head -1)"
    [ -n "$TITLE" ] || TITLE='(unknown)'
    # A list that is not fenced at both ends did not come from ISSUE_VIEW_JQ —
    # the query failed, or gh answered a shape this runner does not know. Treat
    # it as "no labels read" rather than pattern-matching a partial answer.
    case "$ISSUE_LABELS" in ,*,) ;; *) ISSUE_LABELS=",," ;; esac
    log "--- issue #$N: $TITLE"

    # First of two evaluations. This one is before anything at all is created,
    # so a skip here costs no worktree, no branch and no headless run.
    check_work_in_progress "$N" "$ISSUE_LABELS"
    case "$WIP_STATUS" in
      blocked)
        if [ "$DRY_RUN" = yes ]; then
          log "DRY-RUN: #$N classified SKIP — $BLOCKING_PR [signal: $WIP_SIGNAL]"
        else
          skip_issue "$N" "selection" "$WIP_SIGNAL" "$BLOCKING_PR"
        fi
        continue
        ;;
      unknown)
        log "WARN #$N: work-in-progress check could not run ($WIP_UNKNOWN_REASON) — drafting unchecked"
        ;;
      *)
        [ "$DRY_RUN" = yes ] && log "DRY-RUN: #$N classified DRAFT — no epic-filed label, no open or merged non-runner PR closes it or declares itself part of it, and no branch on origin is named for it"
        ;;
    esac

    # NO epic number is claimed here. Phase 1 assigns the number at APPROVAL,
    # not at drafting, and a runner reserving one early both contradicted that
    # and collided whenever two issues were labelled before either merged
    # (GH #22). A proposal is named for its issue, which is already unique.
    # sed -E: BSD sed has no \+ in a basic regex, and silently leaves it literal —
    # which produced branch names containing spaces until a live run caught it.
    SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' \
              | sed -E -e 's/[^a-z0-9]+/-/g' -e 's/^-+//' -e 's/-+$//' | cut -c1-48)"
    SLUG="$(printf '%s' "$SLUG" | sed -E -e 's/-+$//')"
    [ -n "$SLUG" ] || SLUG="issue-$N"
    BRANCH="${PROPOSAL_BRANCH_PREFIX}${N}-${SLUG}"
    WT="$WT_ROOT/$(basename "$REPO_DIR")-proposed-${N}-${SLUG}"
    # Belt and braces: never create outside the declared root, whatever the
    # repo basename or slug turned out to be.
    case "$WT" in
      "$WT_ROOT"/*) ;;
      *) fail_issue "$N" "refusing to create a worktree outside $WT_ROOT"; continue ;;
    esac

    if [ "$DRY_RUN" = yes ]; then
      log "DRY-RUN: would create worktree $WT on $BRANCH"
      log "DRY-RUN: would run headless intake for #$N producing ${EPICS_DIR}/proposed-${N}-${SLUG}/plan.md at Status: planning"
      log "DRY-RUN: would open a PR (Part of #$N, no Closes), comment the link, and remove label '$LABEL'"
      continue
    fi

    # NEVER touch the target checkout — no switch, no pull. The user may be
    # mid-edit on another branch, and this runs unattended on a timer. Fetching
    # is enough: the worktree is cut from origin/<default>, so no local branch
    # needs to exist or be current (GH #27).
    "$GIT_BIN" fetch -q origin "$BASE_BRANCH" 2>/dev/null || true

    if ! "$GIT_BIN" worktree add -q "$WT" -b "$BRANCH" "origin/$BASE_BRANCH" 2>/dev/null; then
      fail_issue "$N" "could not create worktree $WT on $BRANCH"
      continue
    fi

    # Phase 0 + Phase 1 only. The prompt restates the hard stops because the
    # model is the thing being constrained, and a headless run has no one to ask.
    PROMPT="Run unattended intake for GitHub issue #$N in this repository.

  Follow the dev-epic-workflow skill's unattended-intake contract in
  ${SKILL_DIR}/references/issue-intake.md. Run ONLY Phase 0 (ground
  the work by reading the actual code and config) and Phase 1 (draft the plan).
  Both reference files are readable at those absolute paths — read them there.
  Do NOT search the filesystem for them.

  Write the plan to ${EPICS_DIR}/proposed-${N}-${SLUG}/plan.md using the structure in
  ${SKILL_DIR}/references/plan-template.md, with:
    **Status:** planning
    **Source:** GH #$N
    **Recommendation:** one of plan | no-work | needs-decision — see below

  SUPPLIED HEADER FACTS — these are read from this repository's own configuration by the
  runner that started you. They are not yours to work out. Copy them into the header
  verbatim, exactly as written here:
    **Live branch:** ${LIVE_BRANCH}
    **Integration branch:** ${BASE_BRANCH}
  and this repository keeps its epics in ${EPICS_DIR}/ — use that path exactly, including
  its capitalisation.

  Do NOT infer, re-derive or improve those two branch values: not from the branch you are
  standing on, not from what similar repositories usually do, and not from memory. They are
  handed to you because a drafter left to fill them in itself got them wrong on 2 of 7
  proposals, naming the INTEGRATION branch as the live one — on the exact field the first
  invariant of this workflow (the live branch is never written to) is written in terms of.
  Live and integration are frequently different branches, and on this repository they may
  well be. If a value above reads unknown, then write unknown in the header and say in
  Grounding that it could not be resolved. Never substitute a plausible-looking branch name
  for a fact you were not given: a wrong-but-believable header is worse than an admitted gap,
  because it reads as correct and gets approved.

  **Pre-epic tag:** is NOT supplied. That one is yours to judge — propose a tag, or n/a.

  THE RECOMMENDATION — pick exactly one, and put it in the header directly under Status:
    plan            There is real work here. The body is a normal epic plan. This is the
                    default, and today's behaviour.
    no-work         There is nothing for an approved epic to dispatch: already fixed,
                    already in flight, a duplicate, or invalid as reported. NAME the
                    evidence that makes it so — the PR, commit, issue or code you read.
    needs-decision  A real choice has to be made by a human before any plan is worth
                    writing. State the choice and the options in the body, with what each
                    one costs. Do NOT resolve it, and do NOT quietly adopt a default.

  no-work and needs-decision are CORRECT, PREFERRED outputs when they fit. They are not
  failures, and reporting one is not giving up: a plan you would not defend is worse than an
  honest no-work, and inventing work in order to have something to draft is the worst thing
  you can do here. They are equally not an escape hatch — a brief that is merely
  under-specified but still has obvious real work is a plan with Open questions, NOT a
  needs-decision.

  Whichever value you choose, the artifact is the same: one plan.md at **Status:** planning,
  committed on this branch. A no-work or needs-decision plan still states what you looked at
  and what you found — it is evidence, and a human will read it.

  HARD STOPS — you are running unattended and nobody can approve anything:
    - Do NOT set Status to approved. It is a proposal, not a filed epic.
    - Do NOT dispatch any executor or subagent.
    - Do NOT write, modify, or delete any code outside ${EPICS_DIR}/proposed-${N}-${SLUG}/.
    - Do NOT merge anything, and do NOT close the issue.
    - Do NOT git push, do NOT open a PR — the runner does that.
  Commit the plan with a conventional message and stop."

    ( cd "$WT" && "$CLAUDE_BIN" -p "$PROMPT" \
        --add-dir "$SKILL_DIR" \
        --allowed-tools 'Bash(git:*)' 'Bash(gh issue view:*)' 'Bash(ls:*)' 'Bash(grep:*)' 'Bash(sed:*)' 'Bash(cat:*)' 'Bash(head:*)' 'Bash(date:*)' Read Write Edit Glob Grep ) \
        > "$WT/.intake-run.log" 2>&1
    RC=$?

    if [ $RC -ne 0 ]; then
      fail_issue "$N" "headless run exited $RC (see $WT/.intake-run.log)" "$WT" "$BRANCH"
      continue
    fi

    if ! "$GIT_BIN" -C "$WT" log --oneline "origin/$BASE_BRANCH".."$BRANCH" 2>/dev/null | grep -q .; then
      fail_issue "$N" "headless run produced no commit" "$WT" "$BRANCH"
      continue
    fi

    # Second evaluation, immediately before the proposal is published. The
    # #757 window between selection and PR creation was under four minutes and
    # the blocking PR merged inside it, so one check at selection is not
    # enough. It sits before the push rather than between the push and
    # `gh pr create` on purpose: push-then-create is a single publication step,
    # and checking ahead of it means a skip leaves no branch on origin and no
    # PR — nothing half-built, which is the same contract fail_issue keeps.
    # The labels are RE-READ here rather than reused from selection, and this is
    # the one place item 8 spends an API call it did not have to. The whole
    # reason this second evaluation exists is that the window between the two is
    # wide enough for the world to change inside it, and the change this signal
    # watches for — a human filing an epic and labelling the issue — is exactly
    # the thing that leaves no PR and no branch for the other three to see.
    # Evaluating the highest-authority signal on selection-time data would put a
    # hole in the middle of the check. It is also cheaper than it looks: when
    # the label is there this returns before the timeline query, the per-PR
    # reads and the branch listing, so it REPLACES more calls than it adds.
    RECHECK_VIEW="$("$GH_BIN" issue view "$N" --json title,labels -q "$ISSUE_VIEW_JQ" 2>/dev/null || true)"
    RECHECK_LABELS="$(printf '%s\n' "$RECHECK_VIEW" | head -1)"
    case "$RECHECK_LABELS" in ,*,) ;; *) RECHECK_LABELS=",," ;; esac
    check_work_in_progress "$N" "$RECHECK_LABELS"
    if [ "$WIP_STATUS" = blocked ]; then
      skip_issue "$N" "pre-PR re-check" "$WIP_SIGNAL" "$BLOCKING_PR" "$WT" "$BRANCH"
      continue
    fi
    [ "$WIP_STATUS" = unknown ] && log "WARN #$N: pre-PR work-in-progress re-check could not run ($WIP_UNKNOWN_REASON) — publishing unchecked"

    # ------------------------------------------------------- the recommendation
    # AFTER the pre-PR re-check above, deliberately: a skipped issue is never
    # published, `skip_issue` removes the worktree this reads from, and logging
    # a recommendation for a proposal that is then discarded would be false
    # telemetry. Do not reorder these two blocks.
    #
    # The draft declares its terminal outcome in the plan header:
    #   **Recommendation:** plan | no-work | needs-decision
    # (the vocabulary is defined in references/issue-intake.md). Read it back so
    # the PR and the issue comment say which one it is. NOTHING here acts on it:
    # routing a no-work or needs-decision proposal to a human is a documented
    # obligation, not an automated one, and this runner still never approves,
    # never dispatches, never merges, and never closes an issue.
    REC_FILE="$WT/${EPICS_DIR}/proposed-${N}-${SLUG}/plan.md"
    REC_RAW="$(head -"$PLAN_HEADER_LINES" "$REC_FILE" 2>/dev/null \
                 | sed -n -E -e 's/^[[:space:]*_]*[Rr]ecommendation:[[:space:]*_]*//p' \
                 | head -1 | tr -d '\r')"
    # First word only, case-folded: `no-work (duplicate of #758)` is no-work.
    REC="$(printf '%s' "$REC_RAW" | tr '[:upper:]' '[:lower:]' \
             | sed -E -e 's/[^a-z-].*$//' -e 's/^-+//' -e 's/-+$//')"
    case "$REC" in
      plan|no-work|needs-decision) ;;
      '') REC=plan ;;                 # absent: the proposal predates the field,
                                      # which is additive. Reads as a plan.
      # A value outside the vocabulary is NOT quietly read as an approvable plan.
      # A malformed terminal outcome is exactly the case a human should look at,
      # so it is logged verbatim and shown as needs-decision.
      *) log "#$N: unrecognised Recommendation [$REC_RAW] — treating as needs-decision"
         REC=needs-decision ;;
    esac
    log "#$N: recommendation=$REC"

    # What the PR and the issue then say. `plan` leaves every one of these at its
    # pre-existing value, so an ordinary proposal reads exactly as it did before.
    # ------------------------------------------------ collision detection (4)
    # Admission decides this, not drafter goodwill. On overlap the proposal's
    # own Recommendation is DOWNGRADED to needs-decision — settled 2026-08-21,
    # and the point of it: a genuine file collision IS the human decision the
    # outcome exists to route, and only the downgrade moves the proposal out of
    # the SessionStart *awaiting approval* bucket (where it could be approved
    # without the collision ever being registered) into *awaiting a decision*.
    # It is not a fourth value: the vocabulary in references/issue-intake.md is
    # closed at three and this consumes it rather than extending it.
    #
    # HERE, deliberately: after REC has been read back so it can be amended, and
    # before REC_TITLE_TAG below so the title tag, the PR body and the issue
    # comment all consume ONE settled value. `gh pr create` follows.
    #
    # It runs ONLY for a `plan`. A `no-work` proposal proposes no edits, so it
    # cannot collide with anything — and it usually carries no `**Scope:**`
    # block at all, so the colliding-unknown rule would turn every honest
    # no-work into a needs-decision and quietly delete item 1's outcome. A draft
    # that already says needs-decision is already where a collision would put it.
    COLLISION_PR_NOTE=""
    COLLISION_ISSUE_TAIL=""
    COLLISION_PARTNERS=""
    if [ "$REC" = plan ]; then
      check_collisions "$N" "$REC_FILE" "$BRANCH"
      case "$COLLISION_STATUS" in
        collided|undeclared)
          REC=needs-decision
          log "#$N: collision -> recommendation downgraded from plan to needs-decision ($COLLISION_SUMMARY)"
          COLLISION_SECTION="$WT/.intake-collision-section.md"
          {
            printf '## Collision detected in admission — not approvable as it stands\n\n'
            printf '**The `**Recommendation:**` above was downgraded from `plan` to `needs-decision`\n'
            printf 'by the unattended intake runner, not by the drafter.** %s.\n' "$COLLISION_SUMMARY"
            printf 'The draft below proposed a plan; admission compared what it declares it will\n'
            printf 'touch against every other open proposal in this repository and found an overlap:\n\n'
            printf '%s\n\n' "$COLLISION_DETAIL"
            printf 'Deciding which proposal owns the shared files — or that they are really one\n'
            printf 'epic, or that they must be sequenced — is the human decision this outcome\n'
            printf 'exists to route. It is deliberately not made here: nothing was reordered,\n'
            printf 'superseded or closed, and the counterpart proposal was annotated by a comment\n'
            printf 'on its issue rather than rewritten.\n\n'
            printf 'Declared files are read from `**Scope:**` blocks only and matched on path\n'
            printf 'suffixes at component boundaries. The rule favours recall over precision, so a\n'
            printf 'path named above may be one the counterpart only reads — read both `**Scope:**`\n'
            printf 'blocks before concluding there is no conflict.\n\n'
          } > "$COLLISION_SECTION" 2>/dev/null
          if ! downgrade_plan_recommendation "$REC_FILE" \
             || ! insert_plan_collision_section "$REC_FILE" "$COLLISION_SECTION"; then
            rm -f "$COLLISION_SECTION" 2>/dev/null || true
            fail_issue "$N" "collision detected but the proposal's own plan.md could not be downgraded to needs-decision — refusing to publish a PR whose title and header disagree" "$WT" "$BRANCH"
            continue
          fi
          rm -f "$COLLISION_SECTION" 2>/dev/null || true
          if ! "$GIT_BIN" -C "$WT" add "${EPICS_DIR}/proposed-${N}-${SLUG}/plan.md" >/dev/null 2>&1 \
             || ! "$GIT_BIN" -C "$WT" commit -q -m "docs(intake): downgrade to needs-decision — collision detected in admission" >/dev/null 2>&1; then
            fail_issue "$N" "collision detected and the plan was downgraded, but the downgrade could not be committed" "$WT" "$BRANCH"
            continue
          fi
          log "#$N: plan.md downgraded to needs-decision and committed on $BRANCH"
          COLLISION_PR_NOTE="
  **Collision detected in admission — $COLLISION_SUMMARY.** This is why the recommendation above reads \`needs-decision\` and not \`plan\`: the draft itself proposed a plan, and admission downgraded it. Overlapping declarations:

$COLLISION_DETAIL

  Deciding which proposal owns the shared files — or that they should be one epic, or sequenced — is the human decision this outcome exists to route. Nothing here resolved it, ordered them, or superseded either. The counterpart proposal has been annotated **by comment on its issue** and was not edited: an open PR is not rewritten from under a reviewer.

  Declarations are read from \`**Scope:**\` blocks only, matched on path suffixes at component boundaries, and the rule is tuned for recall over precision — so a listed path may be one the counterpart only reads. Check the two Scope blocks before concluding there is no conflict."
          COLLISION_ISSUE_TAIL="

  **Admission also found a collision** — $COLLISION_SUMMARY — which is why the recommendation is \`needs-decision\` rather than the \`plan\` the draft asked for. The PR names the overlapping paths and the counterpart proposal."
          ;;
        unknown)
          log "WARN #$N: collision detection did not run (the open-proposal query failed) — publishing unchecked" ;;
        *)
          log "#$N: no collision — no other open proposal declares a file this one declares" ;;
      esac
    else
      log "#$N: collision check not run — recommendation is $REC, which proposes no edits that could collide"
    fi

    REC_TITLE_TAG=""
    REC_PR_NOTE=""
    REC_ISSUE_TAIL="It is at \`Status: planning\` — not approved, not dispatchable. Review the PR; approve by merging it and setting \`Status: approved\`."
    case "$REC" in
      no-work)
        REC_TITLE_TAG="[no-work] "
        REC_PR_NOTE="
  **Recommendation: no-work** — the draft's own conclusion is that there is nothing here to build, and the plan names the evidence for it. This is not asking to be approved: read it, then close this PR — or say why the conclusion is wrong. Nothing was closed by the run; that call is a human's."
        REC_ISSUE_TAIL="**Recommendation: \`no-work\`** — the run concluded there is nothing here to build, and the plan names the evidence. It is at \`Status: planning\` and is not asking to be approved: read it, then close the PR, or say why it is wrong. Nothing was closed here — that call is yours." ;;
      needs-decision)
        REC_TITLE_TAG="[needs-decision] "
        REC_PR_NOTE="
  **Recommendation: needs-decision** — the draft states a choice it deliberately did not make. It is not approvable as it stands: decide the question in the plan body, then re-draft. Nothing in this run resolved it for you, by design."
        REC_ISSUE_TAIL="**Recommendation: \`needs-decision\`** — the run found a choice a human has to make first. The plan states it with its options and leaves it unresolved. It is at \`Status: planning\` and is not approvable as it stands: decide, then re-draft." ;;
    esac

    if ! "$GIT_BIN" -C "$WT" push -q -u origin "$BRANCH" 2>/dev/null; then
      fail_issue "$N" "push failed" "$WT" "$BRANCH"
      continue
    fi

    PR_URL="$("$GH_BIN" pr create --base "$BASE_BRANCH" --head "$BRANCH" \
        --title "intake: ${REC_TITLE_TAG}proposed epic for #$N — ${SLUG}" \
        --body "Proposed epic plan drafted by **unattended intake** from #$N.

  **This is a proposal, not a filed epic.** The plan is at \`**Status:** planning\`, which is never dispatchable. Approving means merging this PR **and** setting \`**Status:** approved\` — until that edit lands it is a draft that happens to be version-controlled.

  No epic number is claimed here. Phase 1 assigns the number **at approval** — rename \`${EPICS_DIR}/proposed-${N}-${SLUG}/\` to \`${EPICS_DIR}/<NN>-<slug>/\` when you approve, and set \`Status: approved\`.

  Nothing was approved, dispatched, merged, or closed by this run. No code outside \`${EPICS_DIR}/proposed-${N}-${SLUG}/\` was touched.
${REC_PR_NOTE}${COLLISION_PR_NOTE}
  Part of #$N" 2>/dev/null || true)"

    if [ -z "$PR_URL" ]; then
      fail_issue "$N" "PR creation failed (branch is pushed and preserved)"
      continue
    fi

    "$GH_BIN" issue comment "$N" --body "Unattended intake drafted a proposed epic plan: $PR_URL

  ${REC_ISSUE_TAIL}${COLLISION_ISSUE_TAIL}" >/dev/null 2>&1 || true
    # Both sides of a collision are told, because only one of them is reading
    # this PR. The counterpart is annotated BY COMMENT ON ITS ISSUE and is never
    # rewritten: its proposal PR is open, someone may be reading it, and editing
    # a plan out from under a reviewer is not an annotation, it is a surprise.
    # This is a comment and nothing else — no label is added or removed there,
    # nothing is closed, nothing is superseded.
    if [ -n "$COLLISION_PARTNERS" ]; then
      printf '%s\n' "$COLLISION_PARTNERS" | while IFS=' ' read -r CPR CISSUE CPATHS; do
        case "${CPR:-}" in ''|*[!0-9]*) continue ;; esac
        case "${CISSUE:-}" in ''|*[!0-9]*) continue ;; esac
        CLIST=""
        for H in $CPATHS; do CLIST="$CLIST \`$H\`,"; done
        CLIST="${CLIST%,}"
        "$GH_BIN" issue comment "$CISSUE" --body "Unattended intake drafted a proposal for #$N that **declares files this issue's own open proposal (PR #$CPR) also declares**:$CLIST

  The new proposal is $PR_URL, and admission set its recommendation to \`needs-decision\` for exactly this reason. **Nothing here changes this issue or PR #$CPR** — no plan was rewritten, nothing was superseded, closed, or reordered. Which proposal owns the shared files, whether they should be one epic, and in what order they land, is a decision for you.

  Declared files are read from \`**Scope:**\` blocks and matched on path suffixes; the rule favours recall, so a listed path may be one side only reads." >/dev/null 2>&1 || true
        log "#$N: collision annotated on #$CISSUE (counterpart proposal PR #$CPR)"
      done
    fi
    "$GH_BIN" issue edit "$N" --remove-label "$LABEL" >/dev/null 2>&1 || true

    log "#$N -> $PR_URL (label removed)"
    "$GIT_BIN" worktree remove --force "$WT" 2>/dev/null || true
  done

done <<REPOLIST
$(printf '%s\n' "$REPOS" | grep .)
REPOLIST

if [ "$FAILED" -ne 0 ]; then
  log "finished with failures"
  exit 4
fi

log "finished"
exit 0
