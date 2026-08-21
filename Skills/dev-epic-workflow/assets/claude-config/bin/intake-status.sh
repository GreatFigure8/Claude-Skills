#!/usr/bin/env bash
# ONE CONTROL PLANE — telemetry for the unattended runner (epic 11 item 2).
#
# THE DEFECT THIS EXISTS TO CLOSE, measured 2026-08-21 and not supposed. There
# were two telemetry universes and only one of them was visible from a session:
#
#                          orchestrated executor | unattended runner
#   status.json milestones             yes       | ZERO writes
#   agent log in the status tree       yes       | none
#   surfaced by SessionStart           yes       | ZERO references
#   where it reports    the canonical control plane | one flat file outside
#                                                    every repo
#
# On 2026-08-21 the runner drafted nine LODE proposals and the only way to watch
# it was to know `~/.config/claude-intake/intake.log` exists and `tail -f` it by
# hand. An automation nobody can see is not automation, it is a background
# process. This library makes the runner report where the orchestrator already
# looks, so watching is the DEFAULT rather than something assembled each time.
#
# IT CHANGES ONLY WHAT THE RUNNER REPORTS, NEVER WHAT IT DOES. Nothing here
# approves, dispatches, merges, closes an issue, or writes a line of code. Every
# function is best-effort and returns 0 whatever happens: a runner that fails
# because its TELEMETRY failed is strictly worse than a runner with no telemetry,
# and this one runs unattended on a 600-second timer against live repositories.
#
# ------------------------------------------------------------ WHERE IT WRITES
#
# THE DESIGN PROBLEM: a drafting run has NO EPIC YET. A proposal is being
# written, so there is no `docs/epics/<NN>-<slug>/` to report into — but the
# control plane is addressed by epic folder. The answer is a RESERVED INTAKE
# STATUS TREE, one per repo, resolved by the same rule the hooks use:
#
#     <repo-root>/<epics-dir>/.intake/status/
#     where <repo-root> = dirname "$(git rev-parse --path-format=absolute
#                                    --git-common-dir)"
#
# so a linked worktree cannot split it: drafting happens in a worktree, and the
# worktree's --git-common-dir still points at the main checkout's .git.
#
# IT MUST NEVER BE MISTAKEN FOR AN EPIC. GH #9 and GH #11 are what that mistake
# costs — a live executor's telemetry redirected into a closed epic, then into a
# queued one. THREE INDEPENDENT GUARANTEES, not one:
#
#   1. THE NAME BEGINS WITH A DOT. The resolvers glob `docs/epics/*/plan.md` and
#      `docs/epics/*/`, and a shell `*` does not match a leading dot. So the
#      active-epic resolver, the epic-queue section, the handoff and autosnapshot
#      globs and the session-end guard cannot see it at all.
#   2. IT NEVER CONTAINS A plan.md. Even with `dotglob` forced on, resolution
#      passes (b) and (c) require a readable plan.md, and the queue section
#      iterates `*/plan.md`. No plan, no candidacy. `intake_status_tree` asserts
#      this on every call and REFUSES the tree if one ever appears.
#   3. NOTHING HERE EVER WRITES `.claude/signals/active-epic`. Pointer
#      resolution — path (a) — is an orchestrator act at dispatch setup, and the
#      unattended runner is not an orchestrator.
#
# The tree also carries a SELF-IGNORING `.gitignore` containing `*`, which git
# applies to the .gitignore itself, so the whole directory is invisible to
# `git status` in the target repo. The runner must never dirty a checkout a
# human may be mid-edit in, and runtime state is never committed — the same rule
# `docs/epics/*/status/` already follows in this repo's own .gitignore.
#
# ----------------------------------------------------------- WHAT IT WRITES
#
#   status/cycle.json           the cycle, status.json-SHAPED (item/branch/state/
#                               detail/commit/updated) plus the cycle facts a
#                               reader needs: cycle id, pid, lock, issue, queue.
#   status/<branch-slug>.json   one per issue, named exactly as an executor's is
#                               — the proposal branch with `/` turned to `-`.
#   status/agent-<cycle>.log    an agent-style log, in the same
#                               `<ts> | ── … ──` shape subagent-lifecycle.sh
#                               writes, so one reader reads both.
#   status/ledger.jsonl         THE DURABLE AUDIT TRAIL UNDERNEATH, append-only,
#                               one line per transition and never more than one.
#                               It is not the interface: the interface is the
#                               status file the session reads without being asked.
#
# Every status write is ATOMIC — a temp file in the same directory, then mv — so
# a reader never sees half a record, and a SIGKILL mid-write cannot corrupt one.
#
# ------------------------------------------------------- READING IT BACK
#
# The records are written ONE KEY PER LINE in a fixed order so that a reader with
# neither jq nor python3 can parse them with shell builtins alone. The writer
# here and the reader in hooks/session-start-context.sh are a MATCHED PAIR: if
# you change the shape here, change it there, and the fixtures will tell you.
#
# --------------------------------------------- WHAT THESE RECORDS ARE NOT
#
# STATUS IS A CONVENIENCE VIEW. THE REPO IS THE TRUTH. The branch, the PR and
# the ledger are authoritative; a status record is a faster way to look at them
# and nothing more. This item makes status far MORE prominent — surfaced at
# SessionStart to every session that opens — and that is precisely when the
# assumption is worth restating: if anything ever starts trusting a status file
# over the repo, a single mis-addressed write stops being free. It has already
# happened once (GH #63): an executor clobbered a SIBLING EPIC's status.json and
# it cost nothing, because nobody was acting on it.
#
# TWO RULES FOLLOW, AND BOTH ARE IMPLEMENTED HERE RATHER THAN ADVISED.
#
#   THE TARGET PATH MUST BE VISIBLE AT THE CALL SITE. The clobber went through a
#   helper whose command line did not show the file it wrote. Correct resolution
#   and INVISIBLE resolution are independent properties and only the second one
#   causes that bug — so a helper that takes an epic-relative name and resolves
#   the path internally is the hazard HOWEVER CORRECT its resolution is. Here:
#   `intake_status_write` takes an already-resolved absolute path, resolves
#   nothing itself, refuses anything that is not a direct child of the tree this
#   process bound to, and LOGS the path it wrote. Every caller assigns the target
#   to a named variable on the line above the call.
#
#   THERE IS A DEFINED OUT-OF-BAND VALUE FOR "THIS RECORD IS UNTRUSTWORTHY":
#   `state: unknown` (INTAKE_STATUS_UNTRUSTED_STATE), deliberately outside the
#   milestone vocabulary so that nothing can read it as progress. A
#   wrong-but-plausible status is WORSE than an obviously-broken one, because a
#   reader acts on it. `intake_status_unknown` is how a writer says so, and it
#   overrides a terminal state rather than being blocked by one.
#
# IS A CYCLE STILL RUNNING? Two conditions, both builtins, no clock and no fork:
#   the recorded pid answers `kill -0`, AND the recorded lock directory exists.
# A cycle that finished normally says so in `state`. One killed with SIGTERM
# writes `interrupted` from its trap. One SIGKILLed writes nothing — traps do not
# run — so the reader infers it: a non-terminal state whose process is gone is
# INTERRUPTED, not finished. Requiring the lock too is what stops a RECYCLED pid
# reading as a live cycle; the lock is removed by the runner's own EXIT trap.

# The contract marker. A fixture suite for item 2 that is pointed at a tree
# predating item 2 must ABORT rather than pass, and this is what it greps for.
INTAKE_STATUS_CONTRACT=1

# The reserved directory name. One definition, consumed by the runner, the
# SessionStart hook's documentation and every fixture.
INTAKE_STATUS_RESERVED_DIR=".intake"

# Cycle state vocabulary, most to least advanced. `finished`, `failed`,
# `stopped` and `interrupted` are TERMINAL: a reader must not call them running.
# `unknown` is terminal too, and is NOT a milestone — see below.
INTAKE_STATUS_TERMINAL_STATES="finished failed stopped interrupted unknown"

# THE OUT-OF-BAND VALUE. Not a milestone, not a stage of progress, and on
# purpose not spellable as one: it means "do not trust this record". A reader
# must render it as a warning and never as a state the cycle reached. It is
# terminal so that a later, cheerier write cannot paper over it.
INTAKE_STATUS_UNTRUSTED_STATE="unknown"

# ------------------------------------------------------------------- state
INTAKE_STATUS_AVAILABLE=yes
INTAKE_STATUS_GIT="${INTAKE_STATUS_GIT:-${INTAKE_GIT:-/usr/bin/git}}"
INTAKE_STATUS_CYCLE_ID=""
INTAKE_STATUS_DIR=""
INTAKE_STATUS_ROOT=""
INTAKE_STATUS_REPO=""
INTAKE_STATUS_LOCK=""
INTAKE_STATUS_PID=$$
INTAKE_STATUS_STARTED=""
INTAKE_STATUS_STATE=""
INTAKE_STATUS_TOTAL=0
INTAKE_STATUS_DONE=0
INTAKE_STATUS_ISSUE=""
INTAKE_STATUS_LAST_ERROR=""
INTAKE_STATUS_TREE_OUT=""

intake_status_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '1970-01-01T00:00:00Z'; }

# A JSON string body: control characters folded to spaces or dropped, backslash
# and quote escaped. Issue titles are arbitrary human text and go straight into
# these records, so this is a boundary, not a nicety. Non-ASCII is preserved —
# an em dash in a title is not a hazard, an embedded newline is.
intake_status_escape() { # $1 = raw -> stdout
  printf '%s' "${1:-}" \
    | LC_ALL=C tr '\12\15\11' '   ' 2>/dev/null \
    | LC_ALL=C tr -d '\1-\10\13\14\16-\37\177' 2>/dev/null \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' 2>/dev/null
}

# A branch name as the control plane names its status file: `/` becomes `-`,
# exactly as an orchestrated executor's `<branch-slug>.json` is derived.
intake_status_branch_slug() { # $1 = branch -> stdout
  printf '%s' "${1:-}" | tr '/' '-' 2>/dev/null
}

# THE CANONICAL REPO ROOT — the main checkout, never a worktree. Resolved the way
# every control-plane hook resolves it, with the same two fallbacks, so a status
# file cannot land on a filesystem nobody watches.
intake_status_repo_root() { # $1 = a directory inside the repo -> stdout
  ISR_DIR="${1:-.}"
  ISR_ROOT="$("$INTAKE_STATUS_GIT" -C "$ISR_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$ISR_ROOT" ]; then
    ISR_ROOT="$(dirname "$ISR_ROOT" 2>/dev/null || true)"
  else
    ISR_ROOT="$("$INTAKE_STATUS_GIT" -C "$ISR_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  # Last resort: the directory we were handed. The runner only ever hands us a
  # checkout it has already verified is a git repo, so this is a degraded answer
  # rather than a wrong one — telemetry into the right repo, resolved the dumb
  # way, beats no telemetry at all.
  [ -n "$ISR_ROOT" ] && [ -d "$ISR_ROOT" ] || ISR_ROOT="$ISR_DIR"
  printf '%s' "$ISR_ROOT"
}

# Create (idempotently) the reserved status tree and put it in
# INTAKE_STATUS_TREE_OUT. Returns 1, with INTAKE_STATUS_TREE_OUT empty, if it
# cannot be created or if guarantee 2 has been violated.
#
# IT SETS A VARIABLE RATHER THAN ECHOING, and that is not a style choice: a
# `$( )` around this call is a SUBSHELL, and the refusal reason it writes to
# INTAKE_STATUS_LAST_ERROR would die with it. A control plane that refuses
# itself silently is exactly the failure this whole item is about — the caller
# would see an empty directory and no reason, which is the same information
# content as the flat log nobody read.
intake_status_tree() { # $1 = repo root, $2 = epics dir (repo-relative)
  INTAKE_STATUS_TREE_OUT=""
  IST_ROOT="${1:-}"
  IST_EPICS="${2:-docs/epics}"
  [ -n "$IST_ROOT" ] && [ -d "$IST_ROOT" ] || return 1
  case "$IST_EPICS" in ''|/*|*..*) IST_EPICS="docs/epics" ;; esac
  IST_BASE="$IST_ROOT/$IST_EPICS/$INTAKE_STATUS_RESERVED_DIR"
  IST_DIR="$IST_BASE/status"

  # GUARANTEE 2, ENFORCED RATHER THAN ASSUMED. A plan.md here would make the
  # tree a candidate epic the moment anything globs with dotglob set. If one
  # ever appears — dropped by hand, or by a future edit — REFUSE the tree
  # entirely rather than write telemetry into a directory that could steal a
  # live executor's. Losing telemetry is recoverable; GH #9 was not.
  if [ -e "$IST_BASE/plan.md" ]; then
    INTAKE_STATUS_LAST_ERROR="refusing $IST_BASE: it contains a plan.md, which would make the reserved intake tree resolvable as an epic"
    return 1
  fi
  mkdir -p "$IST_DIR" 2>/dev/null || return 1

  # The self-ignoring ignore file: `*` matches every path in this directory
  # INCLUDING this file, so git reports nothing here and the target checkout
  # stays clean. Written once; never rewritten, so a human may amend it.
  if [ ! -f "$IST_BASE/.gitignore" ]; then
    printf '*\n' > "$IST_BASE/.gitignore" 2>/dev/null || true
  fi
  if [ ! -f "$IST_BASE/README" ]; then
    {
      printf 'Unattended intake control plane — runtime telemetry, never committed.\n\n'
      printf 'THIS IS NOT AN EPIC. It is deliberately named with a leading dot and\n'
      printf 'deliberately contains no plan.md, so the active-epic resolver in\n'
      printf 'subagent-lifecycle.sh / subagent-tool-logger.sh can never select it\n'
      printf '(GH #9, GH #11). Do not put a plan.md here.\n\n'
      printf 'status/cycle.json          the cycle in flight, or the last one\n'
      printf 'status/<branch>.json       one record per issue drafted\n'
      printf 'status/agent-<cycle>.log   the agent-style log for one cycle\n'
      printf 'status/ledger.jsonl        append-only audit trail, one line per transition\n\n'
      printf 'STATUS IS A CONVENIENCE VIEW. THE REPO IS THE TRUTH: the branches, the\n'
      printf 'pull requests and ledger.jsonl are authoritative, and these records are a\n'
      printf 'faster way to look at them. A record reading "state": "unknown" is saying\n'
      printf 'it cannot be trusted; go and read the repo.\n'
    } > "$IST_BASE/README" 2>/dev/null || true
  fi
  INTAKE_STATUS_TREE_OUT="$IST_DIR"
  return 0
}

# Atomic write: temp file beside the target, then mv. Never leaves a partial
# record for a reader, and never leaves the temp file behind on failure.
intake_status_atomic() { # $1 = target path; body on stdin
  ISA_T="${1:-}"
  [ -n "$ISA_T" ] || return 1
  ISA_TMP="$ISA_T.tmp.$$"
  cat > "$ISA_TMP" 2>/dev/null || { rm -f "$ISA_TMP" 2>/dev/null; return 1; }
  mv "$ISA_TMP" "$ISA_T" 2>/dev/null || { rm -f "$ISA_TMP" 2>/dev/null; return 1; }
  return 0
}

# One line in the agent-style log, in exactly the shape subagent-lifecycle.sh
# uses, so a human (or a tool) reading agent-*.log reads both without a second
# format. Best-effort; a missing tree is silence, not an error.
intake_status_log() { # $1 = text
  [ -n "$INTAKE_STATUS_DIR" ] || return 0
  [ -n "$INTAKE_STATUS_CYCLE_ID" ] || return 0
  printf '%s | %s\n' "$(intake_status_now)" "${1:-}" \
    >> "$INTAKE_STATUS_DIR/agent-$INTAKE_STATUS_CYCLE_ID.log" 2>/dev/null || true
  return 0
}

# THE WRITE GUARD, and the invariant it enforces is NOT "validate the payload"
# (GH #63). It is: THE TARGET PATH MUST BE VISIBLE AT THE CALL SITE. This
# function resolves NOTHING — the caller hands it an absolute path it computed
# into a named variable one line above — and it refuses any target that is not a
# direct child of the tree this process bound to at intake_status_open. So a
# record can never land in an epic's status tree, a sibling repo, or anywhere
# else: the class of bug is structurally unavailable rather than avoided by care.
# It also LOGS the path it wrote, which is the only place that can be forgotten
# and therefore the only place it belongs.
#
# THE BODY IS AN ARGUMENT, NOT STDIN, and that is not a style choice either.
# `printf … | intake_status_write "$T"` runs the FUNCTION in a subshell, so
# every global it sets — INTAKE_STATUS_LAST_ERROR above all — dies with the
# pipeline and a refusal becomes a silent one. Records are a few hundred bytes;
# an argument costs nothing and keeps the reason for a refusal alive in the
# process that has to report it.
intake_status_write() { # $1 = RESOLVED absolute target path, $2 = record body
  ISW_T="${1:-}"
  # Unbound reporter: an empty INTAKE_STATUS_DIR would make the prefix test `/*`
  # and admit every absolute path on the machine. Refuse before comparing.
  if [ -z "$INTAKE_STATUS_DIR" ] || [ -z "$ISW_T" ]; then
    INTAKE_STATUS_LAST_ERROR="refused a status write with no bound control plane"
    return 1
  fi
  ISW_REL="${ISW_T#"$INTAKE_STATUS_DIR"/}"
  case "$ISW_T" in "$INTAKE_STATUS_DIR"/*) ;; *) ISW_REL="" ;; esac
  case "$ISW_REL" in
    ''|*/*|.|..|*..*)
      INTAKE_STATUS_LAST_ERROR="refused a status write to [$ISW_T]: not a direct child of the bound control plane [$INTAKE_STATUS_DIR]"
      intake_status_log "REFUSED a status write to $ISW_T — outside $INTAKE_STATUS_DIR"
      return 1 ;;
  esac
  printf '%s\n' "${2:-}" | intake_status_atomic "$ISW_T" || {
    INTAKE_STATUS_LAST_ERROR="could not write $ISW_T"
    intake_status_log "FAILED to write $ISW_T"
    return 1
  }
  intake_status_log "wrote $ISW_T"
  return 0
}

# THE LEDGER — one line per transition, appended, never rewritten. Called from
# exactly one place per transition (the two reporters below) so "exactly once"
# is a property of the call graph rather than a hope.
intake_status_ledger() { # $1 = kind (cycle|issue), $2 = state, $3 = detail, $4 = issue ("" for cycle)
  [ -n "$INTAKE_STATUS_DIR" ] || return 0
  ISL_ISSUE="${4:-}"
  case "$ISL_ISSUE" in ''|*[!0-9]*) ISL_ISSUE=null ;; esac
  printf '{"ts":"%s","cycle":"%s","repo":"%s","kind":"%s","state":"%s","issue":%s,"detail":"%s"}\n' \
    "$(intake_status_now)" \
    "$(intake_status_escape "$INTAKE_STATUS_CYCLE_ID")" \
    "$(intake_status_escape "$INTAKE_STATUS_REPO")" \
    "$(intake_status_escape "${1:-}")" \
    "$(intake_status_escape "${2:-}")" \
    "$ISL_ISSUE" \
    "$(intake_status_escape "${3:-}")" \
    >> "$INTAKE_STATUS_DIR/ledger.jsonl" 2>/dev/null || true
  return 0
}

# Bind this process to a repo's control plane. Called once per repo, after the
# repo's epics directory has been resolved from the repo itself. Returns 0 even
# when it could not open the tree — the caller must never branch on telemetry.
intake_status_open() { # $1 = repo dir, $2 = repo slug, $3 = epics dir, $4 = lock dir
  INTAKE_STATUS_DIR=""
  INTAKE_STATUS_REPO="${2:-}"
  INTAKE_STATUS_LOCK="${4:-}"
  INTAKE_STATUS_TOTAL=0
  INTAKE_STATUS_DONE=0
  INTAKE_STATUS_ISSUE=""
  INTAKE_STATUS_STATE=""
  [ -n "$INTAKE_STATUS_CYCLE_ID" ] || \
    INTAKE_STATUS_CYCLE_ID="$(intake_status_now | tr -d ':-' )-$INTAKE_STATUS_PID"
  [ -n "$INTAKE_STATUS_STARTED" ] || INTAKE_STATUS_STARTED="$(intake_status_now)"
  INTAKE_STATUS_ROOT="$(intake_status_repo_root "${1:-.}")"
  # NOT in a $( ): see intake_status_tree. The refusal reason has to survive.
  intake_status_tree "$INTAKE_STATUS_ROOT" "${3:-docs/epics}" || return 0
  [ -n "$INTAKE_STATUS_TREE_OUT" ] || return 0
  INTAKE_STATUS_DIR="$INTAKE_STATUS_TREE_OUT"
  intake_status_log "── INTAKE CYCLE START ($INTAKE_STATUS_CYCLE_ID, unattended-intake) on $INTAKE_STATUS_REPO ──"
  return 0
}

# Is this reporter bound to a control plane at all?
intake_status_active() { [ -n "$INTAKE_STATUS_DIR" ]; }

intake_status_is_terminal() { # $1 = state
  case " $INTAKE_STATUS_TERMINAL_STATES " in *" ${1:-} "*) return 0 ;; esac
  return 1
}

# THE CYCLE RECORD. status.json-shaped first — item, branch, state, detail,
# commit, updated, in that order, because that is the contract a reader of an
# executor's status file already knows — then the cycle facts.
#
# `branch` is null and `commit` is null, always and on purpose: a drafting cycle
# is not on a branch and has no HEAD of its own. Writing a plausible branch there
# would be the same class of lie as a plausible-but-wrong plan header.
intake_status_cycle() { # $1 = state, $2 = detail
  intake_status_active || return 0
  ISC_STATE="${1:-}"
  ISC_DETAIL="${2:-}"
  INTAKE_STATUS_STATE="$ISC_STATE"
  ISC_FIN=null
  intake_status_is_terminal "$ISC_STATE" && ISC_FIN="\"$(intake_status_now)\""
  ISC_ISSUE="${INTAKE_STATUS_ISSUE:-}"
  case "$ISC_ISSUE" in ''|*[!0-9]*) ISC_ISSUE=null ;; esac
  ISC_QUEUED=$(( INTAKE_STATUS_TOTAL - INTAKE_STATUS_DONE ))
  [ "$ISC_QUEUED" -ge 0 ] || ISC_QUEUED=0
  ISC_TARGET="$INTAKE_STATUS_DIR/cycle.json"      # resolved HERE, visible HERE
  ISC_BODY="$( {
    printf '{\n'
    printf '  "item": "unattended intake cycle %s",\n' "$(intake_status_escape "$INTAKE_STATUS_CYCLE_ID")"
    printf '  "branch": null,\n'
    printf '  "state": "%s",\n'   "$(intake_status_escape "$ISC_STATE")"
    printf '  "detail": "%s",\n'  "$(intake_status_escape "$ISC_DETAIL")"
    printf '  "commit": null,\n'
    printf '  "updated": "%s",\n' "$(intake_status_now)"
    printf '  "runner": "unattended-intake",\n'
    printf '  "cycle": "%s",\n'   "$(intake_status_escape "$INTAKE_STATUS_CYCLE_ID")"
    printf '  "repo": "%s",\n'    "$(intake_status_escape "$INTAKE_STATUS_REPO")"
    printf '  "pid": %s,\n'       "$INTAKE_STATUS_PID"
    printf '  "lock": "%s",\n'    "$(intake_status_escape "$INTAKE_STATUS_LOCK")"
    printf '  "issue": %s,\n'     "$ISC_ISSUE"
    printf '  "total": %s,\n'     "$INTAKE_STATUS_TOTAL"
    printf '  "done": %s,\n'      "$INTAKE_STATUS_DONE"
    printf '  "queued": %s,\n'    "$ISC_QUEUED"
    printf '  "started": "%s",\n' "$(intake_status_escape "$INTAKE_STATUS_STARTED")"
    printf '  "finished": %s,\n'  "$ISC_FIN"
    printf '  "log": "agent-%s.log"\n' "$(intake_status_escape "$INTAKE_STATUS_CYCLE_ID")"
    printf '}'
  } )"
  intake_status_write "$ISC_TARGET" "$ISC_BODY" || true
  intake_status_log "cycle $ISC_STATE — $ISC_DETAIL"
  intake_status_ledger cycle "$ISC_STATE" "$ISC_DETAIL" ""
  return 0
}

# THE PER-ISSUE RECORD, named exactly as an executor's status file is named.
intake_status_issue() { # $1 = issue, $2 = branch, $3 = state, $4 = detail, $5 = recommendation
  intake_status_active || return 0
  ISI_N="${1:-}"
  ISI_BRANCH="${2:-}"
  ISI_SLUG="$(intake_status_branch_slug "$ISI_BRANCH")"
  [ -n "$ISI_SLUG" ] || ISI_SLUG="issue-$ISI_N"
  ISI_NUM="$ISI_N"
  case "$ISI_NUM" in ''|*[!0-9]*) ISI_NUM=null ;; esac
  ISI_BR=null
  [ -n "$ISI_BRANCH" ] && ISI_BR="\"$(intake_status_escape "$ISI_BRANCH")\""
  ISI_REFUSED=no
  ISI_TARGET="$INTAKE_STATUS_DIR/$ISI_SLUG.json"   # resolved HERE, visible HERE
  ISI_BODY="$( {
    printf '{\n'
    printf '  "item": "intake #%s",\n'  "$(intake_status_escape "$ISI_N")"
    printf '  "branch": %s,\n'          "$ISI_BR"
    printf '  "state": "%s",\n'         "$(intake_status_escape "${3:-}")"
    printf '  "detail": "%s",\n'        "$(intake_status_escape "${4:-}")"
    printf '  "commit": null,\n'
    printf '  "updated": "%s",\n'       "$(intake_status_now)"
    printf '  "runner": "unattended-intake",\n'
    printf '  "cycle": "%s",\n'         "$(intake_status_escape "$INTAKE_STATUS_CYCLE_ID")"
    printf '  "repo": "%s",\n'          "$(intake_status_escape "$INTAKE_STATUS_REPO")"
    printf '  "issue": %s,\n'           "$ISI_NUM"
    printf '  "recommendation": "%s"\n' "$(intake_status_escape "${5:-}")"
    printf '}'
  } )"
  intake_status_write "$ISI_TARGET" "$ISI_BODY" || ISI_REFUSED=yes
  intake_status_log "#$ISI_N ${3:-} — ${4:-}"
  intake_status_ledger issue "${3:-}" "${4:-}" "$ISI_N"
  # A refused or failed write means the per-issue record on disk is NOT what
  # just happened. Saying nothing would leave a stale record reading as current,
  # which is the wrong-but-plausible failure exactly. Say so, out of band.
  if [ "$ISI_REFUSED" = yes ]; then
    intake_status_unknown "a record for #$ISI_N could not be written (${INTAKE_STATUS_LAST_ERROR:-unknown reason}); the per-issue records in this tree may be stale — the branches, the PRs and ledger.jsonl are the truth"
  fi
  return 0
}

# SAY THE RECORD CANNOT BE TRUSTED, in the one value that cannot be mistaken for
# progress (GH #63). Deliberately NOT a milestone: a reader that does not know
# this word must still fail to read it as a stage of a healthy cycle. It writes
# over a terminal state on purpose — "untrustworthy" is later news than
# "finished", and a plausible record is the thing being prevented.
intake_status_unknown() { # $1 = why
  intake_status_active || return 0
  intake_status_cycle "$INTAKE_STATUS_UNTRUSTED_STATE" "${1:-the record for this cycle is not trustworthy}"
  return 0
}

# Close the cycle. Called from the runner's own exit path AND from its trap, so
# it must be idempotent: a record already in a terminal state is left exactly as
# it is rather than overwritten with a second, later, less true one.
intake_status_close() { # $1 = state, $2 = detail
  intake_status_active || return 0
  intake_status_is_terminal "$INTAKE_STATUS_STATE" && return 0
  intake_status_cycle "${1:-finished}" "${2:-}"
  intake_status_log "── INTAKE CYCLE END ($INTAKE_STATUS_CYCLE_ID) — ${1:-finished} ──"
  return 0
}
