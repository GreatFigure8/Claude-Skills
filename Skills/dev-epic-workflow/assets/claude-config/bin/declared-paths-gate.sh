#!/usr/bin/env bash
# THE PR GATE COMPARES DECLARATION AGAINST DIFF — dev-epic-workflow, epic 10 item 3.
#
# WHAT THIS REPLACES. `references/pr-template.md:62` asked a human to eyeball
# `git diff --stat <base>...HEAD` against the plan item's prose `**Scope:**` and
# answer "touched paths match scope: yes/no + note" by hand. Epic 10 item 1 gave
# a work item a machine-readable `**Touches:**` block; this script is the first
# thing that reads it, and it makes that question mechanical.
#
# WHAT IT CHECKS, AND IN BOTH DIRECTIONS. Given a plan, a work item number and a
# base ref, it extracts the item's declared `**Touches:**` block and compares it
# against `git diff --name-only <base>...<head>`:
#   declared-but-untouched   the item declared a path it never actually changed
#                             (it did LESS than it said)
#   touched-but-undeclared   the diff touches a path the item never declared
#                             (it did MORE than it said)
# Both directions are reported, because either one alone hides the other class
# of drift — see the plan's Grounding section for the measured false positives
# and false negatives a prose-only extractor already produced on real proposals.
#
# V1 WARNS. IT DOES NOT BLOCK. Exit code communicates the finding, never a
# reason to refuse the PR: 0 = declared paths match the diff exactly, or the
# item declares nothing (absence is "not declared", never a failure); 1 = a
# mismatch was found in one or both directions — a WARN for a human to read, not
# a build failure; 2 = usage or lookup error (bad arguments, plan or item not
# found, git diff failed) — this is the only case that means "the check itself
# could not run."
#
# NO RETROFIT, BY THE SAME INVARIANT ITEM 1 STATED. A work item with no
# `**Touches:**` block — every one of the 27 items across the 9 filed plans that
# predate this epic — reports "not declared" and exits 0. This script never
# fails a plan closed just because it predates the field.
#
# Usage:
#   declared-paths-gate.sh --plan <path/to/plan.md> --item <N> --base <ref>
#                           [--head <ref>] [--repo <path>]
#
#   --plan   path to the epic's plan.md (required)
#   --item   the work item number, matching its `### N. <title>` heading (required)
#   --base   the ref the diff is measured from, e.g. `origin/main` (required)
#   --head   the ref the diff is measured to (default: HEAD)
#   --repo   the git repo to run `git diff` in (default: cwd)
#
# Sourced use: `. declared-paths-gate.sh` exposes `declared_paths_gate_run` and
# `declared_paths_gate_extract_touches` without executing the CLI, for a fixture
# harness or a future caller that wants the parsed sets rather than the report.

set -u

# --------------------------------------------------------------- extraction
# Reads plan.md and prints the declared paths for one work item, one per line,
# in file order. Prints nothing (rc 0) when the item has no `**Touches:**`
# block — that is "not declared," not an error. Returns rc 1 only when the
# item's own `### N. ` heading cannot be found in the plan at all, which is a
# caller error (wrong item number, wrong plan) rather than an absent field.
declared_paths_gate_extract_touches() { # $1 = plan file, $2 = item number
  local PLAN="$1" ITEM="$2"
  [ -f "$PLAN" ] || return 1
  awk -v item="$ITEM" '
    BEGIN { found = 0; insection = 0; intouches = 0 }
    /^### [0-9]+[a-z]?\./ {
      n = $0
      sub(/^### /, "", n)
      sub(/\..*$/, "", n)
      if (n == item) { insection = 1; found = 1 } else { insection = 0 }
      intouches = 0
      next
    }
    /^## / { insection = 0; intouches = 0; next }
    insection && /^- \*\*Touches:\*\*[[:space:]]*$/ { intouches = 1; next }
    insection && intouches {
      if ($0 ~ /^[[:space:]]+-[[:space:]]+`[^`]+`[[:space:]]*$/) {
        line = $0
        sub(/^[[:space:]]+-[[:space:]]+`/, "", line)
        sub(/`.*$/, "", line)
        print line
        next
      }
      # A blank line or the start of the next `- **Field:**` bullet legitimately
      # ends the Touches block — stay silent, same as before.
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^- \*\*[^*]+:\*\*/) {
        intouches = 0
        next
      }
      # Anything else inside the Touches block that is not a `path` bullet is a
      # malformed line (e.g. a trailing annotation after the closing backtick).
      # Warn and keep scanning rather than silently dropping the rest of the
      # block — a silent stop here means paths after this line vanish from the
      # declared set with no error surfaced.
      print "declared-paths-gate: warning: item " item " has an unparsed line in its Touches block (not a `path` bullet, blank line, or new field) — declared paths may be incomplete: " $0 > "/dev/stderr"
      next
    }
    END { if (!found) exit 1 }
  ' "$PLAN"
}

# ------------------------------------------------------------- set compare
# POSIX-shell set difference, no associative arrays (this runs under macOS
# /bin/bash 3.2 elsewhere in this repo's toolset, so the whole family avoids
# them on principle even where not yet required). $1 minus $2, both newline-
# separated, one entry per output line.
_declared_paths_gate_diff_set() { # $1 = set A (newline list), $2 = set B (newline list)
  local A="$1" B="$2" LINE FENCED_B
  FENCED_B="
$B
"
  while IFS= read -r LINE; do
    [ -n "$LINE" ] || continue
    case "$FENCED_B" in
      *"
$LINE
"*) : ;;
      *) printf '%s\n' "$LINE" ;;
    esac
  done <<SET_EOF
$A
SET_EOF
  return 0
}

# ------------------------------------------------------------------ report
# Runs the comparison and prints the report. rc 0 = clean or not-declared,
# rc 1 = a mismatch was found (WARN, not a failure — see header), rc 2 = the
# lookup itself failed.
declared_paths_gate_run() { # $1=plan $2=item $3=base $4=head $5=repo
  local PLAN="$1" ITEM="$2" BASE="$3" HEAD="${4:-HEAD}" REPO="${5:-.}"
  local DECLARED DIFF UNDER OVER RC=0

  if [ ! -f "$PLAN" ]; then
    printf 'declared-paths-gate: no such plan file: %s\n' "$PLAN" >&2
    return 2
  fi
  if [ -z "$ITEM" ] || [ -z "$BASE" ]; then
    printf 'declared-paths-gate: --item and --base are required\n' >&2
    return 2
  fi

  DECLARED="$(declared_paths_gate_extract_touches "$PLAN" "$ITEM")"
  if [ $? -ne 0 ]; then
    printf 'declared-paths-gate: item %s has no "### %s. " heading in %s\n' "$ITEM" "$ITEM" "$PLAN" >&2
    return 2
  fi

  if [ -z "$DECLARED" ]; then
    printf 'declared-paths-gate: item %s declares no Touches block — not declared\n' "$ITEM"
    return 0
  fi

  DIFF="$(git -C "$REPO" diff --name-only "${BASE}...${HEAD}" 2>&1)"
  if [ $? -ne 0 ]; then
    printf 'declared-paths-gate: git diff --name-only %s...%s failed in %s:\n%s\n' \
      "$BASE" "$HEAD" "$REPO" "$DIFF" >&2
    return 2
  fi

  UNDER="$(_declared_paths_gate_diff_set "$DECLARED" "$DIFF")"
  OVER="$(_declared_paths_gate_diff_set "$DIFF" "$DECLARED")"

  printf 'declared-paths-gate: item %s — declared vs %s...%s\n' "$ITEM" "$BASE" "$HEAD"
  if [ -z "$UNDER" ] && [ -z "$OVER" ]; then
    printf '  match: every declared path was touched, and nothing touched was undeclared\n'
    return 0
  fi

  RC=1
  if [ -n "$UNDER" ]; then
    printf '  declared-but-untouched (declared, never touched — did LESS than declared):\n'
    printf '%s\n' "$UNDER" | sed 's/^/    - /'
  fi
  if [ -n "$OVER" ]; then
    printf '  touched-but-undeclared (touched, never declared — did MORE than declared):\n'
    printf '%s\n' "$OVER" | sed 's/^/    - /'
  fi
  printf '  WARN only — v1 does not block the PR on this mismatch (epic 10 item 3)\n'
  return "$RC"
}

# ---------------------------------------------------------------------- CLI
_declared_paths_gate_usage() { sed -n '1,35p' "$0" | sed 's/^# \{0,1\}//'; }

_declared_paths_gate_cli() {
  local PLAN="" ITEM="" BASE="" HEAD="HEAD" REPO="."
  while [ $# -gt 0 ]; do
    case "$1" in
      --plan) PLAN="${2-}"; shift ;;
      --item) ITEM="${2-}"; shift ;;
      --base) BASE="${2-}"; shift ;;
      --head) HEAD="${2-}"; shift ;;
      --repo) REPO="${2-}"; shift ;;
      -h|--help) _declared_paths_gate_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
    shift
  done
  declared_paths_gate_run "$PLAN" "$ITEM" "$BASE" "$HEAD" "$REPO"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _declared_paths_gate_cli "$@"
  exit $?
fi
