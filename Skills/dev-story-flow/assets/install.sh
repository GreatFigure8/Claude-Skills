#!/usr/bin/env bash
# dev-story-flow installer — idempotent. Run it FROM THE LIVE WORKTREE (~/Source/claude-skills-main),
# because the symlinks point at wherever this file lives.
#   1. symlink Skills/dev-story-flow into ~/.claude/skills
#   2. symlink Skills/goal (the `/goal using <skill> <objective>` entry point) into ~/.claude/skills
#   3. make assets/bin and assets/tests executable
# Executors and the control plane are reused: story-item-executor comes from dev-story-sprint's
# install, cancel gate / lifecycle / statusline from dev-epic-workflow's. This only warns.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"        # Skills/dev-story-flow
GOAL="$(cd "$HERE/../goal" 2>/dev/null && pwd || true)"
SKILLS_DEST="${HOME}/.claude/skills"
mkdir -p "$SKILLS_DEST"
chmod +x "$HERE"/assets/*.sh "$HERE"/assets/bin/*.sh "$HERE"/assets/tests/*.sh 2>/dev/null || true

case "$HERE" in
  *claude-skills-main*) ;;
  *) echo "note: running from $HERE — symlinks will point here, not at the live worktree. See SKILL.md Install." >&2 ;;
esac

link() { # link <target> <linkpath>
  local target="$1" link="$2"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then echo "ok:        $link -> $target"; return 0; fi
  if [ -e "$link" ] && [ ! -L "$link" ]; then mv "$link" "$link.bak"; echo "moved:     $link -> $link.bak"; fi
  ln -sfn "$target" "$link"; echo "linked:    $link -> $target"
}

link "$HERE" "$SKILLS_DEST/dev-story-flow"
if [ -n "$GOAL" ]; then link "$GOAL" "$SKILLS_DEST/goal"; else echo "warning: Skills/goal not found beside dev-story-flow — /goal entry point not installed" >&2; fi

[ -e "${HOME}/.claude/agents/story-item-executor.md" ] || echo "warning: ~/.claude/agents/story-item-executor.md missing — run dev-story-sprint's assets/install.sh (the coder dispatches through it)." >&2
[ -f "${HOME}/.claude/hooks/cancel-gate.sh" ]         || echo "warning: ~/.claude/hooks/cancel-gate.sh missing — run dev-epic-workflow's install.sh --user for the cancel gate, lifecycle hook, and context-budget gate." >&2
command -v python3 >/dev/null 2>&1                     || echo "warning: python3 not found — assets/bin/sprint-state.sh needs it." >&2
