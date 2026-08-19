# Epic: executor attribution and isolation

**Status:** in flight (item 1 of 3)
**Source:** GH #2, GH #3, GH #5
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome
Orchestrated execution becomes safe to cancel and safe to trust. The cancel gate denies
only the executor's tool calls and never the orchestrator's, so a sentinel can always be
cleaned up. The tool log records executor activity only. An item is stamped `terminal`
only by the agent that owns it, so Layer 3 reconciliation cannot be poisoned by an
unrelated stop. And every executor runs in its own git worktree, so an orchestrator commit
can never land on the item branch.

## Grounding
- **Verified (docs):** `PreToolUse` and `PostToolUse` hook input carries `agent_id` and
  `agent_type`, and those fields are **present only when the hook fires inside a subagent
  call**. Absence of `agent_id` therefore *is* the orchestrator signal — no marker
  matching required. `SubagentStop` also carries `agent_id` (independently proven in epic
  01: the lifecycle hook read it correctly on first dispatch).
- **Verified (code):** `cancel-gate.sh` line 31 and `subagent-tool-logger.sh` line 19 both
  detect a subagent purely by `ls .claude/signals/subagent-active-*`, with no per-call
  attribution. `cancel-gate.sh` line 26 currently discards the hook input JSON unread.
- **Verified (code):** `subagent-lifecycle.sh` resolves `STATUS_JSON` from the current
  branch slug and stamps `terminal:true` with no check that the stopping agent owns it.
- **Verified (docs defect):** `executor-control-plane.md` Layer 2 asserts "The orchestrator
  itself is never gated (the gate only fires while a subagent marker is armed)". That
  claim is false and must change with the code.
- **Verified (code):** `SKILL.md` line 66 mandates a worktree only "When work items will
  run in parallel"; line 79 step 2 makes the worktree a parenthetical "(In parallel mode:
  …)". Phase 5 line 142 and step 10 already handle worktree cleanup.
- **Verified (state):** all seven installed hooks are byte-identical to the repo copies.
- **ANSWERED, and worse than assumed (verified live during item 1's dispatch):** the hooks
  resolve the **orchestrator's checkout**, never the executor's worktree. Evidence: with the
  executor working in
  `../claude-skills-fix-executor-attribution-worktree-isolation`, the lifecycle hook wrote
  `docs/epics/02-executor-attribution/status/main.log` in the MAIN checkout, with the bracket
  reading `── SUBAGENT START (a71a4bb…) on branch main ──`; the marker landed in the main
  checkout's `.claude/signals/`; the worktree's `.claude/signals/` was never touched.
  Two consequences:
  1. **Branch-scoped cancellation is dead in worktree mode.** A sentinel naming an executor's
     branch never matches, because the gate compares against the orchestrator's branch. Worse,
     a sentinel naming the orchestrator's branch would match *every* executor at once — the
     precise opposite of granular.
  2. **Per-item status collides.** Every executor writes `<orchestrator-branch>.json/.log`, so
     parallel worktree items overwrite each other's status. Observability breaks in exactly the
     mode item 1 makes the default.
- **Assumed:** the two unexplained `SubagentStop` events seen in epic 01 (`af496cdec8c7d1d96`,
  `a6e1ee0f8c0afd15b`) originate from agents whose `SubagentStart` did not reach the hook.
  Owner-matching makes their origin irrelevant, so the epic does not depend on identifying
  them — but it also does not explain them.

## Invariants
- **Hooks fail open.** Any internal error in a `PreToolUse` hook must allow the tool call.
  A gate that errors closed would brick every session on the machine.
- Cancellation must not regress: an executor under a matching sentinel is still denied.
- The orchestrator is never denied, under any sentinel shape.
- No new dependency: correct with `jq` absent, `python3` absent.
- Runs under bash 3.2.
- All seven hooks stay installable by the existing idempotent `install.sh`.

## Work items

### 1. Worktree isolation for every executor
- **Branch:** `fix/executor-attribution-worktree-isolation`
- **Depends on:** none
- **Scope:** `SKILL.md` Phase 2 (line 66) and Phase 3 step 2 (line 79) — make a worktree
  per executor the default for **every** dispatch, not only parallel ones; Phase 3 step 10
  and Phase 5 already cover teardown and need only wording alignment. Mirror the change in
  `references/executor-control-plane.md` dispatch conventions. Add the rationale: the
  orchestrator keeps writing to the epic folder while the executor owns a branch, so
  concurrency exists at one item, not just at two.
  Also correct epic 01's retro, which claims all three defects share the attribution root
  cause — true of #2 and #5, but #3 is shared mutable state, a different fault.
- **Not in scope:** any hook code; automating worktree creation inside `install.sh`.
- **Definition of done:** no remaining text conditions a worktree on parallelism; a reader
  following Phase 3 step 2 creates a worktree for a single-item dispatch; teardown wording
  matches in Phase 3 step 10 and Phase 5.
- **Verification:** `grep -n 'worktree' SKILL.md references/executor-control-plane.md` and
  read every hit; confirm no "when … parallel" conditioning survives. Dispatch item 2 into
  a worktree as the live proof, and confirm `git worktree list` shows it.
- **Rollback:** revert the merge commit; docs only, no runtime effect.

### 2. Per-call attribution in the cancel gate and tool logger
- **Branch:** `fix/executor-attribution-cancel-gate`
- **Depends on:** item 1 (so it can be dispatched into a worktree)
- **Scope:** `cancel-gate.sh` — read the hook input JSON instead of discarding it; extract
  `agent_id` (jq, python3 fallback, consistent with the other hooks); when `agent_id` is
  absent, exit 0 immediately (orchestrator, never gated). Keep the sentinel semantics
  unchanged for subagent calls. `subagent-tool-logger.sh` — same test, so orchestrator
  calls stop polluting the executor's log. Update the false Layer 2 claim in
  `references/executor-control-plane.md` to describe the real mechanism.
  **Required by the answered question:** branch-scoped matching must stop reading the
  orchestrator's branch. Key the sentinel on `agent_id`, or resolve the calling agent's
  actual working directory — comparing against `CLAUDE_PROJECT_DIR`'s branch is wrong in
  every worktree dispatch.
- **Not in scope:** changing sentinel file locations or the empty-vs-branch-scoped
  semantics; the marker files themselves (still used by the lifecycle hook).
- **Definition of done:**
  - Fixture with `agent_id` present + empty sentinel → exit 2 (denied).
  - Fixture with `agent_id` absent + empty sentinel → exit 0 (allowed).
  - Fixture with `agent_id` present + branch-scoped sentinel matching → exit 2.
  - Fixture with `agent_id` present + branch-scoped sentinel not matching → exit 0.
  - No sentinel, any input → exit 0.
  - Malformed/empty stdin → exit 0 (fail open).
  - `jq` absent → identical results via the python3 path.
  - Tool logger writes nothing for input lacking `agent_id`.
- **Verification:** run `cancel-gate.sh` directly with each fixture JSON on stdin and paste
  the exit codes — **all eight before installing anything**. Then the live test, in this
  order: (a) dispatch a disposable executor, create a **branch-scoped** sentinel naming
  only its branch — safe by construction, since the orchestrator is on a different branch
  even under the old logic — confirm the executor is denied and the orchestrator still
  runs commands; (b) only then repeat with an empty sentinel.
  **Escape hatch if the gate misbehaves and the session is locked:** delete the sentinel
  from a terminal outside Claude Code (`rm docs/epics/*/CANCEL .claude/signals/cancel`).
  This is stated because it is the one failure mode the fix itself cannot recover from.
- **Rollback:** revert the merge commit, re-run `install.sh --user`. Worst case the gate
  reverts to today's over-broad behaviour, which is annoying, not destructive.

### 3. Owner-matched terminal stamping and co-located brackets
- **Branch:** `fix/executor-attribution-lifecycle-owner`
- **Depends on:** item 1
- **Scope:** `subagent-lifecycle.sh` — record the owning `agent_id` into `status.json` at
  `SubagentStart`; at `SubagentStop`, stamp `terminal:true` only when the stopping
  `agent_id` matches the recorded owner. Fix the split bracket pair by resolving the log
  path from the epic plus the owning agent rather than the live branch (or writing the
  `START` bracket to the same file the `STOP` will use). Update Layer 1/Layer 3 wording in
  `references/executor-control-plane.md` where it describes the bracket pair.
  **Required by the answered question:** the status/log path must key on the epic plus the
  item or owning agent, not on the resolved branch — otherwise parallel worktree executors
  all write one file. This subsumes the split-bracket defect: both are branch-derived paths.
- **Not in scope:** identifying where the unexplained stops originate; changing the
  `status.json` milestone vocabulary; the stale-marker sweep.
- **Definition of done:**
  - A `SubagentStop` whose `agent_id` differs from the recorded owner leaves `terminal`
    unset and does not truncate the log bracket.
  - A stop from the true owner stamps `terminal:true` exactly as today.
  - `START` and `STOP` brackets for one agent land in the **same** log file across a
    mid-run branch change.
  - No `status.json` present → still exit 0, no error.
- **Verification:** drive the hook directly with fixture `SubagentStart`/`SubagentStop`
  JSON (matching and mismatching `agent_id`) against a temp epic folder, and paste the
  resulting `status.json` and log for each; then confirm on the epic's own final dispatch
  that exactly one bracket pair appears in one file.
- **Rollback:** revert the merge commit, re-run `install.sh --user`.

## Sequence
1 → 2 → 3, serial. Items 2 and 3 are logically independent and item 1 makes parallel
dispatch safe, but **both edit `references/executor-control-plane.md`**, so running them
concurrently buys a merge conflict in exchange for little wall-clock. Item 1 goes first
because until it lands, every orchestrator commit during a dispatch is at risk of landing
on the item branch — the exact defect #3 describes.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| A broken `PreToolUse` gate denies or errors on every tool call | Low | **Severe — could brick every session on this machine** | Fail-open invariant; all eight fixtures pass *before* `install.sh` runs; `bash -n`; documented out-of-band sentinel removal |
| Live cancel test deadlocks the orchestrator | Low | Session stuck mid-epic | Branch-scoped sentinel first (safe even under old logic), empty sentinel only after; escape hatch documented |
| Fixing attribution regresses cancellation itself | Medium | Kill switch silently stops working | DoD tests denial and allowance in both directions, not just allowance |
| `agent_id` semantics differ from the documented behaviour | Low | Item 2's premise fails | Fixture tests are the proof; if `agent_id` turns out present for main-session calls, the executor reports `blocked` rather than guessing |
| Doc-only item 1 drifts from hook behaviour | Medium | Docs describe a system that doesn't exist | Items 2 and 3 each update the same reference alongside their code |
| **Item 1 alone makes worktree mode the default while branch-scoped cancel and per-item status are still broken in it** | Certain until item 2+3 land | Granular cancel silently dead; parallel status collides | Interim window is single-user and known; item 1's text notes the limitation; do not run parallel worktree items until item 3 lands |

## Deferred / out of scope
- Add a shell/hook section to `references/stack-gates.md` — carried over from epic 01, now
  with a concrete harness shape (`bash -n`, stdin fixtures, a `gh` test double, jq-less PATH).
- Azure DevOps twin of the backlog query (`az boards`), and `Source: AB#<n>` in the
  correlation grep.
- The timeout grandchild-kill edge in `session-start-context.sh` (needs `set -m` plus
  process-group kill; theoretical for real `gh`).
- Roadmap Tier 2 — unattended intake via CI. Explicitly blocked until this epic lands:
  putting executors on CI while the cancel gate cannot be cleaned up is the worst version
  of #2.
- Explaining the unexplained `SubagentStop` events. Owner-matching makes them harmless;
  understanding them is a separate question.

## Log
- 2026-08-19 — epic drafted from GH #2, #3, #5 after epic 01's first orchestrated run
  surfaced all three. Phase 0 confirmed via Claude Code hook documentation that
  `PreToolUse`/`PostToolUse` carry `agent_id` only inside subagent calls, which is what
  makes item 2 a small fix rather than a redesign.
- 2026-08-19 — item 1 dispatched into a git worktree, ahead of its own documentation
  change, because the #3 hazard is live today. Its dispatch doubles as the experiment for
  the worktree branch-resolution open question above.
- 2026-08-19 — worktree branch-resolution question ANSWERED by item 1's own dispatch: hooks
  follow the orchestrator's checkout. Items 2 and 3 gained required scope as a result, and
  the finding was added to GH #5. Orchestrator committed this amendment to `main` while the
  executor worked in its worktree — which is item 1's premise, validated live.
