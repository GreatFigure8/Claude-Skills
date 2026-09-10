#!/usr/bin/env bash
# epic-loop.sh — the driver skeleton for epic 19 (epic-loop), item 1.
#
# THE SHAPE THIS ITEM BUILDS, AND NOTHING MORE. An admitted GitHub issue is
# carried through dev-epic-workflow as a chain of fresh headless sessions — but
# every session that does that work (drafting, dispatching, verifying, merging,
# closing) is a LATER item of this epic. This file is the bash skeleton that
# will run them: a per-issue state machine, a phase dispatcher that checks
# STOP/AUTONOMY-OFF/budget before touching anything, and a `--dry-run` mode
# that prints the sequence of phases and the command each one would run.
#
#   THIS BUILD NEVER INVOKES CLAUDE. Not in dry-run (which only prints), and
#   not for real either: a non-dry-run invocation refuses cleanly, naming the
#   later item that will fill in each phase's real implementation. See
#   `epic_loop_process_issue` below — there is exactly one place a real
#   `claude -p` call could be added, and it is not reachable from this build.
#
# STATES, in the order the plan (docs/epics/19-epic-loop/plan.md) declares
# them:
#
#   picked -> drafting -> awaiting-approval -> approved -> dispatching(item N)
#   -> awaiting-verify -> awaiting-merge -> merged(item N) -> closing -> closed
#   | blocked | refused
#
# `merged(item N)` either advances to `dispatching(item N+1)` — the next
# undispatched item of the SAME epic — or to `closing` when there is none.
# `refused` is still not reachable by this build. `blocked` became reachable
# in item 5: a cold verifier `fail` verdict at `awaiting-verify` routes there
# for real (`epic_loop_verify_gate` below) and is never auto-retried — a human
# resolves it. Both states were already in this file's vocabulary before that,
# because a reader — this file's own `epic_loop_next_state` included — had to
# already know they are terminal.
#
# PER-ISSUE STATE, one file per issue, named for the issue number, living
# beside the reserved intake status tree so it is protected by the SAME
# leading-dot / no-plan.md / self-ignoring-gitignore guarantees
# `intake-status.sh` already built and documented (GH #9, GH #11):
#
#   <repo-root>/<epics-dir>/.intake/loop/<issue>.json      one record per issue
#   <repo-root>/<epics-dir>/.intake/loop/ledger.jsonl      append-only, one
#                                                           line per transition
#
# `<repo-root>` is resolved the canonical way — the main checkout, never a
# worktree — by `intake_status_repo_root`, reused rather than re-implemented.
#
# WHAT THIS ITEM DELIBERATELY DOES NOT DO:
#   - select a NEW issue to work (that is item 8's "next-issue loop"; this file
#     only advances an issue that ALREADY has a state file, however it got one)
#   - decide whether a phase is ALLOWED at the repo's granted level — the
#     `may-approve` / `may-merge` / `may-chain` predicates are item 2's, and do
#     not exist yet. `--dry-run` previews the happy-path sequence regardless,
#     and says so; it is a preview of the shape, not a claim about permission.
#   - run any real `claude -p` session, or touch `dispatch.sh`'s internals.
#
# WHAT IT DOES READ FROM `dispatch.sh` (A3, epic 19's grounding): the plan
# parser, `dispatch_work_items`, and its field separator `DISPATCH_FS`, so that
# "what is the next undispatched item of this epic" is answered exactly once,
# by the same code `dispatch.sh` itself uses — never a second, drifting copy.
# `dispatch.sh` is sourced read-only; nothing here calls anything that cuts a
# worktree, pushes a branch, or opens a pull request.
#
# Usage:
#   epic-loop.sh --repo <path> [--once] [--max-issues N] [--dry-run]
#
#   --repo <path>    the target checkout (required)
#   --once           accepted; a single pass over the discovered issues is the
#                     only mode this build has — the same convention
#                     unattended-intake.sh states for its own --once
#   --max-issues N   cap on DISTINCT issues advanced this invocation (default:
#                     every non-terminal issue found). Independent of
#                     autonomy.sh's own `budget.max-items` / `max-wall-clock`,
#                     which are checked per PHASE below and are not this flag.
#   --dry-run        preview the phase sequence; writes the per-issue state
#                     file and ledger (that bookkeeping is the thing being
#                     demonstrated), never invokes claude, never calls `gh` or
#                     `git` in a way that mutates anything outside the
#                     `.intake/loop` tree.
#
# Exit codes: 0 ok (including "nothing to do" and STOP observed)
#             1 usage error, or a required library could not be sourced
#             2 a non-dry-run invocation reached a phase with no real
#               implementation yet (deliberate refusal, not a crash)

set -u

# --------------------------------------------------------------- this build
# The machine-readable contract marker, the sibling of DISPATCH_ENFORCED and
# AUTONOMY_ENFORCED. A fixture greps for it; flipping it to `no` while real
# phase logic exists elsewhere would be a lie a fixture catches.
EPIC_LOOP_CONTRACT=1
EPIC_LOOP_INVOKES_CLAUDE=no

# ------------------------------------------------------------------- binaries
GIT_BIN="${INTAKE_GIT:-/usr/bin/git}"
GH_BIN="${INTAKE_GH:-/opt/homebrew/bin/gh}"
CLAUDE_BIN="${INTAKE_CLAUDE:-$HOME/.local/bin/claude}"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTONOMY_LIB="${INTAKE_AUTONOMY_LIB:-$BIN_DIR/autonomy.sh}"
STATUS_LIB="${INTAKE_STATUS_LIB:-$BIN_DIR/intake-status.sh}"
DISPATCH_LIB="${INTAKE_DISPATCH_LIB:-$BIN_DIR/dispatch.sh}"
# THE PHASE-EXECUTION SEAM (item 3). Not sourced at top level — like
# DISPATCH_LIB above, a phase that actually calls it sources it lazily via
# epic_loop_run_phase_session below, so a build with no reachable real phase
# (this one) never pays for it and never risks it silently becoming reachable.
PHASE_SESSION_BIN="${INTAKE_PHASE_SESSION:-$BIN_DIR/phase-session.sh}"
# ITEM 5's own harness — invoked as an external script by epic_loop_verify_gate
# below, the same "not sourced at top level" discipline as PHASE_SESSION_BIN,
# for the same reason: `awaiting-verify` is the only state that ever reaches it.
VERIFY_ITEM_BIN="${INTAKE_VERIFY_ITEM_BIN:-$BIN_DIR/verify-item.sh}"

EPIC_LOOP_EPICS_DIR="${INTAKE_EPICS_DIR:-docs/epics}"

# ------------------------------------------------------------------- budget
# CYCLE-WIDE, not per issue — the same shape as dispatch.sh's own
# DISPATCH_ITEMS_DONE / DISPATCH_CYCLE_START, and for the same reason: this
# library is loaded once per invocation, so the counters live here rather
# than being threaded through every call.
EPIC_LOOP_DISPATCHED_THIS_CYCLE=0
EPIC_LOOP_CYCLE_START="$(date -u +%s 2>/dev/null || printf '0')"

epic_loop_elapsed() {
  local NOW
  NOW="$(date -u +%s 2>/dev/null || printf '0')"
  case "$NOW$EPIC_LOOP_CYCLE_START" in *[!0-9]*) printf '0'; return 0 ;; esac
  printf '%s' $((NOW - EPIC_LOOP_CYCLE_START))
}

# ------------------------------------------------------------- the vocabulary
# The happy-path transition table (see header). `merged` is parameterised by
# whether another item exists, because that is the one branch in the arrow
# chain — everything else is a straight line.
EPIC_LOOP_TERMINAL_STATES="closed blocked refused"

epic_loop_is_terminal() { # $1 = state
  case " $EPIC_LOOP_TERMINAL_STATES " in *" ${1:-} "*) return 0 ;; esac
  return 1
}

# $1 = current state, $2 = "yes" if another undispatched item exists (only
# consulted when $1 is `merged`) -> stdout next state, empty when $1 is
# terminal or unrecognised.
epic_loop_next_state() {
  case "${1:-}" in
    picked)             printf 'drafting' ;;
    drafting)           printf 'awaiting-approval' ;;
    awaiting-approval)  printf 'approved' ;;
    approved)           printf 'dispatching' ;;
    dispatching)        printf 'awaiting-verify' ;;
    awaiting-verify)    printf 'awaiting-merge' ;;
    awaiting-merge)     printf 'merged' ;;
    merged)             if [ "${2:-no}" = yes ]; then printf 'dispatching'; else printf 'closing'; fi ;;
    closing)            printf 'closed' ;;
    *)                  printf '' ;;
  esac
}

# The descriptive command each phase WOULD run, once the item that builds it
# lands. Printed, never executed — this is the thing `--dry-run` demonstrates.
# $1=state $2=issue $3=item $4=slug $5=plan-rel(epic field, may be empty)
epic_loop_phase_command() {
  case "${1:-}" in
    picked)
      printf 'bootstrap: issue #%s admitted (selection itself is item 8 — this file only advances an issue that already has a state file)' "${2:-}" ;;
    drafting)
      printf '%s/phase-session.sh drafting-%s.md   # runs one claude -p session (item 3); drafts the epic plan for issue #%s' "$BIN_DIR" "${2:-}" "${2:-}" ;;
    awaiting-approval)
      printf 'park: waiting for may-approve (item 2) at L1+, or a human merge of the proposal PR and an edit to Status: approved (item 4)' ;;
    approved)
      printf 'bookkeeping: Status: approved observed on %s; locating the next undispatched work item' "${5:-<plan.md, not yet known>}" ;;
    dispatching)
      printf '%s/dispatch.sh --select --repo <checkout> --slug %s --epics-dir %s   # item %s (item 6 wires the real invocation; --select already exists, pinned by fixture)' \
        "$BIN_DIR" "${4:-<slug>}" "$EPIC_LOOP_EPICS_DIR" "${3:-N}" ;;
    awaiting-verify)
      printf '%s/verify-item.sh --item %s --pr <url>   # cold acceptance check against the plan'"'"'s DoD and the issue'"'"'s acceptance criteria (item 5)' "$BIN_DIR" "${3:-N}" ;;
    awaiting-merge)
      printf 'park: waiting for may-merge (item 2) at L3+, or a human merge of item %s'"'"'s pull request (item 6)' "${3:-N}" ;;
    merged)
      printf 'bookkeeping: land-and-reset for item %s — pull, delete branch, remove worktree, tick checklist (item 6)' "${3:-N}" ;;
    closing)
      printf 'bookkeeping: Status: closed on the integration branch, retro comment, gh issue close if not already closed (item 7)' ;;
    closed)
      printf '' ;;
    *)
      printf '' ;;
  esac
}

# ---------------------------------------------------- the phase-execution seam
# THE ONE PLACE a real `claude -p` call is wired in — item 1's header named
# this exact spot ("there is exactly one place a real `claude -p` call could
# be added, and it is not reachable from this build"). Item 3 fills it in:
# given a brief file a phase-specific caller has ALREADY written (items 4-8 —
# none of them exist yet, so nothing below calls this function today), run it
# through phase-session.sh and hand back what it decided about
# `docs/epics/handoff.md`. This wrapper embeds NO phase judgement of its own —
# no drafting, no approval, no dispatch, no verify, no merge logic — it is a
# thin pass-through to the harness item 3 actually built
# (`phase-session.sh`), exactly item 3's own scope ("the harness that runs *a*
# session and manages the handoff file around it").
#
# $1 = brief-file (already written by the caller)  $2 = repo checkout the
# session should run in  $3 = state-file (the per-issue state JSON, for
# phase-session.sh's fallback-handoff derivation, or "" to omit)
# $4 = epic-relative plan path (for the fallback's Epic field, or "" to omit)
# -> stdout phase-session.sh's own output; rc = its own exit code (0 unless a
# usage error or a disk failure — see phase-session.sh's own header for its
# "never fail outright on a bad session" contract).
epic_loop_run_phase_session() {
  local BRIEF="${1:-}" REPO="${2:-}" SF="${3:-}" EPIC="${4:-}"
  [ -r "$PHASE_SESSION_BIN" ] || { printf 'epic-loop: cannot read phase-session harness: %s\n' "$PHASE_SESSION_BIN" >&2; return 1; }
  if [ -n "$SF" ] && [ -n "$EPIC" ]; then
    bash "$PHASE_SESSION_BIN" "$BRIEF" --repo "$REPO" --state-file "$SF" --epic "$EPIC"
  elif [ -n "$SF" ]; then
    bash "$PHASE_SESSION_BIN" "$BRIEF" --repo "$REPO" --state-file "$SF"
  elif [ -n "$EPIC" ]; then
    bash "$PHASE_SESSION_BIN" "$BRIEF" --repo "$REPO" --epic "$EPIC"
  else
    bash "$PHASE_SESSION_BIN" "$BRIEF" --repo "$REPO"
  fi
}

# ---------------------------------------------------------- the plan lookup
# Answers "what is the next work item of this epic after $3", by parsing the
# SAME plan.md with the SAME parser dispatch.sh itself uses
# (`dispatch_work_items`, sourced below, read-only). $1 = repo root,
# $2 = epic-relative plan path (as recorded in the state file's "epic" field,
# e.g. "docs/epics/93-.../plan.md"), $3 = current item id. Empty stdout when
# there is no epic recorded, no readable plan, or no item after $3 — any of
# which the caller reads as "no more items, go to closing".
epic_loop_next_item() {
  local ROOT="${1:-}" PLAN_REL="${2:-}" CUR="${3:-}" PLAN
  [ -n "$PLAN_REL" ] || return 0
  PLAN="$ROOT/$PLAN_REL"
  [ -r "$PLAN" ] || return 0
  command -v dispatch_work_items >/dev/null 2>&1 || return 0
  local ID BR GT DEP TITLE FOUND=no NEXT=""
  while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
    [ -n "${ID:-}" ] || continue
    if [ "$FOUND" = yes ]; then NEXT="$ID"; break; fi
    [ "$ID" = "$CUR" ] && FOUND=yes
  done <<ITEMS_EOF
$(dispatch_work_items < "$PLAN")
ITEMS_EOF
  printf '%s' "$NEXT"
}

# The FIRST item id of the plan, same parser, same read-only sourcing. Used at
# `approved -> dispatching` so the item number written is the plan's actual
# first item (`1`, `2b`, whatever it is written as) rather than an assumed
# literal `1` — that assumption is only the fallback, for a state file with no
# `epic` recorded at all (every fixture that exercises this build directly,
# rather than through a real plan).
epic_loop_first_item() { # $1 = repo root, $2 = epic-relative plan path -> stdout id or empty
  local ROOT="${1:-}" PLAN_REL="${2:-}" PLAN
  [ -n "$PLAN_REL" ] || return 0
  PLAN="$ROOT/$PLAN_REL"
  [ -r "$PLAN" ] || return 0
  command -v dispatch_work_items >/dev/null 2>&1 || return 0
  local ID BR GT DEP TITLE
  while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
    [ -n "${ID:-}" ] || continue
    printf '%s' "$ID"
    return 0
  done <<ITEMS_EOF
$(dispatch_work_items < "$PLAN")
ITEMS_EOF
  return 0
}

# --------------------------------------------------------- the approval gate
# ITEM 4. The one phase this build gives a REAL (non-dry-run) implementation:
# `awaiting-approval`. Everything else still refuses exactly as item 1 left
# it — see the DRY-run branch in `epic_loop_process_issue` below, which only
# carves out this one state.
#
# NOT THIS FILE'S JOB: drafting the proposal. `unattended-intake.sh` already
# opened it (its own hard stop, unchanged) before this state is ever reached;
# this gate only decides what happens to a proposal that already exists.
#
# THE VOCABULARY. `unattended-intake.sh` writes `**Recommendation:** plan |
# no-work | needs-decision` (references/issue-intake.md). The plan's own
# prose for this item calls the approvable one "ready" — that is prose for
# `plan`, not a fourth value; this file reads the real field and never
# invents "ready" as a literal string.
EPIC_LOOP_PROPOSAL_PREFIX="${INTAKE_PROPOSAL_PREFIX:-intake/proposed-}"
EPIC_LOOP_PLAN_HEADER_LINES=10   # same window session-start-context.sh and
                                 # unattended-intake.sh's PLAN_HEADER_LINES use

# stdin = a plan.md's text -> stdout one of plan | no-work | needs-decision.
# The SAME parse unattended-intake.sh applies to its own draft (first-word,
# case-folded, absent reads as `plan`, anything unrecognised reads as
# `needs-decision`) — duplicated rather than sourced, because
# unattended-intake.sh is a top-level script with its own preflight and
# locking, never designed to be sourced (unlike autonomy.sh / dispatch.sh /
# intake-status.sh, which this file DOES source).
epic_loop_parse_recommendation() {
  local RAW REC
  RAW="$(head -"$EPIC_LOOP_PLAN_HEADER_LINES" 2>/dev/null \
           | sed -n -E -e 's/^[[:space:]*_]*[Rr]ecommendation:[[:space:]*_]*//p' \
           | head -1 | tr -d '\r')"
  REC="$(printf '%s' "$RAW" | tr '[:upper:]' '[:lower:]' \
           | sed -E -e 's/[^a-z-].*$//' -e 's/^-+//' -e 's/-+$//')"
  case "$REC" in
    plan|no-work|needs-decision) ;;
    '') REC=plan ;;
    *)  REC=needs-decision ;;
  esac
  printf '%s' "$REC"
}

# A NUMBERED (non-`proposed-`) epic folder whose plan.md names $3 as its
# `Source` is FILED — approved already, however that happened: this gate's
# own sequence below, or a human who merged the PR and edited `Status` by
# hand while this driver was not looking. Numbering is assigned ONLY at
# approval (SKILL.md, Phase 1: "the number is assigned when the plan is
# approved"), so a numbered folder's mere existence is the proof; its
# CURRENT Status (approved / in flight / closed) is not re-examined, because
# by the time it has moved past `approved` this gate has nothing left to
# decide anyway — a later item's phase owns what happens next.
# $1 = repo root  $2 = epics-dir (repo-root-relative)  $3 = issue
# -> stdout "<epics-dir>/<NN-slug>/plan.md", rc 1 if none found
epic_loop_find_filed_epic() {
  local ROOT="${1:-}" EPICS_DIR="${2:-}" ISSUE="${3:-}" PLAN DIRNAME SRC
  for PLAN in "$ROOT/$EPICS_DIR"/*/plan.md; do
    [ -r "$PLAN" ] || continue
    DIRNAME="$(basename "$(dirname "$PLAN")")"
    case "$DIRNAME" in proposed-*) continue ;; esac
    SRC="$(head -20 "$PLAN" 2>/dev/null \
             | grep -m1 -Ei 'Source:.*GH[[:space:]]*#[0-9]+' \
             | sed -E 's/.*GH[[:space:]]*#([0-9]+).*/\1/')"
    [ -n "$SRC" ] || continue
    [ "$SRC" = "$ISSUE" ] || continue
    printf '%s/%s/plan.md' "$EPICS_DIR" "$DIRNAME"
    return 0
  done
  return 1
}

# The open proposal PR for issue $2, found the same way
# unattended-intake.sh's own collision check finds its candidates: by BRANCH
# PREFIX, never by title or body text — the branch name is the one thing an
# attended and an unattended run can never disagree about.
# $1 = repo slug  $2 = issue -> stdout "<pr-number> <head-branch>", rc 1 if
# no open PR's head branch matches.
epic_loop_find_proposal_pr() {
  local SLUG="${1:-}" ISSUE="${2:-}" LIST PR BR
  LIST="$("$GH_BIN" pr list --repo "$SLUG" --state open --limit 100 \
            --json number,headRefName -q '.[] | "\(.number) \(.headRefName)"' 2>/dev/null)" || return 1
  while IFS=' ' read -r PR BR; do
    case "${PR:-}" in ''|*[!0-9]*) continue ;; esac
    [ -n "${BR:-}" ] || continue
    case "$BR" in "$EPIC_LOOP_PROPOSAL_PREFIX""$ISSUE"-*) printf '%s %s' "$PR" "$BR"; return 0 ;; esac
  done <<PROPOSAL_PR_LIST_EOF
$LIST
PROPOSAL_PR_LIST_EOF
  return 1
}

# Rewrite ONLY the header's `**Status:**` line to `approved` — the same
# temp-file-verify-mv shape `downgrade_plan_recommendation` in
# unattended-intake.sh uses for its own header rewrite, so a reader who
# already knows that function recognises this one. $1 = plan file.
epic_loop_set_status_approved() {
  local F="${1:-}" TMP
  [ -f "$F" ] || return 1
  TMP="$F.epic-loop-approve.$$"
  awk '
    BEGIN { done = 0 }
    !done && /^\*\*Status:\*\*/ { print "**Status:** approved"; done = 1; next }
    { print }
  ' "$F" > "$TMP" 2>/dev/null || { rm -f "$TMP"; return 1; }
  [ -s "$TMP" ] || { rm -f "$TMP"; return 1; }
  mv "$TMP" "$F" 2>/dev/null || { rm -f "$TMP"; return 1; }
  grep -q '^\*\*Status:\*\* approved$' "$F" || return 1
  return 0
}

# THE GATE ITSELF. $1=repo checkout (the driver's OWN main checkout, per the
# plan's Risks: "the driver works in the repo's main checkout only via gh and
# git pull; executors stay in worktrees" — never a worktree) $2=repo slug
# $3=issue $4=repo root (for reading; equal to $1 in every real and fixture
# use of this file) $5=epics-dir (repo-root-relative).
#
# Sets, for the caller:
#   EPIC_LOOP_GATE_RESULT  approved | parked | error
#   EPIC_LOOP_GATE_EPIC    epics-dir-relative plan path — only when approved
#   EPIC_LOOP_GATE_DETAIL  one line, for the state file and the ledger
#
# rc is always 0 — a parked issue and a failed merge are both things this
# gate REPORTS, never a crash; the caller decides what rc the whole
# invocation carries.
epic_loop_approval_gate() {
  local REPO="${1:-}" SLUG="${2:-}" ISSUE="${3:-}" ROOT="${4:-}" EPICS_DIR="${5:-}"
  EPIC_LOOP_GATE_RESULT=error
  EPIC_LOOP_GATE_EPIC=""
  EPIC_LOOP_GATE_DETAIL="no attempt made"

  # Best-effort sync of the main checkout to whatever it already tracks,
  # BEFORE anything on disk is trusted — never fatal: a transient fetch
  # failure falls through to whatever is already on disk, exactly as if
  # this step had never run.
  "$GIT_BIN" -C "$REPO" fetch origin >/dev/null 2>&1 || true
  local CUR_BR
  CUR_BR="$("$GIT_BIN" -C "$REPO" branch --show-current 2>/dev/null)"
  if [ -n "$CUR_BR" ]; then
    "$GIT_BIN" -C "$REPO" merge --ff-only "origin/$CUR_BR" >/dev/null 2>&1 || true
  fi

  # THE HUMAN MAY HAVE ALREADY DONE THIS. Checked before anything else is
  # asked, so a repo where Jonathan merged the PR and edited `Status` by hand
  # is recognised and carried forward rather than re-decided — the scope's
  # own words: "later cycles must detect the human's merge + `approved` edit
  # and continue from there."
  local FILED
  if FILED="$(epic_loop_find_filed_epic "$ROOT" "$EPICS_DIR" "$ISSUE")"; then
    EPIC_LOOP_GATE_RESULT=approved
    EPIC_LOOP_GATE_EPIC="$FILED"
    EPIC_LOOP_GATE_DETAIL="already approved by a human at $FILED — continuing from there, nothing merged or filed by this gate"
    return 0
  fi

  local PR_LINE PR BR
  PR_LINE="$(epic_loop_find_proposal_pr "$SLUG" "$ISSUE")" || PR_LINE=""
  PR="${PR_LINE%% *}"
  BR="${PR_LINE#* }"
  case "$PR" in ''|*[!0-9]*) PR=""; BR="" ;; esac
  if [ -z "$PR" ]; then
    EPIC_LOOP_GATE_RESULT=parked
    EPIC_LOOP_GATE_DETAIL="no open proposal PR found for issue #$ISSUE (branch ${EPIC_LOOP_PROPOSAL_PREFIX}${ISSUE}-*) — nothing to approve or park differently this cycle"
    return 0
  fi

  local BREST PSLUG PLAN_REL PLAN_TEXT REC
  BREST="${BR#"$EPIC_LOOP_PROPOSAL_PREFIX"}"
  PSLUG="${BREST#"$ISSUE"-}"
  PLAN_REL="$EPICS_DIR/proposed-$ISSUE-$PSLUG/plan.md"
  PLAN_TEXT="$("$GH_BIN" api "repos/$SLUG/contents/$PLAN_REL?ref=$BR" \
                 -H 'Accept: application/vnd.github.raw' 2>/dev/null)"
  if [ -z "$PLAN_TEXT" ]; then
    EPIC_LOOP_GATE_RESULT=parked
    EPIC_LOOP_GATE_DETAIL="PR #$PR is open but its plan at $PLAN_REL@$BR could not be read — parked rather than guessing"
    return 0
  fi
  REC="$(printf '%s' "$PLAN_TEXT" | epic_loop_parse_recommendation)"

  # THE ORDER MATTERS: the recommendation is checked BEFORE `may-approve`, so
  # a `needs-decision` proposal parks at every level including L4 — "never
  # no-work or needs-decision" is unconditional, not something a high enough
  # rung overrides. Only once the recommendation itself is `plan` does the
  # repo's granted level get asked at all.
  local REASON=""
  if [ "$REC" != plan ]; then
    REASON="recommendation is $REC, never auto-approved regardless of level"
  elif ! autonomy_may_approve; then
    REASON="level ${AUTONOMY_LEVEL:-L0} does not grant may-approve"
  fi
  if [ -n "$REASON" ]; then
    EPIC_LOOP_GATE_RESULT=parked
    EPIC_LOOP_GATE_DETAIL="parked at PR #$PR ($BR) — $REASON"
    return 0
  fi

  # ---------------------------------------------- may-approve AND ready
  # Merge first: everything after this point is bookkeeping on a PR that is
  # ALREADY merged, so a failure past here never leaves a merged PR
  # unaccounted for — it leaves an unfinished FILING, which is visible (the
  # folder is still named `proposed-*`) and safely retryable.
  if ! "$GH_BIN" pr merge "$PR" --repo "$SLUG" --merge >/dev/null 2>&1; then
    EPIC_LOOP_GATE_RESULT=parked
    EPIC_LOOP_GATE_DETAIL="may-approve and recommendation=plan at PR #$PR, but the merge itself failed — parked unchanged, retried next cycle"
    return 0
  fi

  "$GIT_BIN" -C "$REPO" fetch origin >/dev/null 2>&1 || true
  if [ -z "$CUR_BR" ] || ! "$GIT_BIN" -C "$REPO" merge --ff-only "origin/$CUR_BR" >/dev/null 2>&1; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="PR #$PR merged on origin, but the local checkout at $REPO could not fast-forward onto it — filing did not complete; fix the checkout and retry"
    return 0
  fi

  if [ ! -d "$REPO/$EPICS_DIR/proposed-$ISSUE-$PSLUG" ]; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="PR #$PR merged, but $EPICS_DIR/proposed-$ISSUE-$PSLUG is not on $CUR_BR after the pull — filing did not complete"
    return 0
  fi

  # THE NUMBER, assigned now and only now (SKILL.md, Phase 1) — the next
  # integer above every NN-slug folder already on the integration branch,
  # zero-padded to two digits (three once a repo passes 99 epics; %02d
  # widens rather than truncates).
  local NEXT_NUM=1 D B N
  for D in "$REPO/$EPICS_DIR"/*/; do
    [ -d "$D" ] || continue
    B="$(basename "$D")"
    case "$B" in
      [0-9]*-*)
        N="${B%%-*}"
        case "$N" in ''|*[!0-9]*) continue ;; esac
        [ "$N" -ge "$NEXT_NUM" ] 2>/dev/null && NEXT_NUM=$((N + 1))
        ;;
    esac
  done
  local NN OLD_DIR NEW_DIR
  NN="$(printf '%02d' "$NEXT_NUM")"
  OLD_DIR="$EPICS_DIR/proposed-$ISSUE-$PSLUG"
  NEW_DIR="$EPICS_DIR/$NN-$PSLUG"

  if ! "$GIT_BIN" -C "$REPO" mv "$OLD_DIR" "$NEW_DIR" 2>/dev/null; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="PR #$PR merged, but git mv $OLD_DIR -> $NEW_DIR failed — filing did not complete"
    return 0
  fi
  if ! epic_loop_set_status_approved "$REPO/$NEW_DIR/plan.md"; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="PR #$PR merged and renamed to $NEW_DIR, but Status could not be set to approved — filing did not complete, fix by hand"
    return 0
  fi
  if ! "$GIT_BIN" -C "$REPO" add "$NEW_DIR" >/dev/null 2>&1 \
     || ! "$GIT_BIN" -C "$REPO" commit -q -m "docs(epic): file $NN-$PSLUG — approved via epic-loop (L1 auto-approve, issue #$ISSUE)" >/dev/null 2>&1; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="PR #$PR merged and renamed to $NEW_DIR, but the filing commit failed — filing did not complete, fix by hand"
    return 0
  fi
  if ! "$GIT_BIN" -C "$REPO" push -q origin "$CUR_BR" >/dev/null 2>&1; then
    EPIC_LOOP_GATE_RESULT=error
    EPIC_LOOP_GATE_DETAIL="filed $NEW_DIR locally but the push to origin/$CUR_BR failed — the commit exists locally; retry the push"
    return 0
  fi

  local SHA PERMALINK
  SHA="$("$GIT_BIN" -C "$REPO" rev-parse HEAD 2>/dev/null)"
  PERMALINK="https://github.com/$SLUG/blob/${SHA:-$CUR_BR}/$NEW_DIR/plan.md"

  # Label and comment are best-effort, matching unattended-intake.sh's own
  # `|| true` on its issue comment/label calls: the epic IS filed by this
  # point regardless of whether GitHub's side of the bookkeeping lands.
  "$GH_BIN" issue edit "$ISSUE" --repo "$SLUG" --add-label epic:planned >/dev/null 2>&1 || true
  "$GH_BIN" issue comment "$ISSUE" --repo "$SLUG" \
    --body "Epic filed: $NEW_DIR/plan.md — $PERMALINK

Approved by epic-loop's L1 approval gate: PR #$PR merged, \`**Status:** planning\` set to \`approved\`, numbered $NEW_DIR." >/dev/null 2>&1 || true

  EPIC_LOOP_GATE_RESULT=approved
  EPIC_LOOP_GATE_EPIC="$NEW_DIR/plan.md"
  EPIC_LOOP_GATE_DETAIL="approved via L1 auto-approve — PR #$PR merged, filed at $NEW_DIR, epic:planned applied, permalink commented on #$ISSUE"
  return 0
}

# ------------------------------------------------------------ the verify gate
# ITEM 5. Real (non-dry-run) implementation of `awaiting-verify`: locate the
# item's own open pull request by its DECLARED branch (same parser,
# `dispatch_work_items`, sourced read-only, that `epic_loop_next_item` /
# `epic_loop_first_item` above already use), then hand everything else —
# the four deterministic gates, the cold verifier session, the verdict
# comment — to `verify-item.sh`, exactly the phase-execution seam item 3
# built for a caller like this one. This function embeds NO verify judgement
# of its own: it only finds the PR and translates verify-item.sh's exit code
# into a state transition, the same shape epic_loop_approval_gate already
# uses for `awaiting-approval`.

# The declared BRANCH of one work item, same parser/read-only sourcing as
# epic_loop_first_item / epic_loop_next_item above. $1=repo root
# $2=epic-relative plan path $3=item id -> stdout branch name or empty.
epic_loop_item_branch() {
  local ROOT="${1:-}" PLAN_REL="${2:-}" ITEM="${3:-}" PLAN
  [ -n "$PLAN_REL" ] || return 0
  PLAN="$ROOT/$PLAN_REL"
  [ -r "$PLAN" ] || return 0
  command -v dispatch_work_items >/dev/null 2>&1 || return 0
  local ID BR GT DEP TITLE
  while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
    [ -n "${ID:-}" ] || continue
    if [ "$ID" = "$ITEM" ]; then printf '%s' "$BR"; return 0; fi
  done <<ITEMS_EOF
$(dispatch_work_items < "$PLAN")
ITEMS_EOF
  return 0
}

# The open PR whose head branch is EXACTLY the item's declared branch — never
# a prefix match, unlike epic_loop_find_proposal_pr's `intake/proposed-N-*`
# search: item branches are one-to-one with work items, not a namespaced
# family sharing a common prefix. $1=slug $2=branch -> stdout
# "<pr-number> <url>", rc 1 if no open PR's head branch matches.
epic_loop_find_item_pr() {
  local SLUG="${1:-}" BR="${2:-}" LIST PR HEAD URLV
  [ -n "$BR" ] || return 1
  LIST="$("$GH_BIN" pr list --repo "$SLUG" --state open --limit 100 \
            --json number,headRefName,url -q '.[] | "\(.number) \(.headRefName) \(.url)"' 2>/dev/null)" || return 1
  while IFS=' ' read -r PR HEAD URLV; do
    case "${PR:-}" in ''|*[!0-9]*) continue ;; esac
    [ -n "${HEAD:-}" ] || continue
    [ "$HEAD" = "$BR" ] && { printf '%s %s' "$PR" "$URLV"; return 0; }
  done <<ITEM_PR_LIST_EOF
$LIST
ITEM_PR_LIST_EOF
  return 1
}

# THE GATE ITSELF. $1=repo checkout $2=repo slug $3=issue $4=repo root
# $5=epics-dir $6=epic-relative plan path $7=item id $8=per-issue state file
# path (may be empty).
#
# Sets, for the caller:
#   EPIC_LOOP_VERIFY_RESULT   pass | fail | parked | error
#   EPIC_LOOP_VERIFY_DETAIL   one line, for the state file and the ledger
#
# rc is always 0 — same contract as epic_loop_approval_gate: a parked issue
# and a failed verify are both things this gate REPORTS, never a crash.
epic_loop_verify_gate() {
  local REPO="${1:-}" SLUG="${2:-}" ISSUE="${3:-}" ROOT="${4:-}" EPICS_DIR="${5:-}"
  local PLAN_REL="${6:-}" ITEM="${7:-}" SF="${8:-}"
  EPIC_LOOP_VERIFY_RESULT=error
  EPIC_LOOP_VERIFY_DETAIL="no attempt made"
  : "$EPICS_DIR"  # not needed once PLAN_REL is already epics-dir-relative

  if [ -z "$PLAN_REL" ] || [ -z "$ITEM" ]; then
    EPIC_LOOP_VERIFY_DETAIL="no epic/item recorded for issue #$ISSUE — cannot know which PR to verify"
    return 0
  fi

  local BR
  BR="$(epic_loop_item_branch "$ROOT" "$PLAN_REL" "$ITEM")"
  if [ -z "$BR" ]; then
    EPIC_LOOP_VERIFY_DETAIL="item $ITEM has no declared branch in $PLAN_REL — cannot look up its PR"
    return 0
  fi

  "$GIT_BIN" -C "$REPO" fetch origin >/dev/null 2>&1 || true

  local PR_LINE PR
  PR_LINE="$(epic_loop_find_item_pr "$SLUG" "$BR")" || PR_LINE=""
  PR="${PR_LINE%% *}"
  case "$PR" in ''|*[!0-9]*) PR="" ;; esac
  if [ -z "$PR" ]; then
    EPIC_LOOP_VERIFY_RESULT=parked
    EPIC_LOOP_VERIFY_DETAIL="no open PR found for item $ITEM's branch $BR — nothing to verify this cycle"
    return 0
  fi

  if [ ! -r "$VERIFY_ITEM_BIN" ]; then
    EPIC_LOOP_VERIFY_DETAIL="cannot read verify-item harness: $VERIFY_ITEM_BIN"
    return 0
  fi

  local OUT RC
  if [ -n "$SF" ]; then
    OUT="$(bash "$VERIFY_ITEM_BIN" --plan "$ROOT/$PLAN_REL" --item "$ITEM" --pr "$PR" \
             --repo "$REPO" --slug "$SLUG" --issue "$ISSUE" --state-file "$SF" --epic "$PLAN_REL" 2>&1)"
  else
    OUT="$(bash "$VERIFY_ITEM_BIN" --plan "$ROOT/$PLAN_REL" --item "$ITEM" --pr "$PR" \
             --repo "$REPO" --slug "$SLUG" --issue "$ISSUE" --epic "$PLAN_REL" 2>&1)"
  fi
  RC=$?
  EPIC_LOOP_VERIFY_DETAIL="$(printf '%s\n' "$OUT" | tail -1)"
  [ -n "$EPIC_LOOP_VERIFY_DETAIL" ] || EPIC_LOOP_VERIFY_DETAIL="verify-item.sh exited $RC with no output"
  case "$RC" in
    0)   EPIC_LOOP_VERIFY_RESULT=pass ;;
    1)   EPIC_LOOP_VERIFY_RESULT=fail ;;
    2|3) EPIC_LOOP_VERIFY_RESULT=parked ;;
    *)   EPIC_LOOP_VERIFY_RESULT=error ;;
  esac
  return 0
}

# --------------------------------------------------------------- the state tree
# Reuses intake_status_tree for its three guarantees (leading dot, refuses a
# plan.md ever appearing under `.intake`, self-ignoring `.gitignore`) rather
# than re-deriving them, then creates a SIBLING `loop/` directory under the
# same `.intake` base — the same base `intake-status.sh`'s own `.gitignore`
# (containing a single `*`) already covers, whether or not that library has
# ever run in this repo.
epic_loop_state_dir() { # $1 = repo root -> stdout dir, rc 1 on refusal
  local ROOT="${1:-}" BASE DIR
  intake_status_tree "$ROOT" "$EPIC_LOOP_EPICS_DIR" >/dev/null 2>&1 || return 1
  [ -n "$INTAKE_STATUS_TREE_OUT" ] || return 1
  BASE="$(dirname "$INTAKE_STATUS_TREE_OUT")"
  DIR="$BASE/loop"
  mkdir -p "$DIR" 2>/dev/null || return 1
  printf '%s' "$DIR"
}

# ------------------------------------------------------------- read / write
# ONE KEY PER LINE, grep-and-sed, the same shape `dispatch_read_executor_status`
# reads a status.json with — no jq dependency for a local file this size.
epic_loop_state_read() { # $1 = path -> sets EPIC_LOOP_R_*, rc 1 if unreadable
  local F="${1:-}"
  EPIC_LOOP_R_ISSUE=""; EPIC_LOOP_R_REPO=""; EPIC_LOOP_R_EPIC=""
  EPIC_LOOP_R_STATE=""; EPIC_LOOP_R_ITEM=""; EPIC_LOOP_R_DETAIL=""
  [ -r "$F" ] || return 1
  EPIC_LOOP_R_ISSUE="$(grep -o '"issue"[[:space:]]*:[[:space:]]*[0-9]*' "$F" 2>/dev/null | head -1 | grep -o '[0-9]*$')"
  EPIC_LOOP_R_REPO="$(grep -o '"repo"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  EPIC_LOOP_R_EPIC="$(grep -o '"epic"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  EPIC_LOOP_R_STATE="$(grep -o '"state"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  EPIC_LOOP_R_ITEM="$(grep -o '"item"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  EPIC_LOOP_R_DETAIL="$(grep -o '"detail"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  [ -n "$EPIC_LOOP_R_STATE" ] || return 1
  return 0
}

# Atomic write via `intake_status_atomic` (temp file beside the target, then
# `mv`) — reused rather than re-implemented, same guarantee: no reader ever
# sees a half-written record. $1 = RESOLVED absolute target path (visible at
# every call site, per GH #63), $2=issue $3=repo $4=epic(or empty) $5=state
# $6=item(or empty) $7=detail
epic_loop_state_write() {
  local T="${1:-}"
  [ -n "$T" ] || return 1
  local BODY
  BODY="$( {
    printf '{\n'
    printf '  "issue": %s,\n' "${2:-null}"
    printf '  "repo": "%s",\n' "$(intake_status_escape "${3:-}")"
    if [ -n "${4:-}" ]; then printf '  "epic": "%s",\n' "$(intake_status_escape "${4}")"; else printf '  "epic": null,\n'; fi
    printf '  "state": "%s",\n' "$(intake_status_escape "${5:-}")"
    if [ -n "${6:-}" ]; then printf '  "item": "%s",\n' "$(intake_status_escape "${6}")"; else printf '  "item": null,\n'; fi
    printf '  "detail": "%s",\n' "$(intake_status_escape "${7:-}")"
    printf '  "updated": "%s"\n' "$(intake_status_now)"
    printf '}\n'
  } )"
  printf '%s' "$BODY" | intake_status_atomic "$T"
}

# One line per transition, append-only, never rewritten — the durable trail
# underneath the per-issue file, in the same spirit as `intake_status_ledger`.
# $1=state-dir $2=issue $3=repo $4=from $5=to $6=detail
epic_loop_ledger() {
  local DIR="${1:-}"
  [ -n "$DIR" ] || return 0
  printf '{"ts":"%s","issue":%s,"repo":"%s","from":"%s","to":"%s","detail":"%s"}\n' \
    "$(intake_status_now)" "${2:-null}" "$(intake_status_escape "${3:-}")" \
    "$(intake_status_escape "${4:-}")" "$(intake_status_escape "${5:-}")" \
    "$(intake_status_escape "${6:-}")" >> "$DIR/ledger.jsonl" 2>/dev/null || true
  return 0
}

# ------------------------------------------------------------- the phase loop
# ONE ISSUE, phase by phase, checking STOP at the top of EVERY iteration —
# before the state is even read — so a STOP that appears between two phases
# is honoured before the next one starts, whatever this invocation had
# already done. `--dry-run` walks all the way to a terminal state in one
# process (a genuine chain of phase boundaries, matching the epic's Outcome);
# a real invocation stops at the first phase, because no phase has a real
# implementation in this build (see the header).
#
# rc 0 = advanced as far as this cycle allows (terminal, parked by STOP, or
#        budget exhausted) — never a failure
# rc 2 = a non-dry-run invocation reached a phase with no implementation yet
epic_loop_process_issue() { # $1=issue $2=repo-checkout $3=slug $4=state-dir $5=repo-root $6=dry-run(yes|no)
  local ISSUE="${1:-}" REPO="${2:-}" SLUG="${3:-}" STATE_DIR="${4:-}" ROOT="${5:-}" DRY="${6:-no}"
  local TARGET="$STATE_DIR/$ISSUE.json"
  local CUR_STATE CUR_ITEM CUR_EPIC CUR_DETAIL NEXT WRITE_ITEM NEXT_ITEM CMD PHASES=0

  while :; do
    if autonomy_stop_requested; then
      printf 'STOP: cycle stop file present at %s — halting between phases; issue #%s is left exactly as last written\n' \
        "$AUTONOMY_STOP_FILE" "$ISSUE"
      epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" "" "" "STOP observed — no phase run this cycle"
      return 0
    fi

    if ! epic_loop_state_read "$TARGET"; then
      CUR_STATE=picked; CUR_ITEM=""; CUR_EPIC=""; CUR_DETAIL="issue admitted"
      epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "" "$CUR_STATE" "" "$CUR_DETAIL" || true
      epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" "" "$CUR_STATE" "bootstrap"
    else
      CUR_STATE="$EPIC_LOOP_R_STATE"; CUR_ITEM="$EPIC_LOOP_R_ITEM"
      CUR_EPIC="$EPIC_LOOP_R_EPIC"; CUR_DETAIL="$EPIC_LOOP_R_DETAIL"
    fi

    if epic_loop_is_terminal "$CUR_STATE"; then
      printf 'issue #%s is %s — nothing to do\n' "$ISSUE" "$CUR_STATE"
      return 0
    fi

    # Level and budget both come from autonomy.sh's config, so it is resolved
    # (which loads that config) BEFORE either is consulted — the reverse order
    # reads AUTONOMY_BUDGET_MAX_ITEMS/_SECONDS before autonomy_load has ever
    # set them. `may-approve` (item 4, below) reads AUTONOMY_LEVEL set here;
    # every other state still only logs the level — `--dry-run` previews the
    # happy path regardless of level and says so in its own output.
    autonomy_resolve "$REPO" "$SLUG" || true

    # Wall-clock budget, checked every phase: a cycle running long is a cycle
    # running long whatever phase it is in.
    if ! autonomy_budget_allows_time "$(epic_loop_elapsed)"; then
      printf 'epic-loop: issue #%s — no further phase this cycle: %s\n' "$ISSUE" "${AUTONOMY_REFUSAL:-budget}"
      return 0
    fi
    # The per-cycle ITEM budget (epic 11's "one item at a time" invariant) is
    # about work items actually DISPATCHED, not about every bookkeeping phase
    # of this loop — so it is asked only where a phase corresponds to that:
    # `dispatching`. Counted across every issue this invocation touches
    # (EPIC_LOOP_DISPATCHED_THIS_CYCLE is a script-global, not `local`),
    # exactly as dispatch.sh's own DISPATCH_ITEMS_DONE is cycle-wide rather
    # than per repo.
    if [ "$CUR_STATE" = dispatching ] && ! autonomy_budget_allows_item "$EPIC_LOOP_DISPATCHED_THIS_CYCLE"; then
      printf 'epic-loop: issue #%s — no further dispatch this cycle: %s\n' "$ISSUE" "${AUTONOMY_REFUSAL:-budget}"
      return 0
    fi

    CMD="$(epic_loop_phase_command "$CUR_STATE" "$ISSUE" "$CUR_ITEM" "$SLUG" "$CUR_EPIC")"

    if [ "$DRY" != yes ]; then
      # ITEM 4's one real phase. Every other state below still refuses —
      # see the fallback at the end of this block, unchanged from item 1.
      if [ "$CUR_STATE" = awaiting-approval ]; then
        epic_loop_approval_gate "$REPO" "$SLUG" "$ISSUE" "$ROOT" "$EPIC_LOOP_EPICS_DIR"
        case "$EPIC_LOOP_GATE_RESULT" in
          approved)
            printf 'epic-loop: issue #%s — approval gate: %s\n' "$ISSUE" "$EPIC_LOOP_GATE_DETAIL"
            epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$EPIC_LOOP_GATE_EPIC" approved "" "$EPIC_LOOP_GATE_DETAIL" || true
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-approval approved "$EPIC_LOOP_GATE_DETAIL"
            # Loop again rather than returning: STOP is honoured again at the
            # top before anything else runs, exactly as every other
            # transition in this loop already does. The NEXT iteration reads
            # state=approved, for which this build (like every state but
            # awaiting-approval) has no real implementation — it refuses
            # below with rc 2, correctly: this item files the epic, it does
            # not dispatch it.
            continue
            ;;
          parked)
            printf 'epic-loop: issue #%s — approval gate parked: %s\n' "$ISSUE" "$EPIC_LOOP_GATE_DETAIL"
            epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$CUR_EPIC" awaiting-approval "" "$EPIC_LOOP_GATE_DETAIL" || true
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-approval awaiting-approval "$EPIC_LOOP_GATE_DETAIL"
            return 0
            ;;
          *)
            printf 'epic-loop: issue #%s — approval gate error: %s\n' "$ISSUE" "$EPIC_LOOP_GATE_DETAIL" >&2
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-approval awaiting-approval "ERROR: $EPIC_LOOP_GATE_DETAIL"
            return 0
            ;;
        esac
      fi
      # ITEM 5's one real phase. `pass` advances to `awaiting-merge` (item 6
      # owns what happens there); `fail` is the one path in this whole build
      # that reaches `blocked` for real — and it is NEVER auto-retried, per
      # the plan's own scope line, so this branch returns rather than
      # looping. `parked`/`error` leave the state untouched for a later
      # cycle, the same shape awaiting-approval's own park/error cases use.
      if [ "$CUR_STATE" = awaiting-verify ]; then
        epic_loop_verify_gate "$REPO" "$SLUG" "$ISSUE" "$ROOT" "$EPIC_LOOP_EPICS_DIR" "$CUR_EPIC" "$CUR_ITEM" "$TARGET"
        case "$EPIC_LOOP_VERIFY_RESULT" in
          pass)
            printf 'epic-loop: issue #%s — verify: %s\n' "$ISSUE" "$EPIC_LOOP_VERIFY_DETAIL"
            epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$CUR_EPIC" awaiting-merge "$CUR_ITEM" "$EPIC_LOOP_VERIFY_DETAIL" || true
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-verify awaiting-merge "$EPIC_LOOP_VERIFY_DETAIL"
            continue
            ;;
          fail)
            printf 'epic-loop: issue #%s — verify FAILED: %s\n' "$ISSUE" "$EPIC_LOOP_VERIFY_DETAIL" >&2
            epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$CUR_EPIC" blocked "$CUR_ITEM" "$EPIC_LOOP_VERIFY_DETAIL" || true
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-verify blocked "$EPIC_LOOP_VERIFY_DETAIL"
            return 0
            ;;
          parked)
            printf 'epic-loop: issue #%s — verify parked: %s\n' "$ISSUE" "$EPIC_LOOP_VERIFY_DETAIL"
            epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$CUR_EPIC" awaiting-verify "$CUR_ITEM" "$EPIC_LOOP_VERIFY_DETAIL" || true
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-verify awaiting-verify "$EPIC_LOOP_VERIFY_DETAIL"
            return 0
            ;;
          *)
            printf 'epic-loop: issue #%s — verify gate error: %s\n' "$ISSUE" "$EPIC_LOOP_VERIFY_DETAIL" >&2
            epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" awaiting-verify awaiting-verify "ERROR: $EPIC_LOOP_VERIFY_DETAIL"
            return 0
            ;;
        esac
      fi
      printf 'epic-loop: real execution of phase "%s" is not implemented in this build (epic 19 items 2-8 fill it in) — pass --dry-run to preview the sequence. Nothing was invoked; issue #%s is unchanged.\n' \
        "$CUR_STATE" "$ISSUE" >&2
      return 2
    fi

    printf 'DRY-RUN: issue #%s phase=%s level=%s(%s) -> %s\n' \
      "$ISSUE" "$CUR_STATE" "${AUTONOMY_LEVEL:-L0}" "${AUTONOMY_REASON:-unconfigured}" "$CMD"

    WRITE_ITEM="$CUR_ITEM"
    case "$CUR_STATE" in
      approved)
        NEXT=dispatching
        WRITE_ITEM="$(epic_loop_first_item "$ROOT" "$CUR_EPIC")"
        [ -n "$WRITE_ITEM" ] || WRITE_ITEM="${CUR_ITEM:-1}"
        ;;
      merged)
        NEXT_ITEM="$(epic_loop_next_item "$ROOT" "$CUR_EPIC" "$CUR_ITEM")"
        if [ -n "$NEXT_ITEM" ]; then NEXT=dispatching; WRITE_ITEM="$NEXT_ITEM"
        else NEXT=closing; WRITE_ITEM=""
        fi
        ;;
      closing) NEXT=closed; WRITE_ITEM="" ;;
      *) NEXT="$(epic_loop_next_state "$CUR_STATE")" ;;
    esac

    if [ -z "$NEXT" ]; then
      printf 'epic-loop: issue #%s — no next state defined for "%s"; stopping rather than guessing\n' "$ISSUE" "$CUR_STATE" >&2
      return 2
    fi

    epic_loop_state_write "$TARGET" "$ISSUE" "$SLUG" "$CUR_EPIC" "$NEXT" "$WRITE_ITEM" "advanced from $CUR_STATE (dry-run preview)" || true
    epic_loop_ledger "$STATE_DIR" "$ISSUE" "$SLUG" "$CUR_STATE" "$NEXT" "dry-run preview"

    # Count the dispatch AFTER it has actually happened, matching where
    # dispatch.sh itself increments DISPATCH_ITEMS_DONE — right after the
    # phase that consumes the budget has run, not before.
    [ "$CUR_STATE" = dispatching ] && EPIC_LOOP_DISPATCHED_THIS_CYCLE=$((EPIC_LOOP_DISPATCHED_THIS_CYCLE + 1))

    PHASES=$((PHASES + 1))
    # A safety cap, not a real limit: no plan this build can read has more
    # than a handful of items, so 40 phases is already several epics' worth
    # and a loop still running at 40 is a bug in the transition table, not a
    # long epic.
    if [ "$PHASES" -ge 40 ]; then
      printf 'epic-loop: issue #%s — safety cap of 40 phases reached this cycle; stopping\n' "$ISSUE" >&2
      return 2
    fi
  done
}

# ---------------------------------------------------------------------- CLI
_epic_loop_usage() { sed -n '1,60p' "$0"; }

main() {
  local REPO="" ONCE=no MAX_ISSUES="" DRY_RUN=no

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)       REPO="${2:-}"; shift ;;
      --once)       ONCE=yes ;;   # accepted; single-pass is the only mode this build has
      --max-issues) MAX_ISSUES="${2:-}"; shift ;;
      --dry-run)    DRY_RUN=yes ;;
      -h|--help)    _epic_loop_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done
  : "$ONCE"  # accepted-and-unused is the documented contract, not dead code

  if [ -z "$REPO" ]; then
    printf 'usage: epic-loop.sh --repo <path> [--once] [--max-issues N] [--dry-run]\n' >&2
    return 1
  fi
  if [ ! -d "$REPO" ]; then
    printf 'epic-loop: not a directory: %s\n' "$REPO" >&2
    return 1
  fi
  case "${MAX_ISSUES:-}" in
    ''|*[!0-9]*) [ -z "${MAX_ISSUES:-}" ] || { printf 'epic-loop: --max-issues must be a non-negative integer, got %s\n' "$MAX_ISSUES" >&2; return 1; } ;;
  esac

  for LIB in "$AUTONOMY_LIB" "$STATUS_LIB" "$DISPATCH_LIB"; do
    if [ ! -r "$LIB" ]; then
      printf 'epic-loop: cannot read required library: %s\n' "$LIB" >&2
      return 1
    fi
    # shellcheck disable=SC1090
    . "$LIB" 2>/dev/null || { printf 'epic-loop: failed to source %s\n' "$LIB" >&2; return 1; }
  done

  # THE FIRST CHECK, before any repo is even touched — same placement
  # unattended-intake.sh uses and for the same reason: a stop is honoured
  # before the credential file, the lock, or any GitHub call could get in its
  # way.
  if autonomy_stop_requested; then
    printf 'STOP: cycle stop file present at %s — no cycle will start\n' "$AUTONOMY_STOP_FILE"
    return 0
  fi

  local ROOT SLUG
  ROOT="$(intake_status_repo_root "$REPO")"

  SLUG="${INTAKE_REPO_SLUG_OVERRIDE:-}"
  if [ -z "$SLUG" ] && [ -x "$GH_BIN" ]; then
    SLUG="$(cd "$REPO" 2>/dev/null && "$GH_BIN" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  fi
  [ -n "$SLUG" ] || SLUG="unknown/$(basename "$REPO")"

  local STATE_DIR
  STATE_DIR="$(epic_loop_state_dir "$ROOT")" || {
    printf 'epic-loop: could not open the per-issue state tree under %s/%s/.intake\n' "$ROOT" "$EPIC_LOOP_EPICS_DIR" >&2
    return 1
  }

  local ISSUES
  ISSUES="$(cd "$STATE_DIR" 2>/dev/null && ls -1 *.json 2>/dev/null | sed -e 's/\.json$//' | grep -E '^[0-9]+$' | sort -n)"

  if [ -z "$ISSUES" ]; then
    printf 'epic-loop: no per-issue state file under %s — nothing to advance (selecting a NEW issue is item 8, not this build)\n' "$STATE_DIR"
    return 0
  fi

  local COUNT=0 RC=0 ISSUE
  for ISSUE in $ISSUES; do
    if [ -n "${MAX_ISSUES:-}" ] && [ "$COUNT" -ge "$MAX_ISSUES" ]; then
      break
    fi
    epic_loop_process_issue "$ISSUE" "$REPO" "$SLUG" "$STATE_DIR" "$ROOT" "$DRY_RUN"
    case $? in
      0) : ;;
      *) RC=2 ;;
    esac
    COUNT=$((COUNT + 1))
    if autonomy_stop_requested; then
      printf 'epic-loop: STOP observed — halting the cycle, no further issues processed this invocation\n'
      return 0
    fi
  done
  return "$RC"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
  exit $?
fi
