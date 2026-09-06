#!/usr/bin/env bash
# dev-story-sprint installer — four idempotent steps. Run it FROM THE LIVE WORKTREE
# (~/Source/claude-skills-main), because the symlinks and hook point at wherever this file lives.
#   1. symlink the skill dir into ~/.claude/skills
#   2. symlink the story-item-executor agent into ~/.claude/agents
#   3. merge assets/permissions-allow.json into ~/.claude/settings.json permissions.allow
#   4. register assets/hooks/refresh-live-post-push.sh as a PostToolUse(Bash) hook so every
#      `git push` from this repo refreshes the live worktree — no human "go live" step
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
  *) echo "note: running from $HERE — symlinks will point here, not at the live worktree. See SKILL.md Install." >&2 ;;
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
  python3 - "$SETTINGS" "$ALLOW_SRC" "$HOOK_CMD" <<'PY'
import json, os, sys, tempfile
settings_path, allow_path, hook_cmd = sys.argv[1], sys.argv[2], sys.argv[3]
with open(allow_path) as f:
    wanted = json.load(f)["allow"]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
changed = []

# permissions.allow — set union
perms = dict(settings.get("permissions", {}))
current = list(perms.get("allow", []))
missing = [e for e in wanted if e not in current]
if missing:
    perms = {**perms, "allow": current + missing}
    changed.append(f"{len(missing)} allow entries")
else:
    print(f"ok:        permissions.allow has all {len(wanted)} sprint entries")

# hooks.PostToolUse — one Bash-matcher entry for the refresh hook, keyed on its command path
hooks = dict(settings.get("hooks", {}))
post = list(hooks.get("PostToolUse", []))
present = any(h.get("command") == hook_cmd for e in post for h in e.get("hooks", []))
if not present:
    post = post + [{"matcher": "Bash", "hooks": [{"type": "command", "command": hook_cmd}]}]
    hooks = {**hooks, "PostToolUse": post}
    changed.append("PostToolUse refresh-live hook")
else:
    print(f"ok:        PostToolUse hook registered: {hook_cmd}")

if not changed:
    sys.exit(0)
new_settings = {**settings, "permissions": perms, "hooks": hooks}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path) or ".", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(new_settings, f, indent=2)
    f.write("\n")
os.replace(tmp, settings_path)
print(f"merged:    {', '.join(changed)} into {settings_path}")
PY
fi

if [ ! -f "${HOME}/.claude/hooks/cancel-gate.sh" ]; then
  echo "warning: ~/.claude/hooks/cancel-gate.sh not found — run dev-epic-workflow's install.sh --user for the cancel gate, subagent lifecycle, and statusline." >&2
fi
