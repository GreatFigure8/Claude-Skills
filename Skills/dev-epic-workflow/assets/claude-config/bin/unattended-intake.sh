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

# How "a pull request references this issue" is asked of GitHub. The issue
# timeline is the same thing GitHub renders under the issue itself, and a
# cross-reference is recorded whether the mention came from the PR body or from
# a comment on it. `.source.issue.pull_request` is present only when the
# referring item is a PR, which is what separates a PR reference from a plain
# issue-to-issue mention.
TIMELINE_PR_JQ='.[] | select(.event == "cross-referenced") | select(.source.issue.pull_request != null) | .source.issue.number'

# How many lines of a drafted plan count as its header. The SAME window the
# SessionStart hook uses (session-start-context.sh: EPIC_QUEUE_HEADER_LINES), so
# the runner and the injection can never disagree about what the header said.
PLAN_HEADER_LINES=10
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
  # So a PR blocks when it is OPEN or MERGED and was not opened by this runner.
  # A CLOSED-unmerged PR does not block: abandoned work is not work in flight.
  #
  # Sets WIP_STATUS to one of:
  #   clear    nothing referencing this issue blocks it
  #   blocked  BLOCKING_PR holds the evidence, naming the specific PR
  #   unknown  the query itself failed (offline, rate limited, issue gone)
  # `unknown` proceeds to draft, loudly: a GitHub blip must not stop a runner
  # that worked yesterday, and an unchecked draft is a wasted PR, not a wrong
  # one. It is logged so it is never silent.
  BLOCKING_PR=""
  WIP_STATUS=""

  check_work_in_progress() { # $1 = issue number
    BLOCKING_PR=""
    WIP_STATUS="clear"
    if ! WIP_PRS="$("$GH_BIN" api --paginate \
          "repos/$REPO_SLUG/issues/$1/timeline?per_page=100" \
          -H "Accept: application/vnd.github+json" \
          -q "$TIMELINE_PR_JQ" 2>/dev/null)"; then
      WIP_STATUS="unknown"
      return 0
    fi
    for WIP_PR in $WIP_PRS; do
      case "$WIP_PR" in ''|*[!0-9]*) continue ;; esac
      # state is OPEN | CLOSED | MERGED — CLOSED here means closed-unmerged,
      # because gh reports a merged PR as MERGED and never as CLOSED.
      WIP_LINE="$("$GH_BIN" pr view "$WIP_PR" --repo "$REPO_SLUG" \
                    --json state,headRefName,url \
                    -q '"\(.state) \(.headRefName) \(.url)"' 2>/dev/null)" || continue
      WIP_STATE=""; WIP_HEAD=""; WIP_URL=""
      read -r WIP_STATE WIP_HEAD WIP_URL <<WIPLINE
$WIP_LINE
WIPLINE
      # Our own proposal never blocks us. Today the label is removed after a
      # successful draft so the runner never re-selects its own issue; this
      # costs nothing and stops it tripping over itself if the label is ever
      # re-applied by hand.
      case "$WIP_HEAD" in "$PROPOSAL_BRANCH_PREFIX"*) continue ;; esac
      case "$WIP_STATE" in
        OPEN)   BLOCKING_PR="PR #$WIP_PR is open and references this issue ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
        MERGED) BLOCKING_PR="PR #$WIP_PR is already merged and references this issue ($WIP_URL, branch \`$WIP_HEAD\`)" ;;
        *)      continue ;;
      esac
      WIP_STATUS="blocked"
      return 0
    done
    return 0
  }

  # A skip is never silent (epic 09 invariant): the evidence goes on the issue
  # naming the specific PR, the label comes off so the next poll cannot spin on
  # it, and it is logged. A skip is also NOT a failure — the runner did the
  # right thing — so FAILED is untouched and the run still exits 0.
  skip_issue() { # $1 = issue, $2 = stage, $3 = evidence, $4 = worktree (opt), $5 = branch (opt)
    log "SKIP #$1 ($2): already addressed or in flight — $3"
    "$GH_BIN" issue comment "$1" --body "Unattended intake skipped this issue: $3

  Drafting a proposal here would duplicate work that is already merged or already in flight, so nothing was drafted. Checked at: $2.

  The \`$LABEL\` label has been removed so this does not retry automatically. Re-applying it produces this same skip while that pull request stands — so if the reference above is only a passing mention, draft this one attended rather than relabelling it." >/dev/null 2>&1 || true
    "$GH_BIN" issue edit "$1" --remove-label "$LABEL" >/dev/null 2>&1 || true
    [ -n "${4:-}" ] && "$GIT_BIN" worktree remove --force "$4" 2>/dev/null || true
    [ -n "${5:-}" ] && "$GIT_BIN" branch -D "$5" 2>/dev/null || true
  }


  for N in $ISSUES; do
    TITLE="$("$GH_BIN" issue view "$N" --json title -q .title 2>/dev/null || echo '(unknown)')"
    log "--- issue #$N: $TITLE"

    # First of two evaluations. This one is before anything at all is created,
    # so a skip here costs no worktree, no branch and no headless run.
    check_work_in_progress "$N"
    case "$WIP_STATUS" in
      blocked)
        if [ "$DRY_RUN" = yes ]; then
          log "DRY-RUN: #$N classified SKIP — $BLOCKING_PR"
        else
          skip_issue "$N" "selection" "$BLOCKING_PR"
        fi
        continue
        ;;
      unknown)
        log "WARN #$N: work-in-progress check could not run (timeline query failed) — drafting unchecked"
        ;;
      *)
        [ "$DRY_RUN" = yes ] && log "DRY-RUN: #$N classified DRAFT — no open or merged non-runner PR references it"
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
    check_work_in_progress "$N"
    if [ "$WIP_STATUS" = blocked ]; then
      skip_issue "$N" "pre-PR re-check" "$BLOCKING_PR" "$WT" "$BRANCH"
      continue
    fi
    [ "$WIP_STATUS" = unknown ] && log "WARN #$N: pre-PR work-in-progress re-check could not run — publishing unchecked"

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
${REC_PR_NOTE}
  Part of #$N" 2>/dev/null || true)"

    if [ -z "$PR_URL" ]; then
      fail_issue "$N" "PR creation failed (branch is pushed and preserved)"
      continue
    fi

    "$GH_BIN" issue comment "$N" --body "Unattended intake drafted a proposed epic plan: $PR_URL

  ${REC_ISSUE_TAIL}" >/dev/null 2>&1 || true
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
