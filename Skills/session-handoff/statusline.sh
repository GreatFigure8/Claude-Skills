#!/usr/bin/env bash
# Statusline — dev-epic-workflow: branch | model | context usage.
# Receives session JSON on stdin; prints one line.
# Parses with jq when available, falls back to python3, degrades to branch-only.
# Statusline input fields evolve across Claude Code releases; context usage is
# probed across several known field paths and omitted when absent — if the
# percentage stops rendering after an update, check the current statusline docs
# and adjust the probes. Never fail: always print something.

set -u
INPUT="$(cat 2>/dev/null || true)"

BRANCH="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || true)"
[ -z "$BRANCH" ] && BRANCH="no-git"

MODEL=""
CTX=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    MODEL="$(printf '%s' "$INPUT" | jq -r '.model.display_name // .model.id // (.model | strings) // empty' 2>/dev/null || true)"
    CTX="$(printf '%s' "$INPUT" | jq -r '
      ( .context_window.used_percentage
        // .context_window.used_percent
        // .context.used_percent
        // (if (.context_window.used_tokens? != null) and (.context_window.max_tokens? != null) and (.context_window.max_tokens > 0)
            then (.context_window.used_tokens / .context_window.max_tokens * 100)
            else empty end)
      ) // empty
      | if type == "number" then (. | floor | tostring) + "%" else tostring end
    ' 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    PARSED="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
m = d.get("model")
model = (m.get("display_name") or m.get("id") or "") if isinstance(m, dict) else (m if isinstance(m, str) else "")
ctx = ""
cw = d.get("context_window") or {}
c = d.get("context") or {}
for v in (cw.get("used_percentage"), cw.get("used_percent"), c.get("used_percent")):
    if isinstance(v, (int, float)):
        ctx = f"{int(v)}%"; break
if not ctx:
    u, mx = cw.get("used_tokens"), cw.get("max_tokens")
    if isinstance(u, (int, float)) and isinstance(mx, (int, float)) and mx > 0:
        ctx = f"{int(u / mx * 100)}%"
print(model); print(ctx)
' 2>/dev/null || true)"
    MODEL="$(printf '%s\n' "$PARSED" | sed -n '1p')"
    CTX="$(printf '%s\n' "$PARSED" | sed -n '2p')"
  fi
fi

LINE="⎇ ${BRANCH}"
[ -n "$MODEL" ] && LINE="${LINE} | ${MODEL}"
if [ -n "$CTX" ] && [ "$CTX" != "null" ]; then
  LINE="${LINE} | ctx ${CTX}"
  PCT="${CTX%\%}"
  case "$PCT" in
    (*[!0-9]*) : ;;
    (*) [ "$PCT" -ge 50 ] 2>/dev/null && LINE="${LINE} → /handoff" ;;
  esac
fi

printf '%s\n' "$LINE"
exit 0
