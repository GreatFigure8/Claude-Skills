#!/usr/bin/env bash
# Fixtures for the verify phase / cold acceptance check — dev-epic-workflow,
# epic 19 (epic-loop) item 5: ../../bin/verify-item.sh (and the
# ../../agents/acceptance-verifier.md brief it drives via phase-session.sh).
#
# WHAT THIS PROVES, against the item's own DoD, verbatim:
#
#   "synthetic PR with a deliberately unmet DoD line -> `fail` naming that
#    line" -> Section E below.
#   "clean PR -> `pass`" -> Section D below.
#   "missing `gates-passed` -> refused before any session starts" -> Section
#    C1 below, and — the sharper form of the same claim — C1 asserts the
#    stub `claude` marker file was never even written, i.e. no session was
#    EVER spawned, not merely that its result was discarded.
#
# Section C also exercises the other three deterministic gates (declared-
# paths mismatch, red `gh pr checks`, a diff that touches the sensitive-path
# denylist floor) with the same "no session, no comment" assertion, because
# the plan's own ordering ("deterministic gates first ... THEN a cold
# verifier session") is a claim about every one of the four gates, not only
# the one the DoD happens to name.
#
# REAL GIT, STUBBED `gh` AND `claude` — the same split declared-paths-gate-
# fixtures.sh and phase-session-fixtures.sh both make: a diff is the thing
# several of these gates actually check, so a fake diff would not test the
# seam that matters, but there is no reason to hit the network or a real
# model for a script whose own job is "run four cheap checks, then hand a
# brief to a harness that is already covered by phase-session-fixtures.sh."
# `gh` is stubbed by a small config-directory-driven script (one CFG dir per
# scenario, a call log every invocation appends to) rather than one script
# per gh subcommand, because verify-item.sh calls five distinct `gh`
# subcommands and hand-rolling five stubs would drift from each other the
# moment one of them changed.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/verify-item-fixtures.sh
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch,
#         2 = the tree under test is not what this suite expects (abort).

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/verify-item.sh}"
AGENT_FILE="$BIN_DIR/../agents/acceptance-verifier.md"
REAL_GIT="$(command -v git 2>/dev/null || printf '/usr/bin/git')"

for F in "$SCRIPT" "$BIN_DIR/phase-session.sh" "$BIN_DIR/autonomy.sh" "$BIN_DIR/declared-paths-gate.sh" "$AGENT_FILE"; do
  [ -r "$F" ] || { echo "ERROR: missing $F — this is not an epic 19 item 5 tree. Aborting." >&2; exit 2; }
done
if ! grep -q '^VERIFY_ITEM_CONTRACT=1' "$SCRIPT"; then
  echo "ERROR: $SCRIPT carries no VERIFY_ITEM_CONTRACT=1 marker." >&2
  exit 2
fi

FAILURES=0
CASES=0

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-70s exp=%-8s got=%-8s %s\n' "$1" "$2" "$3" "$R"
}

check_contains() { # $1 label  $2 expected(0|1 present)  $3 haystack  $4 needle
  CASES=$((CASES + 1))
  local GOT=0
  case "$3" in *"$4"*) GOT=1 ;; esac
  if [ "$2" = "$GOT" ]; then R="PASS"; else R="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-70s exp=%-8s got=%-8s %s\n' "$1" "$2" "$GOT" "$R"
}

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/verify-item-fixtures.XXXXXX")" || exit 2
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 2 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

export HOME="$SANDBOX/home"
mkdir -p "$HOME"
export INTAKE_GIT="$REAL_GIT"

echo "script:  $SCRIPT"
echo "sandbox: $SANDBOX"
echo

# ============================================================ SECTION A ===
# Unit: plan parsing, sourced (main() is guarded — same convention every
# other script in this tree uses — so sourcing never spawns a session).
echo "=== A. plan parsing — extract_title / extract_dod / dod_criteria ==="

# shellcheck disable=SC1090
. "$SCRIPT"

APLAN="$SANDBOX/a-plan.md"
cat > "$APLAN" <<'EOF'
# Epic: fixture

## Work items

### 1. first item
- **DoD:** the widget renders; the config validates required fields

### 2a. a split item id
- **DoD:** split items are addressable too

### 3. no dod at all
- **Scope:** nothing to check against
EOF

check "A1 extract_title finds item 1's title" "first item" "$(verify_item_extract_title "$APLAN" 1)"
check "A2 extract_title finds a split id (2a)" "a split item id" "$(verify_item_extract_title "$APLAN" 2a)"
check "A3 extract_title on an unknown item is empty" "" "$(verify_item_extract_title "$APLAN" 99)"
check "A4 extract_dod flattens item 1's bullet" "the widget renders; the config validates required fields" "$(verify_item_extract_dod "$APLAN" 1)"
check "A5 extract_dod rc on an unknown item is 1" "1" "$(verify_item_extract_dod "$APLAN" 99 >/dev/null 2>&1; echo $?)"
check "A6 extract_dod rc on an item with no DoD bullet is 0 (empty, not an error)" "0" "$(verify_item_extract_dod "$APLAN" 3 >/dev/null 2>&1; echo $?)"
DOD_A4="$(verify_item_extract_dod "$APLAN" 1)"
check "A7 dod_criteria splits on ; and trims" "the widget renders
the config validates required fields" "$(verify_item_dod_criteria "$DOD_A4")"
check "A8 branch_slug turns / into -" "feat-item-1" "$(verify_item_branch_slug feat/item-1)"

# ============================================================ SECTION B ===
echo
echo "=== B. status.json / verdict.json parsing =========================="

BSTATUS_OK="$SANDBOX/b-status-ok.json"
cat > "$BSTATUS_OK" <<'EOF'
{
  "item": "1. fixture",
  "branch": "feat/item-1",
  "state": "pr-opened",
  "detail": "PR #1",
  "commit": "abc123",
  "updated": "2026-09-10T00:00:00Z"
}
EOF
verify_item_read_status "$BSTATUS_OK"; B1_RC=$?
check "B1 read_status reads pr-opened" "0" "$B1_RC"
check "B2 read_status sets the state" "pr-opened" "${VERIFY_ITEM_STATUS_STATE:-}"
verify_item_read_status "$SANDBOX/nope.json"; B3_RC=$?
check "B3 read_status rc 1 on a missing file" "1" "$B3_RC"

VOK="$SANDBOX/b-verdict-ok.json"
cat > "$VOK" <<'EOF'
{
  "verdict": "pass",
  "criteria": [
    { "text": "a", "met": true, "evidence": "e1" },
    { "text": "b", "met": true, "evidence": "e2" }
  ]
}
EOF
check "B4 verdict_valid accepts a well-formed pass" "0" "$(verify_item_verdict_valid "$VOK"; echo $?)"
check "B5 verdict_value reads pass" "pass" "$(verify_item_verdict_value "$VOK")"
check_contains "B6 render_comment header names PASS" 1 "$(verify_item_render_comment "$VOK")" "Cold acceptance verdict: PASS"

VTRUNC="$SANDBOX/b-verdict-truncated.json"
cat > "$VTRUNC" <<'EOF'
{
  "verdict": "pass",
  "criteria": [
    { "text": "a", "met": true, "evidence": "e1" },
    { "text": "b", "met": true
  ]
}
EOF
check "B7 verdict_valid rejects a truncated write (text/met/evidence counts disagree)" "1" "$(verify_item_verdict_valid "$VTRUNC"; echo $?)"

VBAD="$SANDBOX/b-verdict-bad-value.json"
printf '{ "verdict": "maybe", "criteria": [ { "text": "a", "met": true, "evidence": "e" } ] }\n' > "$VBAD"
check "B8 verdict_valid rejects an unrecognised verdict value" "1" "$(verify_item_verdict_valid "$VBAD"; echo $?)"

VFAIL="$SANDBOX/b-verdict-fail.json"
cat > "$VFAIL" <<'EOF'
{
  "verdict": "fail",
  "criteria": [
    { "text": "the widget renders", "met": true, "evidence": "src/widget.ts:12" },
    { "text": "MARKER-UNMET-atomic-write is present", "met": false, "evidence": "MARKER-UNMET-atomic-write does not appear anywhere in the diff" }
  ]
}
EOF
check_contains "B9 render_comment header names FAIL and blocked routing" 1 "$(verify_item_render_comment "$VFAIL")" "FAIL — this item moves to \`blocked\`"
check_contains "B10 render_comment NAMES the unmet criterion's evidence" 1 "$(verify_item_render_comment "$VFAIL")" "MARKER-UNMET-atomic-write does not appear"

# ============================================================ SECTION C ===
# THE FOUR DETERMINISTIC GATES, each in isolation, real repo + stubbed gh +
# a `claude` stub whose only job is to prove it was NEVER invoked.
echo
echo "=== C. deterministic gates refuse before any session starts ========"

REPO="$SANDBOX/repo"
mkdir -p "$REPO/docs/epics/93-fixture-epic/status"
"$REAL_GIT" -C "$REPO" init -q 2>/dev/null || "$REAL_GIT" init -q "$REPO"
"$REAL_GIT" -C "$REPO" config user.email fixture@test.local
"$REAL_GIT" -C "$REPO" config user.name fixture

PLAN="$REPO/docs/epics/93-fixture-epic/plan.md"
cat > "$PLAN" <<'EOF'
# Epic: fixture — cold acceptance check

## Work items

### 1. clean item
- **Touches:**
  - `src/feature.txt`
- **DoD:** the feature file exists; the feature file mentions widget

### 2. unmet criterion item
- **Touches:**
  - `src/feature.txt`
- **DoD:** the feature file exists; MARKER-UNMET-atomic-write is present in the diff

### 3. declared paths mismatch item
- **Touches:**
  - `src/only-declared.txt`
- **DoD:** irrelevant to this gate

### 4. denylist item
- **DoD:** irrelevant to this gate

### 5. checks red item
- **Touches:**
  - `src/feature.txt`
- **DoD:** irrelevant to this gate

### 6. missing gates-passed item
- **Touches:**
  - `src/feature.txt`
- **DoD:** irrelevant to this gate
EOF
: > "$REPO/README.md"
"$REAL_GIT" -C "$REPO" add -A
"$REAL_GIT" -C "$REPO" commit -q -m base
BASE_SHA="$("$REAL_GIT" -C "$REPO" rev-parse HEAD)"
"$REAL_GIT" -C "$REPO" update-ref refs/remotes/origin/main "$BASE_SHA"

mk_branch() { # $1=branch $2=file $3=content
  "$REAL_GIT" -C "$REPO" checkout -q -b "$1" "$BASE_SHA"
  mkdir -p "$(dirname "$REPO/$2")"
  printf '%s\n' "$3" > "$REPO/$2"
  "$REAL_GIT" -C "$REPO" add -A
  "$REAL_GIT" -C "$REPO" commit -q -m "$1"
  "$REAL_GIT" -C "$REPO" update-ref "refs/remotes/origin/$1" "$1"
  "$REAL_GIT" -C "$REPO" checkout -q "$BASE_SHA" --detach
  "$REAL_GIT" -C "$REPO" branch -q -D "$1"
}

mk_branch feat/item-1 src/feature.txt "the widget lives here"
mk_branch feat/item-2 src/feature.txt "the widget lives here, but not the marker clause"
mk_branch feat/item-3 src/other-file.txt "never touches the declared path"
mk_branch feat/item-4 .env "SECRET=leaked"
mk_branch feat/item-5 src/feature.txt "the widget lives here"
mk_branch feat/item-6 src/feature.txt "the widget lives here"

status_write() { # $1=branch $2=state
  local SLUG_F
  SLUG_F="$(printf '%s' "$1" | tr '/' '-')"
  cat > "$REPO/docs/epics/93-fixture-epic/status/$SLUG_F.json" <<EOF
{
  "item": "fixture",
  "branch": "$1",
  "state": "$2",
  "detail": "seeded by fixture",
  "commit": "abc123",
  "updated": "2026-09-10T00:00:00Z"
}
EOF
}
status_write feat/item-1 pr-opened
status_write feat/item-2 pr-opened
status_write feat/item-3 pr-opened
status_write feat/item-4 pr-opened
status_write feat/item-5 pr-opened
status_write feat/item-6 implementing   # never reached gates-passed/pr-opened

GH_CALL_LOG="$SANDBOX/gh-calls.log"
: > "$GH_CALL_LOG"
GH_STUB="$SANDBOX/gh"
cat > "$GH_STUB" <<STUB_EOF
#!/usr/bin/env bash
CFG="\${GH_CFG_DIR:?GH_CFG_DIR not set}"
printf '%s\n' "\$*" >> "$GH_CALL_LOG"
case "\${1:-}" in
  repo)
    [ "\${2:-}" = view ] && { cat "\$CFG/slug" 2>/dev/null; exit 0; }
    ;;
  pr)
    case "\${2:-}" in
      view)
        printf '%s\t%s\t%s\t%s\n' \\
          "\$(cat "\$CFG/pr-number" 2>/dev/null)" \\
          "\$(cat "\$CFG/pr-head" 2>/dev/null)" \\
          "\$(cat "\$CFG/pr-base" 2>/dev/null)" \\
          "\$(cat "\$CFG/pr-url" 2>/dev/null)"
        exit 0
        ;;
      checks)
        exit "\$(cat "\$CFG/checks-rc" 2>/dev/null || echo 0)"
        ;;
      diff)
        cat "\$CFG/pr-diff" 2>/dev/null
        exit 0
        ;;
      comment)
        PREV=""
        for A in "\$@"; do
          [ "\$PREV" = "--body" ] && printf '%s' "\$A" > "\$CFG/last-comment-body"
          PREV="\$A"
        done
        exit 0
        ;;
    esac
    ;;
  issue)
    [ "\${2:-}" = view ] && { cat "\$CFG/issue-body" 2>/dev/null; exit 0; }
    ;;
esac
exit 1
STUB_EOF
chmod +x "$GH_STUB"
export INTAKE_GH="$GH_STUB"

CLAUDE_NEVER="$SANDBOX/claude-never"
CLAUDE_NEVER_MARKER="$SANDBOX/claude-never.marker"
cat > "$CLAUDE_NEVER" <<EOF
#!/usr/bin/env bash
printf 'INVOKED %s\n' "\$*" >> "$CLAUDE_NEVER_MARKER"
exit 1
EOF
chmod +x "$CLAUDE_NEVER"

mk_cfg() { # $1=name $2=pr-number $3=head $4=base -> stdout cfg dir
  local CFG="$SANDBOX/gh-cfg-$1"
  mkdir -p "$CFG"
  printf '%s' "$2" > "$CFG/pr-number"
  printf '%s' "$3" > "$CFG/pr-head"
  printf '%s' "$4" > "$CFG/pr-base"
  printf 'https://github.com/acme/fixture/pull/%s' "$2" > "$CFG/pr-url"
  printf '0' > "$CFG/checks-rc"
  printf '%s' "acme/fixture" > "$CFG/slug"
  printf '' > "$CFG/issue-body"
  printf '' > "$CFG/pr-diff"
  printf '%s' "$CFG"
}

run_verify() { # $1=item $2=pr $3=cfg-dir -> stdout+stderr combined, sets RC
  VOUT="$(GH_CFG_DIR="$3" INTAKE_CLAUDE="$CLAUDE_NEVER" bash "$SCRIPT" \
            --plan "$PLAN" --item "$1" --pr "$2" --repo "$REPO" --slug acme/fixture 2>&1)"
  VRC=$?
}

# C1 — the DoD's own named case: status.json does not show pr-opened.
CFG6="$(mk_cfg six 106 feat/item-6 main)"
rm -f "$CLAUDE_NEVER_MARKER"
run_verify 6 106 "$CFG6"
check "C1a rc 2 — refused, not fail, not pass" "2" "$VRC"
check_contains "C1b names status.json / pr-opened as the reason" 1 "$VOUT" "does not show pr-opened"
check "C1c NO session was ever spawned (claude marker absent)" "0" "$( [ -f "$CLAUDE_NEVER_MARKER" ] && echo 1 || echo 0 )"
check "C1d NO PR comment was posted" "0" "$( [ -f "$CFG6/last-comment-body" ] && echo 1 || echo 0 )"

# C2 — declared-paths-gate mismatch (item declares a path never touched).
CFG3="$(mk_cfg three 103 feat/item-3 main)"
rm -f "$CLAUDE_NEVER_MARKER"
run_verify 3 103 "$CFG3"
check "C2a rc 2 — refused" "2" "$VRC"
check_contains "C2b names declared-paths-gate as the reason" 1 "$VOUT" "declared-paths-gate did not report clean"
check "C2c NO session was ever spawned" "0" "$( [ -f "$CLAUDE_NEVER_MARKER" ] && echo 1 || echo 0 )"

# C3 — gh pr checks is not green.
CFG5="$(mk_cfg five 105 feat/item-5 main)"
printf '1' > "$CFG5/checks-rc"
rm -f "$CLAUDE_NEVER_MARKER"
run_verify 5 105 "$CFG5"
check "C3a rc 2 — refused" "2" "$VRC"
check_contains "C3b names gh pr checks as the reason" 1 "$VOUT" "gh pr checks is not green"
check "C3c NO session was ever spawned" "0" "$( [ -f "$CLAUDE_NEVER_MARKER" ] && echo 1 || echo 0 )"

# C4 — the real diff touches a sensitive-path denylist floor entry (.env).
CFG4="$(mk_cfg four 104 feat/item-4 main)"
rm -f "$CLAUDE_NEVER_MARKER"
run_verify 4 104 "$CFG4"
check "C4a rc 2 — refused" "2" "$VRC"
check_contains "C4b names the sensitive-path denylist as the reason" 1 "$VOUT" "sensitive-path denylist"
check "C4c NO session was ever spawned" "0" "$( [ -f "$CLAUDE_NEVER_MARKER" ] && echo 1 || echo 0 )"

# ============================================================ SECTION D ===
# CLEAN PR — every gate clears, a stubbed cold session writes a valid PASS
# verdict, and the harness posts it as a PR comment.
echo
echo "=== D. clean PR — all four gates clear, verifier session -> pass ==="

CLAUDE_PASS="$SANDBOX/claude-pass"
CLAUDE_PASS_LOG="$SANDBOX/claude-pass.log"
cat > "$CLAUDE_PASS" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$CLAUDE_PASS_LOG"
VPATH="\$(printf '%s' "\$*" | grep -oE '/[^[:space:]]*docs/epics/verdict\.json' | head -1)"
[ -n "\$VPATH" ] || exit 1
mkdir -p "\$(dirname "\$VPATH")"
cat > "\$VPATH" <<VERDICT_EOF
{
  "verdict": "pass",
  "criteria": [
    { "text": "the feature file exists", "met": true, "evidence": "src/feature.txt is present in the diff" },
    { "text": "the feature file mentions widget", "met": true, "evidence": "src/feature.txt contains the word widget" }
  ]
}
VERDICT_EOF
exit 0
EOF
chmod +x "$CLAUDE_PASS"

CFG1="$(mk_cfg one 101 feat/item-1 main)"
printf 'MARKER-ISSUE-BODY-7c2a1f the reported behaviour goes here' > "$CFG1/issue-body"
"$REAL_GIT" -C "$REPO" diff "$BASE_SHA...origin/feat/item-1" > "$CFG1/pr-diff"

D_OUT="$(GH_CFG_DIR="$CFG1" INTAKE_CLAUDE="$CLAUDE_PASS" bash "$SCRIPT" \
           --plan "$PLAN" --item 1 --pr 101 --repo "$REPO" --slug acme/fixture --issue 55 2>&1)"; D_RC=$?
check "D1 rc 0 — pass" "0" "$D_RC"
check_contains "D2 result line reports verdict=pass" 1 "$D_OUT" "VERIFY-ITEM-RESULT: verdict=pass"
check "D3 a session WAS spawned this time" "1" "$( [ -s "$CLAUDE_PASS_LOG" ] && echo 1 || echo 0 )"
check_contains "D4 the brief embedded the item's own DoD" 1 "$(cat "$CLAUDE_PASS_LOG")" "the feature file mentions widget"
check_contains "D5 the brief embedded the source issue's body" 1 "$(cat "$CLAUDE_PASS_LOG")" "MARKER-ISSUE-BODY-7c2a1f"
check_contains "D6 the brief embedded the real diff" 1 "$(cat "$CLAUDE_PASS_LOG")" "src/feature.txt"
check "D7 a PR comment was posted" "1" "$( [ -f "$CFG1/last-comment-body" ] && echo 1 || echo 0 )"
check_contains "D8 the comment names PASS" 1 "$(cat "$CFG1/last-comment-body" 2>/dev/null)" "Cold acceptance verdict: PASS"

# ============================================================ SECTION E ===
# THE DoD's OWN CASE: a deliberately unmet criterion -> fail, and the
# verdict/comment NAME that specific unmet line, not a generic "fail."
echo
echo "=== E. unmet DoD criterion — fail, naming that specific line ======="

CLAUDE_FAIL="$SANDBOX/claude-fail"
cat > "$CLAUDE_FAIL" <<EOF
#!/usr/bin/env bash
VPATH="\$(printf '%s' "\$*" | grep -oE '/[^[:space:]]*docs/epics/verdict\.json' | head -1)"
[ -n "\$VPATH" ] || exit 1
mkdir -p "\$(dirname "\$VPATH")"
cat > "\$VPATH" <<VERDICT_EOF
{
  "verdict": "fail",
  "criteria": [
    { "text": "the feature file exists", "met": true, "evidence": "src/feature.txt is present in the diff" },
    { "text": "MARKER-UNMET-atomic-write is present in the diff", "met": false, "evidence": "MARKER-UNMET-atomic-write does not appear anywhere in the diff — the criterion the plan's DoD names is unmet" }
  ]
}
VERDICT_EOF
exit 0
EOF
chmod +x "$CLAUDE_FAIL"

CFG2="$(mk_cfg two 102 feat/item-2 main)"
"$REAL_GIT" -C "$REPO" diff "$BASE_SHA...origin/feat/item-2" > "$CFG2/pr-diff"

E_OUT="$(GH_CFG_DIR="$CFG2" INTAKE_CLAUDE="$CLAUDE_FAIL" bash "$SCRIPT" \
           --plan "$PLAN" --item 2 --pr 102 --repo "$REPO" --slug acme/fixture 2>&1)"; E_RC=$?
check "E1 rc 1 — fail (never rc 2, the gates DID clear)" "1" "$E_RC"
check_contains "E2 result line reports verdict=fail" 1 "$E_OUT" "VERIFY-ITEM-RESULT: verdict=fail"
check "E3 a PR comment was posted" "1" "$( [ -f "$CFG2/last-comment-body" ] && echo 1 || echo 0 )"
check_contains "E4 the comment NAMES the specific unmet criterion" 1 "$(cat "$CFG2/last-comment-body" 2>/dev/null)" "MARKER-UNMET-atomic-write does not appear"
check_contains "E5 the comment says this routes to blocked, not auto-retried" 1 "$(cat "$CFG2/last-comment-body" 2>/dev/null)" "blocked"

# F — a session that writes no usable verdict at all is inconclusive (rc 3),
# never silently promoted to a fail or a pass, and nothing is posted.
echo
echo "=== F. no usable verdict from the session -> inconclusive, never fabricated ==="

CLAUDE_SILENT="$SANDBOX/claude-silent"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CLAUDE_SILENT"
chmod +x "$CLAUDE_SILENT"

CFG1B="$(mk_cfg one-silent 107 feat/item-1 main)"
"$REAL_GIT" -C "$REPO" diff "$BASE_SHA...origin/feat/item-1" > "$CFG1B/pr-diff"
F_OUT="$(GH_CFG_DIR="$CFG1B" INTAKE_CLAUDE="$CLAUDE_SILENT" bash "$SCRIPT" \
           --plan "$PLAN" --item 1 --pr 107 --repo "$REPO" --slug acme/fixture 2>&1)"; F_RC=$?
check "F1 rc 3 — inconclusive, not fabricated as pass or fail" "3" "$F_RC"
check "F2 no PR comment was posted" "0" "$( [ -f "$CFG1B/last-comment-body" ] && echo 1 || echo 0 )"

echo
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
