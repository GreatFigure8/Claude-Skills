#!/usr/bin/env bash
# Fixture harness for ACTIVE-EPIC RESOLUTION in the control-plane telemetry hooks:
#   ../subagent-lifecycle.sh     (SubagentStart/Stop)
#   ../subagent-tool-logger.sh   (PostToolUse)
#
# Both must answer the same question the same way: WHICH epic is in flight, and
# therefore which docs/epics/<NN>-<slug>/status/ tree receives this agent's
# telemetry. The rule under test (GH #9):
#   (a) the explicit pointer $REPO_ROOT/.claude/signals/active-epic, when it
#       names a real epic directory;
#   (b) otherwise the newest plan.md whose "**Status:**" is NOT closed;
#   (c) otherwise nothing at all — exit 0, write nothing, say nothing.
# It used to be bare mtime, so touching a CLOSED epic's plan.md stole a live
# executor's telemetry.
#
# Runs the REPO copies of the hooks against synthetic hook-input JSON in a
# throwaway sandbox: every git repo, worktree, pointer, plan and status tree
# lives under a fresh mktemp -d removed on exit. Never installs anything, never
# touches a real repo, ~/.claude, or any real epic folder.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.
#
# Variants, because resolution must not depend on a JSON parser being installed:
#   full  — normal PATH (jq present)
#   nojq  — python3 but no jq
#   bare  — neither (grep/sed only)
# The logger's log LINE needs jq or python3, so cases that assert a logged tool
# line skip `bare`; every resolution assertion runs in all three, using the
# lifecycle hook's SUBAGENT START bracket (parser-free) as the observable.

set -u

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIFECYCLE="$HOOKS_DIR/subagent-lifecycle.sh"
LOGGER="$HOOKS_DIR/subagent-tool-logger.sh"
for f in "$LIFECYCLE" "$LOGGER"; do
  [ -f "$f" ] || { echo "ERROR: not found: $f" >&2; exit 1; }
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/active-epic-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0
AGENT="c0ffee1234567890abcd"
OPEN_EPIC="docs/epics/02-open-epic"
CLOSED_EPIC="docs/epics/01-closed-epic"
THIRD_EPIC="docs/epics/03-third-epic"

git_q() { git -c user.email=fixture@example.com -c user.name=fixture \
              -c commit.gpgsign=false -c init.defaultBranch=main "$@"; }

check() { # $1 label  $2 expected  $3 actual  $4 variant
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-58s %-5s exp=%-20s got=%-20s %s\n' "$1" "$4" "$2" "$3" "$R"
}

BIN_NOJQ="$SANDBOX/bin-nojq"; BIN_BARE="$SANDBOX/bin-bare"
mkdir -p "$BIN_NOJQ" "$BIN_BARE"
for t in cat grep sed head tr cut wc git ls mkdir rm mv dirname basename date printf env sort find touch sleep; do
  p="$(command -v "$t" 2>/dev/null)" || continue
  ln -sf "$p" "$BIN_NOJQ/$t"; ln -sf "$p" "$BIN_BARE/$t"
done
p="$(command -v python3 2>/dev/null)" && ln -sf "$p" "$BIN_NOJQ/python3"
PATH_FULL="$PATH"
path_for() {
  case "$1" in
    full) printf '%s' "$PATH_FULL" ;;
    nojq) printf '%s' "$BIN_NOJQ" ;;
    bare) printf '%s' "$BIN_BARE" ;;
  esac
}

plan_file() { # $1 = dir, $2 = status word (empty = no Status line at all)
  mkdir -p "$1"
  if [ -n "$2" ]; then
    printf '# Epic: fixture\n\n**Status:** %s\n**Source:** GH #0\n\n## Outcome\nfixture\n' "$2" > "$1/plan.md"
  else
    printf '# Epic: fixture with no status header\n\nnothing parseable here\n' > "$1/plan.md"
  fi
}

# Build a repo with a closed epic and an open epic, then TOUCH THE CLOSED ONE
# LAST — the exact observed failure: mtime says "closed epic", truth says "open".
mkrepo() { # $1 = base -> $1/orch (main checkout) + $1/orch-wt (linked worktree)
  rm -rf "$1"; mkdir -p "$1/orch/.claude/signals"
  plan_file "$1/orch/$OPEN_EPIC" "in flight (item 1 of 1)"
  plan_file "$1/orch/$CLOSED_EPIC" "closed"
  git_q -C "$1/orch" init -q
  git_q -C "$1/orch" checkout -q -b main 2>/dev/null || git_q -C "$1/orch" branch -q -m main
  git_q -C "$1/orch" add -A > /dev/null 2>&1
  git_q -C "$1/orch" commit -q -m fixture > /dev/null 2>&1
  git_q -C "$1/orch" worktree add -q -b fix/item-a "$1/orch-wt" main > /dev/null 2>&1
  sleep 1                                   # 1s filesystem mtime granularity
  touch "$1/orch/$CLOSED_EPIC/plan.md"      # the legitimate retro edit
}

fx_lifecycle() { # $1 event  $2 agent
  printf '{"session_id":"sess-1","transcript_path":"/dev/null","cwd":"%s",
 "hook_event_name":"%s","agent_id":"%s","agent_type":"work-item-executor"}\n' \
    "$SANDBOX" "$1" "$2"
}
fx_posttool() { # $1 agent  $2 command text
  printf '{"session_id":"sess-1","hook_event_name":"PostToolUse","agent_id":"%s",
 "agent_type":"work-item-executor","tool_name":"Bash","tool_input":{"command":"%s"}}\n' \
    "$1" "$2"
}
run_life() { # $1 projectdir  $2 event  $3 agent  $4 variant
  fx_lifecycle "$2" "$3" | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$4")" \
    /bin/bash "$LIFECYCLE" > /dev/null 2>> "$SANDBOX/stderr.log"
}
run_log() { # $1 projectdir  $2 agent  $3 command  $4 variant
  fx_posttool "$2" "$3" | CLAUDE_PROJECT_DIR="$1" PATH="$(path_for "$4")" \
    /bin/bash "$LOGGER" > /dev/null 2>> "$SANDBOX/stderr.log"
}

# Which epic did the LIFECYCLE hook choose? -> the epic dir holding its bracket
# file, printed relative to the checkout. "<none>" when it wrote nothing.
life_epic() { # $1 = checkout root  $2 = agent
  F="$(ls "$1"/docs/epics/*/status/agent-"$2".log 2>/dev/null | head -1)"
  [ -n "$F" ] || { printf '<none>'; return 0; }
  D="${F%/status/agent-$2.log}"
  printf '%s' "${D#$1/}"
}
# Which epic did the LOGGER choose? -> the epic dir it appended a tool line to.
log_epic() { # $1 = checkout root  $2 = agent
  for F in "$1"/docs/epics/*/status/agent-"$2".log; do
    [ -f "$F" ] || continue
    grep -q ' | Bash | ' "$F" 2>/dev/null || continue
    D="${F%/status/agent-$2.log}"
    printf '%s' "${D#$1/}"; return 0
  done
  printf '<none>'
}

echo "sandbox:   $SANDBOX"
echo "lifecycle: $LIFECYCLE"
echo "logger:    $LOGGER"
echo "bash:      $(/bin/bash --version | head -1)"
echo "git:       $(git --version)"
echo

# ============================================================================
echo "=== A. THE OBSERVED FAILURE: closed epic touched last, no pointer ======"
echo "    (mtime says 01-closed-epic; the open epic must win anyway)"
for V in full nojq bare; do
  B="$SANDBOX/A-$V"; mkrepo "$B"; ORCH="$B/orch"
  NEWEST="$(ls -t "$ORCH"/docs/epics/*/plan.md | head -1)"
  check "precondition: newest plan.md IS the closed epic" \
        "$CLOSED_EPIC/plan.md" "${NEWEST#$ORCH/}" "$V"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "lifecycle picks the OPEN epic" "$OPEN_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"
  check "closed epic got no status tree" "0" \
        "$(ls "$ORCH/$CLOSED_EPIC/status" 2>/dev/null | wc -l | tr -d ' ')" "$V"
  run_life "$ORCH" SubagentStop "$AGENT" "$V"
  check "START+STOP both in the open epic" "2" \
        "$(grep -c 'SUBAGENT ST' "$ORCH/$OPEN_EPIC/status/agent-$AGENT.log" 2>/dev/null | tr -d ' ')" "$V"
  check "closed epic still has no status tree after stop" "0" \
        "$(ls "$ORCH/$CLOSED_EPIC/status" 2>/dev/null | wc -l | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== B. explicit pointer wins over a newer plan.md ======================"
for V in full nojq bare; do
  B="$SANDBOX/B-$V"; mkrepo "$B"; ORCH="$B/orch"
  plan_file "$ORCH/$THIRD_EPIC" "in flight (item 1 of 1)"   # newest of all, and open
  printf '03-third-epic\n' > "$ORCH/.claude/signals/active-epic"   # ...but not the one
  sleep 1; touch "$ORCH/$OPEN_EPIC/plan.md"                  # make 02 the newest again
  NEWEST="$(ls -t "$ORCH"/docs/epics/*/plan.md | head -1)"
  check "precondition: newest is 02, pointer names 03" \
        "$OPEN_EPIC/plan.md" "${NEWEST#$ORCH/}" "$V"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "lifecycle follows the pointer, not mtime" "$THIRD_EPIC" \
        "$(life_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== C. pointer value forms all resolve to the same epic ================"
for V in full nojq bare; do
  B="$SANDBOX/C-$V"; mkrepo "$B"; ORCH="$B/orch"
  plan_file "$ORCH/$THIRD_EPIC" "approved"
  for FORM in "03-third-epic" "docs/epics/03-third-epic" "docs/epics/03-third-epic/" \
              "$ORCH/docs/epics/03-third-epic" "docs/epics/03-third-epic/plan.md" \
              "  03-third-epic  "; do
    rm -rf "$ORCH"/docs/epics/*/status
    printf '%s\n' "$FORM" > "$ORCH/.claude/signals/active-epic"
    run_life "$ORCH" SubagentStart "$AGENT" "$V"
    LABEL="$(printf '%s' "$FORM" | sed "s|$ORCH|<root>|")"
    check "pointer form [$LABEL]" "$THIRD_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"
  done
  # comments and blank lines are skipped; first real line wins
  rm -rf "$ORCH"/docs/epics/*/status
  printf '# written by dispatch setup\n\n03-third-epic\n02-open-epic\n' \
    > "$ORCH/.claude/signals/active-epic"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "pointer form [comments + blanks skipped]" "$THIRD_EPIC" \
        "$(life_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== D. a pointer that resolves to nothing falls back, never errors ====="
for V in full nojq bare; do
  B="$SANDBOX/D-$V"; mkrepo "$B"; ORCH="$B/orch"
  for BAD in "99-deleted-epic" "docs/epics/99-deleted-epic" "../../../../etc" "" "   " "#only a comment"; do
    rm -rf "$ORCH"/docs/epics/*/status
    printf '%s\n' "$BAD" > "$ORCH/.claude/signals/active-epic"
    run_life "$ORCH" SubagentStart "$AGENT" "$V"; RC=$?
    check "bad pointer [${BAD:-<empty>}]: falls back to open epic" "$OPEN_EPIC" \
          "$(life_epic "$ORCH" "$AGENT")" "$V"
    check "bad pointer [${BAD:-<empty>}]: exit code" 0 "$RC" "$V"
  done
  # a pointer that is a directory, not a file, is ignored the same way
  rm -rf "$ORCH"/docs/epics/*/status "$ORCH/.claude/signals/active-epic"
  mkdir -p "$ORCH/.claude/signals/active-epic"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "pointer is a directory: falls back" "$OPEN_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"
  rm -rf "$ORCH/.claude/signals/active-epic"
done

# ============================================================================
echo
echo "=== E. two OPEN epics, no pointer: newest open wins ===================="
for V in full nojq bare; do
  B="$SANDBOX/E-$V"; mkrepo "$B"; ORCH="$B/orch"
  plan_file "$ORCH/$THIRD_EPIC" "approved"
  sleep 1; touch "$ORCH/$THIRD_EPIC/plan.md"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "newest open epic wins" "$THIRD_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"
  rm -rf "$ORCH"/docs/epics/*/status
  sleep 1; touch "$ORCH/$OPEN_EPIC/plan.md"     # the other open epic becomes newest
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "order follows mtime AMONG OPEN epics" "$OPEN_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== F. Status parsing: only 'closed' closes; unparseable counts OPEN ==="
for V in full nojq bare; do
  B="$SANDBOX/F-$V"; mkrepo "$B"; ORCH="$B/orch"
  rm -rf "$ORCH/$OPEN_EPIC"                       # leave ONLY the closed epic...
  plan_file "$ORCH/$THIRD_EPIC" ""                # ...and one with no Status line
  sleep 1; touch "$ORCH/$CLOSED_EPIC/plan.md"     # closed one is newest again
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "no Status: line is treated as OPEN" "$THIRD_EPIC" "$(life_epic "$ORCH" "$AGENT")" "$V"

  for S in "planning" "approved" "in flight (item 2 of 3)" "Closed-ish" "closed (2026-08-19)"; do
    rm -rf "$ORCH"/docs/epics/*/status
    plan_file "$ORCH/$THIRD_EPIC" "$S"
    sleep 1; touch "$ORCH/$CLOSED_EPIC/plan.md"
    run_life "$ORCH" SubagentStart "$AGENT" "$V"
    case "$S" in "closed ("*) EXP="<none>" ;; *) EXP="$THIRD_EPIC" ;; esac
    check "Status [$S] -> ${EXP##*/}" "$EXP" "$(life_epic "$ORCH" "$AGENT")" "$V"
  done
  # CRLF line endings must not make a closed plan look open
  rm -rf "$ORCH"/docs/epics/*/status
  printf '# Epic: fixture\r\n\r\n**Status:** closed\r\n' > "$ORCH/$THIRD_EPIC/plan.md"
  sleep 1; touch "$ORCH/$THIRD_EPIC/plan.md"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  check "CRLF '**Status:** closed' still reads closed" "<none>" \
        "$(life_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== G. nothing resolvable: exit 0, write nothing, say nothing =========="
for V in full nojq bare; do
  B="$SANDBOX/G-$V"; mkrepo "$B"; ORCH="$B/orch"
  rm -rf "$ORCH/$OPEN_EPIC"                       # every remaining epic is closed
  : > "$SANDBOX/stderr-G.log"
  fx_lifecycle SubagentStart "$AGENT" | CLAUDE_PROJECT_DIR="$ORCH" PATH="$(path_for "$V")" \
    /bin/bash "$LIFECYCLE" > "$SANDBOX/stdout-G.log" 2> "$SANDBOX/stderr-G.log"
  check "all epics closed: exit code" 0 "$?" "$V"
  check "all epics closed: nothing written" "<none>" "$(life_epic "$ORCH" "$AGENT")" "$V"
  check "all epics closed: no stderr" "0" "$(wc -c < "$SANDBOX/stderr-G.log" | tr -d ' ')" "$V"
  check "all epics closed: no stdout" "0" "$(wc -c < "$SANDBOX/stdout-G.log" | tr -d ' ')" "$V"
  check "all epics closed: marker still cleaned up by stop" "0" \
        "$(run_life "$ORCH" SubagentStop "$AGENT" "$V"; ls "$ORCH/.claude/signals/" 2>/dev/null \
           | grep -c 'subagent-active' | tr -d ' ')" "$V"

  NOEPICS="$SANDBOX/G-noepics-$V"; rm -rf "$NOEPICS"; mkdir -p "$NOEPICS"
  : > "$SANDBOX/stderr-G2.log"
  fx_lifecycle SubagentStart "$AGENT" | CLAUDE_PROJECT_DIR="$NOEPICS" PATH="$(path_for "$V")" \
    /bin/bash "$LIFECYCLE" > /dev/null 2> "$SANDBOX/stderr-G2.log"
  check "no docs/epics at all, no git: exit code" 0 "$?" "$V"
  check "no docs/epics at all, no git: no stderr" "0" \
        "$(wc -c < "$SANDBOX/stderr-G2.log" | tr -d ' ')" "$V"
done

# ============================================================================
echo
echo "=== H. the two hooks agree — same block, same choice ==================="
BLOCK_A="$SANDBOX/block-lifecycle.txt"; BLOCK_B="$SANDBOX/block-logger.txt"
sed -n '/BEGIN active-epic resolution/,/END active-epic resolution/p' "$LIFECYCLE" > "$BLOCK_A"
sed -n '/BEGIN active-epic resolution/,/END active-epic resolution/p' "$LOGGER"    > "$BLOCK_B"
check "resolution block present in lifecycle (lines)" "yes" \
      "$([ -s "$BLOCK_A" ] && echo yes || echo no)" "-"
check "resolution block present in logger (lines)" "yes" \
      "$([ -s "$BLOCK_B" ] && echo yes || echo no)" "-"
check "resolution block is byte-identical in both hooks" "identical" \
      "$(cmp -s "$BLOCK_A" "$BLOCK_B" && echo identical || echo DRIFTED)" "-"
# The old rule was one line: EPIC_PLAN="$(ls -t .../plan.md | head -1)". It must
# be gone, and the ONE surviving `ls -t` per hook (the fallback) must live inside
# the shared block — an mtime selection anywhere else is drift by definition.
for HOOK in "$LIFECYCLE" "$LOGGER"; do
  N="$(basename "$HOOK")"
  check "[$N] old EPIC_PLAN mtime selection is gone" "0" \
        "$(grep -c 'EPIC_PLAN' "$HOOK" | tr -d ' ')" "-"
  LS_ALL="$(grep -c 'ls -t' "$HOOK" | tr -d ' ')"
  LS_BLK="$(sed -n '/BEGIN active-epic resolution/,/END active-epic resolution/p' "$HOOK" \
             | grep -c 'ls -t' | tr -d ' ')"
  check "[$N] the shared block carries the mtime fallback" "yes" \
        "$([ "$LS_BLK" -ge 1 ] && echo yes || echo no)" "-"
  check "[$N] no 'ls -t' anywhere outside the shared block" "0" \
        "$((LS_ALL - LS_BLK))" "-"
done
for V in full nojq; do        # logger needs a parser for its log LINE
  B="$SANDBOX/H-$V"; mkrepo "$B"; ORCH="$B/orch"
  plan_file "$ORCH/$THIRD_EPIC" "approved"
  printf '03-third-epic\n' > "$ORCH/.claude/signals/active-epic"
  sleep 1; touch "$ORCH/$CLOSED_EPIC/plan.md"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  run_log  "$ORCH" "$AGENT" "git status --short" "$V"
  check "pointer: both hooks chose the same epic" "$(life_epic "$ORCH" "$AGENT")" \
        "$(log_epic "$ORCH" "$AGENT")" "$V"
  # and again with no pointer, on the fallback path
  B="$SANDBOX/H2-$V"; mkrepo "$B"; ORCH="$B/orch"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  run_log  "$ORCH" "$AGENT" "git status --short" "$V"
  check "fallback: both hooks chose the same epic" "$(life_epic "$ORCH" "$AGENT")" \
        "$(log_epic "$ORCH" "$AGENT")" "$V"
  check "fallback: and it is the OPEN epic" "$OPEN_EPIC" "$(log_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== I. worktree dispatch: pointer read from the CANONICAL root ========="
echo "    (CLAUDE_PROJECT_DIR = the worktree, which has no .claude/signals)"
for V in full nojq bare; do
  B="$SANDBOX/I-$V"; mkrepo "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  plan_file "$ORCH/$THIRD_EPIC" "approved"
  printf '03-third-epic\n' > "$ORCH/.claude/signals/active-epic"   # main checkout only
  sleep 1; touch "$ORCH/$CLOSED_EPIC/plan.md"
  check "precondition: worktree has no pointer of its own" "absent" \
        "$([ -e "$WT/.claude/signals/active-epic" ] && echo present || echo absent)" "$V"
  run_life "$WT" SubagentStart "$AGENT" "$V"
  check "hook run from worktree honours the pointer" "$THIRD_EPIC" \
        "$(life_epic "$ORCH" "$AGENT")" "$V"
  check "nothing written inside the worktree" "0" \
        "$(ls "$WT"/docs/epics/*/status 2>/dev/null | wc -l | tr -d ' ')" "$V"
  # fallback path from the worktree, too
  B="$SANDBOX/I2-$V"; mkrepo "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  run_life "$WT" SubagentStart "$AGENT" "$V"
  check "hook run from worktree falls back to the OPEN epic" "$OPEN_EPIC" \
        "$(life_epic "$ORCH" "$AGENT")" "$V"
done

# ============================================================================
echo
echo "=== J. epic 02's behaviour is untouched by the new resolution =========="
for V in full nojq bare; do
  B="$SANDBOX/J-$V"; mkrepo "$B"; ORCH="$B/orch"; WT="$B/orch-wt"
  printf '02-open-epic\n' > "$ORCH/.claude/signals/active-epic"
  run_life "$ORCH" SubagentStart "$AGENT" "$V"
  D="$ORCH/$OPEN_EPIC/status"
  printf '{\n  "item": "1 fixture",\n  "state": "pr-opened",\n  "detail": "fixture"\n}\n' \
    > "$D/fix-item-a.json.tmp"; mv "$D/fix-item-a.json.tmp" "$D/fix-item-a.json"
  check "owner record written under the chosen epic" "1" \
        "$(ls "$D/.agents" 2>/dev/null | wc -l | tr -d ' ')" "$V"
  run_life "$ORCH" SubagentStop "$AGENT" "$V"
  check "terminal stamped in the chosen epic" "1" \
        "$(grep -c '"terminal"' "$D/fix-item-a.json" 2>/dev/null | tr -d ' ')" "$V"
  check "state preserved" "1" \
        "$(grep -c '"state": "pr-opened"' "$D/fix-item-a.json" 2>/dev/null | tr -d ' ')" "$V"
  check "marker removed at stop" "0" \
        "$(ls "$ORCH/.claude/signals/" | grep -c 'subagent-active' | tr -d ' ')" "$V"
  check "pointer NOT consumed by the hooks" "present" \
        "$([ -f "$ORCH/.claude/signals/active-epic" ] && echo present || echo gone)" "$V"
done

echo
echo "=== hook stderr (empty unless a hook errored on its own) ==============="
[ -s "$SANDBOX/stderr.log" ] && head -20 "$SANDBOX/stderr.log"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
