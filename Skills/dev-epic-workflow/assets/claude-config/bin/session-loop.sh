#!/usr/bin/env bash
# session-loop.sh — the deterministic half of the SESSION-SCOPED ISSUE LOOP
# (dev-epic-workflow, epic 21 item 3).
#
# WHAT THE LOOP IS. Jonathan opens a live Claude Code session, names one repo,
# and says "start the loop". From that point the session itself works admitted
# GitHub issues end to end — draft, dispatch, verify, harm-check, merge, chain,
# close, next issue — with no approval stop, because STARTING THE LOOP IS THE
# APPROVAL. It runs until he says stop or the session ends. The prose contract
# a session follows is `references/session-loop.md`; the `/issue-loop` command is the
# entry point; THIS FILE is the part of it that must not depend on a model
# remembering to do the right thing.
#
# THE SEAM, AND WHY IT IS HERE RATHER THAN ANYWHERE ELSE.
#
#   this file (deterministic)          the live session (judgement)
#   ---------------------------------  ----------------------------------------
#   which issues are ADMITTED          drafting the plan for one
#   which action comes NEXT            running a work item (work-item-executor)
#   the HARM CHECK before it           judging a diff (acceptance-verifier)
#   the STOP signal                    writing the PR body, the retro, the plan
#   the per-issue state + ledger       talking to Jonathan
#
# The brake lives on the deterministic side ON PURPOSE. `--next` runs epic 21
# item 2's harm floor ITSELF before it will name a merge, a chain or a close,
# and emits `blocked`/`halt` instead when the floor refuses — so a session
# cannot skip the check by forgetting it exists. The plan's invariant ("the
# harm check runs before every merge and every chain action, with no
# exception") is therefore enforced by what this file will TELL a session to
# do, not by what the session was asked to remember.
#
# NOT HEADLESS, AND MECHANICALLY SO. This file never invokes `claude`. There is
# no CLAUDE_BIN here, no `-p`, no `--agent`, no subprocess that could become
# one; `SESSION_LOOP_INVOKES_CLAUDE=no` is the machine-readable statement of
# it and a fixture greps this file to prove it stays true. Every judgement step
# happens in the live session that called this script, through the `Agent`
# tool, which is what "reusing unattended-intake's drafting logic directly, not
# headlessly" and "the existing orchestrated work-item-executor path —
# unchanged" mean in the plan. The headless path (`unattended-intake.sh`,
# `phase-session.sh`) is retired for this purpose, not wrapped.
#
# ONE REPO, ONE LOOP, ONE LIVE SESSION. `--start` binds a loop record to one
# checkout; a second `--start` naming a different repo is REFUSED rather than
# accommodated. Multi-repo looping is out of scope for this epic by name.
#
# ADMISSION — the epic's own invariant, checked against the issue, not assumed
# from a label. An issue is ADMITTED iff BOTH hold:
#
#   1. it carries the `epic-loop-ready` label (GitHub) — the same constant the
#      `author-issue` skill applies to everything it files
#      (Skills/author-issue/references/trackers.md), so the producing side and
#      this consuming side name one string; and
#   2. its BODY carries a `Requirements` heading and an `Acceptance criteria`
#      heading, each with real content under it
#      (Skills/author-issue/references/issue-body.md's skeleton).
#
# Both, because the label is a CLAIM and the body is the EVIDENCE. A label
# applied by hand to an issue with no criteria is exactly the case the epic's
# invariant exists to refuse, and `## Loop admission`'s four checkboxes are
# self-reported — read as documentation, never as the gate. An issue that
# fails either half is PARKED, never executed: the loop steps over it and
# keeps going.
#
# STATUS IS A CONVENIENCE VIEW; THE REPO IS THE TRUTH. Branches, pull requests
# and `ledger.jsonl` are authoritative — the same rule the executor control
# plane and the intake control plane both state. A record this file cannot
# trust says `unknown`, which is deliberately not a state in the vocabulary
# below so that nothing can read it as progress.
#
# ---------------------------------------------------------------------------
# Usage (every mode is read-only against the REPO; only this loop's own state
# tree is ever written, and only under <epics-dir>/.intake/session-loop/):
#
#   session-loop.sh --start  --repo PATH [--epics-dir D] [--integration B]
#   session-loop.sh --status --repo PATH
#   session-loop.sh --admit  --repo PATH [--issue N]
#   session-loop.sh --next   --repo PATH [--dry-run]
#   session-loop.sh --record --repo PATH --state S [--issue N] [--item I]
#                            [--branch B] [--detail T]
#   session-loop.sh --stop   --repo PATH [--detail T]
#
#   --start        bind the loop to this checkout for this session. Refuses if
#                   a live loop is already bound to a DIFFERENT repo.
#   --status       print the loop record and the active issue's record.
#   --admit        print the admission verdict for every open issue (or one).
#                   `admitted` / `parked <reason>`, one line each.
#   --next         print the ONE next action, as `key value` lines. The harm
#                   floor has already run for any action that is not `poll` or
#                   `stop`; an action this prints is an action the floor
#                   cleared at the moment it was printed.
#   --dry-run      with `--next`: print the projected happy-path SEQUENCE for
#                   every admitted issue instead of the single next action,
#                   and write nothing. A preview of the shape, not a claim
#                   about what will pass — the same thing epic-loop.sh's own
#                   --dry-run meant.
#   --record       the session reports back what it just did. This is what
#                   advances the per-issue state machine; `--next` reads it.
#   --stop         request a clean stop. `--next` then answers `stop` before
#                   any further action, which is what "a typed stop halts it
#                   before the next action" means mechanically.
#
# Exit codes: 0 ok · 1 usage/setup error · 2 refused (not started, wrong repo,
#             unreadable state) · 3 the harm floor refused the action that was
#             asked for (`--next` prints `action blocked|halt` and the reason).
#             A harm check whose INPUT could not be established refuses the
#             same way and with the same code — an empty or failed diff is a
#             missing check, never a passed one.
#
# The per-issue state vocabulary, in order. `blocked`, `parked` and `closed`
# are terminal for an issue; the loop steps to the next admitted issue.
#
#   picked -> drafting -> filed -> dispatching(item N) -> awaiting-verify
#          -> verified -> merged(item N) -> [dispatching(N+1) | integration-tested]
#          -> closed | blocked | parked
#
# `integration-tested` (epic 21 item 5) is reached once, after every work item
# of the issue has merged and before it closes — never per item, the way
# `merged(item N)` is. A repo with nothing declared to check reaches it in the
# same `--next` call that found nothing left to dispatch, silently; a repo
# with a declared command or declared gates reaches it only after the session
# reports back via `--record --state integration-tested`.
#
# There is deliberately NO `awaiting-approval` state. epic-loop.sh had one
# because a human approved every plan between drafting and dispatch; this loop
# does not stop there, and the missing state is where that difference lives.

set -u

# --------------------------------------------------------------- this build
SESSION_LOOP_CONTRACT=1
# The mechanical statement of "not headless". A fixture greps this file for a
# `claude` invocation and asserts there is none; this marker is the claim that
# grep proves.
SESSION_LOOP_INVOKES_CLAUDE=no

# ------------------------------------------------------------------- binaries
# Prefixed names, not GIT_BIN/GH_BIN: this file SOURCES verify-item.sh and
# dispatch.sh, both of which define their own binary variables, and a shared
# name would let a sourced library silently redefine ours.
SESSION_LOOP_GIT="${INTAKE_GIT:-git}"
SESSION_LOOP_GH="${INTAKE_GH:-gh}"

SESSION_LOOP_BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_LOOP_STATUS_LIB="${INTAKE_STATUS_LIB:-$SESSION_LOOP_BIN_DIR/intake-status.sh}"
SESSION_LOOP_AUTONOMY_LIB="${INTAKE_AUTONOMY_LIB:-$SESSION_LOOP_BIN_DIR/autonomy.sh}"
SESSION_LOOP_DISPATCH_LIB="${INTAKE_DISPATCH_LIB:-$SESSION_LOOP_BIN_DIR/dispatch.sh}"
SESSION_LOOP_VERIFY_LIB="${INTAKE_VERIFY_ITEM_LIB:-$SESSION_LOOP_BIN_DIR/verify-item.sh}"
SESSION_LOOP_DPG_LIB="${INTAKE_DECLARED_PATHS_GATE_LIB:-$SESSION_LOOP_BIN_DIR/declared-paths-gate.sh}"
# The same declared-gate library dispatch.sh already sources (epic 11 item
# 2b/3), reused rather than re-derived for the per-issue integration check
# (epic 21 item 5): `provision_integration_test` and, on its refusal,
# `provision_gates ""` for the declared-gates fallback.
SESSION_LOOP_PROVISION_LIB="${INTAKE_PROVISION_LIB:-$SESSION_LOOP_BIN_DIR/worktree-provision.sh}"

# The admission label, one definition, matching the producing side exactly.
SESSION_LOOP_ADMISSION_LABEL="${INTAKE_ADMISSION_LABEL:-epic-loop-ready}"

# THE BINDING MARKER — one line naming the checkout a loop is currently bound
# to. It lives OUTSIDE any repo because that is the only place from which a
# `--start` on a DIFFERENT repo can see it: each repo's own loop record lives
# inside that repo, so a second repo's record would be an empty directory and
# the "one loop, one repo" rule would be unenforceable rather than enforced.
#
# It is machine-wide rather than session-wide, deliberately and with a known
# cost: a script invocation cannot see which Claude session called it, so this
# refuses a little more than the rule strictly needs (two SESSIONS looping two
# repos are refused too). For a surface that auto-merges, refusing too much is
# the correct direction to be wrong in, and the refusal names its own one-line
# remedy. A marker left behind by a session that died is cleared the same way.
SESSION_LOOP_MARKER="${INTAKE_SESSION_LOOP_MARKER:-$HOME/.config/claude-intake/session-loop}"

# How long the session should wait before its next wakeup, per action. Seconds.
# `poll` is long because it means "nothing is ready yet"; everything else is
# short because the session is about to do real work and the wakeup is only
# there to hand the turn back.
SESSION_LOOP_WAKE_POLL="${INTAKE_LOOP_WAKE_POLL:-300}"
SESSION_LOOP_WAKE_ACT="${INTAKE_LOOP_WAKE_ACT:-60}"

SESSION_LOOP_EPICS_DIR="${INTAKE_EPICS_DIR:-docs/epics}"

# ------------------------------------------------------------------- state
SESSION_LOOP_ROOT=""          # canonical repo root (main checkout, never a worktree)
SESSION_LOOP_DIR=""           # <root>/<epics>/.intake/session-loop
SESSION_LOOP_SLUG=""
SESSION_LOOP_REFUSAL=""
SESSION_LOOP_R_REPO=""
SESSION_LOOP_R_SLUG=""
SESSION_LOOP_R_STATE=""
SESSION_LOOP_R_ISSUE=""
SESSION_LOOP_R_ITEM=""
SESSION_LOOP_R_BRANCH=""
SESSION_LOOP_R_EPICS=""
SESSION_LOOP_R_INTEGRATION=""
SESSION_LOOP_ADMIT_REASON=""
SESSION_LOOP_HARM_REASON=""

# --------------------------------------------------------------- utilities

session_loop_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z'; }

# Sourcing is lazy and each failure is a NAMED refusal, never a crash: a
# missing sibling library must not look like "nothing to do".
session_loop_source() { # $1 = path, $2 = a function it must define
  local P="${1:-}" F="${2:-}"
  command -v "$F" >/dev/null 2>&1 && return 0
  if [ ! -r "$P" ]; then
    SESSION_LOOP_REFUSAL="required library not readable: $P"
    return 1
  fi
  # shellcheck disable=SC1090
  . "$P" 2>/dev/null
  if ! command -v "$F" >/dev/null 2>&1; then
    SESSION_LOOP_REFUSAL="sourced $P but it defines no $F() — wrong or truncated file"
    return 1
  fi
  return 0
}

# One field out of one of this control plane's flat one-key-per-line JSON
# records. Hand-parsed exactly as every other reader here does it: these files
# are written by this file, are a dozen lines long, and a jq dependency for
# that shape has been refused throughout this control plane.
session_loop_field() { # $1 = file, $2 = key -> stdout ("" when absent)
  [ -r "${1:-}" ] || return 0
  grep -o "\"${2:-}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" 2>/dev/null \
    | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//'
}

# ------------------------------------------------------------- the state tree
# Reuses intake-status.sh's reserved-tree machinery rather than re-deriving it:
# the canonical repo root, the refusal when a plan.md would make the tree
# resolvable as an epic, and the self-ignoring `.gitignore` are all guarantees
# that already exist and are already fixture-covered (GH #9, GH #11). This
# loop's own records live in a SIBLING directory of the intake tree, not in it
# — different producer, different lifetime, and a reader must never confuse a
# drafting cycle's record with a loop's.
session_loop_tree() { # $1 = a directory inside the repo -> sets ROOT/DIR
  local WHERE="${1:-.}"
  SESSION_LOOP_REFUSAL=""
  session_loop_source "$SESSION_LOOP_STATUS_LIB" intake_status_repo_root || return 1
  SESSION_LOOP_ROOT="$(intake_status_repo_root "$WHERE")"
  [ -n "$SESSION_LOOP_ROOT" ] && [ -d "$SESSION_LOOP_ROOT" ] || {
    SESSION_LOOP_REFUSAL="cannot resolve a repo root from [$WHERE]"
    return 1
  }
  if ! intake_status_tree "$SESSION_LOOP_ROOT" "$SESSION_LOOP_EPICS_DIR"; then
    SESSION_LOOP_REFUSAL="${INTAKE_STATUS_LAST_ERROR:-could not create the reserved intake tree}"
    return 1
  fi
  SESSION_LOOP_DIR="$(dirname "$INTAKE_STATUS_TREE_OUT")/session-loop"
  mkdir -p "$SESSION_LOOP_DIR" 2>/dev/null || {
    SESSION_LOOP_REFUSAL="cannot create $SESSION_LOOP_DIR"
    return 1
  }
  return 0
}

session_loop_state_file() { printf '%s/loop.json' "$SESSION_LOOP_DIR"; }
session_loop_issue_file() { printf '%s/issue-%s.json' "$SESSION_LOOP_DIR" "${1:-0}"; }

session_loop_read() { # loads the loop record into SESSION_LOOP_R_*
  local F
  F="$(session_loop_state_file)"
  SESSION_LOOP_R_REPO="$(session_loop_field "$F" repo)"
  SESSION_LOOP_R_SLUG="$(session_loop_field "$F" slug)"
  SESSION_LOOP_R_STATE="$(session_loop_field "$F" state)"
  SESSION_LOOP_R_ISSUE="$(session_loop_field "$F" issue)"
  SESSION_LOOP_R_EPICS="$(session_loop_field "$F" epics_dir)"
  SESSION_LOOP_R_INTEGRATION="$(session_loop_field "$F" integration)"
  [ -n "$SESSION_LOOP_R_STATE" ] || return 1
  return 0
}

# Every write is atomic (temp file beside the target, then mv) and every write
# is also appended to the ledger. The ledger is append-only and is the audit
# trail a human reads when a record and the repo disagree.
session_loop_write() { # $1=file  $2=body
  session_loop_source "$SESSION_LOOP_STATUS_LIB" intake_status_atomic || return 1
  printf '%s\n' "$2" | intake_status_atomic "$1"
}

session_loop_ledger() { # $1=kind $2=state $3=detail $4=issue
  [ -n "$SESSION_LOOP_DIR" ] || return 0
  session_loop_source "$SESSION_LOOP_STATUS_LIB" intake_status_escape || return 0
  printf '{"at":"%s","kind":"%s","state":"%s","issue":"%s","detail":"%s"}\n' \
    "$(session_loop_now)" "$(intake_status_escape "${1:-}")" \
    "$(intake_status_escape "${2:-}")" "$(intake_status_escape "${4:-}")" \
    "$(intake_status_escape "${3:-}")" \
    >> "$SESSION_LOOP_DIR/ledger.jsonl" 2>/dev/null || true
}

# ------------------------------------------------------------------ admission
# THE BODY CHECK. Reads an issue body on stdin; rc 0 = the body carries both
# human-authored sections with real content, rc 1 = it does not and
# SESSION_LOOP_ADMIT_REASON says which half is missing.
#
# A heading matches on its TEXT, not its level: `### Requirements`,
# `## Requirements` and `**Requirements:**` are one section, because the
# skeleton in author-issue names the text and a hand-written issue will not
# match a level. `Derived acceptance criteria` is explicitly NOT the
# human-authored one — it is Claude's, and admitting on it would let the
# machine satisfy its own admission test.
#
# "Real content" is at least two non-blank, non-heading lines before the next
# heading. One line is a template hint or a lone "TBD"; the invariant asks for
# DETAILED requirements and DETAILED criteria, and two lines is the cheapest
# honest reading of "detailed" that a machine can check without pretending to
# judge quality.
session_loop_body_admits() {
  local BODY
  BODY="$(cat)"
  SESSION_LOOP_ADMIT_REASON=""
  local MISSING=""
  local S
  for S in requirements "acceptance criteria"; do
    if ! printf '%s\n' "$BODY" | session_loop_section_has_content "$S"; then
      [ -n "$MISSING" ] && MISSING="$MISSING and "
      MISSING="$MISSING no detailed '$S' section"
    fi
  done
  if [ -n "$MISSING" ]; then
    SESSION_LOOP_ADMIT_REASON="$MISSING (human-authored requirements AND acceptance criteria are the epic's admission invariant)"
    return 1
  fi
  return 0
}

# $1 = section text, lower case. stdin = the body. rc 0 if the section exists
# with >= 2 lines of content under it.
session_loop_section_has_content() {
  awk -v want="${1:-}" '
    function norm(s) {
      s = tolower(s)
      gsub(/^[[:space:]]*#+[[:space:]]*/, "", s)     # ### Heading
      gsub(/\*\*/, "", s)                            # **Heading:**
      gsub(/[[:space:]]*:[[:space:]]*$/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function is_heading(s) {
      return (s ~ /^[[:space:]]*#+[[:space:]]/) || (s ~ /^[[:space:]]*\*\*[^*]+\*\*[[:space:]]*:?[[:space:]]*$/)
    }
    is_heading($0) {
      h = norm($0)
      # "derived acceptance criteria" is Claudes half, never the admission
      # evidence; anything containing "derived" closes the section instead of
      # opening it.
      if (h == want && h !~ /derived/) { inseg = 1; next }
      inseg = 0; next
    }
    inseg && $0 ~ /[^[:space:]]/ { n++ }
    END { exit (n >= 2 ? 0 : 1) }
  '
}

# The label half. $1 = a comma-fenced label list as `,a,b,` (the shape
# unattended-intake.sh already uses for the same job), rc 0 when the admission
# label is present.
session_loop_has_label() {
  case "${1:-}" in
    *",$SESSION_LOOP_ADMISSION_LABEL,"*) return 0 ;;
  esac
  return 1
}

# The whole admission decision for one issue. $1 = issue number.
# Sets SESSION_LOOP_ADMIT_REASON on refusal. Costs one `gh issue view`.
session_loop_admits() { # $1 = issue number
  local N="${1:-}" LINE LABELS BODY
  SESSION_LOOP_ADMIT_REASON=""
  LINE="$("$SESSION_LOOP_GH" issue view "$N" --repo "$SESSION_LOOP_SLUG" \
            --json labels -q '"," + ([.labels[].name] | join(",")) + ","' 2>/dev/null)" || LINE=""
  if [ -z "$LINE" ]; then
    SESSION_LOOP_ADMIT_REASON="could not read issue #$N's labels — parked rather than guessed"
    return 1
  fi
  LABELS="$LINE"
  if ! session_loop_has_label "$LABELS"; then
    SESSION_LOOP_ADMIT_REASON="no '$SESSION_LOOP_ADMISSION_LABEL' label"
    return 1
  fi
  BODY="$("$SESSION_LOOP_GH" issue view "$N" --repo "$SESSION_LOOP_SLUG" --json body -q .body 2>/dev/null)" || BODY=""
  if [ -z "$BODY" ]; then
    SESSION_LOOP_ADMIT_REASON="issue #$N has an empty or unreadable body"
    return 1
  fi
  # A HERE-DOC, NOT A PIPE, and for the reason autonomy_harm_check's own header
  # spells out: bash runs the right-hand side of a pipe in a SUBSHELL, so the
  # reason the body check sets would vanish the instant the pipe finished and
  # every parked issue would be parked for no stated cause.
  session_loop_body_admits <<ADMIT_BODY_EOF || return 1
$BODY
ADMIT_BODY_EOF
  return 0
}

# Every open issue carrying the admission label, oldest first — the loop works
# the backlog in filing order, not recency, so an issue cannot be starved by
# newer ones arriving. One line per issue: `<number><TAB><title>`.
session_loop_candidates() {
  "$SESSION_LOOP_GH" issue list --repo "$SESSION_LOOP_SLUG" --state open \
      --label "$SESSION_LOOP_ADMISSION_LABEL" --limit 100 \
      --json number,title -q '.[] | "\(.number)\t\(.title)"' 2>/dev/null \
    | sort -n -k1,1
}

# --------------------------------------------------------------- the harm floor
# Epic 21 item 2, called the way its own header sanctions for a sourced caller:
# `autonomy_resolve` first (this repo's own deny-paths/size additions are the
# caller's to apply), then `autonomy_harm_check` with a HERE-STRING, never a
# pipe — a pipe would run the function in a subshell and lose
# AUTONOMY_HARM_REASON, which that header states in as many words.
#
# $1 = branch (may be empty)  $2 = git-op string (may be empty)
# $3 = epic dir name to exclude from the collision scan (may be empty)
# $4 = diff paths, newline separated (may be empty)
# rc 0 = cleared. rc 1 = refused, SESSION_LOOP_HARM_REASON says why.
session_loop_harm_check() {
  local BRANCH="${1:-}" GIT_OP="${2:-}" EPIC_DIR="${3:-}" PATHS="${4:-}"
  local FILES=0 LINES=0
  SESSION_LOOP_HARM_REASON=""
  session_loop_source "$SESSION_LOOP_AUTONOMY_LIB" autonomy_harm_check || return 1
  [ -n "$PATHS" ] && FILES="$(printf '%s\n' "$PATHS" | grep -c . 2>/dev/null || printf '0')"
  if [ -n "$BRANCH" ] && [ -n "$SESSION_LOOP_R_INTEGRATION" ]; then
    LINES="$("$SESSION_LOOP_GIT" -C "$SESSION_LOOP_ROOT" diff --numstat \
               "${SESSION_LOOP_R_INTEGRATION}...${BRANCH}" 2>/dev/null \
               | autonomy_diff_size 2>/dev/null | awk '{print $2+0}')"
    case "${LINES:-}" in ''|*[!0-9]*) LINES=0 ;; esac
  fi
  autonomy_resolve "$SESSION_LOOP_ROOT" "$SESSION_LOOP_SLUG" >/dev/null 2>&1 || true
  if autonomy_harm_check --repo "$SESSION_LOOP_ROOT" --branch "$BRANCH" \
       --git-op "$GIT_OP" --files "$FILES" --lines "$LINES" \
       --epics-root "$SESSION_LOOP_ROOT/$SESSION_LOOP_EPICS_DIR" \
       --epic-dir "$EPIC_DIR" >/dev/null 2>&1 <<HARM_EOF
$PATHS
HARM_EOF
  then
    return 0
  fi
  SESSION_LOOP_HARM_REASON="${AUTONOMY_HARM_REASON:-the harm floor refused and gave no reason — treat as refused}"
  return 1
}

# A STOP refusal is not the same event as a denylist refusal, and the loop must
# not treat them the same way: STOP means the machine stops, everything else
# means THIS action cannot proceed and the loop steps past it.
session_loop_harm_is_stop() {
  case "${SESSION_LOOP_HARM_REASON:-}" in "STOP present"*) return 0 ;; esac
  return 1
}

# ------------------------------------------------------------- plan facts
session_loop_plan_integration() { # $1 = plan file -> stdout branch or empty
  [ -r "${1:-}" ] || return 0
  grep -i -m1 '^\*\*Integration branch:\*\*' "$1" 2>/dev/null \
    | sed -E -e 's/^[^:]*:\*\*[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//'
}

session_loop_plan_source_issue() { # $1 = plan file -> stdout issue number or empty
  [ -r "${1:-}" ] || return 0
  grep -i -m1 '^\*\*Source:\*\*' "$1" 2>/dev/null \
    | sed -E -e 's/.*#([0-9]+).*/\1/' -e 't' -e 's/.*//'
}

# The epic folder whose plan carries `Source: GH #<issue>`, if any. This is how
# an issue and an epic are related — the same `Source:` line the whole workflow
# already uses, never a name convention.
session_loop_epic_for_issue() { # $1 = issue number -> stdout folder name or empty
  local N="${1:-}" D PLAN
  [ -n "$N" ] || return 0
  for D in "$SESSION_LOOP_ROOT/$SESSION_LOOP_EPICS_DIR"/*/; do
    [ -d "$D" ] || continue
    PLAN="${D}plan.md"
    [ -r "$PLAN" ] || continue
    if [ "$(session_loop_plan_source_issue "$PLAN")" = "$N" ]; then
      basename "$D"
      return 0
    fi
  done
  return 0
}

# ------------------------------------------------------------------ --next
# ONE action per call, and the harm floor has already cleared anything that is
# not `poll` or `stop`. Printed as aligned `key value` lines — the same shape
# dispatch.sh and autonomy.sh already print, hand-parseable with awk.
session_loop_emit() { printf '%-14s %s\n' "${1:-}" "${2:-}"; }

session_loop_emit_action() { # $1=action $2=reason $3=wake
  session_loop_emit action "$1"
  session_loop_emit reason "$2"
  session_loop_emit wake-in "${3:-$SESSION_LOOP_WAKE_ACT}"
}

# The whole decision. Returns the exit code the CLI should use.
session_loop_next() {
  local ISSUE EPIC PLAN PLAN_REL BRANCH ITEM PHASE IFILE
  local ITEST GCMDS GLINE

  # 1. STOP FIRST, before anything is read from GitHub, before the state is
  #    consulted, and before any harm check spends a query. "A typed stop halts
  #    it before the next action" is enforced by this being the first branch.
  if [ "$(session_loop_field "$(session_loop_state_file)" stop)" = "yes" ]; then
    session_loop_emit_action stop "stop requested at $(session_loop_field "$(session_loop_state_file)" stopped_at) — the loop halts before the next action" 0
    return 0
  fi

  ISSUE="$SESSION_LOOP_R_ISSUE"
  IFILE="$(session_loop_issue_file "$ISSUE")"
  PHASE="$(session_loop_field "$IFILE" state)"
  case "$PHASE" in closed|blocked|parked|'') ISSUE="" ;; esac

  # 2. No active issue -> pick the next admitted one.
  if [ -z "$ISSUE" ]; then
    local N T
    while IFS="$(printf '\t')" read -r N T; do
      [ -n "$N" ] || continue
      case "$(session_loop_field "$(session_loop_issue_file "$N")" state)" in
        closed|blocked|parked) continue ;;
      esac
      if session_loop_admits "$N"; then
        ISSUE="$N"
        break
      fi
      session_loop_emit parked-issue "#$N — $SESSION_LOOP_ADMIT_REASON"
    done <<CAND_EOF
$(session_loop_candidates)
CAND_EOF
    if [ -z "$ISSUE" ]; then
      session_loop_emit_action poll "no admitted issue is ready to work — the loop keeps watching until Jonathan says stop" "$SESSION_LOOP_WAKE_POLL"
      return 0
    fi
  fi
  # Re-derived AFTER the selection above, never before it: the issue the loop
  # is about to work is not necessarily the one the loop record named when this
  # call started, and reading the previous issue's record here would attribute
  # one issue's branch and item to another.
  IFILE="$(session_loop_issue_file "$ISSUE")"
  PHASE="$(session_loop_field "$IFILE" state)"

  EPIC="$(session_loop_epic_for_issue "$ISSUE")"
  session_loop_emit issue "$ISSUE"
  [ -n "$EPIC" ] && session_loop_emit epic "$EPIC"

  # 3. No epic yet -> draft one, in this session, from the issue.
  if [ -z "$EPIC" ]; then
    if ! session_loop_harm_check "" "" "" ""; then
      session_loop_emit_action "$(session_loop_harm_is_stop && printf halt || printf blocked)" \
        "$SESSION_LOOP_HARM_REASON" 0
      return 3
    fi
    session_loop_emit_action draft "issue #$ISSUE is admitted and has no epic — draft one in-session per references/session-loop.md, file it at Status: approved, and dispatch item 1 without stopping"
    return 0
  fi

  PLAN="$SESSION_LOOP_ROOT/$SESSION_LOOP_EPICS_DIR/$EPIC/plan.md"
  PLAN_REL="$SESSION_LOOP_EPICS_DIR/$EPIC/plan.md"
  session_loop_emit plan "$PLAN_REL"
  [ -n "$SESSION_LOOP_R_INTEGRATION" ] || SESSION_LOOP_R_INTEGRATION="$(session_loop_plan_integration "$PLAN")"
  session_loop_emit integration "${SESSION_LOOP_R_INTEGRATION:-<unknown>}"

  BRANCH="$(session_loop_field "$IFILE" branch)"
  ITEM="$(session_loop_field "$IFILE" item)"

  # 4. An item is out with an executor -> is it ready to verify?
  if [ "$PHASE" = dispatching ] && [ -n "$BRANCH" ]; then
    session_loop_emit item "$ITEM"
    session_loop_emit branch "$BRANCH"
    local PRNUM
    PRNUM="$("$SESSION_LOOP_GH" pr list --repo "$SESSION_LOOP_SLUG" --head "$BRANCH" \
               --state open --json number -q '.[0].number' 2>/dev/null)" || PRNUM=""
    if [ -z "$PRNUM" ]; then
      session_loop_emit_action poll "item $ITEM is still running — no open pull request on $BRANCH yet" "$SESSION_LOOP_WAKE_POLL"
      return 0
    fi
    session_loop_emit pr "$PRNUM"
    if ! session_loop_source "$SESSION_LOOP_DPG_LIB" declared_paths_gate_run \
       || ! session_loop_source "$SESSION_LOOP_VERIFY_LIB" verify_item_deterministic_gates; then
      session_loop_emit_action blocked "$SESSION_LOOP_REFUSAL" 0
      return 2
    fi
    if verify_item_deterministic_gates "$SESSION_LOOP_ROOT" "$SESSION_LOOP_SLUG" "$PLAN" "$ITEM" \
         "$SESSION_LOOP_R_INTEGRATION" "$BRANCH" "$BRANCH" "$PRNUM"; then
      session_loop_emit_action verify "item $ITEM's four deterministic gates are clean — run the COLD acceptance-verifier in-session against the plan's DoD"
      return 0
    fi
    session_loop_emit_action poll "item $ITEM is not verifiable yet: ${VERIFY_ITEM_REFUSAL:-a deterministic gate did not clear}" "$SESSION_LOOP_WAKE_POLL"
    return 0
  fi

  # 5. A verified item -> merge it. HARM-CHECKED, against the REAL diff.
  if [ "$PHASE" = verified ] && [ -n "$BRANCH" ]; then
    session_loop_emit item "$ITEM"
    session_loop_emit branch "$BRANCH"
    local PATHS DIFF_RC=0 PATH_COUNT=0
    PATHS="$("$SESSION_LOOP_GIT" -c core.quotepath=false -C "$SESSION_LOOP_ROOT" \
               diff --name-only -M "${SESSION_LOOP_R_INTEGRATION}...${BRANCH}" 2>/dev/null)" || DIFF_RC=$?
    [ -n "$PATHS" ] && PATH_COUNT="$(printf '%s\n' "$PATHS" | grep -c . 2>/dev/null || printf '0')"
    case "${PATH_COUNT:-}" in ''|*[!0-9]*) PATH_COUNT=0 ;; esac
    # FAIL CLOSED ON THE INPUT, NOT JUST ON THE VERDICT. The denylist half of
    # the harm floor is only as good as the path list it is fed, and an empty
    # list clears it trivially (autonomy_harm_check's own header says so). This
    # driver never fetches, so `$BRANCH` may simply not resolve here — and a
    # diff that FAILED and a diff that found nothing both arrive as "" and
    # would clear the exact check that exists to catch a bad merge. Neither is
    # evidence of a safe merge, so neither is allowed to pass for one: an
    # unresolvable range is a broken precondition, and a verified item whose
    # merge would change no file is not a merge worth making unattended. Both
    # refuse, through the same emission the harm floor's own refusals use.
    if [ "$DIFF_RC" -ne 0 ] || [ "$PATH_COUNT" -eq 0 ]; then
      if [ "$DIFF_RC" -ne 0 ]; then
        SESSION_LOOP_HARM_REASON="merge harm check has no input: \`git diff --name-only ${SESSION_LOOP_R_INTEGRATION}...${BRANCH}\` exited $DIFF_RC (the range does not resolve in $SESSION_LOOP_ROOT — the branch may be unfetched, renamed or gone). Refused rather than harm-checked against an empty diff."
      else
        SESSION_LOOP_HARM_REASON="merge harm check has no input: \`git diff --name-only ${SESSION_LOOP_R_INTEGRATION}...${BRANCH}\` resolved but names zero changed files. A verified item that changes nothing is not merged unattended."
      fi
      session_loop_emit_action "$(session_loop_harm_is_stop && printf halt || printf blocked)" \
        "$SESSION_LOOP_HARM_REASON" 0
      return 3
    fi
    if ! session_loop_harm_check "$BRANCH" "merge --no-ff $BRANCH" "$EPIC" "$PATHS"; then
      session_loop_emit_action "$(session_loop_harm_is_stop && printf halt || printf blocked)" \
        "$SESSION_LOOP_HARM_REASON" 0
      return 3
    fi
    session_loop_emit harm-check "pass (merge)"
    session_loop_emit_action merge "item $ITEM verified and the harm floor cleared the real diff — merge into $SESSION_LOOP_R_INTEGRATION, then land-and-reset per Phase 3 step 10"
    return 0
  fi

  # 6. Otherwise: is there a next item to dispatch (a CHAIN action), or is the
  #    epic finished and the issue ready to close (also a chain action — it is
  #    what advances the loop to the next issue)?
  if ! session_loop_source "$SESSION_LOOP_DISPATCH_LIB" dispatch_select; then
    session_loop_emit_action blocked "$SESSION_LOOP_REFUSAL" 0
    return 2
  fi
  if ! dispatch_load_signals "$SESSION_LOOP_SLUG"; then
    session_loop_emit_action poll "dispatchability cannot be decided right now: ${DISPATCH_REFUSAL:-gh could not be read}" "$SESSION_LOOP_WAKE_POLL"
    return 0
  fi
  if dispatch_select "$SESSION_LOOP_ROOT" "$SESSION_LOOP_EPICS_DIR"; then
    if [ "$DISPATCH_EPIC" != "$EPIC" ]; then
      # dispatch_select answers repo-wide, in-flight epics first. A different
      # epic winning means the loop's active issue is not the repo's most
      # urgent work; say so rather than dispatching an item this issue's
      # record knows nothing about.
      session_loop_emit other-epic "$DISPATCH_EPIC"
    fi
    if ! session_loop_harm_check "$DISPATCH_BRANCH" "" "$DISPATCH_EPIC" ""; then
      session_loop_emit_action "$(session_loop_harm_is_stop && printf halt || printf blocked)" \
        "$SESSION_LOOP_HARM_REASON" 0
      return 3
    fi
    session_loop_emit harm-check "pass (chain)"
    session_loop_emit item "$DISPATCH_ITEM"
    session_loop_emit branch "$DISPATCH_BRANCH"
    session_loop_emit title "$DISPATCH_TITLE"
    session_loop_emit_action dispatch "next undispatched item of $DISPATCH_EPIC — dispatch work-item-executor into its own worktree, unchanged"
    return 0
  fi
  if [ -n "${DISPATCH_REFUSAL:-}" ]; then
    session_loop_emit_action blocked "$DISPATCH_REFUSAL" 0
    return 2
  fi

  # 7. Nothing left to dispatch anywhere -> ONE per-issue integration check
  #    before close (epic 21 item 5), unless it has already run for this
  #    issue. Reused declared-gate pattern from worktree-provisioning.md: a
  #    declared `integration-test` command wins; where none is declared, the
  #    repo's own declared `gates.*` are the closest available check (never an
  #    invented one); where NEITHER is declared, this is silent and the gap is
  #    a known one, not a defect (see the plan's Deferred parking lot).
  if [ "$PHASE" != integration-tested ]; then
    if ! session_loop_source "$SESSION_LOOP_PROVISION_LIB" provision_resolve; then
      session_loop_emit_action blocked "$SESSION_LOOP_REFUSAL" 0
      return 2
    fi
    if ! provision_resolve "$SESSION_LOOP_ROOT" "$SESSION_LOOP_SLUG"; then
      session_loop_emit_action blocked "${PROVISION_REFUSAL:-provisioning config could not be resolved}" 0
      return 2
    fi
    if ITEST="$(provision_integration_test)"; then
      session_loop_emit command "$ITEST"
      session_loop_emit_action integration-test "run the declared integration-test command for $SESSION_LOOP_SLUG above (once for issue #$ISSUE, post-merge, pre-close), then \`session-loop.sh --record --issue $ISSUE --state integration-tested --detail \"pass|fail: <output summary>\"\`. On FAIL, file it FIRST via \`bin/issue-filer.sh --file --repo $SESSION_LOOP_ROOT --issue $ISSUE --item issue-level --check \"integration-test\" --evidence \"<the command's own failure output>\"\` — the same call site pattern dispatch's blocked handling already uses — THEN record integration-tested; filing is the terminal action and never blocks the record or the chain to close." \
        "$SESSION_LOOP_WAKE_ACT"
      return 0
    fi
    if [ -n "$PROVISION_GATE_TYPES" ]; then
      GCMDS="$(provision_gates "")"
      while IFS= read -r GLINE; do
        [ -n "$GLINE" ] || continue
        session_loop_emit command "$GLINE"
      done <<GATES_FALLBACK_EOF
$GCMDS
GATES_FALLBACK_EOF
      session_loop_emit_action integration-test "no integration-test command is declared for $SESSION_LOOP_SLUG — running its declared gates.* above as the closest available check instead (epic 21 item 5's own scope: never invent one). Run every command, then \`--record --issue $ISSUE --state integration-tested --detail \"pass|fail: <summary>\"\`, filing a FAIL first via bin/issue-filer.sh --file the same way." \
        "$SESSION_LOOP_WAKE_ACT"
      return 0
    fi
    session_loop_emit integration-test "skipped — $SESSION_LOOP_SLUG declares neither integration-test nor gates.<type>; nothing invented, this is the plan's own Deferred gap, not a defect"
  fi

  # 8. Every work item merged and the per-issue integration check is settled
  #    (or, for a repo declaring neither check, silently not applicable) ->
  #    this issue's epic is done.
  if ! session_loop_harm_check "" "" "$EPIC" ""; then
    session_loop_emit_action "$(session_loop_harm_is_stop && printf halt || printf blocked)" \
      "$SESSION_LOOP_HARM_REASON" 0
    return 3
  fi
  session_loop_emit harm-check "pass (chain)"
  session_loop_emit_action close "every work item of $EPIC has landed — close the epic (Phase 5) and the issue, then take the next admitted issue"
  return 0
}

# ---------------------------------------------------------------- --dry-run
# The projected happy-path SEQUENCE, for every admitted issue in the order the
# loop would take them. A PREVIEW OF THE SHAPE, NOT A CLAIM ABOUT PERMISSION —
# the same words epic-loop.sh's own --dry-run earned, for the same reason: a
# harm check that passes now may refuse later, and a verifier may say fail.
# Writes nothing, and calls nothing that mutates.
session_loop_preview() {
  local N T EPIC PLAN ID BR GT DEP TITLE COUNT=0
  printf 'DRY RUN — projected happy path. A preview of the shape, not a claim\n'
  printf '         about permission: the harm floor runs for real at every merge\n'
  printf '         and every chain, and can refuse any step below.\n\n'
  if [ "$(session_loop_field "$(session_loop_state_file)" stop)" = "yes" ]; then
    printf 'stop         requested at %s — the loop halts before the next action, and\n' \
      "$(session_loop_field "$(session_loop_state_file)" stopped_at)"
    printf '             nothing below would run.\n'
    return 0
  fi
  while IFS="$(printf '\t')" read -r N T; do
    [ -n "$N" ] || continue
    case "$(session_loop_field "$(session_loop_issue_file "$N")" state)" in
      closed) printf 'issue #%-5s %s\n  skip       already closed by this loop\n' "$N" "$T"; continue ;;
      blocked|parked) printf 'issue #%-5s %s\n  skip       parked/blocked — a human decides, the loop steps past it\n' "$N" "$T"; continue ;;
    esac
    printf 'issue #%-5s %s\n' "$N" "$T"
    if ! session_loop_admits "$N"; then
      printf '  park       %s\n' "$SESSION_LOOP_ADMIT_REASON"
      continue
    fi
    COUNT=$((COUNT + 1))
    printf '  admitted   %s label + human-authored requirements and acceptance criteria\n' "$SESSION_LOOP_ADMISSION_LABEL"
    EPIC="$(session_loop_epic_for_issue "$N")"
    if [ -z "$EPIC" ]; then
      printf '  draft      in-session plan from the issue; filed at Status: approved (no approval stop)\n'
      printf '  dispatch   item 1 .. item M  [harm check before each chain]\n'
      printf '  verify     cold acceptance-verifier per item [4 deterministic gates first]\n'
      printf '  merge      per item [harm check against the real diff]\n'
      printf '  close      epic closed (Phase 5), issue #%s closed\n' "$N"
      continue
    fi
    PLAN="$SESSION_LOOP_ROOT/$SESSION_LOOP_EPICS_DIR/$EPIC/plan.md"
    printf '  epic       %s (already filed — no drafting needed)\n' "$EPIC"
    if session_loop_source "$SESSION_LOOP_DISPATCH_LIB" dispatch_work_items; then
      while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
        [ -n "${ID:-}" ] || continue
        printf '  item %-5s dispatch %s -> verify -> [harm check] -> merge\n' "$ID" "${BR:-<no branch line — REFUSED>}"
      done <<PREVIEW_ITEMS_EOF
$(dispatch_work_items < "$PLAN")
PREVIEW_ITEMS_EOF
    fi
    printf '  close      [harm check] epic closed (Phase 5), issue #%s closed\n' "$N"
  done <<PREVIEW_EOF
$(session_loop_candidates)
PREVIEW_EOF
  printf '\n%s admitted issue(s) would be chained in this order.\n' "$COUNT"
  printf 'stop         `session-loop.sh --stop` (or Jonathan typing stop) halts before the next action.\n'
  return 0
}

# ---------------------------------------------------------------------- CLI
_session_loop_usage() { sed -n '1,10p' "$0"; }

_session_loop_cli() {
  local MODE="" REPO="." SLUG="" ISSUE="" ITEM="" BRANCH="" DETAIL="" STATE=""
  local DRY=no INTEGRATION=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --start)       MODE=start ;;
      --status)      MODE=status ;;
      --admit)       MODE=admit ;;
      --next)        MODE=next ;;
      --record)      MODE=record ;;
      --stop)        MODE=stop ;;
      --repo)        REPO="${2:-}"; shift ;;
      --slug)        SLUG="${2:-}"; shift ;;
      --epics-dir)   SESSION_LOOP_EPICS_DIR="${2:-}"; shift ;;
      --integration) INTEGRATION="${2:-}"; shift ;;
      --issue)       ISSUE="${2:-}"; shift ;;
      --item)        ITEM="${2:-}"; shift ;;
      --branch)      BRANCH="${2:-}"; shift ;;
      --state)       STATE="${2:-}"; shift ;;
      --detail)      DETAIL="${2:-}"; shift ;;
      --dry-run)     DRY=yes ;;
      -h|--help)     _session_loop_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done
  [ -n "$MODE" ] || { _session_loop_usage; return 1; }

  if ! session_loop_tree "$REPO"; then
    printf 'REFUSED — %s\n' "$SESSION_LOOP_REFUSAL" >&2
    return 2
  fi

  # The slug: given, or asked of `gh` in the checkout — the same fallback
  # autonomy.sh's own CLI uses, and never guessed from a directory name.
  if [ -z "$SLUG" ]; then
    SLUG="$(session_loop_field "$(session_loop_state_file)" slug)"
  fi
  if [ -z "$SLUG" ]; then
    SLUG="$("$SESSION_LOOP_GH" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
              || ( cd "$SESSION_LOOP_ROOT" 2>/dev/null && "$SESSION_LOOP_GH" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null ))" || SLUG=""
  fi
  SESSION_LOOP_SLUG="$SLUG"

  case "$MODE" in
    start)
      local BOUND BOUND_REC
      BOUND="$(head -1 "$SESSION_LOOP_MARKER" 2>/dev/null)"
      if [ -n "$BOUND" ] && [ "$BOUND" != "$SESSION_LOOP_ROOT" ]; then
        # A marker naming a repo whose own record says the loop STOPPED is
        # stale, and stale is not a reason to refuse: the normal stop path
        # clears the marker, and this is the belt to that braces.
        BOUND_REC="$BOUND/$SESSION_LOOP_EPICS_DIR/.intake/session-loop/loop.json"
        if [ "$(session_loop_field "$BOUND_REC" state)" = running ] \
           && [ "$(session_loop_field "$BOUND_REC" stop)" != yes ]; then
          printf 'REFUSED — a loop is already bound to %s. One loop, one repo, one live\n' "$BOUND" >&2
          printf '          session: multi-repo looping is out of scope for epic 21 by name,\n' >&2
          printf '          not by accident. Stop that one first:\n' >&2
          printf '            session-loop.sh --stop --repo %s\n' "$BOUND" >&2
          return 2
        fi
      fi
      [ -n "$SESSION_LOOP_SLUG" ] || { printf 'REFUSED — cannot resolve owner/name for %s via gh\n' "$SESSION_LOOP_ROOT" >&2; return 2; }
      [ -n "$INTEGRATION" ] || INTEGRATION="$("$SESSION_LOOP_GIT" -C "$SESSION_LOOP_ROOT" symbolic-ref --short HEAD 2>/dev/null)"
      if [ "$DRY" = yes ]; then
        printf 'DRY RUN — would bind the loop to %s (%s), integration %s\n' \
          "$SESSION_LOOP_ROOT" "$SESSION_LOOP_SLUG" "${INTEGRATION:-<unknown>}"
        return 0
      fi
      session_loop_write "$(session_loop_state_file)" "$(printf '{\n  "repo": "%s",\n  "slug": "%s",\n  "state": "running",\n  "issue": "",\n  "epics_dir": "%s",\n  "integration": "%s",\n  "stop": "no",\n  "started": "%s",\n  "updated": "%s"\n}' \
        "$SESSION_LOOP_ROOT" "$SESSION_LOOP_SLUG" "$SESSION_LOOP_EPICS_DIR" "${INTEGRATION:-}" "$(session_loop_now)" "$(session_loop_now)")" || {
        printf 'REFUSED — could not write %s\n' "$(session_loop_state_file)" >&2; return 2; }
      mkdir -p "$(dirname "$SESSION_LOOP_MARKER")" 2>/dev/null || true
      printf '%s\n' "$SESSION_LOOP_ROOT" > "$SESSION_LOOP_MARKER" 2>/dev/null || true
      session_loop_ledger loop running "started on $SESSION_LOOP_SLUG" ""
      session_loop_emit repo "$SESSION_LOOP_ROOT"
      session_loop_emit slug "$SESSION_LOOP_SLUG"
      session_loop_emit integration "${INTEGRATION:-<unknown>}"
      session_loop_emit state running
      session_loop_emit state-dir "$SESSION_LOOP_DIR"
      return 0 ;;

    status)
      if ! session_loop_read; then
        printf 'no loop has been started in %s\n' "$SESSION_LOOP_ROOT"
        return 0
      fi
      session_loop_emit repo "$SESSION_LOOP_R_REPO"
      session_loop_emit slug "$SESSION_LOOP_R_SLUG"
      session_loop_emit state "$SESSION_LOOP_R_STATE"
      session_loop_emit stop "$(session_loop_field "$(session_loop_state_file)" stop)"
      session_loop_emit integration "$SESSION_LOOP_R_INTEGRATION"
      session_loop_emit issue "${SESSION_LOOP_R_ISSUE:-<none>}"
      if [ -n "$SESSION_LOOP_R_ISSUE" ]; then
        session_loop_emit issue-state "$(session_loop_field "$(session_loop_issue_file "$SESSION_LOOP_R_ISSUE")" state)"
        session_loop_emit issue-item  "$(session_loop_field "$(session_loop_issue_file "$SESSION_LOOP_R_ISSUE")" item)"
        session_loop_emit issue-branch "$(session_loop_field "$(session_loop_issue_file "$SESSION_LOOP_R_ISSUE")" branch)"
      fi
      session_loop_emit state-dir "$SESSION_LOOP_DIR"
      return 0 ;;

    admit)
      [ -n "$SESSION_LOOP_SLUG" ] || { printf 'REFUSED — no repo slug\n' >&2; return 2; }
      if [ -n "$ISSUE" ]; then
        if session_loop_admits "$ISSUE"; then
          printf '#%-6s admitted\n' "$ISSUE"
          return 0
        fi
        printf '#%-6s parked — %s\n' "$ISSUE" "$SESSION_LOOP_ADMIT_REASON"
        return 0
      fi
      local N T
      while IFS="$(printf '\t')" read -r N T; do
        [ -n "$N" ] || continue
        if session_loop_admits "$N"; then
          printf '#%-6s admitted   %s\n' "$N" "$T"
        else
          printf '#%-6s parked     %s — %s\n' "$N" "$T" "$SESSION_LOOP_ADMIT_REASON"
        fi
      done <<ADMIT_EOF
$(session_loop_candidates)
ADMIT_EOF
      return 0 ;;

    next)
      if ! session_loop_read; then
        printf 'REFUSED — no loop is running in %s. Start one first: session-loop.sh --start --repo %s\n' \
          "$SESSION_LOOP_ROOT" "$SESSION_LOOP_ROOT" >&2
        return 2
      fi
      [ -n "$SESSION_LOOP_SLUG" ] || SESSION_LOOP_SLUG="$SESSION_LOOP_R_SLUG"
      if [ "$DRY" = yes ]; then
        session_loop_preview
        return 0
      fi
      session_loop_next
      return $? ;;

    record)
      session_loop_read || { printf 'REFUSED — no loop is running in %s\n' "$SESSION_LOOP_ROOT" >&2; return 2; }
      [ -n "$STATE" ] || { printf 'REFUSED — --record needs --state\n' >&2; return 1; }
      [ -n "$ISSUE" ] || ISSUE="$SESSION_LOOP_R_ISSUE"
      [ -n "$ISSUE" ] || { printf 'REFUSED — --record needs --issue (no active issue on the loop record)\n' >&2; return 1; }
      if [ "$DRY" = yes ]; then
        printf 'DRY RUN — would record issue #%s state=%s item=%s branch=%s\n' "$ISSUE" "$STATE" "${ITEM:-}" "${BRANCH:-}"
        return 0
      fi
      session_loop_source "$SESSION_LOOP_STATUS_LIB" intake_status_escape || { printf 'REFUSED — %s\n' "$SESSION_LOOP_REFUSAL" >&2; return 2; }
      session_loop_write "$(session_loop_issue_file "$ISSUE")" "$(printf '{\n  "issue": "%s",\n  "state": "%s",\n  "item": "%s",\n  "branch": "%s",\n  "detail": "%s",\n  "updated": "%s"\n}' \
        "$(intake_status_escape "$ISSUE")" "$(intake_status_escape "$STATE")" \
        "$(intake_status_escape "$ITEM")" "$(intake_status_escape "$BRANCH")" \
        "$(intake_status_escape "$DETAIL")" "$(session_loop_now)")" || {
        printf 'REFUSED — could not write %s\n' "$(session_loop_issue_file "$ISSUE")" >&2; return 2; }
      session_loop_ledger issue "$STATE" "$DETAIL" "$ISSUE"
      # The loop record follows the active issue, and lets go of it the moment
      # the issue reaches one of its terminal states — otherwise the next
      # `--next` would keep re-reading a finished issue instead of chaining.
      local ACTIVE="$ISSUE"
      case "$STATE" in closed|blocked|parked) ACTIVE="" ;; esac
      session_loop_write "$(session_loop_state_file)" "$(printf '{\n  "repo": "%s",\n  "slug": "%s",\n  "state": "%s",\n  "issue": "%s",\n  "epics_dir": "%s",\n  "integration": "%s",\n  "stop": "%s",\n  "started": "%s",\n  "updated": "%s"\n}' \
        "$SESSION_LOOP_R_REPO" "$SESSION_LOOP_R_SLUG" "$SESSION_LOOP_R_STATE" "$ACTIVE" \
        "${SESSION_LOOP_R_EPICS:-$SESSION_LOOP_EPICS_DIR}" "$SESSION_LOOP_R_INTEGRATION" \
        "$(session_loop_field "$(session_loop_state_file)" stop)" \
        "$(session_loop_field "$(session_loop_state_file)" started)" "$(session_loop_now)")" || true
      printf 'recorded issue #%s state=%s%s\n' "$ISSUE" "$STATE" \
        "$( [ -n "$ITEM" ] && printf ' item=%s' "$ITEM" )"
      return 0 ;;

    stop)
      session_loop_read || { printf 'no loop is running in %s — nothing to stop\n' "$SESSION_LOOP_ROOT"; return 0; }
      if [ "$DRY" = yes ]; then
        printf 'DRY RUN — would request a clean stop of the loop on %s\n' "$SESSION_LOOP_R_SLUG"
        return 0
      fi
      session_loop_write "$(session_loop_state_file)" "$(printf '{\n  "repo": "%s",\n  "slug": "%s",\n  "state": "stopped",\n  "issue": "%s",\n  "epics_dir": "%s",\n  "integration": "%s",\n  "stop": "yes",\n  "started": "%s",\n  "stopped_at": "%s",\n  "detail": "%s",\n  "updated": "%s"\n}' \
        "$SESSION_LOOP_R_REPO" "$SESSION_LOOP_R_SLUG" "$SESSION_LOOP_R_ISSUE" \
        "${SESSION_LOOP_R_EPICS:-$SESSION_LOOP_EPICS_DIR}" "$SESSION_LOOP_R_INTEGRATION" \
        "$(session_loop_field "$(session_loop_state_file)" started)" "$(session_loop_now)" \
        "${DETAIL:-stop requested}" "$(session_loop_now)")" || {
        printf 'REFUSED — could not write the stop into %s\n' "$(session_loop_state_file)" >&2; return 2; }
      session_loop_ledger loop stopped "${DETAIL:-stop requested}" "$SESSION_LOOP_R_ISSUE"
      if [ "$(head -1 "$SESSION_LOOP_MARKER" 2>/dev/null)" = "$SESSION_LOOP_ROOT" ]; then
        rm -f "$SESSION_LOOP_MARKER" 2>/dev/null || true
      fi
      printf 'stopped — the loop halts before its next action. Work already pushed is safe.\n'
      return 0 ;;
  esac
  _session_loop_usage
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _session_loop_cli "$@"
  exit $?
fi
