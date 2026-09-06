#!/usr/bin/env bash
# Refresh the live skills worktree to whatever origin/main is. ~/.claude/skills/* and
# ~/.claude/agents/story-item-executor.md symlink into this worktree, so this is the
# "go live" step after a merge to main. The worktree is detached and read-only by
# convention: nobody commits here, so `git switch` in the dev checkout can never change
# what Claude Code loads.
set -euo pipefail
LIVE="${CLAUDE_SKILLS_LIVE:-$HOME/Source/claude-skills-main}"
[ -d "$LIVE/.git" ] || [ -f "$LIVE/.git" ] || { echo "no worktree at $LIVE — see SKILL.md Install" >&2; exit 1; }
git -C "$LIVE" fetch -q origin
git -C "$LIVE" checkout -q --detach origin/main
echo "live: $LIVE @ $(git -C "$LIVE" log --oneline -1)"
