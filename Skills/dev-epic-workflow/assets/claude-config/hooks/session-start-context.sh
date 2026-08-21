#!/usr/bin/env bash
# SessionStart hook — dev-epic-workflow session grounding.
# stdout from this hook is injected into the session's context.
# Fires on: startup | resume | clear | compact (see settings.json matcher).
# Must never fail the session: exit 0 always.

set -u
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0

# Drain stdin (hook input JSON); capture source if jq is available.
INPUT="$(cat 2>/dev/null || true)"
SOURCE=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)"
  elif command -v python3 >/dev/null 2>&1; then
    SOURCE="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("source") or "")
except Exception: pass' 2>/dev/null || true)"
  fi
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

echo "## Session grounding (auto-injected — dev-epic-workflow)"
[ -n "$SOURCE" ] && echo "_Session source: ${SOURCE}_"
echo
echo "### Git state"
echo "- Branch: $(git branch --show-current 2>/dev/null || echo '(detached)')"
echo "- Working tree root: $(git rev-parse --show-toplevel 2>/dev/null)"

DIRTY="$(git status --short 2>/dev/null | head -15)"
if [ -n "$DIRTY" ]; then
  echo "- Status (dirty):"
  echo '```'
  echo "$DIRTY"
  echo '```'
else
  echo "- Status: clean"
fi

echo "- Recent commits:"
echo '```'
git log --oneline -5 2>/dev/null
echo '```'

WT_COUNT="$(git worktree list 2>/dev/null | wc -l | tr -d ' ')"
if [ "${WT_COUNT:-1}" -gt 1 ]; then
  echo "- Worktrees:"
  echo '```'
  git worktree list 2>/dev/null
  echo '```'
fi

# Surface any emergency autosnapshot FIRST (compaction or dirty session-end), then delete it.
for SNAP in "$(ls -t docs/epics/*/handoff-autosnapshot.md 2>/dev/null | head -1)" ".claude/handoff-autosnapshot.md"; do
  if [ -n "$SNAP" ] && [ -f "$SNAP" ]; then
    echo
    echo "### ⚠️ AUTOSNAPSHOT FOUND — a previous session compacted or ended uncleanly"
    echo "Treat all prior claims as UNVERIFIED. Re-ground from disk (Phase 0 resume rule) before continuing."
    echo
    echo '```'
    cat "$SNAP"
    echo '```'
    rm -f "$SNAP" 2>/dev/null || true
  fi
done

# Inject the newest handoff, if any.
HANDOFF="$(ls -t docs/epics/*/handoff.md 2>/dev/null | head -1)"
if [ -n "$HANDOFF" ] && [ -f "$HANDOFF" ]; then
  EPIC_DIR="$(dirname "$HANDOFF")"
  echo
  echo "### Active session handoff: ${HANDOFF}"
  echo "Epic plan: ${EPIC_DIR}/plan.md — read it before acting."
  echo "Per dev-epic-workflow Phase 0/3.5: verify everything under 'Claimed but NOT yet verified' against the repo before building on it."
  echo
  echo '```'
  cat "$HANDOFF"
  echo '```'
else
  NEWEST_PLAN="$(ls -t docs/epics/*/plan.md 2>/dev/null | head -1)"
  if [ -n "$NEWEST_PLAN" ]; then
    echo
    echo "### No active handoff. Newest epic plan: ${NEWEST_PLAN}"
  fi
fi

# Epics filed but NOT yet dispatched — the queue Jonathan plans ahead into,
# split into the TWO things that queue can mean.
# Purely local: it reads plan headers already on disk. No gh, no network, no
# bearing on the tracker call below or its ~2s cap.
#
# Vocabulary: references/plan-template.md —
# planning | approved | in flight (item N of M) | closed. In-flight epics are
# already surfaced by the handoff / newest-plan section above, and closed ones
# are done; everything else queues, in one of two buckets:
#
#   approved  -> "awaiting dispatch"  — the orchestrator can start it now.
#   planning  -> "awaiting approval"  — Phase 1's gate has NOT been crossed.
#
# The split exists because those two are not interchangeable and conflating them
# erodes the one gate this workflow actually leans on. Unattended intake
# (references/issue-intake.md) opens PRs carrying plans at `Status: planning`, so
# `planning` plans now arrive without a human ever having seen them; a line that
# called them "awaiting dispatch" would be inviting exactly the mistake the gate
# exists to prevent. A `planning` plan is never dispatchable.
#
# ...and two more that are `planning` but are NOT asking to be approved. An
# unattended proposal declares a terminal outcome in its header
# (references/issue-intake.md): `**Recommendation:** plan | no-work |
# needs-decision`. The last two get their own lines, because what they need from
# Jonathan is not approval:
#
#   no-work         -> "recommending no work" — read the evidence, then close it.
#   needs-decision  -> "awaiting a decision"  — make the call the plan refused to.
#
# Listing those under "awaiting approval" would invite the one thing they are
# designed to prevent: approving a proposal whose own conclusion is that there is
# nothing to build, or one that is holding an unmade decision. The override
# applies to the approval bucket ONLY — once a human has set `approved`, that
# human has overtaken the recommendation and it is spent.
#
# Absent or unrecognised means `plan`, so every pre-existing plan and every
# hand-written epic renders exactly as it did before.
#
# The `in flight` PHRASE is matched, not the first-word truncation the Status
# parser produces, so `in flight (items 1-2 of 2, parallel)` still counts.
#
# A plan with no parseable Status is listed, never hidden — the same
# fail-toward-visibility rule the control-plane hooks use when resolving the
# active epic. A malformed header must never make queued work invisible. It is
# listed as AWAITING APPROVAL, because that is the bucket whose mistake is
# harmless: an approved epic shown as needing approval costs one glance at the
# header, while a `planning` epic shown as dispatchable costs the gate.
#
# Order within each line is FOLDER NUMBER, not mtime: Phase 1 numbers epic
# folders by implementation sequence, so 05- is dispatched before 06- however
# recently either plan was edited. An unnumbered folder sorts last rather than
# first. Dispatch is printed before approval — it is the actionable queue, and
# keeping it first leaves the pre-split line exactly where it was.
#
# Cost discipline: this runs on EVERY session start, so the whole section is
# shell builtins — it forks nothing, at all. A head|grep|sed|tr pipeline per
# plan measured +20ms at 6 epics and +90ms at 30; piping the rows through
# sort|cut still cost ~9ms; this costs ~1ms and, having no external tool to
# lose, cannot go wrong on a stripped PATH either.
EPIC_QUEUE_MAX_NAMED=5
EPIC_QUEUE_HEADER_LINES=10

# Emit one queue line, or nothing if that bucket is empty.
#   $1 = dispatch | approval | decision | no-work
# Reads the EQ_* arrays built by epic_queue_section; EQ_BLANK_DONE makes the
# lines share a single leading blank so they render as one markdown list.
epic_queue_line() {
  EQL_BUCKET="$1"
  EQL_NAMED=""
  EQL_COUNT=0
  EQL_I=0
  while [ "$EQL_I" -lt "$EQ_TOTAL" ]; do
    if [ "${EQ_QUEUES[$EQL_I]}" = "$EQL_BUCKET" ]; then
      EQL_COUNT=$((EQL_COUNT + 1))
      if [ "$EQL_COUNT" -le "$EPIC_QUEUE_MAX_NAMED" ]; then
        if [ -z "$EQL_NAMED" ]; then
          EQL_NAMED="${EQ_NAMES[$EQL_I]}"
        else
          EQL_NAMED="${EQL_NAMED}, ${EQ_NAMES[$EQL_I]}"
        fi
      fi
    fi
    EQL_I=$((EQL_I + 1))
  done
  [ "$EQL_COUNT" -gt 0 ] || return 0

  # Every bucket but `dispatch` carries its warning in BOTH forms; the dispatch
  # line keeps the exact singular/plural wording it had before the split. The
  # two recommendation lines say `proposal`, not `epic` — an unapproved proposal
  # recommending no work is not an epic and calling it one is the mistake.
  EQL_ONE="epic"; EQL_MANY="epics"
  case "$EQL_BUCKET" in
    approval)
      EQL_NOUN="awaiting approval"
      EQL_TAIL=" — approve before dispatch; \`planning\` is never dispatchable."
      EQL_SOLO_TAIL="$EQL_TAIL" ;;
    decision)
      EQL_ONE="proposal"; EQL_MANY="proposals"
      EQL_NOUN="awaiting a decision"
      EQL_TAIL=" — each states a choice it deliberately did not make; decide it, then re-draft. Not approvable as they stand."
      EQL_SOLO_TAIL=" — it states a choice it deliberately did not make; decide it, then re-draft. Not approvable as it stands." ;;
    no-work)
      EQL_ONE="proposal"; EQL_MANY="proposals"
      EQL_NOUN="recommending no work"
      EQL_TAIL=" — read the evidence, then close them or say why they are wrong. Never dispatch one."
      EQL_SOLO_TAIL=" — read the evidence, then close it or say why it is wrong. Never dispatch one." ;;
    *)
      EQL_NOUN="awaiting dispatch"
      EQL_TAIL=" — dispatch the lowest number first."
      EQL_SOLO_TAIL="." ;;
  esac

  [ "$EQ_BLANK_DONE" -eq 0 ] && { echo; EQ_BLANK_DONE=1; }

  if [ "$EQL_COUNT" -eq 1 ]; then
    echo "- 1 ${EQL_ONE} ${EQL_NOUN}: ${EQL_NAMED}${EQL_SOLO_TAIL}"
    return 0
  fi
  EQL_MORE=""
  if [ "$EQL_COUNT" -gt "$EPIC_QUEUE_MAX_NAMED" ]; then
    EQL_MORE=" (+$((EQL_COUNT - EPIC_QUEUE_MAX_NAMED)) more)"
  fi
  echo "- ${EQL_COUNT} ${EQL_MANY} ${EQL_NOUN}: ${EQL_NAMED}${EQL_MORE}${EQL_TAIL}"
}

epic_queue_section() {
  [ -d docs/epics ] || return 0

  EQ_KEYS=()      # folder numbers, kept sorted as rows are inserted
  EQ_NAMES=()     # folder names, in the same positions
  EQ_QUEUES=()    # dispatch|approval|decision|no-work, same positions
  EQ_TOTAL=0
  EQ_BLANK_DONE=0
  for EQ_PLAN in docs/epics/*/plan.md; do
    [ -f "$EQ_PLAN" ] || continue
    EQ_NAME="${EQ_PLAN%/plan.md}"
    EQ_NAME="${EQ_NAME##*/}"

    # Status and Recommendation from the plan header. Only the first
    # EPIC_QUEUE_HEADER_LINES lines are considered — the same window the
    # control-plane resolver and the intake runner use — so prose further down a
    # plan can never be mistaken for the header. The first occurrence of each
    # field wins; the scan stops as soon as both have been seen.
    EQ_STATE=""
    EQ_REC=""
    EQ_N=0
    while IFS= read -r EQ_LINE || [ -n "$EQ_LINE" ]; do
      EQ_N=$((EQ_N + 1))
      [ "$EQ_N" -gt "$EPIC_QUEUE_HEADER_LINES" ] && break
      EQ_L="$EQ_LINE"
      while :; do                       # leading space and ** / _ emphasis
        case "$EQ_L" in
          [[:space:]]*|'*'*|'_'*) EQ_L="${EQ_L#?}" ;;
          *) break ;;
        esac
      done
      case "$EQ_L" in
        [Ss][Tt][Aa][Tt][Uu][Ss]:*)                  [ -z "$EQ_STATE" ] || continue ;;
        [Rr][Ee][Cc][Oo][Mm][Mm][Ee][Nn][Dd][Aa][Tt][Ii][Oo][Nn]:*) [ -z "$EQ_REC" ] || continue ;;
        *) continue ;;
      esac
      EQ_VAL="${EQ_L#*:}"
      while :; do                       # and again after the colon: `**Status:** x`
        case "$EQ_VAL" in               # leaves `** x` behind otherwise
          [[:space:]]*|'*'*|'_'*) EQ_VAL="${EQ_VAL#?}" ;;
          *) break ;;
        esac
      done
      while :; do                       # trailing space, \r, and emphasis
        case "$EQ_VAL" in
          *[[:space:]]|*'*'|*'_') EQ_VAL="${EQ_VAL%?}" ;;
          *) break ;;
        esac
      done
      case "$EQ_L" in
        [Ss][Tt][Aa][Tt][Uu][Ss]:*) EQ_STATE="$EQ_VAL" ;;
        *)                          EQ_REC="$EQ_VAL" ;;
      esac
      [ -n "$EQ_STATE" ] && [ -n "$EQ_REC" ] && break
    done < "$EQ_PLAN" 2>/dev/null

    case "$EQ_STATE" in
      [Cc][Ll][Oo][Ss][Ee][Dd]*) continue ;;
      [Ii][Nn][-[:space:]][Ff][Ll][Ii][Gg][Hh][Tt]*) continue ;;
      [Aa][Pp][Pp][Rr][Oo][Vv][Ee][Dd]*) EQ_QUEUE="dispatch" ;;
      *) EQ_QUEUE="approval" ;;         # `planning`, and anything unparseable
    esac

    # A non-`plan` recommendation moves it out of the approval queue: it is not
    # asking to be approved. Approval-bucket only, and text-only — no plan is
    # hidden by this, it is relabelled. Anything unrecognised stays where it was.
    if [ "$EQ_QUEUE" = "approval" ]; then
      case "$EQ_REC" in
        [Nn][Oo]-[Ww][Oo][Rr][Kk]*) EQ_QUEUE="no-work" ;;
        [Nn][Ee][Ee][Dd][Ss]-[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]*) EQ_QUEUE="decision" ;;
      esac
    fi

    EQ_NUM="${EQ_NAME%%-*}"                              # the NN of NN-slug
    case "$EQ_NUM" in ''|*[!0-9]*) EQ_NUM=9999 ;; esac   # unnumbered folder: last
    EQ_NUM=$((10#$EQ_NUM))                               # 08 is eight, not octal

    # Insertion sort by folder number, so 9- comes before 10- (which a lexical
    # sort gets backwards) and equal numbers keep glob order. n is the number of
    # epics in the repo; this is cheaper than starting sort(1) would be. Both
    # buckets read out of this one ordered list, so each stays in folder order.
    EQ_I="$EQ_TOTAL"
    while [ "$EQ_I" -gt 0 ] && [ "${EQ_KEYS[$((EQ_I - 1))]}" -gt "$EQ_NUM" ]; do
      EQ_KEYS[$EQ_I]="${EQ_KEYS[$((EQ_I - 1))]}"
      EQ_NAMES[$EQ_I]="${EQ_NAMES[$((EQ_I - 1))]}"
      EQ_QUEUES[$EQ_I]="${EQ_QUEUES[$((EQ_I - 1))]}"
      EQ_I=$((EQ_I - 1))
    done
    EQ_KEYS[$EQ_I]="$EQ_NUM"
    EQ_NAMES[$EQ_I]="$EQ_NAME"
    EQ_QUEUES[$EQ_I]="$EQ_QUEUE"
    EQ_TOTAL=$((EQ_TOTAL + 1))
  done
  [ "$EQ_TOTAL" -gt 0 ] || return 0

  epic_queue_line dispatch
  epic_queue_line approval
  epic_queue_line decision
  epic_queue_line no-work
}

epic_queue_section

# Tracker backlog: open GitHub issues that no epic has picked up yet.
# Strictly best-effort and silent — a missing gh, a non-GitHub remote, an auth
# or network failure, or a slow tracker all produce NO output, leaving every
# section above byte-identical. Never delays session start by more than ~2s.
BACKLOG_MAX_NAMED=5
BACKLOG_TITLE_CHARS=60

backlog_section() {
  # Hard guards first: no gh, or not a GitHub repo, means no tracker call at all
  # (this is also what keeps gh's "no git remotes found" noise off every repo).
  command -v gh >/dev/null 2>&1 || return 0
  git remote -v 2>/dev/null | grep -qi 'github\.com' 2>/dev/null || return 0

  BL_OUT="$(mktemp "${TMPDIR:-/tmp}/session-start-backlog.XXXXXX" 2>/dev/null)" || return 0

  # gh's built-in --jq (no external jq needed) drops issues already labelled as
  # adopted by an epic. Backgrounded so the poll loop below can cap the wait:
  # macOS ships no timeout(1)/gtimeout, so this is the portable equivalent.
  gh issue list --state open --limit 100 --json number,title,labels \
    --jq '.[] | select((.labels | any(.name == "epic:planned" or .name == "epic:in-progress")) | not) | "\(.number)\t\(.title)"' \
    > "$BL_OUT" 2>/dev/null &
  BL_PID=$!

  # The first tick doubles as a probe: fractional sleep is BSD/GNU, not POSIX,
  # so fall back to 1s ticks (still a 2s cap) where it is unsupported.
  if sleep 0.1 2>/dev/null; then BL_TICK="0.1"; BL_MAX_TICKS=20; else BL_TICK="1"; BL_MAX_TICKS=2; fi
  BL_TICKS=1
  while [ "$BL_TICKS" -lt "$BL_MAX_TICKS" ]; do
    kill -0 "$BL_PID" 2>/dev/null || break
    sleep "$BL_TICK" 2>/dev/null
    BL_TICKS=$((BL_TICKS + 1))
  done

  if kill -0 "$BL_PID" 2>/dev/null; then
    # Over the cap: kill the query and say nothing. Children are listed before
    # the parent dies, or they would be reparented and outlive the session.
    BL_KIDS="$(pgrep -P "$BL_PID" 2>/dev/null | tr '\n' ' ')"
    kill -TERM "$BL_PID" 2>/dev/null
    for BL_KID in $BL_KIDS; do kill -TERM "$BL_KID" 2>/dev/null; done
    wait "$BL_PID" 2>/dev/null
    rm -f "$BL_OUT" 2>/dev/null
    return 0
  fi
  if ! wait "$BL_PID" 2>/dev/null; then
    rm -f "$BL_OUT" 2>/dev/null
    return 0
  fi

  # Second correlation signal: issue numbers already claimed by a filed epic via
  # the plan header (`Source: GH #<n>`). Anchored to the header line so a passing
  # mention of an issue elsewhere in a plan does not silence it.
  BL_ADOPTED="$(grep -hE '^[[:space:]]*[*_]*Source:' docs/epics/*/plan.md 2>/dev/null \
    | grep -oE 'GH #[0-9]+' | grep -oE '[0-9]+' | tr '\n' ' ')"

  BL_NAMED=""
  BL_COUNT=0
  while IFS=$'\t' read -r BL_NUM BL_TITLE; do
    [ -n "$BL_NUM" ] || continue
    case " $BL_ADOPTED " in *" $BL_NUM "*) continue ;; esac
    BL_COUNT=$((BL_COUNT + 1))
    [ "$BL_COUNT" -gt "$BACKLOG_MAX_NAMED" ] && continue
    BL_SHORT="$(printf '%s' "$BL_TITLE" | cut -c "1-$BACKLOG_TITLE_CHARS")"
    [ "${#BL_TITLE}" -gt "$BACKLOG_TITLE_CHARS" ] && BL_SHORT="${BL_SHORT}…"
    if [ -z "$BL_NAMED" ]; then
      BL_NAMED="#${BL_NUM} ${BL_SHORT}"
    else
      BL_NAMED="${BL_NAMED}; #${BL_NUM} ${BL_SHORT}"
    fi
  done < "$BL_OUT"
  rm -f "$BL_OUT" 2>/dev/null

  [ "$BL_COUNT" -gt 0 ] || return 0
  BL_MORE=""
  if [ "$BL_COUNT" -gt "$BACKLOG_MAX_NAMED" ]; then
    BL_MORE=" (+$((BL_COUNT - BACKLOG_MAX_NAMED)) more)"
  fi
  echo
  echo "- Open issues with no epic yet (${BL_COUNT}): ${BL_NAMED}${BL_MORE} — \`/intake #<n>\` to plan one."
}

backlog_section

# Unattended intake config for THIS repo — armed or not, and against which base.
#
# The config is per-repo and lives outside the repo, so from inside a session it
# is invisible: an orchestrator can work all day believing labelled issues will
# be drafted while the agent is unloaded, or believing proposals target `dev`
# when they would target `main`. This states the facts; SKILL.md tells the
# orchestrator to confirm them with Jonathan rather than assume.
#
# Silent when unattended intake has never been configured — a repo that does not
# use it must not grow a nag line. Purely local: reads one file and asks launchd.
# No gh, no network, no bearing on the tracker call's ~2s cap.
intake_config_section() {
  IC_LIST="${INTAKE_REPO_LIST:-$HOME/.config/claude-intake/repos}"
  [ -f "$IC_LIST" ] && [ -r "$IC_LIST" ] || return 0     # never configured → say nothing

  IC_ROOT="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$IC_ROOT" ]; then IC_ROOT="$(dirname "$IC_ROOT" 2>/dev/null || true)"; fi
  [ -n "$IC_ROOT" ] || IC_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$IC_ROOT" ] || return 0

  IC_LISTED=no
  IC_BASE=""
  while IFS= read -r IC_LINE || [ -n "$IC_LINE" ]; do
    IC_LINE="${IC_LINE%"${IC_LINE##*[![:space:]]}"}"
    IC_LINE="${IC_LINE#"${IC_LINE%%[![:space:]]*}"}"
    case "$IC_LINE" in ''|'#'*) continue ;; esac
    case "$IC_LINE" in '~'*) IC_LINE="$HOME${IC_LINE#\~}" ;; esac
    case "$IC_LINE" in
      *\|*) IC_PATH="${IC_LINE%|*}"; IC_B="${IC_LINE##*|}" ;;
      *)     IC_PATH="$IC_LINE";      IC_B="" ;;
    esac
    IC_PATH="${IC_PATH%"${IC_PATH##*[![:space:]]}"}"
    if [ "$IC_PATH" = "$IC_ROOT" ]; then
      IC_LISTED=yes
      IC_BASE="$IC_B"
      break
    fi
  done < "$IC_LIST"

  IC_AGENT=no
  launchctl list 2>/dev/null | grep -q 'unattended-intake' && IC_AGENT=yes

  echo
  if [ "$IC_LISTED" = no ]; then
    echo "- Unattended intake: this repo is **not** listed in \`$IC_LIST\` — labelling \`claude-intake\` here does nothing."
  else
    if [ -n "$IC_BASE" ]; then IC_SHOWN="$IC_BASE"; else IC_SHOWN="(GitHub default)"; fi
    if [ "$IC_AGENT" = yes ]; then
      echo "- Unattended intake: **armed** — proposals target \`$IC_SHOWN\`, agent loaded and polling."
    else
      echo "- Unattended intake: listed (base \`$IC_SHOWN\`) but the **agent is not loaded** — nothing polls until it is."
    fi
  fi
  echo "  Confirm this is right for this repo before relying on it (dev-epic-workflow: intake config check)."
}

intake_config_section

exit 0
