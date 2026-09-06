#!/usr/bin/env bash
# dev-story-sprint installer — symlinks the skill dir and the story-item-executor agent
# into ~/.claude so edits in the repo are live immediately. Idempotent: re-running on an
# already-linked machine is a no-op. A pre-existing plain copy is moved aside as .bak.
# The control plane (cancel gate, subagent lifecycle, statusline) comes from
# dev-epic-workflow's user-level install; this script only warns if it's missing.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the skill dir
SKILLS_DEST="${HOME}/.claude/skills"
AGENTS_DEST="${HOME}/.claude/agents"
mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"

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

if [ ! -f "${HOME}/.claude/hooks/cancel-gate.sh" ]; then
  echo "warning: ~/.claude/hooks/cancel-gate.sh not found — run dev-epic-workflow's install.sh --user for the cancel gate, subagent lifecycle, and statusline." >&2
fi
