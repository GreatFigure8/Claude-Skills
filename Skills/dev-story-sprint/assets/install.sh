#!/usr/bin/env bash
# dev-story-sprint installer — three idempotent steps:
#   1. symlink the skill dir into ~/.claude/skills (edits in the repo are live immediately)
#   2. symlink the story-item-executor agent into ~/.claude/agents
#   3. merge assets/permissions-allow.json into ~/.claude/settings.json permissions.allow
#      (set union; existing entries, defaultMode and every other key are preserved)
# A pre-existing plain copy at a symlink target is moved aside as .bak.
# The control plane (cancel gate, subagent lifecycle, statusline) comes from
# dev-epic-workflow's user-level install; this script only warns if it's missing.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the skill dir
SKILLS_DEST="${HOME}/.claude/skills"
AGENTS_DEST="${HOME}/.claude/agents"
SETTINGS="${HOME}/.claude/settings.json"
ALLOW_SRC="$HERE/assets/permissions-allow.json"
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

# --- permissions allowlist merge -------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found — skipped merging $ALLOW_SRC into $SETTINGS" >&2
else
  python3 - "$SETTINGS" "$ALLOW_SRC" <<'PY'
import json, os, sys, tempfile
settings_path, allow_path = sys.argv[1], sys.argv[2]
with open(allow_path) as f:
    wanted = json.load(f)["allow"]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
perms = dict(settings.get("permissions", {}))
current = list(perms.get("allow", []))
missing = [e for e in wanted if e not in current]
if not missing:
    print(f"ok:        {settings_path} permissions.allow already has all {len(wanted)} sprint entries")
    sys.exit(0)
new_settings = {**settings, "permissions": {**perms, "allow": current + missing}}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path) or ".", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(new_settings, f, indent=2)
    f.write("\n")
os.replace(tmp, settings_path)
print(f"merged:    {len(missing)} entries into {settings_path} permissions.allow (now {len(current) + len(missing)})")
PY
fi

if [ ! -f "${HOME}/.claude/hooks/cancel-gate.sh" ]; then
  echo "warning: ~/.claude/hooks/cancel-gate.sh not found — run dev-epic-workflow's install.sh --user for the cancel gate, subagent lifecycle, and statusline." >&2
fi
