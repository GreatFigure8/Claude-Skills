---
title: Guard merges into a shared branch with a branch-identity check
slug: assert-branch-before-merge
sprint: 2026-09-11-003
kind: service
created: 2026-09-11T18:05:00Z
---

# Guard merges into a shared branch with a branch-identity check

## Statement
> Add a real, enforced check that the shared checkout is on the branch being merged into
> before any `git merge --no-ff` into an integration or live branch runs, because today
> that's just prose ("From the main checkout, never switching branches") that nothing
> verifies — and it failed in practice.

`dev-story-sprint`'s Step 3 and `dev-story-flow`'s coder (steps 3 and 6) merge an item's
branch into the sprint's integration branch, and eventually the integration branch into
live, always "from the main checkout, never switching branches" — but nothing actually
asserts the checkout is on that branch first. During a live `dev-story-flow` EXECUTE run on
2026-09-11, the shared checkout (`~/Source/claude-skills`, used concurrently by multiple
Claude sessions per this repo's own `CLAUDE.md`) was left on `dev` when the orchestrator ran
`git merge --no-ff origin/feat/list-story-counts-column`. That created the merge commit on
`dev` instead of `sprint/2026-09-11-001`, and it landed on top of an unpushed commit from a
different concurrent session (drafting sprint `2026-09-11-002`). The push failed only by
coincidence (`git push origin sprint/2026-09-11-001` had no matching local branch), which is
what surfaced the mistake before it reached `origin/dev`. Recovery required a `git reset
--hard` back to the concurrent session's last commit and moving the rest of that sprint's
merges into a dedicated `git worktree`.

## Requirements
1. R1 — Before any `git merge --no-ff` into an integration or live branch from the shared
   checkout (item merges, sprint-to-live merges), the tooling checks that the checkout is
   actually on that target branch, and refuses to proceed if not.
2. R2 — A new `sprint-state.sh` subcommand, `assert-branch <sprint> [--target
   integration|live]`, does this check: compares `git branch --show-current` (run in the
   caller's cwd) against the named sprint's `branch.integration` or `branch.live` field, and
   exits non-zero with a message naming both the expected and actual branch if they differ.
   Exits 0 silently if they match.
3. R3 — `dev-story-flow/references/dev-story-coder.md` (steps 3 and 6) and
   `dev-story-sprint/SKILL.md` (Step 3, and its Step 4 sprint-close merge) are updated to run
   `assert-branch` immediately before every merge-into-shared-branch command, so the check is
   a real gate the docs instruct every orchestrator to run, not just advisory prose.
4. R4 — Unit test coverage for `assert-branch`: correct branch → exit 0; wrong branch → exit
   1 with a message naming both the expected and actual branch names.

## Specification
- File: `Skills/dev-story-flow/assets/bin/sprint-state.sh`.
  - Add `cmd_assert_branch(base, args)`: parses `<sprint>` and an optional `--target
    integration|live` (default `integration`). Loads the sprint manifest (reusing the
    existing `load()` helper used by `cmd_get`/`cmd_set`), reads `m["branch"][target]`
    (`target` mapped `integration`→`"integration"`, `live`→`"live"`). Special-case
    `branch.integration == "none"`: in that mode there is no separate integration branch, so
    `--target integration` should compare against `branch.live` instead (the repo's own
    convention when `integration=none`) — die with a clear message if neither field is
    resolvable.
  - Determine the current branch via `subprocess` calling `git rev-parse --abbrev-ref HEAD`
    (matches how the rest of the script shells out to git, e.g. the `new` subcommand's
    branch-naming logic) run in the process's actual `cwd` — the caller is expected to `cd`
    into the checkout/worktree it wants checked before invoking this.
  - On match: print nothing, exit 0. On mismatch: print `assert-branch: expected on '<sprint>'
    <target> branch '<expected>', but currently on '<actual>'` to stderr, exit 1.
  - Register the subcommand in the script's dispatch table (same pattern as `list`, `get`,
    `set`, `story`, `stale`, `new`) and its `--help`/usage text.
- File: `Skills/dev-story-flow/references/sprint-state.md` — add `assert-branch` to the
  helper's command list (section documenting `list`/`get`/`set`/`story`/`stale`/`new`).
- File: `Skills/dev-story-flow/references/dev-story-coder.md`:
  - Step 3 (`## 3. Execute each story using its plan`): immediately before the `git merge
    --no-ff -m "merge(<slug>): item <n> ..." origin/<branch> && git push origin <integration>`
    line, add `sprint-state.sh assert-branch <sprint> || <abort/fix, do not merge>`.
  - Step 6 (`## 6. Mark the sprint complete`): immediately before `git merge --no-ff -m
    "merge(sprint): <sprint> — <k> stories" origin/sprint/<sprint> && git push origin <live>`,
    add `sprint-state.sh assert-branch <sprint> --target live`.
- File: `Skills/dev-story-sprint/SKILL.md`:
  - Step 3 (`## Step 3 — An executor returns: verify cold, merge, reset...`): before the `git
    merge --no-ff -m "merge(<slug>): item <n> <branch> (#<n>)" origin/<branch>` line, add the
    same `assert-branch` call (dev-story-sprint has no sprint manifest, so this applies only
    when it's reused via dev-story-flow — note in prose that a bare dev-story-sprint run
    without a sprint.json skips this check, since `assert-branch` needs a manifest to read
    the expected branch from).
  - Step 4 (`## Step 4 — Story done`): same treatment for the merge-to-live step.
- No new dependencies — `subprocess`/`git rev-parse` only, consistent with the script's
  existing git shell-outs.

## Dependencies, risks, and breaking changes
- No dependency on other stories in this sprint (only story in sprint 2026-09-11-003).
- Purely additive: a new subcommand plus a new line in existing doc procedures. No existing
  subcommand's behavior or output changes.
- Risk: `assert-branch` reads `git branch --show-current` in the **caller's** cwd — if an
  orchestrator runs it from the wrong directory (e.g. a worktree it isn't actually using),
  the check gives a false pass. The fix only closes the gap this incident exposed
  (forgetting to switch/verify at all); it does not make every future git-directory mistake
  impossible.
- Risk: `branch.integration == "none"` repos need the `--target integration` case redirected
  to `branch.live` — get this wrong and the check either always fails or never fires for
  those repos.

## Acceptance criteria
- AC-U: unit tests pass — `bash Skills/dev-story-flow/assets/tests/sprint-state-fixtures.sh`
  exits 0, including new checks for `assert-branch`.
- AC-I: integration — a new or extended
  `Skills/dev-story-flow/assets/tests/sprint-state-list-integration.sh`-style script runs
  `assert-branch` against a throwaway git repo on the correct branch (exit 0) and on a
  different branch (exit 1, message names both branches), and exits 0.
- AC1: on the sprint's integration branch, `sprint-state.sh assert-branch <sprint>` exits 0.
- AC2: on any other branch, `sprint-state.sh assert-branch <sprint>` exits 1 and the stderr
  message names both the expected and the actual branch.
- AC3: `sprint-state.sh assert-branch <sprint> --target live`, run on the sprint's
  `branch.live`, exits 0; run elsewhere, exits 1.
- AC4: for a sprint with `branch.integration == "none"`, `assert-branch <sprint>` (default
  target) checks against `branch.live` instead, and exits 0 there.
- AC5: `dev-story-coder.md` steps 3 and 6, and `dev-story-sprint/SKILL.md` steps 3 and 4,
  each show an `assert-branch` invocation immediately before their respective merge command
  (verifiable by `grep -B2 'git merge --no-ff' <file>` showing `assert-branch` in the two
  lines above each merge line that targets a shared branch).

## Out of scope
- Guarding every git operation in the flow (branch, checkout, push, rebase) — only the
  merge-into-shared-branch moment.
- Automatically fixing a wrong branch (switching, stashing, rebasing) — the check only
  refuses and reports; the orchestrator (human or executor) decides the recovery.
- Any change to how executors pick their own worktree/branch — this is about the
  orchestrator's own checkout at merge time.
- Preventing concurrent sessions from sharing the checkout at all, or building a locking
  mechanism — out of scope; this fix only stops one specific, already-observed failure mode
  (merging into the wrong branch unnoticed).

## Open questions
None — Jonathan confirmed the proposed requirements and acceptance criteria as-is.
