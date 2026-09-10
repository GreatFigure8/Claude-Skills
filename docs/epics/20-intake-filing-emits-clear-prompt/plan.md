# Epic: intake-filing-emits-clear-prompt — end every intake session with a paste-able coding-session prompt

**Status:** approved
**Source:** GH #94
**Live branch:** main   **Integration branch:** none (per repo `CLAUDE.md`, items merge straight to `main`)
**Approved:** 2026-09-10

## Outcome

When an intake session files an approved epic and links the tracker, it ends by running
`clear-prompt` and posting a `dev-epic-workflow prep-for-clear` block in chat. Jonathan pastes
that block into a fresh session, which recognises it as a coding-session declaration and
proceeds straight to dispatching item 1. `clear-prompt` gains an "epic filed, nothing
dispatched" shape so the block is correct for that state, and a drift fixture keeps the three
filing surfaces and the caller table in agreement.

## Grounding

- Inspected: `Skills/dev-epic-workflow/SKILL.md` (Session mode lines 23–29, Phase 1 filing
  lines 105–107, Phase 3.5 step 4), `assets/claude-config/commands/intake.md` step 6,
  `references/issue-intake.md` Pickup step 5, `Skills/clear-prompt/SKILL.md` (template lines
  56–71, the "not /handoff" table), `hooks/tests/` fixture inventory, `docs/epics` numbering,
  recent history of both skills.
- Observed: nothing in dev-epic-workflow mentions `clear-prompt`; `clear-prompt` says "if the
  session is running dev-epic-workflow, use `/handoff`, not this." `docs/epics/handoff.md` was
  stale at planning time (described the epic-loop draft as awaiting approval after it was filed).
- Assumed, not verified: the hook fixture scripts are run individually with `bash <file>` and
  there is no aggregating runner to register a new fixture in. Item 3 checks this first.
- Overlap check: epic 19 (epic-loop, GH #93) is the headless path. It never has a chat to post
  into, so this change does not touch it and it does not touch this.

## Invariants

- `/handoff` and `docs/epics/handoff.md` keep their current role for mid-epic orchestrator
  checkpoints. `clear-prompt` at filing is additive, not a replacement.
- The intake session still never dispatches. Emitting the block is the last thing it does,
  after filing and tracker linking, never before.
- The live skills are symlinks into `~/Source/claude-skills-main` at `origin/main`. Merging to
  `main` is going live, so each item must read cleanly on its own.

## Work items

### 1. Filing ends with clear-prompt, on all three surfaces

- **Branch:** `feat/intake-filing-emits-clear-prompt`
- **Touches:**
  - `Skills/dev-epic-workflow/SKILL.md`
  - `Skills/dev-epic-workflow/assets/claude-config/commands/intake.md`
  - `Skills/dev-epic-workflow/references/issue-intake.md`
- **Scope:** Phase 1's "Filing is not finished until the tracker says so" paragraph gains a
  final step: run `clear-prompt` with caller `dev-epic-workflow` and post the block. Session
  mode adds a pasted `dev-epic-workflow prep-for-clear` block to the coding-session triggers,
  and states the intake session's output is "a filed plan plus the paste block". `/intake`
  step 6 and Pickup step 5 replace "state the ref, path and items, then stop" with "run
  clear-prompt, post the block, then stop", since the block already carries ref, path and
  items. Filing also deletes a `docs/epics/handoff.md` that describes this epic's draft, in the
  filing commit.
- **Done when:** all three surfaces name `clear-prompt` at the filing step and agree on what
  the block replaces.
- **Does not:** touch Phase 3.5, the SessionStart hook, or any executor text.

### 2. clear-prompt learns the "epic filed" shape

- **Branch:** `feat/clear-prompt-epic-filed-shape`
- **Touches:**
  - `Skills/clear-prompt/SKILL.md`
- **Scope:** add dev-epic-workflow as a second caller. The "not /handoff" guidance becomes a
  distinction, not a refusal: mid-epic with items in flight is `/handoff`; end of intake with
  nothing dispatched is `clear-prompt`. Add the shape: header `dev-epic-workflow
  prep-for-clear`, epic path, `Source:`, every item NEXT with its branch, Verified = filing
  commit hash and tracker label, Claimed-but-NOT-verified = anything the intake session
  asserted without checking, Exact next action = "This is a coding session. Dispatch item 1
  per Phase 2–3." Include one worked example.
- **Done when:** the skill description and caller table name dev-epic-workflow, and the
  example block validates against the template fields.
- **Does not:** change the dev-story-sprint shape or the template's field set.

### 3. Drift fixture for the filing contract

- **Branch:** `test/clear-prompt-filing-drift-fixture`
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/hooks/tests/clear-prompt-filing-fixtures.sh`
  - a runner registration, only if a runner exists
- **Scope:** grep-based assertions that SKILL.md Phase 1, `intake.md`, and `issue-intake.md`
  each mention `clear-prompt` at the filing step, that Session mode lists the pasted block as a
  coding trigger, and that `clear-prompt/SKILL.md` names dev-epic-workflow as a caller. Same
  pattern as `output-discipline-drift-fixtures.sh`.
- **Done when:** the fixture passes on the merged tree and fails when any one of those lines
  is removed (checked by a deliberate mutation during verification).
- **Does not:** test hook behaviour or run any skill.

## Sequence and dependencies

Items 1 and 2 are independent and can run in parallel. Item 3 depends on both being merged.

## Risk and rollback

- **Item 1:** prose only. Revert the merge commit. Risk is an intake session that emits the
  block before linking the tracker; the wording puts it after, and item 3 pins the ordering by
  line position.
- **Item 2:** prose only. Revert. Risk is a fresh session reading the block and treating it as
  a mid-story sprint resume; the header word `dev-epic-workflow` is what routes it, so item 1's
  Session-mode trigger keys on that.
- **Item 3:** a fixture that fails on a false premise blocks nothing else. Revert or fix.

## Decisions

- No `docs/epics/handoff.md` is written at filing. The SessionStart injection ("N epics
  awaiting dispatch") plus the pasted block is enough; a stale draft-handoff is deleted in the
  filing commit instead. (Open question 1, resolved on approval 2026-09-10.)
- This epic's own filing ends the old way, since item 1 has not landed yet.

## Deferred / out of scope

- Emitting a `clear-prompt` block at Phase 5 close ("epic done, what next").

## Log

- 2026-09-10 — drafted from grounding, approved by Jonathan, filed as epic 20 with GH #94.
