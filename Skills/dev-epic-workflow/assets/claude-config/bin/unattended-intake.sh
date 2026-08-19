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

ENV_FILE="${INTAKE_ENV_FILE:-$HOME/.config/claude-intake/env}"
REPO_DIR="${INTAKE_REPO_DIR:-$HOME/Source/claude-skills}"
LOG_FILE="${INTAKE_LOG:-$HOME/.config/claude-intake/intake.log}"
LOCK_DIR="${INTAKE_LOCK:-$HOME/.config/claude-intake/.lock}"
LABEL="${INTAKE_LABEL:-claude-intake}"
WORKTREE_ROOT="${INTAKE_WORKTREE_ROOT:-}"   # default: sibling of REPO_DIR

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
[ -d "$REPO_DIR/.git" ] || die "not a git repo: $REPO_DIR" 1

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

# --------------------------------------------------------------------- repo
cd "$REPO_DIR" || die "cannot cd to $REPO_DIR" 1
REPO_SLUG="${REPO_OVERRIDE:-$("$GH_BIN" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)}"
[ -n "$REPO_SLUG" ] || die "could not determine repo (gh auth? no GitHub remote?)" 1
[ -n "$WORKTREE_ROOT" ] || WORKTREE_ROOT="$(dirname "$REPO_DIR")"

log "unattended intake starting — repo=$REPO_SLUG label=$LABEL dry-run=$DRY_RUN"

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
    [ -n "$ISSUES" ] || { log "issue #$ONLY_ISSUE is not open with label '$LABEL' (use --force-issue to override)"; exit 0; }
  fi
else
  ISSUES="$("$GH_BIN" issue list --state open --label "$LABEL" --limit 100 \
              --json number -q '.[].number' 2>/dev/null || true)"
fi

if [ -z "$ISSUES" ]; then
  log "nothing labelled '$LABEL' — nothing to do"
  exit 0
fi

log "issues to process: $(printf '%s' "$ISSUES" | tr '\n' ' ')"

# ------------------------------------------------------------------ process
FAILED=0

for N in $ISSUES; do
  TITLE="$("$GH_BIN" issue view "$N" --json title -q .title 2>/dev/null || echo '(unknown)')"
  log "--- issue #$N: $TITLE"

  # Next free epic number, claimed at draft time. A collision is resolved by
  # renumbering at approval; the PR body says so.
  LAST="$(ls -d docs/epics/[0-9][0-9]-* 2>/dev/null | sed 's|.*/||; s|-.*||' | sort -n | tail -1)"
  [ -n "$LAST" ] || LAST=00
  NEXT="$(printf '%02d' $((10#$LAST + 1)))"
  SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' \
            | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-48)"
  [ -n "$SLUG" ] || SLUG="issue-$N"
  BRANCH="intake/${NEXT}-${SLUG}"
  WT="$WORKTREE_ROOT/$(basename "$REPO_DIR")-${NEXT}-${SLUG}"

  if [ "$DRY_RUN" = yes ]; then
    log "DRY-RUN: would create worktree $WT on $BRANCH"
    log "DRY-RUN: would run headless intake for #$N producing docs/epics/${NEXT}-${SLUG}/plan.md at Status: planning"
    log "DRY-RUN: would open a PR (Part of #$N, no Closes), comment the link, and remove label '$LABEL'"
    continue
  fi

  "$GIT_BIN" switch -q main 2>/dev/null || true
  "$GIT_BIN" pull -q --ff-only 2>/dev/null || true

  if ! "$GIT_BIN" worktree add -q "$WT" -b "$BRANCH" main 2>/dev/null; then
    log "ERROR #$N: could not create worktree $WT on $BRANCH"
    FAILED=1
    continue
  fi

  # Phase 0 + Phase 1 only. The prompt restates the hard stops because the
  # model is the thing being constrained, and a headless run has no one to ask.
  PROMPT="Run unattended intake for GitHub issue #$N in this repository.

Follow the dev-epic-workflow skill's unattended-intake contract in
Skills/dev-epic-workflow/references/issue-intake.md. Run ONLY Phase 0 (ground
the work by reading the actual code and config) and Phase 1 (draft the plan).

Write the plan to docs/epics/${NEXT}-${SLUG}/plan.md using the structure in
Skills/dev-epic-workflow/references/plan-template.md, with:
  **Status:** planning
  **Source:** GH #$N

HARD STOPS — you are running unattended and nobody can approve anything:
  - Do NOT set Status to approved. It is a proposal, not a filed epic.
  - Do NOT dispatch any executor or subagent.
  - Do NOT write, modify, or delete any code outside docs/epics/${NEXT}-${SLUG}/.
  - Do NOT merge anything, and do NOT close the issue.
  - Do NOT git push, do NOT open a PR — the runner does that.
Commit the plan with a conventional message and stop."

  ( cd "$WT" && "$CLAUDE_BIN" -p "$PROMPT" \
      --allowed-tools 'Bash(git:*)' 'Bash(gh issue view:*)' 'Bash(ls:*)' 'Bash(find:*)' 'Bash(grep:*)' 'Bash(sed:*)' 'Bash(cat:*)' 'Bash(head:*)' 'Bash(date:*)' Read Write Edit Glob Grep ) \
      > "$WT/.intake-run.log" 2>&1
  RC=$?

  if [ $RC -ne 0 ]; then
    log "ERROR #$N: headless run exited $RC — see $WT/.intake-run.log"
    "$GH_BIN" issue comment "$N" --body "Unattended intake failed (exit $RC). The \`$LABEL\` label has been removed so this does not retry automatically; re-apply it to try again." >/dev/null 2>&1 || true
    "$GH_BIN" issue edit "$N" --remove-label "$LABEL" >/dev/null 2>&1 || true
    "$GIT_BIN" worktree remove --force "$WT" 2>/dev/null || true
    "$GIT_BIN" branch -D "$BRANCH" 2>/dev/null || true
    FAILED=1
    continue
  fi

  if ! "$GIT_BIN" -C "$WT" log --oneline main.."$BRANCH" 2>/dev/null | grep -q .; then
    log "ERROR #$N: headless run produced no commit"
    "$GH_BIN" issue comment "$N" --body "Unattended intake produced no plan. The \`$LABEL\` label has been removed so this does not retry automatically." >/dev/null 2>&1 || true
    "$GH_BIN" issue edit "$N" --remove-label "$LABEL" >/dev/null 2>&1 || true
    "$GIT_BIN" worktree remove --force "$WT" 2>/dev/null || true
    "$GIT_BIN" branch -D "$BRANCH" 2>/dev/null || true
    FAILED=1
    continue
  fi

  "$GIT_BIN" -C "$WT" push -q -u origin "$BRANCH" 2>/dev/null || {
    log "ERROR #$N: push failed"; FAILED=1; continue; }

  PR_URL="$("$GH_BIN" pr create --base main --head "$BRANCH" \
      --title "intake: proposed epic ${NEXT}-${SLUG} (from #$N)" \
      --body "Proposed epic plan drafted by **unattended intake** from #$N.

**This is a proposal, not a filed epic.** The plan is at \`**Status:** planning\`, which is never dispatchable. Approving means merging this PR **and** setting \`**Status:** approved\` — until that edit lands it is a draft that happens to be version-controlled.

Epic number \`${NEXT}\` was claimed at draft time; if it collides with an epic filed since, renumber at approval.

Nothing was approved, dispatched, merged, or closed by this run. No code outside \`docs/epics/${NEXT}-${SLUG}/\` was touched.

Part of #$N" 2>/dev/null || true)"

  if [ -z "$PR_URL" ]; then
    log "ERROR #$N: PR creation failed"
    FAILED=1
    continue
  fi

  "$GH_BIN" issue comment "$N" --body "Unattended intake drafted a proposed epic plan: $PR_URL

It is at \`Status: planning\` — not approved, not dispatchable. Review the PR; approve by merging it and setting \`Status: approved\`." >/dev/null 2>&1 || true
  "$GH_BIN" issue edit "$N" --remove-label "$LABEL" >/dev/null 2>&1 || true

  log "#$N -> $PR_URL (label removed)"
  "$GIT_BIN" worktree remove --force "$WT" 2>/dev/null || true
done

if [ "$FAILED" -ne 0 ]; then
  log "finished with failures"
  exit 4
fi

log "finished"
exit 0
