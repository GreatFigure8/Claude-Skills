#!/usr/bin/env bash
# SessionStart hook — dev-epic-workflow session grounding.
# stdout from this hook is injected into the session's context.
# Fires on: startup | resume | clear | compact (see settings.json matcher).
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

# Drain stdin (hook input JSON); capture source if jq is available.
INPUT="$(cat 2>/dev/null || true)"
SOURCE=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    SOURCE="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("source") or "")
except Exception: pass' 2>/dev/null || true)"
  fi
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

echo "## Session grounding (auto-injected — dev-epic-workflow)"
[ -n "$SOURCE" ] && echo "_Session source: ${SOURCE}_"
echo
echo "### Git state"
echo "- Branch: $(git branch --show-current 2>/dev/null || echo '(detached)')"
echo "- Working tree root: $(git rev-parse --show-toplevel 2>/dev/null)"

DIRTY="$(git status --short 2>/dev/null | head -15)"
if [ -n "$DIRTY" ]; then
  echo "- Status (dirty):"
  echo '```'
  echo "$DIRTY"
  echo '```'
else
  echo "- Status: clean"
fi

echo "- Recent commits:"
echo '```'
git log --oneline -5 2>/dev/null
echo '```'

WT_COUNT="$(git worktree list 2>/dev/null | wc -l | tr -d ' ')"
if [ "${WT_COUNT:-1}" -gt 1 ]; then
  echo "- Worktrees:"
  echo '```'
  git worktree list 2>/dev/null
  echo '```'
fi

# Surface any emergency autosnapshot FIRST (compaction or dirty session-end), then delete it.
for SNAP in "$(ls -t docs/epics/*/handoff-autosnapshot.md 2>/dev/null | head -1)" ".claude/handoff-autosnapshot.md"; do
  if [ -n "$SNAP" ] && [ -f "$SNAP" ]; then
    echo
    echo "### ⚠️ AUTOSNAPSHOT FOUND — a previous session compacted or ended uncleanly"
    echo "Treat all prior claims as UNVERIFIED. Re-ground from disk (Phase 0 resume rule) before continuing."
    echo
    echo '```'
    cat "$SNAP"
    echo '```'
    rm -f "$SNAP" 2>/dev/null || true
  fi
done

# Inject the newest handoff, if any.
HANDOFF="$(ls -t docs/epics/*/handoff.md 2>/dev/null | head -1)"
if [ -n "$HANDOFF" ] && [ -f "$HANDOFF" ]; then
  EPIC_DIR="$(dirname "$HANDOFF")"
  echo
  echo "### Active session handoff: ${HANDOFF}"
  echo "Epic plan: ${EPIC_DIR}/plan.md — read it before acting."
  echo "Per dev-epic-workflow Phase 0/3.5: verify everything under 'Claimed but NOT yet verified' against the repo before building on it."
  echo
  echo '```'
  cat "$HANDOFF"
  echo '```'
else
  NEWEST_PLAN="$(ls -t docs/epics/*/plan.md 2>/dev/null | head -1)"
  if [ -n "$NEWEST_PLAN" ]; then
    echo
    echo "### No active handoff. Newest epic plan: ${NEWEST_PLAN}"
  fi
fi

exit 0
