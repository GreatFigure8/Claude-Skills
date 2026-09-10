#!/usr/bin/env bash
# verify-item.sh — the verify phase, cold acceptance check — epic 19
# (epic-loop) item 5.
#
# THE SHAPE THIS ITEM BUILDS, AND NOTHING MORE. When an issue's state machine
# (item 1) reaches `awaiting-verify`, this script decides whether the item's
# pull request is acceptable — never by fixing it, never by remediating it,
# only by judging and reporting. Judgement happens in two layers:
#
#   1. FOUR DETERMINISTIC GATES, cheap and cheatable-only-by-lying-to-git/gh,
#      checked BEFORE anything expensive runs:
#        a. the executor's own status.json shows `pr-opened` (which, because
#           that contract's milestones only move forward, is only reachable
#           after `gates-passed` — so this one field stands for both)
#        b. `declared-paths-gate.sh` (epic 10 item 3) reports CLEAN — not
#           merely "not declared", an exact match, for this phase specifically
#        c. `gh pr checks` is green
#        d. the REAL diff, `git diff --name-only` between the PR's base and
#           head, clears the sensitive-path denylist floor (autonomy.sh)
#      Any one of these failing REFUSES before a session is even started —
#      "no wasted session on ungated work" is this item's own DoD line, and it
#      is enforced here, not hoped for.
#   2. ONLY THEN, a COLD verifier session — a fresh `claude -p --agent
#      acceptance-verifier` run via `phase-session.sh` (item 3's harness,
#      "per this epic's phase-session pattern" per the plan) — is handed
#      exactly three things and nothing else: the item's `**DoD:**` bullet
#      verbatim from the plan, the source issue's body (never invented,
#      omitted honestly if no `--issue` was given or `gh` could not read it),
#      and the PR's real diff. It has NO memory of the executor that built the
#      PR — that isolation is the entire point of a COLD check.
#
# WHAT THIS ITEM DELIBERATELY DOES NOT DO: fix a failed item. A `fail` verdict
# is reported and nothing else; routing that to `blocked` and never
# auto-retrying it is the CALLER's job (epic-loop.sh), not this script's.
# This script also never merges, never edits the plan, never touches any
# branch — it only reads the diff, judges it, and writes a verdict.
#
# THE VERDICT SHAPE, concretely (the plan's own shorthand `{pass|fail,
# criteria:[{text, met, evidence}]}` spelled out exactly, one JSON key per
# line — the same hand-parsed convention every other JSON file in this
# control plane uses, never a jq dependency for a file this shape):
#
#   {
#     "verdict": "pass",
#     "criteria": [
#       { "text": "...", "met": true, "evidence": "..." }
#     ]
#   }
#
# `verdict` is `pass` only if EVERY criterion's `met` is `true`; one `false`
# makes the whole verdict `fail`, and that criterion's `evidence` must NAME
# what is missing — the plan's own DoD line: "a synthetic PR with a
# deliberately unmet DoD line produces `fail` naming that specific unmet
# line". This script does not judge that itself (a cold LLM session does);
# this script only refuses to let an invalid or missing verdict pass itself
# off as one (see `verify_item_verdict_valid` below), matching
# phase-session.sh's own "never fabricate what a session did not actually
# say" discipline for its handoff.
#
# CONTRACT MARKER, the sibling of EPIC_LOOP_CONTRACT / PHASE_SESSION_CONTRACT
# / DISPATCH_ENFORCED — a fixture greps for it.
VERIFY_ITEM_CONTRACT=1
#
# Usage:
#   verify-item.sh --plan <path/to/plan.md> --item <N> --pr <number-or-url>
#                   [--repo <checkout>] [--slug <owner/repo>]
#                   [--base <integration-branch>] [--issue <source-issue-n>]
#                   [--state-file <path>] [--epic <epic-relative-plan-path>]
#                   [--model <name>] [--agent <name>] [--timeout <seconds>]
#                   [--verdict <path>]
#
#   --plan         path to the epic's plan.md (required)
#   --item         the work item number, matching its `### N. ` heading
#                   (required) — also accepts a split-item id, e.g. `3a`
#   --pr           the pull request number, or any URL ending in one (e.g.
#                   `https://github.com/o/r/pull/42`) (required)
#   --repo         the checkout to run git/gh in. Default: `.` — this is the
#                   driver's OWN main checkout (never a worktree), same
#                   convention every other epic-loop.sh gate uses.
#   --slug         `owner/repo`. Default: inferred via `gh repo view` in
#                   --repo, same fallback autonomy.sh's own CLI uses.
#   --base         override the integration branch the diff is measured
#                   against. Default: the PR's own `baseRefName` (from
#                   `gh pr view`) — trust the PR's own record of what it
#                   targets rather than assuming.
#   --issue        the SOURCE issue number (the epic's `Source: GH #n`, not
#                   the work item) — its body becomes the "observed/expected"
#                   text in the verifier's brief. Omitted honestly (never
#                   invented) when not given or unreadable.
#   --state-file   the per-issue state file, passed straight through to
#                   phase-session.sh for its own handoff fallback derivation.
#                   Optional.
#   --epic         epic-relative plan path override, passed straight through
#                   to phase-session.sh for the same fallback. Optional.
#   --model        default: opus (the plan's Log: "Verifier model: Opus for
#                   the verify phase; Sonnet for every other phase").
#   --agent        default: acceptance-verifier.
#   --timeout      seconds before the session is killed. Default: same as
#                   phase-session.sh's own default (INTAKE_PHASE_SESSION_TIMEOUT
#                   or 3600), passed straight through.
#   --verdict      override where the verdict is expected. Default:
#                   `<repo>/docs/epics/verdict.json` — the sibling of
#                   `docs/epics/handoff.md`, named explicitly in the brief
#                   (phase-session.sh's own A1 mitigation, applied here too:
#                   never rely on a session inferring a path).
#
# Exit codes:
#   0 = verdict PASS — a valid verdict.json exists and was posted as a PR
#       comment.
#   1 = verdict FAIL — a valid verdict.json exists and was posted as a PR
#       comment. THE CALLER routes this item to `blocked` and never
#       auto-retries it; this script does not do that itself.
#   2 = REFUSED before any verifier session started — one of the four
#       deterministic gates did not clear. No session ran, no verdict.json
#       was touched, no PR comment was posted. This is not a fail verdict —
#       the caller should leave the item parked and retry later.
#   3 = the verifier session ran (or the harness could not even start it) but
#       produced no usable verdict.json — genuinely inconclusive, never
#       fabricated as pass or fail. The caller should retry later.
#   4 = usage or setup error (bad arguments, unreadable plan, the PR could
#       not be read via `gh pr view`, a required library missing) — fix the
#       invocation and rerun; this is never a clean outcome and never a WARN.
#
# Sourced use: `. verify-item.sh` exposes every `verify_item_*` function below
# without executing the CLI, for a fixture harness that wants the parsed
# pieces (DoD extraction, verdict validity, the deterministic gates) directly.

set -u

# ------------------------------------------------------------------- binaries
GIT_BIN="${INTAKE_GIT:-/usr/bin/git}"
GH_BIN="${INTAKE_GH:-/opt/homebrew/bin/gh}"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTONOMY_LIB="${INTAKE_AUTONOMY_LIB:-$BIN_DIR/autonomy.sh}"
DECLARED_PATHS_GATE_LIB="${INTAKE_DECLARED_PATHS_GATE_LIB:-$BIN_DIR/declared-paths-gate.sh}"
PHASE_SESSION_BIN="${INTAKE_PHASE_SESSION:-$BIN_DIR/phase-session.sh}"

VERIFY_ITEM_MODEL_DEFAULT="${INTAKE_VERIFY_ITEM_MODEL:-opus}"
VERIFY_ITEM_AGENT_DEFAULT="${INTAKE_VERIFY_ITEM_AGENT:-acceptance-verifier}"
VERIFY_ITEM_TIMEOUT_DEFAULT="${INTAKE_PHASE_SESSION_TIMEOUT:-3600}"

# THE ALLOWLIST. Deliberately narrower than dispatch.sh's own executor grant —
# this session reads a diff and writes one file; it has no business pushing,
# committing, commenting, or merging anything. Enforced by what it cannot
# invoke, same discipline dispatch_allowed_tools documents for its own
# absences: "L2's ceiling is ... enforced by what the executor cannot invoke
# rather than by what it was asked not to do."
VERIFY_ITEM_ALLOWED_TOOLS="${INTAKE_VERIFY_ITEM_TOOLS:-Read Grep Glob Write Bash(gh pr view:*) Bash(gh pr diff:*) Bash(gh issue view:*) Bash(git show:*) Bash(git diff:*) Bash(git log:*) Bash(cat:*) Bash(head:*) Bash(tail:*) Bash(wc:*) Bash(grep:*) Bash(sed:*)}"

# THE DIFF SIZE THIS BRIEF WILL EMBED VERBATIM. A safety cap, not a real
# limit — a synthetic or real work-item diff several times this size is
# already a plan-scoping problem, not something this brief should silently
# swallow into an enormous prompt.
VERIFY_ITEM_DIFF_LINE_CAP=3000

# --------------------------------------------------------- branch <-> slug
# Duplicated rather than sourced from dispatch.sh: dispatch.sh is a 1000+ line
# top-level script with its own preflight and locking, never designed to be
# sourced for one line of logic — the same reasoning epic-loop.sh's own
# epic_loop_parse_recommendation gives for duplicating unattended-intake.sh's
# parse rather than sourcing that file.
verify_item_branch_slug() { # $1 = branch -> stdout
  printf '%s' "${1:-}" | tr '/' '-' 2>/dev/null
}

# ------------------------------------------------------------- plan parsing
# The item's own `### N. <title>` heading text, stripped of the numbering.
# $1=plan $2=item -> stdout title or empty.
verify_item_extract_title() {
  awk -v item="${2:-}" '
    /^### [0-9]+[a-z]?\./ {
      n = $0; t = $0
      sub(/^### /, "", n); sub(/\..*$/, "", n)
      sub(/^### [0-9]+[a-z]?\.[[:space:]]*/, "", t)
      if (n == item) { print t; exit }
    }
  ' "${1:-}"
}

# The item's `- **DoD:**` bullet, flattened to one line (continuation lines
# are joined with a single space, the same "unwrap a bullet's continuation"
# shape declared_paths_gate_extract_touches uses for `**Touches:**`, except
# DoD is prose to flatten rather than a list to enumerate). Empty stdout, rc 0,
# when the item exists but declares no DoD (a plan malformed enough to lack
# one is not this script's problem to invent around); rc 1 only when the
# item's own heading cannot be found at all.
verify_item_extract_dod() { # $1=plan $2=item
  local PLAN="${1:-}" ITEM="${2:-}"
  [ -f "$PLAN" ] || return 1
  awk -v item="$ITEM" '
    BEGIN { found = 0; insection = 0; indod = 0 }
    /^### [0-9]+[a-z]?\./ {
      n = $0
      sub(/^### /, "", n); sub(/\..*$/, "", n)
      if (n == item) { insection = 1; found = 1 } else { insection = 0 }
      indod = 0
      next
    }
    /^## / { insection = 0; indod = 0; next }
    insection && /^- \*\*DoD:\*\*/ {
      line = $0
      sub(/^- \*\*DoD:\*\*[[:space:]]*/, "", line)
      printf "%s", line
      indod = 1
      next
    }
    insection && indod {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^- \*\*[^*]+:\*\*/) { indod = 0; next }
      line = $0
      sub(/^[[:space:]]+/, " ", line)
      printf "%s", line
      next
    }
    END { if (!found) exit 1 }
  ' "$PLAN"
}

# Splits a flattened DoD line into individual clauses on `;`, trimmed, one
# per output line — a presentation aid for the brief only; the verifier
# session decides its own criteria, this never dictates them.
verify_item_dod_criteria() { # $1 = dod text -> stdout
  printf '%s\n' "${1:-}" | tr ';' '\n' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v '^[[:space:]]*$'
}

# ------------------------------------------------------------ status.json
# Same grep-and-sed idiom dispatch_read_executor_status / epic_loop_state_read
# already use for this exact file shape — duplicated intentionally rather
# than sourcing either (dispatch.sh's reader wants globals this script never
# sets; epic-loop.sh's reads a DIFFERENT file, the per-ISSUE loop state, not
# the per-ITEM executor status this needs).
verify_item_read_status() { # $1=path -> sets VERIFY_ITEM_STATUS_STATE, rc1 if unreadable
  local F="${1:-}"
  VERIFY_ITEM_STATUS_STATE=""
  [ -r "$F" ] || return 1
  VERIFY_ITEM_STATUS_STATE="$(grep -o '"state"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null \
    | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  [ -n "$VERIFY_ITEM_STATUS_STATE" ] || return 1
  return 0
}

# ------------------------------------------------------------------- gh pr view
# $1=slug $2=pr -> sets VERIFY_ITEM_PR_NUMBER/_HEAD/_BASE/_URL, rc 1 on
# failure (bad PR, `gh` failure, or an empty/short reply).
verify_item_pr_info() {
  local SLUG="${1:-}" PR="${2:-}" LINE
  VERIFY_ITEM_PR_NUMBER=""; VERIFY_ITEM_PR_HEAD=""; VERIFY_ITEM_PR_BASE=""; VERIFY_ITEM_PR_URL=""
  LINE="$("$GH_BIN" pr view "$PR" --repo "$SLUG" --json number,headRefName,baseRefName,url \
            -q '"\(.number)\t\(.headRefName)\t\(.baseRefName)\t\(.url)"' 2>/dev/null)" || return 1
  [ -n "$LINE" ] || return 1
  IFS=$'\t' read -r VERIFY_ITEM_PR_NUMBER VERIFY_ITEM_PR_HEAD VERIFY_ITEM_PR_BASE VERIFY_ITEM_PR_URL <<PR_INFO_EOF
$LINE
PR_INFO_EOF
  [ -n "$VERIFY_ITEM_PR_HEAD" ] || return 1
  return 0
}

# --------------------------------------------------------- the four gates
# $1=repo $2=slug $3=plan $4=item $5=base-ref $6=head-ref $7=branch(for the
# status.json lookup) $8=pr-number -> rc 0 clean (proceed to a session), rc 1
# refused (VERIFY_ITEM_REFUSAL names why). Checked in the plan's own order —
# cheapest and most-likely-to-catch-ungated-work first.
verify_item_deterministic_gates() {
  local REPO="${1:-}" SLUG="${2:-}" PLAN="${3:-}" ITEM="${4:-}"
  local BASE_REF="${5:-}" HEAD_REF="${6:-}" BRANCH="${7:-}" PRNUM="${8:-}"
  VERIFY_ITEM_REFUSAL=""

  local EPIC_DIR STATUS_PATH
  EPIC_DIR="$(dirname "$PLAN")"
  STATUS_PATH="$EPIC_DIR/status/$(verify_item_branch_slug "$BRANCH").json"
  if ! verify_item_read_status "$STATUS_PATH" || [ "$VERIFY_ITEM_STATUS_STATE" != "pr-opened" ]; then
    VERIFY_ITEM_REFUSAL="status.json at $STATUS_PATH does not show pr-opened (found: ${VERIFY_ITEM_STATUS_STATE:-<unreadable>}) — the executor has not finished this item yet"
    return 1
  fi

  declared_paths_gate_run "$PLAN" "$ITEM" "$BASE_REF" "$HEAD_REF" "$REPO" >/dev/null 2>&1
  local DPG_RC=$?
  if [ "$DPG_RC" -ne 0 ]; then
    VERIFY_ITEM_REFUSAL="declared-paths-gate did not report clean for item $ITEM against $BASE_REF...$HEAD_REF (exit $DPG_RC — 1=mismatch, 2=lookup error)"
    return 1
  fi

  if ! "$GH_BIN" pr checks "$PRNUM" --repo "$SLUG" >/dev/null 2>&1; then
    VERIFY_ITEM_REFUSAL="gh pr checks is not green for PR #$PRNUM"
    return 1
  fi

  autonomy_resolve "$REPO" "$SLUG" >/dev/null 2>&1 || true
  if ! "$GIT_BIN" -c core.quotepath=false -C "$REPO" diff --name-only -M "${BASE_REF}...${HEAD_REF}" 2>/dev/null \
       | autonomy_deny_diff_paths >/dev/null 2>&1; then
    VERIFY_ITEM_REFUSAL="the real diff $BASE_REF...$HEAD_REF touches a path on the sensitive-path denylist"
    return 1
  fi

  return 0
}

# --------------------------------------------------------------- the brief
# $1=item $2=title $3=dod $4=issue-number-or-none $5=issue-body $6=pr-number
# $7=pr-url $8=diff-text $9=verdict-path -> stdout the full brief.
verify_item_build_brief() {
  local ITEM="${1:-}" TITLE="${2:-}" DOD="${3:-}" ISSUE="${4:-none}" ISSUE_BODY="${5:-}"
  local PR="${6:-}" PR_URL="${7:-}" DIFF="${8:-}" VERDICT_PATH="${9:-}"
  local DIFF_LINES DIFF_SHOWN
  DIFF_LINES="$(printf '%s\n' "$DIFF" | wc -l | tr -d ' ')"
  if [ "${DIFF_LINES:-0}" -gt "$VERIFY_ITEM_DIFF_LINE_CAP" ]; then
    DIFF_SHOWN="$(printf '%s\n' "$DIFF" | head -"$VERIFY_ITEM_DIFF_LINE_CAP")
... TRUNCATED at $VERIFY_ITEM_DIFF_LINE_CAP of $DIFF_LINES lines. The omitted
tail is still real diff you have not seen — judge only what is shown, and say
so in a criterion's evidence if that criterion depends on something past this
point."
  else
    DIFF_SHOWN="$DIFF"
  fi

  cat <<BRIEF_EOF
You are the COLD ACCEPTANCE VERIFIER for one work item of an approved epic —
epic 19 (epic-loop), item 5. You have NO memory of the session that built this
pull request and no context beyond what is written below: that isolation is
the entire point of a cold check. Judge only the definition of done, the
source issue's own words, and what the diff actually shows.

Your ONLY job is to judge and report. You never remediate a failing item,
never edit any file in this repository, never push, never comment on the pull
request yourself, and never merge anything — the driver that dispatched you
posts your verdict as a PR comment after you finish; you must not do that
step yourself, and your tool grant for this session does not include it.

## The work item under review

Item ${ITEM} — ${TITLE:-<no title found in the plan>}

## Definition of done, verbatim from the plan

${DOD}

Read as separate criteria, roughly (yours may differ — judge the DoD itself,
this numbering is only a reading aid):
$(verify_item_dod_criteria "$DOD" | nl -ba -w1 -s'. ')

## The source issue's reported behavior, issue #${ISSUE}

${ISSUE_BODY:-<no source issue text available for this run — judge the DoD and the diff alone, and say so honestly rather than inventing what the issue might have said>}

## The pull request diff, PR #${PR:-unknown} (${PR_URL:-no URL given})

\`\`\`diff
${DIFF_SHOWN:-<no diff text available>}
\`\`\`

## What you must produce

Write EXACTLY ONE file, at this absolute path, and nothing else:

    ${VERDICT_PATH}

One JSON key per line — no nesting on one line, matching this repository's
own convention for hand-parsed JSON — in EXACTLY this shape:

{
  "verdict": "pass",
  "criteria": [
    {
      "text": "<one DoD criterion, in your own words or verbatim>",
      "met": true,
      "evidence": "<a short, SPECIFIC pointer into the diff or the issue text
                    — a file, a line, a behavior — never a restatement of the
                    criterion itself>"
    }
  ]
}

\`verdict\` is exactly \`pass\` only if EVERY criterion's \`met\` is \`true\`.
If even one criterion is not met, \`verdict\` is \`fail\` and that criterion's
\`evidence\` NAMES SPECIFICALLY what is missing — a fail verdict that does not
name the unmet criterion is not useful to the human who reads it next. Write
one criteria object per DoD clause identified above; do not invent criteria
the DoD does not state, and do not merge two criteria into one.

A \`fail\` verdict here routes this item to \`blocked\` and it is NEVER
auto-retried — a human resolves it. Judge honestly rather than leniently: a
wrong \`pass\` costs this project more than an honest \`fail\`.
BRIEF_EOF
}

# ------------------------------------------------------------- the verdict
verify_item_verdict_value() { # $1 = verdict path -> stdout pass|fail|<empty>
  grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "${1:-}" 2>/dev/null \
    | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//'
}

# rc 0 valid: a recognised verdict value, at least one criterion, and the
# text/met/evidence counts agree (so a truncated or malformed write is never
# mistaken for a complete one). rc 1 otherwise.
verify_item_verdict_valid() { # $1 = verdict path
  local F="${1:-}" V TC MC EC
  [ -r "$F" ] || return 1
  V="$(verify_item_verdict_value "$F")"
  case "$V" in pass|fail) ;; *) return 1 ;; esac
  TC="$(grep -c '"text"[[:space:]]*:[[:space:]]*"' "$F" 2>/dev/null)"
  MC="$(grep -cE '"met"[[:space:]]*:[[:space:]]*(true|false)' "$F" 2>/dev/null)"
  EC="$(grep -c '"evidence"[[:space:]]*:[[:space:]]*"' "$F" 2>/dev/null)"
  [ "${TC:-0}" -ge 1 ] || return 1
  [ "$TC" = "$MC" ] && [ "$MC" = "$EC" ] || return 1
  return 0
}

# A markdown rendering of a validated verdict.json, for the PR comment. Never
# called on an invalid file — the caller checks verify_item_verdict_valid
# first.
verify_item_render_comment() { # $1 = verdict path -> stdout
  local F="${1:-}" V TEXTS METS EVS PASTED T ME EV I=0
  V="$(verify_item_verdict_value "$F")"
  TEXTS="$(grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  METS="$(grep -oE '"met"[[:space:]]*:[[:space:]]*(true|false)' "$F" 2>/dev/null | sed -E 's/.*:[[:space:]]*//')"
  EVS="$(grep -o '"evidence"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  case "$V" in
    pass) printf '## Cold acceptance verdict: PASS\n\n' ;;
    fail) printf '## Cold acceptance verdict: FAIL — this item moves to `blocked`, it is not auto-retried\n\n' ;;
    *)    printf '## Cold acceptance verdict: %s\n\n' "$V" ;;
  esac
  printf 'Judged by a fresh, cold `claude -p` session with no memory of the executor that built this PR (epic 19 item 5, dev-epic-workflow).\n\n'
  printf '| # | criterion | met | evidence |\n|---|---|---|---|\n'
  PASTED="$(paste -d'\t' <(printf '%s\n' "$TEXTS") <(printf '%s\n' "$METS") <(printf '%s\n' "$EVS"))"
  while IFS=$'\t' read -r T ME EV; do
    [ -n "$T" ] || continue
    I=$((I + 1))
    printf '| %s | %s | %s | %s |\n' "$I" "$T" "$ME" "$EV"
  done <<PASTED_EOF
$PASTED
PASTED_EOF
}

# ---------------------------------------------------------------------- CLI
_verify_item_usage() { sed -n '1,90p' "$0"; }

main() {
  local PLAN="" ITEM="" PR="" REPO="." SLUG="" BASE_OVERRIDE="" ISSUE=""
  local STATE_FILE="" EPIC_OV="" MODEL="$VERIFY_ITEM_MODEL_DEFAULT" AGENT="$VERIFY_ITEM_AGENT_DEFAULT"
  local TIMEOUT="$VERIFY_ITEM_TIMEOUT_DEFAULT" VERDICT_PATH=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --plan)       PLAN="${2:-}"; shift ;;
      --item)       ITEM="${2:-}"; shift ;;
      --pr)         PR="${2:-}"; shift ;;
      --repo)       REPO="${2:-}"; shift ;;
      --slug)       SLUG="${2:-}"; shift ;;
      --base)       BASE_OVERRIDE="${2:-}"; shift ;;
      --issue)      ISSUE="${2:-}"; shift ;;
      --state-file) STATE_FILE="${2:-}"; shift ;;
      --epic)       EPIC_OV="${2:-}"; shift ;;
      --model)      MODEL="${2:-}"; shift ;;
      --agent)      AGENT="${2:-}"; shift ;;
      --timeout)    TIMEOUT="${2:-}"; shift ;;
      --verdict)    VERDICT_PATH="${2:-}"; shift ;;
      -h|--help)    _verify_item_usage; return 0 ;;
      *) printf 'verify-item: unknown argument: %s\n' "$1" >&2; return 4 ;;
    esac
    shift
  done

  [ -n "$PLAN" ] && [ -r "$PLAN" ] || { printf 'verify-item: cannot read plan file: %s\n' "${PLAN:-<none given>}" >&2; return 4; }
  [ -n "$ITEM" ] || { printf 'verify-item: --item is required\n' >&2; return 4; }
  [ -n "$PR" ]   || { printf 'verify-item: --pr is required\n' >&2; return 4; }
  [ -d "$REPO" ] || { printf 'verify-item: not a directory: %s\n' "$REPO" >&2; return 4; }
  case "$TIMEOUT" in ''|*[!0-9]*) printf 'verify-item: --timeout must be a non-negative integer, got %s\n' "$TIMEOUT" >&2; return 4 ;; esac

  REPO="$(cd "$REPO" && pwd)"
  PLAN="$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")"

  case "$PR" in *[!0-9]*) PR="${PR##*/}" ;; esac
  case "$PR" in ''|*[!0-9]*) printf 'verify-item: --pr must be a PR number or a URL ending in one\n' >&2; return 4 ;; esac

  for LIB in "$AUTONOMY_LIB" "$DECLARED_PATHS_GATE_LIB"; do
    if [ ! -r "$LIB" ]; then
      printf 'verify-item: cannot read required library: %s\n' "$LIB" >&2
      return 4
    fi
    # shellcheck disable=SC1090
    . "$LIB" 2>/dev/null || { printf 'verify-item: failed to source %s\n' "$LIB" >&2; return 4; }
  done
  if [ ! -r "$PHASE_SESSION_BIN" ]; then
    printf 'verify-item: cannot read phase-session harness: %s\n' "$PHASE_SESSION_BIN" >&2
    return 4
  fi

  if [ -z "$SLUG" ] && [ -x "$GH_BIN" ]; then
    SLUG="$(cd "$REPO" 2>/dev/null && "$GH_BIN" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  fi
  [ -n "$SLUG" ] || { printf 'verify-item: --slug not given and could not be inferred via gh repo view\n' >&2; return 4; }

  if ! verify_item_pr_info "$SLUG" "$PR"; then
    printf 'verify-item: could not read PR #%s from %s via gh pr view\n' "$PR" "$SLUG" >&2
    return 4
  fi

  local BASE_BRANCH="${BASE_OVERRIDE:-$VERIFY_ITEM_PR_BASE}"
  "$GIT_BIN" -C "$REPO" fetch origin >/dev/null 2>&1 || true
  local BASE_REF="origin/$BASE_BRANCH" HEAD_REF="origin/$VERIFY_ITEM_PR_HEAD"

  if ! verify_item_deterministic_gates "$REPO" "$SLUG" "$PLAN" "$ITEM" "$BASE_REF" "$HEAD_REF" "$VERIFY_ITEM_PR_HEAD" "$VERIFY_ITEM_PR_NUMBER"; then
    printf 'verify-item: refused before any verifier session started — %s\n' "$VERIFY_ITEM_REFUSAL" >&2
    printf 'VERIFY-ITEM-RESULT: verdict=refused pr=%s reason="%s"\n' "$VERIFY_ITEM_PR_NUMBER" "$VERIFY_ITEM_REFUSAL"
    return 2
  fi

  [ -n "$VERDICT_PATH" ] || VERDICT_PATH="$REPO/docs/epics/verdict.json"
  # A stale verdict from a prior run must never be mistaken for this run's.
  rm -f "$VERDICT_PATH" 2>/dev/null || true

  local DOD TITLE ISSUE_BODY DIFF BRIEF
  DOD="$(verify_item_extract_dod "$PLAN" "$ITEM")"
  if [ -z "$DOD" ]; then
    printf 'verify-item: item %s has no "- **DoD:**" bullet in %s — nothing for the verifier to check against\n' "$ITEM" "$PLAN" >&2
    return 4
  fi
  TITLE="$(verify_item_extract_title "$PLAN" "$ITEM")"

  ISSUE_BODY=""
  if [ -n "$ISSUE" ]; then
    ISSUE_BODY="$("$GH_BIN" issue view "$ISSUE" --repo "$SLUG" --json body -q .body 2>/dev/null)"
  fi

  DIFF="$("$GH_BIN" pr diff "$VERIFY_ITEM_PR_NUMBER" --repo "$SLUG" 2>/dev/null)"

  BRIEF="$(mktemp "${TMPDIR:-/tmp}/verify-item-brief.XXXXXX" 2>/dev/null)"
  [ -n "$BRIEF" ] || { printf 'verify-item: could not create a temp file for the brief\n' >&2; return 4; }
  verify_item_build_brief "$ITEM" "$TITLE" "$DOD" "${ISSUE:-none}" "$ISSUE_BODY" \
    "$VERIFY_ITEM_PR_NUMBER" "$VERIFY_ITEM_PR_URL" "$DIFF" "$VERDICT_PATH" > "$BRIEF"

  local PS_ARGS=(--repo "$REPO" --model "$MODEL" --agent "$AGENT" --allowed-tools "$VERIFY_ITEM_ALLOWED_TOOLS" --timeout "$TIMEOUT")
  [ -n "$STATE_FILE" ] && PS_ARGS+=(--state-file "$STATE_FILE")
  [ -n "$EPIC_OV" ] && PS_ARGS+=(--epic "$EPIC_OV")

  bash "$PHASE_SESSION_BIN" "$BRIEF" "${PS_ARGS[@]}"
  local SESSION_RC=$?
  rm -f "$BRIEF" 2>/dev/null || true

  if [ "$SESSION_RC" -ne 0 ]; then
    printf 'verify-item: phase-session harness itself failed (rc %s) — could not even run the verifier session\n' "$SESSION_RC" >&2
    return 3
  fi

  if ! verify_item_verdict_valid "$VERDICT_PATH"; then
    printf 'verify-item: verifier session produced no valid verdict at %s — treating as inconclusive, never fabricated as pass or fail\n' "$VERDICT_PATH" >&2
    return 3
  fi

  local COMMENT
  COMMENT="$(verify_item_render_comment "$VERDICT_PATH")"
  if ! "$GH_BIN" pr comment "$VERIFY_ITEM_PR_NUMBER" --repo "$SLUG" --body "$COMMENT" >/dev/null 2>&1; then
    printf 'verify-item: warning: could not post the verdict comment to PR #%s (verdict.json at %s is still authoritative on disk)\n' "$VERIFY_ITEM_PR_NUMBER" "$VERDICT_PATH" >&2
  fi

  local VERDICT
  VERDICT="$(verify_item_verdict_value "$VERDICT_PATH")"
  printf 'VERIFY-ITEM-RESULT: verdict=%s pr=%s verdict-file=%s\n' "$VERDICT" "$VERIFY_ITEM_PR_NUMBER" "$VERDICT_PATH"
  case "$VERDICT" in
    pass) return 0 ;;
    fail) return 1 ;;
    *)    return 3 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
  exit $?
fi
