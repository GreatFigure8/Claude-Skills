#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash). After any `git push` run from the claude-skills repo,
# fast-forward the live skills worktree (~/Source/claude-skills-main, checked out on branch
# main and never switched) so what Claude Code loads follows origin/main with no human step. Registered by
# dev-story-sprint/assets/install.sh. Must never fail the tool call: exit 0 always.
set -u
LIVE="${CLAUDE_SKILLS_LIVE:-$HOME/Source/claude-skills-main}"
INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

PARSED="$(printf '%s' "$INPUT" | python3 -c '
import json, os, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
cmd = (d.get("tool_input") or {}).get("command") or ""
cwd = str(d.get("cwd") or "")

push = False
git_dir = cwd
try:
    tokens = shlex.split(cmd)
except ValueError:
    tokens = []
i = 0
while i < len(tokens):
    if tokens[i] == "git":
        j, resolved = i + 1, cwd
        while j + 1 < len(tokens) and tokens[j] == "-C":
            p = tokens[j + 1]
            resolved = p if os.path.isabs(p) else os.path.join(resolved, p)
            j += 2
        k = j
        while k < len(tokens) and tokens[k] != "git":
            k += 1
        args = tokens[j:k]
        if "push" in args and "--dry-run" not in args:
            push = True
            git_dir = resolved
        i = j
    else:
        i += 1

print("|".join([str(d.get("tool_name", "")), "PUSH" if push else "NOPUSH", cwd, git_dir]))
' 2>/dev/null)"
IFS='|' read -r TOOL PUSH CWD GITDIR <<<"$PARSED"
[ "${TOOL:-}" = "Bash" ] && [ "${PUSH:-}" = "PUSH" ] || exit 0
[ -n "${CWD:-}" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "${GITDIR:-}" ] || GITDIR="$CWD"

# Only act when the push came from a checkout of the same repository as the live worktree.
[ -e "$LIVE/.git" ] || exit 0
LIVE_COMMON="$(git -C "$LIVE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
CWD_COMMON="$(git -C "$GITDIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[ -n "$LIVE_COMMON" ] && [ "$LIVE_COMMON" = "$CWD_COMMON" ] || exit 0

if git -C "$LIVE" fetch -q origin 2>/dev/null && git -C "$LIVE" merge -q --ff-only origin/main 2>/dev/null; then
  echo "live skills refreshed: $(git -C "$LIVE" log --oneline -1 2>/dev/null)"

  # Merge the freshly-refreshed allowlist into the running session's settings, so a
  # new Bash(...) prefix goes live the same way skill file edits already do. Claude
  # Code watches settings.json and reloads `permissions` live, without a restart —
  # see https://code.claude.com/docs/en/settings.md. Read the allow file from LIVE
  # AFTER the fast-forward above, so this merges what just went live.
  MERGE_SCRIPT="$LIVE/Skills/dev-story-sprint/assets/merge-settings.sh"
  ALLOW_JSON="$LIVE/Skills/dev-story-sprint/assets/permissions-allow.json"
  if [ -e "$MERGE_SCRIPT" ] && [ -e "$ALLOW_JSON" ]; then
    "$MERGE_SCRIPT" --quiet "$HOME/.claude/settings.json" "$ALLOW_JSON" \
      "$LIVE/Skills/dev-story-sprint/assets/hooks/refresh-live-post-push.sh" \
      2>/dev/null || echo "settings allowlist merge FAILED for $LIVE" >&2
  fi
else
  echo "live skills refresh FAILED for $LIVE — run Skills/dev-story-sprint/assets/refresh-live.sh" >&2
fi
exit 0
