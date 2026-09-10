#!/usr/bin/env bash
# issue-filer.sh — FAILURE-DRIVEN ISSUE FILING (dev-epic-workflow, epic 21 item 4).
#
# WHAT THIS REPLACES. Today, when a gate turns up a failure out of the current
# work item's own scope — persistent after retry, or discovered incidentally
# while working a different item — the workflow's answer is "note it and stop
# to ask" (`work-item-executor.md`'s own hard boundary: scope that grows
# mid-item does not grow the branch; the remainder is proposed as a follow-on
# item for the orchestrator). That is the right answer in an interactive
# session, and it is unaffected by this file. In a session-scoped loop
# (`session-loop.md`) there is nobody to ask, so the epic's Outcome makes the
# equivalent move deterministic: file a new GitHub issue instead of silently
# absorbing the scope creep, then keep going.
#
# WHAT THIS FILE IS, AND WHERE IT SITS. The deterministic half of that move,
# in the same style `autonomy.sh`'s harm floor and `session-loop.sh`'s driver
# already use: no judgment, one well-known entry point, a fixture per guard.
# The JUDGMENT — deciding a given gate failure really is out of the current
# item's scope, and writing the evidence down — stays with whichever live
# session discovered it (`session-loop.md` names the call sites: `dispatch`'s
# `blocked` handling and `verify`'s `fail` handling). This file only does the
# two things a session must never be trusted to remember on its own:
#
#   1. DEDUPLICATE by fingerprint against open issues already labelled
#      `epic-loop-filed`, so the same discovered failure is never filed twice.
#   2. FILE, with a body naming the discovering issue/item, the failing check,
#      and the evidence — and nothing else. Filing is the TERMINAL action;
#      auto-fixing the discovery is explicitly out of scope for this epic item
#      (the fix is a future loop cycle picking up the new issue).
#
# THE FINGERPRINT is a checksum of the trimmed `<check>\x1e<evidence>` pair,
# printed in the created issue's body as a hidden marker
# (`<!-- epic-loop-fingerprint: HEX -->`) so a later run can find it again
# without depending on the human-facing prose staying byte-identical. `cksum`
# is used rather than a hash tool that may not be installed (`shasum`,
# `sha256sum`) — this is a dedup key against accidental repeats, not a
# security boundary, and POSIX `cksum` is guaranteed present.
#
# Used two ways:
#   sourced   `. issue-filer.sh` exposes `issue_filer_fingerprint`,
#             `issue_filer_find_duplicate` and `issue_filer_file` for a
#             fixture harness or a future caller (item 5 routes its own
#             failures through `issue_filer_file` directly).
#   executed  `issue-filer.sh --file --repo PATH [--slug SLUG] --issue N
#             --item I --check "<name>" --evidence "<text>" [--title "<t>"]`
#             files (or skips, if a fingerprint match is open) and prints
#             `filed <url>` or `skip #<n> <reason>`.
#             `issue-filer.sh --fingerprint --check "<name>" --evidence "<text>"`
#             prints the fingerprint alone — read-only, no `gh` call, for a
#             fixture or a human to check what a given failure would hash to.
#
# Exit codes: 0 = filed, or skipped because an open duplicate already exists
# (both are the correct terminal outcome for that input — "already covered" is
# not a failure of this tool). 1 = usage error. 2 = `gh` could not be reached
# (list, view or create failed) — the caller has not been told a fingerprint
# was checked or an issue was filed, because neither happened.

set -u

ISSUE_FILER_CONTRACT=1

# Prefixed rather than GIT_BIN/GH_BIN, the same reason session-loop.sh gives:
# this file may be sourced alongside other libraries that define their own.
ISSUE_FILER_GH="${INTAKE_GH:-gh}"

# The one label every issue this file creates carries, and the one label its
# own dedup search filters on. One definition, both directions.
ISSUE_FILER_LABEL="${INTAKE_LOOP_FILED_LABEL:-epic-loop-filed}"

ISSUE_FILER_REFUSAL=""
ISSUE_FILER_RESULT_ACTION=""   # "filed" | "skip"
ISSUE_FILER_RESULT_URL=""
ISSUE_FILER_RESULT_ISSUE=""    # the duplicate's number, only set on skip
ISSUE_FILER_DUP_ISSUE=""

# --------------------------------------------------------------- utilities
_issue_filer_strip() { # $1 -> stdout, leading/trailing whitespace trimmed
  local S="${1-}"
  S="${S#"${S%%[![:space:]]*}"}"
  S="${S%"${S##*[![:space:]]}"}"
  printf '%s' "$S"
}

# ------------------------------------------------------------- fingerprint
# $1 = failing check name   $2 = evidence text -> stdout a stable hex-ish key.
# Trimmed first so incidental leading/trailing whitespace from a caller's
# `"$(...)"` capture never changes the fingerprint of an otherwise identical
# failure; everything else about the text (case, internal whitespace) is
# hashed as given, because normalising further risks two DIFFERENT failures
# colliding, which is the wrong direction to be wrong in for a dedup key.
issue_filer_fingerprint() { # $1=check $2=evidence -> stdout
  local CHECK EVIDENCE
  CHECK="$(_issue_filer_strip "${1:-}")"
  EVIDENCE="$(_issue_filer_strip "${2:-}")"
  printf '%s\x1e%s' "$CHECK" "$EVIDENCE" | cksum 2>/dev/null | awk '{printf "%08x%06x", $1, $2}'
}

# ------------------------------------------------------------- duplicate search
# $1 = repo slug   $2 = fingerprint. Sets ISSUE_FILER_DUP_ISSUE on a match.
# rc 0 = a match was found. rc 1 = searched cleanly, no match. rc 2 = the
# search itself could not be trusted (a `gh` call failed) — ISSUE_FILER_REFUSAL
# says which. rc 2 is deliberately distinct from rc 1: a caller must never read
# "the list call failed" as "nothing to dedupe against", or it would file a
# duplicate on the exact turn `gh` was flaky.
issue_filer_find_duplicate() { # $1=slug $2=fingerprint
  local SLUG="${1:-}" FP="${2:-}" NUMS N BODY
  ISSUE_FILER_REFUSAL=""
  ISSUE_FILER_DUP_ISSUE=""
  [ -n "$SLUG" ] || { ISSUE_FILER_REFUSAL="no repo slug given"; return 2; }
  [ -n "$FP" ]   || { ISSUE_FILER_REFUSAL="no fingerprint given"; return 2; }
  NUMS="$("$ISSUE_FILER_GH" issue list --repo "$SLUG" --state open \
            --label "$ISSUE_FILER_LABEL" --json number -q '.[].number' 2>/dev/null)"
  if [ $? -ne 0 ]; then
    ISSUE_FILER_REFUSAL="could not list open '$ISSUE_FILER_LABEL' issues on $SLUG"
    return 2
  fi
  # A HERE-DOC, not a pipe: ISSUE_FILER_DUP_ISSUE must survive past this loop,
  # and bash runs the right side of a pipe in a subshell — the same discipline
  # session-loop.sh and autonomy.sh both state in their own headers.
  while IFS= read -r N; do
    [ -n "$N" ] || continue
    BODY="$("$ISSUE_FILER_GH" issue view "$N" --repo "$SLUG" --json body -q .body 2>/dev/null)" || continue
    case "$BODY" in
      *"epic-loop-fingerprint: $FP"*) ISSUE_FILER_DUP_ISSUE="$N"; return 0 ;;
    esac
  done <<NUMS_EOF
$NUMS
NUMS_EOF
  return 1
}

# ---------------------------------------------------------------------- file
# Params, all required except TITLE: SLUG ISSUE ITEM CHECK EVIDENCE [TITLE]
# Sets ISSUE_FILER_RESULT_ACTION/URL/ISSUE. rc 0 = filed or correctly skipped.
# rc 2 = a `gh` call failed (list/view during dedup, or create).
issue_filer_file() { # $1=slug $2=issue $3=item $4=check $5=evidence $6=title
  local SLUG="${1:-}" ISSUE="${2:-}" ITEM="${3:-}" CHECK="${4:-}" EVIDENCE="${5:-}" TITLE="${6:-}"
  local FP RC BODYFILE URL
  ISSUE_FILER_REFUSAL=""
  ISSUE_FILER_RESULT_ACTION=""
  ISSUE_FILER_RESULT_URL=""
  ISSUE_FILER_RESULT_ISSUE=""
  [ -n "$SLUG" ]     || { ISSUE_FILER_REFUSAL="no repo slug given"; return 2; }
  [ -n "$CHECK" ]    || { ISSUE_FILER_REFUSAL="no failing check name given"; return 2; }
  [ -n "$EVIDENCE" ] || { ISSUE_FILER_REFUSAL="no evidence given"; return 2; }

  FP="$(issue_filer_fingerprint "$CHECK" "$EVIDENCE")"

  issue_filer_find_duplicate "$SLUG" "$FP"
  RC=$?
  if [ "$RC" -eq 2 ]; then
    return 2
  fi
  if [ "$RC" -eq 0 ]; then
    ISSUE_FILER_RESULT_ACTION="skip"
    ISSUE_FILER_RESULT_ISSUE="$ISSUE_FILER_DUP_ISSUE"
    printf 'skip #%s duplicate of this failure is already open (fingerprint %s)\n' \
      "$ISSUE_FILER_DUP_ISSUE" "$FP"
    return 0
  fi

  [ -n "$TITLE" ] || TITLE="epic-loop: $CHECK failed (discovered from #${ISSUE:-?} item ${ITEM:-?})"

  BODYFILE="$(mktemp "${TMPDIR:-/tmp}/issue-filer-body.XXXXXX" 2>/dev/null)" || {
    ISSUE_FILER_REFUSAL="could not create a temp file for the issue body"
    return 2
  }
  {
    printf '## Summary\n\n'
    printf 'Discovered while working issue #%s item %s: `%s` failed, out of that\n' \
      "${ISSUE:-?}" "${ITEM:-?}" "$CHECK"
    printf "item's own scope. Filed automatically by the session-scoped issue loop;\n"
    printf 'filing is the terminal action here — fixing this is a future loop cycle.\n\n'
    printf '## Discovered by\n\n'
    printf -- '- Issue: #%s\n' "${ISSUE:-?}"
    printf -- '- Item: %s\n' "${ITEM:-?}"
    printf -- '- Failing check: `%s`\n\n' "$CHECK"
    printf '## Evidence\n\n'
    printf '```\n%s\n```\n\n' "$EVIDENCE"
    printf '<!-- epic-loop-fingerprint: %s -->\n' "$FP"
  } > "$BODYFILE"

  URL="$("$ISSUE_FILER_GH" issue create --repo "$SLUG" --title "$TITLE" \
           --body-file "$BODYFILE" --label "$ISSUE_FILER_LABEL" 2>&1)"
  RC=$?
  rm -f "$BODYFILE" 2>/dev/null || true
  if [ "$RC" -ne 0 ]; then
    ISSUE_FILER_REFUSAL="gh issue create failed: $URL"
    return 2
  fi
  ISSUE_FILER_RESULT_ACTION="filed"
  ISSUE_FILER_RESULT_URL="$URL"
  printf 'filed %s\n' "$URL"
  return 0
}

# ---------------------------------------------------------------------- CLI
_issue_filer_usage() { sed -n '1,50p' "$0"; }

_issue_filer_cli() {
  local MODE="" REPO="." SLUG="" ISSUE="" ITEM="" CHECK="" EVIDENCE="" TITLE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --file)        MODE=file ;;
      --fingerprint) MODE=fingerprint ;;
      --repo)        REPO="${2:-}"; shift ;;
      --slug)        SLUG="${2:-}"; shift ;;
      --issue)       ISSUE="${2:-}"; shift ;;
      --item)        ITEM="${2:-}"; shift ;;
      --check)       CHECK="${2:-}"; shift ;;
      --evidence)    EVIDENCE="${2:-}"; shift ;;
      --title)       TITLE="${2:-}"; shift ;;
      -h|--help)     _issue_filer_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done
  [ -n "$MODE" ] || { _issue_filer_usage; return 1; }

  if [ "$MODE" = fingerprint ]; then
    issue_filer_fingerprint "$CHECK" "$EVIDENCE"
    printf '\n'
    return 0
  fi

  # --file
  if [ -z "$SLUG" ]; then
    SLUG="$( cd "$REPO" 2>/dev/null && "$ISSUE_FILER_GH" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null )" || SLUG=""
  fi
  [ -n "$SLUG" ] || { printf 'REFUSED — cannot resolve owner/name for %s via gh; pass --slug\n' "$REPO" >&2; return 2; }

  issue_filer_file "$SLUG" "$ISSUE" "$ITEM" "$CHECK" "$EVIDENCE" "$TITLE"
  RC=$?
  if [ "$RC" -ne 0 ]; then
    printf 'REFUSED — %s\n' "$ISSUE_FILER_REFUSAL" >&2
  fi
  return "$RC"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _issue_filer_cli "$@"
  exit $?
fi
