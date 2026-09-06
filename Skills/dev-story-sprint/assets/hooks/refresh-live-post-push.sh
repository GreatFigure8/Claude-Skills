#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash). After any `git push` run from the claude-skills repo,
# refresh the live skills worktree (~/Source/claude-skills-main, detached at origin/main) so
# what Claude Code loads follows origin/main with no human step. Registered by
# dev-story-sprint/assets/install.sh. Must never fail the tool call: exit 0 always.
set -u
LIVE="${CLAUDE_SKILLS_LIVE:-$HOME/Source/claude-skills-main}"
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

PARSED="$(printf '%s' "$INPUT" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd=(d.get("tool_input") or {}).get("command") or ""
push = "git push" in cmd and "--dry-run" not in cmd
print("|".join([str(d.get("tool_name","")), "PUSH" if push else "NOPUSH", str(d.get("cwd") or "")]))
' 2>/dev/null)"
IFS='|' read -r TOOL PUSH CWD <<<"$PARSED"
[ "${TOOL:-}" = "Bash" ] && [ "${PUSH:-}" = "PUSH" ] || exit 0
[ -n "${CWD:-}" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Only act when the push came from a checkout of the same repository as the live worktree.
[ -e "$LIVE/.git" ] || exit 0
LIVE_COMMON="$(git -C "$LIVE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
CWD_COMMON="$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[ -n "$LIVE_COMMON" ] && [ "$LIVE_COMMON" = "$CWD_COMMON" ] || exit 0

if git -C "$LIVE" fetch -q origin 2>/dev/null && git -C "$LIVE" checkout -q --detach origin/main 2>/dev/null; then
  echo "live skills refreshed: $(git -C "$LIVE" log --oneline -1 2>/dev/null)"
else
  echo "live skills refresh FAILED for $LIVE — run Skills/dev-story-sprint/assets/refresh-live.sh" >&2
fi
exit 0
