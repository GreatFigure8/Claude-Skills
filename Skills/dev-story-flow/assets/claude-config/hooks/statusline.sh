#!/usr/bin/env bash
# Statusline — shared: branch | model | context usage (dev-story-flow / dev-story-sprint / dev-epic-workflow).
# Receives session JSON on stdin; prints one line.
# Parses with jq when available, falls back to python3, degrades to branch-only.
# Statusline input fields evolve across Claude Code releases; context usage is
# probed across several known field paths and omitted when absent — if the
# percentage stops rendering after an update, check the current statusline docs
# and adjust the probes. Never fail: always print something.
#
# Side effect: as it renders, this script also writes the parsed context usage
# to a sentinel under ${CLAUDE_PROJECT_DIR:-.}/.claude/signals/ — see
# context-budget-gate contract section 1. Consumer: the PreToolUse
# context-budget-gate.sh hook, which reads the sentinel to decide whether to
# nudge or block further Agent dispatch. Sentinel writes are best-effort and
# must never change this script's printed output or exit code.

set -u
INPUT="$(cat 2>/dev/null || true)"

BRANCH="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || true)"
[ -z "$BRANCH" ] && BRANCH="no-git"

MODEL=""
CTX=""
SENT_SID=""
SENT_UT=""
SENT_MT=""
SENT_UP=""
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
    SENT_SID="$(printf '%s' "$INPUT" | jq -r '(.session_id? // empty) | tostring' 2>/dev/null || true)"
    SENT_UT="$(printf '%s' "$INPUT" | jq -r '(.context_window.used_tokens? // empty) | if type == "number" then (. | floor | tostring) else empty end' 2>/dev/null || true)"
    SENT_MT="$(printf '%s' "$INPUT" | jq -r '(.context_window.max_tokens? // empty) | if type == "number" then (. | floor | tostring) else empty end' 2>/dev/null || true)"
    SENT_UP="$(printf '%s' "$INPUT" | jq -r '
      ( .context_window.used_percentage
        // .context_window.used_percent
        // .context.used_percent
        // empty
      ) | if type == "number" then (. | floor | tostring) else empty end
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
sid = d.get("session_id")
sid = sid if isinstance(sid, str) else ""
ut = cw.get("used_tokens")
ut = str(int(ut)) if isinstance(ut, (int, float)) else ""
mt = cw.get("max_tokens")
mt = str(int(mt)) if isinstance(mt, (int, float)) else ""
up = ""
for v in (cw.get("used_percentage"), cw.get("used_percent"), c.get("used_percent")):
    if isinstance(v, (int, float)):
        up = str(int(v)); break
print(sid); print(ut); print(mt); print(up)
' 2>/dev/null || true)"
    MODEL="$(printf '%s\n' "$PARSED" | sed -n '1p')"
    CTX="$(printf '%s\n' "$PARSED" | sed -n '2p')"
    SENT_SID="$(printf '%s\n' "$PARSED" | sed -n '3p')"
    SENT_UT="$(printf '%s\n' "$PARSED" | sed -n '4p')"
    SENT_MT="$(printf '%s\n' "$PARSED" | sed -n '5p')"
    SENT_UP="$(printf '%s\n' "$PARSED" | sed -n '6p')"
  fi
fi

# Write the context-usage sentinel (best-effort, silent on any failure). Never
# lets a write error affect the line already computed above.
write_context_sentinel() {
  [ -z "$SENT_UT" ] && [ -z "$SENT_UP" ] && return 0
  local base epoch content tmp generic slug perfile
  base="${CLAUDE_PROJECT_DIR:-.}/.claude/signals"
  mkdir -p "$base" 2>/dev/null || return 0
  epoch="$(date +%s 2>/dev/null || true)"
  case "$epoch" in
    (*[!0-9]*|'') return 0 ;;
  esac
  content="epoch=${epoch}"$'\n'
  [ -n "$SENT_SID" ] && content="${content}session_id=${SENT_SID}"$'\n'
  [ -n "$SENT_UT" ] && content="${content}used_tokens=${SENT_UT}"$'\n'
  [ -n "$SENT_MT" ] && content="${content}max_tokens=${SENT_MT}"$'\n'
  [ -n "$SENT_UP" ] && content="${content}used_percentage=${SENT_UP}"$'\n'

  generic="${base}/context-usage"
  tmp="$(mktemp "${base}/.context-usage.XXXXXX" 2>/dev/null || true)"
  if [ -n "$tmp" ]; then
    printf '%s' "$content" > "$tmp" 2>/dev/null && mv -f "$tmp" "$generic" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  fi

  if [ -n "$SENT_SID" ]; then
    slug="$(printf '%s' "$SENT_SID" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64 2>/dev/null || true)"
    if [ -n "$slug" ]; then
      perfile="${base}/context-usage-${slug}"
      tmp="$(mktemp "${base}/.context-usage.XXXXXX" 2>/dev/null || true)"
      if [ -n "$tmp" ]; then
        printf '%s' "$content" > "$tmp" 2>/dev/null && mv -f "$tmp" "$perfile" 2>/dev/null || rm -f "$tmp" 2>/dev/null
      fi
    fi
  fi
  return 0
}
write_context_sentinel 2>/dev/null || true

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
