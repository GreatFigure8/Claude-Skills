#!/usr/bin/env bash
# PostToolUse hook — dev-epic-workflow executor telemetry.
#
# Append one compact line per SUBAGENT tool call to that agent's log:
# docs/epics/<NN>-<slug>/status/agent-<agent-id>.log
#
# This is the deterministic progress stream — it does not depend on the model
# choosing to report anything. Tail it live:
#   tail -f docs/epics/<NN>-<slug>/status/agent-*.log
#
# Attribution is per call, not per session: PostToolUse input carries
# `agent_id` ONLY inside a subagent call, so its absence identifies the
# orchestrator / main session and nothing is written. The
# .claude/signals/subagent-active-* markers are not consulted — a marker only
# proves that some subagent is running, so orchestrator calls made while an
# executor was armed used to be logged as executor activity (GH #2). The
# markers stay in place; subagent-lifecycle.sh still owns them.
#
# The log path is keyed on the AGENT, not on the branch (GH #5). The executor
# branches at step 2 of every item, so a branch-derived path split each agent's
# stream across files and put its START and STOP brackets in different ones.
# It is also resolved from the CANONICAL repo root — the parent of
# `git rev-parse --git-common-dir`, i.e. the main checkout even when this runs
# inside a linked worktree — so hooks and the executor write one status tree.
#
# Ownership side-effect: when a subagent's own tool call names a status.json in
# that tree and the file records no owner yet, this hook records the caller as
# its owner. That binding is what lets SubagentStop stamp terminal:true on the
# right item and only on the right item, including when several worktree
# executors run at once.
#
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# Fast path: no agent_id anywhere in the payload → main session → log nothing.
# Cheap pre-filter only; an escaped occurrence inside a tool argument is
# rejected by the real extraction below.
case "$INPUT" in
  *'"agent_id"'*) ;;
  *) exit 0 ;;
esac

# Confirm it with a real parse: jq, python3 fallback, then a parser-free
# grep/sed fallback. The (^|[{,]) anchor stops an escaped \"agent_id\" inside
# tool_input from matching. Unparseable → treat as main session → log nothing.
AGENT_ID=""
if command -v jq > /dev/null 2>&1; then
  AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
elif command -v python3 > /dev/null 2>&1; then
  AGENT_ID="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("agent_id") or "")
except Exception: pass' 2>/dev/null || true)"
else
  # Only trust this path on a payload that at least opens and closes as an
  # object; a truncated one yields no id, so malformed input still fails open.
  RAW="${INPUT%"${INPUT##*[![:space:]]}"}"
  case "$RAW" in
    '{'*'}')
      AGENT_ID="$(printf '%s' "$RAW" \
        | grep -oE '(^|[{,])[[:space:]]*"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
        | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' 2>/dev/null || true)" ;;
  esac
fi
[ -n "$AGENT_ID" ] || exit 0

# Same sanitisation subagent-lifecycle.sh applies, so the bracket lines and the
# tool lines for one agent land in the same file.
AGENT_ID="$(printf '%s' "$AGENT_ID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64 2>/dev/null || true)"
[ -n "$AGENT_ID" ] || exit 0

# Canonical repo root (main checkout, even from inside a linked worktree).
REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ]; then
  REPO_ROOT="$(dirname "$REPO_ROOT" 2>/dev/null || true)"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] || REPO_ROOT="$(pwd)"

# ------------------------------------------------------------------ epic ----
# --- BEGIN active-epic resolution (identical block in subagent-lifecycle.sh
# --- and subagent-tool-logger.sh; drift between them is a fixture failure) ---
#
# Which epic is in flight, in order:
#   (a) the explicit pointer $REPO_ROOT/.claude/signals/active-epic — epic folder
#       name, repo-relative path, or absolute path — when it names a real epic
#       directory. The orchestrator writes it at dispatch setup (Phase 3 step 2)
#       and removes it at epic close (Phase 5).
#   (b) otherwise the newest plan.md whose "**Status:**" line is NOT closed.
#   (c) otherwise nothing: the caller degrades to silence and exits 0.
#
# It used to be bare mtime — "whichever plan.md was touched last" — which is not
# "the epic in flight". Editing a CLOSED epic's plan is a legitimate act (a retro
# correction), and doing it during epic 02 redirected a live executor's telemetry
# into closed epic 01: two SUBAGENT STOP brackets landed there while the real
# epic's own bracket landed two minutes later, one dispatch split across two epic
# folders (GH #9). Hence: an explicit signal first, and a fallback that can never
# choose a closed epic.
#
# A plan with no parseable Status: line counts as OPEN — fail toward writing
# telemetry, never toward silently losing it. The pointer is read relative to
# REPO_ROOT (the canonical checkout), not CLAUDE_PROJECT_DIR, so the hooks stay
# correct when an executor runs from inside a linked worktree.
#
# Tools used here are only those the parser-free fixture variant provides
# (head/grep/sed/ls plus shell builtins): no jq, no python3, no awk, bash 3.2.

plan_is_open() { # $1 = plan.md path; false ONLY when its Status line reads closed
  EPIC_STATE="$(head -10 "$1" 2>/dev/null | grep '^\*\*Status:\*\*' 2>/dev/null \
                 | head -1 | sed 's/^\*\*Status:\*\*[[:space:]]*//' 2>/dev/null || true)"
  EPIC_STATE="${EPIC_STATE%%[[:space:]]*}"          # first word; also drops a trailing \r
  case "$EPIC_STATE" in closed|Closed|CLOSED) return 1 ;; *) return 0 ;; esac
}

resolve_epic_dir() { # echo the epic folder in flight, or nothing at all
  # (a) explicit pointer: first non-blank, non-comment line.
  EPIC_POINTER="$REPO_ROOT/.claude/signals/active-epic"
  EPIC_PTR=""
  if [ -f "$EPIC_POINTER" ] && [ -r "$EPIC_POINTER" ]; then
    EPIC_LINE=""
    while IFS= read -r EPIC_LINE || [ -n "$EPIC_LINE" ]; do
      EPIC_LINE="${EPIC_LINE%"${EPIC_LINE##*[![:space:]]}"}"   # rtrim (drops \r too)
      EPIC_LINE="${EPIC_LINE#"${EPIC_LINE%%[![:space:]]*}"}"   # ltrim
      case "$EPIC_LINE" in ''|'#'*) continue ;; esac
      EPIC_PTR="$EPIC_LINE"; break
    done 2>/dev/null < "$EPIC_POINTER"
  fi
  case "$EPIC_PTR" in
    ''|*..*) EPIC_PTR="" ;;        # empty, or a path escaping the repo: ignore it
  esac
  if [ -n "$EPIC_PTR" ]; then
    EPIC_PTR="${EPIC_PTR%/}"; EPIC_PTR="${EPIC_PTR%/plan.md}"; EPIC_PTR="${EPIC_PTR%/}"
    case "$EPIC_PTR" in
      /*)  EPIC_CAND="$EPIC_PTR" ;;                          # absolute path
      */*) EPIC_CAND="$REPO_ROOT/$EPIC_PTR" ;;               # repo-relative path
      *)   EPIC_CAND="$REPO_ROOT/docs/epics/$EPIC_PTR" ;;    # bare epic folder name
    esac
    if [ -d "$EPIC_CAND" ]; then printf '%s' "$EPIC_CAND"; return 0; fi
    # Pointer names nothing that exists (deleted epic, typo): fall through to (b).
  fi
  # (b) newest plan.md that is not closed. ls -t is newest-first, so the first
  #     open plan wins and closed epics are never selected at all.
  ls -t "$REPO_ROOT"/docs/epics/*/plan.md 2>/dev/null | while IFS= read -r EPIC_P; do
    [ -f "$EPIC_P" ] || continue
    plan_is_open "$EPIC_P" || continue
    printf '%s' "${EPIC_P%/plan.md}"
    break
  done
  # (c) nothing resolvable: print nothing.
}

EPIC_DIR="$(resolve_epic_dir)"
# --- END active-epic resolution ---

[ -n "$EPIC_DIR" ] || exit 0
STATUS_DIR="$EPIC_DIR/status"
mkdir -p "$STATUS_DIR" 2>/dev/null || exit 0
LOG="$STATUS_DIR/agent-$AGENT_ID.log"

# ------------------------------------------------------- ownership claim ----
# Bind a status.json to this agent when the agent's own call names it. Only
# unowned files, only files touched during this agent's life, and only for an
# agent that actually started (owner record or marker). Pure-shell test first:
# no subprocess at all on the overwhelming majority of calls.
START_REF=""
[ -f "$STATUS_DIR/.agents/$AGENT_ID.json" ] && START_REF="$STATUS_DIR/.agents/$AGENT_ID.json"
[ -z "$START_REF" ] && [ -f ".claude/signals/subagent-active-$AGENT_ID" ] \
  && START_REF=".claude/signals/subagent-active-$AGENT_ID"

if [ -n "$START_REF" ]; then
  for F in "$STATUS_DIR"/*.json; do
    [ -f "$F" ] || continue
    BASE="${F##*/}"
    case "$INPUT" in *"$BASE"*) ;; *) continue ;; esac
    grep -q '"agent_id"[[:space:]]*:' "$F" 2>/dev/null && continue      # already owned
    [ -n "$(find "$F" -newer "$START_REF" 2>/dev/null || true)" ] || continue
    if command -v python3 > /dev/null 2>&1; then
      python3 - "$F" "$AGENT_ID" << 'PYEOF' 2>/dev/null && continue
import json, sys, os, tempfile
path, agent = sys.argv[1], sys.argv[2]
try:
    with open(path) as f: d = json.load(f)
except Exception: sys.exit(1)
if not isinstance(d, dict): sys.exit(1)
d["agent_id"] = agent
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
os.replace(tmp, path)
PYEOF
    fi
    if command -v jq > /dev/null 2>&1; then
      TMP="$F.tmp.$$"
      if jq --arg id "$AGENT_ID" '. + {agent_id: $id}' "$F" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
        mv "$TMP" "$F" 2>/dev/null && continue
      fi
      rm -f "$TMP" 2>/dev/null
    fi
    # Parser-free insert, guarded: object must open with { and hold a key.
    FIRST="$(sed -n '1p' "$F" 2>/dev/null || true)"
    case "$FIRST" in '{'*) ;; *) continue ;; esac
    grep -q '"' "$F" 2>/dev/null || continue
    TMP="$F.tmp.$$"
    { printf '{\n  "agent_id": "%s",\n' "$AGENT_ID"; sed '1s/^{//' "$F"; } > "$TMP" 2>/dev/null \
      && mv "$TMP" "$F" 2>/dev/null
    rm -f "$TMP" 2>/dev/null
  done
fi

# ------------------------------------------------------------- log line ----
LINE=""
if command -v jq > /dev/null 2>&1; then
  LINE="$(printf '%s' "$INPUT" | jq -r '
    def trunc(n): tostring | if length > n then .[:n] + "…" else . end;
    [ (now | todate),
      (.tool_name // "?"),
      ( .tool_input // {} |
        ( .command // .file_path // .path // .pattern // .query // "" ) | trunc(120) )
    ] | join(" | ")' 2>/dev/null || true)"
elif command -v python3 > /dev/null 2>&1; then
  LINE="$(printf '%s' "$INPUT" | python3 -c '
import json, sys, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
brief = str(ti.get("command") or ti.get("file_path") or ti.get("path")
            or ti.get("pattern") or ti.get("query") or "")
brief = " ".join(brief.split())
if len(brief) > 120: brief = brief[:120] + "…"
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
tool = d.get("tool_name") or "?"
print(now + " | " + tool + " | " + brief)' 2>/dev/null || true)"
fi

[ -n "$LINE" ] && echo "$LINE" >> "$LOG" 2>/dev/null

exit 0
