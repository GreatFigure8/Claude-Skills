#!/usr/bin/env bash
# dev-story-sprint installer — four idempotent steps. Run it FROM THE LIVE WORKTREE
# (~/Source/claude-skills-main, checked out on main), because the symlinks and hook point at
# wherever this file lives.
#   1. symlink the skill dir into ~/.claude/skills
#   2. symlink the story-item-executor agent into ~/.claude/agents
#   3. merge assets/permissions-allow.json into ~/.claude/settings.json permissions.allow
#   4. register assets/hooks/refresh-live-post-push.sh as a PostToolUse(Bash) hook so every
#      `git push` from this repo fast-forwards the live worktree — no human "go live" step
# Existing entries, defaultMode and every other settings key are preserved. A pre-existing
# plain copy at a symlink target is moved aside as .bak. The control plane (cancel gate,
# subagent lifecycle, statusline) comes from dev-epic-workflow's install; this only warns.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the skill dir
SKILLS_DEST="${HOME}/.claude/skills"
AGENTS_DEST="${HOME}/.claude/agents"
SETTINGS="${HOME}/.claude/settings.json"
ALLOW_SRC="$HERE/assets/permissions-allow.json"
HOOK_CMD="$HERE/assets/hooks/refresh-live-post-push.sh"
mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"
chmod +x "$HERE"/assets/*.sh "$HERE"/assets/hooks/*.sh 2>/dev/null || true

case "$HERE" in
  *claude-skills-main*) ;;
  *) echo "note: running from $HERE — symlinks will point here, not at the live worktree on main. See CLAUDE.md rule 3." >&2 ;;
esac

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

# --- settings.json: permissions allowlist + PostToolUse hook ------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found — skipped settings.json merge (allowlist, hook)" >&2
else
  "$HERE/assets/merge-settings.sh" "$SETTINGS" "$ALLOW_SRC" "$HOOK_CMD"
fi

if [ ! -f "${HOME}/.claude/hooks/cancel-gate.sh" ]; then
  echo "warning: ~/.claude/hooks/cancel-gate.sh not found — run dev-epic-workflow's install.sh --user for the cancel gate, subagent lifecycle, and statusline." >&2
fi
