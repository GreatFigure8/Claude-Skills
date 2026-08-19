# Epic: resolve branch-name cancel selectors via status ownership under worktree dispatch

**Status:** planning
**Source:** GH #12
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome

Writing a work item's branch name into a `CANCEL` sentinel cancels that item's executor,
even under worktree dispatch — the mode that is now the default for every dispatch
(epic 02). Today `cancel-gate.sh` only resolves a branch selector via `LEGACY_BRANCH`,
which is set solely when `git worktree list` reports a single checkout, so under worktree
dispatch a branch selector is silently inert and granular cancellation requires digging an
agent id out of `.claude/signals/subagent-active-*` or a `SUBAGENT START` bracket. After
this epic, the gate additionally resolves a branch selector by scanning the relevant
epic's `status/*.json` files for the one whose `"branch"` field matches and whose
`"agent_id"` is bound, and denies only the executor that owns it — matching the exact
mechanism the issue's own "Sketch" section proposed.

## Grounding

- **Verified — the defect, exactly as described.** `cancel-gate.sh` (139 lines, read in
  full) matches a selector against an exact agent id, an 8+ char agent-id prefix, or
  `LEGACY_BRANCH` — set only when `git worktree list | wc -l` is `1`. Under worktree
  dispatch (the default since epic 02) that condition is never true, so the `case "$LINE"
  in "$LEGACY_BRANCH")` branch selector check at line 130 never fires for any real
  dispatch. Confirmed against `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh`
  line 202, whose case name says it outright: `"worktree mode: item branch name (ignored
  by design)"`, asserting exit `0` (allowed) where a cancel is intended.
- **Verified — ownership binding already exists and is exactly what the fix needs.**
  `subagent-lifecycle.sh` (`SubagentStop`) and `subagent-tool-logger.sh` (`PostToolUse`)
  already bind a `status/<branch-slug>.json` file to the agent that wrote it: the first
  subagent tool call naming that file in its own `tool_input` gets `"agent_id"` written
  into the JSON (`subagent-tool-logger.sh` lines 202–249); failing that, `SubagentStop`
  claims an unowned file modified during its life only when it was the sole live
  executor. `work-item-executor.md` (lines 21–51) confirms the schema the executor itself
  writes: `{item, branch, state, detail, commit, updated}`, with `agent_id` and
  `terminal` added only by the hooks. So a bound `status.json` already carries both
  `branch` and `agent_id`, greppable without `jq`, exactly as the issue's "Why it is now
  feasible" section claims.
- **Verified — the shared active-epic-resolution block is an established, deliberate
  pattern, not a shortcut to avoid.** `subagent-lifecycle.sh` and `subagent-tool-logger.sh`
  each carry a byte-identical copy of the same ~90-line block (between `BEGIN/END
  active-epic resolution` markers), asserted identical by
  `hooks/tests/active-epic-fixtures.sh` section H (`cmp -s "$BLOCK_A" "$BLOCK_B"`). Each
  hook script is a fully standalone `bash` file with no sourced dependencies (a
  reliability property, not an oversight) — epic 02's retro records "the `agent_id`
  extraction block now exists in three copies" as accepted, non-blocking debt. Adding a
  fourth verbatim copy to `cancel-gate.sh` (needed only for the *global*
  `.claude/signals/cancel` sentinel, where the epic isn't already implied by the sentinel's
  own path) continues that pattern rather than breaking it.
- **Verified — the scoped sentinel needs no epic resolution at all.** A sentinel matched
  from `docs/epics/<NN>-<slug>/CANCEL` already names its epic via `dirname`; only the
  global `.claude/signals/cancel` sentinel is epic-agnostic and needs the active-epic
  pointer/fallback to know which `status/` tree to scan.
- **Verified — three-tier parser invariant.** All three hooks maintain "correct with `jq`,
  correct with only `python3`, correct with neither" (`cancel-gate.sh` header, line 39;
  proven by `hooks/tests/cancel-gate-fixtures.sh`'s `full`/`nojq`/`bare` `PATH` variants).
  Any new JSON field extraction in `cancel-gate.sh` must hold the same invariant.
- **Verified — `.gitignore` already covers this epic's runtime state.** `docs/epics/*/status/`
  and `docs/epics/*/CANCEL` are glob patterns already in the repo's `.gitignore`; no change
  needed for this proposal's own folder.
- **Verified — issue and prior-PR history.** GH #12's body supplies the "Sketch" this plan
  follows almost verbatim (scan `status/*.json` for a `branch` match with a bound
  `agent_id`; ambiguity or no bound owner → no match, never guess; orchestrator never
  denied; lookup only runs when a sentinel exists and no cheaper selector matched; fail
  open on unreadable/malformed status files). A prior unattended-intake run had already
  opened PR #21 for this same issue under the epic-number-reservation scheme that epic 06
  (`fix(intake): drop epic-number reservation`, commit `a6f8aa1`) replaced; PR #21 is
  closed (it claimed epic number `06`, which collided with the epic actually filed there).
  This proposal uses the corrected `proposed-<issue>-<slug>` naming and supersedes it.
- **Verified — no CI in this repo.** No `.github/workflows/`; verification for
  control-plane hook changes is the three fixture harnesses run by hand, per
  `references/executor-control-plane.md`'s own instruction to run all three "before
  `install.sh` puts the change live."
- **Assumed — global-sentinel scope is "the active epic," not "every epic."** The issue's
  sketch says "scan the active epic's `status/*.json`," matching the existing
  active-epic-resolution semantics used everywhere else in the control plane. An
  alternative (scan every epic's `status/` tree for the global sentinel) was considered and
  rejected for this plan: it would require no new shared block, but it also means a branch
  name colliding across two unrelated epics could resolve ambiguously in a way the
  single-epic design does not need to reason about, and it would depart from how every
  other piece of this control plane decides "which epic." Not verified against Jonathan
  directly (this is an unattended run); flagged here as a design decision made from the
  issue text rather than a silent assumption.
- **Assumed — no live-install/performance testing done.** The lookup only runs when a
  sentinel is armed and no cheaper selector matched, and `status/` directories in this
  workflow hold at most a handful of files (one per concurrently-dispatched work item), so
  added `PreToolUse` latency is assumed negligible. Not measured.

## Invariants

- The orchestrator is never denied under any sentinel shape. (Structurally already true —
  a `PreToolUse` call with no `agent_id` in its payload exits allow before any sentinel or
  selector logic runs; this epic must not disturb that fast path, only extend what happens
  after it.)
- Fail-open holds for every new code path: missing `status/` directory, unreadable or
  malformed `status.json`, a status file missing a `branch` or `agent_id` field — all
  resolve to "no match," never to an error or a wrongful deny.
- Ambiguous resolution never guesses: more than one `status/*.json` claiming the same
  branch, or a matching file with no bound `agent_id`, resolves to "no match."
- No regression in any existing `cancel-gate-fixtures.sh`, `lifecycle-fixtures.sh`, or
  `active-epic-fixtures.sh` case whose expectation this epic does not deliberately change.
- No hook installation happens as part of this epic's work items — `install.sh` is a
  separate, deliberate step Jonathan (or the orchestrator, post-verification) runs after
  merge, per epic 02's own precedent ("the agent which could brick the machine should not
  be the one to pull the trigger").

## Work items

### 1. Resolve branch selectors via status-file ownership in the cancel gate

- **Branch:** `fix/cancel-gate-branch-selector-resolution`
- **Depends on:** none
- **Scope:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/cancel-gate.sh` — for a selector
    line that matches neither an agent-id form nor `LEGACY_BRANCH`, resolve the owning
    epic's `status/` directory (scoped sentinel: `dirname` of the matched `CANCEL` file;
    global sentinel: add the shared active-epic-resolution block, matching
    `subagent-lifecycle.sh`/`subagent-tool-logger.sh` byte-for-byte between their
    `BEGIN/END active-epic resolution` markers), scan its `status/*.json` files (not
    `status/.agents/*.json`) for one whose `"branch"` equals the selector and whose
    `"agent_id"` is present and unambiguous, and deny only when that `agent_id` equals the
    caller's. Support all three parser tiers (`jq`, `python3`, grep/sed), matching the
    file's existing extraction pattern. Update the file's header comment (currently states
    branch selectors work "ONLY in direct (single-checkout) dispatch") to describe the new
    resolved behavior alongside the still-true `LEGACY_BRANCH` case.
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh` —
    flip the existing "worktree mode: item branch name (ignored by design)" case (line 202)
    to its new expectation (a bound status file with a matching branch now denies the
    owning agent), and rename it to reflect the new behavior. Add cases for: a status file
    bound to a *different* agent (allow); two status files claiming the same branch
    (ambiguous — allow); a matching branch with no bound `agent_id` (allow); no `status/`
    directory present at all (allow, fail open); the global `.claude/signals/cancel`
    sentinel resolving a branch selector via the active-epic pointer (deny the owner); and
    an explicit regression case confirming an orchestrator call (no `agent_id` in the
    hook payload) is never denied by this path.
- **Not in scope:** the empty/global cancel-all semantics; agent-id exact/prefix matching;
  `LEGACY_BRANCH` (direct-dispatch) behavior, which stays as-is; `status.json`'s schema or
  who writes it; any change to `subagent-lifecycle.sh` or `subagent-tool-logger.sh`
  themselves (this item only reads what they already write); running `install.sh`.
- **Definition of done:** a `CANCEL` sentinel (scoped or global) containing only a branch
  name denies the executor whose bound `status.json` carries that branch, under worktree
  dispatch, and denies no one when the match is ambiguous or unbound; `bash
  Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh` passes
  with zero failures across all three `full`/`nojq`/`bare` variants.
- **Verification:** `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/cancel-gate-fixtures.sh`
  exits 0 with `failures: 0`; `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/lifecycle-fixtures.sh`
  still exits 0 with `failures: 0` (no regression, since this item does not touch that
  hook); `git diff --stat` touches only the two files above.
- **Rollback:** revert the merge commit. Pure shell, no schema or migration, and the hook
  is not installed as part of this item, so a bad revert has zero live-machine impact
  until someone deliberately re-runs `install.sh`.

### 2. Extend the cross-hook consistency guard to the gate's new resolution block

- **Branch:** `fix/cancel-gate-active-epic-consistency`
- **Depends on:** item 1 (the block it checks does not exist until item 1 lands)
- **Scope:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh` —
    extend section H ("the two hooks agree") from a pairwise `cmp` between
    `subagent-lifecycle.sh` and `subagent-tool-logger.sh` to a three-way check that also
    extracts and compares the `BEGIN/END active-epic resolution` block now present in
    `cancel-gate.sh`, so drift in any of the three is caught the same way drift between the
    original two already is. Also extend the "no `ls -t` anywhere outside the shared
    block" check (lines 328–338) to `cancel-gate.sh`.
  - `Skills/dev-epic-workflow/references/executor-control-plane.md` — update the "Residual
    limitation" paragraph (currently: "A branch-name selector in a cancel sentinel is still
    a no-op under worktree dispatch... restoring branch-selector granularity on top of it is
    a recorded follow-on, not a shipped behaviour") to state the resolved behavior, and add
    the new case to the Layer 2 kill-switch selector list and the failure-modes table if a
    row is warranted.
- **Not in scope:** any further code change to the hooks themselves; the plan-template or
  issue-intake reference docs, which describe process, not this mechanism.
- **Definition of done:** `active-epic-fixtures.sh` fails loudly if `cancel-gate.sh`'s
  active-epic-resolution block ever drifts from the other two hooks'; the control-plane
  reference doc no longer describes branch selectors as inert under worktree dispatch.
- **Verification:** `bash Skills/dev-epic-workflow/assets/claude-config/hooks/tests/active-epic-fixtures.sh`
  exits 0 with `failures: 0`; `grep -n "no-op under worktree dispatch" Skills/dev-epic-workflow/references/executor-control-plane.md`
  returns nothing (or only the historical mention inside a retro/changelog, not a
  present-tense claim).
- **Rollback:** revert the merge commit. Test-and-doc-only; no runtime behavior change.

## Sequence

1 → 2. Item 2 greps for a block that item 1 introduces, so it cannot start first; nothing
else in this epic is parallel.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| New resolution logic denies the wrong agent (false-positive cancel) | Low | One executor's run cancelled unnecessarily; loss-free since executors push on first commit | Ambiguity and unbound matches resolve to "no match" by design; dedicated fixture cases for both; orchestrator's own fast-path exit is untouched |
| Grep/sed parser-free tier has a subtle bug absent `jq`/`python3` | Low | Silent false negative (selector doesn't resolve) rather than false positive, since fail-open is the default on any extraction failure | Mirrors the already-proven `json_owner`-style pattern from `subagent-lifecycle.sh`; `bare` variant exercised in fixtures |
| `PreToolUse` latency grows for every tool call while any sentinel is armed | Low | Perceptible lag during an active cancel, not steady-state (sentinels are transient) | Lookup only runs after cheaper checks fail and only while a sentinel exists; `status/` trees are small by construction |
| A reviewer "fixes" the fourth copy of the active-epic-resolution block as DRY debt, silently reintroducing a shared-file dependency | Low | Would reintroduce the coupling epic 02 deliberately avoided (every hook stands alone) | Grounding section and item 1's scope note the duplication is intentional; item 2's fixture makes the copies' equality a tested invariant, not tribal knowledge |

## Deferred / out of scope

- Scanning *every* epic's `status/` tree for a global-sentinel branch selector (rejected in
  Grounding in favor of active-epic-only scoping, for consistency with the rest of the
  control plane).
- Any reduction of the three-copy `active-epic-resolution` block duplication into a shared
  file — noted in epic 02's retro as accepted debt; out of scope here and not proposed to
  change.
- Any change to how `install.sh` deploys hook changes to a live machine.

## Log

- 2026-08-19 — proposed by unattended intake from GH #12. `Status: planning` — awaiting
  Jonathan's review and approval (merge the PR and set `Status: approved`). Supersedes the
  closed PR #21, which used the epic-number-reservation scheme dropped by epic 06.
