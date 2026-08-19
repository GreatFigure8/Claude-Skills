#!/usr/bin/env bash
# PreToolUse hook — dev-epic-workflow deterministic cancel gate.
#
# Cancellation that does not depend on the model noticing: while a cancel
# sentinel exists, every tool call from an ACTIVE SUBAGENT in this project dir
# is denied (exit 2 → the denial message on stderr is fed back to the agent).
# The orchestrator / main session is never gated, so it can always clean up
# and remove the sentinel.
#
# Sentinels (any one triggers the gate):
#   docs/epics/<NN>-<slug>/CANCEL     — cancel executors for that epic
#   .claude/signals/cancel            — cancel all executors in this project dir
#
# Granularity: an EMPTY sentinel cancels every active executor. A sentinel
# whose content is one branch name per line cancels only executors whose
# current git branch matches a listed line (worktree/parallel mode).
#
# Subagent detection: the subagent-lifecycle hook maintains marker files in
# .claude/signals/subagent-active-* between SubagentStart and SubagentStop.
# No marker → not a subagent tool call → always allow (exit 0 fast path).
#
# Must be FAST and must never break a session on its own errors.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0
cat > /dev/null 2>&1 || true   # drain hook input JSON; we don't need it

SIGNALS_DIR=".claude/signals"

# Fast path 1: no active subagent → allow.
ls "$SIGNALS_DIR"/subagent-active-* > /dev/null 2>&1 || exit 0

# Collect sentinels. Fast path 2: none exist → allow.
SENTINELS=""
[ -f "$SIGNALS_DIR/cancel" ] && SENTINELS="$SIGNALS_DIR/cancel"
for C in docs/epics/*/CANCEL; do
  [ -f "$C" ] && SENTINELS="$SENTINELS $C"
done
[ -z "$SENTINELS" ] && exit 0

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"

for SENTINEL in $SENTINELS; do
  if [ ! -s "$SENTINEL" ]; then
    # Empty sentinel → cancel everything.
    MATCH="yes"
  else
    # Non-empty → cancel only listed branches.
    MATCH="no"
    if [ -n "$CURRENT_BRANCH" ] && grep -qxF "$CURRENT_BRANCH" "$SENTINEL" 2>/dev/null; then
      MATCH="yes"
    fi
  fi
  if [ "$MATCH" = "yes" ]; then
    {
      echo "CANCELLED by dev-epic-workflow cancel gate (sentinel: $SENTINEL)."
      echo "This work item has been cancelled by the orchestrator. Do NOT retry or route around this."
      echo "Everything already pushed is safe. Stop now and return a summary of exactly where the"
      echo "branch stands: last pushed commit, what was in flight, what remains. No final status"
      echo "write is possible (tool calls are denied); state it in your summary instead."
    } >&2
    exit 2
  fi
done

exit 0
