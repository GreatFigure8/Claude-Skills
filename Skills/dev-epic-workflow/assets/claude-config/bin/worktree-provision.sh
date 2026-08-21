#!/usr/bin/env bash
# Worktree provisioning and gate declaration — dev-epic-workflow, epic 11 item 2b.
#
# WHY THIS FILE EXISTS. It was measured on the first unattended-shaped dispatch
# against a real product repo on 2026-08-21, not anticipated. A fresh
# `git worktree add` produces a checkout that CANNOT RUN ITS OWN TEST SUITE:
#
#   * the environment file the suite reads is gitignored, so it is not in the
#     worktree — the run died with `RuntimeError: DB_PASSWORD is not set`
#   * `node_modules` is per-worktree and absent until something installs it
#
# The attended executor hit `7 failed, 1554 passed, 9 errors`, recognised the
# shape as provisioning rather than regression, copied the file, ran the
# install, and carried on. AN UNATTENDED EXECUTOR HAS NO SUCH NERVE. The
# failure looks exactly like a broken change, so the available outcomes are a
# false `blocked`, a false red pull request, or — worst — a run that decides the
# gates are unrunnable, reports them skipped, and opens the PR anyway.
#
# THE SECOND FINDING, SAME DISPATCH: THE GATE SET IS PER ITEM TYPE, NOT PER REPO.
# That repo's `scripts/test-both.sh` is `ruff` plus `pytest` twice and covers
# ZERO TypeScript (verified by reading it). It runs none of the tests covering a
# `.tsx` work item; every test that could have caught a regression there lives
# in a different command entirely. The dispatch brief that said "the gate is
# test-both.sh" was the orchestrator's, and it was WRONG. The executor ran the
# right gates from repo precedent rather than from instruction — which is
# judgement, and judgement is the one thing an unattended runner does not have.
# So the gate set is DECLARED, per item type, and handed to the executor in its
# brief rather than left to be inferred.
#
# WHAT THIS FILE IS
#   sourced   `. worktree-provision.sh` — the dispatcher calls the functions
#             below. Sourcing never exits the caller, reads no config until
#             asked, and mutates nothing outside its own variables.
#   executed  `worktree-provision.sh --check ...`   read-only, always
#             `worktree-provision.sh --gates ...`   read-only, always
#             `worktree-provision.sh --brief ...`   read-only, always
#             `worktree-provision.sh --preflight ...` ACTS: copies the declared
#             files into the named worktree, runs the declared install, and runs
#             the declared smoke command. It is the only mode that writes.
#
# NOTHING IN THIS BUILD CALLS THE PROVISIONER AS PART OF A CYCLE.
# `PROVISION_DISPATCH_WIRED=no` below is that claim in a form a fixture asserts.
# Epic 11 item 3 is the dispatcher, and it is what calls `provision_preflight`.
#
# ---------------------------------------------------------------------------
# INERTNESS IS THE FIRST REQUIREMENT, NOT THE LAST
#
# A repo that declares nothing gets today's behaviour: A BARE WORKTREE, no copy,
# no install, no smoke, and not one extra line of log. That is a definition-of-
# done clause of item 2b, and `provision_resolve` takes a deliberately silent
# path for it — the same silent path `autonomy_resolve` takes for a repo with no
# section, and for the same reason.
#
# ---------------------------------------------------------------------------
# WHY A THIRD SIBLING FILE AND NOT MORE KEYS IN `autonomy`
#
# The format is the one epic 11 item 1 established and `references/autonomy-
# control-surface.md` documents: an INI file of `[section]` headers that are
# either a checkout PATH (starts with `/` or `~`) or an `owner/name` SLUG, with
# `key = value` lines under them. That format is followed here rather than a
# second one being invented. The FILE is separate because:
#
#  1. `autonomy` is a PERMISSION surface. `env-files`, `install`, `smoke` and
#     `gates.*` grant nothing — they are CAPABILITY: how to make a checkout able
#     to run, and what running means. Editing a permission file for a
#     non-permission reason is exactly what the `repos`-versus-`autonomy` split
#     already refused, and the argument does not weaken for a third concern.
#  2. Blast radius. Any error anywhere in `autonomy` pins EVERY repo to L0. A
#     typo in an install command should not silently revoke a rung, and a
#     revoked rung should not be the way you find out about a typo.
#  3. Version skew. Item 1's parser refuses any key it does not know. Adding
#     provisioning keys to `autonomy` would make an older copy of `autonomy.sh`
#     refuse the whole file. A file that the other reader never opens cannot do
#     that to it.
#
# THIS FILE CONTAINS EXECUTABLE CONFIGURATION, AND SAYS SO PLAINLY.
# `install`, `smoke` and every `gates.*` value are shell commands that this
# library runs. There is no way to provision a checkout without running
# something, so the honest response is not to pretend otherwise but to guard the
# source: the config file must be a regular file, owned by the user running this,
# and not writable by group or other. Anything else is refused and NOTHING is
# run. That is the same standard the credential file is already held to, for the
# same reason. Commands run with the worktree as the working directory and are
# not sandboxed beyond that; a machine that can write your provisioning file can
# already run code as you.
#
# ---------------------------------------------------------------------------
# A DRAFTING WORKTREE IS NEVER PROVISIONED
#
# Unattended intake (L0) drafts a plan and runs no gate, so it needs no install
# and no environment file. Copying credential material into a worktree where a
# headless drafter holds Write is a widened blast radius bought for no benefit.
# Provisioning belongs to DISPATCH worktrees only, and the runner's drafting path
# does not call it.

# =========================================================================
# CONTRACT MARKERS — asserted by the fixtures
# =========================================================================
# Whether any code path in this build invokes the provisioner as part of a
# cycle. `no` for the whole of item 2b: this is the mechanism, item 3 is the
# dispatcher that calls it.
PROVISION_DISPATCH_WIRED=no

# ------------------------------------------------------------------- paths
PROVISION_CONFIG_FILE="${INTAKE_PROVISION_FILE:-$HOME/.config/claude-intake/provisioning}"

# launchd gives a minimal PATH, so git is resolved explicitly and shares the
# runner's own override rather than inventing a second one.
PROVISION_GIT="${INTAKE_GIT:-git}"

# ------------------------------------------------------------------- state
PROVISION_LOADED=no
PROVISION_CONFIG_PRESENT=no
PROVISION_CONFIG_OK=yes
PROVISION_CONFIG_ERRORS=""
PROVISION_PARSED=""

PROVISION_RESOLVED=no
PROVISION_DECLARED=no
PROVISION_SECTION=""
PROVISION_ENV_FILES=""
PROVISION_INSTALL=""
PROVISION_SMOKE=""
PROVISION_GATE_TYPES=""
PROVISION_REASON=""
PROVISION_LOG=""
PROVISION_REFUSAL=""
PROVISION_REPORT=""
PROVISION_RUN_LOG=""

# --------------------------------------------------------------- utilities
# Deliberately duplicated from autonomy.sh rather than shared through it: the
# permission surface must not acquire a runtime dependency on the capability
# surface, in either direction. Three small stable functions is the whole cost.

_provision_strip() { # $1 -> stdout, trimmed
  local S="${1-}"
  S="${S#"${S%%[![:space:]]*}"}"
  S="${S%"${S##*[![:space:]]}"}"
  printf '%s' "$S"
}

# `~/x` -> `$HOME/x`, trailing slashes removed, resolved through symlinks when
# the directory exists (macOS hands out /var and /private/var for one place, and
# a fixture sandbox lives in exactly that overlap).
provision_normalise_path() { # $1 = path -> stdout
  local P
  P="$(_provision_strip "${1-}")"
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

# Last lines of a command's output, for a refusal that has to be actionable
# without anyone opening the log by hand.
_provision_tail() { # $1 = file, $2 = lines
  [ -f "${1-}" ] || return 0
  tail -n "${2:-20}" "$1" 2>/dev/null | sed 's/^/    | /'
}

# ------------------------------------------------------------------ parsing
_provision_err() {
  PROVISION_CONFIG_OK=no
  PROVISION_CONFIG_ERRORS="$PROVISION_CONFIG_ERRORS$PROVISION_CONFIG_FILE:$1: $2
"
}

_provision_get() { # $1 section  $2 key -> stdout value (empty when unset)
  # Pure shell rather than `awk -v`: awk processes escape sequences in a -v
  # value, so a section name containing a backslash would be silently rewritten
  # before the comparison.
  local S K V
  while IFS='	' read -r S K V; do
    [ "$S" = "$1" ] || continue
    [ "$K" = "$2" ] || continue
    printf '%s' "$V"
    return 0
  done <<GET_EOF
$PROVISION_PARSED
GET_EOF
  return 0
}

_provision_sections() {
  printf '%s\n' "$PROVISION_PARSED" | awk -F'\t' 'NF>=2 {print $1}' | sort -u | grep .
}

_provision_section_exists() { # $1 = section name
  local S
  while IFS= read -r S; do
    [ "$S" = "$1" ] && return 0
  done <<EXISTS_EOF
$(_provision_sections)
EXISTS_EOF
  return 1
}

# Whether a section set any real key, as opposed to merely existing. The
# difference matters twice: an empty section declares no provisioning (bare
# worktree, today's behaviour) yet still conflicts with a second section naming
# the same repo.
_provision_section_has_keys() { # $1 = section
  local S K V
  while IFS='	' read -r S K V; do
    [ "$S" = "$1" ] || continue
    [ -n "$K" ] && return 0
  done <<HASKEYS_EOF
$PROVISION_PARSED
HASKEYS_EOF
  return 1
}

# Keys the section under a repo may set. `gates.<type>` is a family, not a
# fixed name, because the item types a repo has are the repo's business —
# but the TYPE part is constrained so `gates.` alone, or a type with a space in
# it, is an error rather than a key nobody can ever name in a brief.
_provision_key_ok() { # $1 = key
  case "${1-}" in
    env-files|install|smoke) return 0 ;;
    gates.*)
      case "${1#gates.}" in
        '') return 1 ;;
        *[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
      esac ;;
    *) return 1 ;;
  esac
}

# A declared environment file is a repo-relative path and nothing else.
# Absolute paths, `~`, and `..` are refused because "provisioning" that reaches
# outside the source checkout is not provisioning; globs are refused because a
# glob that matches nothing copies nothing and says nothing, which is the
# silent-degrade failure this whole item exists to remove.
_provision_env_path_ok() { # $1 = declared path
  case "${1-}" in
    '') return 1 ;;
    /*|'~'*) return 1 ;;
    '..'|'../'*|*'/../'*|*'/..') return 1 ;;
    *'*'*|*'?'*|*'['*) return 1 ;;
    *) return 0 ;;
  esac
}

# THE SOURCE GUARD. This file's values are executed, so its provenance is
# checked before a single line of it is parsed. Loose permissions are a refusal,
# never a warning.
_provision_file_trustworthy() { # $1 = path; sets PROVISION_REFUSAL on rc 1
  local F="$1" MODE OWNER ME
  PROVISION_REFUSAL=""
  if [ ! -f "$F" ]; then
    PROVISION_REFUSAL="not a regular file"
    return 1
  fi
  # BSD stat first (this runs under launchd on macOS), GNU stat second.
  MODE="$(stat -f '%Lp' "$F" 2>/dev/null)" || MODE=""
  OWNER="$(stat -f '%u' "$F" 2>/dev/null)" || OWNER=""
  if [ -z "$MODE" ]; then
    MODE="$(stat -c '%a' "$F" 2>/dev/null)" || MODE=""
    OWNER="$(stat -c '%u' "$F" 2>/dev/null)" || OWNER=""
  fi
  if [ -z "$MODE" ] || [ -z "$OWNER" ]; then
    PROVISION_REFUSAL="its mode could not be read, and an unverifiable file whose contents are executed is refused"
    return 1
  fi
  ME="$(id -u 2>/dev/null)" || ME=""
  if [ -n "$ME" ] && [ "$OWNER" != "$ME" ]; then
    PROVISION_REFUSAL="it is owned by uid $OWNER, not by uid $ME who is running this"
    return 1
  fi
  # Group- or other-writable. `%Lp` prints e.g. 644; take the last two digits.
  case "$MODE" in
    *[2367])            PROVISION_REFUSAL="it is world-writable (mode $MODE); chmod 600 '$F'"; return 1 ;;
  esac
  case "$MODE" in
    *[2367]?)           PROVISION_REFUSAL="it is group-writable (mode $MODE); chmod 600 '$F'"; return 1 ;;
  esac
  return 0
}

# Parse into PROVISION_PARSED as `section<TAB>key<TAB>value` lines, in file
# order. No associative arrays (macOS /bin/bash is 3.2) and no eval, ever.
provision_load() {
  if [ "$PROVISION_LOADED" = yes ]; then
    [ "$PROVISION_CONFIG_OK" = yes ]
    return $?
  fi
  PROVISION_LOADED=yes
  PROVISION_CONFIG_OK=yes
  PROVISION_CONFIG_ERRORS=""
  PROVISION_PARSED=""

  if [ ! -e "$PROVISION_CONFIG_FILE" ]; then
    PROVISION_CONFIG_PRESENT=no
    return 0
  fi
  PROVISION_CONFIG_PRESENT=yes
  if ! _provision_file_trustworthy "$PROVISION_CONFIG_FILE"; then
    _provision_err 0 "refused before parsing: $PROVISION_REFUSAL"
    return 1
  fi
  if [ ! -r "$PROVISION_CONFIG_FILE" ]; then
    _provision_err 0 "not readable"
    return 1
  fi

  local RAW LINE N SECTION KEY VALUE SEEN P
  N=0; SECTION=""; SEEN=""
  while IFS= read -r RAW || [ -n "$RAW" ]; do
    N=$((N + 1))
    LINE="$(_provision_strip "$RAW")"
    case "$LINE" in ''|'#'*|';'*) continue ;; esac
    case "$LINE" in
      '['*']')
        SECTION="$(_provision_strip "${LINE#[}")"
        SECTION="$(_provision_strip "${SECTION%]}")"
        if [ -z "$SECTION" ]; then _provision_err "$N" "empty section header"; continue; fi
        case "$SECTION" in *"$(printf '\t')"*) _provision_err "$N" "section header contains a tab"; SECTION=""; continue ;; esac
        case "$SECTION" in
          global)
            _provision_err "$N" "[global] has no meaning here — every key in this file is per repo, so name the repo by path or by owner/name slug"
            SECTION=""; continue ;;
          /*|'~'*) SECTION="$(provision_normalise_path "$SECTION")" ;;
          */*/*)   _provision_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
          */*)     : ;;
          *)       _provision_err "$N" "section [$SECTION] is neither a path (starts with / or ~) nor an owner/name slug" ;;
        esac
        case "
$SEEN" in *"
$SECTION"*) _provision_err "$N" "duplicate section [$SECTION]" ;; esac
        SEEN="$SEEN
$SECTION"
        # A bare marker row, so a section that sets no keys is still DECLARED to
        # EXIST. `[repo]` with nothing under it declares no provisioning — it is
        # a bare worktree, exactly as today — but it is still that repo's one
        # section, and a second section naming the same repo is still a conflict.
        PROVISION_PARSED="$PROVISION_PARSED$SECTION		
"
        continue ;;
    esac
    case "$LINE" in
      *=*) ;;
      *) _provision_err "$N" "not a comment, a [section] header, or a key = value line: $LINE"; continue ;;
    esac
    if [ -z "$SECTION" ]; then
      _provision_err "$N" "key outside any [section]: $LINE"
      continue
    fi
    KEY="$(_provision_strip "${LINE%%=*}")"
    VALUE="$(_provision_strip "${LINE#*=}")"
    case "$VALUE" in *"$(printf '\t')"*) _provision_err "$N" "value for '$KEY' contains a tab"; continue ;; esac
    if [ -z "$VALUE" ]; then
      _provision_err "$N" "'$KEY' has an empty value; delete the line or give it one"
      continue
    fi
    if ! _provision_key_ok "$KEY"; then
      case "$KEY" in
        gates.*) _provision_err "$N" "'$KEY' is not a usable gate name — a gate is 'gates.<type>' where <type> is letters, digits, dot, dash or underscore" ;;
        *)       _provision_err "$N" "unknown key '$KEY' in [$SECTION]; this file knows env-files, install, smoke and gates.<type>" ;;
      esac
      continue
    fi
    if [ -n "$(_provision_get "$SECTION" "$KEY")" ]; then
      _provision_err "$N" "duplicate key '$KEY' in [$SECTION]"
      continue
    fi
    if [ "$KEY" = env-files ]; then
      local EF
      EF="$(printf '%s' "$VALUE" | tr ',' '\n')"
      while IFS= read -r P; do
        P="$(_provision_strip "$P")"
        [ -n "$P" ] || continue
        _provision_env_path_ok "$P" \
          || _provision_err "$N" "env-files entry '$P' must be a repo-relative path with no '..' and no glob — provisioning copies named files, it does not search for them"
      done <<ENV_EOF
$EF
ENV_EOF
    fi
    PROVISION_PARSED="$PROVISION_PARSED$SECTION	$KEY	$VALUE
"
  done < "$PROVISION_CONFIG_FILE"

  _provision_validate_sections
  [ "$PROVISION_CONFIG_OK" = yes ]
}

# A section that declares ANYTHING is claiming "a worktree of this repo can run
# its gates". `smoke` is the only part of that claim which is ever CHECKED, so
# it is required — the same rule, for the same reason, as item 1 requiring a
# size ceiling from any repo above L0. A gate that has never been shown to run
# is a hope, and this item exists because a hope failed.
_provision_validate_sections() {
  local S LIST HAS_SMOKE
  LIST="$(_provision_sections)"
  while IFS= read -r S; do
    [ -n "$S" ] || continue
    _provision_section_has_keys "$S" || continue
    HAS_SMOKE="$(_provision_get "$S" smoke)"
    [ -n "$HAS_SMOKE" ] && continue
    _provision_err "[$S]" "declares provisioning but no 'smoke' command — a section that claims a worktree can run its gates must state how that claim is CHECKED before an executor is dispatched into it"
  done <<SECTIONS_EOF
$LIST
SECTIONS_EOF
}

# --------------------------------------------------------------- resolution
# Sets PROVISION_DECLARED and the per-repo declaration, and PROVISION_LOG —
# which is EMPTY when there is nothing to say. That emptiness is the inertness
# guarantee at the level a human notices.
#
# Precedence:
#   1. no config file            -> nothing declared, SILENT   (this is today)
#   2. config refused or invalid -> rc 1, nothing provisioned, loud
#   3. path and slug both match  -> rc 1, one repo one section, loud
#   4. no section for this repo  -> nothing declared, SILENT   (this is today)
#   5. otherwise                 -> the declaration
provision_resolve() { # $1 = repo checkout path, $2 = repo slug
  local RPATH RSLUG SEC_PATH SEC_SLUG SEC K
  PROVISION_RESOLVED=yes
  PROVISION_DECLARED=no
  PROVISION_SECTION=""
  PROVISION_ENV_FILES=""
  PROVISION_INSTALL=""
  PROVISION_SMOKE=""
  PROVISION_GATE_TYPES=""
  PROVISION_REASON=""
  PROVISION_LOG=""
  PROVISION_REFUSAL=""

  provision_load >/dev/null 2>&1 || true
  RPATH="$(provision_normalise_path "${1-}")"
  RSLUG="$(_provision_strip "${2-}")"

  if [ "$PROVISION_CONFIG_PRESENT" = no ]; then
    PROVISION_REASON="no provisioning file"
    return 0
  fi
  if [ "$PROVISION_CONFIG_OK" != yes ]; then
    PROVISION_REASON="provisioning config is invalid; no worktree is provisioned and no dispatch may proceed"
    PROVISION_REFUSAL="$PROVISION_REASON"
    PROVISION_LOG="provisioning: REFUSED — $PROVISION_REASON"
    return 1
  fi

  SEC_PATH=""; SEC_SLUG=""
  if [ -n "$PROVISION_PARSED" ]; then
    if [ -n "$RPATH" ] && _provision_section_exists "$RPATH"; then SEC_PATH="$RPATH"; fi
    if [ -n "$RSLUG" ] && _provision_section_exists "$RSLUG"; then SEC_SLUG="$RSLUG"; fi
  fi
  if [ -n "$SEC_PATH" ] && [ -n "$SEC_SLUG" ]; then
    PROVISION_REASON="refused: [$SEC_PATH] and [$SEC_SLUG] both declare this repo — one repo, one section"
    PROVISION_REFUSAL="$PROVISION_REASON"
    PROVISION_LOG="provisioning: REFUSED — $PROVISION_REASON"
    return 1
  fi
  SEC="$SEC_PATH"; [ -n "$SEC" ] || SEC="$SEC_SLUG"
  if [ -n "$SEC" ] && ! _provision_section_has_keys "$SEC"; then
    # The section exists and sets nothing. That is a statement about this repo —
    # it is why the conflict check above still saw it — but what it states is
    # "no provisioning", so the answer is a bare worktree and silence.
    PROVISION_REASON="[$SEC] declares nothing"
    return 0
  fi
  if [ -z "$SEC" ]; then
    # THE SILENT PATH. No section, nothing declared, nothing logged, and a bare
    # worktree — byte for byte what this machine did before item 2b existed.
    PROVISION_REASON="unconfigured"
    return 0
  fi

  PROVISION_DECLARED=yes
  PROVISION_SECTION="$SEC"
  PROVISION_ENV_FILES="$(_provision_get "$SEC" env-files)"
  PROVISION_INSTALL="$(_provision_get "$SEC" install)"
  PROVISION_SMOKE="$(_provision_get "$SEC" smoke)"
  # Gate types in DECLARATION order, which is the order they will be run and the
  # order they appear in a brief. `sort -u` would put `api` before `web` on
  # every repo whose author meant something by the order they wrote them in.
  PROVISION_GATE_TYPES="$(printf '%s\n' "$PROVISION_PARSED" \
    | awk -F'\t' -v s="$SEC" '$1 == s && $2 ~ /^gates\./ { sub(/^gates\./, "", $2); print $2 }')"
  PROVISION_REASON="declared by [$SEC]"
  PROVISION_LOG="provisioning: $SEC declares env-files=[${PROVISION_ENV_FILES:-none}] install=[${PROVISION_INSTALL:-none}] gates=[$(printf '%s' "$PROVISION_GATE_TYPES" | tr '\n' ' ' | sed -e 's/ $//' -e 's/^$/none/')]"
  return 0
}

# --------------------------------------------------- the gate declaration
# THE ANSWER TO FINDING 2. A brief names an item type; this returns the gate
# commands for it, one per line.
#
#   named and declared    -> its commands
#   named, NOT declared   -> REFUSED, naming what is declared. Never a fallback
#                            to "the repo's usual gate": running the wrong gate
#                            is the defect, and a fallback is how you get one.
#   not named             -> EVERY declared gate, in declaration order. Over-
#                            running gates is safe; under-running them is the
#                            thing that was measured.
provision_gates() { # $1 = item type (may be empty) -> commands on stdout
  local T CMD FOUND=0
  PROVISION_REFUSAL=""
  T="$(_provision_strip "${1-}")"
  if [ "$PROVISION_RESOLVED" != yes ]; then
    PROVISION_REFUSAL="provision_resolve has not been called; a gate set is per repo and there is no repo yet"
    return 1
  fi
  if [ "$PROVISION_DECLARED" != yes ]; then
    PROVISION_REFUSAL="this repo declares no gates; the executor's own stack-gates discipline is what applies"
    return 1
  fi
  if [ -z "$PROVISION_GATE_TYPES" ]; then
    PROVISION_REFUSAL="[$PROVISION_SECTION] declares provisioning but no gates.<type>"
    return 1
  fi
  if [ -n "$T" ]; then
    CMD="$(_provision_get "$PROVISION_SECTION" "gates.$T")"
    if [ -z "$CMD" ]; then
      PROVISION_REFUSAL="no gate set named '$T' is declared for [$PROVISION_SECTION]; declared: $(printf '%s' "$PROVISION_GATE_TYPES" | tr '\n' ' ' | sed 's/ $//')"
      return 1
    fi
    printf '%s\n' "$CMD"
    return 0
  fi
  while IFS= read -r T; do
    [ -n "$T" ] || continue
    CMD="$(_provision_get "$PROVISION_SECTION" "gates.$T")"
    [ -n "$CMD" ] || continue
    printf '%s\n' "$CMD"
    FOUND=1
  done <<TYPES_EOF
$PROVISION_GATE_TYPES
TYPES_EOF
  [ "$FOUND" -eq 1 ]
}

# The block a dispatch brief carries verbatim. Prose, because its reader is an
# executor agent and the measured failure was an executor being TOLD the wrong
# gate — so this says where the list came from and forbids substitution.
provision_gate_brief() { # $1 = item type (may be empty)
  local T CMDS I=0 LINE
  T="$(_provision_strip "${1-}")"
  CMDS="$(provision_gates "$T")" || return 1
  if [ -n "$T" ]; then
    printf 'Gates for this item — declared for %s, item type `%s`:\n' "$PROVISION_SECTION" "$T"
  else
    printf 'Gates for this item — declared for %s (every declared set, because the dispatch named no item type):\n' "$PROVISION_SECTION"
  fi
  while IFS= read -r LINE; do
    [ -n "$LINE" ] || continue
    I=$((I + 1))
    printf '  %s. %s\n' "$I" "$LINE"
  done <<CMDS_EOF
$CMDS
CMDS_EOF
  printf 'Run every one of them from the worktree root and report each result verbatim.\n'
  printf 'Do NOT substitute a gate you believe is equivalent, and do NOT skip one that\n'
  printf 'looks unrelated to your diff: this list is declared per item type precisely\n'
  printf 'because a repo-wide gate script was measured covering none of an item.\n'
  return 0
}

# ------------------------------------------------------- doing the work
_provision_run_log_path() { # $1 = worktree -> stdout
  local G
  # Inside the worktree's own admin directory: `git status` never shows it, it
  # dies with the worktree, and it is not in anybody's diff. A log written into
  # the working tree would be caught by this library's own clean-tree check.
  G="$("$PROVISION_GIT" -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" || G=""
  if [ -n "$G" ] && [ -d "$G" ]; then
    printf '%s/provision.log' "$G"
  else
    printf '%s/.provision-%s.log' "${TMPDIR:-/tmp}" "$$"
  fi
}

_provision_run() { # $1 = worktree, $2 = label, $3 = command -> rc of the command
  local WT="$1" LABEL="$2" CMD="$3" RC
  {
    printf '=== %s: %s\n' "$LABEL" "$CMD"
    printf '=== cwd: %s\n' "$WT"
  } >> "$PROVISION_RUN_LOG" 2>/dev/null || true
  ( cd "$WT" && /usr/bin/env bash -c "$CMD" ) >> "$PROVISION_RUN_LOG" 2>&1
  RC=$?
  printf '=== %s exited %s\n' "$LABEL" "$RC" >> "$PROVISION_RUN_LOG" 2>/dev/null || true
  return "$RC"
}

# THE CLEAN-TREE CHECK, AND WHY IT REFUSES RATHER THAN WARNS.
# After provisioning, `git status --porcelain` must be empty. Two different
# disasters share this one check:
#   * a copied environment file that is NOT gitignored is now an untracked (or
#     modified) file in a worktree an unattended executor is about to run `git
#     add` in. That is a credential in a pull request.
#   * an install that rewrites a lockfile has put changes into the executor's
#     diff that the executor did not make and cannot explain.
# Both are silent at the moment they happen and expensive later, so this is a
# refusal that names the paths.
_provision_tree_clean() { # $1 = worktree, $2 = stage label
  local WT="$1" STAGE="$2" DIRTY P LEAK=""
  DIRTY="$("$PROVISION_GIT" -C "$WT" status --porcelain 2>/dev/null)" || {
    PROVISION_REFUSAL="could not read 'git status' in $WT after $STAGE"
    return 1
  }
  [ -n "$DIRTY" ] || return 0
  # Newline-FENCED on both sides, so `.env` never matches `.env.local`.
  local DECLARED
  DECLARED="
$(printf '%s' "$PROVISION_ENV_FILES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
"
  while IFS= read -r P; do
    [ -n "$P" ] || continue
    P="$(_provision_strip "${P#???}")"
    case "$DECLARED" in
      *"
$P
"*) LEAK="$LEAK $P" ;;
    esac
  done <<DIRTY_EOF
$DIRTY
DIRTY_EOF
  if [ -n "$LEAK" ]; then
    PROVISION_REFUSAL="a copied environment file is VISIBLE TO GIT in $WT after $STAGE:$LEAK — it is not gitignored there, so an executor running 'git add' would commit credential material into a pull request. Refusing to dispatch."
  else
    PROVISION_REFUSAL="provisioning left the worktree dirty after $STAGE, so the executor's diff would contain changes it did not make:
$(printf '%s' "$DIRTY" | sed 's/^/    /')"
  fi
  return 1
}

# Copy the declared environment files and run the declared install.
# A repo that declares nothing does nothing here and says nothing — rc 0.
provision_worktree() { # $1 = repo checkout path, $2 = worktree path
  local SRC_ROOT="$1" WT="$2" REL SRC DEST COPIED=0 RC
  PROVISION_REFUSAL=""
  PROVISION_REPORT=""
  if [ "$PROVISION_RESOLVED" != yes ]; then
    PROVISION_REFUSAL="provision_resolve has not been called"
    return 1
  fi
  if [ "$PROVISION_DECLARED" != yes ]; then
    # Today's behaviour, exactly: a bare worktree.
    return 0
  fi
  if [ ! -d "$WT" ]; then
    PROVISION_REFUSAL="worktree does not exist: $WT"
    return 1
  fi
  if [ ! -d "$SRC_ROOT" ]; then
    PROVISION_REFUSAL="source checkout does not exist: $SRC_ROOT"
    return 1
  fi
  if ! "$PROVISION_GIT" -C "$WT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROVISION_REFUSAL="not a git worktree: $WT"
    return 1
  fi
  PROVISION_RUN_LOG="$(_provision_run_log_path "$WT")"
  : > "$PROVISION_RUN_LOG" 2>/dev/null || true

  while IFS= read -r REL; do
    REL="$(_provision_strip "$REL")"
    [ -n "$REL" ] || continue
    # Re-checked at USE time and not only at parse time: the config could have
    # been reloaded, and a traversal that is only refused during validation is
    # refused in the wrong place.
    if ! _provision_env_path_ok "$REL"; then
      PROVISION_REFUSAL="env-files entry '$REL' is not a safe repo-relative path"
      return 1
    fi
    SRC="$SRC_ROOT/$REL"
    DEST="$WT/$REL"
    if [ ! -f "$SRC" ]; then
      PROVISION_REFUSAL="declared environment file is missing from the source checkout: $SRC — a worktree cut from this repo cannot run its gates without it, so this is a refusal and not a warning"
      return 1
    fi
    mkdir -p "$(dirname "$DEST")" 2>/dev/null || {
      PROVISION_REFUSAL="could not create $(dirname "$DEST")"
      return 1
    }
    if ! cp -p "$SRC" "$DEST" 2>/dev/null; then
      PROVISION_REFUSAL="could not copy $SRC to $DEST"
      return 1
    fi
    COPIED=$((COPIED + 1))
    PROVISION_REPORT="${PROVISION_REPORT}provisioning: copied $REL into the worktree
"
  done <<FILES_EOF
$(printf '%s' "$PROVISION_ENV_FILES" | tr ',' '\n')
FILES_EOF

  if [ -n "$PROVISION_INSTALL" ]; then
    _provision_run "$WT" install "$PROVISION_INSTALL"
    RC=$?
    if [ "$RC" -ne 0 ]; then
      PROVISION_REFUSAL="the declared install failed (exit $RC): $PROVISION_INSTALL
  full output: $PROVISION_RUN_LOG
$(_provision_tail "$PROVISION_RUN_LOG" 20)"
      return 1
    fi
    PROVISION_REPORT="${PROVISION_REPORT}provisioning: ran install — $PROVISION_INSTALL
"
  fi

  _provision_tree_clean "$WT" "provisioning" || return 1
  PROVISION_REPORT="${PROVISION_REPORT}provisioning: $COPIED file(s) copied, worktree clean
"
  return 0
}

# THE SMOKE CHECK — the difference between "we provisioned" and "the gate can
# run". The measured failure had the file copied and STILL could not run, so
# checking that the copy happened is not the check that matters.
provision_smoke_check() { # $1 = worktree path
  local WT="$1" RC
  PROVISION_REFUSAL=""
  if [ "$PROVISION_RESOLVED" != yes ]; then
    PROVISION_REFUSAL="provision_resolve has not been called"
    return 1
  fi
  [ "$PROVISION_DECLARED" = yes ] || return 0
  if [ -z "$PROVISION_SMOKE" ]; then
    # Unreachable through provision_load, which refuses a section without one.
    # Kept because "no smoke declared" must never resolve to "smoke passed".
    PROVISION_REFUSAL="[$PROVISION_SECTION] declares no smoke command, so nothing verified that this worktree can run its gates"
    return 1
  fi
  [ -n "$PROVISION_RUN_LOG" ] || PROVISION_RUN_LOG="$(_provision_run_log_path "$WT")"
  _provision_run "$WT" smoke "$PROVISION_SMOKE"
  RC=$?
  if [ "$RC" -ne 0 ]; then
    PROVISION_REFUSAL="THE SMOKE CHECK FAILED (exit $RC): $PROVISION_SMOKE
  This worktree cannot run its gates. Dispatching into it would produce a gate
  failure indistinguishable from a broken change — a false blocked, a false red
  PR, or a PR opened with the gates reported as skipped.
  full output: $PROVISION_RUN_LOG
$(_provision_tail "$PROVISION_RUN_LOG" 20)"
    return 1
  fi
  _provision_tree_clean "$WT" "the smoke check" || return 1
  PROVISION_REPORT="${PROVISION_REPORT}provisioning: smoke check passed — $PROVISION_SMOKE
"
  return 0
}

# THE ONE CALL A DISPATCHER MAKES. rc 0 = this worktree may be dispatched into.
# rc 1 = it may not, and PROVISION_REFUSAL says why in a sentence a human can
# act on without opening a log.
provision_preflight() { # $1 = repo path, $2 = repo slug, $3 = worktree path
  PROVISION_REPORT=""
  provision_resolve "$1" "$2" || return 1
  [ "$PROVISION_DECLARED" = yes ] || return 0
  provision_worktree "$1" "$3" || return 1
  provision_smoke_check "$3" || return 1
  return 0
}

# ---------------------------------------------------------------------- CLI
_provision_cli_usage() { sed -n '1,10p' "$0"; }

# rc 1 when this repo is REFUSED, so the exit code agrees with the text. A mode
# that prints "no dispatch may proceed" and exits 0 is a mode whose exit code is
# a lie, and the exit code is the half a script reads.
_provision_cli_one() { # $1 path, $2 slug
  local P="$1" S="$2" T RC=0
  provision_resolve "$P" "$S" || RC=1
  printf 'repo            %s\n' "${S:-${P:-<none>}}"
  printf '  path          %s\n' "$(provision_normalise_path "$P")"
  if [ "$PROVISION_DECLARED" = yes ]; then
    printf '  declared by   [%s]\n' "$PROVISION_SECTION"
    printf '  env-files     %s\n' "${PROVISION_ENV_FILES:-none}"
    printf '  install       %s\n' "${PROVISION_INSTALL:-none}"
    printf '  smoke         %s\n' "${PROVISION_SMOKE:-none}"
    while IFS= read -r T; do
      [ -n "$T" ] || continue
      printf '  gates.%-8s %s\n' "$T" "$(_provision_get "$PROVISION_SECTION" "gates.$T")"
    done <<CLI_TYPES_EOF
$PROVISION_GATE_TYPES
CLI_TYPES_EOF
  elif [ -n "$PROVISION_REFUSAL" ]; then
    printf '  provisioning  REFUSED — %s\n' "$PROVISION_REFUSAL"
    printf '                no dispatch may proceed into a worktree of this repo\n'
  else
    printf '  provisioning  %s (a bare worktree, exactly as before this existed)\n' "${PROVISION_REASON:-unconfigured}"
  fi
  return "$RC"
}

_provision_cli() {
  local MODE=check REPO_PATH="" REPO_SLUG="" TYPE="" WT="" RC=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --check)     MODE=check ;;
      --gates)     MODE=gates; TYPE="${2-}"; shift ;;
      --brief)     MODE=brief; TYPE="${2-}"; shift ;;
      --preflight) MODE=preflight; WT="${2-}"; shift ;;
      --repo)      REPO_PATH="${2-}"; shift ;;
      --slug)      REPO_SLUG="${2-}"; shift ;;
      -h|--help)   _provision_cli_usage; return 0 ;;
      *) printf 'unknown argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  case "$MODE" in
    gates|brief)
      provision_resolve "$REPO_PATH" "$REPO_SLUG" || { printf '%s\n' "$PROVISION_REFUSAL" >&2; return 1; }
      if [ "$MODE" = gates ]; then
        provision_gates "$TYPE" || { printf '%s\n' "$PROVISION_REFUSAL" >&2; return 1; }
      else
        provision_gate_brief "$TYPE" || { printf '%s\n' "$PROVISION_REFUSAL" >&2; return 1; }
      fi
      return 0 ;;
    preflight)
      if [ -z "$WT" ]; then printf 'preflight needs a worktree path\n' >&2; return 1; fi
      if provision_preflight "$REPO_PATH" "$REPO_SLUG" "$WT"; then
        printf '%s' "$PROVISION_REPORT"
        if [ "$PROVISION_DECLARED" = yes ]; then
          printf 'provisioning: %s may be dispatched into\n' "$WT"
        else
          printf 'provisioning: nothing declared for this repo — bare worktree, unchanged\n'
        fi
        return 0
      fi
      printf '%s' "$PROVISION_REPORT"
      printf 'provisioning: REFUSING TO DISPATCH into %s\n' "$WT" >&2
      printf '  %s\n' "$PROVISION_REFUSAL" >&2
      return 1 ;;
  esac

  provision_load >/dev/null 2>&1 || RC=1
  printf 'config          %s%s\n' "$PROVISION_CONFIG_FILE" \
    "$( [ "$PROVISION_CONFIG_PRESENT" = yes ] && printf '' || printf '   (absent — every worktree is bare and today is unchanged)' )"
  if [ "$PROVISION_CONFIG_OK" != yes ]; then
    printf 'config          INVALID — nothing is provisioned and no dispatch may proceed\n'
    printf '%s' "$PROVISION_CONFIG_ERRORS" | sed 's/^/  error  /'
  fi
  printf 'dispatch wired  %s   (item 2b ships the mechanism; item 3 is what calls it)\n' "$PROVISION_DISPATCH_WIRED"
  if [ -n "$REPO_PATH" ] || [ -n "$REPO_SLUG" ]; then
    _provision_cli_one "$REPO_PATH" "$REPO_SLUG" || RC=1
  fi
  return "$RC"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _provision_cli "$@"
  exit $?
fi
