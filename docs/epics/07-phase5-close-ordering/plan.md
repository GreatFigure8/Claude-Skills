# Epic: Phase 5 close-out marks the plan closed before deleting the status tree

**Status:** closed
**Source:** GH #41
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a

## Outcome

`SKILL.md` Phase 5's close-out steps mark the plan header `**Status:** closed` *before* deleting
the epic's `status/` directory, `CANCEL` sentinel, and `.claude/signals/active-epic` pointer — and
say explicitly that `closed` must be live in the **canonical checkout** (merged and pulled, not
merely committed on a branch) before that deletion runs. A subagent that stops mid-close-out can
then never resolve back into the epic being closed and recreate its status tree, which is what
happened live during epic 06's close-out.

## Grounding

- **Verified:** `Skills/dev-epic-workflow/SKILL.md` Phase 5 (lines 154–162) today lists line 157
  — "Temporary scaffolding actually deleted…", which includes the epic's `status/` directory, any
  `CANCEL` sentinel, and the `.claude/signals/active-epic` pointer — *before* line 158, "Mark the
  plan header `**Status:** closed`". This is exactly the ordering the issue describes, still
  present in the repo as of this run.
- **Verified:** `references/executor-control-plane.md` documents the active-epic resolution order
  the hooks actually run: (1) the `active-epic` pointer, when it names a directory whose plan is
  **not** closed; (2) otherwise the newest `plan.md` whose `**Status:**` reads `in flight`; (3)
  otherwise the newest open-but-not-started plan; (4) otherwise nothing. This confirms the issue's
  causal chain precisely: once step 157 has removed the pointer and the `status/` directory, but
  Status still reads `in flight`, any subagent that stops in that window falls through to rule (2)
  — "newest plan marked in flight" — and recreates `status/` to write its `SUBAGENT STOP` bracket.
- **Verified:** `docs/epics/06-runner-conformance/plan.md`'s own Log records this incident live —
  closing epic 06 required removing `status/` twice for exactly this reason. The bug is not
  hypothetical; it already happened against this repo.
- **Verified:** `assets/claude-config/hooks/tests/active-epic-fixtures.sh` (594 lines, sections
  A–N) is a fixture harness for the **hooks'** resolution logic
  (`subagent-lifecycle.sh`/`subagent-tool-logger.sh`), driven against synthetic sandbox repos. It
  asserts the resolution *algorithm* is correct — and it is; nothing about this issue implicates
  it — but it reads and asserts nothing about `SKILL.md`'s prose ordering. The issue's "worth
  checking whether the fixture can assert the ordering property directly" is therefore not already
  covered and would need a new, narrow, separate check rather than an extension of the existing
  hook-behavior harness.
- **Verified:** this is a documentation-only defect. The resolution rule itself is correct as
  specified and requires no change — the issue's own "Scope" section agrees: "Documentation
  ordering in `SKILL.md` Phase 5, plus possibly one fixture. No hook behaviour change."
- **Assumed:** nothing material — the issue's diagnosis matches the current file contents exactly,
  line for line.

## Invariants

- No change to hook behavior or the active-epic resolution algorithm — this epic touches
  documentation (and optionally a new, narrow test) only.
- Every other Phase 5 bullet keeps its current meaning; only the order of two bullets changes,
  plus one clarifying clause.

## Work items

### 1. Reorder Phase 5: mark Status closed before deleting scaffolding
- **Branch:** `docs/phase5-close-order-status-first`
- **Depends on:** none
- **Scope:** `Skills/dev-epic-workflow/SKILL.md`, Phase 5 section only. Swap the order of the two
  bullets so "Mark the plan header `**Status:** closed`" appears *before* "Temporary scaffolding
  actually deleted…". Add an explicit clause (on the now-first Status bullet, or as a lead-in to
  the scaffolding bullet) stating that `closed` must be live in the **canonical checkout** — merged
  and pulled, not merely committed on a close-out branch — before `status/`, `CANCEL`, and the
  `active-epic` pointer are removed, since the resolution hooks read the canonical checkout's
  `plan.md`, not a feature branch's.
- **Not in scope:** any change to `references/executor-control-plane.md`'s documented resolution
  algorithm, the hook scripts themselves (`subagent-lifecycle.sh`, `subagent-tool-logger.sh`), or
  any other Phase's content.
- **Definition of done:** in `SKILL.md` Phase 5, the "Mark the plan header `**Status:** closed`"
  bullet's line number is lower than the "Temporary scaffolding actually deleted" bullet's line
  number, and the scaffolding-deletion bullet's text references both preconditions (closed status
  first, live in the canonical checkout).
- **Verification:** `grep -n "Mark the plan header\|Temporary scaffolding actually deleted" Skills/dev-epic-workflow/SKILL.md` and confirm the Status line's number precedes the scaffolding line's number; read Phase 5 end-to-end to confirm sense.
- **Rollback:** revert the commit — pure documentation, no runtime dependency.

## Sequence

Single item. A second item was proposed — a fixture asserting the bullet order — and dropped at
approval: the draft itself argued in its risk table that prose-matching against free-form
Markdown is brittle, and an item you have already argued against is not worth carrying.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Reordering the bullets accidentally changes the wording or meaning of either instruction | Low | Confusing close-out guidance | Diff reviewed line-by-line; only the order and one clarifying clause change, no other rewording |
| A close-out already resolved against the old (buggy) order re-hits the race once more before picking up the merged fix | Low | One more instance of the same double-cleanup annoyance | Doc-only fix takes effect the moment the next close-out reads the merged `SKILL.md`; no runtime rollout needed |

## Deferred / out of scope

- **Runtime enforcement** — e.g. a hook that refuses to delete `status/` while `Status` still
  reads `in flight`. The issue's own Scope section rules out hook behavior changes; a code-level
  guard reopens the question of how much of Phase 5 should be automated at all, and belongs to its
  own epic if the doc fix alone proves insufficient in practice.
- **Broader Phase 5 automation or tooling.** This epic only reorders existing guidance; it does
  not change what close-out *does*, only the order in which two already-documented steps happen.

## Open questions

- Resolved at approval: the line-order fixture was dropped. The defect is narrow, the fix is two
  bullets, and a prose-matching test would fail on any future rewording. If this recurs after the
  fix, the answer is runtime enforcement (already in Deferred), not a brittle text assertion.

## Log

- 2026-08-20 — proposed from GH #41 via unattended intake. Phase 0 confirmed the described
  ordering defect is live in `SKILL.md` today (lines 157–158) and matches the causal chain
  documented in `executor-control-plane.md`'s active-epic resolution rule; confirmed epic 06's own
  retro recorded this incident happening live; confirmed no existing fixture harness tests
  `SKILL.md`'s prose ordering. Not approved, not numbered, not dispatchable.
- 2026-08-20 — approved and numbered **07**. Item 2 (the prose-ordering fixture) dropped at
  approval for the reason the draft itself gave. Dispatching item 1.

## Retro

**Outcome.** Phase 5 now marks the plan `closed` before deleting the epic's scaffolding, and
states that `closed` must be **merged and pulled into the canonical checkout** first — the hooks
resolve the epic from the canonical `plan.md`, so a `closed` living only on a close-out branch
does not count. Merged as PR #45, closing GH #41. Verified on `main`: the Status bullet is line
167, the scaffolding bullet 168 — reversed from the order that caused the defect.

**What this epic actually proved.** It is the first plan **drafted unattended, approved, dispatched
to an executor, and merged** — the whole loop, end to end, with a human acting only as approver and
verifier. Every prior epic was built inline.

**What got split.** Item 2 — a fixture asserting the two bullets' line order — was dropped at
approval, not deferred. The draft proposed it and then argued in its own risk table that
prose-matching against free-form Markdown is brittle. An item you have already argued against is
not worth carrying; if the defect recurs, the escalation is the runtime enforcement sitting in
Deferred, not a text assertion that breaks on the next rewording.

**What surprised us:**

1. **The executor exceeded a mechanical definition of done.** The DoD was a line-number
   comparison, which a naive two-line swap would satisfy. Instead it rewrote both bullets so they
   read as a pair, and ended the scaffolding bullet with the failure mode itself — pointer gone,
   header still `in flight`, next subagent falls through to the "newest plan marked in flight"
   fallback and recreates the tree you just deleted. The incident from the morning is now written
   into the instruction that prevents it. A falsifiable DoD is a floor, not a ceiling.
2. **It caught a stale base without being told.** Its worktree was cut from `b2c4994`; the
   orchestrator then pushed `920818e` (the dispatch status flip). It rebased before starting
   rather than opening a PR against a stale base.
3. **It declined a gate and said so in the PR body** instead of leaving an unchecked box —
   `active-epic-fixtures.sh` exercises hook resolution this diff does not touch, and GH #15
   (fixture harnesses can escape their sandbox) is open. Naming a skipped gate and its reason is
   the behaviour Phase 3 asks for and rarely gets.
4. **It labelled its own unverified claim.** Rendered Markdown appearance on GitHub was checked
   mechanically (delimiter balance, list structure), not by viewing the page, and it said so.

**The recursion worth recording.** The work item edited the Phase 5 text that governs closing
epics — including this one. This close-out is the first to run under the new ordering: `closed`
was landed in the canonical checkout before any scaffolding came down. If the fix is wrong, this
retro is where it would have shown up.

**Deferred, unchanged.** Runtime enforcement (a hook refusing to delete `status/` while the header
reads `in flight`) remains the escalation if the documentation fix proves insufficient.
