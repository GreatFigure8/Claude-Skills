#!/usr/bin/env bash
# SubagentStart / SubagentStop hook — dev-epic-workflow executor lifecycle.
#
# SubagentStart: create a marker in .claude/signals/ (arms the cancel gate),
#                record an owner record for the agent, and open a bracket line
#                in that agent's status log.
# SubagentStop:  remove the marker(s), close the bracket in the SAME log file,
#                and stamp terminal:true ONLY on the status.json this agent
#                actually owns, so a stuck task-list UI can never masquerade as
#                "still running" — and an unrelated stop can never declare
#                someone else's item finished.
#
# Three defects this hook used to have (GH #5), and what replaced them:
#
# 1. UNOWNED STAMPING. It resolved status.json from the *current branch* and
#    stamped terminal:true with no check that the stopping agent owned it. Epic
#    01 saw three SUBAGENT STOP brackets against one START, two from agents that
#    never started, while the real executor was still working. Now: SubagentStart
#    writes status/.agents/<agent-id>.json, and SubagentStop stamps only files
#    whose "agent_id" is this agent (see OWNERSHIP below). A stop from an agent
#    with no start record stamps nothing, ever.
#
# 2. SPLIT BRACKET PAIR. The log path came from the live branch and the executor
#    branches at step 2 of every item, so START landed in <orchestrator-branch>.log
#    and STOP in another file — the pair was never co-located in normal operation.
#    Now the log is status/agent-<agent-id>.log: one file per agent life, immune
#    to branch changes.
#
# 3. TWO FILESYSTEMS. Under worktree dispatch the executor wrote status/ inside
#    its worktree while hooks wrote status/ in the orchestrator's checkout, so
#    SubagentStop looked for a file that did not exist and terminal was never
#    stamped at all. Now every path is resolved from the CANONICAL repo root —
#    the parent of `git rev-parse --git-common-dir`, which is the main checkout
#    from inside any linked worktree — so hooks and executors write one place.
#
# OWNERSHIP (how a status.json gets bound to an agent):
#   a. subagent-tool-logger.sh claims a status file for the calling agent when
#      that agent's own tool call names it (the executor's status write does).
#   b. Failing that, SubagentStop claims unowned status files that were modified
#      after this agent started — but only when this agent is the ONLY live
#      executor, so concurrent worktree executors can never inherit each other's
#      item. Unbindable is stamped as nothing: Layer 3 then falls back to origin.
#
# Marker files stay project-dir relative (.claude/signals/) because cancel-gate.sh
# reads them from there; only status/ moves to the canonical root, because that is
# the tree the executor also writes.
#
# The repo decides, not the sidebar: reconciliation lives on disk.
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"

# ------------------------------------------------------------------ parse ----
# jq → python3 → parser-free grep/sed, so the hook is correct with neither
# installed (same three-tier shape as cancel-gate.sh / subagent-tool-logger.sh).
PARSER="raw"
if command -v jq > /dev/null 2>&1; then PARSER="jq"
elif command -v python3 > /dev/null 2>&1; then PARSER="py"; fi

field() { # $1 = top-level string key of the hook input
  [ -n "$INPUT" ] || return 0
  case "$PARSER" in
    jq) printf '%s' "$INPUT" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null || true ;;
    py) printf '%s' "$INPUT" | HOOK_KEY="$1" python3 -c 'import json,os,sys
try: print(json.load(sys.stdin).get(os.environ["HOOK_KEY"]) or "")
except Exception: pass' 2>/dev/null || true ;;
    *)  # Only trust the raw path on a payload that opens and closes as an
        # object; the (^|[{,]) anchor rejects an escaped key inside a value.
        RAW="${INPUT%"${INPUT##*[![:space:]]}"}"
        case "$RAW" in
          '{'*'}') printf '%s' "$RAW" \
             | grep -oE "(^|[{,])[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null \
             | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' 2>/dev/null || true ;;
        esac ;;
  esac
}

EVENT="$(field hook_event_name)"
AGENT_ID="$(field agent_id)"
[ -n "$AGENT_ID" ] || AGENT_ID="$(field session_id)"
[ -n "$AGENT_ID" ] || AGENT_ID="unknown-$$"
# Same sanitisation cancel-gate.sh applies to selectors and subagent-tool-logger.sh
# applies to log names, so marker, log, owner record and selector all agree.
AGENT_ID="$(printf '%s' "$AGENT_ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64)"
AGENT_TYPE="$(field agent_type | tr -c 'A-Za-z0-9._ -' '-' | cut -c1-40)"

case "$EVENT" in SubagentStart|SubagentStop) ;; *) exit 0 ;; esac

# ------------------------------------------------------------------ paths ----
SIGNALS_DIR=".claude/signals"          # project-dir relative: cancel-gate.sh reads here
mkdir -p "$SIGNALS_DIR" 2>/dev/null || exit 0
MARKER="$SIGNALS_DIR/subagent-active-$AGENT_ID"

# Canonical repo root: from inside a linked worktree --git-common-dir still points
# at the MAIN checkout's .git, so every agent resolves the same status tree.
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ]; then
  REPO_ROOT="$(dirname "$REPO_ROOT" 2>/dev/null || true)"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] || REPO_ROOT="$(pwd)"

EPIC_PLAN="$(ls -t "$REPO_ROOT"/docs/epics/*/plan.md 2>/dev/null | head -1)"
STATUS_DIR=""
if [ -n "$EPIC_PLAN" ]; then
  STATUS_DIR="$(dirname "$EPIC_PLAN")/status"
  mkdir -p "$STATUS_DIR/.agents" 2>/dev/null || STATUS_DIR=""
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
[ -n "$BRANCH" ] || BRANCH="detached"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="$STATUS_DIR/agent-$AGENT_ID.log"
OWNER_REC="$STATUS_DIR/.agents/$AGENT_ID.json"

# ------------------------------------------------------------- json edits ----
# Small, dependency-free edits to a status.json the executor owns. Preference is
# python3 → jq → a parser-free insert, so the invariant "correct with jq absent
# and python3 absent" holds for stamping too (it used to silently no-op).
json_has() { grep -q "\"$2\"[[:space:]]*:" "$1" 2>/dev/null; }

json_owner() { # echo the recorded owner agent id of a status file, or nothing
  grep -oE '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' 2>/dev/null || true
}

sh_insert() { # $1 = file, $2 = raw JSON fragment ending in a comma
  FIRST="$(sed -n '1p' "$1" 2>/dev/null || true)"
  case "$FIRST" in '{'*) ;; *) return 1 ;; esac
  grep -q '"' "$1" 2>/dev/null || return 1     # need at least one existing key
  TMP="$1.tmp.$$"
  { printf '{\n  %s\n' "$2"; sed '1s/^{//' "$1"; } > "$TMP" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; return 1; }
  mv "$TMP" "$1" 2>/dev/null || { rm -f "$TMP" 2>/dev/null; return 1; }
}

json_claim() { # $1 = status file, $2 = agent id
  if command -v python3 > /dev/null 2>&1; then
    python3 - "$1" "$2" << 'PYEOF' 2>/dev/null && return 0
import json, sys, os, tempfile
path, agent = sys.argv[1], sys.argv[2]
try:
    with open(path) as f: d = json.load(f)
except Exception: sys.exit(1)
if not isinstance(d, dict): sys.exit(1)
d["agent_id"] = agent
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2); f.write("\n")
os.replace(tmp, path)
PYEOF
  fi
  if command -v jq > /dev/null 2>&1; then
    TMP="$1.tmp.$$"
    if jq --arg id "$2" '. + {agent_id: $id}' "$1" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
      mv "$TMP" "$1" 2>/dev/null && return 0
    fi
    rm -f "$TMP" 2>/dev/null
  fi
  sh_insert "$1" "\"agent_id\": \"$2\","
}

json_terminal() { # $1 = status file, $2 = timestamp
  json_has "$1" terminal && return 0                 # already stamped: idempotent
  if command -v python3 > /dev/null 2>&1; then
    python3 - "$1" "$2" << 'PYEOF' 2>/dev/null && return 0
import json, sys, os, tempfile
path, now = sys.argv[1], sys.argv[2]
try:
    with open(path) as f: d = json.load(f)
except Exception: sys.exit(1)
if not isinstance(d, dict): sys.exit(1)
d["terminal"] = True
d["updated"] = now
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2); f.write("\n")
os.replace(tmp, path)
PYEOF
  fi
  if command -v jq > /dev/null 2>&1; then
    TMP="$1.tmp.$$"
    if jq --arg t "$2" '. + {terminal: true, updated: $t}' "$1" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
      mv "$TMP" "$1" 2>/dev/null && return 0
    fi
    rm -f "$TMP" 2>/dev/null
  fi
  # Parser-free last resort: insert the key, leave "updated" as the executor left it.
  sh_insert "$1" '"terminal": true,'
}

# ----------------------------------------------------------------- events ----
case "$EVENT" in
  SubagentStart)
    : > "$MARKER" 2>/dev/null || true
    if [ -n "$STATUS_DIR" ]; then
      # The owner record is also the start timestamp: SubagentStop compares
      # status-file mtimes against it with find -newer.
      printf '{\n  "agent_id": "%s",\n  "agent_type": "%s",\n  "started": "%s",\n  "start_branch": "%s",\n  "log": "%s"\n}\n' \
        "$AGENT_ID" "$AGENT_TYPE" "$NOW" "$BRANCH" "agent-$AGENT_ID.log" \
        > "$OWNER_REC" 2>/dev/null || true
      echo "$NOW | ── SUBAGENT START ($AGENT_ID${AGENT_TYPE:+, $AGENT_TYPE}) on branch $BRANCH ──" \
        >> "$LOG" 2>/dev/null || true
    fi
    ;;

  SubagentStop)
    NOTE="nothing stamped"
    if [ -n "$STATUS_DIR" ]; then
      # Did this agent ever start? Owner record, or (belt and braces) its marker.
      START_REF=""
      [ -f "$OWNER_REC" ] && START_REF="$OWNER_REC"
      [ -z "$START_REF" ] && [ -f "$MARKER" ] && START_REF="$MARKER"

      if [ -z "$START_REF" ]; then
        NOTE="no SubagentStart record for this agent; nothing stamped"
      else
        # Sole live executor? (our own marker counted; check before removing it)
        LIVE=0
        for M in "$SIGNALS_DIR"/subagent-active-*; do
          [ -f "$M" ] && LIVE=$((LIVE + 1))
        done
        [ -f "$MARKER" ] || LIVE=$((LIVE + 1))     # count ourselves even if the marker is gone
        SOLE=no; [ "$LIVE" -le 1 ] && SOLE=yes

        STAMPED=""
        for F in "$STATUS_DIR"/*.json; do
          [ -f "$F" ] || continue
          OWNER="$(json_owner "$F")"
          if [ "$OWNER" = "$AGENT_ID" ]; then
            json_terminal "$F" "$NOW" && STAMPED="$STAMPED $(basename "$F")"
          elif [ -z "$OWNER" ] && [ "$SOLE" = "yes" ] \
               && [ -n "$(find "$F" -newer "$START_REF" 2>/dev/null || true)" ]; then
            # Unowned, written during this agent's life, and no other executor
            # was live: it is ours. Record the binding, then stamp.
            if json_claim "$F" "$AGENT_ID"; then
              json_terminal "$F" "$NOW" && STAMPED="$STAMPED $(basename "$F")"
            fi
          fi
        done

        if [ -n "$STAMPED" ]; then
          NOTE="stamped terminal:$STAMPED"
        elif [ "$SOLE" = "yes" ]; then
          NOTE="no status file owned by this agent; nothing stamped"
        else
          NOTE="no owned status file and other executors are live; nothing stamped"
        fi
      fi

      echo "$NOW | ── SUBAGENT STOP  ($AGENT_ID) on branch $BRANCH — $NOTE ──" \
        >> "$LOG" 2>/dev/null || true
    fi

    rm -f "$MARKER" 2>/dev/null || true
    # Belt-and-braces: clear stale markers older than a day so a crashed run
    # can't leave the cancel gate armed forever.
    find "$SIGNALS_DIR" -name 'subagent-active-*' -mmin +1440 -delete 2>/dev/null || true
    ;;
esac

exit 0
