#!/usr/bin/env bash
# Fixture harness for the executor control plane's attribution hooks:
#   ../cancel-gate.sh            (PreToolUse — deny executor calls under a sentinel)
#   ../subagent-tool-logger.sh   (PostToolUse — log executor calls only)
#
# Runs the REPO copies of the hooks against synthetic hook-input JSON in a
# throwaway sandbox, and prints one row per case with the real exit code.
# Nothing outside the sandbox is read or written: every cancel sentinel, git
# repo, worktree and marker file lives under a fresh mktemp -d that is removed
# on exit. Never creates a sentinel in a real repo, and never installs anything.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# Each case is run under three tool availabilities, because the hooks must be
# correct with no JSON parser at all:
#   full  — normal PATH (jq present)
#   nojq  — curated PATH with python3 but no jq
#   bare  — curated PATH with neither jq nor python3 (grep/sed fallback)
# The logger cases skip `bare`: formatting a log line has always required jq or
# python3, which is pre-existing behaviour this fixture does not change.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$HOOKS_DIR/cancel-gate.sh"
LOGGER="$HOOKS_DIR/subagent-tool-logger.sh"
for f in "$GATE" "$LOGGER"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 1; }
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/cancel-gate-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0
CASES=0
EPIC_REL="docs/epics/99-fixture-epic"
AGENT_ID="a71a4bb0c9d2ef3456789"
OTHER_ID="b6f0e1e0f8c0afd15b0"

# ---------------------------------------------------------------- sandbox ----

# Every path this harness inits, commits in, or removes MUST live under
# $SANDBOX. Without this guard a single mistyped or clobbered variable makes
# `git -C "" add -A` (git treats an empty -C as "stay here") commit the
# developer's own checkout — exactly the epic 04 item 2 bug. Abort loudly
# instead (same guard as session-start-fixtures.sh).
sandboxed() { # $1 = path that is about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

git_q() { git -c user.email=fixture@example.com -c user.name=fixture \
              -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }

mkrepo() { # $1 = path, $2 = branch
  sandboxed "$1"
  mkdir -p "$1/$EPIC_REL" "$1/.claude/signals"
  printf '# fixture epic\n' > "$1/$EPIC_REL/plan.md"
  git_q -C "$1" init -q
  git_q -C "$1" checkout -q -b "$2" 2>/dev/null || git_q -C "$1" branch -q -m "$2"
  git_q -C "$1" add -A
  git_q -C "$1" commit -q -m "fixture" > /dev/null
}

DIRECT="$SANDBOX/direct"     # single checkout: project dir branch IS the executor's
ORCH="$SANDBOX/orch"         # orchestrator checkout on main ...
WT="$SANDBOX/orch-wt"        # ... with a linked worktree on the item branch
mkrepo "$DIRECT" "fix/item-a"
mkrepo "$ORCH" "main"
git_q -C "$ORCH" worktree add -q -b "fix/item-a" "$WT" main > /dev/null 2>&1

# A lifecycle marker, armed in both repos. Present for every case on purpose:
# the hooks must ignore it entirely (that it was ever consulted is GH #2).
touch "$DIRECT/.claude/signals/subagent-active-$AGENT_ID"
touch "$ORCH/.claude/signals/subagent-active-$AGENT_ID"

# Curated PATHs for the "no jq" / "no parser" variants.
BIN_NOJQ="$SANDBOX/bin-nojq"; BIN_BARE="$SANDBOX/bin-bare"
mkdir -p "$BIN_NOJQ" "$BIN_BARE"
for t in cat grep sed head tr cut wc git ls mkdir rm dirname basename date printf env sort find touch; do
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

# --------------------------------------------------------------- fixtures ----

FX="$SANDBOX/fx"; mkdir -p "$FX"

cat > "$FX/subagent.json" <<EOF
{"session_id":"sess-1","transcript_path":"/dev/null","cwd":"$ORCH","permission_mode":"default",
 "hook_event_name":"PreToolUse","agent_id":"$AGENT_ID","agent_type":"work-item-executor",
 "tool_name":"Bash","tool_input":{"command":"git status --short"}}
EOF

cat > "$FX/orchestrator.json" <<EOF
{"session_id":"sess-1","transcript_path":"/dev/null","cwd":"$ORCH","permission_mode":"default",
 "hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status --short"}}
EOF

# Orchestrator call whose ARGUMENT contains the literal text "agent_id" (this is
# what editing these hooks looks like from the inside). Must not be mistaken for
# a subagent call by any of the three extraction paths.
cat > "$FX/orchestrator-escaped.json" <<EOF
{"session_id":"sess-1","hook_event_name":"PreToolUse","tool_name":"Write",
 "tool_input":{"file_path":"cancel-gate.sh","content":"{\\"agent_id\\": \\"spoofed\\"}"}}
EOF

cat > "$FX/other-subagent.json" <<EOF
{"session_id":"sess-1","hook_event_name":"PreToolUse","agent_id":"$OTHER_ID",
 "agent_type":"work-item-executor","tool_name":"Bash","tool_input":{"command":"ls"}}
EOF

cat > "$FX/agent-id-null.json" <<EOF
{"session_id":"sess-1","hook_event_name":"PreToolUse","agent_id":null,
 "tool_name":"Bash","tool_input":{"command":"ls"}}
EOF

# Truncated mid-value, and truncated after a complete agent_id pair.
printf '%s' '{"hook_event_name":"PreToolUse","agent_id":"a71a' > "$FX/malformed-a.json"
printf '%s' "{\"hook_event_name\":\"PreToolUse\",\"agent_id\":\"$AGENT_ID\",\"tool_inp" > "$FX/malformed-b.json"
: > "$FX/empty.json"
printf 'not json at all\n' > "$FX/garbage.json"

# ---------------------------------------------------------------- helpers ----

sentinel_reset() { sandboxed "$1"; rm -f "$1/$EPIC_REL/CANCEL" "$1/.claude/signals/cancel"; }

run_gate() { # $1 repo  $2 fixture  $3 variant
  CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$3")" \
    /bin/bash "$GATE" < "$2" > /dev/null 2>> "$SANDBOX/gate-stderr.log"
}

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-58s %-5s exp=%s got=%s  %s\n' "$1" "$4" "$2" "$3" "$R"
}

gate_case() { # $1 label  $2 repo  $3 fixture  $4 expected
  for V in full nojq bare; do
    run_gate "$2" "$3" "$V"; RC=$?
    check "$1" "$4" "$RC" "$V"
  done
}

echo "sandbox:      $SANDBOX"
echo "gate:         $GATE"
echo "logger:       $LOGGER"
echo "bash:         $(/bin/bash --version | head -1)"
echo "direct repo:  branch fix/item-a, $(git_q -C "$DIRECT" worktree list | wc -l | tr -d ' ') worktree(s)"
echo "orch repo:    branch main, $(git_q -C "$ORCH" worktree list | wc -l | tr -d ' ') worktree(s) (linked: fix/item-a)"
echo "marker armed in both repos: .claude/signals/subagent-active-$AGENT_ID"
echo
echo "=== cancel gate (0 = allowed, 2 = denied) ==============================="

# --- Definition of done, items 1-6 (worktree/orchestrator repo) --------------
sentinel_reset "$ORCH"
gate_case "no sentinel + agent_id present" "$ORCH" "$FX/subagent.json" 0
gate_case "no sentinel + agent_id absent" "$ORCH" "$FX/orchestrator.json" 0

: > "$ORCH/$EPIC_REL/CANCEL"
gate_case "empty sentinel + agent_id present" "$ORCH" "$FX/subagent.json" 2
gate_case "empty sentinel + agent_id absent (orchestrator)" "$ORCH" "$FX/orchestrator.json" 0
gate_case "empty sentinel + agent_id null" "$ORCH" "$FX/agent-id-null.json" 0
gate_case "empty sentinel + escaped agent_id in tool_input" "$ORCH" "$FX/orchestrator-escaped.json" 0
gate_case "empty sentinel + empty stdin" "$ORCH" "$FX/empty.json" 0
gate_case "empty sentinel + non-JSON stdin" "$ORCH" "$FX/garbage.json" 0
gate_case "empty sentinel + truncated JSON (mid-value)" "$ORCH" "$FX/malformed-a.json" 0
gate_case "empty sentinel + truncated JSON (after agent_id)" "$ORCH" "$FX/malformed-b.json" 0

sentinel_reset "$ORCH"
: > "$ORCH/.claude/signals/cancel"
gate_case "empty .claude/signals/cancel + agent_id present" "$ORCH" "$FX/subagent.json" 2
gate_case "empty .claude/signals/cancel + agent_id absent" "$ORCH" "$FX/orchestrator.json" 0

# --- Scoped sentinels: agent-id selectors ------------------------------------
sentinel_reset "$ORCH"
printf '%s\n' "$AGENT_ID" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "scoped sentinel: exact agent id matches" "$ORCH" "$FX/subagent.json" 2
gate_case "scoped sentinel: exact agent id, other agent" "$ORCH" "$FX/other-subagent.json" 0
gate_case "scoped sentinel: exact agent id, orchestrator" "$ORCH" "$FX/orchestrator.json" 0

printf '%s' "$AGENT_ID" > "$ORCH/$EPIC_REL/CANCEL"   # no trailing newline
gate_case "scoped sentinel: last line lacks newline" "$ORCH" "$FX/subagent.json" 2

printf '%s\n' "${AGENT_ID%????????????}" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "scoped sentinel: 9-char agent id prefix" "$ORCH" "$FX/subagent.json" 2

printf '%s\n' "a71a" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "scoped sentinel: 4-char prefix (too short to match)" "$ORCH" "$FX/subagent.json" 0

printf '# cancel item 3 later\n\n   \n' > "$ORCH/$EPIC_REL/CANCEL"
gate_case "sentinel with only comments/blank lines + agent_id" "$ORCH" "$FX/subagent.json" 2
gate_case "sentinel with only comments/blank lines + orchestrator" "$ORCH" "$FX/orchestrator.json" 0

printf '  %s  \n' "$AGENT_ID" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "scoped sentinel: surrounding whitespace tolerated" "$ORCH" "$FX/subagent.json" 2

# --- Scoped sentinels: branch selectors, worktree dispatch -------------------
printf '%s\n' "fix/item-a" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "worktree mode: item branch name (ignored by design)" "$ORCH" "$FX/subagent.json" 0
printf '%s\n' "main" > "$ORCH/$EPIC_REL/CANCEL"
gate_case "worktree mode: orchestrator branch (must NOT cancel all)" "$ORCH" "$FX/subagent.json" 0
gate_case "worktree mode: orchestrator branch + orchestrator call" "$ORCH" "$FX/orchestrator.json" 0
sentinel_reset "$ORCH"

# --- Scoped sentinels: branch selectors, direct dispatch (back-compat) -------
sentinel_reset "$DIRECT"
printf '%s\n' "fix/item-a" > "$DIRECT/$EPIC_REL/CANCEL"
gate_case "direct mode: current branch name matches (legacy)" "$DIRECT" "$FX/subagent.json" 2
gate_case "direct mode: current branch name + orchestrator call" "$DIRECT" "$FX/orchestrator.json" 0
printf '%s\n' "fix/item-z" > "$DIRECT/$EPIC_REL/CANCEL"
gate_case "direct mode: different branch name (no match)" "$DIRECT" "$FX/subagent.json" 0
sentinel_reset "$DIRECT"

# --- Not a git repo at all ---------------------------------------------------
NOGIT="$SANDBOX/nogit"; mkdir -p "$NOGIT/$EPIC_REL" "$NOGIT/.claude/signals"
printf '# fixture\n' > "$NOGIT/$EPIC_REL/plan.md"
printf '%s\n' "fix/item-a" > "$NOGIT/$EPIC_REL/CANCEL"
gate_case "non-git project dir: branch selector, no crash" "$NOGIT" "$FX/subagent.json" 0
printf '%s\n' "$AGENT_ID" > "$NOGIT/$EPIC_REL/CANCEL"
gate_case "non-git project dir: agent id still matches" "$NOGIT" "$FX/subagent.json" 2

echo
echo "=== tool logger (lines appended to the epic status log) ================="

LOGREPO="$SANDBOX/logrepo"
logger_case() { # $1 label  $2 fixture  $3 expected line count
  for V in full nojq; do
    sandboxed "$LOGREPO"; rm -rf "$LOGREPO"; mkrepo "$LOGREPO" "main"
    touch "$LOGREPO/.claude/signals/subagent-active-$AGENT_ID"
    CLAUDE_PROJECT_DIR="$LOGREPO" PATH="$(path_for "$V")" \
      /bin/bash "$LOGGER" < "$2" > /dev/null 2>> "$SANDBOX/logger-stderr.log"
    RC=$?
    N="$(cat "$LOGREPO/$EPIC_REL/status/"*.log 2>/dev/null | wc -l | tr -d ' ')"
    check "$1 [exit]" 0 "$RC" "$V"
    check "$1 [lines]" "$3" "$N" "$V"
  done
}
logger_case "logger: agent_id present -> one line" "$FX/subagent.json" 1
logger_case "logger: agent_id absent -> nothing (marker armed)" "$FX/orchestrator.json" 0
logger_case "logger: agent_id null -> nothing" "$FX/agent-id-null.json" 0
logger_case "logger: escaped agent_id in tool_input -> nothing" "$FX/orchestrator-escaped.json" 0
logger_case "logger: truncated JSON -> nothing" "$FX/malformed-b.json" 0
logger_case "logger: empty stdin -> nothing" "$FX/empty.json" 0

echo
echo "=== hook stderr (empty unless a hook errored on its own) ================"
for f in "$SANDBOX/gate-stderr.log" "$SANDBOX/logger-stderr.log"; do
  [ -s "$f" ] && { echo "--- $(basename "$f")"; grep -v '^CANCELLED by dev-epic-workflow' "$f" \
    | grep -v '^This work item has been cancelled' | grep -v '^Everything already pushed is safe' \
    | grep -v '^branch stands:' | grep -v '^write is possible' | head -20; }
done

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
