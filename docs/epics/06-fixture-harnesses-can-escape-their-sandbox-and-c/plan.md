# Epic: fixture harnesses can escape their sandbox and commit the working tree

**Status:** planning
**Source:** GH #15
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
All four fixture harnesses under `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/`
refuse to run any mutating command (`git init`/`add`/`commit`/`worktree`, `rm`, `mv`, a
destructive `mkdir -p`) against a path that isn't verified to live under the harness's own
`mktemp` sandbox — the same guard `session-start-fixtures.sh` already has — so a variable
collision can never again make a harness commit to, or delete from, the developer's real working
tree. `references/stack-gates.md` gains the still-missing shell/hook gate section documenting the
guard requirement and the `bash -n`-is-not-sufficient finding that motivated it.

## Grounding
- **Verified (code):** `session-start-fixtures.sh` (lines 44-71) canonicalizes its sandbox with
  `SANDBOX="$(cd "$SANDBOX" && pwd -P)"` and defines a `sandboxed()` function — abort with `exit 2`
  and a stderr message unless the given path is under `"$SANDBOX"/*` — called as the first
  statement in every function that touches a path destructively (`plan_file`, `mkrepo`,
  `commit_all`, `run_hook`, and the `UNSPLIT_HOOK` write).
- **Verified (code):** `cancel-gate-fixtures.sh`, `lifecycle-fixtures.sh`, and
  `active-epic-fixtures.sh` have no such guard. Each has one or more functions that run
  `git -C "$1" ...`, `rm -rf "$1"`, `mv`, or `mkdir -p` on a caller-supplied path with no
  verification it is non-empty or under the harness's own sandbox:
  - `cancel-gate-fixtures.sh`: `mkrepo()`, `sentinel_reset()`, `logger_case()` (`rm -rf
    "$LOGREPO"`), plus a bare `git_q -C "$ORCH" worktree add ...` at top level.
  - `lifecycle-fixtures.sh`: `mkorch()` (`rm -rf "$1"`, git init/add/commit, worktree add),
    `exec_status()` (resolves the canonical repo root from the caller's cwd via
    `git rev-parse --path-format=absolute --git-common-dir`, then `mv`s into it — the exact shape
    of function where the original bug occurred).
  - `active-epic-fixtures.sh`: `mkrepo()` (`rm -rf "$1"`, git init/add/commit, worktree add,
    `touch`).
- **Verified (issue text, GH #15):** the root cause was a variable collision while
  `session-start-fixtures.sh` was being written — a loop label `R` was reused for the repo-path
  variable also named `R`, producing `git -C "" add -A`. Git treats an empty `-C` as "stay here,"
  so the harness committed the executor's own worktree, creating a stray `fixture` commit and a
  `PASS/` directory. The executor recovered on its own branch (reset to `origin/main` plus one
  clean commit, `PASS/` deleted, force-pushed with lease); `main` and the main checkout were
  independently verified unaffected at `42138c5`.
- **Verified (docs):** `docs/epics/04-epic-queue/plan.md`'s Deferred section already named this
  exact gap when `session-start-fixtures.sh`'s guard was added: *"Harness sandbox guard (filed
  separately): item 2's harness hit a variable collision that produced `git -C "" add -A` ... The
  new harness now aborts on any path outside its `mktemp` sandbox; the three older harnesses do
  not."* GH #15 is that filed follow-on.
- **Verified (docs):** `references/stack-gates.md` has sections for Python/FastAPI, uv
  workspace, migrations, MCP tool contracts, Next.js, OCI, Auth, and Supabase — no shell/hook
  section exists yet, matching the issue's "Related" note.
- **Verified (repo):** no `.github/` directory exists — no CI workflow invokes these harnesses.
  They run manually or as part of an executor's own verification step, so this fix has no CI
  coupling to account for.
- **Verified (repo):** `.gitignore` already carries the three dev-epic-workflow runtime-state
  lines (`.claude/signals/`, `docs/epics/*/status/`, `docs/epics/*/CANCEL`) from prior epics — no
  action needed here.
- **Verified (repo):** `docs/epics/` holds `01`-`05`, all filed; `06` is the next free number and
  matches this intake branch's folder name. Origin remote is
  `https://github.com/GreatFigure8/Claude-Skills.git`, confirming `gh` as the tracker.
  Local `bash --version` is 3.2.57 (macOS default), matching the bash-3.2 compatibility target
  the other three harnesses already test against.
- **Verified (code):** grepped every `.sh` under `Skills/` for constructed `git -C "$...` calls.
  Only the four test harnesses and `hooks/statusline.sh` matched; `statusline.sh`'s call
  (`git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current`) is read-only and defaults to `.` on
  an empty/unset variable rather than resolving to an empty `-C`, so it does not share this risk
  and stays out of scope.

## Open questions
- Whether any script *outside* `hooks/tests/` and outside `Skills/` constructs a mutating git/rm
  path from a similarly collidable variable was not exhaustively checked (grounding covered
  `Skills/` only, since that's what the issue and repo both scope this to). If a future session
  finds one, it's a new issue, not silently folded into this epic.
- The guard's exact behavior (abort with `exit 2` plus a stderr message, matching
  `session-start-fixtures.sh`'s `sandboxed()`) is assumed to be the intended shape since the issue
  doesn't mandate a specific exit code or message — this plan adopts the existing precedent for
  consistency across all four harnesses rather than inventing a new one.

## Invariants
- Every harness still reports 0 failures on its real (non-mutated) run after the guard lands —
  the guard changes safety, not test semantics or expected outcomes.
- No harness gains a new external dependency (`jq`/`python3` stay optional; bash 3.2 stays the
  floor).
- The guard never fires on any of the harnesses' own legitimate sandbox paths — a false-positive
  abort would break the harness itself, not just fail to catch a real bug.
- No production hook code (`hooks/*.sh` outside `hooks/tests/`) changes — scope is limited to the
  four test harnesses and the `stack-gates.md` reference doc.

## Work items

### 1. Add the sandbox-escape guard to the three unguarded harnesses
- **Branch:** `fix/fixture-harness-sandbox-guard`
- **Depends on:** none
- **Scope:** `cancel-gate-fixtures.sh`, `lifecycle-fixtures.sh`, `active-epic-fixtures.sh` — port
  `session-start-fixtures.sh`'s pattern: canonicalize `$SANDBOX` with `pwd -P` at creation, define
  the same `sandboxed()` function (abort loudly, non-zero exit, unless the path is under
  `"$SANDBOX"/*`), and call it as the first statement of every function identified in Grounding
  that performs a mutating filesystem/git operation on a constructed path (`mkrepo`/`mkorch`,
  `exec_status`, `sentinel_reset`, `logger_case`'s `rm -rf`, and the bare top-level `worktree add`
  / `mkdir -p` / `rm -rf` calls on constructed paths).
- **Not in scope:** `session-start-fixtures.sh` itself (already guarded); production hook scripts;
  guarding the harnesses' hardcoded fixture-JSON writes (e.g. `$FX/*.json` in
  `cancel-gate-fixtures.sh`) — those are string literals, not variables that can collide, so they
  don't carry the risk this item closes.
- **Definition of done:**
  - All three harnesses define the same `sandboxed()` shape as `session-start-fixtures.sh`
    (canonical `$SANDBOX`, path-prefix check, loud abort, non-zero exit).
  - Every function named in Grounding calls `sandboxed` on its path argument before any mutating
    operation on it.
  - A mutation check per harness — reproducing the original bug shape (e.g. blanking the
    repo-path variable passed into a `git_q -C` call) in a scratch copy — shows the harness now
    aborts loudly instead of operating outside the sandbox, the same proof technique
    `session-start-fixtures.sh`'s header already documents.
  - All three harnesses still pass with 0 failures on the unmodified (non-mutated) code.
  - `bash -n` clean on all three files — and, per the issue's own noted gap, at least one case
    exercised at runtime rather than trusted from `bash -n` alone, since a `case` pattern's `)`
    inside `$( )` parses clean on bash 3.2 and fails only when actually run.
- **Verification:** run each of the three harnesses directly and confirm `cases: N failures: 0`;
  run each mutation-check scratch copy and confirm it aborts with the sandbox-guard message and a
  non-zero exit instead of running to completion; `bash -n` all three files.
- **Rollback:** revert the merge commit — the harnesses return to their current (unguarded but
  currently-passing) state.

### 2. Document the shell/hook gate in stack-gates.md
- **Branch:** `docs/stack-gates-shell-hooks`
- **Depends on:** item 1 (documents the guard pattern item 1 ships)
- **Scope:** `references/stack-gates.md` — add a "Shell scripts / Claude Code hooks" section
  covering: run `bash -n` over every changed hook/fixture, and treat it as necessary but not
  sufficient (the `case` pattern `)`-inside-`$( )` runtime-only failure mode from GH #15, found
  while building `session-start-fixtures.sh`); every fixture harness that constructs a mutating
  path from a variable must guard it against operating outside its own `mktemp` sandbox (the
  `sandboxed()` pattern); run all four harnesses under `hooks/tests/` and require 0 failures
  before a hook- or fixture-touching PR.
- **Not in scope:** rewriting or restructuring the other seven `stack-gates.md` sections; adding a
  fifth harness or new test coverage beyond what item 1 ships; the shared-sourced-helper refactor
  (parked in Deferred).
- **Definition of done:** `stack-gates.md` has a new section reachable the same way the other
  seven are (heading plus a fenced command block where applicable); it names all four harnesses
  by path; `docs/epics/04-epic-queue/plan.md`'s Deferred line about the missing section is
  satisfied by this addition.
- **Verification:** read the rendered section back; grep confirms all four harness filenames
  appear in it.
- **Rollback:** revert the merge commit.

## Sequence
1 → 2. Item 2 documents the guard shape item 1 actually ships, so it follows rather than runs in
parallel — trivial to sequence and avoids the doc describing a guard shape that then changes
during item 1's review.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| The guard's path-prefix check false-positives on a legitimate sandbox path (e.g. an unresolved-symlink form) | Low | A harness that used to pass now aborts, blocking its own verification | Port `session-start-fixtures.sh`'s exact `pwd -P` canonicalization; require a full, un-mutated harness green-run as part of DoD |
| A mutating call site is missed in the port | Medium | The same class of bug survives in an un-audited function | DoD requires a mutation check per harness reproducing the original collision, not just a code read |
| A future (fifth) harness ships without the guard | Medium | Regression of the same class, silently | Out of scope here but named in Deferred — a shared sourced helper would close this permanently |

## Deferred / out of scope
- A shared `hooks/tests/lib/sandbox-guard.sh` sourced by all harnesses instead of copy-pasted per
  file — closes "a future harness forgets it" permanently, but matches a pattern epic 04 already
  chose not to take on for the active-epic resolution block ("a third instance of the
  shared-logic problem"). Worth revisiting if a fifth harness is ever added.
- Auditing scripts outside `Skills/` for the same collidable-path pattern (Open questions, above).
- Any change to production hook scripts (`hooks/*.sh` proper) — this epic is test-harness-only.

## Log
- 2026-08-19 — unattended intake drafted this plan from GH #15, opened via the `claude-intake`
  label. Phase 0 confirmed the gap against all four harness files directly and cross-referenced
  `docs/epics/04-epic-queue/plan.md`'s Deferred section, which named this exact follow-on when it
  shipped `session-start-fixtures.sh`'s guard.
