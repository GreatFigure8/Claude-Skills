#!/usr/bin/env bash
# Fixture harness for WORKTREE PROVISIONING AND THE GATE DECLARATION
# (epic 11 item 2b), across both halves of the mechanism:
#   ../../bin/worktree-provision.sh  — parses and validates the provisioning
#                                      declaration, resolves it per repo,
#                                      copies the declared environment files,
#                                      runs the declared install, SMOKE-CHECKS
#                                      that the gates can actually run, and
#                                      answers the per-item-type gate set
#   ../../bin/unattended-intake.sh   — reports a refused provisioning config on
#                                      the timer, and provisions NOTHING
#
# WHAT THIS PROVES, AND WHAT IT DOES NOT.
# It proves the MECHANISM: that a bare worktree of a repo whose environment file
# is gitignored genuinely cannot run its own gate, that provisioning makes it
# able to, that the smoke check refuses to dispatch when it did not work, that a
# gate set is answered per ITEM TYPE and an undeclared type is refused rather
# than falled back on, and — above all — that a repo declaring no provisioning
# behaves EXACTLY as it did before this item existed.
# It does NOT prove that any dispatch calls it, because in this item nothing
# does: `PROVISION_DISPATCH_WIRED=no` and case M asserts it. Epic 11 item 3 is
# the dispatcher, and its own fixtures are what will prove that.
#
# THE MEASURED FAILURE THIS REPRODUCES. On 2026-08-21 a fresh `git worktree add`
# on a real product repo could not run its test suite: the environment file the
# suite reads is gitignored so it was absent, and `node_modules` is per-worktree.
# The run died with `RuntimeError: DB_PASSWORD is not set` — a message
# indistinguishable, to an unattended reader, from a broken change. Case K
# rebuilds that exact shape against a SYNTHETIC repo in the sandbox and requires
# the bare worktree to fail with that message before provisioning fixes it. The
# real repo is never touched by this suite, is not named in it, and does not
# need to exist for it to run.
#
# THE NEGATIVE CONTROL, BUILT BRITTLE ON PURPOSE (epic 09 items 4, 6, 7 and 8 all
# do this, and epic 11 item 1 after them). A suite that passes against the code
# as it stood BEFORE the item is a suite that tests nothing:
#   - it hard-errors at startup if the library is absent or does not carry the
#     `PROVISION_DISPATCH_WIRED=` contract marker, rather than skipping quietly
#   - case L reconstructs the PRE-ITEM-2b runner by deleting the item's own 40
#     added lines, REQUIRES the reconstruction to be exactly 40 lines shorter and
#     to still parse, proves the two are byte-identical on an unconfigured
#     machine, and then proves they DIFFER on a malformed config — so the
#     inertness case and the discriminating case are the same pair of runs
#   - cases N1-N4 are library mutants (an advisory smoke check, a gate-type
#     fallback, a disabled clean-tree check, a disabled source guard) that must
#     each break a case that passes on the shipped library
#
# SANDBOXING (GH #15 is open and unfixed: a harness in this repo has already
# escaped its sandbox and committed a real working tree). Every repo, worktree,
# config, log and stub lives under one `mktemp -d` removed on exit, and every
# destructive path goes through sandboxed(). The library cases use REAL git,
# because a worktree that git did not create would not test anything — so the
# host repo's HEAD and porcelain status are fingerprinted before and after and
# compared, and no git command in this file names any path outside the sandbox.
#
# IT NEVER READS OR WRITES ~/.config/claude-intake. `INTAKE_PROVISION_FILE` is
# set on every single invocation and `HOME` is redirected into the sandbox, so
# even the library's default path cannot resolve to the live one. A machine
# running a live unattended timer is untouched by this suite and this suite is
# unaffected by it.
#
# Usage:  bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/worktree-provision-fixtures.sh
#         INTAKE_FIXTURE_PROVISION_LIB=/path/to/other-worktree-provision.sh bash ...
#         INTAKE_FIXTURE_SCRIPT=/path/to/other-unattended-intake.sh bash ...
#           (both overrides exist so this suite can be pointed at a PRE-ITEM-2b
#            tree as a negative control; it must NOT pass there)
# Exit:   0 = every case matched its expectation, 1 = at least one mismatch.

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$TESTS_DIR/../../bin" && pwd)"
LIB="${INTAKE_FIXTURE_PROVISION_LIB:-$BIN_DIR/worktree-provision.sh}"
SCRIPT="${INTAKE_FIXTURE_SCRIPT:-$BIN_DIR/unattended-intake.sh}"

# ---------------------------------------- the negative control's tripwire
# Not a skip, not a warning: an abort. Pointed at a pre-item-2b tree this suite
# must stop with a message, because a suite that "passes" where the feature does
# not exist is worse than no suite.
[ -f "$SCRIPT" ] || { echo "ERROR: not found: $SCRIPT" >&2; exit 1; }
if [ ! -f "$LIB" ]; then
  echo "ERROR: no worktree provisioner at $LIB." >&2
  echo "       This suite tests epic 11 item 2b. Against a tree that predates it" >&2
  echo "       there is nothing to test, and passing would be a lie. Aborting." >&2
  exit 1
fi
if ! grep -q '^PROVISION_DISPATCH_WIRED=' "$LIB"; then
  echo "ERROR: $LIB carries no PROVISION_DISPATCH_WIRED= contract marker." >&2
  echo "       Either it is not the provisioner, or the marker was removed — and" >&2
  echo "       the marker IS the not-yet-wired claim. Aborting." >&2
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: real git is required" >&2; exit 1; }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/worktree-provision-fixtures.XXXXXX")" || exit 1
SANDBOX="$(cd "$SANDBOX" && pwd -P)" || exit 1      # /var -> /private/var on macOS
case "$SANDBOX" in /*) ;; *) echo "ERROR: bad sandbox path" >&2; exit 1 ;; esac
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

FAILURES=0; CASES=0
mkdir -p "$SANDBOX/home"

sandboxed() { # $1 = path about to be used destructively
  case "${1:-}" in
    "$SANDBOX"/*) return 0 ;;
    *) echo "ABORT: refusing to operate outside the sandbox: [${1:-<empty>}]" >&2
       exit 2 ;;
  esac
}

check() { # $1 label  $2 expected  $3 actual
  CASES=$((CASES + 1))
  if [ "$2" = "$3" ]; then VERDICT="PASS"; else VERDICT="FAIL"; FAILURES=$((FAILURES + 1)); fi
  printf '%-64s\n  exp=[%s]\n  got=[%s]  %s\n' "$1" "$2" "$3" "$VERDICT"
}
contains() { # $1 haystack  $2 needle -> yes/no
  case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
yesno() { if "$@"; then printf 'yes'; else printf 'no'; fi; }

# -------------------------------------------------- GH #15 tripwire (read only)
HOST_REPO="$(git -C "$TESTS_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
host_fingerprint() {
  [ -n "$HOST_REPO" ] || { printf 'no-host-repo'; return; }
  printf '%s|%s' "$(git -C "$HOST_REPO" rev-parse HEAD 2>/dev/null)" \
                 "$(git -C "$HOST_REPO" status --porcelain 2>/dev/null | sort | cksum)"
}
HOST_BEFORE="$(host_fingerprint)"

LIB_UNDER_TEST="$LIB"

# ------------------------------------------------------------------ helpers
# A synthetic repo shaped like the one the failure was measured on: an
# environment file its test reads, a per-worktree install directory, and a test
# script that fails in exactly the measured way when either is missing.
#   $1 = name
#   $2 = ignore-env | track-env | expose-env
#        ignore-env  the realistic case: .env gitignored, so it is absent from a
#                    fresh worktree and a copy of it stays invisible to git
#        track-env   .env committed — no copy is needed and none leaks
#        expose-env  .env neither ignored nor committed, so a copy of it is
#                    UNTRACKED IN THE WORKTREE: the credential-leak hazard
mkrepo() { # -> repo path on stdout
  MKR_D="$SANDBOX/repos/$1"; sandboxed "$MKR_D"
  rm -rf "$MKR_D"; mkdir -p "$MKR_D/scripts"
  git -C "$MKR_D" init -q 2>/dev/null
  git -C "$MKR_D" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
  case "$2" in
    ignore-env) printf '.env\nnode_modules/\n' > "$MKR_D/.gitignore" ;;
    *)          printf 'node_modules/\n'       > "$MKR_D/.gitignore" ;;
  esac
  cat > "$MKR_D/scripts/test-api.sh" <<'MKR_API'
#!/bin/sh
[ -f .env ] || { echo "RuntimeError: DB_PASSWORD is not set"; exit 1; }
[ -d node_modules ] || { echo "node_modules missing"; exit 1; }
echo "api: 2385 passed"
MKR_API
  cat > "$MKR_D/scripts/test-web.sh" <<'MKR_WEB'
#!/bin/sh
[ -d node_modules ] || { echo "node_modules missing"; exit 1; }
echo "web: 1166 passed"
MKR_WEB
  chmod +x "$MKR_D/scripts/test-api.sh" "$MKR_D/scripts/test-web.sh"
  printf 'placeholder\n' > "$MKR_D/README"
  git -C "$MKR_D" add -A >/dev/null 2>&1
  printf 'DB_PASSWORD=hunter2\n' > "$MKR_D/.env"
  [ "$2" = track-env ] && git -C "$MKR_D" add -f .env >/dev/null 2>&1
  git -C "$MKR_D" -c user.email=f@f -c user.name=f commit -qm init >/dev/null 2>&1
  printf '%s' "$MKR_D"
}

mkwt() { # $1 = repo path, $2 = worktree name -> worktree path on stdout
  MKW_W="$SANDBOX/worktrees/$2"; sandboxed "$MKW_W"
  rm -rf "$MKW_W"; mkdir -p "$SANDBOX/worktrees"
  git -C "$1" worktree add -q -b "wt-$2" "$MKW_W" HEAD >/dev/null 2>&1
  printf '%s' "$MKW_W"
}

cfg() { # $1 = name, rest = lines -> config path on stdout
  CFG_F="$SANDBOX/cfg-$1"; sandboxed "$CFG_F"; shift
  : > "$CFG_F"
  for CFG_L in "$@"; do printf '%s\n' "$CFG_L" >> "$CFG_F"; done
  chmod 600 "$CFG_F"
  printf '%s' "$CFG_F"
}

# Run the library's CLI. PV_OUT and PV_RC are the result. Both the config path
# and HOME are redirected on EVERY call, with no code path that omits either.
pv() { # $1 = config path, rest = CLI args
  PV_CFG="$1"; shift
  PV_OUT="$(INTAKE_PROVISION_FILE="$PV_CFG" HOME="$SANDBOX/home" \
            /bin/bash "$LIB_UNDER_TEST" "$@" 2>&1)"
  PV_RC=$?
}

# Source the library in its own process and run a snippet against it.
pvsh() { # $1 = config path, $2 = snippet -> stdout+stderr
  PVS_CFG="$1"
  INTAKE_PROVISION_FILE="$PVS_CFG" PROVISION_LIB_UT="$LIB_UNDER_TEST" \
  HOME="$SANDBOX/home" \
    /bin/bash -c 'set -u; . "$PROVISION_LIB_UT"; '"$2" 2>&1
}

echo "=== A. INERTNESS: no provisioning file at all ============================"
# Branch 1 of provision_resolve, and the state of every machine that has not
# opted in. Nothing declared, nothing logged, nothing run, rc 0.
A_REPO="$(mkrepo a ignore-env)"
A_WT="$(mkwt "$A_REPO" a)"
A_NONE="$SANDBOX/no-such-provisioning-file"
pv "$A_NONE" --check --repo "$A_REPO" --slug "acme/a"
check "A: an absent config is not an error"                    "0"   "$PV_RC"
check "A: and it says so in the way a human reads first"       "yes" "$(contains "$PV_OUT" "absent — every worktree is bare and today is unchanged")"
check "A: the repo gets a bare worktree"                       "yes" "$(contains "$PV_OUT" "a bare worktree, exactly as before this existed")"
check "A: PROVISION_LOG is EMPTY — the inertness claim itself"  "[]" \
      "[$(pvsh "$A_NONE" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_LOG\"")]"
check "A: nothing is DECLARED"                                 "no" \
      "$(pvsh "$A_NONE" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_DECLARED\"")"
pv "$A_NONE" --preflight "$A_WT" --repo "$A_REPO" --slug "acme/a"
check "A: preflight succeeds and provisions nothing"           "0"   "$PV_RC"
check "A: and names the bare worktree as unchanged"            "yes" "$(contains "$PV_OUT" "bare worktree, unchanged")"
check "A: no .env was copied into the worktree"                "no"  "$(yesno test -f "$A_WT/.env")"
check "A: no install ran"                                      "no"  "$(yesno test -d "$A_WT/node_modules")"
check "A: and the worktree is still clean"                     "[]"  "[$(git -C "$A_WT" status --porcelain)]"

echo
echo "=== B. INERTNESS: a config that exists but names other repos ============="
# Branch 4 of provision_resolve. The file is present and valid; this repo simply
# is not in it. Also silent, because a machine that provisions one repo must not
# change its behaviour towards the others.
B_CFG="$(cfg b "[other/repo]" "smoke = true")"
pv "$B_CFG" --check --repo "$A_REPO" --slug "acme/a"
check "B: an unnamed repo resolves cleanly"                    "0"   "$PV_RC"
check "B: and is still bare"                                   "yes" "$(contains "$PV_OUT" "a bare worktree, exactly as before this existed")"
check "B: PROVISION_LOG is still empty"                        "[]" \
      "[$(pvsh "$B_CFG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_LOG\"")]"
check "B: the reason is 'unconfigured', not an error"          "unconfigured" \
      "$(pvsh "$B_CFG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_REASON\"")"

echo
echo "=== C. INERTNESS: an EMPTY section is a declaration of nothing ==========="
# A section with no keys under it. It exists — so a second section naming the
# same repo is still a conflict — but what it declares is "no provisioning", so
# the answer is a bare worktree and silence.
C_CFG="$(cfg c "[$A_REPO]")"
pv "$C_CFG" --check --repo "$A_REPO" --slug "acme/a"
check "C: an empty section is not an error"                    "0"   "$PV_RC"
check "C: it declares nothing"                                 "no" \
      "$(pvsh "$C_CFG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_DECLARED\"")"
check "C: and it is silent"                                    "[]" \
      "[$(pvsh "$C_CFG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_LOG\"")]"

echo
echo "=== D. THE PARSER REFUSES, AND NAMES WHAT IS WRONG ======================="
D_T() { # $1 = label, $2 = needle, rest = config lines
  D_LBL="$1"; D_NEEDLE="$2"; shift 2
  D_CFG="$(cfg "d-$(printf '%s' "$D_LBL" | tr -c 'a-z0-9' '-')" "$@")"
  pv "$D_CFG" --check
  check "D: $D_LBL is refused"                    "1"   "$PV_RC"
  check "D: ...naming it: $D_NEEDLE"              "yes" "$(contains "$PV_OUT" "$D_NEEDLE")"
  check "D: ...and nothing is provisioned"        "yes" "$(contains "$PV_OUT" "INVALID — nothing is provisioned and no dispatch may proceed")"
}
D_T "an unknown key"          "unknown key 'instal'"              "[o/r]" "smoke = true" "instal = x"
D_T "an empty value"          "has an empty value"                "[o/r]" "smoke = true" "install ="
D_T "a key outside a section" "key outside any [section]"         "smoke = true"
D_T "a junk line"             "not a comment, a [section] header" "[o/r]" "smoke = true" "just some words"
D_T "a [global] section"      "[global] has no meaning here"      "[global]" "smoke = true"
D_T "a bare-word section"     "is neither a path"                 "[notaslug]" "smoke = true"
D_T "a three-part section"    "is neither a path"                 "[a/b/c]" "smoke = true"
D_T "a duplicate section"     "duplicate section"                 "[o/r]" "smoke = true" "[o/r]" "smoke = true"
D_T "a duplicate key"         "duplicate key 'smoke'"             "[o/r]" "smoke = true" "smoke = false"
D_T "an unnamed gate"         "is not a usable gate name"         "[o/r]" "smoke = true" "gates. = x"
D_T "a gate type with a space" "is not a usable gate name"        "[o/r]" "smoke = true" "gates.a b = x"
D_T "an absolute env-file"    "must be a repo-relative path"      "[o/r]" "smoke = true" "env-files = /etc/passwd"
D_T "a ~ env-file"            "must be a repo-relative path"      "[o/r]" "smoke = true" "env-files = ~/.aws/credentials"
D_T "a traversing env-file"   "must be a repo-relative path"      "[o/r]" "smoke = true" "env-files = ../../../.env"
D_T "a glob env-file"         "must be a repo-relative path"      "[o/r]" "smoke = true" "env-files = *.env"

# The rule that mirrors item 1 requiring a size ceiling above L0: a section
# claiming a worktree can run its gates must state how that claim is CHECKED.
D_T "a section with no smoke" "declares provisioning but no 'smoke' command" "[o/r]" "install = true"

# And the shapes that must NOT be refused.
D_OK="$(cfg d-ok "# a comment" "; another" "" "[o/r]" "  smoke   =   true  " "gates.web-2.0_x = y")"
pv "$D_OK" --check
check "D: comments, blanks, padding and a dotted gate type parse" "0" "$PV_RC"

echo
echo "=== E. THE SOURCE GUARD: this file's values are EXECUTED ================="
# `install`, `smoke` and every `gates.*` value are shell commands this library
# runs. Provenance is therefore checked before a single line is parsed, and
# loose permissions are a refusal rather than a warning.
E_CFG="$(cfg e "[$A_REPO]" "smoke = true")"
chmod 646 "$E_CFG"
pv "$E_CFG" --check --repo "$A_REPO"
check "E: a world-writable config is refused"        "1"   "$PV_RC"
check "E: ...naming the mode and the fix"            "yes" "$(contains "$PV_OUT" "world-writable (mode 646); chmod 600")"
check "E: ...before parsing, not after"              "yes" "$(contains "$PV_OUT" "refused before parsing")"
chmod 660 "$E_CFG"
pv "$E_CFG" --check --repo "$A_REPO"
check "E: a group-writable config is refused"        "1"   "$PV_RC"
check "E: ...naming the mode and the fix"            "yes" "$(contains "$PV_OUT" "group-writable (mode 660); chmod 600")"
chmod 600 "$E_CFG"
pv "$E_CFG" --check --repo "$A_REPO"
check "E: 600 is accepted"                           "0"   "$PV_RC"
E_DIR="$SANDBOX/cfg-e-dir"; sandboxed "$E_DIR"; mkdir -p "$E_DIR"
pv "$E_DIR" --check
check "E: a directory is not a config file"          "1"   "$PV_RC"
check "E: ...and says so"                            "yes" "$(contains "$PV_OUT" "not a regular file")"
# A refused config is a refusal for the REPO too, not merely a file-level gripe.
chmod 646 "$E_CFG"
pv "$E_CFG" --preflight "$A_WT" --repo "$A_REPO"
check "E: and no dispatch may proceed into any worktree" "1" "$PV_RC"
check "E: ...loudly"                                 "yes" "$(contains "$PV_OUT" "REFUSING TO DISPATCH")"
check "E: ...and it still copied nothing"            "no"  "$(yesno test -f "$A_WT/.env")"
chmod 600 "$E_CFG"

echo
echo "=== F. RESOLUTION: one repo, one section ================================"
F_CFG="$(cfg f "[$A_REPO]" "smoke = true" "install = mkdir -p node_modules")"
check "F: a PATH section matches the checkout"       "yes" \
      "$(pvsh "$F_CFG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_DECLARED\"")"
F_SLUG="$(cfg f-slug "[acme/a]" "smoke = true")"
check "F: a SLUG section matches too"                "yes" \
      "$(pvsh "$F_SLUG" "provision_resolve '$A_REPO' 'acme/a'; printf '%s' \"\$PROVISION_DECLARED\"")"
F_BOTH="$(cfg f-both "[$A_REPO]" "smoke = true" "[acme/a]" "smoke = false")"
pv "$F_BOTH" --check --repo "$A_REPO" --slug "acme/a"
check "F: BOTH claiming one repo is a conflict"      "1"   "$PV_RC"
check "F: ...naming both sections"                   "yes" "$(contains "$PV_OUT" "both declare this repo — one repo, one section")"
# A trailing slash and a `~` are the same path, so they must resolve the same.
F_TILDE="$(cfg f-tilde "[$A_REPO/]" "smoke = true")"
check "F: a trailing slash is the same path"         "yes" \
      "$(pvsh "$F_TILDE" "provision_resolve '$A_REPO' ''; printf '%s' \"\$PROVISION_DECLARED\"")"

echo
echo "=== G. THE GATE SET IS PER ITEM TYPE ===================================="
# Finding 2 from the measured dispatch: the repo-wide gate script covered ZERO
# TypeScript, so it ran none of the tests covering a .tsx item. The brief said
# "the gate is test-both.sh" and was wrong. The gate set is therefore declared.
G_CFG="$(cfg g "[$A_REPO]" \
  "smoke = sh scripts/test-api.sh" \
  "gates.api = sh scripts/test-api.sh" \
  "gates.web = sh scripts/test-web.sh")"
check "G: a declared type returns its command"       "sh scripts/test-web.sh" \
      "$(pvsh "$G_CFG" "provision_resolve '$A_REPO' ''; provision_gates web")"
check "G: no type named returns EVERY gate"          "sh scripts/test-api.sh|sh scripts/test-web.sh" \
      "$(pvsh "$G_CFG" "provision_resolve '$A_REPO' ''; provision_gates ''" | tr '\n' '|' | sed 's/|$//')"
pv "$G_CFG" --gates tsx --repo "$A_REPO"
check "G: an UNDECLARED type is REFUSED, never guessed" "1" "$PV_RC"
check "G: ...listing what IS declared"               "yes" "$(contains "$PV_OUT" "declared: api web")"
check "G: ...and prints no command at all"           "no"  "$(contains "$PV_OUT" "scripts/test-")"
# Declaration order, not sorted order: an author who wrote web before api meant it.
G_ORD="$(cfg g-ord "[$A_REPO]" "smoke = true" "gates.web = W" "gates.api = A")"
check "G: gates come back in DECLARATION order"      "W|A" \
      "$(pvsh "$G_ORD" "provision_resolve '$A_REPO' ''; provision_gates ''" | tr '\n' '|' | sed 's/|$//')"
# A repo that declares provisioning but no gates says so rather than inventing one.
G_NOG="$(cfg g-nog "[$A_REPO]" "smoke = true")"
pv "$G_NOG" --gates "" --repo "$A_REPO"
check "G: provisioning without gates is refused"     "1"   "$PV_RC"
check "G: ...naming the section"                     "yes" "$(contains "$PV_OUT" "declares provisioning but no gates.<type>")"
# And an unconfigured repo hands the executor back to its own discipline.
pv "$A_NONE" --gates api --repo "$A_REPO"
check "G: an unconfigured repo declares no gates"    "1"   "$PV_RC"
check "G: ...and defers to the executor's stack-gates" "yes" \
      "$(contains "$PV_OUT" "the executor's own stack-gates discipline is what applies")"

echo
echo "=== H. THE BRIEF THE DISPATCH CARRIES ===================================="
pv "$G_CFG" --brief api --repo "$A_REPO"
check "H: a brief is produced"                       "0"   "$PV_RC"
check "H: it names the item type"                    "yes" "$(contains "$PV_OUT" 'item type `api`')"
check "H: it numbers the commands"                   "yes" "$(contains "$PV_OUT" "1. sh scripts/test-api.sh")"
check "H: it forbids substitution"                   "yes" "$(contains "$PV_OUT" "Do NOT substitute a gate you believe is equivalent")"
check "H: it forbids skipping"                       "yes" "$(contains "$PV_OUT" "do NOT skip one that")"
check "H: it says why, so the reader can weigh it"   "yes" "$(contains "$PV_OUT" "a repo-wide gate script was measured covering none of an item")"
check "H: it carries only the named type's gate"     "no"  "$(contains "$PV_OUT" "test-web.sh")"
pv "$G_CFG" --brief "" --repo "$A_REPO"
check "H: an untyped brief carries every gate"       "yes" "$(contains "$PV_OUT" "test-web.sh")"
check "H: ...and says the dispatch named no type"    "yes" "$(contains "$PV_OUT" "because the dispatch named no item type")"
pv "$G_CFG" --brief tsx --repo "$A_REPO"
check "H: an undeclared type produces NO brief"      "1"   "$PV_RC"

echo
echo "=== I. PROVISIONING THE WORKTREE ========================================"
I_REPO="$(mkrepo i ignore-env)"
I_WT="$(mkwt "$I_REPO" i)"
I_CFG="$(cfg i "[$I_REPO]" \
  "env-files = .env" \
  "install   = mkdir -p node_modules" \
  "smoke     = sh scripts/test-api.sh")"
check "I: the file is genuinely absent from a fresh worktree" "no" "$(yesno test -f "$I_WT/.env")"
pv "$I_CFG" --preflight "$I_WT" --repo "$I_REPO" --slug "acme/i"
check "I: preflight succeeds"                        "0"   "$PV_RC"
check "I: the declared file was copied"              "yes" "$(yesno test -f "$I_WT/.env")"
check "I: with its contents intact"                  "DB_PASSWORD=hunter2" "$(cat "$I_WT/.env" 2>/dev/null)"
check "I: the declared install ran"                  "yes" "$(yesno test -d "$I_WT/node_modules")"
check "I: it reported the copy"                      "yes" "$(contains "$PV_OUT" "copied .env into the worktree")"
check "I: it reported the install"                   "yes" "$(contains "$PV_OUT" "ran install — mkdir -p node_modules")"
check "I: it reported the smoke check"               "yes" "$(contains "$PV_OUT" "smoke check passed")"
check "I: and cleared the worktree for dispatch"     "yes" "$(contains "$PV_OUT" "may be dispatched into")"
check "I: the worktree is CLEAN afterwards"          "[]"  "[$(git -C "$I_WT" status --porcelain)]"
# A missing source file is a refusal, not a warning: a worktree cut from this
# repo cannot run its gates without it, and continuing produces the exact
# false-red this item exists to prevent.
I_MISS="$(cfg i-miss "[$I_REPO]" "env-files = .env.production" "smoke = true")"
I_WT2="$(mkwt "$I_REPO" i2)"
pv "$I_MISS" --preflight "$I_WT2" --repo "$I_REPO"
check "I: a missing source file refuses"             "1"   "$PV_RC"
check "I: ...naming the file"                        "yes" "$(contains "$PV_OUT" ".env.production")"
check "I: ...and saying it is a refusal, not a warning" "yes" "$(contains "$PV_OUT" "this is a refusal and not a warning")"
# A failing install is a refusal too, with its exit code and its output.
I_BADINST="$(cfg i-badinst "[$I_REPO]" "install = echo nope >&2; exit 7" "smoke = true")"
I_WT3="$(mkwt "$I_REPO" i3)"
pv "$I_BADINST" --preflight "$I_WT3" --repo "$I_REPO"
check "I: a failing install refuses"                 "1"   "$PV_RC"
check "I: ...with its exit code"                     "yes" "$(contains "$PV_OUT" "the declared install failed (exit 7)")"
check "I: ...and never reaches the smoke check"      "no"  "$(contains "$PV_OUT" "smoke check passed")"

echo
echo "=== J. THE SMOKE CHECK IS THE POINT ====================================="
# "We provisioned" and "the gate can run" are different claims. The measured
# failure had the file present and STILL could not run, so only the second claim
# is worth checking. An install that does not actually make the gate runnable
# must refuse to dispatch, loudly.
J_REPO="$(mkrepo j ignore-env)"
J_WT="$(mkwt "$J_REPO" j)"
J_CFG="$(cfg j "[$J_REPO]" "install = true" "smoke = sh scripts/test-api.sh")"
pv "$J_CFG" --preflight "$J_WT" --repo "$J_REPO"
check "J: provisioning that did not work REFUSES"    "1"   "$PV_RC"
check "J: ...loudly, in capitals, first line"        "yes" "$(contains "$PV_OUT" "THE SMOKE CHECK FAILED (exit 1)")"
check "J: ...refusing to dispatch"                   "yes" "$(contains "$PV_OUT" "REFUSING TO DISPATCH")"
check "J: ...naming the three bad outcomes it prevents" "yes" \
      "$(contains "$PV_OUT" "a false blocked, a false red")"
check "J: ...and quoting the real failure verbatim"  "yes" "$(contains "$PV_OUT" "RuntimeError: DB_PASSWORD is not set")"
check "J: ...with a log path for the rest"           "yes" "$(contains "$PV_OUT" "full output:")"
# Refusing is not the same as reporting success with a caveat: rc must be 1 and
# the "may be dispatched into" line must be absent.
check "J: it never says the worktree may be used"    "no"  "$(contains "$PV_OUT" "may be dispatched into")"

echo
echo "=== K. THE MEASURED FAILURE, REPRODUCED AND THEN FIXED ==================="
# The whole item in one case, against a SYNTHETIC repo. The real product repo is
# never touched: it is not named here and does not need to exist.
K_REPO="$(mkrepo k ignore-env)"
K_WT="$(mkwt "$K_REPO" k)"
K_BARE_OUT="$(cd "$K_WT" && sh scripts/test-api.sh 2>&1)"; K_BARE_RC=$?
check "K: a BARE worktree cannot run its gate"       "1"   "$K_BARE_RC"
check "K: ...failing exactly as it was measured"     "RuntimeError: DB_PASSWORD is not set" "$K_BARE_OUT"
K_CFG="$(cfg k "[$K_REPO]" \
  "env-files = .env" \
  "install   = mkdir -p node_modules" \
  "smoke     = sh scripts/test-api.sh" \
  "gates.api = sh scripts/test-api.sh" \
  "gates.web = sh scripts/test-web.sh")"
pv "$K_CFG" --preflight "$K_WT" --repo "$K_REPO" --slug "acme/k"
check "K: preflight makes it runnable"               "0"   "$PV_RC"
K_API="$(cd "$K_WT" && sh scripts/test-api.sh 2>&1)"; K_API_RC=$?
K_WEB="$(cd "$K_WT" && sh scripts/test-web.sh 2>&1)"; K_WEB_RC=$?
check "K: the api gate now runs green"               "0|api: 2385 passed" "$K_API_RC|$K_API"
check "K: AND the web gate does too — both, not one" "0|web: 1166 passed" "$K_WEB_RC|$K_WEB"
check "K: with no manual step in between"            "[]"  "[$(git -C "$K_WT" status --porcelain)]"

echo
echo "=== L. THE CREDENTIAL LEAK, WHICH IS SILENT WHEN IT HAPPENS =============="
# A copied environment file that is NOT gitignored in the worktree is an
# untracked file in a checkout an unattended executor is about to run `git add`
# in. That is a credential in a pull request, and it is invisible at the moment
# it happens. This is the case that only fires when the copy is genuinely
# exposed, so it is asserted against BOTH shapes.
L_SAFE="$(mkrepo l-safe ignore-env)"
L_SWT="$(mkwt "$L_SAFE" l-safe)"
L_SCFG="$(cfg l-safe "[$L_SAFE]" "env-files = .env" "smoke = true")"
pv "$L_SCFG" --preflight "$L_SWT" --repo "$L_SAFE"
check "L: a gitignored .env copies cleanly"          "0"   "$PV_RC"
check "L: ...and is invisible to git"                "[]"  "[$(git -C "$L_SWT" status --porcelain)]"
L_LEAK="$(mkrepo l-leak expose-env)"
L_LWT="$(mkwt "$L_LEAK" l-leak)"
L_LCFG="$(cfg l-leak "[$L_LEAK]" "env-files = .env" "smoke = true")"
pv "$L_LCFG" --preflight "$L_LWT" --repo "$L_LEAK"
check "L: an EXPOSED .env refuses to dispatch"       "1"   "$PV_RC"
check "L: ...calling it visible to git"              "yes" "$(contains "$PV_OUT" "VISIBLE TO GIT")"
check "L: ...naming the file"                        "yes" "$(contains "$PV_OUT" ": .env —")"
check "L: ...and saying what would happen"           "yes" \
      "$(contains "$PV_OUT" "would commit credential material into a pull request")"
# An install that rewrites a lockfile is the same defect wearing different
# clothes: changes in the executor's diff that the executor did not make.
L_DIRTY="$(mkrepo l-dirty ignore-env)"
L_DWT="$(mkwt "$L_DIRTY" l-dirty)"
L_DCFG="$(cfg l-dirty "[$L_DIRTY]" "install = echo rewritten > README" "smoke = true")"
pv "$L_DCFG" --preflight "$L_DWT" --repo "$L_DIRTY"
check "L: an install that dirties the tree refuses"  "1"   "$PV_RC"
check "L: ...naming the diff it would have caused"   "yes" \
      "$(contains "$PV_OUT" "the executor's diff would contain changes it did not make")"

echo
echo "=== M. THE CONTRACT MARKER: WIRED, AND BY EXACTLY ONE CALLER ============"
# For the whole of item 2b this section asserted that NOTHING called the
# provisioner. Epic 11 item 3 is the caller it was waiting for, so the assertions
# are inverted rather than left pointing at a file the behaviour moved out of —
# and the part that still matters is unchanged: exactly one caller, and it is a
# dispatch path, never the drafting one.
M_DISPATCHER="${INTAKE_FIXTURE_DISPATCH_LIB:-$(cd "$(dirname "$0")/../../bin" && pwd)/dispatch.sh}"
check "M: the library says dispatch IS wired"        "PROVISION_DISPATCH_WIRED=yes" \
      "$(grep -m1 '^PROVISION_DISPATCH_WIRED=' "$LIB")"
check "M: and --check prints it, so a human can see" "yes" \
      "$(pv "$A_NONE" --check; contains "$PV_OUT" "dispatch wired  yes")"
check "M: precondition — the dispatcher exists and parses" "yes" \
      "$(yesno /bin/bash -n "$M_DISPATCHER")"
# THE RUNNER STILL ONLY LOADS AND VALIDATES. Everything that ACTS is in the
# dispatcher, which is what keeps "a drafting worktree is never provisioned" true
# by construction rather than by care: the drafting path cannot reach the caller.
check "M: the runner still calls no provisioning function" "0" \
      "$(grep -v '^[[:space:]]*#' "$SCRIPT" | grep -cE '(^|[^_[:alnum:]])provision_(preflight|worktree|smoke_check|gates|gate_brief)[[:space:]]*$|(^|[^_[:alnum:]])provision_(preflight|worktree|smoke_check|gates|gate_brief)[[:space:]]+' | tr -d ' ')"
check "M: ...it only loads and validates the config" "yes" \
      "$(yesno grep -q 'provision_load' "$SCRIPT")"
check "M: the DISPATCHER calls the preflight"        "yes" \
      "$(yesno grep -q 'provision_preflight "' "$M_DISPATCHER")"
check "M: ...and asks for the declared gate set"     "yes" \
      "$(yesno grep -q 'provision_gate_brief "' "$M_DISPATCHER")"
check "M: ...and REFUSES the dispatch when the preflight fails" "yes" \
      "$(yesno grep -q 'worktree provisioning refused this dispatch' "$M_DISPATCHER")"
check "M: ...and never calls provision_worktree without the smoke check" "0" \
      "$(grep -v '^[[:space:]]*#' "$M_DISPATCHER" | grep -cE '(^|[^_[:alnum:]])provision_(worktree|smoke_check)[[:space:]]' | tr -d ' ')"

echo
echo "=== N. THE RUNNER: INERTNESS PROVEN, AND THE CASE THAT DISCRIMINATES ====="
# Reconstruct the runner as it stood before this item by deleting exactly the
# lines the item added. Brittle ON PURPOSE: if the block moves, the line count
# stops matching and this stops rather than proving nothing.
PRE="$SANDBOX/unattended-intake.pre-item-2b.sh"; sandboxed "$PRE"
line_of() { grep -nF -m1 -- "$2" "$1" | cut -d: -f1; }
N_S="$(line_of "$SCRIPT" '# ----------------------------------- worktree provisioning (epic 11 item 2b)')"
N_E="$(line_of "$SCRIPT" '# The autonomy config is validated ONCE per run, not once per repo, and it is')"
for V in "$N_S" "$N_E"; do
  case "$V" in ''|*[!0-9]*)
    echo "ERROR: an anchor for the pre-item-2b reconstruction did not match." >&2
    echo "       The item-2b block moved, so this case would prove nothing." >&2
    exit 1 ;;
  esac
done
sed -e "${N_S},$((N_E - 1))d" "$SCRIPT" > "$PRE"
chmod +x "$PRE"
N_REMOVED=$(( $(wc -l < "$SCRIPT") - $(wc -l < "$PRE") ))
check "N: the reconstruction removes exactly the item's 40 added lines" "40" "$N_REMOVED"
if [ "$N_REMOVED" -ne 40 ]; then
  echo "ERROR: the pre-item-2b reconstruction is $N_REMOVED lines, not 40. Either" >&2
  echo "       the item grew or the anchors rotted; either way this is not a proof." >&2
  exit 1
fi
cmp -s "$SCRIPT" "$PRE" && { echo "ERROR: the reconstruction is identical to the script" >&2; exit 1; }
/bin/bash -n "$PRE" || { echo "ERROR: the pre-item-2b reconstruction does not parse" >&2; exit 1; }
# CODE, not prose. Epic 11 item 3's block in the runner legitimately describes
# what it does — it provisions a dispatch worktree — and a bare `grep -i
# provision` would count that sentence as item 2b's code surviving the deletion.
# What this case asserts is that item 2b's MECHANISM is gone, and the mechanism
# is named by its variable prefix and its function prefix.
check "N: and it carries no trace of provisioning CODE" "0" \
      "$(grep -v '^[[:space:]]*#' "$PRE" | grep -cE 'PROVISION_|provision_' | tr -d ' ')"
check "N: while the shipped runner does"             "yes" \
      "$(yesno grep -q 'PROVISION_LIB' "$SCRIPT")"

# --- the smallest cycle that reaches the block: a repo with no issues to draft.
NBIN="$SANDBOX/bin"; sandboxed "$NBIN"; mkdir -p "$NBIN"
cat > "$NBIN/gh" <<'N_GH'
#!/usr/bin/env bash
set -u
printf 'gh %s\n' "$(printf '%s ' "$@")" >> "$FIXTURE_CASE_DIR/calls.log"
case " $* " in
  *" repo view "*" nameWithOwner "*)      printf 'fixture/repo\n'; exit 0 ;;
  *" repo view "*" defaultBranchRef "*)   printf 'main\n'; exit 0 ;;
  *" label list "*)                       exit 0 ;;
  *" label create "*)                     exit 0 ;;
  *" issue list "*)                       exit 0 ;;
  *" pr list "*)                          exit 0 ;;
  *" api "*)                              exit 0 ;;
esac
printf 'gh STUB UNANSWERED: %s\n' "$*" >> "$FIXTURE_CASE_DIR/calls.log"
printf 'stub cannot answer: %s\n' "$*" >&2
exit 1
N_GH
cat > "$NBIN/git" <<'N_GIT'
#!/usr/bin/env bash
set -u
printf 'git %s\n' "$(printf '%s ' "$@")" >> "$FIXTURE_CASE_DIR/calls.log"
case " $* " in
  *" rev-parse --show-toplevel "*) printf '%s\n' "$FIXTURE_CASE_DIR/repo"; exit 0 ;;
  *" rev-parse "*)                 printf 'deadbeef\n'; exit 0 ;;
  *" status --porcelain "*)        exit 0 ;;
esac
exit 0
N_GIT
cat > "$NBIN/claude" <<'N_CLAUDE'
#!/usr/bin/env bash
set -u
printf 'claude %s\n' "$(printf '%s ' "$@")" >> "$FIXTURE_CASE_DIR/calls.log"
exit 0
N_CLAUDE
chmod +x "$NBIN/gh" "$NBIN/git" "$NBIN/claude"

# The runner refuses to start without its skill references. They are stubbed in
# the sandbox rather than pointed at the real ones, so the reconstruction — which
# lives in the sandbox and cannot resolve them relatively — starts on equal terms.
N_SKILL="$SANDBOX/skill"; sandboxed "$N_SKILL"; mkdir -p "$N_SKILL/references"
printf 'fixture issue-intake reference\n'  > "$N_SKILL/references/issue-intake.md"
printf 'fixture plan-template reference\n' > "$N_SKILL/references/plan-template.md"

nkcase() { # $1 = name -> case dir
  NK_D="$SANDBOX/$1"; sandboxed "$NK_D"
  rm -rf "$NK_D"; mkdir -p "$NK_D/repo/.git" "$NK_D/worktrees" "$NK_D/home"
  : > "$NK_D/calls.log"
  printf '%s\n' "$NK_D/repo" > "$NK_D/repos"
  printf 'CLAUDE_CODE_OAUTH_TOKEN=fixture-token-not-real\n' > "$NK_D/env"
  chmod 600 "$NK_D/env"
  printf '%s' "$NK_D"
}
N_SUT="$SCRIPT"
# Epic 11 item 2's telemetry library, passed EXPLICITLY for the same reason
# INTAKE_PROVISION_LIB is: the runner resolves it relative to its OWN path, so
# the reconstruction below — which lives in the sandbox — would silently lose it
# and the two sides of this byte-identity proof would differ for a reason that
# has nothing to do with item 2b. Both sides get the same library. Item 1's
# suite carries the identical line for the identical reason.
N_STATUS_LIB="${INTAKE_FIXTURE_STATUS_LIB:-$(cd "$(dirname "$0")/../../bin" && pwd)/intake-status.sh}"
# Epic 11 item 3's dispatch library, for the identical reason. Without it the
# reconstruction below would lose the dispatcher while the shipped copy kept it,
# and this proof would be about two variables instead of one.
N_DISPATCH_LIB="${INTAKE_FIXTURE_DISPATCH_LIB:-$(cd "$(dirname "$0")/../../bin" && pwd)/dispatch.sh}"
run_intake() { # $1 = case dir, rest = extra args -> exit code
  RI_D="$1"; shift; sandboxed "$RI_D"
  INTAKE_GIT="$NBIN/git" INTAKE_GH="$NBIN/gh" INTAKE_CLAUDE="$NBIN/claude" \
  INTAKE_SKILL_DIR="$N_SKILL" \
  INTAKE_ENV_FILE="$RI_D/env" INTAKE_REPO_LIST="$RI_D/repos" \
  INTAKE_REPO_DIR="$RI_D/repo" INTAKE_LOG="$RI_D/intake.log" \
  INTAKE_LOCK="$RI_D/.lock" INTAKE_WORKTREE_ROOT="$RI_D/worktrees" \
  INTAKE_PROVISION_FILE="$RI_D/provisioning" INTAKE_PROVISION_LIB="$LIB_UNDER_TEST" \
  INTAKE_STATUS_LIB="$N_STATUS_LIB" INTAKE_DISPATCH_LIB="$N_DISPATCH_LIB" \
  FIXTURE_CASE_DIR="$RI_D" FIXTURE_REPO_SLUG="fixture/repo" \
  HOME="$RI_D/home" \
    /bin/bash "$N_SUT" "$@" > "$RI_D/stdout.log" 2> "$RI_D/stderr.log"
  printf '%s' "$?"
}
normalise() { sed -E -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| //' \
                     -e "s|$1|<CASE>|g" -e "s|$SANDBOX|<SANDBOX>|g"; }

# --- N1: unconfigured, shipped vs pre-item-2b, byte for byte.
NA="$(nkcase N-after)"; NB="$(nkcase N-before)"
RC_A="$(run_intake "$NA")"
N_SUT="$PRE"; RC_B="$(run_intake "$NB")"; N_SUT="$SCRIPT"
check "N: both unconfigured runs succeeded"          "0|0" "$RC_A|$RC_B"
check "N: no provisioning file was created"          "no"  "$(yesno test -e "$NA/provisioning")"
for STREAM in intake.log stdout.log stderr.log calls.log; do
  check "N: BYTE-IDENTICAL to the pre-item-2b runner — $STREAM" "same" \
        "$(if diff -q <(normalise "$NA" < "$NA/$STREAM") \
                     <(normalise "$NB" < "$NB/$STREAM") >/dev/null 2>&1; \
           then printf 'same'; else printf 'DIFFERENT'; fi)"
done
# The sandbox's own mktemp name contains "provision", so this is asked of the
# NORMALISED log: otherwise the case matches the harness and not the code.
check "N: and the log says nothing about provisioning" "0" \
      "$(normalise "$NA" < "$NA/intake.log" | grep -ci provision | tr -d ' ')"

# --- N2: THE DISCRIMINATING CASE. A malformed provisioning config is reported
# by the shipped runner on the timer, and is invisible to the pre-item-2b one.
# Without this pair the byte-identity above would pass on a runner that does
# nothing at all, which is precisely what a negative control is for.
NC="$(nkcase N-bad-after)"; ND="$(nkcase N-bad-before)"
for D in "$NC" "$ND"; do
  printf '[o/r]\nnonsense-key = x\n' > "$D/provisioning"; chmod 600 "$D/provisioning"
done
RC_C="$(run_intake "$NC")"
N_SUT="$PRE"; RC_D="$(run_intake "$ND")"; N_SUT="$SCRIPT"
check "N: a malformed config does not stop the cycle" "0|0" "$RC_C|$RC_D"
check "N: the SHIPPED runner refuses it, on the timer" "yes" \
      "$(contains "$(cat "$NC/intake.log")" "provisioning config REFUSED: ")"
check "N: ...naming the unknown key"                 "yes" \
      "$(contains "$(cat "$NC/intake.log")" "unknown key 'nonsense-key'")"
check "N: ...and saying no dispatch may proceed"     "yes" \
      "$(contains "$(cat "$NC/intake.log")" "no dispatch may proceed")"
check "N: ...while drafting is explicitly unaffected" "yes" \
      "$(contains "$(cat "$NC/intake.log")" "drafting is unaffected")"
check "N: NEGATIVE CONTROL — the pre-item-2b runner is blind to it" "0" \
      "$(normalise "$ND" < "$ND/intake.log" | grep -ci provision | tr -d ' ')"
# A valid config is reported as a count, not as a silence.
NE="$(nkcase N-good)"
printf '[o/r]\nsmoke = true\n' > "$NE/provisioning"; chmod 600 "$NE/provisioning"
RC_E="$(run_intake "$NE")"
check "N: a valid config is acknowledged"            "0"   "$RC_E"
check "N: ...by count of declared sections"          "yes" \
      "$(contains "$(cat "$NE/intake.log")" "provisioning: 1 repo section(s) declared")"
# And no cycle, configured or not, provisions anything: drafting runs no gate.
check "N: no drafting worktree was provisioned"      "no" \
      "$(contains "$(cat "$NE/intake.log")" "copied")"
check "N: no stub call went unanswered"              "0" \
      "$(cat "$NA/calls.log" "$NC/calls.log" "$NE/calls.log" 2>/dev/null | grep -c 'STUB UNANSWERED' | tr -d ' ')"

echo
echo "=== O. MUTANTS: each must break a case that passes on the shipped lib ===="
# A case only proves something if a plausible weakening of the code breaks it.
# Each mutant is a change someone could genuinely make, believing it harmless.
mutant_fn() { # $1 = out, $2 = function name, $3 = injected line
  awk -v fn="$2() {" -v inj="$3" 'index($0, fn) == 1 { print; print "  " inj; next } { print }' \
      "$LIB" > "$1"
}
MUT_RESULT() { # $1 = label, $2 = mutant lib, $3 = snippet returning the observation
  LIB_UNDER_TEST="$2"; MR="$(eval "$3")"; LIB_UNDER_TEST="$LIB"; printf '%s' "$MR"
}

# O1 — the smoke check made advisory. The single most tempting weakening: "the
# gate will tell us anyway". It would restore exactly the measured failure.
O1="$SANDBOX/mutant-advisory-smoke.sh"; sandboxed "$O1"
mutant_fn "$O1" provision_smoke_check "return 0"
O1_WT="$(mkwt "$J_REPO" o1)"
check "O1: an advisory smoke check would pass a broken worktree" "0" \
      "$(MUT_RESULT o1 "$O1" 'pv "$J_CFG" --preflight "$O1_WT" --repo "$J_REPO"; printf "%s" "$PV_RC"')"
check "O1: ...where the shipped library refuses it"  "1" \
      "$(pv "$J_CFG" --preflight "$(mkwt "$J_REPO" o1b)" --repo "$J_REPO"; printf '%s' "$PV_RC")"

# O2 — an undeclared gate type falls through instead of refusing. This is the
# "surely running the repo's usual gate is better than nothing" instinct, and it
# is the defect: the usual gate covered none of the item.
O2="$SANDBOX/mutant-gate-fallback.sh"; sandboxed "$O2"
awk 'seen && $0 ~ /^      return 1$/ { print "      return 0"; seen = 0; next }
     /no gate set named/ { seen = 1 } { print }' "$LIB" > "$O2"
check "O2: a falling-through gate lookup would accept 'tsx'" "0" \
      "$(MUT_RESULT o2 "$O2" 'pv "$G_CFG" --gates tsx --repo "$A_REPO"; printf "%s" "$PV_RC"')"
check "O2: ...where the shipped library refuses it"  "1" \
      "$(pv "$G_CFG" --gates tsx --repo "$A_REPO"; printf '%s' "$PV_RC")"

# O3 — the clean-tree check disabled. Silent at the moment it happens, which is
# the whole reason it is a refusal.
O3="$SANDBOX/mutant-no-clean-tree.sh"; sandboxed "$O3"
mutant_fn "$O3" _provision_tree_clean "return 0"
O3_WT="$(mkwt "$L_LEAK" o3)"
check "O3: without the clean-tree check the leak is dispatched" "0" \
      "$(MUT_RESULT o3 "$O3" 'pv "$L_LCFG" --preflight "$O3_WT" --repo "$L_LEAK"; printf "%s" "$PV_RC"')"
check "O3: ...where the shipped library refuses it"  "1" \
      "$(pv "$L_LCFG" --preflight "$(mkwt "$L_LEAK" o3b)" --repo "$L_LEAK"; printf '%s' "$PV_RC")"

# O4 — the source guard disabled, so a world-writable file of shell commands is
# executed. "It is my own machine" is how this one gets written.
O4="$SANDBOX/mutant-no-source-guard.sh"; sandboxed "$O4"
mutant_fn "$O4" _provision_file_trustworthy "return 0"
chmod 646 "$E_CFG"
check "O4: without the source guard a 646 config is trusted" "0" \
      "$(MUT_RESULT o4 "$O4" 'pv "$E_CFG" --check --repo "$A_REPO"; printf "%s" "$PV_RC"')"
check "O4: ...where the shipped library refuses it"  "1" \
      "$(pv "$E_CFG" --check --repo "$A_REPO"; printf '%s' "$PV_RC")"
chmod 600 "$E_CFG"

echo
echo "=== Q. THE INTEGRATION-TEST DECLARATION (epic 21 item 5) =================="
# ONE command, run once per ISSUE — never a `.<type>` family the way gates.* is,
# and never executed by this library itself (session-loop.sh's job, against the
# canonical repo, post-merge — see worktree-provisioning.md).
Q_CFG="$(cfg q "[$A_REPO]" "smoke = true" "integration-test = pnpm run test:e2e")"
check "Q: a declared command is returned"            "pnpm run test:e2e" \
      "$(pvsh "$Q_CFG" "provision_resolve '$A_REPO' ''; provision_integration_test")"
pv "$Q_CFG" --integration-test --repo "$A_REPO"
check "Q: the CLI mode agrees"                       "0"   "$PV_RC"
check "Q: ...and prints the same command"            "pnpm run test:e2e" "$PV_OUT"
check "Q: --check prints it too"                     "yes" \
      "$(contains "$(pv "$Q_CFG" --check --repo "$A_REPO"; printf '%s' "$PV_OUT")" "integration-test  pnpm run test:e2e")"

# Not declared: refused, and the refusal names the section — the same shape
# `provision_gates` already uses for an undeclared type, never a silent "".
Q_NOIT="$(cfg q-noit "[$A_REPO]" "smoke = true" "gates.default = echo gate-ok")"
pv "$Q_NOIT" --integration-test --repo "$A_REPO"
check "Q: no integration-test declared is REFUSED"   "1"   "$PV_RC"
check "Q: ...naming the section"                     "yes" "$(contains "$PV_OUT" "no integration-test command is declared for [$A_REPO]")"
check "Q: ...and prints no command"                  "no"  "$(contains "$PV_OUT" "pnpm")"
# Its declared gates are UNTOUCHED and still answer their own lookup — the
# fallback-to-gates policy belongs to the CALLER (session-loop.sh), not here.
check "Q: gates.* still resolve independently"       "echo gate-ok" \
      "$(pvsh "$Q_NOIT" "provision_resolve '$A_REPO' ''; provision_gates ''")"

# An unconfigured repo: refused the same way as "not declared", not a crash.
pv "$A_NONE" --integration-test --repo "$A_REPO"
check "Q: an unconfigured repo is also REFUSED"      "1"   "$PV_RC"

# The key is parsed, not a `gates.*` collision, and needs `smoke` like every
# other declaring key (case D's own rule, exercised once more for this key).
D_T "integration-test alone, no smoke" "no 'smoke' command" \
    "[o/r]" "integration-test = pnpm run test:e2e"
Q_UNK="$(cfg q-unk "[o/r]" "smoke = true" "integration-tests = x")"
pv "$Q_UNK" --check
check "Q: a near-miss key name is still refused"     "1"   "$PV_RC"
check "Q: ...naming exactly what it does not know"   "yes" \
      "$(contains "$PV_OUT" "unknown key 'integration-tests'")"

echo
echo "=== P. THE SANDBOX HELD ================================================="
check "P: the host repo is byte-for-byte untouched"  "$HOST_BEFORE" "$(host_fingerprint)"
check "P: the live intake config was never created"  "no" \
      "$(yesno test -e "$SANDBOX/home/.config/claude-intake")"

echo
echo "========================================================================="
echo "cases: $CASES   failures: $FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0
