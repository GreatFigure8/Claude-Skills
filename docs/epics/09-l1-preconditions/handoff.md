# Session Handoff — 09-l1-preconditions / work items 2 and 6

**Written:** 2026-08-21T11:08:20Z
**Branch:** main (pushed: yes) — orchestrator session; two item branches in flight, both pushed
**Last commit:** ac35192 docs(epic-09): item 1 done; dispatch items 2 and 6
**Worktree:** main checkout (/Users/jonathanstevenson/Source/claude-skills)

## Verified this session

Every line below names how it was checked. Nothing here rests on an executor's summary.

- **Epic 08 is closed correctly and in the right order.** Header set to `closed` and landed on
  `main` (`2dec41e`) **before** scaffolding came down (`c4c88a2`) — the ordering GH #41 exists
  about. `handoff.md`, the 22-log `status/` tree, and `.claude/signals/active-epic` are gone;
  `git ls-files docs/epics/08-autonomous-mode/` now lists only `plan.md`, the rubric and the
  reviews.
- **PR #49 merged** as `f2c8233` before the close, preserving the opt-in hardening inside epic
  08 item 2's scope.
- **Item 3 merged** as `96ac7c0` (PR #52). Verified cold, not from the summary: PR OPEN→merged
  against `main`, exactly 2 declared files, `Part of #39` with no `Closes`, and diff hunks at base
  lines 51/256/271/337 — none inside the `PROMPT` at 303-325, so item 1's region was untouched.
- **Item 1 merged** as `ba25b9b` (PR #53). Verified cold: block ordering correct in the merged
  file (`check_work_in_progress` :485 precedes `REC_FILE` :505), and **item 3's own suite passes
  60/60 against item 1's branch** — the cross-check that matters.
- **Full gate suite green on merged `main` at `ba25b9b`: 879 cases, 0 failures**, working tree
  clean before and after, `bash -n` clean. Suites run individually: intake-outcomes 96, intake-skip
  60, active-epic 380, cancel-gate 111, lifecycle 107, session-start 125 (env-neutralised).
- **The #757 race timings, re-derived from `gh` rather than inherited.** Issue filed 19:50:58Z →
  PR #758 opened 19:58:37Z → **#758 merged 20:00:12Z** → runner selected #757 at 20:02:46Z →
  PR #761 opened 20:06:10Z → issue closed 20:16:24Z. At selection there was **no open PR and the
  issue was still open**, so "skip on an open PR" would not have caught it. This corrected item 3's
  design before dispatch.
- **Item 3's reference rule is too broad — measured, not inferred.** Live `--dry-run` on this repo
  classified #12, #15, #39 and #48 all `SKIP`, every one a false positive. #48 skips because of
  **PR #52 itself**: its body contains "#48 classified DRAFT — no open or merged non-runner PR
  references it", and that sentence is a cross-reference. Confirmed `skip_issue` removes the
  `claude-intake` label, so a false positive retires an issue rather than deferring it. This
  became item 6.
- **GH #54's cause is diagnosed, not guessed.** `session-start-fixtures.sh` gives 125 cases /
  2 failures unpinned on `main`, and **125 / 0 with `INTAKE_REPO_LIST=/nonexistent`** — run on the
  base commit with the tree clean before and after. Cause: the harness scrubs `PATH`
  (`session-start-fixtures.sh:148`) and `session-start-context.sh` calls bare `grep` for its
  `launchctl` check. Filed as GH #54.
- **PR #55 (item 2) is verified but NOT merged.** OPEN, base `main`, MERGEABLE/CLEAN, 3 declared
  files, `Part of #39` exactly once and `Closes` zero times, and **zero diff lines touching item
  6's territory** (grep for `check_work_in_progress|TIMELINE_PR_JQ|PROPOSAL_BRANCH_PREFIX|skip_issue|WIP_`
  returns 0). Gates against that branch: **957 cases, 0 failures**, tree clean.
- **Item 2's supplied facts are right, checked against ground truth.** Live `--dry-run` prints
  `live=main integration=main` for claude-skills and `live=main integration=dev` for LODE;
  `git remote show origin` reports `HEAD branch: main` for **both** repos — which is exactly what
  LODE plans #741 and #739 got backwards. `~/.config/claude-intake/intake.log` cksum identical
  before and after (`1295622390 68793`), both host checkouts clean.
- **Both item worktrees are clean and their branches are pushed and in sync** with their upstreams
  (`git status -sb` shows no ahead/behind on either).

## Claimed but NOT yet verified

- **All of item 6 / PR #56.** Its executor returned after the session was interrupted and **none of
  its report has been checked against the repo.** Specifically unverified: 108/0 on the extended
  skip suite; that #12/#15/#39/#48 flip `SKIP`→`DRAFT`; that LODE #757 and #786 still `SKIP`; the
  claim that `closingIssuesReferences` is empty for **all** PRs not based on the default branch
  (which is why it added a closing-keyword fallback, and is the load-bearing design claim);
  the negative controls (21 failures on un-updated fixtures, mutant R, stub mutation testing);
  and that it did not touch item 2's territory. **Verify PR #56 cold before merging anything.**
- **Item 6's claim that LODE #757 and #786 "were closed by hand since the plan's table"** — if
  true, item 6's table in `plan.md` is already stale. Not checked.
- **Item 6's discovery that LODE #795 and #766 now classify `DRAFT`** because their PRs say
  "Part of" rather than declaring closure, while both are item 1 of a multi-item epic still in
  flight. If true this directly affects item 5's sample. Not checked.
- **Item 6's keyword regex matching GitHub's own closing-keyword parser** — its executor states
  plainly this is believed, not known, and that cross-repo (`owner/repo#N`) and full-URL closing
  refs are deliberately unhandled.
- **Item 2's DoD is only partly met, by its executor's own account.** The Verification clause "one
  live draft per repo compared against `git remote show origin`" was **not** done — `--dry-run`
  returns before the prompt is built, so **no live run has exercised the new prompt text; only
  fixtures have.** Consequently the plan's risk row *"header facts are passed in but the drafter
  overwrites them anyway"* is **not retired**; its fixture case H deliberately shows a
  recall-based drafter still writing `dev`.
- **The six python-skills descriptions in `stack-gates.md` and `SKILL.md`** were taken from plugin
  UI listings rather than from reading the skills. Carried forward unverified from the epic 08
  handoff; still unverified.

## Exact next action

- Verify PR #56 (item 6) cold against the repo — re-run the live `--dry-run` classification for
  every open issue in both repos and the extended `intake-skip-fixtures.sh` — then resolve the two
  decisions below before merging #55 or #56.

## Environment state

- **Both item worktrees still exist** and must be removed at land-and-reset:
  `../claude-skills-header-from-config` (`fix/intake-header-from-config`, `adb6647`, PR #55) and
  `../claude-skills-reference-narrowing` (`fix/intake-reference-narrowing`, `ed9621f`, PR #56).
- `.claude/signals/active-epic` names `09-l1-preconditions`. Plan header reads
  `**Status:** in flight (items 2 and 6 of 6, parallel)` — both are now at `pr-opened`, unmerged.
- `docs/epics/09-l1-preconditions/status/` holds the two executors' status files and agent logs;
  clean them per item at land-and-reset.
- launchd agent `com.jonathanstevenson.unattended-intake` is **LOADED**, polling every 1800s.
  Unload: `launchctl unload ~/Library/LaunchAgents/com.jonathanstevenson.unattended-intake.plist`.
- `~/.config/claude-intake/repos` watches `~/Source/claude-skills` (integration `main`) and
  `~/Source/Oracle-Simple-Convert|dev`. **No open issue currently carries `claude-intake`**, so the
  poller has nothing to draft and item 3's false positives cannot bite yet.
- Open PRs: **#55**, **#56** (this epic), plus unattended proposals #50 (GH #48), #26 (GH #12),
  #25 (GH #15) awaiting approval.
- Open issues with no epic: #54, #48, #15, #12. GH #39 remains open and is epic 09's `Source`.
- `session-start-fixtures.sh` is red 2/125 on this machine by environment (GH #54). Use
  `INTAKE_REPO_LIST=/nonexistent` as the clean control. Do not read it as a regression.

## Open questions for Jonathan

Two of these were mid-question when the session was interrupted; nothing was decided.

- **PR #55 disposition.** Merge it and let item 5's live drafts supply the missing live-draft
  proof (my recommendation), send it back to draft live now (burns a sample and opens PRs purely
  as a fixture), or hold it unmerged until item 5?
- **Should the header read-back become item 7?** Item 2 supplies the branch facts but adds no gate
  that the drafter used them. Reading the drafted header back and `WARN`ing on mismatch is one
  `sed` and is the only mechanism that would catch #741/#739 **without a human** — which is the
  case L1 is defined by. Epic 08's verdict called this defect "not self-announcing"; item 2 alone
  does not change that.
- **Item 6's finding, which bears directly on item 5.** An issue whose epic is mid-flight (PR says
  "Part of #N", not "closes") now classifies `DRAFT` and will be re-drafted. Under the approved
  rule that is correct; under item 3's *intent* it arguably should skip. Two cheap signals exist:
  a non-runner branch named for the issue, and labels (`epic:in-progress`). Widening the rule is a
  rule change, not an executor's call — decide before item 5 labels its sample.
- Epic 09's own two carried-over open questions are still open: whether a proposal's
  `Recommendation` may be **downgraded** by item 4's collision check, and **where five genuinely
  under-specified briefs come from** for item 5. The second can stall the epic.
