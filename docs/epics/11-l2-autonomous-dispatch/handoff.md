# Session Handoff — 11-l2-autonomous-dispatch / work item 3 (last; epic code-complete)

**Written:** 2026-08-22T14:59:31Z
**Branch:** main (pushed: yes)
**Last commit:** a6babd4 docs(epic-11): item 3 merged; epic is code-complete but not closed
**Worktree:** main checkout (/Users/jonathanstevenson/Source/claude-skills)

## Verified this session

Every line names how it was checked. Nothing here rests on an executor's summary.

- **All four epic 11 items are merged.** Item 1 `440239d`, item 2b `e3d5e42`, item 2 `243052a`,
  item 3 `2626259`. Each was merged by this session and pulled back into the main checkout.
- **Battery on merged `main`: 2181 cases, 0 failures.** Run by the orchestrator on the merged
  branch after item 3, not on the feature branch. `session-start-fixtures.sh` needs
  `INTAKE_REPO_LIST=/nonexistent` (GH #54, environmental).
- **Item 3 ships inert.** Runner diff is exactly **+57 / −0** (`git diff --numstat`), and a grep of
  its added non-comment lines for `gh pr merge|gh issue close|gh issue edit|gh pr edit` returns
  **0**.
- **Nothing above L0 can execute.** `ls ~/.config/claude-intake/` shows **no `autonomy` file and no
  `promotions/` directory**, so every repo resolves `L0 (unconfigured)` and item 1's evidence gate
  refuses any higher level.
- **The launchd runner is healthy and permanent at 600s.** `PlistBuddy` reads `StartInterval 600`;
  `launchctl list` shows it loaded, last exit 0; watching 4 repos. Actual cadence confirmed from
  the log: 14:04:31 → 14:14:48 → 14:25:07 → 14:35:23 → 14:45:43 → 14:56:02.
- **284 cycles logged; nothing labelled in any of the four repos** (`gh issue list --label
  claude-intake` = 0 for Claude-Skills, Oracle-Simple-Convert, AIX-Payroll-Compare,
  oracle-mcp-services).
- **Yesterday's unattended run: 10 issues, 9 proposals, 1 skip.** Read from `intake.log`. The skip
  was **#849 at selection on the `epic:planned` label** — epic 09 item 8 catching a real race
  against a parallel session's live work, with no timeline or PR query needed.
- **The `needs-decision` rate is 2 of 8, not 4 of 8.** Read the plans directly from the proposal
  branches: #851 and #852 open with `## Collision detected in admission` — those are epic 09
  item 4 downgrades, not drafter judgement. Only #841 and #850 are the drafter's own call.
- **#869 (issue #841) is a genuine honest refusal.** Read it: `Recommendation: needs-decision`, a
  section headed *"The decision this proposal cannot make"*, `Outcome: Not yet determined`, and it
  grounded the question by finding `_needs_triage()` / `qa_triage_confident_threshold` at
  `apps/api/src/api/config.py:384` — code the issue's author had explicitly not read.
- **Epic 09 is 7 of 8 done**; only item 5 remains and it is blocked (see its own brief survey).
- **LODE is busy, not quiet.** Five active worktrees this morning (178, 179, three on epic 192),
  `dev` at `93094cef`. This session created none of them and holds nothing in that repo.
- **This checkout is clean**, on `main`, in sync with origin, and `git worktree list` shows only
  the main checkout.

## Claimed but NOT yet verified

- **Item 2b's live LODE verification — NEVER RUN.** Its DoD requires a freshly-created LODE
  worktree to run `bash scripts/test-both.sh` **and** `pnpm --filter web test` green with no manual
  step, diffed against oracle 2385 / postgres 2384 / web 1166. Forbidden by its dispatch because a
  parallel session owned the repo. **Proven only against a synthetic repo of the same shape.**
- **Item 3's live LODE cycle — NEVER RUN.** Same reason, same status. One approved epic's next item
  from queue to open PR on `dev`, unattended, with the gate actually run.
- **`claude -p --agent work-item-executor` has never been exercised by the L2 runner.** The
  executor is a stub in every fixture. The single most load-bearing unproven assumption in epic 11.
- **GH #63's stated cause** (`SubagentStart` not firing rather than firing-and-failing) is an
  inference from the absence of owner records and `subagent-active-*` markers for ~39 stub ids. The
  hook was never instrumented to observe it.
- **`shellcheck` has never been run** on any of epic 11's shell. Not installed on this machine;
  `bash -n` was used throughout and declared as a substitute, not an equivalent.
- **`intake-control-plane-fixtures.sh` case G3 is reported timing-flaky** by item 3's executor —
  it claims a failure on the untouched `main` runner on 1 of 2 runs before its branch existed. This
  session did not reproduce it.
- **Epic 10 (declared-paths) is filed and approved but entirely unstarted.** No item dispatched.
- **Epic 09 item 5's brief survey may already be stale.** It concluded no genuinely
  under-specified briefs exist in either backlog; LODE's issue set has changed materially since.

## Exact next action

Get one hour when no session is working LODE, then run item 2b's live provisioning check on a real
LODE worktree followed by one supervised L2 cycle end to end — that is the only remaining gap
between epic 11 being merged and being trusted.

## Environment state

- **launchd agent `com.jonathanstevenson.unattended-intake` is LOADED**, `StartInterval 600`
  (permanent, at Jonathan's instruction), watching 4 repos. Unload:
  `launchctl unload ~/Library/LaunchAgents/com.jonathanstevenson.unattended-intake.plist`
- `~/.config/claude-intake/repos` lists claude-skills, Oracle-Simple-Convert|dev,
  `AIX Payroll Compare` (path contains spaces — verified working), oracle-mcp-services|dev-v2.
  Backups: `repos.bak-094731`, `plist.bak-094746`.
- **No `autonomy` config and no `promotions/` exist** — this is what keeps L2 inert.
- Nothing labelled `claude-intake` anywhere, so the runner no-ops every 10 minutes.
- No executors, worktrees, or branches held by this session in any repo.
- Issues filed this session: **#57** (declared paths → epic 10), **#61** (collision check warns on
  `no-work` counterparts), **#63** (orphan subagent STOP logs, with a parallel session's incident
  findings added as a comment).

## Open questions for Jonathan

- **Do you want L2 enabled once the live verifications pass?** It needs a promotion record, which
  item 1 made a deliberate human action — the automation cannot write one.
- **File the `- **Branch:** n/a` convention?** Two real LODE items (a `CANCELLED` item with no
  branch, and one reading `deferred to epic 180 item 5`) currently make item 3 refuse their whole
  epic every cycle. The refusals are correct; the convention would make them ordinary.
- **Epic 09 item 5** — re-measure, or close epic 09 on "not measured"? Its blocker was that no hard
  briefs exist; #869 is now one real data point at n=1 against a requirement of ≥5.
- **Epic 10 is unstarted.** It would let item 3's denylist check declarations before execution
  rather than the diff after.
