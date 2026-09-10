#!/usr/bin/env bash
# dispatch — dev-epic-workflow, originally epic 11 item 3 ("L2 dispatch").
#
# RETIRED AS A DAEMON (epic 21 item 1). `dispatch_repo` used to cut a
# worktree, push it, invoke `claude -p --agent work-item-executor` headlessly
# and open the resulting pull request whenever a repo's autonomy-ladder level
# resolved to the exact rung `L2` — see epics 11 and 19, both closed with a
# retro pointing here. Epic 21's Outcome is a session-scoped loop that only
# ever runs inside a live, already-authenticated interactive session: no
# daemon, no subprocess chain, no autonomy ladder. `dispatch_repo` now always
# refuses; nothing in this file spawns a subprocess or opens a pull request.
#
# WHAT SURVIVES, AND WHY. Several functions here are read-only inspection
# utilities with no dependency on the retired ladder, and other live files
# still call them directly, so they stay:
#   dispatch_brief / dispatch_allowed_tools    — phase-session.sh's drafting
#                                                 utility, verify-item.sh
#   dispatch_read_executor_status              — epic-loop.sh, verify-item.sh
#   dispatch_check_diff / dispatch_gate_brief  — denylist+size-ceiling and
#                                                 gate-set preview, reusable
#                                                 by Item 2's harm floor
#   dispatch_work_items / dispatch_select /
#   dispatch_plan_state / dispatch_plan_source — plan parsing, used by this
#                                                 file's own read-only CLI
#
# WHY THE DENYLIST WAS CHECKED AFTER THE EXECUTOR AND NOT BEFORE, HISTORICALLY.
# A work item's plan says what it intends to touch in prose, and prose is not
# machine-readable — that is what epic 10 exists for. A declaration-based
# check would be checking the wrong thing, so `dispatch_check_diff` still
# checks the diff that actually exists, which is why it survives this item.
#
# Usage (every mode below is read-only; nothing here ever dispatches):
#   bin/dispatch.sh --plan <plan.md>                    the work items it parses
#   bin/dispatch.sh --select --repo <path> --slug <o/n> --epics-dir <dir> [--closing-keyword]
#   bin/dispatch.sh --check  --repo <path> --slug <o/n>
#   bin/dispatch.sh --deny   --repo <path> --slug <o/n> --worktree <wt> --base <b>
#
#   --closing-keyword (--select only) previews the PR linkage a caller could
#   write — `Closes #<n>` instead of `Part of #<n>`. Preview only.

# --------------------------------------------------------------- this build
DISPATCH_CONTRACT=1

# The field separator dispatch_work_items emits and every reader splits on. See
# the comment on that function for why it is not a tab.
DISPATCH_FS="$(printf '\037')"

# ------------------------------------------------------------------- binaries
# Resolved the same way every other library here resolves them: launchd gives a
# minimal PATH, and the runner has already proven these three are executable.
DISPATCH_GIT="${INTAKE_GIT:-/usr/bin/git}"
DISPATCH_GH="${INTAKE_GH:-/opt/homebrew/bin/gh}"

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
  local RAW W1 W2 WREST
  RAW="$(grep -m1 -iE '^[[:space:]*_]*status:' "${1:-}" 2>/dev/null \
         | sed -E -e 's/^[[:space:]*_]*[Ss][Tt][Aa][Tt][Uu][Ss]:[[:space:]*_]*//' \
         | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
  # THREE variables, not two. `read -r W1 W2` puts the whole REST of the line in
  # W2, so `in flight (item 3 of 4)` would compare W2 against `flight (item 3 of
  # 4)` and never match. The third variable is what makes "the first two words"
  # actually mean the first two words.
  read -r W1 W2 WREST <<PLAN_STATE_EOF
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
# A plan.md on stdin -> one line per work item, IN PLAN ORDER, fields separated by
# ASCII UNIT SEPARATOR (\037):
#
#   <id>\037<branch>\037<gate type>\037<depends on>\037<title>
#
# NOT a tab, and that is a bug this file already had. A tab is IFS *whitespace*,
# so `IFS=<tab> read -r ID BR GT DEP TITLE` collapses runs of tabs into one
# delimiter and strips leading and trailing ones — which means the moment a
# middle field is empty (no `Gates:` line, which is the common case) every field
# after it shifts left and the title lands in `depends`. Measured against two
# real plans before it was written down. \037 is not IFS whitespace, so an empty
# field stays an empty field, and it cannot occur in a markdown source file.
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
      if (id != "") printf "%s\037%s\037%s\037%s\037%s\n", id, branch, gates, depends, title
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

# `- **Depends on:** 1, 2 and 2b` -> `1 2 2b`. Two rules, both measured against
# real plans rather than imagined:
#
#   1. IF THE FIRST WORD IS `none`, THERE ARE NO DEPENDENCIES, whatever follows.
#      A live plan writes `- **Depends on:** none (independent of 1 and 2)`, and
#      a tokeniser that scraped every number out of that line would make an
#      explicitly independent item wait for two others forever.
#   2. OTHERWISE, READ IDS UNTIL THE PROSE STARTS. Another live plan writes
#      `- **Depends on:** 1 — the sample must show the *corrected* output`, so
#      the list ends at the first token that is neither an item id nor a
#      connector. Everything after that is a human explaining themselves, and
#      this file does not pretend to understand it.
#
# A mis-parse here can only ever cause a REFUSAL — an item waiting for something
# it does not really need — never a dispatch that should not have happened. That
# is the direction this whole file errs in.
dispatch_depends_ids() { # $1 = the raw Depends on value -> ids on stdout
  local FIRST=yes
  printf '%s' "${1-}" \
    | tr 'A-Z' 'a-z' \
    | sed -e 's/[^a-z0-9]/ /g' \
    | tr ' ' '\n' \
    | while IFS= read -r TOK || [ -n "$TOK" ]; do
        [ -n "$TOK" ] || continue
        if [ "$FIRST" = yes ]; then
          FIRST=no
          [ "$TOK" = none ] && break
        fi
        case "$TOK" in
          item|items|and|on|depends) continue ;;
        esac
        case "$TOK" in
          [0-9]|[0-9][a-z]|[0-9][0-9]|[0-9][0-9][a-z]|[0-9][0-9][0-9]|[0-9][0-9][0-9][a-z])
            printf '%s\n' "$TOK" ;;
          *) break ;;
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

# ------------------------------------------------------------- epic ordering
# Epic folders are `<NN>-<slug>` and the number is the implementation sequence
# (references/plan-template.md), so the order is NUMERIC and not lexical. That
# matters on a real repo rather than in principle: one of the two configured
# repos has epics numbered past 190, where a lexical sort puts `100` before `99`
# and the runner would work the queue in the wrong order for the rest of the
# project's life. Anything without a leading number sorts last, by name.
_dispatch_epic_order() { # folder names on stdin -> ordered on stdout
  awk '{ n = $0; sub(/-.*$/, "", n)
         if (n ~ /^[0-9]+$/) printf "%012d\t%s\n", n, $0
         else                printf "%012d\t%s\n", 999999999999, $0 }' 2>/dev/null \
    | LC_ALL=C sort | cut -f2-
}

# ------------------------------------------------------------ the selection
# Sets DISPATCH_EPIC / _PLAN / _PLAN_REL / _EPIC_STATE / _ITEM / _TITLE /
# _BRANCH / _GATE_TYPE / _DEPENDS / _SOURCE_* and returns 0 when there is an item
# to dispatch. Returns 1 with DISPATCH_REFUSAL empty when there is simply nothing
# to do, and 1 with DISPATCH_REFUSAL set when something was refused.
#
# IN FLIGHT BEFORE APPROVED, then numeric order within each. Finishing an epic
# that is already started before starting another is the most conservative
# reading of "serialized, one item at a time", and it is the reading that keeps
# a half-delivered epic from sitting behind a queue of freshly approved ones.
#
# The reserved intake tree cannot be reached from here: it is `.intake`, and the
# `*/plan.md` glob below does not match a leading dot — the same guarantee, by
# the same mechanism, that keeps it from ever being selected as the active epic.
dispatch_select() { # $1 = repo checkout, $2 = epics dir (repo-relative)
  local ROOT="${1:-}" EDIR="${2:-docs/epics}" PLAN NAME STATE PASS
  local ID BR GT DEP TITLE FOUND_STATE
  DISPATCH_EPIC=""; DISPATCH_PLAN=""; DISPATCH_PLAN_REL=""; DISPATCH_EPIC_STATE=""
  DISPATCH_ITEM=""; DISPATCH_TITLE=""; DISPATCH_BRANCH=""
  DISPATCH_GATE_TYPE=""; DISPATCH_DEPENDS=""
  DISPATCH_SOURCE_KIND=none; DISPATCH_SOURCE_NUM=""
  DISPATCH_REFUSAL=""

  if [ "$DISPATCH_SIGNALS_OK" != yes ]; then
    DISPATCH_REFUSAL="dispatch_load_signals has not run, so no item's dispatchability is known"
    return 1
  fi
  [ -d "$ROOT/$EDIR" ] || return 1

  for PASS in in-flight approved; do
    while IFS= read -r NAME; do
      [ -n "$NAME" ] || continue
      PLAN="$ROOT/$EDIR/$NAME/plan.md"
      [ -r "$PLAN" ] || continue
      STATE="$(dispatch_plan_state "$PLAN")"
      [ "$STATE" = "$PASS" ] || continue
      # Every item of this epic, in plan order, until one is dispatchable or
      # something is refused. A refusal inside an epic stops THAT EPIC rather
      # than skipping to its next item: items are sequenced, and stepping over
      # an item whose branch cannot be read is how you dispatch item 3 while
      # item 2 is unaccounted for.
      while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
        [ -n "${ID:-}" ] || continue
        if [ -z "${BR:-}" ]; then
          DISPATCH_REFUSAL="$EDIR/$NAME/plan.md item $ID ('${TITLE:-untitled}') carries no \`- **Branch:**\` line, so whether it has been dispatched cannot be decided — the item is refused, not guessed at, and no later item of this epic is considered"
          return 1
        fi
        if ! dispatch_branch_ok "$BR"; then
          DISPATCH_REFUSAL="$EDIR/$NAME/plan.md item $ID declares the branch [$BR], which is not a usable git branch name — refused rather than sanitised into something the plan did not say"
          return 1
        fi
        dispatch_is_dispatched "$BR" && continue
        # THE CANDIDATE. Everything before it in this epic is dispatched, by
        # construction of this loop.
        DISPATCH_EPIC="$NAME"
        DISPATCH_PLAN="$PLAN"
        DISPATCH_PLAN_REL="$EDIR/$NAME/plan.md"
        DISPATCH_EPIC_STATE="$STATE"
        DISPATCH_ITEM="$ID"
        DISPATCH_TITLE="${TITLE:-}"
        DISPATCH_BRANCH="$BR"
        DISPATCH_GATE_TYPE="${GT:-}"
        DISPATCH_DEPENDS="${DEP:-}"
        dispatch_plan_source "$PLAN"
        if ! _dispatch_depends_ready; then return 1; fi
        return 0
      done <<ITEMS_EOF
$(dispatch_work_items < "$PLAN")
ITEMS_EOF
    done <<EPICS_EOF
$(ls -1 "$ROOT/$EDIR" 2>/dev/null | _dispatch_epic_order)
EPICS_EOF
  done
  return 1
}

# A CANDIDATE WHOSE DEPENDENCY HAS NOT LANDED IS NOT THE NEXT ITEM, and this is
# the difference between working on the first live cycle and producing a broken
# pull request on the second. The runner opens a pull request and stops; a human
# merges it, at whatever hour suits them. Ten minutes later the next cycle sees
# item 1's branch on origin, calls it dispatched, and cuts item 2 from an
# integration branch that does not contain item 1 — which is a real defect
# dressed as progress.
#
# So a declared dependency must be MERGED, not merely dispatched. Merged is
# asked of the same pull request listing already in hand, so this costs no extra
# query. Items that declare `none` are unconstrained, which is what lets two
# genuinely parallel items proceed independently once their shared predecessor
# lands.
#
# A dependency naming an item that does not exist in the plan is a REFUSAL. So
# is one naming an item that appears LATER in the plan than the candidate: this
# file does not reason about out-of-order sequencing, and it says so rather than
# picking whichever reading is convenient.
_dispatch_depends_ready() {
  local IDS DID FOUND DEP_BRANCH DEP_POS CAND_POS POS ID BR GT DEP TITLE
  IDS="$(dispatch_depends_ids "$DISPATCH_DEPENDS")"
  [ -n "$IDS" ] || return 0
  while IFS= read -r DID; do
    [ -n "$DID" ] || continue
    FOUND=no; DEP_BRANCH=""; DEP_POS=0; CAND_POS=0; POS=0
    while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
      [ -n "${ID:-}" ] || continue
      POS=$((POS + 1))
      [ "$(printf '%s' "$ID" | tr 'A-Z' 'a-z')" = "$DID" ] && { FOUND=yes; DEP_BRANCH="${BR:-}"; DEP_POS="$POS"; }
      [ "$ID" = "$DISPATCH_ITEM" ] && CAND_POS="$POS"
    done <<DEP_ITEMS_EOF
$(dispatch_work_items < "$DISPATCH_PLAN")
DEP_ITEMS_EOF
    if [ "$FOUND" = no ]; then
      DISPATCH_REFUSAL="$DISPATCH_PLAN_REL item $DISPATCH_ITEM declares it depends on item $DID, which this plan does not contain — refused rather than assumed satisfied"
      return 1
    fi
    if [ "$DEP_POS" -gt "$CAND_POS" ]; then
      DISPATCH_REFUSAL="$DISPATCH_PLAN_REL item $DISPATCH_ITEM depends on item $DID, which is written AFTER it in the plan — this runner does not reason about out-of-order sequencing and refuses rather than choosing a reading"
      return 1
    fi
    if [ "$(dispatch_pr_state_for "$DEP_BRANCH")" != MERGED ]; then
      DISPATCH_REFUSAL="$DISPATCH_PLAN_REL item $DISPATCH_ITEM depends on item $DID (branch \`$DEP_BRANCH\`), which has no MERGED pull request — dispatching now would cut this item from an integration branch that does not contain its dependency. Merge item $DID first; this is a wait, not a failure"
      return 1
    fi
  done <<DEP_IDS_EOF
$IDS
DEP_IDS_EOF
  return 0
}

# ------------------------------------------------------------- admission
# Item 1's policy, applied. Everything here REFUSES; nothing here clamps a value
# down to something admissible, because a permission quietly reduced to fit is a
# permission nobody chose.
#
# THE LABELS ARE THE SOURCE ISSUE'S. `require-labels` and `forbid-labels` are
# stated about the tracker item, which for an epic is its `**Source:**` ref. A
# plan with no source has no labels to read, which arrives here as `,,`: that
# admits when nothing is required and refuses when something is, which is the
# safe direction in both cases and needs no special case to get right.
#
# A source that IS declared and whose labels cannot be READ is a refusal, not an
# empty list. `unknown` is not `clear`, and a forbidden label that was never
# fetched is a forbidden label that was never checked.
# dispatch_admit (the label-admission gate) is retired along with dispatch_repo
# below (epic 21 item 1) — it existed only to gate the headless invocation this
# file no longer performs.

# --------------------------------------------------- the gate declaration
# THE ONE THING AN UNATTENDED EXECUTOR CANNOT WORK OUT FOR ITSELF. Measured on
# the first real dispatch: the repo-wide gate script covered ZERO TypeScript and
# ran none of the tests that could catch a regression in the `.tsx` item under
# way. An attended executor run from a live session takes its gates from repo
# precedent, which is judgement; a headless one had none, hence this brief.
#
# A repo that declares no gate set is refused here, naming the file and the key
# to add — a gate that has never been shown to run is a hope. This preview
# survives the L2 daemon's retirement because it is reusable diagnostic
# tooling, not part of the retired execution path itself.
dispatch_gate_brief() { # sets DISPATCH_GATE_BRIEF / DISPATCH_GATE_COMMANDS
  DISPATCH_GATE_BRIEF=""
  DISPATCH_GATE_COMMANDS=""
  DISPATCH_REFUSAL=""
  if ! command -v provision_gate_brief >/dev/null 2>&1; then
    DISPATCH_REFUSAL="the provisioning library (bin/worktree-provision.sh) is not loaded, so no gate set is declared for this repo — refusing to dispatch an executor that would have to guess its gates"
    return 1
  fi
  # A `$( )` AROUND A FUNCTION IS A SUBSHELL, AND EVERY GLOBAL IT SETS DIES WITH
  # IT. `provision_gates` reports why it refused in PROVISION_REFUSAL, and
  # captured this way that reason never reaches the caller — the refusal degrades
  # to "none declared", which is a silent refusal wearing a message. So on
  # failure it is called AGAIN, outside the capture, purely to repopulate the
  # reason. It is read-only and idempotent, so the second call costs a function
  # call and buys back a sentence a human can act on. (bin/intake-status.sh
  # documents the identical hazard from the other direction: it takes its body as
  # an argument rather than on stdin so its own refusals survive.)
  if ! DISPATCH_GATE_COMMANDS="$(provision_gates "$DISPATCH_GATE_TYPE" 2>/dev/null)"; then
    provision_gates "$DISPATCH_GATE_TYPE" >/dev/null 2>&1 || true
    DISPATCH_REFUSAL="no gate set for this item: ${PROVISION_REFUSAL:-none declared}. L2 dispatch requires the repo to declare gates.<type> in the provisioning file — an executor that has to work out its own gates is the failure this rung is built on top of"
    return 1
  fi
  if ! DISPATCH_GATE_BRIEF="$(provision_gate_brief "$DISPATCH_GATE_TYPE" 2>/dev/null)"; then
    provision_gate_brief "$DISPATCH_GATE_TYPE" >/dev/null 2>&1 || true
    DISPATCH_REFUSAL="the gate brief for this item could not be built: ${PROVISION_REFUSAL:-unknown reason}"
    return 1
  fi
  return 0
}

# ------------------------------------------------------------- the brief
# WHAT THE EXECUTOR IS TOLD. Its contract is invoked BY NAME — `claude -p --agent
# work-item-executor` — and is never re-inlined or forked here, so this is only
# the per-item dispatch an orchestrator would give in a session, plus the two
# places where an unattended dispatch genuinely differs from an attended one:
#
#   1. IT DOES NOT OPEN THE PULL REQUEST. The denylist has to be enforced against
#      the real diff after the work exists and before it is proposed, and this is
#      the only place that fits. The executor stops at `gates-passed` and pushes;
#      the runner opens the pull request if — and only if — admission passes.
#   2. ITS GATES ARE DECLARED, not inferred. See dispatch_gate_brief.
#
# Nobody is watching this run, so the hard stops are restated in the prompt as
# well as enforced by the allowlist. The prose is the courtesy; the allowlist is
# the control.
dispatch_brief() { # $1 = repo slug, $2 = integration branch, $3 = skill dir
  cat <<BRIEF_EOF
You are dispatched as the work-item executor for ONE work item of an approved
epic. You were started by an UNATTENDED runner on a timer: there is no human in
this session, nobody will answer a question, and nothing you ask will be read
before this process exits.

  Repository:          ${1:-}
  Epic folder:         ${DISPATCH_PLAN_REL%/plan.md}
  Plan:                ${DISPATCH_PLAN_REL}
  Work item:           ${DISPATCH_ITEM} — ${DISPATCH_TITLE}
  Branch:              ${DISPATCH_BRANCH}   (already created and checked out here)
  Integration branch:  ${2:-}
  Your contract:       ${3:-}/../agents/work-item-executor.md  (you are running as that agent)
  Skill references:    ${3:-}/references/   — readable at that absolute path; do
                       NOT search the filesystem for them.

READ ${DISPATCH_PLAN_REL} YOURSELF BEFORE DOING ANYTHING. This dispatch is a
pointer; the plan is the contract. If the two disagree, that is \`blocked\`, not a
judgement call.

THIS WORKTREE IS ALREADY PROVISIONED AND ITS GATES HAVE BEEN SMOKE-TESTED. If a
gate fails, that is your change, not the environment. Do not "fix" the
environment, do not reinstall dependencies, and do not copy configuration around
— a worktree that could not run its gates would never have reached you.

${DISPATCH_GATE_BRIEF}

THE ONE PLACE THIS DIFFERS FROM AN ATTENDED DISPATCH: **DO NOT OPEN THE PULL
REQUEST.** Take the item to \`gates-passed\`, push the branch, and stop. The
runner that started you opens the pull request after it has checked your real
diff against a sensitive-path denylist and a size ceiling — a check that has to
sit between the work existing and the work being proposed. You do not have
\`gh pr create\` in your allowlist, so this is enforced rather than requested.

HARD STOPS, restated because nobody can approve anything right now:
  - Do NOT open, edit, merge or close any pull request.
  - Do NOT close, label, or comment on any issue.
  - Do NOT edit ${DISPATCH_PLAN_REL} or any other plan.
  - Do NOT touch any branch but ${DISPATCH_BRANCH}, and never ${2:-}.
  - Do NOT dispatch a subagent of your own.
  - Do NOT change any CI workflow, install script, hook, launchd job, or
    credential file. Those paths are on a denylist that is checked against your
    real diff before anything is proposed, and touching one throws the whole
    item away.

WHAT TO DO:
  1. Push on your very first commit and at every commit after it. Everything
     pushed survives; everything unpushed dies with this process, and two
     executors on this epic have already died silently with work in hand.
  2. Report a status.json milestone at every step, per your contract, into the
     canonical repo root's epic status tree. The runner READS the state you
     leave there and will not open a pull request unless it reads
     \`gates-passed\` or \`pr-opened\`: a milestone you did not write is a pull
     request that does not get opened.
  3. Run every declared gate above and report each result verbatim.
  4. If anything is ambiguous, write \`blocked\` with a precise question and
     STOP. A blocked item is recorded and left alone for a human. An unattended
     guess at an ambiguous plan is the worst outcome available to you.
  5. Finish the agreed slice. Scope that grows does not grow the branch — note
     the remainder in your return summary as a proposed follow-on item.
BRIEF_EOF
}

# The allowlist handed to `claude -p`. WIDER THAN THE DRAFTER'S BY DESIGN — an
# executor writes code and runs tests — and the widening is exactly why this
# rung has its own admission policy rather than inheriting the drafter's.
#
# WHAT IS ABSENT IS THE POINT. There is no `gh pr create`, no `gh pr merge`, no
# `gh pr edit`, no `gh issue close` and no `gh issue edit`. L2's ceiling is an
# open pull request opened BY THE RUNNER, and the ceiling is enforced by what the
# executor cannot invoke rather than by what it was asked not to do.
#
# The gate commands' own leading words are added, derived from the repo's
# provisioning declaration. That grants nothing new: `install`, `smoke` and every
# `gates.*` value are already shell commands this machinery runs, and
# worktree-provision.sh guards that file's ownership and mode for exactly that
# reason. Deriving the allowlist from the same declaration keeps the two from
# drifting apart, which is how an executor ends up unable to run the gate it was
# just told is mandatory.
dispatch_allowed_tools() { # -> one entry per line
  local CMD HEAD SEEN=""
  printf '%s\n' \
    'Bash(git:*)' \
    'Bash(gh issue view:*)' \
    'Bash(gh pr view:*)' \
    'Bash(gh pr diff:*)' \
    'Bash(ls:*)' 'Bash(cat:*)' 'Bash(head:*)' 'Bash(tail:*)' 'Bash(wc:*)' \
    'Bash(grep:*)' 'Bash(sed:*)' 'Bash(awk:*)' 'Bash(find:*)' 'Bash(date:*)' \
    'Bash(mkdir:*)' 'Bash(mv:*)' 'Bash(cp:*)' 'Bash(rm:*)' 'Bash(chmod:*)' \
    'Bash(diff:*)' 'Bash(cmp:*)' 'Bash(sort:*)' 'Bash(uniq:*)' 'Bash(printf:*)' \
    Read Write Edit Glob Grep
  while IFS= read -r CMD; do
    [ -n "$CMD" ] || continue
    HEAD="${CMD%% *}"
    HEAD="${HEAD##*/}"
    case "$HEAD" in ''|*[!A-Za-z0-9._-]*) continue ;; esac
    case " $SEEN " in *" $HEAD "*) continue ;; esac
    SEEN="$SEEN $HEAD"
    printf 'Bash(%s:*)\n' "$HEAD"
  done <<GATE_CMDS_EOF
$DISPATCH_GATE_COMMANDS
GATE_CMDS_EOF
}

# dispatch_record (one control-plane record per dispatch attempt) is retired
# with dispatch_repo below (epic 21 item 1) — it recorded state for the
# headless invocation this file no longer performs.

# ------------------------------------------- the denylist, against the DIFF
# THE CHECK THAT MAKES THIS RUNG SAFE, and it is asked of `git diff --name-only`
# and of nothing else. A plan says what an item intends to touch in PROSE; prose
# is not machine-readable, which is the entire reason epic 10 exists, so a
# declaration-based check would be checking the wrong thing with great
# confidence. This runs after the executor has returned and before anything is
# proposed.
#
# A refusal here does NOT delete the branch. The work is on origin and a human
# decides what it was: the refusal names the path and the pattern that caught it.
dispatch_check_diff() { # $1 = worktree, $2 = base ref
  local NAMES SIZE
  DISPATCH_DENIED=""
  DISPATCH_DIFF_FILES=0
  DISPATCH_DIFF_LINES=0
  DISPATCH_REFUSAL=""
  if ! command -v autonomy_deny_diff_paths >/dev/null 2>&1; then
    DISPATCH_REFUSAL="the autonomy control surface is not loaded, so the sensitive-path denylist could not be applied — refusing to open a pull request that was never checked"
    return 1
  fi
  NAMES="$("$DISPATCH_GIT" -C "${1:-}" diff --name-only "${2:-}...HEAD" 2>/dev/null)" || {
    DISPATCH_REFUSAL="could not read the diff of ${DISPATCH_BRANCH} against ${2:-} — refusing to open a pull request whose contents are unknown"
    return 1
  }
  if [ -z "$(printf '%s' "$NAMES" | tr -d '[:space:]')" ]; then
    DISPATCH_REFUSAL="the executor changed no files at all — there is nothing to propose"
    return 1
  fi
  SIZE="$("$DISPATCH_GIT" -C "${1:-}" diff --numstat "${2:-}...HEAD" 2>/dev/null | autonomy_diff_size)"
  DISPATCH_DIFF_FILES="${SIZE%% *}"
  DISPATCH_DIFF_LINES="${SIZE##* }"
  case "$DISPATCH_DIFF_FILES" in ''|*[!0-9]*) DISPATCH_DIFF_FILES=0 ;; esac
  case "$DISPATCH_DIFF_LINES" in ''|*[!0-9]*) DISPATCH_DIFF_LINES=0 ;; esac

  if ! DISPATCH_DENIED="$(printf '%s\n' "$NAMES" | autonomy_deny_diff_paths)"; then
    DISPATCH_REFUSAL="the diff touches a path on the sensitive-path denylist: $(printf '%s' "$DISPATCH_DENIED" | awk -F'\t' '{ printf "%s (matched %s); ", $1, $2 }' | sed -e 's/; $//'). No pull request was opened. The branch \`$DISPATCH_BRANCH\` is on origin and is left for a human"
    return 1
  fi
  if ! autonomy_check_size "$DISPATCH_DIFF_FILES" "$DISPATCH_DIFF_LINES"; then
    DISPATCH_REFUSAL="the diff exceeds this repo's size ceiling: ${AUTONOMY_REFUSAL:-too large}. No pull request was opened. The branch \`$DISPATCH_BRANCH\` is on origin and is left for a human"
    return 1
  fi
  return 0
}

# ------------------------------------------- what the executor said it did
# READ, NEVER TRUSTED OVER THE REPO. `origin` outranks `status.json` — that rule
# is load-bearing here rather than decorative, so this file uses the record for
# exactly two things: to notice `blocked`, and to refuse to open a pull request
# for an item whose gates were never reported.
#
# THE MISSING-RECORD CASE IS A REFUSAL. Item 2b names the worst available
# outcome of an unattended dispatch: a run that decides the gates are unrunnable,
# reports them skipped, and opens the pull request anyway. An executor that never
# wrote a milestone is indistinguishable from that, so it does not get a pull
# request. The branch stands and a human looks.
dispatch_read_executor_status() { # $1 = canonical repo root, $2 = epics dir
  local F
  DISPATCH_EXECUTOR_STATE=""
  DISPATCH_EXECUTOR_DETAIL=""
  F="${1:-}/${2:-docs/epics}/$DISPATCH_EPIC/status/$(dispatch_branch_slug "$DISPATCH_BRANCH").json"
  [ -r "$F" ] || return 1
  DISPATCH_EXECUTOR_STATE="$(grep -o '"state"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null \
    | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  DISPATCH_EXECUTOR_DETAIL="$(grep -o '"detail"[[:space:]]*:[[:space:]]*"[^"]*"' "$F" 2>/dev/null \
    | head -1 | sed -E -e 's/.*:[[:space:]]*"//' -e 's/"$//')"
  [ -n "$DISPATCH_EXECUTOR_STATE" ] || return 1
  return 0
}

# dispatch_pr_body, the budget counters (_dispatch_elapsed), the executor run
# log path (_dispatch_run_log_path) and _dispatch_cleanup_worktree are retired
# with dispatch_repo below (epic 21 item 1) — every one of them existed only to
# support the headless invocation this file no longer performs.

# rc 1 always now — see the header note at the top of this file. Signature and
# rc vocabulary kept unchanged from epic 11/19 because unattended-intake.sh and
# epic-loop.sh (both out of this item's scope) still call this function by
# name; only its body is retired.
dispatch_repo() { # $1 repo, $2 slug, $3 epics dir, $4 integration branch,
                  # $5 worktree root, $6 dry-run (yes|no), $7 skill dir,
                  # $8 closing-keyword (yes|no, default no — epic 19 item 6)
  local REPO="${1:-}" SLUG="${2:-}" EDIR="${3:-docs/epics}" BASE="${4:-}"
  local WTROOT="${5:-}" DRY="${6:-no}" SKILL="${7:-}"

  DISPATCH_REFUSAL="unattended dispatch is retired (epic 21 item 1) — dispatch only runs from a live, already-authenticated interactive session via the orchestrated work-item-executor path. Nothing was cut, pushed or invoked for $SLUG"
  DISPATCH_STATE="refused"
  dispatch_emit "REFUSED: $DISPATCH_REFUSAL"
  return 1
}

# ---------------------------------------------------------------------- CLI
# READ-ONLY IN EVERY MODE, and there is deliberately no `--dispatch`.
# `dispatch_repo` is the only function that once ran an executor, pushed a
# branch or opened a pull request, and it now always refuses (epic 21 item 1)
# — see the header note at the top of this file. A human can see everything
# this CLI decides without any of it happening.
_dispatch_cli_usage() { sed -n '1,10p' "$0"; }

_dispatch_cli() {
  local MODE=check REPO_PATH="" REPO_SLUG="" EDIR="" PLAN="" WT="" BASE="" RC=0
  local CLI_CLOSING=no
  local ID BR GT DEP TITLE
  while [ $# -gt 0 ]; do
    case "$1" in
      --check)      MODE=check ;;
      --plan)       MODE=plan; PLAN="${2-}"; shift ;;
      --select)     MODE=select ;;
      --deny)       MODE=deny ;;
      --repo)       REPO_PATH="${2-}"; shift ;;
      --slug)       REPO_SLUG="${2-}"; shift ;;
      --epics-dir)  EDIR="${2-}"; shift ;;
      --worktree)   WT="${2-}"; shift ;;
      --base)       BASE="${2-}"; shift ;;
      # Read-only preview only (epic 19 item 6): shows what `select`'s linkage
      # WOULD read as if a caller dispatched this item with the flag set. Never
      # dispatches anything — see the CLI's own header, unchanged by this flag.
      --closing-keyword) CLI_CLOSING=yes ;;
      -h|--help)    _dispatch_cli_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done
  [ -n "$EDIR" ] || EDIR=docs/epics

  case "$MODE" in
    plan)
      [ -r "$PLAN" ] || { printf 'cannot read plan: %s\n' "$PLAN" >&2; return 1; }
      printf 'status          %s\n' "$(dispatch_plan_state "$PLAN")"
      dispatch_plan_source "$PLAN"
      printf 'source          %s%s\n' "$DISPATCH_SOURCE_KIND" \
        "$( [ -n "$DISPATCH_SOURCE_NUM" ] && printf ' #%s' "$DISPATCH_SOURCE_NUM" )"
      while IFS="$DISPATCH_FS" read -r ID BR GT DEP TITLE; do
        [ -n "${ID:-}" ] || continue
        printf 'item %-6s branch=%-44s gates=%-8s depends=%-12s %s\n' \
          "$ID" "${BR:-<MISSING — REFUSED>}" "${GT:-<all>}" "${DEP:-none}" "${TITLE:-}"
      done <<CLI_ITEMS_EOF
$(dispatch_work_items < "$PLAN")
CLI_ITEMS_EOF
      return 0 ;;
    select)
      dispatch_load_signals "$REPO_SLUG" || { printf '%s\n' "$DISPATCH_REFUSAL" >&2; return 1; }
      if dispatch_select "$REPO_PATH" "$EDIR"; then
        printf 'epic            %s (%s)\n' "$DISPATCH_EPIC" "$DISPATCH_EPIC_STATE"
        printf 'item            %s — %s\n' "$DISPATCH_ITEM" "$DISPATCH_TITLE"
        printf 'branch          %s\n' "$DISPATCH_BRANCH"
        printf 'gate type       %s\n' "${DISPATCH_GATE_TYPE:-<all declared>}"
        printf 'source          %s%s\n' "$DISPATCH_SOURCE_KIND" \
          "$( [ -n "$DISPATCH_SOURCE_NUM" ] && printf ' #%s' "$DISPATCH_SOURCE_NUM" )"
        case "$DISPATCH_SOURCE_KIND" in
          gh) printf 'linkage         %s\n' "$( [ "$CLI_CLOSING" = yes ] && printf 'Closes #%s' "$DISPATCH_SOURCE_NUM" || printf 'Part of #%s' "$DISPATCH_SOURCE_NUM" )" ;;
          ab) printf 'linkage         %s\n' "$( [ "$CLI_CLOSING" = yes ] && printf 'Closes AB#%s' "$DISPATCH_SOURCE_NUM" || printf 'Part of AB#%s' "$DISPATCH_SOURCE_NUM" )" ;;
          *)  printf 'linkage         none (no Source: ref)\n' ;;
        esac
        return 0
      fi
      if [ -n "$DISPATCH_REFUSAL" ]; then
        printf 'REFUSED — %s\n' "$DISPATCH_REFUSAL" >&2
        return 1
      fi
      printf 'nothing to dispatch: no approved or in-flight epic has an undispatched work item\n'
      return 0 ;;
    deny)
      [ -n "$WT" ] && [ -n "$BASE" ] || { printf '--deny needs --worktree and --base\n' >&2; return 1; }
      if dispatch_check_diff "$WT" "$BASE"; then
        printf 'diff            %s file(s), %s line(s) — admitted\n' "$DISPATCH_DIFF_FILES" "$DISPATCH_DIFF_LINES"
        return 0
      fi
      printf 'REFUSED — %s\n' "$DISPATCH_REFUSAL" >&2
      return 1 ;;
  esac

  printf 'dispatch        RETIRED (epic 21 item 1) — dispatch_repo always refuses; nothing here spawns an executor unattended\n'
  printf 'never           approves · merges · closes an issue · chains to another item\n'
  if [ -n "$REPO_PATH" ] || [ -n "$REPO_SLUG" ]; then
    if command -v autonomy_resolve >/dev/null 2>&1; then
      autonomy_resolve "$REPO_PATH" "$REPO_SLUG"
      printf 'policy          %s\n' "${AUTONOMY_REASON:-unconfigured}"
    else
      printf 'policy          UNKNOWN — bin/autonomy.sh is not loadable\n'
      RC=1
    fi
    if command -v provision_resolve >/dev/null 2>&1; then
      provision_resolve "$REPO_PATH" "$REPO_SLUG" || true
      if dispatch_gate_brief; then
        printf 'gates           %s\n' "$(printf '%s' "$DISPATCH_GATE_COMMANDS" | tr '\n' ';' | sed -e 's/;$//')"
      else
        printf 'gates           REFUSED — %s\n' "$DISPATCH_REFUSAL"
        RC=1
      fi
    else
      printf 'gates           UNKNOWN — bin/worktree-provision.sh is not loadable\n'
      RC=1
    fi
    [ "$RC" -eq 0 ] || printf '                no dispatch may proceed for this repo\n'
  fi
  return "$RC"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _DISPATCH_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _DISPATCH_SIB in "${INTAKE_AUTONOMY_LIB:-$_DISPATCH_BIN/autonomy.sh}" \
                       "${INTAKE_PROVISION_LIB:-$_DISPATCH_BIN/worktree-provision.sh}"; do
    # shellcheck disable=SC1090
    [ -r "$_DISPATCH_SIB" ] && . "$_DISPATCH_SIB" 2>/dev/null
  done
  _dispatch_cli "$@"
  exit $?
fi
