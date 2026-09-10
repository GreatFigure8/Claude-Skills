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
# `blocked` and `refused` are not reachable by this build (nothing here makes a
# judgement that could produce either); they exist in the vocabulary because a
# later item writes them and a reader — this file's own `epic_loop_next_state`
# included — must already know they are terminal.
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
    # set them. Informational for level in this build — no `may-approve` /
    # `may-merge` / `may-chain` exists yet (item 2), so the level is logged
    # but nothing here branches on it; `--dry-run` previews the happy path
    # regardless and says so in its own output.
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
