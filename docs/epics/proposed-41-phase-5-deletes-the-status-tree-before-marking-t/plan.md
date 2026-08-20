# Epic: Phase 5 close-out marks the plan closed before deleting the status tree

**Status:** planning
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

### 2. Guard the ordering with a small fixture assertion (optional)
- **Branch:** `test/phase5-close-order-fixture`
- **Depends on:** item 1
- **Scope:** A small, narrow script under
  `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/` (new file, or a short addition to
  an existing harness if a natural home exists) that greps `SKILL.md`'s Phase 5 section for the
  two bullets' line numbers and fails if "Mark the plan header `**Status:** closed`" does not
  precede "Temporary scaffolding actually deleted". Purpose: a future edit that silently
  re-reverses the order fails a test instead of shipping quietly and waiting for the next close-out
  to rediscover it live.
- **Not in scope:** testing hook runtime behavior (already covered by `active-epic-fixtures.sh`);
  testing any other document's prose ordering; any change to how tests are invoked or wired into
  `install.sh`.
- **Definition of done:** running the new check against the corrected `SKILL.md` from item 1
  passes; reverting item 1's order locally makes it fail.
- **Verification:** temporarily swap the two bullets back to the old (buggy) order and confirm the
  new check fails; restore item 1's order and confirm it passes.
- **Rollback:** delete the new script — it is not load-bearing to item 1's doc fix.

## Sequence

1 → 2. Item 2 is optional and cheap; it only guards against this exact defect recurring and can be
dropped without weakening item 1's fix if the ordering check proves too brittle to write cleanly
against free-form prose.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Reordering the bullets accidentally changes the wording or meaning of either instruction | Low | Confusing close-out guidance | Diff reviewed line-by-line; only the order and one clarifying clause change, no other rewording |
| A doc-ordering fixture is brittle to future prose edits (rewording either bullet breaks a naive text match) | Medium | Noisy false failures on unrelated `SKILL.md` edits | Match on stable anchor phrases already used verbatim elsewhere in the docs (`Mark the plan header`, `Temporary scaffolding actually deleted`); keep item 2 optional so a brittle check doesn't block the core fix |
| A close-out already resolved against the old (buggy) order re-hits the race once more before picking up the merged fix | Low | One more instance of the same double-cleanup annoyance | Doc-only fix takes effect the moment the next close-out reads the merged `SKILL.md`; no runtime rollout needed |

## Deferred / out of scope

- **Runtime enforcement** — e.g. a hook that refuses to delete `status/` while `Status` still
  reads `in flight`. The issue's own Scope section rules out hook behavior changes; a code-level
  guard reopens the question of how much of Phase 5 should be automated at all, and belongs to its
  own epic if the doc fix alone proves insufficient in practice.
- **Broader Phase 5 automation or tooling.** This epic only reorders existing guidance; it does
  not change what close-out *does*, only the order in which two already-documented steps happen.

## Open questions

- Is the line-order fixture (item 2) worth the ongoing maintenance cost of a prose-matching test,
  or is this specific defect narrow enough that documentation plus review discipline is
  sufficient on its own? Left as a judgment call for approval — item 1 alone fully addresses the
  issue as filed.

## Log

- 2026-08-20 — proposed from GH #41 via unattended intake. Phase 0 confirmed the described
  ordering defect is live in `SKILL.md` today (lines 157–158) and matches the causal chain
  documented in `executor-control-plane.md`'s active-epic resolution rule; confirmed epic 06's own
  retro recorded this incident happening live; confirmed no existing fixture harness tests
  `SKILL.md`'s prose ordering. Not approved, not numbered, not dispatchable.
