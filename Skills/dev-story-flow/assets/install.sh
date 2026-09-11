#!/usr/bin/env bash
# dev-story-flow installer — idempotent, user-level only. Symlinks point at wherever this
# file lives — normally the single working checkout, ~/Source/claude-skills. There is no
# separate worktree pinned to `main`: whatever branch is checked out here (and any
# uncommitted edit) is what every repo on the machine loads. Re-run this after merging to
# `main`, or whenever you want the global copies refreshed to match what's on disk here —
# nothing does that automatically. See CLAUDE.md rule 3.
#   1. symlink Skills/dev-story-flow into ~/.claude/skills
#   2. symlink Skills/goal (the `/goal using <skill> <objective>` entry point) into ~/.claude/skills
#   3. install this skill's OWN copies of the story-item-executor agent and the executor
#      control-plane hooks (cancel gate, context budget gate, hand-off stop gate, subagent
#      lifecycle, statusline) into ~/.claude/agents and ~/.claude/hooks, and merge their
#      wiring into ~/.claude/settings.json
#   4. make assets/bin and assets/tests executable
# No dependency on dev-story-sprint or dev-epic-workflow being installed: every asset this
# skill dispatches through lives under assets/agents and assets/claude-config here. If those
# sibling skills are ALSO installed, their copies of the same-named files are functionally
# interchangeable with these (shared conventions, see assets/claude-config/hooks) — whichever
# ran its installer last simply wins at the shared ~/.claude/ destination path.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"        # Skills/dev-story-flow
GOAL="$(cd "$HERE/../goal" 2>/dev/null && pwd || true)"
SKILLS_DEST="${HOME}/.claude/skills"
mkdir -p "$SKILLS_DEST" "${HOME}/.claude/agents" "${HOME}/.claude/hooks"
chmod +x "$HERE"/assets/*.sh "$HERE"/assets/bin/*.sh "$HERE"/assets/tests/*.sh "$HERE"/assets/claude-config/hooks/*.sh 2>/dev/null || true

link() { # link <target> <linkpath>
  local target="$1" link="$2"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then echo "ok:        $link -> $target"; return 0; fi
  if [ -e "$link" ] && [ ! -L "$link" ]; then mv "$link" "$link.bak"; echo "moved:     $link -> $link.bak"; fi
  ln -sfn "$target" "$link"; echo "linked:    $link -> $target"
}

link "$HERE" "$SKILLS_DEST/dev-story-flow"
if [ -n "$GOAL" ]; then link "$GOAL" "$SKILLS_DEST/goal"; else echo "warning: Skills/goal not found beside dev-story-flow — /goal entry point not installed" >&2; fi

# 1. story-item-executor agent.
cp "$HERE/assets/agents/story-item-executor.md" "${HOME}/.claude/agents/story-item-executor.md"
echo "  ✓ story-item-executor agent → ${HOME}/.claude/agents/story-item-executor.md"

# 2. Executor control-plane hooks + statusline.
cp "$HERE"/assets/claude-config/hooks/*.sh "${HOME}/.claude/hooks/"
chmod +x "${HOME}"/.claude/hooks/*.sh
echo "  ✓ control-plane hooks → ${HOME}/.claude/hooks/ (6 scripts, executable)"

# 3. Merge hook wiring into settings.json without clobbering. Needs python3.
if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found — skipping the settings.json hook-wiring merge and assets/bin/sprint-state.sh will not run. Install python3, then re-run this script." >&2
else
python3 - "$HERE/assets/claude-config/settings-hooks.json" "${HOME}/.claude/settings.json" << 'PYEOF'
import json, sys, os

src_path, dst_path = sys.argv[1], sys.argv[2]
with open(src_path) as f:
    src = json.load(f)
src.pop("$comment", None)

dst = {}
if os.path.exists(dst_path):
    with open(dst_path) as f:
        try:
            dst = json.load(f)
        except json.JSONDecodeError:
            sys.exit(f"ERROR: {dst_path} exists but is not valid JSON — fix it, then re-run.")

changed = []

# statusLine: set only if absent (never clobber an existing statusline).
if "statusLine" not in dst:
    dst["statusLine"] = src["statusLine"]
    changed.append("statusLine")
else:
    print("  • statusLine already configured — left untouched "
          "(point it at hooks/statusline.sh manually if you want ours)")

# hooks: append our matcher-groups per event, skipping any group whose command
# set is already wired (idempotence keyed on the command paths).
dst_hooks = dst.setdefault("hooks", {})
for event, src_groups in src["hooks"].items():
    dst_groups = dst_hooks.setdefault(event, [])
    existing_cmds = {
        h.get("command")
        for g in dst_groups if isinstance(g, dict)
        for h in g.get("hooks", []) if isinstance(h, dict)
    }
    for group in src_groups:
        cmds = {h.get("command") for h in group.get("hooks", [])}
        if cmds <= existing_cmds:
            matcher_changed = False
            for g in dst_groups:
                if not isinstance(g, dict):
                    continue
                g_cmds = {
                    h.get("command") for h in g.get("hooks", []) if isinstance(h, dict)
                }
                if not (g_cmds & cmds):
                    continue
                if "matcher" not in group:
                    if "matcher" in g:
                        g.pop("matcher", None)
                        matcher_changed = True
                elif g.get("matcher") != group["matcher"]:
                    g["matcher"] = group["matcher"]
                    matcher_changed = True
            if matcher_changed:
                changed.append(f"{event} (matcher)")
            continue  # already installed
        dst_groups.append(group)
        changed.append(event)

with open(dst_path, "w") as f:
    json.dump(dst, f, indent=2)
    f.write("\n")

print(f"  ✓ settings merged → {dst_path}" +
      (f" (added: {', '.join(changed)})" if changed else " (already up to date)"))
PYEOF
fi

echo "NOTE (user mode): runtime state lines are NOT gitignored globally. In any repo that"
echo "runs dev-story-flow, ensure .gitignore contains: .claude/signals/  .claude/stories/"
