#!/usr/bin/env bash
# phase-session.sh — the phase-session harness and handoff bridge, epic 19
# (epic-loop) item 3.
#
# KEPT, NOT RETIRED (epic 21 item 1 decision, 2026-09-10, made in-item per the
# dispatch note): this file's role as epic-loop.sh's automatic phase-chaining
# mechanism is moot now that epic-loop.sh's approve/merge/chain phases always
# park for a human (see that file's own retirement note) — nothing left
# invokes this harness unattended. But `phase_session_run_claude` (spawn one
# bounded `claude -p` session, wait on it, kill it on timeout) and the handoff
# validity/fallback machinery around it have no dependency on the retired
# ladder at all — no level, no grant record, no budget — and are reusable
# plumbing for spawning a single scoped drafting session, which is exactly
# what a future item may want. Deleting a working, ladder-independent utility
# because its one caller is gone would be losing a tool over an accident of
# history, so it stays as a drafting-phase utility rather than being removed.
#
# THE SHAPE THIS ITEM BUILDS, AND NOTHING MORE. Every phase of epic-loop.sh's
# state machine (item 1) is a FRESH `claude -p` session with no memory of the
# phase before it — the whole point of the epic's Outcome ("every phase
# boundary is a real context boundary"). This file is the one place that
# session gets run and the one place `docs/epics/handoff.md` gets managed
# around it:
#
#   1. run ONE `claude -p` session against a brief already written to disk by
#      the caller (items 4-8 construct that brief's PHASE content; this file
#      adds nothing about drafting, approving, dispatching, verifying,
#      merging or closing to it — see the header of dispatch_brief() for the
#      shape a phase-specific brief takes, which this deliberately does not
#      re-derive or fork),
#   2. append the repo's own `/handoff` command body as the session's closing
#      instruction, so the session checkpoints the same way an attended one
#      does — not a paraphrase of the ritual, the actual command body, read
#      from commands/handoff.md and pasted in verbatim,
#   3. name `docs/epics/handoff.md`'s ABSOLUTE path explicitly in the prompt,
#      both for reading (a previous phase's state, if any) and for writing
#      (this session's own checkpoint) — the A1 mitigation from the plan's
#      Grounding: SessionStart hooks may not fire for a `claude -p` process
#      with no Claude Code parent, so this harness never relies on injection
#      alone, whatever any later caller's own brief does or forgets to do,
#   4. after the session ends, VALIDATE the handoff it (should have) written:
#      a `**Epic:**` field, an `## Exact next action` section, a
#      `## Claimed but NOT yet verified` section (or equivalent — matched
#      case-insensitively). If it's missing or any of those three is absent,
#      this harness writes a MINIMAL DETERMINISTIC FALLBACK handoff derived
#      from the per-issue state file (item 1's
#      `docs/epics/.intake/loop/<issue>.json`, read with epic-loop.sh's own
#      `epic_loop_state_read` — sourced read-only, never re-implemented)
#      rather than failing outright. A bad or missing handoff is not this
#      harness's failure; a driver with no handoff at all to resume from is.
#
# WHAT THIS ITEM DELIBERATELY DOES NOT DO: decide what a phase's brief SAYS.
# There is no drafting logic, no approval logic, no dispatch logic, no verify
# logic, no merge logic anywhere below — those are items 4-7. This is the
# harness that runs *a* session and manages the handoff file around it,
# nothing about which session or why.
#
# CONTRACT MARKER, the sibling of EPIC_LOOP_CONTRACT / DISPATCH_ENFORCED — a
# fixture greps for it.
PHASE_SESSION_CONTRACT=1
#
# Usage:
#   phase-session.sh <brief-file> [--repo <path>] [--handoff <path>]
#                     [--state-file <path>] [--epic <epic-relative-plan-path>]
#                     [--model <name>] [--agent <name>]
#                     [--allowed-tools "<space-separated list>"]
#                     [--timeout <seconds>] [--log <path>]
#
#   <brief-file>     required, readable file — the phase-specific brief this
#                     session is dispatched with (this file's content, not
#                     this file's PATH, becomes the start of the prompt).
#   --repo            checkout the session runs in. Default: `.`. Resolved to
#                     an ABSOLUTE path before anything else, so the handoff
#                     path named in the prompt is unambiguous wherever this
#                     was invoked from.
#   --handoff         override the handoff path. Default:
#                     <repo>/docs/epics/handoff.md (this repo's own
#                     convention — see references/session-handoff.md).
#   --state-file      the per-issue state file
#                     (docs/epics/.intake/loop/<issue>.json) to derive a
#                     fallback handoff from, if the session's own is missing
#                     or invalid. Optional — omitted means the fallback (if
#                     one is needed) carries only what git and --epic can
#                     supply, honestly, rather than inventing a state.
#   --epic            epic-relative plan path override for the fallback's
#                     `**Epic:**` field, when the state file doesn't have one
#                     or none was given.
#   --model           default: sonnet.
#   --agent           optional; omitted means no --agent flag (a bare
#                     session) — items 4-8 pass whatever agent their phase
#                     needs, or none.
#   --allowed-tools   optional passthrough, space-separated, same shape
#                     dispatch.sh's own `dispatch_allowed_tools | tr '\n' ' '`
#                     produces.
#   --timeout         seconds before the session is killed. Default 3600,
#                     same default dispatch.sh's own executor timeout uses
#                     (INTAKE_DISPATCH_TIMEOUT) — this harness has its own
#                     knob, INTAKE_PHASE_SESSION_TIMEOUT, so the two never
#                     have to move together by accident.
#   --log             where the session's raw stdout/stderr lands. Default: a
#                     mktemp file. Named explicitly so a caller (or a
#                     fixture) can inspect the transcript afterward.
#
# Exit codes: 0 = a valid handoff exists at the target path when this returns
#                 (session-written or this harness's own deterministic
#                 fallback) — the caller can always resume from it
#             1 = usage error (bad args, unreadable brief, a required library
#                 could not be sourced) — nothing was invoked
#             2 = claude could not be invoked at all (binary missing/not
#                 executable), or even the fallback handoff could not be
#                 written (disk error) — genuinely stuck, not a bad session

set -u

# ------------------------------------------------------------------- binaries
CLAUDE_BIN="${INTAKE_CLAUDE:-$HOME/.local/bin/claude}"
GIT_BIN="${INTAKE_GIT:-/usr/bin/git}"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_LIB="${INTAKE_STATUS_LIB:-$BIN_DIR/intake-status.sh}"
EPIC_LOOP_LIB="${INTAKE_EPIC_LOOP_LIB:-$BIN_DIR/epic-loop.sh}"
HANDOFF_CMD="${INTAKE_HANDOFF_CMD:-$BIN_DIR/../commands/handoff.md}"

PHASE_SESSION_TIMEOUT_DEFAULT="${INTAKE_PHASE_SESSION_TIMEOUT:-3600}"

# ------------------------------------------------------------ the /handoff body
# The command file is frontmatter (--- ... ---) then the actual ritual. This
# strips the frontmatter and returns everything after the SECOND `---` line —
# the real instructions, pasted verbatim rather than paraphrased, so a phase
# session checkpoints exactly the way an attended `/handoff` does.
phase_session_handoff_cmd_body() {
  awk 'BEGIN{d=0} /^---[ \t]*$/{d++; next} d>=2{print}' "$HANDOFF_CMD"
}

# $1 = brief-file, $2 = ABSOLUTE handoff path -> stdout the full prompt
phase_session_build_prompt() {
  local BRIEF="${1:-}" HANDOFF="${2:-}" CMD_BODY
  CMD_BODY="$(phase_session_handoff_cmd_body)"
  cat "$BRIEF"
  printf '\n\n'
  printf -- '---\n\n'
  printf 'HANDOFF FILE, EXPLICIT ABSOLUTE PATH (A1 mitigation, epic 19 plan Grounding):\n'
  printf 'this session may be running headless with no interactive parent and no\n'
  printf 'SessionStart hook firing, so do not rely on any automatic injection for this.\n\n'
  printf '    %s\n\n' "$HANDOFF"
  printf 'If a previous phase left state there, read it directly, first, before doing\n'
  printf 'anything else. At the end of THIS session, before you stop, checkpoint to that\n'
  printf 'exact path using the ritual below — the same one this repo'"'"'s own /handoff\n'
  printf 'command runs — whatever any tool or hook implies about a different location.\n\n'
  printf -- '---\n\n'
  printf '%s\n' "$CMD_BODY"
}

# ------------------------------------------------------------- the validity gate
# $1 = handoff path -> rc 0 valid, 1 missing or invalid. Matches
# references/session-handoff.md's template: a `**Epic:**` field, an
# `## Exact next action` section, a `## Claimed but NOT yet verified` section
# (or equivalent — matched case-insensitively so a session that spells it
# "not yet verified" in different case still passes; the WORDS are what a
# resuming session depends on, not their case).
phase_session_handoff_valid() {
  local F="${1:-}"
  [ -r "$F" ] || return 1
  grep -qE '\*\*Epic:\*\*' "$F" 2>/dev/null || return 1
  grep -qiE '^#+[[:space:]]*Exact next action' "$F" 2>/dev/null || return 1
  grep -qiE '^#+[[:space:]]*Claimed but NOT yet verified' "$F" 2>/dev/null || return 1
  return 0
}

# --------------------------------------------------------- the deterministic fallback
# NEVER FAILS OUTRIGHT ON A BAD SESSION. A missing or invalid handoff is
# recorded honestly as a fallback, not hidden as a real one — every field
# below is either read from the per-issue state file (item 1's
# `epic_loop_state_read`, sourced read-only) or plainly marked unknown; no
# field is invented. $1 = handoff path, $2 = state-file (optional),
# $3 = epic override (optional), $4 = repo checkout
phase_session_write_fallback() {
  local HANDOFF="${1:-}" SF="${2:-}" EPIC_OV="${3:-}" REPO="${4:-.}" LOG="${5:-}"
  local ISSUE="" EPIC="" STATE="" ITEM="" DETAIL=""
  if [ -n "$SF" ] && command -v epic_loop_state_read >/dev/null 2>&1 && epic_loop_state_read "$SF"; then
    ISSUE="$EPIC_LOOP_R_ISSUE"; EPIC="$EPIC_LOOP_R_EPIC"; STATE="$EPIC_LOOP_R_STATE"
    ITEM="$EPIC_LOOP_R_ITEM"; DETAIL="$EPIC_LOOP_R_DETAIL"
  fi
  [ -n "$EPIC_OV" ] && EPIC="$EPIC_OV"

  local BRANCH COMMIT
  BRANCH="$("$GIT_BIN" -C "$REPO" branch --show-current 2>/dev/null)"
  COMMIT="$("$GIT_BIN" -C "$REPO" rev-parse --short HEAD 2>/dev/null)"

  local BODY
  BODY="$( {
    printf '# Session Handoff — %s / work item %s\n\n' "${EPIC:-none}" "${ITEM:-N/A}"
    printf '**Written:** %s\n' "$(intake_status_now)"
    printf '**Epic:** %s\n' "${EPIC:-none}"
    printf '**Branch:** %s (pushed: unknown — this is a deterministic fallback, not a session-written handoff)\n' "${BRANCH:-unknown}"
    printf '**Last commit:** %s\n' "${COMMIT:-unknown}"
    printf '**Worktree:** %s\n\n' "$REPO"
    printf '## Verified this session\n'
    printf -- '- none — phase-session.sh wrote this fallback because the session'"'"'s own handoff was missing or invalid, so nothing here was checked against a live session\n\n'
    printf '## Claimed but NOT yet verified\n'
    if [ -n "$STATE" ]; then
      printf -- '- the per-issue state file (%s) last recorded state=%s, item=%s%s — unverified against the repo, verify this FIRST\n' \
        "${SF:-unknown}" "$STATE" "${ITEM:-none}" "${DETAIL:+, detail: $DETAIL}"
    else
      printf -- '- no per-issue state file was available to this fallback; nothing beyond the git state above is known — verify from the plan and the repo before doing anything\n'
    fi
    printf '\n## Exact next action\n'
    printf -- '- phase-session.sh could not validate a real handoff for issue %s — re-ground from the epic plan and the per-issue state file (%s) before continuing\n' \
      "${ISSUE:-unknown}" "${SF:-none provided}"
    printf '\n## Environment state\n- none\n\n'
    printf '## Open questions for Jonathan\n'
    printf -- '- the phase session produced no valid handoff — check %s for why (claude exit code, transcript) before trusting this fallback further\n' "${LOG:-the run log}"
  } )"
  mkdir -p "$(dirname "$HANDOFF")" 2>/dev/null || return 1
  printf '%s\n' "$BODY" | intake_status_atomic "$HANDOFF"
}

# ------------------------------------------------------------- run the session
# A HEARTBEAT-FREE, TIMEOUT-BOUNDED WAIT, the same shape dispatch.sh's own
# executor wait uses (kill -TERM then -KILL after a grace window) — this
# harness runs one bounded session, not a long-running cycle, so it skips
# dispatch.sh's periodic heartbeat log lines but keeps the same kill shape.
# $1=prompt $2=repo $3=model $4=agent $5=tools $6=timeout $7=log -> rc
phase_session_run_claude() {
  local PROMPT="${1:-}" REPO="${2:-}" MODEL="${3:-}" AGENT="${4:-}" TOOLS="${5:-}" TIMEOUT="${6:-}" LOG="${7:-}"
  [ -x "$CLAUDE_BIN" ] || { printf 'phase-session: claude binary not found or not executable: %s\n' "$CLAUDE_BIN" >&2; return 2; }
  (
    cd "$REPO" || exit 2
    if [ -n "$AGENT" ] && [ -n "$TOOLS" ]; then
      # shellcheck disable=SC2086
      "$CLAUDE_BIN" -p "$PROMPT" --model "${MODEL:-sonnet}" --agent "$AGENT" --allowed-tools $TOOLS
    elif [ -n "$AGENT" ]; then
      "$CLAUDE_BIN" -p "$PROMPT" --model "${MODEL:-sonnet}" --agent "$AGENT"
    elif [ -n "$TOOLS" ]; then
      # shellcheck disable=SC2086
      "$CLAUDE_BIN" -p "$PROMPT" --model "${MODEL:-sonnet}" --allowed-tools $TOOLS
    else
      "$CLAUDE_BIN" -p "$PROMPT" --model "${MODEL:-sonnet}"
    fi
  ) > "$LOG" 2>&1 &
  local CPID=$! WAITED=0
  while kill -0 "$CPID" 2>/dev/null; do
    if [ "$WAITED" -ge "$TIMEOUT" ]; then
      kill -TERM "$CPID" 2>/dev/null || true
      sleep 5
      kill -KILL "$CPID" 2>/dev/null || true
      break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
  done
  wait "$CPID" 2>/dev/null
  return $?
}

# ---------------------------------------------------------------------- CLI
_phase_session_usage() { sed -n '1,100p' "$0"; }

main() {
  if [ $# -eq 0 ]; then _phase_session_usage >&2; return 1; fi
  case "$1" in -h|--help) _phase_session_usage; return 0 ;; esac

  local BRIEF="$1"; shift
  local REPO="." HANDOFF="" STATE_FILE="" EPIC_OV="" MODEL="sonnet" AGENT="" TOOLS="" TIMEOUT="$PHASE_SESSION_TIMEOUT_DEFAULT" LOG=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)          REPO="${2:-}"; shift ;;
      --handoff)       HANDOFF="${2:-}"; shift ;;
      --state-file)    STATE_FILE="${2:-}"; shift ;;
      --epic)          EPIC_OV="${2:-}"; shift ;;
      --model)         MODEL="${2:-}"; shift ;;
      --agent)         AGENT="${2:-}"; shift ;;
      --allowed-tools) TOOLS="${2:-}"; shift ;;
      --timeout)       TIMEOUT="${2:-}"; shift ;;
      --log)           LOG="${2:-}"; shift ;;
      -h|--help)       _phase_session_usage; return 0 ;;
      *) printf 'phase-session: unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  [ -n "$BRIEF" ] && [ -r "$BRIEF" ] || { printf 'phase-session: cannot read brief file: %s\n' "$BRIEF" >&2; return 1; }
  [ -d "$REPO" ] || { printf 'phase-session: not a directory: %s\n' "$REPO" >&2; return 1; }
  case "$TIMEOUT" in ''|*[!0-9]*) printf 'phase-session: --timeout must be a non-negative integer, got %s\n' "$TIMEOUT" >&2; return 1 ;; esac

  REPO="$(cd "$REPO" && pwd)"
  [ -n "$HANDOFF" ] || HANDOFF="$REPO/docs/epics/handoff.md"
  case "$HANDOFF" in /*) ;; *) HANDOFF="$REPO/$HANDOFF" ;; esac

  for LIB in "$STATUS_LIB" "$EPIC_LOOP_LIB"; do
    if [ ! -r "$LIB" ]; then
      printf 'phase-session: cannot read required library: %s\n' "$LIB" >&2
      return 1
    fi
    # shellcheck disable=SC1090
    . "$LIB" 2>/dev/null || { printf 'phase-session: failed to source %s\n' "$LIB" >&2; return 1; }
  done
  [ -r "$HANDOFF_CMD" ] || { printf 'phase-session: cannot read %s\n' "$HANDOFF_CMD" >&2; return 1; }

  [ -n "$LOG" ] || LOG="$(mktemp "${TMPDIR:-/tmp}/phase-session.XXXXXX" 2>/dev/null)"
  [ -n "$LOG" ] || LOG="/dev/null"

  local PROMPT
  PROMPT="$(phase_session_build_prompt "$BRIEF" "$HANDOFF")"

  phase_session_run_claude "$PROMPT" "$REPO" "$MODEL" "$AGENT" "$TOOLS" "$TIMEOUT" "$LOG"
  local RC=$?
  printf 'phase-session: claude exited %s (log: %s)\n' "$RC" "$LOG"

  if phase_session_handoff_valid "$HANDOFF"; then
    printf 'phase-session: handoff valid at %s\n' "$HANDOFF"
    printf 'PHASE-SESSION-RESULT: source=session valid=yes handoff=%s\n' "$HANDOFF"
    return 0
  fi

  printf 'phase-session: handoff missing or invalid at %s — writing a deterministic fallback derived from %s\n' \
    "$HANDOFF" "${STATE_FILE:-<no state file given>}" >&2
  if phase_session_write_fallback "$HANDOFF" "$STATE_FILE" "$EPIC_OV" "$REPO" "$LOG" && phase_session_handoff_valid "$HANDOFF"; then
    printf 'PHASE-SESSION-RESULT: source=fallback valid=yes handoff=%s\n' "$HANDOFF"
    return 0
  fi

  printf 'phase-session: could not write a valid fallback handoff to %s\n' "$HANDOFF" >&2
  printf 'PHASE-SESSION-RESULT: source=none valid=no handoff=%s\n' "$HANDOFF"
  return 2
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
  exit $?
fi
