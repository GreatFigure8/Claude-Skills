#!/usr/bin/env bash
# L2 dispatch — dev-epic-workflow, epic 11 item 3.
#
# THIS IS THE ONLY FILE IN THIS WORKFLOW THAT CHANGES WHAT THE MACHINE MAY DO
# WITHOUT A HUMAN. Items 1, 2 and 2b built a switchboard, a control plane and a
# capability check and deliberately wired none of them to anything. This wires
# them, and its ceiling is one sentence:
#
#   L2's ceiling is an OPEN PULL REQUEST.
#
# The runner never approves a plan, never merges a pull request, never closes an
# issue, and never chains to a new one. Any commit that weakens that is a defect,
# not a feature. The refusals here are structural rather than disciplinary: the
# executor is invoked without `gh pr create`, `gh pr merge` or `gh issue close`
# in its allowlist, so the ceiling holds even if every sentence in the brief is
# ignored.
#
# WHAT ONE CYCLE DOES, per configured repo, in order:
#
#   1. refuse unless the repo resolves to L2 (bin/autonomy.sh, item 1)
#   2. refuse unless the per-cycle budget allows another item (item 1)
#   3. ask GitHub for the branches and pull requests of this repo — ONCE
#   4. find the next UNDISPATCHED work item of an epic at `approved` or
#      `in flight`, from the `- **Branch:**` line and NEVER from prose
#   5. admit it against the repo's label policy (item 1)
#   6. cut its worktree from the integration branch and run the provisioning
#      preflight — including the smoke check (bin/worktree-provision.sh, item 2b).
#      A failed smoke check REFUSES THE DISPATCH; it never proceeds hopefully
#   7. push the branch, so the item is marked dispatched before an executor
#      exists that could die without saying so
#   8. invoke `claude -p --agent work-item-executor` with the item's brief and
#      the per-item-type gate set, and WAIT
#   9. push whatever it produced, then enforce the denylist and the size ceiling
#      against `git diff --name-only` — THE REAL DIFF, never the plan's prose
#  10. open the pull request against the INTEGRATION branch
#  11. STOP.
#
# WHY THE DENYLIST IS CHECKED AFTER THE EXECUTOR AND NOT BEFORE. A work item's
# plan says what it intends to touch in prose, and prose is not machine-readable
# — that is what epic 10 exists for. A declaration-based check would be checking
# the wrong thing, so the check runs against the diff that actually exists, after
# the executor returns and BEFORE the pull request is opened. A denied path
# leaves the branch on origin for a human and opens nothing.
#
# WHY THE RUNNER OPENS THE PULL REQUEST AND THE EXECUTOR DOES NOT. Same reason:
# the denylist has to sit between "the work exists" and "the work is proposed",
# and the only place that fits is here. The brief says so, and the allowlist
# enforces it.
#
# NOTHING HERE RUNS AT L0. Every unconfigured repo on this machine resolves L0,
# so this file is loaded and never entered, and an unconfigured run's log is
# byte-identical to what it was before this item — proven by fixture, twice.
#
# Usage (read-only unless --dispatch is named):
#   bin/dispatch.sh --plan <plan.md>                    the work items it parses
#   bin/dispatch.sh --select --repo <path> --slug <o/n> --epics-dir <dir>
#   bin/dispatch.sh --check  --repo <path> --slug <o/n>
#   bin/dispatch.sh --deny   --repo <path> --slug <o/n> --worktree <wt> --base <b>

# --------------------------------------------------------------- this build
# The machine-readable contract marker, the sibling of AUTONOMY_ENFORCED and
# PROVISION_DISPATCH_WIRED. `yes` says the switchboard is connected. A fixture
# asserts it, and flipping it to `no` must break a case that passes today.
DISPATCH_ENFORCED=yes
DISPATCH_CONTRACT=1

# The one rung this file implements. Anything else is refused by autonomy.sh
# before it gets here; this constant exists so the refusal can name the rung
# rather than a level number that means nothing to a reader.
DISPATCH_LEVEL=L2

# ------------------------------------------------------------------- binaries
# Resolved the same way every other library here resolves them: launchd gives a
# minimal PATH, and the runner has already proven these three are executable.
DISPATCH_GIT="${INTAKE_GIT:-/usr/bin/git}"
DISPATCH_GH="${INTAKE_GH:-/opt/homebrew/bin/gh}"
DISPATCH_CLAUDE="${INTAKE_CLAUDE:-$HOME/.local/bin/claude}"

# How long an executor may run before it is killed. A dispatch that has hung is
# not a dispatch that is nearly finished, and a launchd job with no ceiling is a
# job that eventually needs a human with `kill`. Overridable, defaulted low
# enough to be survivable and high enough for a real item.
DISPATCH_EXECUTOR_TIMEOUT="${INTAKE_DISPATCH_TIMEOUT:-3600}"

# ------------------------------------------------------------------- state
DISPATCH_LOG_LAST=""
DISPATCH_REFUSAL=""
DISPATCH_STATE=""
DISPATCH_EPIC=""            # epic folder name, e.g. 11-l2-autonomous-dispatch
DISPATCH_PLAN=""            # absolute path to its plan.md
DISPATCH_PLAN_REL=""        # repo-relative, for the brief and the PR body
DISPATCH_EPIC_STATE=""      # approved | in-flight
DISPATCH_ITEM=""            # the item id as written: 1, 2, 2b
DISPATCH_TITLE=""
DISPATCH_BRANCH=""
DISPATCH_GATE_TYPE=""
DISPATCH_DEPENDS=""
DISPATCH_SOURCE_KIND=""     # gh | ab | none
DISPATCH_SOURCE_NUM=""
DISPATCH_WORKTREE=""
DISPATCH_PR_URL=""
DISPATCH_RUN_LOG=""
DISPATCH_DIFF_FILES=0
DISPATCH_DIFF_LINES=0
DISPATCH_DENIED=""
DISPATCH_EXECUTOR_STATE=""
DISPATCH_EXECUTOR_DETAIL=""
DISPATCH_ORIGIN_BRANCHES=""
DISPATCH_PR_HEADS=""        # "<state> <head>" per line, OPEN and MERGED only
DISPATCH_SIGNALS_OK=no

# The gate set actually handed to the executor, kept so the pull request can say
# which commands were named rather than which ones someone believes were run.
DISPATCH_GATE_BRIEF=""
DISPATCH_GATE_COMMANDS=""

# ---------------------------------------------------------------- emission
# LIVE, not accumulated. A dispatch can take forty minutes, and the two epic 11
# executors that died silently cost 105 minutes precisely because nothing
# distinguished "working quietly" from "dead". The runner replaces this with its
# own log() the moment it sources the file, so every line lands in intake.log,
# on stdout, and in the cycle's agent log as it happens.
dispatch_emit() { # $1... = text
  DISPATCH_LOG_LAST="$*"
  printf '%s\n' "$*"
}

# Telemetry entry points. Defined here ONLY when the runner has not already
# defined them — which is the standalone and fixture case. Nothing in this file
# branches on the result of any of them: a decision that reads telemetry is a
# decision that changes when you watch it.
command -v intake_status_cycle  >/dev/null 2>&1 || intake_status_cycle()  { :; }
command -v intake_status_log    >/dev/null 2>&1 || intake_status_log()    { :; }
command -v intake_status_ledger >/dev/null 2>&1 || intake_status_ledger() { :; }
command -v intake_status_write  >/dev/null 2>&1 || intake_status_write()  { return 1; }
command -v intake_status_escape >/dev/null 2>&1 || intake_status_escape() { printf '%s' "${1:-}"; }

dispatch_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z'; }

# --------------------------------------------------------------- utilities
_dispatch_strip() { # $1 -> stdout, trimmed
  DS_V="${1-}"
  DS_V="${DS_V#"${DS_V%%[![:space:]]*}"}"
  DS_V="${DS_V%"${DS_V##*[![:space:]]}"}"
  printf '%s' "$DS_V"
}

# A branch name as the control plane names a status file — `/` becomes `-`, the
# same derivation an orchestrated executor's own `<branch-slug>.json` uses.
dispatch_branch_slug() { # $1 = branch -> stdout
  printf '%s' "${1:-}" | tr '/' '-' 2>/dev/null
}

# A branch name that git will accept and that no shell will reinterpret. This is
# a boundary: the value comes out of a markdown file that anybody may edit, and
# it is about to become an argument to `git push`.
dispatch_branch_ok() { # $1 = branch
  case "${1:-}" in
    ''|-*|*' '*|*'..'*|*'~'*|*'^'*|*':'*|*'?'*|*'*'*|*'['*|*'\'*|*'$'*|*'`'*|*'"'*|*"'"*|*'|'*|*'&'*|*';'*|*'('*|*')'*|*'<'*|*'>'*)
      return 1 ;;
    */) return 1 ;;
    *//*) return 1 ;;
  esac
  case "${1}" in *[![:alnum:]/._-]*) return 1 ;; esac
  return 0
}

# ------------------------------------------------------------- the plan state
# The Status vocabulary of references/plan-template.md, read from the line's
# first TWO words, case-insensitively, and tolerating anything after the phrase.
# Byte-for-byte the rule the control-plane hooks use, and for the same reason:
# keying on the first word alone truncates `in flight` to `in`, which is exactly
# how `approved` and `in flight` were once indistinguishable (GH #11).
#
# THE ONLY TWO DISPATCHABLE STATES ARE `approved` AND `in flight`. `planning` is
# a proposal and is never dispatchable — that is what makes L1 a separate rung
# this epic does not build. `closed` is finished. Anything unparseable is
# `unknown` and is NOT dispatchable: an epic whose state cannot be read is an
# epic whose author's intent is unknown, and the safe reading of an unknown
# intent about permissions is "none".
dispatch_plan_state() { # $1 = plan file -> approved|in-flight|planning|closed|unknown
  local RAW W1 W2
  RAW="$(grep -m1 -iE '^[[:space:]*_]*status:' "${1:-}" 2>/dev/null \
         | sed -E -e 's/^[[:space:]*_]*[Ss][Tt][Aa][Tt][Uu][Ss]:[[:space:]*_]*//' \
         | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
  read -r W1 W2 <<PLAN_STATE_EOF
$RAW
PLAN_STATE_EOF
  case "${W1:-}" in
    approved) printf 'approved' ;;
    planning) printf 'planning' ;;
    closed)   printf 'closed' ;;
    in)       if [ "${W2:-}" = flight ]; then printf 'in-flight'; else printf 'unknown'; fi ;;
    *)        printf 'unknown' ;;
  esac
}

# The `**Source:**` header, which is what a work-item pull request links back to.
# `GH #<n>` and `AB#<n>` are the two forms references/issue-intake.md defines;
# anything else is `none`, and a `none` source means the pull request carries no
# linkage line at all rather than a guessed one.
dispatch_plan_source() { # $1 = plan file; sets DISPATCH_SOURCE_KIND / _NUM
  local RAW
  DISPATCH_SOURCE_KIND=none
  DISPATCH_SOURCE_NUM=""
  RAW="$(grep -m1 -iE '^[[:space:]*_]*source:' "${1:-}" 2>/dev/null \
         | sed -E -e 's/^[[:space:]*_]*[Ss][Oo][Uu][Rr][Cc][Ee]:[[:space:]*_]*//' | tr -d '\r')"
  [ -n "$RAW" ] || return 0
  case "$RAW" in
    [Gg][Hh]*'#'*)
      DISPATCH_SOURCE_NUM="$(printf '%s' "$RAW" | sed -E -e 's/^[Gg][Hh][[:space:]]*#[[:space:]]*//' -e 's/[^0-9].*$//')"
      [ -n "$DISPATCH_SOURCE_NUM" ] && DISPATCH_SOURCE_KIND=gh ;;
    [Aa][Bb]*'#'*)
      DISPATCH_SOURCE_NUM="$(printf '%s' "$RAW" | sed -E -e 's/^[Aa][Bb][[:space:]]*#[[:space:]]*//' -e 's/[^0-9].*$//')"
      [ -n "$DISPATCH_SOURCE_NUM" ] && DISPATCH_SOURCE_KIND=ab ;;
  esac
  case "$DISPATCH_SOURCE_NUM" in ''|*[!0-9]*) DISPATCH_SOURCE_KIND=none; DISPATCH_SOURCE_NUM="" ;; esac
  return 0
}

# --------------------------------------------------------- the work items
# A plan.md on stdin -> one TAB-separated line per work item, IN PLAN ORDER:
#
#   <id>\t<branch>\t<gate type>\t<depends on>\t<title>
#
# An EMPTY branch field is the "missing `Branch:` line" case and the caller
# REFUSES it. It is deliberately emitted rather than dropped, because an item
# that vanishes from the list is an item the runner would silently step over on
# its way to a later one — which is how you dispatch item 3 while item 2 is
# unaccounted for.
#
# ONLY THE `## Work items` SECTION IS READ, and it ends at the next `## `
# heading. That is not tidiness: measured on a real repo, plans carry
# `### Deferred`, `### RED proof printed the defect verbatim` and
# `### What was submitted, and what it did to DEV-1` as `###` headings in later
# sections, and a parser that reads every `###` in the file would treat them as
# work items.
#
# THE ITEM'S PROSE IS NEVER READ FOR COMPLETION. A real plan marks a finished
# item as `### 1. The UI knows the template's family — DONE (PR #842)`, and this
# parser keeps the title verbatim without ever interpreting it. Dispatchability
# comes from the branch and the pull request, and from nothing else.
dispatch_work_items() {
  awk '
    function flush() {
      if (id != "") printf "%s\t%s\t%s\t%s\t%s\n", id, branch, gates, depends, title
      id = ""; branch = ""; gates = ""; depends = ""; title = ""
    }
    function unwrap(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/^`+|`+$/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    # A `## ` heading closes the current item and decides whether the NEXT
    # section is the work items. Normalised to letters only, so `## Work items`,
    # `## Work Items` and `## Work item` are one heading and a stray colon or
    # emphasis marker does not change the answer.
    /^##[[:space:]]/ && !/^###/ {
      flush()
      h = tolower($0); gsub(/[^a-z]/, "", h)
      in_items = (h ~ /^workitems?$/) ? 1 : 0
      next
    }
    /^#[[:space:]]/ { flush(); in_items = 0; next }
    !in_items { next }
    # Any `### ` heading closes the previous item. Only one that opens with an
    # item id — digits then optional letters, as in `1.` and `2b.` — opens a new
    # one; `### Deferred` inside a Work items section is not a work item and
    # must not inherit the previous items Branch line.
    /^###[[:space:]]/ && !/^####/ {
      flush()
      line = $0
      sub(/^###[[:space:]]+/, "", line)
      if (match(line, /^[0-9]+[A-Za-z]*\./)) {
        id = substr(line, 1, RLENGTH - 1)
        title = substr(line, RLENGTH + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", title)
      }
      next
    }
    id == "" { next }
    # The machine-readable fields. Matched at the start of a bullet so a mention
    # of the word `Branch:` inside a Scope paragraph cannot supply one.
    match($0, /^[[:space:]]*[-*][[:space:]]+\*\*[Bb]ranch:\*\*/) {
      if (branch == "") branch = unwrap(substr($0, RSTART + RLENGTH)); next
    }
    match($0, /^[[:space:]]*[-*][[:space:]]+\*\*[Gg]ates:\*\*/) {
      if (gates == "") gates = unwrap(substr($0, RSTART + RLENGTH)); next
    }
    match($0, /^[[:space:]]*[-*][[:space:]]+\*\*[Dd]epends[[:space:]]+on:\*\*/) {
      if (depends == "") depends = unwrap(substr($0, RSTART + RLENGTH)); next
    }
    END { flush() }
  ' 2>/dev/null
}

# `- **Depends on:** 1, 2 and 2b` -> `1 2 2b`. `none`, and anything that is not
# an item id, contributes nothing. Prose around the ids is discarded rather than
# interpreted: the ids are the only part of that line this file understands, and
# it says so instead of guessing at the rest.
dispatch_depends_ids() { # $1 = the raw Depends on value -> ids on stdout
  printf '%s' "${1-}" \
    | tr 'A-Z' 'a-z' \
    | sed -e 's/[^a-z0-9]/ /g' \
    | tr ' ' '\n' \
    | while IFS= read -r TOK; do
        [ -n "$TOK" ] || continue
        case "$TOK" in
          none|item|items|and|on|depends) continue ;;
        esac
        case "$TOK" in
          [0-9]) printf '%s\n' "$TOK" ;;
          [0-9][a-z]|[0-9][0-9]|[0-9][0-9][a-z]|[0-9][0-9][0-9]) printf '%s\n' "$TOK" ;;
        esac
      done
}

# ------------------------------------------------------- dispatchability
# THE WHOLE RULE, and it is not "parse the plan for a DONE marker":
#
#   an item is DISPATCHABLE iff no branch of its name exists on `origin`
#   AND no open-or-merged pull request has it as head.
#
# Both halves are needed. The branch alone misses an item whose branch was
# deleted after its pull request merged; the pull request alone misses an item
# whose executor pushed and then died. Together they are the same two signals
# epic 09 items 7 and 8 already built and measured, asked of GitHub rather than
# of a local checkout whose remote refs are only as fresh as its last fetch.
#
# A CLOSED-UNMERGED pull request is deliberately NOT a signal: abandoned work is
# not delivered work. Its branch usually still exists, which is what stops the
# item being re-dispatched — and if a human deleted both, then the item really is
# undispatched again and dispatching it is right.
dispatch_load_signals() { # $1 = repo slug
  DISPATCH_ORIGIN_BRANCHES=""
  DISPATCH_PR_HEADS=""
  DISPATCH_SIGNALS_OK=no
  DISPATCH_REFUSAL=""
  DISPATCH_ORIGIN_BRANCHES="$("$DISPATCH_GH" api --paginate \
        "repos/${1:-}/branches?per_page=100" \
        -H "Accept: application/vnd.github+json" -q '.[].name' 2>/dev/null)" || {
    DISPATCH_REFUSAL="the branch listing for ${1:-} failed, so whether an item is already dispatched cannot be decided — refusing rather than guessing"
    return 1
  }
  # An empty branch list is not a plausible answer for a repository that has a
  # default branch, so it is read as a failed query rather than as "no branches".
  if [ -z "$DISPATCH_ORIGIN_BRANCHES" ]; then
    DISPATCH_REFUSAL="the branch listing for ${1:-} came back empty, which no real repository is — treating it as a failed query and refusing rather than guessing"
    return 1
  fi
  DISPATCH_PR_HEADS="$("$DISPATCH_GH" pr list --repo "${1:-}" --state all --limit 200 \
        --json state,headRefName -q '.[] | select(.state == "OPEN" or .state == "MERGED") | "\(.state) \(.headRefName)"' 2>/dev/null)" || {
    DISPATCH_REFUSAL="the pull request listing for ${1:-} failed, so whether an item is already dispatched cannot be decided — refusing rather than guessing"
    return 1
  }
  DISPATCH_SIGNALS_OK=yes
  return 0
}

dispatch_branch_on_origin() { # $1 = branch
  printf '%s\n' "$DISPATCH_ORIGIN_BRANCHES" | grep -Fxq -- "${1:-}"
}

dispatch_pr_state_for() { # $1 = branch -> MERGED | OPEN | "" (best state wins)
  local BEST="" ST HD
  while IFS=' ' read -r ST HD; do
    [ -n "${HD:-}" ] || continue
    [ "$HD" = "${1:-}" ] || continue
    [ "$ST" = MERGED ] && { printf 'MERGED'; return 0; }
    BEST=OPEN
  done <<PR_HEADS_EOF
$DISPATCH_PR_HEADS
PR_HEADS_EOF
  printf '%s' "$BEST"
}

dispatch_is_dispatched() { # $1 = branch -> 0 if already dispatched
  dispatch_branch_on_origin "${1:-}" && return 0
  [ -n "$(dispatch_pr_state_for "${1:-}")" ] && return 0
  return 1
}
