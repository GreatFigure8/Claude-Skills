#!/usr/bin/env bash
# PreCompact hook — dev-epic-workflow emergency snapshot.
# Fires before ANY compaction (manual /compact or automatic).
# Compaction cannot be cancelled from here; the job is to get truth onto disk
# before the summary replaces the conversation. Never fail: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
TRIGGER="unknown"
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TRIGGER="$(printf '%s' "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo unknown)"
  elif command -v python3 >/dev/null 2>&1; then
    TRIGGER="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("trigger") or "unknown")
except Exception: print("unknown")' 2>/dev/null || echo unknown)"
  fi
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Snapshot lands beside the repo's one handoff; fall back to .claude/ if no epics root exists.
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
  echo "# ⚠️ Pre-compact autosnapshot (trigger: ${TRIGGER})"
  echo
  echo "**Written:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "The conversation was compacted after this snapshot. Per dev-epic-workflow,"
  echo "treat every claim from before the compaction as UNVERIFIED. Re-ground from"
  echo "disk (git log / status / diff) and from plan.md + handoff.md before acting."
  if [ "$TRIGGER" = "auto" ]; then
    echo
    echo "Trigger was AUTO — a checkpoint (/handoff) was missed. Note this in the next handoff."
  fi
  echo
  echo "## Git state at snapshot"
  echo "- Branch: $(git branch --show-current 2>/dev/null || echo '(detached)')"
  echo "- Last commits:"
  echo '```'
  git log --oneline -10 2>/dev/null
  echo '```'
  echo "- Status:"
  echo '```'
  git status --short 2>/dev/null
  echo '```'
  echo "- Uncommitted diffstat:"
  echo '```'
  git diff --stat HEAD 2>/dev/null
  echo '```'
} > "$SNAP" 2>/dev/null || true

exit 0
