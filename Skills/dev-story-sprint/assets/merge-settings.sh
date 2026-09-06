#!/usr/bin/env bash
# merge-settings.sh [--quiet] <settings-path> <allow-json-path> <hook-command-path>
#
# Merges an allowlist (permissions.allow, set union) and a PostToolUse(Bash) hook
# registration into a Claude settings.json, preserving every other key. Atomic
# write via tempfile + os.replace. Without --quiet, prints "ok:" lines when
# already up to date, or a "merged:" line when it changed. With --quiet, prints
# the "merged:" line on change and nothing otherwise. Exits non-zero only on a
# real error (no python3, missing/unreadable/invalid-JSON settings or allow file).
set -euo pipefail

QUIET=0
if [ "${1:-}" = "--quiet" ]; then
  QUIET=1
  shift
fi

if [ $# -ne 3 ]; then
  echo "usage: merge-settings.sh [--quiet] <settings-path> <allow-json-path> <hook-command-path>" >&2
  exit 1
fi

SETTINGS="$1"
ALLOW_SRC="$2"
HOOK_CMD="$3"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 not found — cannot merge settings.json" >&2
  exit 1
fi

python3 - "$SETTINGS" "$ALLOW_SRC" "$HOOK_CMD" "$QUIET" <<'PY'
import json, os, sys, tempfile
settings_path, allow_path, hook_cmd, quiet = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
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
elif not quiet:
    print(f"ok:        permissions.allow has all {len(wanted)} sprint entries")

# hooks.PostToolUse — one Bash-matcher entry for the refresh hook, keyed on its command path
hooks = dict(settings.get("hooks", {}))
post = list(hooks.get("PostToolUse", []))
present = any(h.get("command") == hook_cmd for e in post for h in e.get("hooks", []))
if not present:
    post = post + [{"matcher": "Bash", "hooks": [{"type": "command", "command": hook_cmd}]}]
    hooks = {**hooks, "PostToolUse": post}
    changed.append("PostToolUse refresh-live hook")
elif not quiet:
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
