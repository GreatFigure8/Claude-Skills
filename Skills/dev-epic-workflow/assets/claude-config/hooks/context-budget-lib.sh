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

# --- Final handoff sentence for the STOP-band nudge and the HARD-band deny. --
# $1 = signals dir (same convention as resolve_mode). Prints the sentence on
# stdout; sets nothing. Self-contained — does NOT read MODE/HANDOFF from a
# prior resolve_mode call, so it gives the same answer whenever it runs.
#
# UNIT: the story-sprint slug named by .claude/signals/active-epic's first
# non-empty line, when that line names a path under .claude/stories/ — the
# path segment immediately after that marker, same trim/first-line rule
# resolve_mode uses to decide MODE=sprint. No such line -> epic mode, no UNIT.
#
# Sprint mode (UNIT resolved): which /clear-prompt invocation matches the
# phase recorded in docs/sprints/<UNIT>/sprint.json's top-level "status"
# (planning -> plan, executing -> execute); no matching manifest, or any
# other status, falls back to the plain dev-story-sprint caller.
handoff_sentence() {
  HS_SIGNALS_DIR="${1:-.claude/signals}"
  HS_SPRINT_LINE=no
  HS_UNIT=""
  HS_ACTIVE_EPIC="$HS_SIGNALS_DIR/active-epic"
  if [ -f "$HS_ACTIVE_EPIC" ] && [ -r "$HS_ACTIVE_EPIC" ]; then
    while IFS= read -r HS_LINE || [ -n "$HS_LINE" ]; do
      HS_LINE="${HS_LINE%$'\r'}"
      HS_LINE="${HS_LINE#"${HS_LINE%%[![:space:]]*}"}"
      HS_LINE="${HS_LINE%"${HS_LINE##*[![:space:]]}"}"
      [ -n "$HS_LINE" ] || continue
      case "$HS_LINE" in
        *".claude/stories/"*)
          HS_SPRINT_LINE=yes
          HS_REST="${HS_LINE#*.claude/stories/}"
          HS_UNIT="${HS_REST%%/*}"
          ;;
      esac
      break
    done < "$HS_ACTIVE_EPIC"
  fi

  # Genuinely no sprint signal at all -> epic mode.
  if [ "$HS_SPRINT_LINE" = no ]; then
    printf '%s' "Then write docs/epics/handoff.md per dev-epic-workflow's /handoff and commit it."
    return 0
  fi

  # Sprint signal present but no usable unit segment after it — neither the
  # sprint case nor the epic case resolves cleanly. Do not invent wording:
  # repeat the gate's own already-resolved generic reference.
  if [ -z "$HS_UNIT" ]; then
    printf '%s' "${HANDOFF:-}"
    return 0
  fi

  # Canonical repo root — same resolution subagent-lifecycle.sh uses, so a
  # linked worktree still finds the manifest at the MAIN checkout's root.
  HS_REPO_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null || true)"
  if [ -n "$HS_REPO_ROOT" ]; then
    HS_REPO_ROOT="$(dirname "$HS_REPO_ROOT" 2> /dev/null || true)"
  else
    HS_REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || true)"
  fi
  [ -n "$HS_REPO_ROOT" ] && [ -d "$HS_REPO_ROOT" ] || HS_REPO_ROOT="$(pwd)"

  HS_CALLER="dev-story-sprint"
  HS_MANIFEST="$HS_REPO_ROOT/docs/sprints/$HS_UNIT/sprint.json"
  if [ -f "$HS_MANIFEST" ] && [ -r "$HS_MANIFEST" ]; then
    HS_STATUS="$(grep -m1 -E '^  "status"[[:space:]]*:' "$HS_MANIFEST" 2> /dev/null \
      | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/' 2> /dev/null || true)"
    case "$HS_STATUS" in
      planning) HS_CALLER="dev-story-flow plan" ;;
      executing) HS_CALLER="dev-story-flow execute" ;;
      *) HS_CALLER="dev-story-sprint" ;;
    esac
  fi

  printf '%s' "Then call Skill({skill: \"clear-prompt\", args: \"${HS_CALLER} ${HS_UNIT}\"}) — it posts the hand-off and clears this session."
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
