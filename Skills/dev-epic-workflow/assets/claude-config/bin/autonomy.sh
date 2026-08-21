#!/usr/bin/env bash
# The autonomy control surface — dev-epic-workflow, epic 11 item 1.
#
# THIS FILE IS THE SWITCHBOARD, AND SINCE EPIC 11 ITEM 3 IT IS CONNECTED. It
# parses, validates, resolves and reports the controls; `bin/dispatch.sh` is the
# one file that acts on them, and `AUTONOMY_ENFORCED` below says so in a form a
# fixture can assert. Nothing in THIS file ever acts: it answers questions about
# permission and writes nothing but its own variables. What it now grants is one
# rung — L2 — whose ceiling is an open pull request.
#
# Used two ways:
#   sourced   `. autonomy.sh` — the runner and (later) the dispatcher call the
#             functions below. Sourcing NEVER exits the caller and never
#             mutates anything outside its own variables.
#   executed  `autonomy.sh --check [...]` — validate the config and print the
#             resolved surface for a human or a fixture. Read-only, always.
#
# ---------------------------------------------------------------------------
# WHY A SIBLING FILE AND NOT A THIRD FIELD ON THE `repos` LINE
#
# Epic 08 item 2 left the choice open ("extend the `repos` line format, or a
# sibling file — decide at implementation"). Three reasons decide it here, and
# the first one is a measured hazard rather than a preference:
#
#  1. The `repos` parse splits on the LAST pipe, because checkout paths contain
#     spaces and whitespace is not a safe separator. A third field would make
#     `~/Source/LODE|dev|L2` parse as REPO_DIR=`~/Source/LODE|dev`,
#     BASE_OVERRIDE=`L2` under the CURRENT reader — so any machine running an
#     older copy of the runner against a newer `repos` file would silently
#     retarget the integration branch. The failure is silent, it is a branch
#     change, and it is exactly the class of defect epic 09 spent four items
#     removing. A file the old reader never opens cannot do that.
#  2. `repos` is a MEMBERSHIP list — which repos the poller visits at all — and
#     autonomy is a PERMISSION. Collapsing them means one line edit both
#     enrols a repo and grants it a rung. They deserve separate edits, separate
#     review, and separate blast radius, for the same reason the global
#     override and the stop file below are two files and not one.
#  3. The policy is not one value. Required labels, forbidden labels, a
#     path denylist and two size ceilings do not fit on a pipe-delimited line
#     without inventing a nested syntax, and a nested syntax on a line whose
#     separator is already ambiguous is how you get the first problem twice.
#
# ---------------------------------------------------------------------------
# THE FOUR FILES, AND WHY THREE OF THEM ANSWER TO `ls`
#
#   ~/.config/claude-intake/autonomy        the config: level + policy + budget
#   ~/.config/claude-intake/AUTONOMY-OFF    presence pins EVERY repo to L0
#   ~/.config/claude-intake/STOP            presence prevents a cycle starting
#   ~/.config/claude-intake/promotions/     human-authored promotion records
#
# AUTONOMY-OFF and STOP ARE NOT THE SAME CONTROL and must never be merged.
# Epic 08 item 2 states the distinction and epic 11 item 1 restates it:
#
#   AUTONOMY-OFF  revokes the autonomy ABOVE L0 and leaves unattended drafting
#                 running. It is the "I do not trust the dispatcher today"
#                 switch, and the thing it protects is that L0 keeps working —
#                 proposals keep being drafted while nothing is dispatched.
#   STOP          prevents a cycle from starting AT ALL, L0 included. It is the
#                 "stop the machine" switch, and it is honoured before the
#                 credential file is read, before the lock is taken, and before
#                 any GitHub call, so it works on a machine whose token has
#                 expired or whose `gh` is missing.
#
# Collapsing them costs you the ability to revoke dispatch without also
# stopping drafting — which is the single most likely thing to want at 2am,
# and the reason the distinction was designed before either was built.
#
# Both are PRESENCE signals. Contents are never read, so `touch` is the whole
# interface and `ls ~/.config/claude-intake/` is the whole status check. No
# session, no config archaeology, no knowing which repo is configured.
#
# ---------------------------------------------------------------------------
# CONFIG FORMAT
#
#   # comments and blank lines are ignored
#   [global]
#   budget.max-items      = 1
#   budget.max-wall-clock = 60m
#   promotion.min-cycles.L2 = 1
#
#   [/Users/jonathanstevenson/Source/LODE]     # a PATH section (starts with / or ~)
#   level          = L2
#   require-labels = epic:planned
#   forbid-labels  = do-not-automate
#   deny-paths     = alembic/*, api/config.py
#   max-files      = 40
#   max-diff-lines = 800
#
#   [GreatFigure8/Claude-Skills]               # a SLUG section (owner/name)
#   level = L0
#
# A section header beginning `/` or `~` is a checkout PATH; anything else must
# be an `owner/name` slug. That is unambiguous — a path always has a leading
# slash after `~` expansion and a slug never does — so one file can be written
# in whichever identity the reader has to hand. If BOTH a path section and a
# slug section match the same repo, that is a conflict, not a merge: the config
# is refused and every repo resolves L0.
#
# ANY error anywhere in the file refuses the WHOLE file and every repo resolves
# L0. Per-section error isolation was considered and rejected: a config with a
# typo is a config whose author's intent is unknown, and the safe reading of an
# unknown intent about permissions is "none".
#
# ---------------------------------------------------------------------------
# THE PROMOTION-RECORD CONTRACT (defined here; written after item 2; read by
# item 3). See references/autonomy-control-surface.md for the human version.
#
#   path     <promotions-dir>/<owner>__<name>.<LEVEL>       e.g.
#            ~/.config/claude-intake/promotions/GreatFigure8__Claude-Skills.L2
#   format   `key: value`, one per line, `#` comments allowed
#   required repo, level, granted, granted-by, cycles, ledger, evidence
#
# `ls` on the directory is therefore a complete answer to "what is promoted to
# what". A level above L0 with no valid record resolves to L0 and says which
# field was missing. THE AUTOMATION NEVER WRITES THIS DIRECTORY — a system that
# can write its own promotion evidence has widened its own permissions by
# another route, so the only writes in this file are to variables.

# --------------------------------------------------------------- this build
# The highest rung this control surface RECOGNISES. L3/L4 are out of scope for
# epic 11 and are refused rather than silently clamped.
AUTONOMY_CEILING=L2

# Whether anything ACTS on a resolved level. `no` for the whole of item 1, and
# `yes` since item 3 wired bin/dispatch.sh to it. This is the machine-readable
# form of "a resolved level now has consequences", and a fixture asserts it —
# flipping it back to `no` while the dispatcher exists would be a lie a fixture
# catches rather than a comment nobody re-reads.
AUTONOMY_ENFORCED=yes

# ------------------------------------------------------------------- paths
AUTONOMY_CONFIG_FILE="${INTAKE_AUTONOMY_FILE:-$HOME/.config/claude-intake/autonomy}"
AUTONOMY_OVERRIDE_FILE="${INTAKE_AUTONOMY_OVERRIDE:-$HOME/.config/claude-intake/AUTONOMY-OFF}"
AUTONOMY_STOP_FILE="${INTAKE_STOP_FILE:-$HOME/.config/claude-intake/STOP}"
AUTONOMY_PROMOTIONS_DIR="${INTAKE_PROMOTIONS_DIR:-$HOME/.config/claude-intake/promotions}"

# ------------------------------------------------------- the denylist FLOOR
# Always in force at any level above L0, and there is NO config key that
# shrinks it — `deny-paths` only ADDS. Epic 08's invariant names the classes:
# CI config, workflow files, credential handling, install.sh, the control-plane
# hooks themselves, plus whatever the repo declares.
#
# Matching is shell `case` globbing over the full repo-relative path exactly as
# `git diff --name-only` prints it, so `*` CROSSES `/` — `.github/*` matches
# `.github/workflows/ci.yml`. That is deliberately unlike gitignore, it is
# stated here rather than discovered, and it errs toward matching MORE paths.
# A pattern is also tried as `<pattern>/*` so a bare directory name covers its
# contents.
#
# One pattern per line, `<glob>  <why>`; only the first field is the pattern.
AUTONOMY_DENY_FLOOR='.github/*|CI and workflow configuration
.circleci/*|CI configuration
.gitlab-ci.yml|CI configuration
azure-pipelines.yml|CI configuration
Jenkinsfile|CI configuration
.gitmodules|submodule redirection
install.sh|the installer for this control plane
*/install.sh|an installer anywhere in the tree
*/claude-config/hooks/*|the control-plane hooks themselves
*/claude-config/bin/*|the unattended runner and this control surface
.claude/hooks/*|installed control-plane hooks
.claude/settings.json|hook wiring and tool permissions
.claude/settings.local.json|hook wiring and tool permissions
*.plist|launchd job definitions
.env|credential material
*/.env|credential material
*.pem|credential material
*.key|credential material
*.p12|credential material
id_rsa*|credential material
*/secrets/*|credential material
.npmrc|registry credentials
.netrc|host credentials'

# --------------------------------------------------------------- defaults
# max-items is not invented: "one item at a time" is an epic 11 invariant.
# max-wall-clock IS a chosen number — 60 minutes, on the reasoning that the one
# measured executor item on a real stack (LODE PR #857) finished well inside an
# hour, so an hour is a runaway rather than a slow day. It is a default to be
# revised against ledger data once item 2 exists, not a measurement.
AUTONOMY_DEFAULT_MAX_ITEMS=1
AUTONOMY_DEFAULT_MAX_WALL_CLOCK=60m
# Minimum clean cycles a promotion record must attest to, per level. 1 means
# "a record citing no cycle at all is refused". Epic 11 leaves the real number
# for L3 as an open question, and L3 is refused as above-ceiling here anyway,
# so no number is invented for it.
AUTONOMY_DEFAULT_MIN_CYCLES=1

# Identities a promotion record may NOT be granted by. A record is a human act;
# if the automation could author one it could promote itself.
AUTONOMY_RESERVED_GRANTORS='unattended-intake claude claude-code automation runner intake'

# ------------------------------------------------------------------ state
AUTONOMY_LOADED=no
AUTONOMY_CONFIG_PRESENT=no
AUTONOMY_CONFIG_OK=yes
AUTONOMY_CONFIG_ERRORS=""
AUTONOMY_PARSED=""
AUTONOMY_BUDGET_MAX_ITEMS=""
AUTONOMY_BUDGET_MAX_SECONDS=""
AUTONOMY_LEVEL=L0
AUTONOMY_REASON=""
AUTONOMY_LOG=""
AUTONOMY_REFUSAL=""
AUTONOMY_PROMOTION_DETAIL=""
AUTONOMY_REQUIRE_LABELS=""
AUTONOMY_FORBID_LABELS=""
AUTONOMY_DENY_PATHS=""
AUTONOMY_MAX_FILES=""
AUTONOMY_MAX_DIFF_LINES=""

# --------------------------------------------------------------- utilities

autonomy_trim() { # stdin -> stdout, strip leading/trailing whitespace per line
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

_autonomy_strip() { # $1 -> stdout, no subshell-free trim available in sh 3.2
  local S="${1-}"
  S="${S#"${S%%[![:space:]]*}"}"
  S="${S%"${S##*[![:space:]]}"}"
  printf '%s' "$S"
}

# `~/x` -> `$HOME/x`, trailing slashes removed, and resolved through symlinks
# when the directory exists (macOS hands out /var and /private/var for the same
# place, and a fixture sandbox lives in exactly that overlap).
autonomy_normalise_path() { # $1 = path -> stdout
  local P
  P="$(_autonomy_strip "${1-}")"
  case "$P" in '~') P="$HOME" ;; '~/'*) P="$HOME/${P#\~/}" ;; esac
  while :; do
    case "$P" in */) P="${P%/}" ;; *) break ;; esac
    [ -n "$P" ] || { P=/; break; }
  done
  if [ -d "$P" ]; then
    ( cd "$P" 2>/dev/null && pwd -P ) || printf '%s' "$P"
  else
    printf '%s' "$P"
  fi
}

autonomy_is_uint() { # $1 -> 0 if a non-negative integer
  case "${1-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

# `90` `90s` `45m` `2h` -> seconds. Refuses zero, negatives and anything else.
autonomy_parse_duration() { # $1 -> stdout seconds, rc 1 on refusal
  local V="${1-}" N M
  case "$V" in
    *s) N="${V%s}"; M=1 ;;
    *m) N="${V%m}"; M=60 ;;
    *h) N="${V%h}"; M=3600 ;;
    *)  N="$V";     M=1 ;;
  esac
  autonomy_is_uint "$N" || return 1
  [ "$N" -gt 0 ] 2>/dev/null || return 1
  printf '%s' "$((N * M))"
}

autonomy_normalise_level() { # $1 -> stdout L0..L4, rc 1 on refusal
  case "${1-}" in
    L0|l0) printf 'L0' ;;
    L1|l1) printf 'L1' ;;
    L2|l2) printf 'L2' ;;
    L3|l3) printf 'L3' ;;
    L4|l4) printf 'L4' ;;
    *) return 1 ;;
  esac
}

autonomy_level_num() { printf '%s' "${1#L}"; }

# A glob that would be re-parsed as shell syntax inside `case` is refused at
# config-parse time rather than tolerated at match time. This is the only place
# a config value reaches a `case` pattern unquoted, so it is the only place
# that needs the guard.
autonomy_pattern_ok() { # $1 -> 0 if safe to use as a case glob
  case "${1-}" in
    ''|*'|'*|*'('*|*')'*|*'&'*|*';'*|*'`'*|*'$'*|*'"'*|*"'"*) return 1 ;;
    *) return 0 ;;
  esac
}

# --------------------------------------------------------- presence signals
# Contents are never read. `touch` is the whole interface.
autonomy_stop_requested()  { [ -e "$AUTONOMY_STOP_FILE" ]; }
autonomy_override_active() { [ -e "$AUTONOMY_OVERRIDE_FILE" ]; }

# ------------------------------------------------------------------ parsing
_autonomy_err() { AUTONOMY_CONFIG_OK=no; AUTONOMY_CONFIG_ERRORS="$AUTONOMY_CONFIG_ERRORS$AUTONOMY_CONFIG_FILE:$1: $2
"; }

_autonomy_get() { # $1 section  $2 key -> stdout value (empty when unset)
  # Pure shell rather than `awk -v`: awk processes escape sequences in a -v
  # value, so a section name containing a backslash would be silently rewritten
  # before the comparison. Config files are tens of lines; the loop is free.
  local S K V
  while IFS='	' read -r S K V; do
    [ "$S" = "$1" ] || continue
    [ "$K" = "$2" ] || continue
    printf '%s' "$V"
    return 0
  done <<GET_EOF
$AUTONOMY_PARSED
GET_EOF
  return 0
}

_autonomy_sections() { printf '%s\n' "$AUTONOMY_PARSED" | awk -F'\t' 'NF>=2 {print $1}' | sort -u | grep . ; }

# A section EXISTS if it was declared, even if it set no keys — `[foo]` with
# nothing under it is still an answer about foo, and in particular it is still a
# conflict with a second section naming the same repo.
_autonomy_section_exists() { # $1 = section name
  local S
  while IFS= read -r S; do
    if [ "$S" = "$1" ]; then return 0; fi
  done <<EXISTS_EOF
$(_autonomy_sections)
EXISTS_EOF
  return 1
}

# Keys legal in [global] and keys legal in a repo section — disjoint on
# purpose, so a budget key in a repo section is an error rather than a value
# that quietly does nothing.
_autonomy_global_key_ok() {
  case "${1-}" in
    budget.max-items|budget.max-wall-clock) return 0 ;;
    promotion.min-cycles.L1|promotion.min-cycles.L2|promotion.min-cycles.L3|promotion.min-cycles.L4) return 0 ;;
    *) return 1 ;;
  esac
}
_autonomy_repo_key_ok() {
  case "${1-}" in
    level|require-labels|forbid-labels|deny-paths|max-files|max-diff-lines) return 0 ;;
    *) return 1 ;;
  esac
}

# Parse the config into AUTONOMY_PARSED as `section<TAB>key<TAB>value` lines.
# No associative arrays: /bin/bash on macOS is 3.2 and this file has to run
# under whatever `env bash` finds. No eval anywhere, ever — this file reads
# attacker-adjacent config and turns none of it into code.
autonomy_load() {
  if [ "$AUTONOMY_LOADED" = yes ]; then return 0; fi
  AUTONOMY_LOADED=yes
  AUTONOMY_CONFIG_OK=yes
  AUTONOMY_CONFIG_ERRORS=""
  AUTONOMY_PARSED=""
  AUTONOMY_BUDGET_MAX_ITEMS="$AUTONOMY_DEFAULT_MAX_ITEMS"
  AUTONOMY_BUDGET_MAX_SECONDS="$(autonomy_parse_duration "$AUTONOMY_DEFAULT_MAX_WALL_CLOCK")"

  if [ ! -e "$AUTONOMY_CONFIG_FILE" ]; then
    AUTONOMY_CONFIG_PRESENT=no
    return 0
  fi
  AUTONOMY_CONFIG_PRESENT=yes
  if [ ! -r "$AUTONOMY_CONFIG_FILE" ]; then
    _autonomy_err 0 "not readable"
    return 1
  fi

  local LINE RAW N SECTION KEY VALUE SEEN
  N=0; SECTION=""; SEEN=""
  while IFS= read -r RAW || [ -n "$RAW" ]; do
    N=$((N + 1))
    LINE="$(_autonomy_strip "$RAW")"
    case "$LINE" in ''|'#'*|';'*) continue ;; esac
    case "$LINE" in
      '['*']')
        SECTION="$(_autonomy_strip "${LINE#[}")"
        SECTION="$(_autonomy_strip "${SECTION%]}")"
        if [ -z "$SECTION" ]; then _autonomy_err "$N" "empty section header"; continue; fi
        case "$SECTION" in *"$(printf '\t')"*) _autonomy_err "$N" "section header contains a tab"; SECTION=""; continue ;; esac
        if [ "$SECTION" != global ]; then
          case "$SECTION" in
            /*|'~'*) SECTION="$(autonomy_normalise_path "$SECTION")" ;;
            */*/*) _autonomy_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
            */*) : ;;
            *) _autonomy_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
          esac
        fi
        case "
$SEEN" in *"
$SECTION"*) _autonomy_err "$N" "duplicate section [$SECTION]" ;; esac
        SEEN="$SEEN
$SECTION"
        # A bare marker row, so a section that sets no keys is still DECLARED.
        # `[repo]` with nothing under it is an answer about that repo, and in
        # particular it still conflicts with a second section naming it.
        AUTONOMY_PARSED="$AUTONOMY_PARSED$SECTION		
"
        continue ;;
    esac
    case "$LINE" in
      *=*) ;;
      *) _autonomy_err "$N" "not a comment, a [section] header, or a key = value line: $LINE"; continue ;;
    esac
    if [ -z "$SECTION" ]; then
      _autonomy_err "$N" "key outside any [section]: $LINE"
      continue
    fi
    KEY="$(_autonomy_strip "${LINE%%=*}")"
    VALUE="$(_autonomy_strip "${LINE#*=}")"
    case "$VALUE" in *"$(printf '\t')"*) _autonomy_err "$N" "value for '$KEY' contains a tab"; continue ;; esac
    if [ -z "$VALUE" ]; then
      _autonomy_err "$N" "'$KEY' has an empty value; delete the line or give it one"
      continue
    fi
    if [ "$SECTION" = global ]; then
      if ! _autonomy_global_key_ok "$KEY"; then
        if _autonomy_repo_key_ok "$KEY"; then
          _autonomy_err "$N" "'$KEY' is a per-repo key and does not belong in [global]"
        else
          _autonomy_err "$N" "unknown key '$KEY' in [global]"
        fi
        continue
      fi
    else
      if ! _autonomy_repo_key_ok "$KEY"; then
        if _autonomy_global_key_ok "$KEY"; then
          _autonomy_err "$N" "'$KEY' is a global key and does not belong in [$SECTION]"
        else
          _autonomy_err "$N" "unknown key '$KEY' in [$SECTION]"
        fi
        continue
      fi
    fi
    if [ -n "$(_autonomy_get "$SECTION" "$KEY")" ]; then
      _autonomy_err "$N" "duplicate key '$KEY' in [$SECTION]"
      continue
    fi
    AUTONOMY_PARSED="$AUTONOMY_PARSED$SECTION	$KEY	$VALUE
"
  done < "$AUTONOMY_CONFIG_FILE"

  _autonomy_validate_values
  [ "$AUTONOMY_CONFIG_OK" = yes ]
}

# Second pass: every value is checked for shape, and a repo asking for a level
# above L0 is checked for the things that have no safe default.
_autonomy_validate_values() {
  local S V SECS LVL P
  V="$(_autonomy_get global budget.max-items)"
  if [ -n "$V" ]; then
    if autonomy_is_uint "$V" && [ "$V" -ge 1 ]; then AUTONOMY_BUDGET_MAX_ITEMS="$V"
    else _autonomy_err "[global]" "budget.max-items must be an integer >= 1, got '$V'"; fi
  fi
  V="$(_autonomy_get global budget.max-wall-clock)"
  if [ -n "$V" ]; then
    SECS="$(autonomy_parse_duration "$V")" \
      && AUTONOMY_BUDGET_MAX_SECONDS="$SECS" \
      || _autonomy_err "[global]" "budget.max-wall-clock must be a positive duration like 90s, 45m or 2h, got '$V'"
  fi
  for LVL in L1 L2 L3 L4; do
    V="$(_autonomy_get global "promotion.min-cycles.$LVL")"
    [ -n "$V" ] || continue
    autonomy_is_uint "$V" || _autonomy_err "[global]" "promotion.min-cycles.$LVL must be a non-negative integer, got '$V'"
  done

  # Section names contain spaces, so they are iterated with a read loop over a
  # here-doc rather than word splitting. `while read` on the right of a PIPE is
  # a subshell in bash 3.2, and the errors accumulated below have to survive.
  local SECTION_LIST
  SECTION_LIST="$(_autonomy_sections)"
  while IFS= read -r S; do
    [ -n "$S" ] || continue
    if [ "$S" = global ]; then continue; fi
    V="$(_autonomy_get "$S" level)"
    LVL=L0
    if [ -n "$V" ]; then
      LVL="$(autonomy_normalise_level "$V")" \
        || { _autonomy_err "[$S]" "level must be one of L0 L1 L2 L3 L4, got '$V'"; LVL=L0; }
    fi
    for V in max-files max-diff-lines; do
      P="$(_autonomy_get "$S" "$V")"
      [ -n "$P" ] || continue
      if ! autonomy_is_uint "$P" || [ "$P" -lt 1 ]; then
        _autonomy_err "[$S]" "$V must be an integer >= 1, got '$P'"
      fi
    done
    # NOT `for P in $(... )`: an unquoted command substitution in a for-list is
    # pathname-expanded, so validating a pattern like `*.key` would first expand
    # it against the current directory and validate whatever happened to match.
    local DP
    DP="$(printf '%s' "$(_autonomy_get "$S" deny-paths)" | tr ',' '\n')"
    while IFS= read -r P; do
      P="$(_autonomy_strip "$P")"
      [ -n "$P" ] || continue
      autonomy_pattern_ok "$P" \
        || _autonomy_err "[$S]" "deny-paths pattern '$P' contains a character that is not allowed in a glob"
    done <<DENY_EOF
$DP
DENY_EOF
    # A rung above L0 has no safe default for its size ceiling, so it must be
    # stated. Labels legitimately default to empty; a ceiling does not — an
    # unstated ceiling reads as "no ceiling", which is the opposite of a brake.
    if [ "$LVL" != L0 ]; then
      [ -n "$(_autonomy_get "$S" max-files)" ] \
        || _autonomy_err "[$S]" "level $LVL requires max-files to be declared (a size ceiling has no safe default)"
      [ -n "$(_autonomy_get "$S" max-diff-lines)" ] \
        || _autonomy_err "[$S]" "level $LVL requires max-diff-lines to be declared (a size ceiling has no safe default)"
    fi
  done <<SECTIONS
$SECTION_LIST
SECTIONS
}

# ----------------------------------------------------------- promotion record
autonomy_promotion_path() { # $1 = slug, $2 = level
  # owner/name -> owner__name. Every `/` becomes `__`, not just the first, so a
  # slug is recoverable from the filename by eye and `ls` reads as a sentence.
  printf '%s/%s.%s' "$AUTONOMY_PROMOTIONS_DIR" "${1//\//__}" "$2"
}

autonomy_min_cycles() { # $1 = level
  local V
  V="$(_autonomy_get global "promotion.min-cycles.$1")"
  [ -n "$V" ] || V="$AUTONOMY_DEFAULT_MIN_CYCLES"
  printf '%s' "$V"
}

# rc 0 = a valid record grants $2 to $1. rc 1 = refused, and
# AUTONOMY_PROMOTION_DETAIL names exactly what is missing or wrong. Naming it
# is the point: "brakes are structural, not disciplinary" only works if the
# refusal tells you how to satisfy it.
autonomy_promotion_check() { # $1 = repo slug, $2 = level
  local SLUG="$1" LVL="$2" F K V MISSING NEED G
  AUTONOMY_PROMOTION_DETAIL=""
  F="$(autonomy_promotion_path "$SLUG" "$LVL")"
  if [ ! -f "$F" ]; then
    AUTONOMY_PROMOTION_DETAIL="no promotion record at $F"
    return 1
  fi
  if [ ! -r "$F" ]; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F is not readable"
    return 1
  fi
  local R_repo="" R_level="" R_granted="" R_by="" R_cycles="" R_ledger="" R_evidence=""
  while IFS= read -r K || [ -n "$K" ]; do
    K="$(_autonomy_strip "$K")"
    case "$K" in ''|'#'*) continue ;; esac
    case "$K" in *:*) ;; *) continue ;; esac
    V="$(_autonomy_strip "${K#*:}")"
    case "$(_autonomy_strip "${K%%:*}")" in
      repo)        R_repo="$V" ;;
      level)       R_level="$V" ;;
      granted)     R_granted="$V" ;;
      granted-by)  R_by="$V" ;;
      cycles)      R_cycles="$V" ;;
      ledger)      R_ledger="$V" ;;
      evidence)    R_evidence="$V" ;;
    esac
  done < "$F"

  MISSING=""
  [ -n "$R_repo" ]     || MISSING="$MISSING repo"
  [ -n "$R_level" ]    || MISSING="$MISSING level"
  [ -n "$R_granted" ]  || MISSING="$MISSING granted"
  [ -n "$R_by" ]       || MISSING="$MISSING granted-by"
  [ -n "$R_cycles" ]   || MISSING="$MISSING cycles"
  [ -n "$R_ledger" ]   || MISSING="$MISSING ledger"
  [ -n "$R_evidence" ] || MISSING="$MISSING evidence"
  if [ -n "$MISSING" ]; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F is missing required field(s):$MISSING"
    return 1
  fi
  if [ "$R_repo" != "$SLUG" ]; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F names repo '$R_repo', not '$SLUG'"
    return 1
  fi
  if [ "$R_level" != "$LVL" ]; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F grants '$R_level', not '$LVL'"
    return 1
  fi
  case "$R_granted" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) AUTONOMY_PROMOTION_DETAIL="promotion record $F has granted='$R_granted', not an ISO-8601 UTC timestamp (YYYY-MM-DDTHH:MM:SSZ)"
       return 1 ;;
  esac
  for G in $AUTONOMY_RESERVED_GRANTORS; do
    if [ "$R_by" = "$G" ]; then
      AUTONOMY_PROMOTION_DETAIL="promotion record $F is granted-by '$R_by', which names the automation — a promotion record is a human act"
      return 1
    fi
  done
  if ! autonomy_is_uint "$R_cycles"; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F has cycles='$R_cycles', not a non-negative integer"
    return 1
  fi
  NEED="$(autonomy_min_cycles "$LVL")"
  if [ "$R_cycles" -lt "$NEED" ]; then
    AUTONOMY_PROMOTION_DETAIL="promotion record $F attests $R_cycles clean cycle(s); $LVL requires $NEED"
    return 1
  fi
  AUTONOMY_PROMOTION_DETAIL="promotion record $F: $R_cycles clean cycle(s), granted $R_granted by $R_by"
  return 0
}

# --------------------------------------------------------------- resolution
# Sets AUTONOMY_LEVEL, AUTONOMY_REASON, the policy globals, and AUTONOMY_LOG —
# which is EMPTY when there is nothing to say. That emptiness is the inertness
# guarantee at the level a human notices: a machine with no autonomy config
# produces a byte-identical log, not a log with a new "level: L0" line in it.
#
# Precedence, and the order is the whole safety argument:
#   1. global override present      -> L0  (beats even a valid promotion record)
#   2. config malformed             -> L0
#   3. no section for this repo     -> L0  (silent — this is "today")
#   4. configured L0                -> L0
#   5. configured above the ceiling -> L0  (this build does not implement it)
#   6. no valid promotion record    -> L0  (naming what is missing)
#   7. otherwise                    -> the configured level
autonomy_resolve() { # $1 = repo checkout path, $2 = repo slug
  local RPATH RSLUG SEC_PATH SEC_SLUG SEC CONF
  autonomy_load >/dev/null 2>&1 || true
  RPATH="$(autonomy_normalise_path "${1-}")"
  RSLUG="$(_autonomy_strip "${2-}")"
  AUTONOMY_LEVEL=L0
  AUTONOMY_REASON=""
  AUTONOMY_LOG=""
  AUTONOMY_REQUIRE_LABELS=""
  AUTONOMY_FORBID_LABELS=""
  AUTONOMY_DENY_PATHS=""
  AUTONOMY_MAX_FILES=""
  AUTONOMY_MAX_DIFF_LINES=""

  # FIRST, before anything about the config is even looked up. A human who
  # dropped this file in wants to be told that is why, not to be told about a
  # typo three sections down: both answers are L0, but only one of them is the
  # answer to "what did I just do".
  if autonomy_override_active; then
    AUTONOMY_LEVEL=L0
    AUTONOMY_REASON="global override present at $AUTONOMY_OVERRIDE_FILE"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to L0 — $AUTONOMY_REASON (unattended drafting continues)"
    return 0
  fi

  SEC_PATH=""; SEC_SLUG=""
  if [ -n "$AUTONOMY_PARSED" ]; then
    if [ -n "$RPATH" ] && _autonomy_section_exists "$RPATH"; then SEC_PATH="$RPATH"; fi
    if [ -n "$RSLUG" ] && _autonomy_section_exists "$RSLUG"; then SEC_SLUG="$RSLUG"; fi
  fi
  if [ -n "$SEC_PATH" ] && [ -n "$SEC_SLUG" ]; then
    AUTONOMY_REASON="refused: [$SEC_PATH] and [$SEC_SLUG] both configure this repo — one repo, one section"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to L0 — $AUTONOMY_REASON"
    return 0
  fi
  SEC="$SEC_PATH"; [ -n "$SEC" ] || SEC="$SEC_SLUG"

  if [ "$AUTONOMY_CONFIG_OK" != yes ]; then
    AUTONOMY_REASON="autonomy config is invalid; every repo resolves L0"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to L0 — $AUTONOMY_REASON"
    return 0
  fi
  if [ -z "$SEC" ]; then
    # THE SILENT PATH. No section, nothing to say, nothing logged. This is the
    # branch every unconfigured repo on the machine takes.
    AUTONOMY_REASON="unconfigured"
    return 0
  fi

  AUTONOMY_REQUIRE_LABELS="$(_autonomy_get "$SEC" require-labels)"
  AUTONOMY_FORBID_LABELS="$(_autonomy_get "$SEC" forbid-labels)"
  AUTONOMY_DENY_PATHS="$(_autonomy_get "$SEC" deny-paths)"
  AUTONOMY_MAX_FILES="$(_autonomy_get "$SEC" max-files)"
  AUTONOMY_MAX_DIFF_LINES="$(_autonomy_get "$SEC" max-diff-lines)"

  CONF="$(_autonomy_get "$SEC" level)"
  [ -n "$CONF" ] || CONF=L0
  CONF="$(autonomy_normalise_level "$CONF")" || CONF=L0
  if [ "$CONF" = L0 ]; then
    AUTONOMY_REASON="configured L0"
    AUTONOMY_LOG="autonomy: $RSLUG at L0 (configured) — nothing above L0 is available in this build"
    return 0
  fi
  if [ "$(autonomy_level_num "$CONF")" -gt "$(autonomy_level_num "$AUTONOMY_CEILING")" ]; then
    AUTONOMY_REASON="refused: [$SEC] asks for $CONF; this build implements no rung above $AUTONOMY_CEILING"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to L0 — $AUTONOMY_REASON"
    return 0
  fi
  if ! autonomy_promotion_check "$RSLUG" "$CONF"; then
    AUTONOMY_REASON="refused: [$SEC] asks for $CONF but $AUTONOMY_PROMOTION_DETAIL"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to L0 — $AUTONOMY_REASON"
    return 0
  fi
  AUTONOMY_LEVEL="$CONF"
  AUTONOMY_REASON="configured $CONF; $AUTONOMY_PROMOTION_DETAIL"
  AUTONOMY_LOG="autonomy: $RSLUG resolves to $CONF — $AUTONOMY_PROMOTION_DETAIL
autonomy: $RSLUG policy — require-labels=[${AUTONOMY_REQUIRE_LABELS:-none}] forbid-labels=[${AUTONOMY_FORBID_LABELS:-none}] max-files=$AUTONOMY_MAX_FILES max-diff-lines=$AUTONOMY_MAX_DIFF_LINES deny-paths=[${AUTONOMY_DENY_PATHS:-none}] (+${AUTONOMY_DENY_FLOOR_COUNT:-0} built-in)
autonomy: THIS LEVEL IS ENFORCED — AUTONOMY_ENFORCED=$AUTONOMY_ENFORCED; at L2 the next undispatched work item may be executed and proposed as a pull request, and nothing beyond that (no approval, no merge, no issue closed)"
  return 0
}

# ----------------------------------------------------------- admission policy
# Labels arrive COMMA-FENCED — `,a,b,` — which is the shape the runner's
# ISSUE_VIEW_JQ already produces, so membership is one glob and `epic:planned`
# can never match `epic:planned-later`.
autonomy_admit_labels() { # $1 = comma-fenced actual labels
  local ACTUAL="${1-}" L REQ FORB
  AUTONOMY_REFUSAL=""
  case "$ACTUAL" in ,*,) ;; *) ACTUAL=",$(printf '%s' "$ACTUAL" | sed -e 's/^,//' -e 's/,$//')," ;; esac
  # Read loops, not `for L in $(...)`: a GitHub label may contain a space
  # (`needs triage`), and an unquoted command substitution would split it in
  # two and then never match anything.
  REQ="$(printf '%s' "$AUTONOMY_REQUIRE_LABELS" | tr ',' '\n')"
  while IFS= read -r L; do
    L="$(_autonomy_strip "$L")"
    [ -n "$L" ] || continue
    case "$ACTUAL" in
      *",$L,"*) ;;
      *) AUTONOMY_REFUSAL="required label '$L' is absent"; return 1 ;;
    esac
  done <<REQ_EOF
$REQ
REQ_EOF
  FORB="$(printf '%s' "$AUTONOMY_FORBID_LABELS" | tr ',' '\n')"
  while IFS= read -r L; do
    L="$(_autonomy_strip "$L")"
    [ -n "$L" ] || continue
    case "$ACTUAL" in
      *",$L,"*) AUTONOMY_REFUSAL="forbidden label '$L' is present"; return 1 ;;
    esac
  done <<FORB_EOF
$FORB
FORB_EOF
  return 0
}

# THE DENYLIST, AND WHY IT READS STDIN.
#
# Epic 11 item 1 is explicit: the denylist is checked against `git diff
# --name-only` AFTER the executor returns and BEFORE the PR is opened — never
# against a plan's `**Scope:**` prose, which is not machine-readable (that is
# what epic 10 exists for). So this function's only input is a list of real
# paths on stdin, and there is deliberately no variant that takes a plan, a
# scope block, or a declaration. Shaping it for a diff is the contract.
#
#   git -C "$WT" diff --name-only "$BASE...HEAD" | autonomy_deny_diff_paths
#
# rc 0 = nothing denied. rc 1 = at least one path denied, and every denied path
# is printed as `<path><TAB><pattern>` so the refusal can NAME the path.
autonomy_deny_diff_paths() {
  local P G HIT=0 PATTERNS
  PATTERNS="$(printf '%s\n' "$AUTONOMY_DENY_FLOOR" | cut -d'|' -f1)
$(printf '%s' "$AUTONOMY_DENY_PATHS" | tr ',' '\n')"
  while IFS= read -r P || [ -n "$P" ]; do
    P="$(_autonomy_strip "$P")"
    [ -n "$P" ] || continue
    while IFS= read -r G || [ -n "$G" ]; do
      G="$(_autonomy_strip "$G")"
      [ -n "$G" ] || continue
      autonomy_pattern_ok "$G" || continue
      case "$P" in
        $G)   printf '%s\t%s\n' "$P" "$G"; HIT=1; break ;;
        $G/*) printf '%s\t%s\n' "$P" "$G"; HIT=1; break ;;
      esac
    done <<PATTERNS_EOF
$PATTERNS
PATTERNS_EOF
  done
  [ "$HIT" -eq 0 ]
}

# `git diff --numstat` on stdin -> `<files> <lines>`. A binary file counts as a
# file and contributes zero lines, because `-` is what git prints for it and
# inventing a number would be worse than counting none.
autonomy_diff_size() {
  awk -F'\t' '
    NF >= 3 { f++; a = ($1 == "-" ? 0 : $1); d = ($2 == "-" ? 0 : $2); l += a + d }
    END { printf "%d %d", f + 0, l + 0 }'
}

autonomy_check_size() { # $1 = files, $2 = lines
  AUTONOMY_REFUSAL=""
  if [ -n "$AUTONOMY_MAX_FILES" ] && [ "${1:-0}" -gt "$AUTONOMY_MAX_FILES" ]; then
    AUTONOMY_REFUSAL="diff touches $1 files; the ceiling is $AUTONOMY_MAX_FILES"
    return 1
  fi
  if [ -n "$AUTONOMY_MAX_DIFF_LINES" ] && [ "${2:-0}" -gt "$AUTONOMY_MAX_DIFF_LINES" ]; then
    AUTONOMY_REFUSAL="diff changes $2 lines; the ceiling is $AUTONOMY_MAX_DIFF_LINES"
    return 1
  fi
  return 0
}

# ------------------------------------------------------------------- budget
# A budget is a HARD STOP: exceeding it stops new work, and it never degrades
# work in flight to fit. Both callers below answer "may another item start?"
# and neither can answer "shrink this one".
autonomy_budget_allows_item() { # $1 = items already dispatched this cycle
  AUTONOMY_REFUSAL=""
  if [ "${1:-0}" -ge "$AUTONOMY_BUDGET_MAX_ITEMS" ]; then
    AUTONOMY_REFUSAL="per-cycle item budget reached ($AUTONOMY_BUDGET_MAX_ITEMS)"
    return 1
  fi
  return 0
}
autonomy_budget_allows_time() { # $1 = seconds elapsed this cycle
  AUTONOMY_REFUSAL=""
  if [ "${1:-0}" -ge "$AUTONOMY_BUDGET_MAX_SECONDS" ]; then
    AUTONOMY_REFUSAL="per-cycle wall-clock budget reached (${AUTONOMY_BUDGET_MAX_SECONDS}s)"
    return 1
  fi
  return 0
}

AUTONOMY_DENY_FLOOR_COUNT="$(printf '%s\n' "$AUTONOMY_DENY_FLOOR" | grep -c .)"

# ---------------------------------------------------------------------- CLI
# Read-only in every mode. The runner never invokes this path; it exists so a
# human — and a fixture — can see the whole resolved surface without a session,
# which is also how epic 11 item 1's `--dry-run across all four configured
# repos` verification is performed.
_autonomy_cli() {
  local MODE=check REPO_PATH="" REPO_SLUG="" REPOS_FILE="" RC=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --check)  MODE=check ;;
      --repo)   REPO_PATH="${2:-}"; shift ;;
      --slug)   REPO_SLUG="${2:-}"; shift ;;
      --repos)  REPOS_FILE="${2:-}"; shift ;;
      --deny-paths) MODE=deny ;;
      -h|--help) sed -n '1,10p' "$0"; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  autonomy_load >/dev/null 2>&1 || RC=1
  printf 'config          %s%s\n' "$AUTONOMY_CONFIG_FILE" \
    "$( [ "$AUTONOMY_CONFIG_PRESENT" = yes ] && printf '' || printf '   (absent — every repo is L0 and today is unchanged)' )"
  if [ "$AUTONOMY_CONFIG_OK" != yes ]; then
    printf 'config          INVALID — every repo resolves L0\n'
    printf '%s' "$AUTONOMY_CONFIG_ERRORS" | sed 's/^/  error  /'
  fi
  printf 'override        %s   %s\n' "$AUTONOMY_OVERRIDE_FILE" \
    "$( autonomy_override_active && printf 'PRESENT — every repo pinned to L0, drafting continues' || printf 'absent' )"
  printf 'stop            %s   %s\n' "$AUTONOMY_STOP_FILE" \
    "$( autonomy_stop_requested && printf 'PRESENT — no cycle will start' || printf 'absent' )"
  printf 'promotions      %s\n' "$AUTONOMY_PROMOTIONS_DIR"
  printf 'ceiling         %s     enforced=%s\n' "$AUTONOMY_CEILING" "$AUTONOMY_ENFORCED"
  printf 'budget          max-items=%s max-wall-clock=%ss\n' \
    "$AUTONOMY_BUDGET_MAX_ITEMS" "$AUTONOMY_BUDGET_MAX_SECONDS"
  printf 'deny floor      %s built-in patterns, additive only\n' "$AUTONOMY_DENY_FLOOR_COUNT"

  if [ "$MODE" = deny ]; then
    autonomy_resolve "$REPO_PATH" "$REPO_SLUG"
    autonomy_deny_diff_paths || RC=1
    return "$RC"
  fi

  if [ -n "$REPOS_FILE" ]; then
    # Mirrors the runner's own `repos` reader: comment/blank skipping, tilde
    # expansion, and split on the LAST pipe because checkout paths contain
    # spaces. Kept deliberately identical in behaviour; a fixture asserts they
    # agree on a path that itself contains a pipe.
    local RLINE RDIR
    while IFS= read -r RLINE || [ -n "$RLINE" ]; do
      RLINE="$(_autonomy_strip "$RLINE")"
      case "$RLINE" in ''|'#'*) continue ;; esac
      case "$RLINE" in '~'*) RLINE="$HOME${RLINE#\~}" ;; esac
      case "$RLINE" in *\|*) RDIR="${RLINE%|*}" ;; *) RDIR="$RLINE" ;; esac
      RDIR="$(_autonomy_strip "$RDIR")"
      _autonomy_cli_one "$RDIR" ""
    done < "$REPOS_FILE"
    return "$RC"
  fi

  if [ -n "$REPO_PATH" ] || [ -n "$REPO_SLUG" ]; then
    _autonomy_cli_one "$REPO_PATH" "$REPO_SLUG"
  fi
  return "$RC"
}

_autonomy_cli_one() { # $1 path, $2 slug (either may be empty)
  local P="$1" S="$2"
  if [ -z "$S" ] && [ -d "$P/.git" ] && command -v "${INTAKE_GH:-gh}" >/dev/null 2>&1; then
    S="$( cd "$P" 2>/dev/null && "${INTAKE_GH:-gh}" repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null )" || S=""
  fi
  autonomy_resolve "$P" "$S"
  printf 'repo            %s\n' "${S:-${P:-<none>}}"
  printf '  path          %s\n' "$(autonomy_normalise_path "$P")"
  printf '  level         %s   (%s)\n' "$AUTONOMY_LEVEL" "${AUTONOMY_REASON:-unconfigured}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _autonomy_cli "$@"
  exit $?
fi
