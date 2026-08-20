# Session Handoff — 08-autonomous-mode / work item 1

**Written:** 2026-08-20T22:19:09Z
**Branch:** main (pushed: yes)
**Last commit:** 0587642 docs: the designed interactive guide, v1
**Worktree:** main checkout

## Verified this session
- Epic 08 item 1 complete and merged (PR #51, `08417d9`). Deliverables on `main`:
  `draft-quality-rubric.md` and `draft-quality-reviews.md`. Rubric commit `014b1de` (15:56:52)
  precedes scoring commit `255c499` (16:07:02) — confirmed by `git log`, so "criteria not fitted
  to findings" is checkable, not merely claimed.
- **Verdict: NO-GO on L1.** Effective sample n=7, not 9.
- The `Live branch: dev` finding is CORRECT at 2 of 7. Verified by reading each plan from its PR
  **merge commit** (`3fae7e32` for #739, `03caa6d5` for #741) — both declare `**Live branch:** dev`
  where live is `main`. An earlier check of mine reported "1 of 7"; that check was broken because
  the PR head branches were deleted on merge, so `git show origin/<branch>` returned nothing and I
  misread absence-of-file as absence-of-line. The report needs no correction.
- The #757 race is real, timings from `gh` and the runner log: issue filed 19:50:58Z → attended
  PR #758 merged 20:00:12Z (edited `CLAUDE.md`) → runner picked up #757 at 20:02:46Z → unattended
  PR #761 opened 20:06:10Z for work already done. #761 IS an unattended draft (branch
  `intake/proposed-757-...`, runner log records creating it); it was overtaken, not misclassified.
- Epics 06 and 07 closed with retros. Epic 07 ran the full loop: unattended draft (#42) → approved
  (#44) → dispatched → built (#45) → closed (#46). Phase 5 reorder verified live on `main`:
  Status bullet line 167, scaffolding 168.
- Phase 5's new ordering was exercised by epic 07's own close-out: `closed` landed in the canonical
  checkout first, scaffolding removed after, and `status/` did NOT reappear.
- Rule-3 telemetry defect demonstrated concretely: 22 agent logs had accumulated in
  `proposed-39-autonomous-mode/status/` before approval. Filed as GH #48 (labelled `claude-intake`).
- All six python-skills wired into the workflow (PR #43, merged). Live immediately because
  `~/.claude/skills/dev-epic-workflow` is a **symlink** into this repo — no reinstall needed.
- Tier 2 install verified in sync with source (7 hooks, 2 commands, 1 agent, all byte-identical).
  Tier 3 armed: agent loaded, credential 0600, two repos watched, dry-run `rc=0`.

## Claimed but NOT yet verified
- PR #49 (epic 08 item 2 hardening: global override + evidence-gated enablement) is OPEN and
  UNMERGED. Its content is written but not reviewed or landed.
- Epic 08's `plan.md` still reads `**Status:** in flight (item 1 of 8)`. Item 1 is done and merged,
  so the header is stale — it was not updated before this checkpoint.
- The six python-skills descriptions in `stack-gates.md` and `SKILL.md` were taken from the
  plugins' UI listings, NOT from reading the skills. They were not loadable in this session.
- LODE #757's binding work was done by an attended session (PR #758, merged). Its content was
  never reviewed here.
- GH #48 (rule-3 telemetry) is labelled and awaiting an unattended draft; not yet drafted.

## Exact next action
- Decide the epic 09 proposal (five items: first-class non-approval outcomes, header metadata from
  repo config, skip issues already being worked, collision detection in admission, re-measure and
  re-verdict), then file it and dispatch item 1.

## Environment state
- launchd agent `com.jonathanstevenson.unattended-intake` is **LOADED**, polling every 1800s.
  Unload: `launchctl unload ~/Library/LaunchAgents/com.jonathanstevenson.unattended-intake.plist`.
- `~/.config/claude-intake/repos` watches `~/Source/claude-skills` (base: GitHub default `main`)
  and `~/Source/Oracle-Simple-Convert|dev`. Credential at mode 0600.
- Only `claude-skills` GH #48 currently carries `claude-intake`; it will be drafted at the next poll.
- `git worktree list` shows only the main checkout. Two `intake/proposed-*` branches remain locally,
  backing open PRs #25 and #26.
- `.claude/signals/active-epic` names `08-autonomous-mode`.
- **Attended sessions are working LODE concurrently** — they approved and renumbered several
  unattended proposals (epics 139, 141, 144 on `dev`) and won the #757 race. Expect LODE state to
  move without this session's involvement.

## Open questions for Jonathan
- Approve the epic 09 shape as proposed, or restructure it as more items inside epic 08?
- Item 3 of that proposal needs a decision I cannot make alone: should the runner skip an issue
  with **any** open PR referencing it, or only one it did not create? Too broad stops issues under
  discussion; too narrow leaves the race open.
- Merge or close PR #49 (item 2 hardening) — it is written against an epic that is now paused.
