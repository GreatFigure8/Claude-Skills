# Epic: Session mode — distinguish intake sessions from coding sessions

**Status:** in flight (item 1 of 1)
**Live branch:** main   **Integration branch:** main   **Pre-epic tag:** n/a — prose/doc change only, no runtime behavior to reconstruct

## Outcome

Jonathan can open an intake session (`/intake`, or a bug/feature description in conversation)
and stay in planning-only mode across as many epics as he intakes in that sitting — Claude never
offers to implement, never dispatches a work item, and never touches code, even for something
that looks trivial. A coding session — opened by a direct instruction to implement, fix, or
build — skips straight to execution without Claude re-opening a planning conversation. Mode is
declared once, at the top of the session, and holds for the rest of it.

## Grounding

- Verified: `Skills/dev-epic-workflow/assets/claude-config/commands/intake.md` step 6 ("Hand to
  the orchestrator (Phase 3)") instructed the `/intake` command to dispatch the first work item
  to `work-item-executor` on approval — the actual mechanism behind intake sessions sliding into
  execution.
- Verified: `Skills/dev-epic-workflow/references/issue-intake.md` line 124 carried the same
  instruction ("Hand to Phase 3 — the orchestrator dispatches the first executor").
- Verified: `Skills/dev-epic-workflow/SKILL.md`'s Intake section had no concept of session mode
  at all — nothing distinguished "planning only" from "planning then execute," so Claude treated
  every intake session as implicitly headed toward dispatch.
- Assumed: none — this is a prose/behavior-contract change with no runtime mechanism, so there
  is nothing further to verify against a live system.

**Process note:** this epic was filed retroactively. Jonathan asked for the change directly in
conversation; it was implemented immediately without going through Phase 0/1 first, which is the
exact failure mode (#1 in SKILL.md's list) this workflow exists to prevent. When asked whether
the process had been followed, the answer was no — Jonathan then asked for it to be filed
properly after the fact, which is this document.

## Invariants

- L2/unattended intake (`references/l2-dispatch.md`) is unaffected — it already never dispatches
  from the drafting pass; this only changes the *interactive* `/intake` path.
- No new persistent state, hook, or slash command — mode is a conversational declaration read
  from SKILL.md, not a stored flag.

## Work items

### 1. Session mode section, and stop `/intake` from dispatching
- **Branch:** `docs/session-mode-intake-vs-coding`
- **Depends on:** none
- **Scope:** Add a "Session mode — intake or coding" section to `SKILL.md` defining both modes
  and the default when the opening message gives no signal; rewrite the Intake section's Pickup
  bullet to stop at filing instead of handing to Phase 3; rewrite `commands/intake.md` step 6
  from "dispatch the first work item" to "stop — dispatch is a coding-session action"; rewrite
  `references/issue-intake.md` step 5 the same way.
- **Touches:**
  - `Skills/dev-epic-workflow/SKILL.md`
  - `Skills/dev-epic-workflow/assets/claude-config/commands/intake.md`
  - `Skills/dev-epic-workflow/references/issue-intake.md`
- **Not in scope:** no new hook or persistent session-mode indicator (e.g. in the statusline or
  SessionStart injection) — mode is declared and held conversationally; revisit only if drift
  recurs. No change to L2/unattended intake, which was already correct.
- **Definition of done:** `SKILL.md` states both modes and their scope; no file under
  `Skills/dev-epic-workflow/` still instructs an intake session to dispatch a work item.
- **Verification:** `grep -rn "Hand to Phase 3\|hand to Phase 3 for dispatch\|dispatches the first executor" Skills/dev-epic-workflow/` returns nothing; `SKILL.md` contains a `## Session mode` heading.
- **Rollback:** revert the merge commit.

## Sequence
Single item, no dependencies.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Mode declaration is conversational only, no enforcement mechanism — could still drift if a future session ignores the rule | Low-medium | Same failure this epic fixes recurs | Prose is the same mechanism every other rule in this skill uses; add a mechanical check (statusline/hook) later only if it recurs |

## Deferred / out of scope
- A persistent, hook-visible session-mode indicator (e.g. surfaced in the SessionStart
  injection or statusline) — not needed unless the conversational declaration proves
  insufficient in practice.

## Log
- 2026-08-30 — Item 1 implemented directly in conversation, ahead of this plan being filed
  (process gap). Plan filed and item marked done in the same session, retroactively, per
  Jonathan's instruction after being asked whether the process had actually been followed.
