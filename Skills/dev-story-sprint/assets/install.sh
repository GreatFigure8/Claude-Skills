#!/usr/bin/env bash
# dev-story-sprint installer — three idempotent steps. Run it from the claude-skills checkout
# (~/Source/claude-skills); the symlinks point at wherever this file lives, so whatever branch
# is checked out there is what Claude Code loads (keep `main` checked out when not developing).
#   1. symlink the skill dir into ~/.claude/skills
#   2. symlink the story-item-executor agent into ~/.claude/agents
#   3. merge assets/permissions-allow.json into ~/.claude/settings.json permissions.allow
# Existing entries, defaultMode and every other settings key are preserved. A pre-existing
# plain copy at a symlink target is moved aside as .bak. The control plane (cancel gate,
# subagent lifecycle, statusline) comes from dev-epic-workflow's install; this only warns.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the skill dir
SKILLS_DEST="${HOME}/.claude/skills"
AGENTS_DEST="${HOME}/.claude/agents"
SETTINGS="${HOME}/.claude/settings.json"
ALLOW_SRC="$HERE/assets/permissions-allow.json"
mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"
chmod +x "$HERE"/assets/*.sh 2>/dev/null || true

link() { # link <target> <linkpath>
  local target="$1" link="$2"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    echo "ok:        $link -> $target"; return 0
  fi
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    mv "$link" "$link.bak"; echo "moved:     $link -> $link.bak"
  fi
  ln -sfn "$target" "$link"
  echo "linked:    $link -> $target"
}

link "$HERE" "$SKILLS_DEST/dev-story-sprint"
link "$HERE/assets/agents/story-item-executor.md" "$AGENTS_DEST/story-item-executor.md"

# --- settings.json: permissions allowlist ----------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found — skipped settings.json allowlist merge" >&2
else
  "$HERE/assets/merge-settings.sh" "$SETTINGS" "$ALLOW_SRC"
fi

if [ ! -f "${HOME}/.claude/hooks/cancel-gate.sh" ]; then
  echo "warning: ~/.claude/hooks/cancel-gate.sh not found — run dev-epic-workflow's install.sh --user for the cancel gate, subagent lifecycle, and statusline." >&2
fi
