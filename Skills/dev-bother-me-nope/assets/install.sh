#!/usr/bin/env bash
# Links dev-bother-me-nope into ~/.claude: the skill dir (the frontmatter hook resolves
# assets/bin/deploy-guard.py through it) and the bmn-worker agent (carries the same hook
# into every subagent). Idempotent.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$HOME/.claude/skills" "$HOME/.claude/agents"
ln -sfn "$SKILL_DIR" "$HOME/.claude/skills/dev-bother-me-nope"
ln -sfn "$SKILL_DIR/agents/bmn-worker.md" "$HOME/.claude/agents/bmn-worker.md"
chmod +x "$SKILL_DIR/assets/bin/deploy-guard.py"
echo "dev-bother-me-nope installed -> $SKILL_DIR"
