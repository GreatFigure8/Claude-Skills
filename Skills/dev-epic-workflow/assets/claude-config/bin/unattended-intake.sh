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
  # Default branch per repo — never assume 'main'. This is also the PR base.
  # An explicit base in the repos list wins; the GitHub default is only a
  # fallback. Default branch and INTEGRATION branch are not the same thing —
  # this repo integrates on main, LODE integrates on dev.
  if [ -n "$BASE_OVERRIDE" ]; then
    BASE_BRANCH="$BASE_OVERRIDE"
  else
    BASE_BRANCH="$("$GH_BIN" repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)"
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
  log "== repo $REPO_SLUG ($REPO_DIR) base=$BASE_BRANCH"

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


  for N in $ISSUES; do
    TITLE="$("$GH_BIN" issue view "$N" --json title -q .title 2>/dev/null || echo '(unknown)')"
    log "--- issue #$N: $TITLE"

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
    BRANCH="intake/proposed-${N}-${SLUG}"
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

    if ! "$GIT_BIN" -C "$WT" push -q -u origin "$BRANCH" 2>/dev/null; then
      fail_issue "$N" "push failed" "$WT" "$BRANCH"
      continue
    fi

    PR_URL="$("$GH_BIN" pr create --base "$BASE_BRANCH" --head "$BRANCH" \
        --title "intake: proposed epic for #$N — ${SLUG}" \
        --body "Proposed epic plan drafted by **unattended intake** from #$N.

  **This is a proposal, not a filed epic.** The plan is at \`**Status:** planning\`, which is never dispatchable. Approving means merging this PR **and** setting \`**Status:** approved\` — until that edit lands it is a draft that happens to be version-controlled.

  No epic number is claimed here. Phase 1 assigns the number **at approval** — rename \`${EPICS_DIR}/proposed-${N}-${SLUG}/\` to \`${EPICS_DIR}/<NN>-<slug>/\` when you approve, and set \`Status: approved\`.

  Nothing was approved, dispatched, merged, or closed by this run. No code outside \`${EPICS_DIR}/proposed-${N}-${SLUG}/\` was touched.

  Part of #$N" 2>/dev/null || true)"

    if [ -z "$PR_URL" ]; then
      fail_issue "$N" "PR creation failed (branch is pushed and preserved)"
      continue
    fi

    "$GH_BIN" issue comment "$N" --body "Unattended intake drafted a proposed epic plan: $PR_URL

  It is at \`Status: planning\` — not approved, not dispatchable. Review the PR; approve by merging it and setting \`Status: approved\`." >/dev/null 2>&1 || true
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
