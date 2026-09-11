#!/usr/bin/env bash
# SessionEnd hook — dev-epic-workflow uncommitted-work guard.
# SessionEnd cannot block termination; instead it leaves a durable warning that
# the next SessionStart injection will surface (then delete). A separate Stop
# hook, handoff-stop-gate.sh, DOES block a turn from ending — once, past the
# context-budget STOP threshold — safely, because it has three independent
# loop guards: Claude Code's own `stop_hook_active` flag on the retry, a
# once-per-session `.claude/signals/handoff-stop-gate-<slug>` marker written
# before the block is ever printed, and Claude Code's hard cap of 8
# consecutive blocks. This hook sweeps that marker on session end so a new
# session starts with a clean slate. Never fail: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

# Drain stdin.
cat >/dev/null 2>&1 || true

rm -f .claude/signals/handoff-stop-gate-* 2>/dev/null || true

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

DIRTY="$(git status --short 2>/dev/null)"
[ -z "$DIRTY" ] && exit 0

# The ONE handoff, per dev-epic-workflow Phase 3.5: <epics-root>/handoff.md.
# One fixed path per repo -- never a per-epic copy -- so a resuming session opens
# a known file instead of globbing every epic folder and guessing which is live.
# Repos differ only in how they case the epics root.
EPICS_ROOT=""
for D in docs/epics DOCS/EPICS docs/EPICS DOCS/epics; do
  [ -d "$D" ] && { EPICS_ROOT="$D"; break; }
done

if [ -n "$EPICS_ROOT" ]; then
  SNAP="${EPICS_ROOT}/handoff-autosnapshot.md"
else
  mkdir -p .claude 2>/dev/null || true
  SNAP=".claude/handoff-autosnapshot.md"
fi

{
  # Append (a compaction snapshot from the same session may already be here).
  echo
  echo "# ⚠️ Session ended with UNCOMMITTED changes"
  echo
  echo "**Ended:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Branch: $(git branch --show-current 2>/dev/null || echo '(detached)')"
  echo "- Dirty files:"
  echo '```'
  echo "$DIRTY"
  echo '```'
  echo
  echo "Phase 3 rule broken: 'never leave a session with uncommitted work.'"
  echo "First action next session: inspect these changes, then commit or discard deliberately."
} >> "$SNAP" 2>/dev/null || true

exit 0
