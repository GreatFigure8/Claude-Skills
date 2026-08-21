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

# The field separator dispatch_work_items emits and every reader splits on. See
# the comment on that function for why it is not a tab.
DISPATCH_FS="$(printf '\037')"

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
dispatch_admit() { # $1 = repo slug
  local LABELS
  DISPATCH_REFUSAL=""
  if ! command -v autonomy_admit_labels >/dev/null 2>&1; then
    DISPATCH_REFUSAL="the autonomy control surface (bin/autonomy.sh) is not loaded, so no admission policy exists — refusing"
    return 1
  fi
  if [ "${AUTONOMY_LEVEL:-L0}" != "$DISPATCH_LEVEL" ]; then
    DISPATCH_REFUSAL="this repo resolves ${AUTONOMY_LEVEL:-L0}; dispatch requires $DISPATCH_LEVEL"
    return 1
  fi
  LABELS=",,"
  if [ "$DISPATCH_SOURCE_KIND" = gh ]; then
    LABELS="$("$DISPATCH_GH" issue view "$DISPATCH_SOURCE_NUM" --repo "${1:-}" --json labels \
              -q '",\((((.labels // []) | map(.name)) | join(","))),"' 2>/dev/null)" || LABELS=""
    case "$LABELS" in
      ,*,) ;;
      *) DISPATCH_REFUSAL="the labels of the source issue #$DISPATCH_SOURCE_NUM could not be read, so the admission policy could not be applied — refusing rather than admitting an unchecked item"
         return 1 ;;
    esac
  fi
  if ! autonomy_admit_labels "$LABELS"; then
    DISPATCH_REFUSAL="admission refused: ${AUTONOMY_REFUSAL:-label policy}"
    return 1
  fi
  return 0
}

# --------------------------------------------------- the gate declaration
# THE ONE THING AN UNATTENDED EXECUTOR CANNOT WORK OUT FOR ITSELF. Measured on
# the first real dispatch: the repo-wide gate script covered ZERO TypeScript and
# ran none of the tests that could catch a regression in the `.tsx` item under
# way. The attended executor ran the right gates from repo precedent, which is
# judgement, and judgement is what is absent here.
#
# SO L2 REQUIRES A DECLARED GATE SET. A repo that declares none is refused,
# naming the file and the key to add. That is not an inconvenience: a gate that
# has never been shown to run is a hope, and an unattended cycle whose worst
# available outcome is "gates reported skipped, pull request opened anyway" is
# exactly what item 2b exists to prevent. Drafting at L0 is untouched by this —
# a repo with no provisioning section still drafts, exactly as it does today.
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

# ------------------------------------------------------- the control plane
# ONE RECORD PER DISPATCH ATTEMPT, in the reserved intake tree item 2 built,
# written through item 2's guard with the resolved path VISIBLE at the call site
# (GH #63: correct resolution and invisible resolution are independent
# properties, and only the second one causes the bug).
#
# NAMED `dispatch-<branch-slug>.json` and not `<branch-slug>.json`, deliberately.
# The executor writes its OWN `<branch-slug>.json` into the EPIC's status tree;
# these are two different records about two different things — what the executor
# believes, and what the runner observed — and giving them the same basename in
# two trees is an invitation to read one and think it is the other.
#
# Nothing in this file branches on whether this succeeded. Telemetry that can
# change a decision is a decision that changes when you watch it.
dispatch_record() { # $1 = state, $2 = detail
  local TARGET BODY
  DISPATCH_STATE="${1:-}"
  [ -n "${INTAKE_STATUS_DIR:-}" ] || return 0
  [ -n "$DISPATCH_BRANCH" ] || return 0
  TARGET="$INTAKE_STATUS_DIR/dispatch-$(dispatch_branch_slug "$DISPATCH_BRANCH").json"
  BODY="$( {
    printf '{\n'
    printf '  "item": "%s item %s — %s",\n' \
      "$(intake_status_escape "$DISPATCH_EPIC")" \
      "$(intake_status_escape "$DISPATCH_ITEM")" \
      "$(intake_status_escape "$DISPATCH_TITLE")"
    printf '  "branch": "%s",\n'  "$(intake_status_escape "$DISPATCH_BRANCH")"
    printf '  "state": "%s",\n'   "$(intake_status_escape "${1:-}")"
    printf '  "detail": "%s",\n'  "$(intake_status_escape "${2:-}")"
    printf '  "commit": null,\n'
    printf '  "updated": "%s",\n' "$(dispatch_now)"
    printf '  "runner": "unattended-intake (L2 dispatch)",\n'
    printf '  "epic": "%s",\n'    "$(intake_status_escape "$DISPATCH_EPIC")"
    printf '  "plan": "%s",\n'    "$(intake_status_escape "$DISPATCH_PLAN_REL")"
    printf '  "executor_state": "%s",\n' "$(intake_status_escape "$DISPATCH_EXECUTOR_STATE")"
    printf '  "pr": "%s"\n'       "$(intake_status_escape "$DISPATCH_PR_URL")"
    printf '}'
  } )"
  intake_status_write "$TARGET" "$BODY" || true
  intake_status_ledger dispatch "${1:-}" "${2:-}" ""
  return 0
}

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

# ---------------------------------------------------------- the pull request
# THE CEILING. Against the INTEGRATION branch, always; `Part of #<n>` exactly
# once and NEVER a closing keyword, because a closing keyword makes a merge close
# an issue and closing an issue is a thing this runner does not do — not
# directly, and not by leaving a fuse for someone else's merge to light.
#
# EVERY CLAIM IN IT IS EVIDENCE THE RUNNER ACTUALLY HAS. It did not read the
# code, it did not run the gates, and it says so rather than filling the
# template's Verification section with a description of output nobody produced.
# What it can paste, it pastes: the diffstat, the denylist result, the size
# against the ceiling, and the executor's own final milestone verbatim.
dispatch_pr_body() { # $1 = repo slug, $2 = integration branch, $3 = worktree, $4 = base ref
  local LINKAGE=""
  case "$DISPATCH_SOURCE_KIND" in
    gh) LINKAGE="Part of #$DISPATCH_SOURCE_NUM" ;;
    ab) LINKAGE="Part of AB#$DISPATCH_SOURCE_NUM" ;;
  esac
  cat <<PR_EOF
> **Opened by an unattended L2 dispatch cycle. No human has read this diff.**
> A machine selected this work item, wrote it, ran the declared gates and opened
> this pull request. **Review it cold, against the plan, exactly as you would an
> attended item** — the pull request is the gate, and nothing merges without you.

## Work item

Epic: \`${DISPATCH_PLAN_REL%/plan.md}\` — \`${DISPATCH_PLAN_REL}\`
Item: ${DISPATCH_ITEM} — ${DISPATCH_TITLE}
Branch: \`${DISPATCH_BRANCH}\` → \`${2:-}\`

## Summary

Work item ${DISPATCH_ITEM} of \`${DISPATCH_EPIC}\`, executed unattended by
\`work-item-executor\` and admitted by the L2 dispatch policy. The item was
selected because no branch named \`${DISPATCH_BRANCH}\` existed on \`origin\` and
no open or merged pull request had it as head — never from any prose marker in
the plan.

## In scope

- Work item ${DISPATCH_ITEM} of \`${DISPATCH_PLAN_REL}\` as written. The plan
  item is the scope; this body does not restate it, because a restatement drafted
  by the runner would be a second, unreviewed copy of it.

## Deliberately not in scope

- Everything the plan item's own **Not in scope** line names.
- Any path on the sensitive-path denylist — CI and workflow configuration,
  \`install.sh\`, the control-plane hooks, the unattended runner, launchd jobs and
  credential material. That is checked against the real diff below, not promised.

## Verification

**Run by the runner, against the artifacts, after the executor returned:**

- \`git diff --name-only ${4:-}...HEAD\` → **${DISPATCH_DIFF_FILES} file(s)**, **${DISPATCH_DIFF_LINES} line(s)** added+deleted
- sensitive-path denylist → **clean** (no path matched the built-in floor or this repo's \`deny-paths\`)
- size ceiling (\`max-files\` / \`max-diff-lines\`) → **within limits**
- worktree provisioning preflight and smoke check → **passed before the executor was invoked**
- executor's final milestone, read from its own \`status.json\` → **\`${DISPATCH_EXECUTOR_STATE}\`** — ${DISPATCH_EXECUTOR_DETAIL}

\`\`\`
$("$DISPATCH_GIT" -C "${3:-}" diff --stat "${4:-}...HEAD" 2>/dev/null | tail -40)
\`\`\`

\`\`\`
$("$DISPATCH_GIT" -C "${3:-}" log --oneline "${4:-}..HEAD" 2>/dev/null | head -40)
\`\`\`

### Gates (per the repo's declared gate set)

The commands below were declared for this item type in the provisioning
configuration and handed to the executor verbatim:

\`\`\`
${DISPATCH_GATE_COMMANDS}
\`\`\`

**Not verified by the runner, stated plainly:** the runner did not re-run these
and does not paste their output. It read the executor's milestone
(\`${DISPATCH_EXECUTOR_STATE}\`) and refuses to open a pull request for anything
short of \`gates-passed\`. If you want the output, it is in the executor's own
run log on the machine that ran this cycle; if you want certainty, run them here.

## Rollback

Close this pull request, or revert the merge commit. Nothing outside this branch
was changed by the run: no plan was edited, no issue was labelled, commented on
or closed, and nothing was merged.

## Plan impact

- Mark item ${DISPATCH_ITEM} of \`${DISPATCH_PLAN_REL}\` done when this merges,
  and move anything the executor's return summary parked into the Deferred list.

${LINKAGE}
PR_EOF
}

# ------------------------------------------------------------------ budget
# CYCLE-WIDE, not per repo. "One item at a time" is an epic 11 invariant and the
# default is one item per cycle, so the counter lives with the library — which is
# sourced once per cycle — rather than being threaded through the runner where
# somebody would eventually reset it in the repo loop.
DISPATCH_ITEMS_DONE=0
DISPATCH_CYCLE_START="$(date -u +%s 2>/dev/null || printf '0')"

_dispatch_elapsed() {
  local NOW
  NOW="$(date -u +%s 2>/dev/null || printf '0')"
  case "$NOW$DISPATCH_CYCLE_START" in *[!0-9]*) printf '0'; return 0 ;; esac
  printf '%s' $((NOW - DISPATCH_CYCLE_START))
}

# --------------------------------------------------------------- the cycle
# THE EXECUTOR'S OUTPUT GOES IN THE WORKTREE'S ADMIN DIRECTORY, NEVER IN ITS
# WORKING TREE, and this was measured rather than reasoned about: written to
# `$WT/.dispatch-run.log` it is an untracked file in a checkout where an
# unattended executor is about to run `git add -A` — so the runner's own log
# lands in the executor's commit, in the diff the denylist checks, and in the
# pull request a human reviews. The fixture caught it as "2 file(s)" where the
# item touched one. Same reasoning, same fix, as item 2b's provisioning log.
_dispatch_run_log_path() { # $1 = worktree -> stdout
  local G
  G="$("$DISPATCH_GIT" -C "${1:-}" rev-parse --absolute-git-dir 2>/dev/null)" || G=""
  if [ -n "$G" ] && [ -d "$G" ]; then
    printf '%s/dispatch-executor.log' "$G"
  else
    printf '%s/.dispatch-executor-%s.log' "${TMPDIR:-/tmp}" "$$"
  fi
}

_dispatch_cleanup_worktree() { # $1 = repo checkout
  [ -n "$DISPATCH_WORKTREE" ] || return 0
  # The worktree may hold environment files copied in by provisioning. Removing
  # it is not tidiness — a credential-bearing checkout that outlives the run is a
  # credential-bearing checkout nobody is watching.
  "$DISPATCH_GIT" -C "${1:-}" worktree remove --force "$DISPATCH_WORKTREE" 2>/dev/null || true
  rm -rf "$DISPATCH_WORKTREE" 2>/dev/null || true
  DISPATCH_WORKTREE=""
  return 0
}

# rc 0 = an item was dispatched and its pull request is open
# rc 1 = nothing to do, and nothing to say
# rc 2 = refused or failed; DISPATCH_REFUSAL says why and has been emitted
# rc 3 = --dry-run reported what would happen and changed nothing
dispatch_repo() { # $1 repo, $2 slug, $3 epics dir, $4 integration branch,
                  # $5 worktree root, $6 dry-run (yes|no), $7 skill dir
  local REPO="${1:-}" SLUG="${2:-}" EDIR="${3:-docs/epics}" BASE="${4:-}"
  local WTROOT="${5:-}" DRY="${6:-no}" SKILL="${7:-}"
  local BASEREF="origin/$BASE" WT RC CPID WAITED HEARTBEAT ROOT
  local TOOLS=""

  DISPATCH_REFUSAL=""; DISPATCH_PR_URL=""; DISPATCH_WORKTREE=""
  DISPATCH_EXECUTOR_STATE=""; DISPATCH_EXECUTOR_DETAIL=""
  # Cleared per repo. The runner reads it to decide whether this repo's cycle
  # record closes `finished` or `failed`, and inheriting the previous repo's
  # value would attribute one repo's failure to another — the same defect
  # REPO_FAILED_ON_ENTRY already exists to prevent on the drafting side.
  DISPATCH_STATE=""

  # THE LEVEL, FIRST AND SILENTLY. Every repo with no autonomy configuration
  # resolves L0, and an L0 repo produces NOT ONE LINE from this file — no log, no
  # GitHub call, no worktree. That silence is the inertness guarantee at the level
  # a human notices, and it lives HERE rather than in the runner's `if` for the
  # same reason `provision_resolve` owns its own silent path: the policy owns the
  # question, and the caller should not have to know the answer's variable name.
  if [ "${AUTONOMY_LEVEL:-L0}" != "$DISPATCH_LEVEL" ]; then
    return 1
  fi

  # THE BUDGET, NEXT. It is a hard stop: exceeding it stops new work and never
  # shrinks work to fit.
  if ! autonomy_budget_allows_item "$DISPATCH_ITEMS_DONE"; then
    dispatch_emit "L2: $SLUG — no dispatch this cycle: ${AUTONOMY_REFUSAL:-budget}"
    return 1
  fi
  if ! autonomy_budget_allows_time "$(_dispatch_elapsed)"; then
    dispatch_emit "L2: $SLUG — no dispatch this cycle: ${AUTONOMY_REFUSAL:-budget}"
    return 1
  fi

  # THE OVERRIDE, RE-ASKED. autonomy_resolve already honoured it, but a human who
  # reaches for the kill switch does so DURING a cycle, not before one, and every
  # `[ -e ]` between here and the pull request is a place they can still be heard.
  if autonomy_override_active; then
    dispatch_emit "L2: $SLUG — global override present at $AUTONOMY_OVERRIDE_FILE; nothing is dispatched (drafting continues)"
    return 1
  fi

  if ! dispatch_load_signals "$SLUG"; then
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"
    return 2
  fi
  if ! dispatch_select "$REPO" "$EDIR"; then
    if [ -n "$DISPATCH_REFUSAL" ]; then
      dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"
      return 2
    fi
    dispatch_emit "L2: $SLUG — no approved or in-flight epic has an undispatched work item"
    return 1
  fi

  dispatch_emit "L2: $SLUG — next undispatched item is $DISPATCH_EPIC item $DISPATCH_ITEM ($DISPATCH_TITLE) on branch $DISPATCH_BRANCH [epic is $DISPATCH_EPIC_STATE]"

  if ! dispatch_admit "$SLUG"; then
    dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
    dispatch_record refused "$DISPATCH_REFUSAL"
    return 2
  fi

  # Resolved before the worktree exists so a repo that declares no gates is
  # refused without anything having been created for it.
  if command -v provision_resolve >/dev/null 2>&1; then
    provision_resolve "$REPO" "$SLUG" || true
  fi
  if ! dispatch_gate_brief; then
    dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
    dispatch_record refused "$DISPATCH_REFUSAL"
    return 2
  fi

  if [ "$DRY" = yes ]; then
    dispatch_emit "DRY-RUN: would cut $WTROOT/$(basename "$REPO")-$(dispatch_branch_slug "$DISPATCH_BRANCH") on $DISPATCH_BRANCH from origin/$BASE"
    dispatch_emit "DRY-RUN: would provision it, smoke-check it, and invoke claude -p --agent work-item-executor"
    dispatch_emit "DRY-RUN: would check the real diff against the denylist and the size ceiling, then open a PR against $BASE. Nothing merged, nothing closed."
    return 3
  fi

  WT="$WTROOT/$(basename "$REPO")-$(dispatch_branch_slug "$DISPATCH_BRANCH")"
  # Belt and braces, exactly as the drafting path does it: never create outside
  # the one declared root, whatever the repo basename or branch turned out to be.
  case "$WT" in
    "$WTROOT"/*) ;;
    *) DISPATCH_REFUSAL="refusing to create a worktree outside $WTROOT"
       dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record refused "$DISPATCH_REFUSAL"; return 2 ;;
  esac
  if [ -e "$WT" ]; then
    DISPATCH_REFUSAL="$WT already exists — refusing to dispatch into a directory this cycle did not create"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record refused "$DISPATCH_REFUSAL"; return 2
  fi
  if "$DISPATCH_GIT" -C "$REPO" show-ref --verify --quiet "refs/heads/$DISPATCH_BRANCH" 2>/dev/null; then
    DISPATCH_REFUSAL="a local branch \`$DISPATCH_BRANCH\` already exists in $REPO — that is somebody's work, and this runner never touches it"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record refused "$DISPATCH_REFUSAL"; return 2
  fi

  dispatch_record admitted "cutting $DISPATCH_BRANCH from origin/$BASE"
  intake_status_cycle dispatching "L2: $DISPATCH_EPIC item $DISPATCH_ITEM on $DISPATCH_BRANCH ($SLUG)"

  # NEVER touch the target checkout — no switch, no pull (GH #27). Fetching is
  # enough: the worktree is cut from origin/<integration>.
  "$DISPATCH_GIT" -C "$REPO" fetch -q origin "$BASE" 2>/dev/null || true
  if ! "$DISPATCH_GIT" -C "$REPO" worktree add -q "$WT" -b "$DISPATCH_BRANCH" "$BASEREF" 2>/dev/null; then
    DISPATCH_REFUSAL="could not create the worktree $WT on $DISPATCH_BRANCH from $BASEREF"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record failed "$DISPATCH_REFUSAL"
    "$DISPATCH_GIT" -C "$REPO" branch -D "$DISPATCH_BRANCH" 2>/dev/null || true
    return 2
  fi
  DISPATCH_WORKTREE="$WT"

  # THE PREFLIGHT — the difference between "we provisioned" and "the gate can
  # run". A failure here refuses the dispatch and leaves NOTHING behind: no
  # worktree, no local branch, and nothing on origin, so a transient install
  # failure does not permanently retire a work item.
  if command -v provision_preflight >/dev/null 2>&1; then
    if ! provision_preflight "$REPO" "$SLUG" "$WT"; then
      DISPATCH_REFUSAL="worktree provisioning refused this dispatch: ${PROVISION_REFUSAL:-unknown reason}"
      dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
      dispatch_record refused "$DISPATCH_REFUSAL"
      _dispatch_cleanup_worktree "$REPO"
      "$DISPATCH_GIT" -C "$REPO" branch -D "$DISPATCH_BRANCH" 2>/dev/null || true
      return 2
    fi
    while IFS= read -r PLINE; do
      [ -n "$PLINE" ] || continue
      dispatch_emit "$PLINE"
    done <<PROVISION_REPORT_EOF
${PROVISION_REPORT:-}
PROVISION_REPORT_EOF
  else
    DISPATCH_REFUSAL="the provisioning library is not loaded, so nothing verified that this worktree can run its gates"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record refused "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    "$DISPATCH_GIT" -C "$REPO" branch -D "$DISPATCH_BRANCH" 2>/dev/null || true
    return 2
  fi

  # THE POINT OF NO RETRY. Pushing the branch here — before an executor exists
  # that could die without saying so — is what makes the dispatchability rule
  # answer honestly next cycle. An executor that dies at its first tool call
  # leaves a branch at the base commit and a control-plane record saying so; the
  # item is not silently re-dispatched every ten minutes forever, which is the
  # worst behaviour available to an unattended loop.
  if ! "$DISPATCH_GIT" -C "$WT" push -q -u origin "$DISPATCH_BRANCH" 2>/dev/null; then
    DISPATCH_REFUSAL="could not push $DISPATCH_BRANCH to origin — refusing to run an executor whose work would have nowhere to survive"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"; dispatch_record failed "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    "$DISPATCH_GIT" -C "$REPO" branch -D "$DISPATCH_BRANCH" 2>/dev/null || true
    return 2
  fi
  dispatch_emit "L2: $DISPATCH_BRANCH pushed to origin at $BASEREF — the item is now marked dispatched whatever happens next"

  DISPATCH_ITEMS_DONE=$((DISPATCH_ITEMS_DONE + 1))
  DISPATCH_RUN_LOG="$(_dispatch_run_log_path "$WT")"
  : > "$DISPATCH_RUN_LOG" 2>/dev/null || true
  dispatch_record dispatching "executor running in $WT; full output at $DISPATCH_RUN_LOG"
  dispatch_emit "L2: invoking claude -p --agent work-item-executor for $DISPATCH_EPIC item $DISPATCH_ITEM (timeout ${DISPATCH_EXECUTOR_TIMEOUT}s)"

  TOOLS="$(dispatch_allowed_tools | tr '\n' ' ')"
  dispatch_emit "L2: executor allowlist — $TOOLS"
  # shellcheck disable=SC2086
  ( cd "$WT" && "$DISPATCH_CLAUDE" -p "$(dispatch_brief "$SLUG" "$BASE" "$SKILL")" \
      --agent work-item-executor \
      --add-dir "$SKILL" \
      --allowed-tools $TOOLS ) > "$DISPATCH_RUN_LOG" 2>&1 &
  CPID=$!
  # A HEARTBEAT, NOT A HOPE. Two executors on this epic froze at one milestone
  # for over an hour and the only reason anybody noticed was a human counting
  # minutes. A quiet run and a dead one are not the same thing, so this says
  # which it is every five minutes and moves `updated` on the record each time.
  WAITED=0; HEARTBEAT=0
  while kill -0 "$CPID" 2>/dev/null; do
    if [ "$WAITED" -ge "$DISPATCH_EXECUTOR_TIMEOUT" ]; then
      dispatch_emit "L2: executor exceeded ${DISPATCH_EXECUTOR_TIMEOUT}s — terminating it. Everything it pushed survives."
      kill -TERM "$CPID" 2>/dev/null || true
      sleep 5
      kill -KILL "$CPID" 2>/dev/null || true
      break
    fi
    sleep 5
    WAITED=$((WAITED + 5)); HEARTBEAT=$((HEARTBEAT + 5))
    if [ "$HEARTBEAT" -ge 300 ]; then
      HEARTBEAT=0
      dispatch_emit "L2: executor still running — ${WAITED}s elapsed on $DISPATCH_BRANCH"
      dispatch_record dispatching "executor still running — ${WAITED}s elapsed"
    fi
  done
  wait "$CPID" 2>/dev/null
  RC=$?
  dispatch_emit "L2: executor exited $RC after ${WAITED}s"

  # Whatever it produced, get it onto origin before anything is judged. The
  # executor's contract says push on the first commit; this is the runner not
  # relying on that having happened.
  "$DISPATCH_GIT" -C "$WT" push -q -u origin "$DISPATCH_BRANCH" 2>/dev/null || true

  ROOT="$("$DISPATCH_GIT" -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$ROOT" ] && ROOT="$(dirname "$ROOT")" || ROOT="$REPO"
  dispatch_read_executor_status "$ROOT" "$EDIR" || true

  if [ "$DISPATCH_EXECUTOR_STATE" = blocked ]; then
    # RECORDED, AND THE EPIC IS LEFT ALONE. Never retried: a block is by
    # definition something the automation cannot resolve, and an unattended retry
    # loop on an ambiguous plan is the worst behaviour available here.
    DISPATCH_REFUSAL="the executor returned \`blocked\`: ${DISPATCH_EXECUTOR_DETAIL:-no detail given}. No pull request was opened, the epic is left alone, and this is NOT retried — a human answers the question and re-dispatches"
    dispatch_emit "L2 BLOCKED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
    dispatch_record blocked "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    return 2
  fi
  if [ "$RC" -ne 0 ]; then
    DISPATCH_REFUSAL="the executor exited $RC (full output at $DISPATCH_RUN_LOG, which lives in the worktree's admin directory and is removed with it). The branch \`$DISPATCH_BRANCH\` is on origin and is left for a human"
    dispatch_emit "L2 FAILED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
    dispatch_record failed "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    return 2
  fi
  case "$DISPATCH_EXECUTOR_STATE" in
    gates-passed|pr-opened) ;;
    '') DISPATCH_REFUSAL="the executor wrote no status record at all, so nothing says its gates ran. A pull request opened on that basis is exactly the 'gates reported skipped, PR opened anyway' outcome this rung exists to prevent. The branch \`$DISPATCH_BRANCH\` is on origin and is left for a human"
        dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
        dispatch_record refused "$DISPATCH_REFUSAL"
        _dispatch_cleanup_worktree "$REPO"; return 2 ;;
    *)  DISPATCH_REFUSAL="the executor's last milestone was \`$DISPATCH_EXECUTOR_STATE\` (${DISPATCH_EXECUTOR_DETAIL:-no detail}), not \`gates-passed\` — it did not finish. No pull request was opened; the branch \`$DISPATCH_BRANCH\` is on origin and is left for a human"
        dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
        dispatch_record refused "$DISPATCH_REFUSAL"
        _dispatch_cleanup_worktree "$REPO"; return 2 ;;
  esac

  if ! dispatch_check_diff "$WT" "$BASEREF"; then
    dispatch_emit "L2 REFUSED: $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_REFUSAL"
    dispatch_record refused "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    return 2
  fi
  dispatch_emit "L2: diff admitted — $DISPATCH_DIFF_FILES file(s), $DISPATCH_DIFF_LINES line(s), no denylisted path"

  # THE LAST PLACE THE KILL SWITCH IS HEARD. The executor may have run for an
  # hour, and the file may have appeared during it. L2's ceiling is a pull
  # request, so dropping to L0 mid-flight means the pull request is not opened.
  # The work is on origin either way; nothing is lost, and a human decides.
  if autonomy_override_active; then
    DISPATCH_REFUSAL="the global override appeared at $AUTONOMY_OVERRIDE_FILE while the executor was running — every repo is pinned to L0, so no pull request is opened. The branch \`$DISPATCH_BRANCH\` is pushed and complete; open it by hand, or remove the override and re-dispatch"
    dispatch_emit "L2 REFUSED: $DISPATCH_REFUSAL"
    dispatch_record refused "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    return 2
  fi

  DISPATCH_PR_URL="$("$DISPATCH_GH" pr create --repo "$SLUG" --base "$BASE" --head "$DISPATCH_BRANCH" \
      --title "[unattended] $DISPATCH_EPIC item $DISPATCH_ITEM — $DISPATCH_TITLE" \
      --body "$(dispatch_pr_body "$SLUG" "$BASE" "$WT" "$BASEREF")" 2>/dev/null || true)"
  if [ -z "$DISPATCH_PR_URL" ]; then
    DISPATCH_REFUSAL="the pull request could not be created. The branch \`$DISPATCH_BRANCH\` is pushed and complete; open it by hand"
    dispatch_emit "L2 FAILED: $DISPATCH_REFUSAL"
    dispatch_record failed "$DISPATCH_REFUSAL"
    _dispatch_cleanup_worktree "$REPO"
    return 2
  fi

  dispatch_emit "L2: $DISPATCH_EPIC item $DISPATCH_ITEM -> $DISPATCH_PR_URL (open, unmerged; nothing was approved, merged or closed)"
  dispatch_record pr-opened "$DISPATCH_PR_URL"
  intake_status_cycle dispatched "L2: $DISPATCH_EPIC item $DISPATCH_ITEM opened $DISPATCH_PR_URL — stopping there"
  _dispatch_cleanup_worktree "$REPO"
  return 0
}

# ---------------------------------------------------------------------- CLI
# READ-ONLY IN EVERY MODE. There is deliberately no `--dispatch`: the one entry
# point that runs an executor, pushes a branch or opens a pull request is
# `dispatch_repo`, and it is reachable only from the runner, on a cycle that has
# already passed the stop file, the lock, the credential check and the level
# resolution. A human — and a fixture — can see everything this file decides
# without any of it happening.
_dispatch_cli_usage() { sed -n '1,10p' "$0"; }

_dispatch_cli() {
  local MODE=check REPO_PATH="" REPO_SLUG="" EDIR="" PLAN="" WT="" BASE="" RC=0
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

  printf 'dispatch        enforced=%s   ceiling=%s\n' "$DISPATCH_ENFORCED" "$DISPATCH_LEVEL"
  printf 'executor        claude -p --agent work-item-executor   timeout=%ss\n' "$DISPATCH_EXECUTOR_TIMEOUT"
  printf 'never           approves · merges · closes an issue · chains to another item\n'
  printf 'ceiling         an OPEN pull request against the integration branch\n'
  if [ -n "$REPO_PATH" ] || [ -n "$REPO_SLUG" ]; then
    if command -v autonomy_resolve >/dev/null 2>&1; then
      autonomy_resolve "$REPO_PATH" "$REPO_SLUG"
      printf 'level           %s   (%s)\n' "${AUTONOMY_LEVEL:-L0}" "${AUTONOMY_REASON:-unconfigured}"
      [ "${AUTONOMY_LEVEL:-L0}" = "$DISPATCH_LEVEL" ] || RC=1
    else
      printf 'level           UNKNOWN — bin/autonomy.sh is not loadable, so nothing may be dispatched\n'
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
