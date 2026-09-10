# Epic: epic-loop — an issue becomes a closed epic without a human in the middle

**Status:** approved
**Source:** GH #93 — report-first intake; issue created at filing
**Live branch:** `main`   **Integration branch:** `dev` (pushed from `main`'s tip 2026-09-10, scoped to this epic's testing — this repo's own convention per `CLAUDE.md` otherwise has no per-epic integration branch; `dev` is not a repo-wide policy change, promotion `dev` → `main` stays human, see Deferred)   **Pre-epic tag:** `pre-epic-loop` — required; this epic changes what the machine may do unsupervised

## Outcome

A shell driver, `bin/epic-loop.sh`, takes the next admitted GitHub issue in a configured repo and
carries it through every phase of dev-epic-workflow as a chain of **fresh headless sessions**:
draft the epic, approve and file it, dispatch each work item, verify the pull request cold against
the plan's definition of done and the issue's acceptance criteria, merge, close the epic and the
issue, then take the next issue. Every phase boundary is a real context boundary — one `claude -p`
session ends by writing `docs/epics/handoff.md`, the next begins by reading it — so no phase
inherits another's beliefs about file state. The driver is deterministic bash and holds no
judgement; the phase sessions hold judgement and no state.

The loop runs **at the rung the repo has been granted** and not one step further. Below L1 it
parks at the proposal PR and waits for a human to approve. Below L3 it parks at the item PR and
waits for a human to merge. At L4 it runs end to end and chains to the next issue. Parking is
resumable: a later cycle picks the issue up wherever the human left it. The ceiling moves from L2
to L4; the promotion-record contract, the denylist floor, `STOP` and `AUTONOMY-OFF` are unchanged
and are checked between every phase.

## Grounding

Inspected this session (via three Sonnet survey agents, verdicts only):
- `references/l2-dispatch.md`, `autonomy-control-surface.md`, `issue-intake.md`,
  `session-handoff.md`, `executor-control-plane.md` — the ladder (L0–L4 defined, ceiling L2),
  the "never" list, the promotion-record contract (seven required fields), admission keys,
  budget keys, revocation files.
- `assets/claude-config/bin/` — `unattended-intake.sh` (L0 drafting, wired to the launchd
  plist), `dispatch.sh` (L2, invokes `claude -p --agent work-item-executor`), `autonomy.sh`,
  `intake-status.sh`, `worktree-provision.sh`, `declared-paths-gate.sh`. None is copied by
  `install.sh`; none writes or reads `handoff.md`.
- Epic 08/09: L1 scored NO-GO at effective n=7 because good drafts correctly deferred to a
  human; epic 09 fixed the named defects but closed "not measured" — the five-hard-brief
  re-measurement never ran.
- Epic 11: code-complete, not closed; two live LODE verifications outstanding (item 2b fresh
  worktree gates; item 3 one real cycle to an open PR).
- Epic 16: in flight (item 3 of 4), replacing the `claude -p --agent` call inside `dispatch.sh`
  with a custom Messages-API loop. Its item 1 found hook firing under a detached `claude -p`
  **partial / not confirmed**.
- `~/.config/claude-intake/repos`: five repos listed; four target `dev`-family integration
  branches, claude-skills targets main. Launchd agent unloaded; `STOP` present.
- `commands/handoff.md` is prompt-only with tool grants — usable as a trailing instruction to a
  headless session.
- Prior art (`gh search repos`): ralph-style single-process loops and continuous-claude
  (create PR → wait for checks → merge). None chains discrete sessions through a file handoff.

Assumptions, not verified:
- A1. SessionStart hooks fire for a `claude -p` process started by a shell script with no Claude
  Code parent. Mitigated by item 3 passing the handoff path in the brief regardless.
- A2. `gh pr merge --merge` from the driver produces a merge commit acceptable to Phase 3 step 9.
- A3. `dispatch.sh`'s external interface (args, exit codes, ledger line) survives epic 16's
  internal replacement. To be pinned by a fixture in item 1.

## Invariants

- A repo with no promotion record behaves exactly as today: L0 drafting only.
- No phase approves, merges, closes or chains unless the repo's granted level permits it; the
  check is made by `autonomy.sh` at the start of every phase, not once per cycle.
- `STOP` and `AUTONOMY-OFF` are honoured between every phase; an in-flight executor is never
  killed, but nothing new starts.
- The sensitive-path denylist floor is not shrinkable; the real diff is checked before merge, not
  only before PR.
- `dispatch.sh`, `unattended-intake.sh`, `work-item-executor` contracts stay stable — this epic
  wraps them, it does not edit their internals (epic 16 owns `dispatch.sh`'s inside).
- Every `claude -p` phase gets the output-discipline rule in its brief.
- claude-skills is item 8's live-proof target (decided on filing — see Log), proposal and item
  PRs opened against `dev`, not `main`. No repo, including claude-skills, is granted L1 or L3 by
  this epic: every phase parks for a human to approve or merge until a promotion record says
  otherwise, so a bad draft or a bad PR stops there rather than reaching `dev` unattended — and
  even a merged `dev` is not live, since promotion to `main` stays a separate human step.
- Nothing in the loop is installed by `install.sh`; the launchd plist stays opt-in.

## Work items

### 1. Driver skeleton and per-issue state machine
- **Branch:** `feat/epic-loop-driver-skeleton`
- **Scope:** `bin/epic-loop.sh` with `--repo`, `--once`, `--max-issues`, `--dry-run`. Per-issue
  state file `docs/epics/.intake/loop/<issue>.json` with states
  `picked → drafting → awaiting-approval → approved → dispatching(item N) → awaiting-verify →
  awaiting-merge → merged(item N) → closing → closed | blocked | refused`. Phase dispatcher that
  reads the state, checks `autonomy.sh` level + `STOP`/`AUTONOMY-OFF` + budget, runs one phase,
  writes the next state, appends a ledger line. Dry-run prints the phases it would run. Fixture
  pins `dispatch.sh`'s CLI interface (A3).
- **Touches:** `Skills/dev-epic-workflow/assets/claude-config/bin/epic-loop.sh` (new),
  `.../hooks/tests/epic-loop-fixtures.sh` (new), `.../bin/dispatch.sh` (read only — interface
  fixture).
- **DoD:** dry-run on the synthetic repo walks an issue through every state with the phase
  commands logged and no Claude invoked; `STOP` between two phases halts with exit 0 and the
  state file unchanged.
- **Not:** any real session; any ladder change.

### 2. Ladder extension — L1 approve, L3 merge, L4 chain
- **Branch:** `feat/autonomy-ladder-l1-l3-l4`
- **Scope:** `AUTONOMY_CEILING=L4`. `autonomy.sh` answers `may-approve`, `may-merge`,
  `may-chain` from the granted level. Promotion records above L2 require `cycles ≥
  promotion.min-cycles.<LEVEL>` counted from the epic-loop ledger. New budget keys
  `budget.max-issues` (default 1) and `budget.max-merges` (default 1). Doc update to
  `autonomy-control-surface.md` and `l2-dispatch.md` naming the new rungs as built.
- **Touches:** `.../bin/autonomy.sh`, `.../hooks/tests/autonomy-fixtures.sh`,
  `references/autonomy-control-surface.md`, `references/l2-dispatch.md`.
- **DoD:** fixtures: L2 record → `may-approve` false; L1 record → true; L3 → `may-merge`;
  forged `granted-by: runner` refused; `AUTONOMY-OFF` pins all three false.
- **Not:** granting any repo a level; measuring L1.

### 3. Phase-session harness and handoff bridge
- **Branch:** `feat/epic-loop-phase-session`
- **Scope:** `bin/phase-session.sh <brief-file>` runs one `claude -p` session with the brief,
  appends the `/handoff` command body as the closing instruction, and afterwards validates
  `docs/epics/handoff.md` (Epic field, Exact next action, Claimed-but-not-verified section). If
  invalid or missing, the driver writes a minimal deterministic handoff from the state file. The
  next brief always names the handoff path explicitly (A1 mitigation). One live probe: does the
  SessionStart injection appear in a `-p` transcript started from launchd-shaped env — reuse
  epic 16 item 1's findings file and extend it rather than repeat it.
- **Touches:** `.../bin/phase-session.sh` (new), `.../bin/epic-loop.sh`,
  `docs/epics/16-*/item-1-hook-firing-findings.md` (append), `.../hooks/tests/phase-session-fixtures.sh`.
- **DoD:** two chained sessions on the synthetic repo — session 2's transcript shows it read the
  handoff session 1 wrote; the validity check rejects a handoff missing Exact next action.
- **Not:** any phase logic beyond running a brief.

### 4. Approval gate (L1)
- **Branch:** `feat/epic-loop-approval-gate`
- **Scope:** after `unattended-intake.sh` opens a proposal PR: if `may-approve` and the draft
  verdict is `ready` (never `no-work` or `needs-decision`), merge the proposal PR, set
  `**Status:** approved`, label `epic:planned`, comment the plan permalink. Otherwise park at
  `awaiting-approval`; later cycles detect the human's merge + `approved` edit and continue.
- **Touches:** `.../bin/epic-loop.sh`, `.../hooks/tests/epic-loop-fixtures.sh`,
  `references/issue-intake.md` (one paragraph: unattended intake's hard stop is now L0's stop).
- **DoD:** fixtures for all three verdicts × two levels; `needs-decision` at L4 still parks.
- **Not:** changing the drafting runner.

### 5. Verify phase — cold acceptance check
- **Branch:** `feat/epic-loop-verify-phase`
- **Scope:** `bin/verify-item.sh`: deterministic gates first (`status.json` shows
  `gates-passed` and `pr-opened`; `declared-paths-gate.sh` clean; `gh pr checks` green; real diff
  vs denylist), then a cold verifier session (brief: item's DoD from plan.md, issue body's
  observed/expected, PR diff) writing `verdict.json` `{pass|fail, criteria:[{text, met,
  evidence}]}` and posting it as a PR comment. Fail → `blocked`, never auto-retried.
- **Touches:** `.../bin/verify-item.sh` (new), `.../agents/acceptance-verifier.md` (new),
  `.../bin/epic-loop.sh`, `.../hooks/tests/verify-item-fixtures.sh`.
- **DoD:** synthetic PR with a deliberately unmet DoD line → `fail` naming that line; clean PR →
  `pass`; missing `gates-passed` → refused before any session starts.
- **Not:** fixing a failed item.

### 6. Merge gate (L3) and within-epic chaining (L4)
- **Branch:** `feat/epic-loop-merge-and-chain`
- **Scope:** on `pass` and `may-merge`: `gh pr merge --merge`, then land-and-reset (Phase 3
  step 10: pull, delete branch remote+local, remove worktree, prune, tick checklist, clean
  `status/`). On `may-chain`: next undispatched item via `dispatch.sh`, respecting the plan's
  dependency rule (predecessor merged, not merely dispatched). Final item's PR body carries
  `Closes #<n>` when `may-merge`; otherwise `Part of #<n>` as today.
- **Touches:** `.../bin/epic-loop.sh`, `.../bin/dispatch.sh` (one flag: `--closing-keyword`),
  `.../hooks/tests/epic-loop-fixtures.sh`.
- **DoD:** synthetic two-item epic at L4 lands both with merge commits, worktrees gone,
  checklist ticked; same epic at L2 parks at item 1's PR.
- **Not:** merging to live.

### 7. Close phase
- **Branch:** `feat/epic-loop-close-phase`
- **Scope:** when every item is merged: set `**Status:** closed` and land it on the integration
  branch first (Phase 5 ordering, GH #41), retro comment on the issue built from the ledger,
  remove `status/`, `CANCEL`, `active-epic`, `handoff.md` if it names this epic; `gh issue close`
  only if the final PR did not already close it.
- **Touches:** `.../bin/epic-loop.sh`, `.../hooks/tests/epic-loop-fixtures.sh`.
- **DoD:** after close on the synthetic repo, `plan.md` header reads closed on integration,
  `git worktree list` shows main only, issue state closed, no stale pointer.
- **Not:** tagging a release (stays human).

### 8. Next-issue loop, entry points, runbook, live proof
- **Branch:** `feat/epic-loop-entry-and-live-proof`
- **Scope:** bounded iteration over admitted issues (`budget.max-issues`); launchd plist
  `com.jonathanstevenson.epic-loop.plist` opt-in beside the existing one; SessionStart injection
  gains one line of loop state per parked issue; runbook `DOCS/runbooks/epic-loop.md`. Live proof:
  one real issue on claude-skills, walked through every phase by the driver, PRs opened against
  `dev`, parking for Jonathan's approval and merge at each step since neither L1 nor L3 is
  granted here.
- **Touches:** `.../bin/epic-loop.sh`, `.../launchd/com.jonathanstevenson.epic-loop.plist`
  (new), `.../hooks/session-start-context.sh`, `.../hooks/tests/session-start-fixtures.sh`,
  `DOCS/runbooks/epic-loop.md` (new), `SKILL.md` (reference list entry).
- **DoD:** the live issue's plan, PR, verdict comment, merge commit and closed issue all exist on
  origin; the ledger shows one cycle; `STOP` mid-cycle halts the next phase.
- **Not:** loading the plist.

## Sequence

1 → 2 → 3 (independent after 1; 2 and 3 can run in parallel) → 4 → 5 → 6 → 7 → 8.
Item 8's live proof requires epic 11's two outstanding live verifications to have run first, or
it becomes the third. Epic 16 proceeds independently behind `dispatch.sh`'s interface.

## Risks

- **Auto-approve without measurement.** L1 was NO-GO at n=7 and never re-measured. Rollback: no
  repo is granted L1 by this epic; a promotion record is a human file, removable with `rm`.
- **Verifier passes a bad PR.** Rollback: merge commit revert; `budget.max-merges` default 1
  caps blast radius per cycle.
- **Hook does not fire under -p** (A1). Rollback: the explicit handoff path in every brief makes
  the injection redundant rather than required.
- **Runaway loop.** Rollback: `STOP` (no cycle starts), `AUTONOMY-OFF` (everything pins to L0),
  both checked between phases; budgets per cycle.
- **Driver merges on a shared checkout.** Mitigation: the driver works in the repo's main
  checkout only via `gh` and `git pull`; executors stay in worktrees.
- **Live proof runs on claude-skills.** Mitigation: item 8's proposal and item PRs target `dev`,
  not `main`, so a merged PR is not live — reaching `main` needs a separate human promotion step
  (Deferred). L1 and L3 both default to wait for this repo besides (no promotion record exists
  for any repo today), so nothing merges to `dev` without Jonathan's explicit approve/merge
  either.

## Deferred / out of scope

- Re-measuring L1 against five hard briefs (epic 09 item 5) — needed before anyone should grant
  L1 on a real repo; its own epic with a brief-sourcing plan.
- Retrying a `blocked` or `fail` item with the verdict fed back to a new executor.
- Promotion to live (merge integration → main) stays human at every rung.
- Azure DevOps source; this epic is GitHub only.
- Replacing bash with the Agent SDK; epic 16 owns the executor internals.

## Log

- 2026-09-10: decisions resolved before filing —
  - Approval default (L1): wait. No repo is granted L1 by this epic; the gate exists but every
    proposal PR parks at `awaiting-approval` for a human merge.
  - Merge default (L3): wait. No repo is granted L3 by this epic; every item PR parks at
    `awaiting-merge`.
  - First target / live-proof repo (item 8): claude-skills, overriding the earlier
    fusion-sql-mcp/Oracle-Simple-Convert recommendation — Jonathan is less concerned about
    breaking this repo than about the "Jonathan tests all live loads" constraint on
    Oracle-Simple-Convert. The invariant excluding claude-skills was removed; safety instead
    comes from L1/L3 both defaulting to wait (see Risks).
  - Verifier model: Opus for the verify phase (item 5); Sonnet for every other phase — draft
    recommendation adopted without objection.
  - Ordering: file now; dispatch items 1–3 now (neither touches `dispatch.sh` internals or
    needs a live repo). Item 8's live proof still waits on epic 11's two outstanding live
    verifications per Sequence.
  - Integration branch (item 8 / claude-skills): `dev`, not `main`. `dev` was pushed from
    `main`'s tip (09bcf5a) directly to origin, scoped to this epic's testing; `CLAUDE.md`'s
    "no per-epic integration branch" convention is unchanged repo-wide, this is a one-off
    exception. Every Risks/Invariants mention of "reaching main" updated to "reaching dev";
    dev → main promotion stays human and undecided (Deferred).
