#!/usr/bin/env bash
# The autonomy control surface — dev-epic-workflow, epic 11 item 1.
#
# RETIRED AS A LADDER (epic 21 item 1, 2026-09-10). This file used to resolve
# a per-repo level (L0 through L4) from a self-attested, human-authored grant
# record and unlock escalating unattended capability against it: execute
# (epic 11), then approve/merge/chain (epic 19). Epics 11 and 19 are both
# closed with a retro pointing here. Epic 21's Outcome replaces the ladder
# outright: starting a session-scoped loop IS the grant of full autonomy for
# that session, and the loop's own harm floor (epic 21 item 2) is the brake,
# not a human-authored grant record nobody has ever actually written on this
# machine.
#
# WHAT SURVIVES, AND BECOMES THE HARM FLOOR (item 2 wires it up):
#   - the sensitive-path denylist (AUTONOMY_DENY_FLOOR, autonomy_deny_diff_paths)
#   - the size ceiling (max-files / max-diff-lines, autonomy_check_size)
#   - the STOP and AUTONOMY-OFF presence signals
#     (autonomy_stop_requested, autonomy_override_active)
#
# THE HARM FLOOR ITSELF (epic 21 item 2, wired up here). `autonomy_harm_check`
# combines the four survivors above with two new deterministic guards —
# `autonomy_deny_irreversible_op` (refuses a force-push/hard-reset against any
# branch known to exist on origin) and `autonomy_deny_cross_epic_collision`
# (refuses acting on a branch another in-flight epic's own status/ directory
# already claims) — behind ONE well-known entry point: `autonomy.sh
# --harm-check`, so the CLI mode is a real call site today rather than dead
# code waiting on item 3's loop driver. This is the deterministic floor only —
# no "does this look risky" judgment lives here; that is the cold verifier's
# job (item 3/5).
#
# WHAT IS GONE: every level (L0..L4) and the ceiling concept itself, the
# human-authored grant-record file format and its read/write functions, the
# require-labels/forbid-labels admission policy, the per-cycle budget
# (max-items/max-wall-clock/max-issues/max-merges), and the three predicates
# that used to gate automatic approve/merge/chain.
#
# Used two ways:
#   sourced   `. autonomy.sh` — a caller resolves a repo's remaining policy
#             (denylist additions, size ceiling) and checks a diff against it.
#             Sourcing NEVER exits the caller and never mutates anything
#             outside its own variables.
#   executed  `autonomy.sh --check [...]` — print the resolved policy for a
#             human or a fixture. Read-only, always.
#
# ---------------------------------------------------------------------------
# CONFIG FORMAT (repo policy only — no level, no labels, no budget)
#
#   # comments and blank lines are ignored
#   [/Users/jonathanstevenson/Source/LODE]     # a PATH section (starts with / or ~)
#   deny-paths     = alembic/*, api/config.py
#   max-files      = 40
#   max-diff-lines = 800
#
#   [GreatFigure8/Claude-Skills]               # a SLUG section (owner/name)
#   deny-paths = generated/*
#
# A section header beginning `/` or `~` is a checkout PATH; anything else must
# be an `owner/name` slug — unambiguous, so one file can be written in
# whichever identity the reader has to hand. If BOTH a path section and a slug
# section match the same repo, that is a conflict, not a merge: the config is
# refused and every repo resolves the built-in denylist floor only.
#
# ANY error anywhere in the file refuses the WHOLE file. A config with a typo
# is a config whose author's intent is unknown, and the safe reading of an
# unknown intent about a size ceiling is "the built-in floor only, nothing
# looser".
#
# ---------------------------------------------------------------------------
# THE THREE FILES THAT REMAIN
#
#   ~/.config/claude-intake/autonomy        the config: deny-paths / size ceiling
#   ~/.config/claude-intake/AUTONOMY-OFF    presence pins every repo to the
#                                            built-in denylist floor only
#   ~/.config/claude-intake/STOP            presence prevents a cycle starting
#
# (The grant-record directory this file used to read is gone: nothing here
# reads or writes a human-authored capability record any more.)
#
# AUTONOMY-OFF and STOP ARE NOT THE SAME CONTROL and must never be merged.
#   AUTONOMY-OFF  refuses this repo's own deny-paths/size-ceiling ADDITIONS,
#                 leaving only the built-in denylist floor in force. It is the
#                 "I do not trust this repo's own config today" switch.
#   STOP          prevents a cycle from starting AT ALL. It is the "stop the
#                 machine" switch, and it is honoured before the credential
#                 file is read, before the lock is taken, and before any
#                 GitHub call, so it works on a machine whose token has
#                 expired or whose `gh` is missing.
#
# Both are PRESENCE signals. Contents are never read, so `touch` is the whole
# interface and `ls ~/.config/claude-intake/` is the whole status check.

# ------------------------------------------------------------------- paths
AUTONOMY_CONFIG_FILE="${INTAKE_AUTONOMY_FILE:-$HOME/.config/claude-intake/autonomy}"
AUTONOMY_OVERRIDE_FILE="${INTAKE_AUTONOMY_OVERRIDE:-$HOME/.config/claude-intake/AUTONOMY-OFF}"
AUTONOMY_STOP_FILE="${INTAKE_STOP_FILE:-$HOME/.config/claude-intake/STOP}"

# ------------------------------------------------------- the denylist FLOOR
# Always in force, and there is NO config key that shrinks it — `deny-paths`
# only ADDS. Epic 08's invariant names the classes: CI config, workflow files,
# credential handling, install.sh, the control-plane hooks themselves, plus
# whatever the repo declares.
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

# ------------------------------------------------------------------ state
AUTONOMY_LOADED=no
AUTONOMY_CONFIG_PRESENT=no
AUTONOMY_CONFIG_OK=yes
AUTONOMY_CONFIG_ERRORS=""
AUTONOMY_PARSED=""
AUTONOMY_REASON=""
AUTONOMY_LOG=""
AUTONOMY_REFUSAL=""
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

# The only keys a repo section may set. No [global] section any more — the
# only things left to configure are per-repo, so there is nothing left for a
# global section to hold.
_autonomy_repo_key_ok() {
  case "${1-}" in
    deny-paths|max-files|max-diff-lines) return 0 ;;
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
        case "$SECTION" in
          /*|'~'*) SECTION="$(autonomy_normalise_path "$SECTION")" ;;
          */*/*) _autonomy_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
          */*) : ;;
          *) _autonomy_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
        esac
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
    if ! _autonomy_repo_key_ok "$KEY"; then
      _autonomy_err "$N" "unknown key '$KEY' in [$SECTION] (only deny-paths, max-files, max-diff-lines are recognised)"
      continue
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

# Second pass: every value is checked for shape. max-files/max-diff-lines are
# OPTIONAL — a repo may declare only deny-paths additions with no ceiling; item
# 2's harm floor decides what (if anything) to require of a caller, not this
# file.
_autonomy_validate_values() {
  local S V P

  local SECTION_LIST
  SECTION_LIST="$(_autonomy_sections)"
  # Section names contain spaces, so they are iterated with a read loop over a
  # here-doc rather than word splitting. `while read` on the right of a PIPE is
  # a subshell in bash 3.2, and the errors accumulated below have to survive.
  while IFS= read -r S; do
    [ -n "$S" ] || continue
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
  done <<SECTIONS
$SECTION_LIST
SECTIONS
}

# --------------------------------------------------------------- resolution
# Sets AUTONOMY_REASON, AUTONOMY_LOG (empty when there is nothing to say) and
# this repo's own denylist/size-ceiling additions. That emptiness is the
# inertness guarantee at the level a human notices: a machine with no autonomy
# config produces a byte-identical log, not a log with a new line in it.
#
# Precedence:
#   1. global override present      -> built-in floor only (beats config)
#   2. config malformed             -> built-in floor only
#   3. no section for this repo     -> built-in floor only (silent — "today")
#   4. otherwise                    -> this repo's own additions apply too
autonomy_resolve() { # $1 = repo checkout path, $2 = repo slug
  local RPATH RSLUG SEC_PATH SEC_SLUG SEC
  autonomy_load >/dev/null 2>&1 || true
  RPATH="$(autonomy_normalise_path "${1-}")"
  RSLUG="$(_autonomy_strip "${2-}")"
  AUTONOMY_REASON=""
  AUTONOMY_LOG=""
  AUTONOMY_DENY_PATHS=""
  AUTONOMY_MAX_FILES=""
  AUTONOMY_MAX_DIFF_LINES=""

  # FIRST, before anything about the config is even looked up. A human who
  # dropped this file in wants to be told that is why, not to be told about a
  # typo three sections down.
  if autonomy_override_active; then
    AUTONOMY_REASON="global override present at $AUTONOMY_OVERRIDE_FILE"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to the built-in denylist floor only — $AUTONOMY_REASON"
    return 0
  fi

  SEC_PATH=""; SEC_SLUG=""
  if [ -n "$AUTONOMY_PARSED" ]; then
    if [ -n "$RPATH" ] && _autonomy_section_exists "$RPATH"; then SEC_PATH="$RPATH"; fi
    if [ -n "$RSLUG" ] && _autonomy_section_exists "$RSLUG"; then SEC_SLUG="$RSLUG"; fi
  fi
  if [ -n "$SEC_PATH" ] && [ -n "$SEC_SLUG" ]; then
    AUTONOMY_REASON="refused: [$SEC_PATH] and [$SEC_SLUG] both configure this repo — one repo, one section"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to the built-in denylist floor only — $AUTONOMY_REASON"
    return 0
  fi
  SEC="$SEC_PATH"; [ -n "$SEC" ] || SEC="$SEC_SLUG"

  if [ "$AUTONOMY_CONFIG_OK" != yes ]; then
    AUTONOMY_REASON="autonomy config is invalid; every repo resolves the built-in denylist floor only"
    AUTONOMY_LOG="autonomy: $RSLUG pinned to the built-in denylist floor only — $AUTONOMY_REASON"
    return 0
  fi
  if [ -z "$SEC" ]; then
    # THE SILENT PATH. No section, nothing to say, nothing logged. This is the
    # branch every unconfigured repo on the machine takes.
    AUTONOMY_REASON="unconfigured"
    return 0
  fi

  AUTONOMY_DENY_PATHS="$(_autonomy_get "$SEC" deny-paths)"
  AUTONOMY_MAX_FILES="$(_autonomy_get "$SEC" max-files)"
  AUTONOMY_MAX_DIFF_LINES="$(_autonomy_get "$SEC" max-diff-lines)"
  AUTONOMY_REASON="configured"
  AUTONOMY_LOG="autonomy: $RSLUG policy — deny-paths=[${AUTONOMY_DENY_PATHS:-none}] (+${AUTONOMY_DENY_FLOOR_COUNT:-0} built-in) max-files=${AUTONOMY_MAX_FILES:-none} max-diff-lines=${AUTONOMY_MAX_DIFF_LINES:-none}"
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

AUTONOMY_DENY_FLOOR_COUNT="$(printf '%s\n' "$AUTONOMY_DENY_FLOOR" | grep -c .)"

# ---------------------------------------------------------------------- CLI
# Read-only in every mode. The runner never invokes this path; it exists so a
# human — and a fixture — can see the whole resolved policy without a session.
_autonomy_cli() {
  local MODE=check REPO_PATH="" REPO_SLUG="" REPOS_FILE="" RC=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --check)  MODE=check ;;
      --repo)   REPO_PATH="${2:-}"; shift ;;
      --slug)   REPO_SLUG="${2:-}"; shift ;;
      --repos)  REPOS_FILE="${2:-}"; shift ;;
      --deny-paths)  MODE=deny ;;
      -h|--help) sed -n '1,10p' "$0"; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  autonomy_load >/dev/null 2>&1 || RC=1
  printf 'config          %s%s\n' "$AUTONOMY_CONFIG_FILE" \
    "$( [ "$AUTONOMY_CONFIG_PRESENT" = yes ] && printf '' || printf '   (absent — every repo gets the built-in floor only, and today is unchanged)' )"
  if [ "$AUTONOMY_CONFIG_OK" != yes ]; then
    printf 'config          INVALID — every repo resolves the built-in denylist floor only\n'
    printf '%s' "$AUTONOMY_CONFIG_ERRORS" | sed 's/^/  error  /'
  fi
  printf 'override        %s   %s\n' "$AUTONOMY_OVERRIDE_FILE" \
    "$( autonomy_override_active && printf 'PRESENT — every repo pinned to the built-in floor only' || printf 'absent' )"
  printf 'stop            %s   %s\n' "$AUTONOMY_STOP_FILE" \
    "$( autonomy_stop_requested && printf 'PRESENT — no cycle will start' || printf 'absent' )"
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
  printf '  policy        %s\n' "${AUTONOMY_REASON:-unconfigured}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _autonomy_cli "$@"
  exit $?
fi
