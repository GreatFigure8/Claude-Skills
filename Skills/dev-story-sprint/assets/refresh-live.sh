#!/usr/bin/env bash
# Fast-forward the live skills worktree to origin/main. ~/.claude/skills/* and
# ~/.claude/agents/story-item-executor.md symlink into this worktree, so this is the
# "go live" step after a merge to main. The worktree is checked out on branch main and
# never switched: nobody commits here, so `git switch` in the working checkout can never
# change what Claude Code loads.
set -euo pipefail
LIVE="${CLAUDE_SKILLS_LIVE:-$HOME/Source/claude-skills-main}"
[ -d "$LIVE/.git" ] || [ -f "$LIVE/.git" ] || { echo "no worktree at $LIVE — see SKILL.md Install" >&2; exit 1; }
git -C "$LIVE" fetch -q origin
git -C "$LIVE" merge -q --ff-only origin/main
echo "live: $LIVE @ $(git -C "$LIVE" log --oneline -1)"
