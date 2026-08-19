#!/usr/bin/env bash
# Fixture harness for the executor control plane's lifecycle hooks:
#   ../subagent-lifecycle.sh     (SubagentStart/Stop — brackets, owner records,
#                                 owner-matched terminal stamping)
#   ../subagent-tool-logger.sh   (PostToolUse — per-agent log + ownership claim)
#
# Runs the REPO copies of the hooks against synthetic hook-input JSON in a
# throwaway sandbox, and prints one row per case with the real value observed.
# Nothing outside the sandbox is read or written: every git repo, worktree,
# marker, status file and epic folder lives under a fresh mktemp -d removed on
# exit. Never installs anything and never touches a real repo or ~/.claude.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/lifecycle-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# Cases run under three tool availabilities, because the hooks must be correct
# with no JSON parser at all:
#   full  — normal PATH (jq present)
#   nojq  — python3 but no jq
#   bare  — neither (grep/sed parse, parser-free JSON insert)
# The logger's log LINE needs jq or python3 (pre-existing), so line-count
# assertions skip `bare`; its ownership claim is asserted in all three.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIFECYCLE="$HOOKS_DIR/subagent-lifecycle.sh"
LOGGER="$HOOKS_DIR/subagent-tool-logger.sh"
for f in "$LIFECYCLE" "$LOGGER"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 1; }
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/lifecycle-fixtures.XXXXXX")" || exit 1
# Resolve symlinks (/var -> /private/var on macOS): git reports real paths, and
# these cases compare paths for equality.
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0
EPIC_REL="docs/epics/99-fixture-epic"
OWNER="a71a4bb0c9d2ef3456789"          # the agent that starts and stops
PHANTOM="af496cdec8c7d1d96"            # a stop with no start (epic 01's ghost)
OTHER="b6f0e1e0f8c0afd15b0"            # a second, concurrently live executor
ITEM="fix-item-a"                      # executor status file: <item>.json

git_q() { git -c user.email=fixture@example.com -c user.name=fixture \
              -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }

# --------------------------------------------------------------- helpers ----

check() { # $1 label  $2 expected  $3 actual  $4 variant
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-56s %-5s exp=%-22s got=%-22s %s\n' "$1" "$4" "$2" "$3" "$R"
}

BIN_NOJQ="$SANDBOX/bin-nojq"; BIN_BARE="$SANDBOX/bin-bare"
mkdir -p "$BIN_NOJQ" "$BIN_BARE"
for t in cat grep sed head tr cut wc git ls mkdir rm mv dirname basename date printf env sort find touch sleep; do
  p="$(command -v "$t" 2>/dev/null)" || continue
  ln -sf "$p" "$BIN_NOJQ/$t"; ln -sf "$p" "$BIN_BARE/$t"
done
p="$(command -v python3 2>/dev/null)" && ln -sf "$p" "$BIN_NOJQ/python3"
PATH_FULL="$PATH"
path_for() {
  case "$1" in
    full) printf '%s' "$PATH_FULL" ;;
    nojq) printf '%s' "$BIN_NOJQ" ;;
    bare) printf '%s' "$BIN_BARE" ;;
  esac
}

mkorch() { # $1 = base path -> $1/orch (main) + $1/orch-wt (worktree, fix/item-a)
  rm -rf "$1"; mkdir -p "$1/orch/$EPIC_REL" "$1/orch/.claude/signals"
  printf '# fixture epic\n' > "$1/orch/$EPIC_REL/plan.md"
  git_q -C "$1/orch" init -q
  git_q -C "$1/orch" checkout -q -b main 2>/dev/null || git_q -C "$1/orch" branch -q -m main
  git_q -C "$1/orch" add -A; git_q -C "$1/orch" commit -q -m fixture > /dev/null
  git_q -C "$1/orch" worktree add -q -b fix/item-a "$1/orch-wt" main > /dev/null 2>&1
}

# The executor's own status write, performed the way the contract documents it:
# resolve the canonical root from wherever the executor is (here: the worktree),
# then write docs/epics/<NN>-<slug>/status/<item>.json atomically.
exec_status() { # $1 = dir the executor runs in  $2 = state
  R="$(cd "$1" && dirname "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")"
  D="$R/$EPIC_REL/status"; mkdir -p "$D"
  printf '{\n  "item": "3 fixture",\n  "branch": "fix/item-a",\n  "state": "%s",\n  "detail": "fixture write",\n  "commit": "abc1234",\n  "updated": "2026-08-19T00:00:00Z"\n}\n' \
    "$2" > "$D/$ITEM.json.tmp"
  mv "$D/$ITEM.json" "$D/$ITEM.json.bak" 2>/dev/null
  mv "$D/$ITEM.json.tmp" "$D/$ITEM.json"; rm -f "$D/$ITEM.json.bak"
  printf '%s' "$D/$ITEM.json"
}

fx_lifecycle() { # $1 = event  $2 = agent id -> stdout JSON
  printf '{"session_id":"sess-1","transcript_path":"/dev/null","cwd":"%s",
 "hook_event_name":"%s","agent_id":"%s","agent_type":"work-item-executor"}\n' \
    "$SANDBOX" "$1" "$2"
}

fx_posttool() { # $1 = agent id  $2 = command text
  printf '{"session_id":"sess-1","hook_event_name":"PostToolUse","agent_id":"%s",
 "agent_type":"work-item-executor","tool_name":"Bash","tool_input":{"command":"%s"}}\n' \
    "$1" "$2"
}

run_life() { # $1 projectdir  $2 event  $3 agent  $4 variant
  fx_lifecycle "$2" "$3" | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$4")" \
    /bin/bash "$LIFECYCLE" > /dev/null 2>> "$SANDBOX/stderr.log"
}

run_log() { # $1 projectdir  $2 agent  $3 command-text  $4 variant
  fx_posttool "$2" "$3" | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$4")" \
    /bin/bash "$LOGGER" > /dev/null 2>> "$SANDBOX/stderr.log"
}

jget() { # $1 file  $2 key -> value, or "<absent>" ; uses the full PATH python3
  [ -f "$1" ] || { printf '<no-file>'; return 0; }
  PATH="$PATH_FULL" python3 - "$1" "$2" <<'PYEOF' 2>/dev/null || printf '<unparseable>'
import json, sys
try:
    with open(sys.argv[1]) as f: d = json.load(f)
except Exception:
    print("<unparseable>", end=""); sys.exit(0)
v = d.get(sys.argv[2], "<absent>")
print(("true" if v is True else "false" if v is False else str(v)), end="")
PYEOF
}

count() { # $1 = glob-safe path pattern -> matching line count across files
  cat $1 2>/dev/null | wc -l | tr -d ' '
}

echo "sandbox:   $SANDBOX"
echo "lifecycle: $LIFECYCLE"
echo "logger:    $LOGGER"
echo "bash:      $(/bin/bash --version | head -1)"
echo "git:       $(git --version)"
echo

# ============================================================================
echo "=== A. worktree dispatch: one status tree, owner stop stamps terminal ==="
for V in full nojq bare; do
  B="$SANDBOX/A-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  # canonical root resolved from inside the worktree == the orchestrator checkout
  CANON="$(cd "$WT" && dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
  check "canonical root from worktree == orchestrator checkout" "$ORCH" "$CANON" "$V"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  SF="$(exec_status "$WT" implementing)"          # executor writes from the worktree
  check "executor status file lands in hook status dir" "$ORCH/$EPIC_REL/status/$ITEM.json" "$SF" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"; RC=$?
  check "owner stop: exit code" 0 "$RC" "$V"
  check "owner stop: terminal" "true" "$(jget "$SF" terminal)" "$V"
  check "owner stop: recorded owner" "$OWNER" "$(jget "$SF" agent_id)" "$V"
  check "owner stop: state preserved" "implementing" "$(jget "$SF" state)" "$V"
done

# ============================================================================
echo
echo "=== B. a stop from an agent that never started stamps nothing =========="
for V in full nojq bare; do
  B="$SANDBOX/B-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  SF="$(exec_status "$WT" implementing)"
  BEFORE="$(count "$ORCH/$EPIC_REL/status/agent-$OWNER.log")"
  run_life "$ORCH" SubagentStop "$PHANTOM" "$V"; RC=$?
  check "phantom stop: exit code" 0 "$RC" "$V"
  check "phantom stop: terminal left unset" "<absent>" "$(jget "$SF" terminal)" "$V"
  check "phantom stop: no owner recorded" "<absent>" "$(jget "$SF" agent_id)" "$V"
  check "phantom stop: owner's bracket file untouched" "$BEFORE" \
        "$(count "$ORCH/$EPIC_REL/status/agent-$OWNER.log")" "$V"
  check "phantom stop: logged to its own file" "1" \
        "$(count "$ORCH/$EPIC_REL/status/agent-$PHANTOM.log")" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  check "real owner stop afterwards: terminal" "true" "$(jget "$SF" terminal)" "$V"
done

# ============================================================================
echo
echo "=== C. a stop from another LIVE executor never stamps someone else ====="
for V in full nojq; do
  B="$SANDBOX/C-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  run_life "$ORCH" SubagentStart "$OTHER" "$V"
  SF="$(exec_status "$WT" implementing)"
  # owner binds its own file by naming it in its own tool call (logger claim)
  run_log "$ORCH" "$OWNER" "mv $ITEM.json.tmp $ITEM.json" "$V"
  check "logger claim: owner recorded" "$OWNER" "$(jget "$SF" agent_id)" "$V"
  run_life "$ORCH" SubagentStop "$OTHER" "$V"
  check "other executor stop: terminal still unset" "<absent>" "$(jget "$SF" terminal)" "$V"
  check "other executor stop: owner unchanged" "$OWNER" "$(jget "$SF" agent_id)" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  check "owner stop: terminal" "true" "$(jget "$SF" terminal)" "$V"
done

# ============================================================================
echo
echo "=== D. concurrent executors: unowned file is never guessed at =========="
for V in full; do
  B="$SANDBOX/D-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  run_life "$ORCH" SubagentStart "$OTHER" "$V"
  SF="$(exec_status "$WT" implementing)"          # nobody named it: unowned
  run_life "$ORCH" SubagentStop "$OTHER" "$V"
  check "two live executors: unowned file not claimed" "<absent>" "$(jget "$SF" agent_id)" "$V"
  check "two live executors: terminal not stamped" "<absent>" "$(jget "$SF" terminal)" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"     # now sole survivor
  check "last executor standing: claims and stamps" "true" "$(jget "$SF" terminal)" "$V"
done

# ============================================================================
echo
echo "=== E. brackets co-located across a mid-run branch change ==============="
for V in full nojq bare; do
  B="$SANDBOX/E-$V"; mkorch "$B"; ORCH="$B/orch"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  git_q -C "$ORCH" checkout -q -b fix/item-mid    # the executor branches: step 2
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  check "log files created for this agent" "1" \
        "$(ls "$ORCH/$EPIC_REL/status/"*.log 2>/dev/null | wc -l | tr -d ' ')" "$V"
  check "START+STOP in one file" "2" \
        "$(grep -c 'SUBAGENT ST' "$ORCH/$EPIC_REL/status/agent-$OWNER.log" 2>/dev/null | tr -d ' ')" "$V"
  check "file is the agent's, not a branch's" "agent-$OWNER.log" \
        "$(basename "$(ls "$ORCH/$EPIC_REL/status/"*.log | head -1)")" "$V"
done

# ============================================================================
echo
echo "=== F. degenerate inputs still exit 0 and corrupt nothing =============="
for V in full nojq bare; do
  B="$SANDBOX/F-$V"; mkorch "$B"; ORCH="$B/orch"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"; RC=$?
  check "no status.json anywhere: exit code" 0 "$RC" "$V"
  check "no status.json anywhere: bracket still closed" "2" \
        "$(grep -c 'SUBAGENT ST' "$ORCH/$EPIC_REL/status/agent-$OWNER.log" | tr -d ' ')" "$V"

  : | CLAUDE_PROJECT_DIR="$ORCH" PATH="$(path_for "$V")" /bin/bash "$LIFECYCLE" \
        > /dev/null 2>> "$SANDBOX/stderr.log"
  check "empty stdin: exit code" 0 "$?" "$V"
  printf 'not json at all\n' | CLAUDE_PROJECT_DIR="$ORCH" PATH="$(path_for "$V")" \
        /bin/bash "$LIFECYCLE" > /dev/null 2>> "$SANDBOX/stderr.log"
  check "non-JSON stdin: exit code" 0 "$?" "$V"
  printf '%s' '{"hook_event_name":"SubagentStop","agent_id":"a71a' \
    | CLAUDE_PROJECT_DIR="$ORCH" PATH="$(path_for "$V")" /bin/bash "$LIFECYCLE" \
      > /dev/null 2>> "$SANDBOX/stderr.log"
  check "truncated JSON: exit code" 0 "$?" "$V"

  NOEPIC="$SANDBOX/F-noepic-$V"; rm -rf "$NOEPIC"; mkdir -p "$NOEPIC"
  run_life "$NOEPIC" SubagentStart "$OWNER" "$V"
  run_life "$NOEPIC" SubagentStop "$OWNER" "$V"; RC=$?
  check "no epic, no git repo: exit code" 0 "$RC" "$V"
  check "no epic, no git repo: marker cleaned up" "0" \
        "$(ls "$NOEPIC/.claude/signals/" 2>/dev/null | wc -l | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== G. tool logger agrees with the lifecycle hook on one path =========="
for V in full nojq; do
  B="$SANDBOX/G-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  run_log "$ORCH" "$OWNER" "git status --short" "$V"
  run_log "$ORCH" "$OWNER" "git push -u origin fix/item-a" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  check "one log file for the agent" "1" \
        "$(ls "$ORCH/$EPIC_REL/status/"*.log 2>/dev/null | wc -l | tr -d ' ')" "$V"
  check "bracket lines + tool lines in it" "4" \
        "$(count "$ORCH/$EPIC_REL/status/agent-$OWNER.log")" "$V"
  # An orchestrator call (no agent_id) is still never logged.
  printf '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}\n' \
    | CLAUDE_PROJECT_DIR="$ORCH" PATH="$(path_for "$V")" /bin/bash "$LOGGER" \
      > /dev/null 2>> "$SANDBOX/stderr.log"
  check "orchestrator call adds no line" "4" \
        "$(count "$ORCH/$EPIC_REL/status/agent-$OWNER.log")" "$V"
done

# ============================================================================
echo
echo "=== H. logger claim is conservative ===================================="
for V in full nojq bare; do
  B="$SANDBOX/H-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  run_life "$ORCH" SubagentStart "$OTHER" "$V"
  SF="$(exec_status "$WT" implementing)"
  run_log "$ORCH" "$OWNER" "ls -la" "$V"
  check "call that names no status file: no claim" "<absent>" "$(jget "$SF" agent_id)" "$V"
  run_log "$ORCH" "$OWNER" "cat $EPIC_REL/status/$ITEM.json" "$V"
  check "call naming the file: claimed" "$OWNER" "$(jget "$SF" agent_id)" "$V"
  run_log "$ORCH" "$OTHER" "cat $EPIC_REL/status/$ITEM.json" "$V"
  check "another agent cannot re-claim it" "$OWNER" "$(jget "$SF" agent_id)" "$V"
  check "status file is still valid JSON" "implementing" "$(jget "$SF" state)" "$V"
done

# ============================================================================
echo
echo "=== I. stamping is idempotent and preserves the milestone =============="
for V in full nojq bare; do
  B="$SANDBOX/I-$V"; mkorch "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$ORCH" SubagentStart "$OWNER" "$V"
  SF="$(exec_status "$WT" pr-opened)"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  run_life "$ORCH" SubagentStop "$OWNER" "$V"
  check "double stop: terminal" "true" "$(jget "$SF" terminal)" "$V"
  check "double stop: state untouched" "pr-opened" "$(jget "$SF" state)" "$V"
  check "double stop: detail untouched" "fixture write" "$(jget "$SF" detail)" "$V"
  check "marker removed" "0" "$(ls "$ORCH/.claude/signals/" 2>/dev/null | wc -l | tr -d ' ')" "$V"
done

echo
echo "=== hook stderr (empty unless a hook errored on its own) ==============="
[ -s "$SANDBOX/stderr.log" ] && head -20 "$SANDBOX/stderr.log"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
