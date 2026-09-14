#!/usr/bin/env bash
# install.sh — dev-epic-workflow session automation + executor control plane.
# Installs the SessionStart/PreCompact/SessionEnd hooks, the executor control
# plane (cancel gate, subagent lifecycle, tool logger), the work-item-executor
# agent, the /handoff, /intake and /issue-loop commands, and the statusline.
#
# `bin/` is deliberately NOT installed: those scripts are invoked from the
# skill directory by absolute path (`session-loop.sh`, `declared-paths-gate.sh`
# and friends), so there is one copy per machine and no second one to drift.
#
# Two modes:
#
#   --user            install ONCE per machine into ~/.claude/ — applies to
#                     EVERY repo and worktree automatically (recommended
#                     default; nothing is committed into any repo)
#   (default: repo)   install into the current repo's .claude/ — committed,
#                     so it travels with the repo (for cloud sessions,
#                     teammates, or repos that must be self-contained)
#   --commit          repo mode only: also create the bootstrap chore commit
#
# Idempotent in both modes: safe to re-run to pick up updated scripts.
# Do NOT install both modes for the same repo — hooks append, so both would
# fire and duplicate the SessionStart injection (harmless, but noisy).
#
# Usage:
#   bash <skill-path>/assets/claude-config/install.sh --user
#   bash <skill-path>/assets/claude-config/install.sh [--commit]   # from inside a repo

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="repo"
DO_COMMIT="no"
for arg in "$@"; do
  case "$arg" in
    --user)   MODE="user" ;;
    --commit) DO_COMMIT="yes" ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ "$MODE" = "user" ]; then
  TARGET_DIR="$HOME/.claude"
  CMD_PREFIX="\$HOME/.claude/hooks"
  echo "Installing dev-epic-workflow automation at USER level: $TARGET_DIR"
  echo "  (applies to every repo and worktree on this machine)"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: not inside a git repository. cd into the target repo, or use --user." >&2
    exit 1
  }
  cd "$REPO_ROOT"
  TARGET_DIR="$REPO_ROOT/.claude"
  CMD_PREFIX="\$CLAUDE_PROJECT_DIR/.claude/hooks"
  echo "Installing dev-epic-workflow automation into repo: $REPO_ROOT"
fi

# 1. Copy hooks, the /handoff command, and the executor agent.
mkdir -p "$TARGET_DIR/hooks" "$TARGET_DIR/commands" "$TARGET_DIR/agents"
cp "$SRC_DIR"/hooks/session-start-context.sh \
   "$SRC_DIR"/hooks/precompact-snapshot.sh \
   "$SRC_DIR"/hooks/session-end-guard.sh \
   "$SRC_DIR"/hooks/statusline.sh \
   "$SRC_DIR"/hooks/cancel-gate.sh \
   "$SRC_DIR"/hooks/context-budget-gate.sh \
   "$SRC_DIR"/hooks/context-budget-lib.sh \
   "$SRC_DIR"/hooks/handoff-stop-gate.sh \
   "$SRC_DIR"/hooks/subagent-lifecycle.sh \
   "$SRC_DIR"/hooks/subagent-tool-logger.sh \
   "$TARGET_DIR/hooks/"
cp "$SRC_DIR"/commands/handoff.md "$SRC_DIR"/commands/intake.md "$SRC_DIR"/commands/issue-loop.md \
   "$TARGET_DIR/commands/"
cp "$SRC_DIR"/agents/work-item-executor.md "$TARGET_DIR/agents/"
chmod +x "$TARGET_DIR"/hooks/*.sh
echo "  ✓ hooks → $TARGET_DIR/hooks/ (10 scripts, executable)"
echo "  ✓ /handoff + /intake + /issue-loop commands → $TARGET_DIR/commands/"
echo "  ✓ work-item-executor agent → $TARGET_DIR/agents/work-item-executor.md"

# 2. Merge hook wiring into settings.json without clobbering.
python3 - "$SRC_DIR/settings-hooks.json" "$TARGET_DIR/settings.json" "$CMD_PREFIX" << 'PYEOF'
import json, sys, os

src_path, dst_path, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src_path) as f:
    src = json.load(f)
src.pop("$comment", None)

# Rewrite command paths for the chosen install mode.
def repath(cmd):
    return prefix + "/" + os.path.basename(cmd)

src["statusLine"]["command"] = repath(src["statusLine"]["command"])
for groups in src["hooks"].values():
    for g in groups:
        for h in g.get("hooks", []):
            h["command"] = repath(h["command"])

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
            # Already installed — still reconcile a stale/missing matcher on
            # whichever existing group(s) own these commands, in place.
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

# 3. Repo mode extras: gitignore runtime state, optional commit.
if [ "$MODE" = "repo" ]; then
  for LINE in ".claude/handoff-autosnapshot.md" \
              "docs/epics/handoff-autosnapshot.md" \
              ".claude/signals/" \
              "docs/epics/*/status/" \
              "docs/epics/*/CANCEL"; do
    if ! grep -qxF "$LINE" .gitignore 2>/dev/null; then
      echo "$LINE" >> .gitignore
      echo "  ✓ .gitignore → $LINE"
    fi
  done
  if [ "$DO_COMMIT" = "yes" ]; then
    git add .claude .gitignore
    if git diff --cached --quiet; then
      echo "  • nothing to commit — automation already installed"
    else
      git commit -m "chore: session + executor automation (hooks, agent, /handoff, statusline)"
      echo "  ✓ committed: chore: session + executor automation"
    fi
  else
    echo
    echo "Not committed. Review with 'git status', then commit .claude and .gitignore,"
    echo "or re-run with --commit."
  fi
else
  echo
  echo "NOTE (user mode): runtime state lines are NOT gitignored globally. When filing"
  echo "an epic plan (Phase 1), ensure the repo's .gitignore contains:"
  echo "  .claude/signals/  docs/epics/*/status/  docs/epics/*/CANCEL"
fi

echo
echo "Done. Takes effect on the NEXT session started$([ "$MODE" = user ] && echo " in any repo on this machine" || echo " in this repo")."
