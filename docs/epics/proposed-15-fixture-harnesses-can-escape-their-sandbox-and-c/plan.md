# Epic: fixture harnesses can escape their sandbox and commit the working tree

**Status:** planning
**Source:** GH #15
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
All four fixture harnesses under `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/`
refuse to run any mutating command (`git`, `rm`, `mkdir`, `mv`) against a path that is empty,
not under their own `mktemp` sandbox, or resolves outside it — matching the guard
`session-start-fixtures.sh` already has. The collision that produced that incident (a global
variable named `R` used both as a `check()` verdict and as a repo-path variable) is closed off
in all four scripts, not just one. `references/stack-gates.md` gains the shell/hook section
that has been missing since epic 04, describing the convention and the `bash -n` caveat that
same incident also exposed.

## Grounding
- **Verified:** none of the three older harnesses define or call a `sandboxed()`-style guard —
  `grep -rl sandboxed Skills/dev-epic-workflow/assets/claude-config/hooks/tests/` matches only
  `session-start-fixtures.sh`.
- **Verified:** `session-start-fixtures.sh:65-71` defines `sandboxed()` — a pure-shell `case`
  match against `"$SANDBOX"/*` that `exit 2`s with `ABORT: refusing to operate outside the
  sandbox: [...]` on anything else — and calls it at the top of every function that builds a
  path for a mutating command (`plan_file`, `mkrepo`, `commit_all`, plus the inline
  `UNSPLIT_HOOK` write). It has no external-tool dependency, so it still works under the
  script's `bare` PATH variant (no jq/python3/grep-only fallback path).
- **Verified:** the actual historical fix was two-part, not one. `session-start-fixtures.sh`'s
  `check()` (line 73-77) stores its pass/fail verdict in `VERDICT`, not `R` — a deliberate
  rename away from the collision shape the incident report describes (`check()` clobbering a
  same-named repo-path variable). The three older harnesses did not get this rename:
  `cancel-gate-fixtures.sh:136`, `lifecycle-fixtures.sh:54`, and `active-epic-fixtures.sh:70`
  all still assign the verdict to global `R`.
- **Verified:** `lifecycle-fixtures.sh:87` independently assigns global `R` to a resolved repo
  root inside `exec_status()` — the same variable name, the same unscoped-global shape as the
  incident. It is only safe today because every call site captures the function via
  `SF="$(exec_status ...)"` command substitution, which subshell-isolates the assignment. A
  future edit that called `exec_status` directly (no subshell) would reproduce the incident
  exactly: `check()` running afterward would silently overwrite `$R` with `PASS`/`FAIL`.
- **Verified:** `references/stack-gates.md` (97 lines, read in full) has sections for Python,
  the uv workspace, DB migrations, MCP contracts, Next.js, OCI, auth, and Supabase — no shell,
  bash, or hooks section exists.
- **Verified:** `docs/epics/04-epic-queue/plan.md`'s Deferred section (lines 140-145) is the
  origin of this issue — it names the exact incident and defers both the guard retrofit and the
  `stack-gates.md` gap. `docs/epics/06-runner-conformance/plan.md`'s Deferred section
  (line 81) independently lists "Retrofitting the sandbox guard to the three older harnesses
  (GH #15 — a proposal exists)," confirming this issue has no other in-flight owner.
- **Verified:** no CI workflow or Makefile invokes these harnesses (`.github/workflows/` does
  not exist in this repo; no `Makefile`/`justfile` references `fixtures.sh`). They run only via
  the `Usage:` line documented in each script's header — this epic does not need to touch any
  CI wiring.
- **Assumed:** none of the four harnesses currently has an automated case that proves the guard
  itself fires (the epic-04 incident writeup describes a one-off manual proof — "injecting the
  exact bug into a scratch copy" — not a committed regression case). Left unverified whether
  that's an intentional omission or a gap; treated as a gap here, since a guard with no case
  proving it trips is one silent refactor away from becoming dead code.

## Invariants
- No harness may construct a path for a `git`, `rm`, `mkdir`, or `mv` target without it first
  passing through the `sandboxed()` guard — no exceptions for "this call site looks safe."
- The guard function itself uses no external tool (no `jq`, no `python3`), so it keeps working
  under every PATH variant each harness already exercises (`full` / `nojq` or `bare` / etc.).
- Every existing case's expected output is unchanged — this is hardening plus one new guard-proof
  case per harness, not a rewrite of existing assertions. `cases: N   failures: 0` must hold with
  the same `N` as today, plus the new cases.
- Running any of the four harnesses never touches a real repo, `~/.claude`, or the developer's
  own checkout — that is the property this epic exists to make true everywhere, not just in one
  script.

## Work items

### 1. Retrofit the sandbox-escape guard into the three older harnesses
- **Branch:** `fix/fixture-harnesses-can-escape-their-sandbox-and-c`
- **Depends on:** none
- **Scope:**
  - `hooks/tests/cancel-gate-fixtures.sh`, `hooks/tests/lifecycle-fixtures.sh`,
    `hooks/tests/active-epic-fixtures.sh`: port `session-start-fixtures.sh`'s `sandboxed()`
    function verbatim (or the minimal adaptation each script's helper shapes require), and call
    it at the top of every function that builds a path later used by a mutating command
    (`mkrepo`/`mkorch`, `sentinel_reset`, `exec_status`, `commit_all`-equivalents, and any inline
    `: >`, `printf … >`, `rm -f`, `mkdir -p` against a constructed path).
  - In all three, rename `check()`'s verdict variable from `R` to `VERDICT` (matching
    `session-start-fixtures.sh`), closing the collision class at its root rather than only
    guarding against its one known symptom.
  - Add one new case per harness that deliberately drives a mutating helper with a path outside
    its `$SANDBOX` (pointed at a second, separate throwaway `mktemp` location — never a real
    path) and asserts the script aborts loudly (`exit 2`, `ABORT: refusing to operate outside
    the sandbox` on stderr) instead of silently proceeding.
- **Not in scope:** the `agent_id`-extraction duplication across hooks, the `hooks/lib/`
  shared-source idea, branch-selector cancel semantics, and any change to the hooks under test
  themselves (`cancel-gate.sh`, `subagent-lifecycle.sh`, `subagent-tool-logger.sh`) — all
  pre-existing deferred items, untouched here.
- **Definition of done:**
  - `grep -L 'sandboxed()' Skills/dev-epic-workflow/assets/claude-config/hooks/tests/*.sh`
    returns nothing — all four harnesses define the guard.
  - `grep -n 'R="PASS"\|R="FAIL"' Skills/dev-epic-workflow/assets/claude-config/hooks/tests/*.sh`
    returns nothing — the collision-prone name is gone everywhere it was a verdict variable.
  - Each of the three retrofitted harnesses runs clean end to end with `cases: N   failures: 0`,
    where `N` is today's case count plus the one new guard-proof case.
  - `bash -n` clean on all three edited files.
- **Verification:**
  - `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh`
  - `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/lifecycle-fixtures.sh`
  - `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
  - `git diff --stat main...HEAD` touches only the three test scripts.
  - Manually reproduce the original incident shape once (temporarily blank out a sandbox
    variable before a mutating call in a scratch copy) and confirm the guard aborts rather than
    operating — same style of proof the epic-04 incident used, now cheap to repeat because the
    guard exists.
- **Rollback:** revert the merge commit — the guard is additive; reverting restores today's
  unguarded (but currently non-failing) behavior.

### 2. Document the shell/hook gate in stack-gates.md
- **Branch:** `docs/fixture-harnesses-can-escape-their-sandbox-and-c-stack-gates`
- **Depends on:** item 1 (describes the convention item 1 establishes in all four harnesses)
- **Scope:** add a `## Shell / hooks` section to `references/stack-gates.md` that:
  - Lists the four fixture harnesses and how to run them (the `Usage:` line each already
    documents).
  - States the `sandboxed()` convention as mandatory for any harness that performs mutating
    filesystem/git operations against a constructed path — new harnesses included.
  - Records that `bash -n` is necessary but not sufficient on bash 3.2: a `case` pattern's `)`
    inside `$( )` parses clean and fails only at runtime (the exact defect epic 04 item 2 hit),
    so a clean `bash -n` is not sufficient sign-off on its own — the harness must also be run.
- **Not in scope:** rewriting or reorganizing the rest of `stack-gates.md`; adding a CI workflow
  to run these harnesses automatically (no CI exists in this repo today; out of this epic).
- **Definition of done:** `grep -n '^## ' references/stack-gates.md` shows the new section;
  it names all four harness files by path and includes the `bash -n` caveat in its own words
  (not a verbatim copy of this plan or the issue body).
- **Verification:** read the rendered section back; confirm every harness path it names exists
  (`test -f` each).
- **Rollback:** revert the merge commit — documentation-only change.

## Sequence
1 → 2. Item 2 describes the convention item 1 puts in place; documenting it first would describe
a guard that doesn't exist everywhere yet.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| A legitimate path a harness already uses doesn't resolve as literally under `$SANDBOX` (e.g. `/var` vs `/private/var` symlink resolution on macOS) once the guard is added, turning a passing case into a false FAIL | Medium | Noisy — fixtures report failures on already-correct behavior, not data loss | Mirror `session-start-fixtures.sh`'s existing `pwd -P` canonicalization pattern where a harness already resolves `$SANDBOX` or compares canonical git roots; run each full suite after the edit and diff the before/after case count |
| Renaming `check()`'s `R` to `VERDICT` is a mechanical find-and-replace across many call sites; a missed occurrence silently reintroduces the exact collision this epic closes | Low | Same failure class recurs later, undetected until it happens again | `grep` verification in the Definition of Done targets the literal `R="PASS"`/`R="FAIL"` pattern, not just "did the file change" |
| The new guard-proof case itself constructs an out-of-sandbox path to prove the guard fires, and does so unsafely (pointing at something real) | Low | The regression test meant to prevent the incident could itself cause a smaller version of it | Point the deliberately-bad path at a second, independent `mktemp` directory (never `$HOME`, never the developer's checkout), the same discipline `session-start-fixtures.sh`'s own mutation-check section (case L) already uses for a different kind of negative test |

## Deferred / out of scope
- The `agent_id` extraction block duplicated across three hooks (epic 04's deferred item,
  unrelated to this bug).
- A `hooks/lib/` shared-source mechanism for the ~110-line active-epic-resolution block
  duplicated in two hooks (epic 04's deferred item).
- Multi-epic simultaneity, a `/dispatch` command, branch-selector cancel semantics — all
  pre-existing deferred items from other epics, untouched here.
- Wiring any of these harnesses into CI — no CI exists in this repo today; adding one is a
  separate decision, not implied by fixing the guard.

## Log
- 2026-08-19 — proposed by unattended intake from GH #15. Not yet approved.
