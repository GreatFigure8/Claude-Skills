# Session Handoff — epic 10 (declared paths) / items 2 and 3

**Written:** 2026-08-26T14:45:52Z
**Epic:** docs/epics/10-declared-paths
**Branch:** main (pushed: yes)
**Last commit:** 0a3afd2 chore(epic-10): items 2 and 3 pr-opened, awaiting review
**Worktree:** main checkout

## Verified this session
- Epic 10 item 1 (docs/declared-paths-field) was already done/merged (18d0380) before this session — confirmed via plan.md header at session start.
- Item 2 and item 3 are independent per plan.md's explicit "Depends on" lines (both depend only on item 1) and touch disjoint files — dispatched in parallel, each in its own worktree.
- Item 2 (`feat/intake-declare-touched-paths`) executor returned `pr-opened` → PR #74, confirmed cold via `gh pr view 74`: OPEN, base=main, head=feat/intake-declare-touched-paths, MERGEABLE.
- Item 3 (`feat/declared-paths-gate`) executor returned `pr-opened` → PR #72, confirmed cold via `gh pr view 72`: OPEN, base=main, head=feat/declared-paths-gate, MERGEABLE.
- Item 2's new fixture harness (`intake-touches-fixtures.sh`): 21 cases, 0 failures (executor's report). Two pre-existing, unrelated failures were reproduced on unmodified main too: `intake-outcomes-fixtures.sh` (35/96 failing) and `session-start-fixtures.sh` (2/144 failing, already tracked as open issue #54) — not introduced by this branch.
- Item 3's new fixture harness (`declared-paths-gate-fixtures.sh`): 16 cases, 0 failures, including a negative control (executor's report).
- PR #73 (`fix/superseded-status-treated-as-awaiting-approval`), unrelated to this session's dispatch, merged to main externally during this session — main advanced from 4b71919 to ef6cd8e underneath us. Not something this session authored.
- Both dispatch worktrees pre-created by the orchestrator (`../claude-skills-intake-declare-touched-paths`, `../claude-skills-declared-paths-gate`) went unused — the Agent tool's own `isolation: "worktree"` created separate harness worktrees under `.claude/worktrees/agent-<id>/` on SDK-generated branch names instead. Both executors worked around it by pushing to the correct branch name on origin via explicit refspec (`git push origin HEAD:refs/heads/<branch>`). PRs are correct. The two orphaned pre-created worktrees and the two harness agent-worktrees were all removed this session (`git worktree remove --force` + `prune`), verified via `git worktree list` showing only the main checkout afterward.
- Added `.claude/worktrees/` to `.gitignore` (commit 15bded9) since the harness leaves that directory behind and it was showing as untracked.

## Claimed but NOT yet verified
- Neither PR #74 nor #72 has been reviewed/approved by Jonathan yet — nothing has been merged. Phase 4 verification here was cold-checked PR state (open/mergeable/correct base-head) and the executors' self-reported test/gate output; the diffs themselves have not been read line-by-line by this session.
- Item 2's residual risk, stated explicitly by its own executor: whether a live (non-stubbed) drafter model actually complies with the new `**Touches:**` prompt instruction — only a real drafting cycle would confirm this, and none was run (the executor judged running one against the live `~/.config/claude-intake/` config, which has a `STOP` sentinel present, too risky to do unprompted).
- If the next session dispatches with `isolation: "worktree"` again, expect the same orchestrator-pre-created-worktree-goes-unused pattern for item 4 — consider either not pre-creating a worktree when using Agent's own `isolation: "worktree"`, or dropping that isolation flag in favor of the manually-created worktree.

## Exact next action
- Jonathan reviews and merges PR #74 (item 2) and PR #72 (item 3) at his own pace — independent PRs, no ordering requirement between them.
- Once merged, land-and-reset both (Phase 3 step 10: pull main, delete branches remote+local, clean status/ entries), then re-check whether epic 09 item 4 has landed — epic 10 item 4 ("Collision detection reads the field") depends on item 1 (done) **and** on epic 09 item 4 having landed, which was not checked this session.
- Clear `.claude/signals/active-epic` only at epic close (Phase 5), not before — it still correctly points at `10-declared-paths`.

## Environment state
- `.claude/signals/active-epic` = `10-declared-paths`.
- No running services, no applied-but-unmerged migrations, no env vars set this session.
- `git worktree list` shows only the main checkout — all item and harness worktrees from this session were cleaned up.

## Open questions for Jonathan
- Should epic 10 item 4 wait for both PR #74 and PR #72 to merge (the plan's Sequence diagram implies `1 → (2 ∥ 3) → 4`), or does its explicit "Depends on: 1, and epic 09 item 4" line take precedence and it can start once epic 09 item 4 lands, in parallel with 2/3 still under review?
- Any preference on avoiding the pre-created-worktree-goes-unused pattern for future parallel dispatches (see Claimed-but-not-verified above)?
