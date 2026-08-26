# Session Handoff — epic 10 (declared paths) / item 4 PR'd, awaiting merge

**Written:** 2026-08-26T23:20:06Z
**Epic:** docs/epics/10-declared-paths
**Branch:** main (pushed: yes)
**Last commit:** 46bd303 chore(epic-10): item 4 verified and PR'd (#76), awaiting merge
**Worktree:** main checkout

## Verified this session
- Ground-truthed the prior handoff's open items via a cold subagent check (not trusted from the old file): PR #74 (item 2) — confirmed **MERGED** (`mergedAt: 2026-08-26T17:47:21Z`, merge commit `9257d3e`) via `gh pr view 74`. Epic 09 item 4 — confirmed **DONE** (PR #59, merged `57a4239`) by reading epic 09's plan.md directly. So epic 10 item 4's dependency (epic 09 item 4 landed) is satisfied.
- Epic 09 item 5 is still **blocked** — not dispatchable. Epic 11 (`11-l2-autonomous-dispatch`) is **code-complete, all four items merged**, but not closed — outstanding live LODE verifications and no autonomy rung enabled; it has no undispatched work item, so nothing to dispatch there this session.
- Dispatched epic 10 item 4 ("Collision detection reads the field") to a `work-item-executor` subagent (model: Sonnet 5) in its own worktree (`../claude-skills-refactor-collision-detection-reads-declarations`, branch `refactor/collision-detection-reads-declarations`). It implemented the item, opened **PR #76**, and reported `pr-opened`.
- Cold-verified PR #76 myself, independent of the executor's self-report: `gh pr view 76` → `state: OPEN`, 2 files changed (`unattended-intake.sh`, `intake-collision-fixtures.sh`), diffstat matches claimed scope. Confirmed via `git grep` that `normalise_declared_paths` and `DECLARED_PATH_DENY_RE` (the old prose extractor and its denylist) are actually gone from `unattended-intake.sh`, not left dormant. Re-ran `intake-collision-fixtures.sh` myself on the PR branch: **129 cases, 0 failures**, matching the executor's claim exactly.
- Plan header and item 4's line in `docs/epics/10-declared-paths/plan.md` updated to reflect PR #76 open/awaiting merge, committed and pushed (`8f08b3c`, `46bd303`).

## Claimed but NOT yet verified
- **PR #76 itself is not yet reviewed or merged** — that's Jonathan's call, not mine to make autonomously. Once merged, epic 10 is fully done (all 4 items) and ready to close (Phase 5): mark plan `**Status:** closed`, remove `.claude/signals/active-epic`, remove the item's worktree/branch, land-and-reset.
- The executor flagged one pre-existing, out-of-scope issue in PR #76's own gate run: `intake-outcomes-fixtures.sh` shows `96 cases, 35 failures`, verified byte-identical against unmodified `main` (so not a regression from this PR) — but it was not investigated further. Worth a look before or independent of epic close.
- The two known false positives PR #76 was meant to eliminate (`subagent-lifecycle.sh`, `subagent-tool-logger.sh` from PR #26's Scope) and the true collisions (#25↔#50, #26↔#50) were verified against **simulated** Touches blocks in the fixture suite, per the epic's no-retrofit invariant — the live open proposals #25/#26/#50 still carry no Touches field and were confirmed to land on `colliding-unknown` as-is. This is correct per plan, not a gap, but worth knowing before assuming the collision check does anything differently for those three PRs today.

## Exact next action
- Review and merge PR #76 whenever ready. On merge: land-and-reset (switch to main, pull, delete branch remote+local, remove the worktree at `../claude-skills-refactor-collision-detection-reads-declarations`, `git worktree prune`, clean `docs/epics/10-declared-paths/status/` entries for this item), then close epic 10 (Phase 5): status → `closed`, remove `.claude/signals/active-epic`, retro line in the plan's Log.
- After epic 10 closes, epic 09 (item 5 blocked) and epic 11 (code-complete, awaiting live verification + close) are the only epics with open threads — neither has a dispatchable work item right now; both need Jonathan's input (see Open questions).

## Environment state
- `.claude/signals/active-epic` = `10-declared-paths`.
- `git worktree list` shows the main checkout plus one active worktree: `../claude-skills-refactor-collision-detection-reads-declarations` (branch `refactor/collision-detection-reads-declarations`, PR #76 open) — do not remove until PR #76 merges.
- Untracked file `Skills/oic-iar-integration-review.skill` (74,881-byte zip) sits at repo root, present since before this session, never committed, no `.gitignore` rule or repo precedent for `.skill` files, no sibling source directory found for it. Left untouched — not part of any dispatched work item. Flagged for Jonathan below.
- No running services, no applied-but-unmerged migrations.

## Open questions for Jonathan
- **`Skills/oic-iar-integration-review.skill`** (untracked, 74KB zip at repo root) — is this something to commit, or a stray build artifact to delete? Not acted on since it's unrelated to any epic in flight.
- Carried forward, unanswered from prior handoffs: do you want L2 enabled once epic 11's live verifications pass; should the `- **Branch:** n/a` convention be filed as its own issue; re-measure epic 09 item 5 or close it on "not measured"; should the ~59 leftover ad-hoc agent logs in `docs/epics/10-declared-paths/status/` be hand-sorted before epic close or left to Phase 5's bulk removal.
- Worth a look independent of epic 10: `intake-outcomes-fixtures.sh`'s pre-existing 35/96 failures (confirmed not caused by PR #76, root cause not investigated).
