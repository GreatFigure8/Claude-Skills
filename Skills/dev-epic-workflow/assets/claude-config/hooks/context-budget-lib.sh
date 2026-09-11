#!/usr/bin/env bash
# Shared context-budget helpers — sourced, never executed.
#
# Extracted verbatim from context-budget-gate.sh so that more than one hook can
# resolve the SAME session slug, mode, thresholds and sentinel reading. Any
# divergence between two copies of this logic is a gate that disagrees with
# itself about whether the session is over budget, so there is exactly one copy.
#
# Every function here communicates through plain globals (the gate reads them
# straight after the call) and none of them exits: fail-open policy stays with
# the caller, which is the only thing that knows what "open" means for it.

# A bare integer, nothing else — `case` keeps this parser-free and locale-safe.
is_int() {
  case "${1:-}" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Session id -> filename-safe slug for .claude/signals/context-usage-<slug>.
# Prints the slug; prints nothing when the id yields none (caller decides).
session_slug_for() {
  printf '%s' "${1:-}" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-64 2> /dev/null || true
}

# --- MODE: sprint (dev-story-sprint) vs epic (dev-epic-workflow). -------------
# $1 = signals dir. Sets MODE, DEF_SOFT, DEF_HARD, RULE, HANDOFF, STATE.
resolve_mode() {
  SIGNALS_DIR_ARG="${1:-.claude/signals}"
  MODE=epic
  ACTIVE_EPIC="$SIGNALS_DIR_ARG/active-epic"
  if [ -f "$ACTIVE_EPIC" ] && [ -r "$ACTIVE_EPIC" ]; then
    while IFS= read -r LINE || [ -n "$LINE" ]; do
      LINE="${LINE%$'\r'}"
      LINE="${LINE#"${LINE%%[![:space:]]*}"}"
      LINE="${LINE%"${LINE##*[![:space:]]}"}"
      [ -n "$LINE" ] || continue
      case "$LINE" in *".claude/stories/"*) MODE=sprint ;; esac
      break
    done < "$ACTIVE_EPIC"
  fi

  if [ "$MODE" = sprint ]; then
    DEF_SOFT=150000; DEF_HARD=165000
    RULE="dev-story-sprint rule 9"
    HANDOFF="the dev-story-sprint prep-for-clear prompt"
    STATE="sprint.json, with every in-flight story's pushed branch in its detail field"
  else
    DEF_SOFT=120000; DEF_HARD=150000
    RULE="dev-epic-workflow context budget"
    HANDOFF="the dev-epic-workflow handoff at docs/epics/handoff.md"
    STATE="each in-flight item's status/<branch-slug>.json record, with its pushed branch in the detail field"
  fi
}

# --- Thresholds: env, then .claude/context-budget, then mode defaults. --------
# Requires MODE/DEF_SOFT/DEF_HARD (see resolve_mode). Sets SOFT, HARD, STOP.
# Values are NOT validated here — the caller decides what a bad pair means.
resolve_thresholds() {
  SOFT=""; HARD=""; STOP=""
  if [ -n "${CONTEXT_BUDGET_SOFT_TOKENS:-}" ] || [ -n "${CONTEXT_BUDGET_HARD_TOKENS:-}" ]; then
    SOFT="${CONTEXT_BUDGET_SOFT_TOKENS:-}"
    HARD="${CONTEXT_BUDGET_HARD_TOKENS:-}"
  fi
  if [ -n "${CONTEXT_BUDGET_STOP_TOKENS:-}" ]; then
    STOP="${CONTEXT_BUDGET_STOP_TOKENS:-}"
  fi

  SOFT_HARD_FROM_ENV=1
  if [ -z "$SOFT" ] || [ -z "$HARD" ]; then
    SOFT_HARD_FROM_ENV=0
  fi
  if [ -z "$SOFT" ] || [ -z "$HARD" ] || [ -z "$STOP" ]; then
    BUDGET_FILE=".claude/context-budget"
    if [ -f "$BUDGET_FILE" ] && [ -r "$BUDGET_FILE" ]; then
      F_SOFT=""; F_HARD=""; F_STOP=""
      while IFS= read -r LINE || [ -n "$LINE" ]; do
        LINE="${LINE%$'\r'}"
        LINE="${LINE#"${LINE%%[![:space:]]*}"}"
        LINE="${LINE%"${LINE##*[![:space:]]}"}"
        case "$LINE" in '' | '#'*) continue ;; esac
        case "$LINE" in *=*) ;; *) continue ;; esac
        KEY="${LINE%%=*}"; VALUE="${LINE#*=}"
        KEY="${KEY%"${KEY##*[![:space:]]}"}"
        VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
        VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"
        case "$KEY" in
          soft) F_SOFT="$VALUE" ;;
          hard) F_HARD="$VALUE" ;;
          stop) F_STOP="$VALUE" ;;
        esac
      done < "$BUDGET_FILE"
      if [ "$SOFT_HARD_FROM_ENV" -eq 0 ] && [ -n "$F_SOFT" ] && [ -n "$F_HARD" ]; then
        SOFT="$F_SOFT"; HARD="$F_HARD"
      fi
      if [ -z "$STOP" ] && [ -n "$F_STOP" ]; then
        STOP="$F_STOP"
      fi
    fi
  fi

  if [ -z "$SOFT" ] || [ -z "$HARD" ]; then
    SOFT="$DEF_SOFT"; HARD="$DEF_HARD"
  fi

  if [ -z "$STOP" ]; then
    if [ "$MODE" = sprint ]; then
      STOP=160000
    else
      STOP="$HARD"
    fi
  fi
}

# --- Parse the sentinel: plain key=value lines, last wins, keys we know only. -
# $1 = sentinel path. Sets EPOCH, USED_TOKENS, MAX_TOKENS, USED_PCT (each ""
# when the file omits it — the sentinel OMITS unknowns, never empties them).
read_sentinel() {
  EPOCH=""; USED_TOKENS=""; MAX_TOKENS=""; USED_PCT=""
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%$'\r'}"
    case "$LINE" in
      epoch=*) EPOCH="${LINE#epoch=}" ;;
      used_tokens=*) USED_TOKENS="${LINE#used_tokens=}" ;;
      max_tokens=*) MAX_TOKENS="${LINE#max_tokens=}" ;;
      used_percentage=*) USED_PCT="${LINE#used_percentage=}" ;;
    esac
  done < "${1:-/dev/null}"
}
