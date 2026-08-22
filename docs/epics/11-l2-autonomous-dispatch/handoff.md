# Session Handoff — 11-l2-autonomous-dispatch / work item 3 (last; epic code-complete, development PAUSED)

**Written:** 2026-08-22T15:40:00Z
**Branch:** main (pushed: yes)
**Last commit:** 535163c chore(epic): session handoff — 11-l2-autonomous-dispatch item 3
**Worktree:** main checkout (/Users/jonathanstevenson/Source/claude-skills)

> **Development on this repo is paused at Jonathan's instruction.** He is focusing on getting
> LODE to fully convert an HDL file. This session wrote no code here — it re-verified the prior
> handoff's claims and corrected one line of out-of-repo intake config. Nothing is half-done.

## Verified this session

Every line names how it was checked. Nothing here rests on a previous handoff's word.

- **Epic 11's four items are merged.** `git log --oneline --merges`: item 1 `440239d`,
  item 2b `e3d5e42`, item 2 `243052a`, item 3 `2626259`.
- **Battery re-run green on merged `main`: 2181 cases, 0 failures across all 12 suites.** Run
  this session in the main checkout, not on a feature branch, with
  `INTAKE_REPO_LIST=/nonexistent` (GH #54, environmental). Per-suite: active-epic 416,
  autonomy-control 261, cancel-gate 111, intake-collision 127, intake-control-plane 178,
  intake-header 81, intake-outcomes 96, intake-skip 251, l2-dispatch 231, lifecycle 107,
  session-start 144, worktree-provision 178. Every suite rc=0. This is an independent
  reproduction of the prior handoff's identical figure, not a restatement of it.
- **Nothing above L0 can execute.** `ls ~/.config/claude-intake/` shows **no `autonomy` file
  and no `promotions/` directory**, so every repo resolves `L0 (unconfigured)`.
- **The launchd runner is healthy at 600s.** `launchctl list` shows it loaded with last exit 0;
  `PlistBuddy` reads `StartInterval 600`. Observed cycles this session: 15:06, 15:16, 15:26,
  15:37 — matching the interval.
- **Nothing labelled `claude-intake` in any of the four repos.** Confirmed both from
  `intake.log` ("nothing labelled 'claude-intake' — nothing to do" for all four, every cycle)
  and `gh issue list` on this repo. The runner is no-opping.
- **AIX Payroll Compare's intake base was WRONG and is now FIXED.** `~/.config/claude-intake/repos`
  had no `|` suffix for it, so proposals would have targeted GitHub's default `main`. Checked the
  repo directly: `dev` exists, is the branch actually checked out there, and `gh repo view` confirms
  the default is `main` — i.e. the config was genuinely pointing at the wrong base. Corrected to
  `|dev`, backed up to `repos.bak-103506-aixdev`. **Confirmed live**: the 15:37:11Z cycle logged
  `live=main integration=dev`. No restart was needed — the runner re-reads the config each cycle.
  (The 15:26:58Z cycle still logged `integration=main`; that is correct, the edit landed 15:35:06Z.)
- **The SessionStart injection calling epic 11 "awaiting approval" is BY DESIGN, not a defect.**
  Its Status header (`code-complete, NOT closed — ...`) is unparseable, and
  `session-start-context.sh:230` deliberately buckets anything unparseable into the approval
  queue; lines 115–117 document why (an approved epic shown as needing approval costs a glance,
  a `planning` epic shown as dispatchable costs the gate). **No issue should be filed for this.**
- **This checkout is clean**, on `main`, in sync with `origin/main` at `535163c`, and
  `git worktree list` shows only the main checkout. No branches, worktrees, or executors are
  held by this session in any repo.
- **Open-issue state on this repo:** #39 carries `epic:in-progress` (epic 09) and #57 carries
  `epic:planned` (epic 10) — both correctly labelled. Unplanned: #63, #61, #54, #48, #15.

## Claimed but NOT yet verified

Carried forward unchanged — this session addressed none of them.

- **Item 2b's live LODE verification — NEVER RUN.** Its DoD requires a freshly-created LODE
  worktree to run `bash scripts/test-both.sh` **and** `pnpm --filter web test` green with no
  manual step, diffed against oracle 2385 / postgres 2384 / web 1166. **Proven only against a
  synthetic repo of the same shape.**
- **Item 3's live LODE cycle — NEVER RUN.** One approved epic's next item from queue to open PR
  on `dev`, unattended, with the gate actually run.
- **`claude -p --agent work-item-executor` has never been exercised by the L2 runner.** The
  executor is a stub in every fixture. Still the single most load-bearing unproven assumption in
  epic 11. **Epic 11 is merged but not trusted, and this is why.**
- **GH #63's stated cause** (`SubagentStart` not firing rather than firing-and-failing) remains an
  inference from absent owner records for ~39 stub ids. The hook was never instrumented.
- **`shellcheck` has never been run** on any of epic 11's shell. Not installed on this machine;
  `bash -n` was used as a declared substitute, not an equivalent.
- **`intake-control-plane-fixtures.sh` case G3's reported flakiness is unresolved.** It **passed**
  in this session's battery run. That is n=1 against a claimed 1-in-2 failure rate — a failure to
  reproduce, not a clearance. Do not close the report on this evidence.
- **Epic 10 (declared-paths) is filed and approved but entirely unstarted.** No item dispatched.
- **Epic 09 item 5's brief survey may be stale.** #869 is one real data point at n=1 against a
  requirement of ≥5.
- **All LODE repo facts are second-hand.** The five active worktrees (178, 179, three on epic 192)
  and `dev` at `93094cef` come from the *previous* session's observation and were **not
  re-checked** this session. Re-ground before acting on them.

## Exact next action

Development here is paused — switch to LODE and get an HDL file converting end to end; return to
this repo only to run item 2b's live provisioning check and one supervised L2 cycle when LODE is
free, which is the only gap between epic 11 being merged and being trusted.

## Environment state

- **launchd agent `com.jonathanstevenson.unattended-intake` is LOADED and left running**,
  `StartInterval 600`, watching 4 repos at **L0 (drafting only)**. It no-ops every 10 minutes
  because nothing is labelled. Unload with:
  `launchctl unload ~/Library/LaunchAgents/com.jonathanstevenson.unattended-intake.plist`
- `~/.config/claude-intake/repos` now reads: claude-skills→main, Oracle-Simple-Convert→dev,
  **AIX Payroll Compare→dev (corrected this session)**, oracle-mcp-services→dev-v2.
  Backups: `repos.bak-094731`, `repos.bak-preepic30`, `repos.bak-103506-aixdev`.
- **No `autonomy` config and no `promotions/` directory exist** — this is what keeps L2 inert.
- No services, migrations, tunnels, or seeded data from this session. No issues filed this session.

## Open questions for Jonathan

- **Do you want L2 enabled once the live verifications pass?** It needs a promotion record, which
  item 1 made a deliberate human action — the automation cannot write one.
- **File the `- **Branch:** n/a` convention?** Two real LODE items (a `CANCELLED` item with no
  branch, and one reading `deferred to epic 180 item 5`) currently make item 3 refuse their whole
  epic every cycle. The refusals are correct; the convention would make them ordinary.
- **Epic 09 item 5** — re-measure, or close epic 09 on "not measured"?
- **Epic 10 is unstarted.** It would let item 3's denylist check declarations before execution
  rather than the diff after.
- **Epic 11 stays open** while its two live verifications are outstanding. Confirm that is right,
  or say the word and it can be closed on the synthetic evidence.
