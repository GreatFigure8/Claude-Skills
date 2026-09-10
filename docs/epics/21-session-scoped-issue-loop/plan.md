# Epic: session-scoped autonomous issue loop

**Status:** in flight (item 6 of 6)
**Live branch:** main
**Integration branch:** main
**Pre-epic tag:** pre-loop-redesign

## Outcome
Jonathan opens a live Claude Code session, names a repo, and says "start the loop." From
that point the session itself — not a daemon, not a subprocess chain, not an API-keyed
background process — continuously works admitted GitHub issues end to end: draft a plan
from the issue's stated requirements and acceptance criteria, dispatch each work item,
verify it, run a harm check, merge, chain to the next item and then the next issue,
close out, and repeat — with no approval stops and no promotion-ladder tiers, because
starting the loop *is* the grant of full autonomy. The only in-flight brake is a harm
check before any merge or chain action. When the loop's own gates turn up a failure out
of the current item's scope — failing tests, lint/typecheck, compilation, or a post-merge
integration check — it files a new GitHub issue instead of silently absorbing the scope
creep, then keeps going. The loop runs until Jonathan says stop or closes the client.

## Grounding
- Verified: `epic-loop.sh`, `autonomy.sh`, `dispatch.sh`, `phase-session.sh`,
  `verify-item.sh` all live in `Skills/dev-epic-workflow/assets/claude-config/bin/` —
  shared skill infrastructure installed into every repo running dev-epic-workflow, not
  code local to this repo.
- Verified: `epic-loop.sh` is single-pass (`--once` is the only mode); re-triggering for
  the next issue was always meant to come from an external cron/launchd trigger
  (unbuilt item 8 of epic 19). No continuous or self-pacing mechanism exists anywhere in
  the repo — grepped for `ScheduleWakeup`, self-pacing, dynamic-loop: zero hits.
- Verified: `phase-session.sh` spawns one detached `claude -p` subprocess per phase,
  polls it with a timeout/kill, and coordinates phases only through a disk handoff file.
- Verified: `verify-item.sh`'s "verify" is 4 deterministic checks (PR status, path
  denylist, `gh pr checks` green, diff-vs-denylist) plus a cold Opus judgment read of the
  diff against the DoD — it never executes an integration test suite. No such concept
  exists in the codebase today.
- Verified: zero `gh issue create` calls anywhere in `bin/` or hook code — auto-filing on
  failure is net-new.
- Verified: the L0–L4 promotion-record ladder (`~/.config/claude-intake/promotions/*`) is
  threaded through every gate in `autonomy.sh`/`dispatch.sh`/`epic-loop.sh`; no promotion
  record has ever existed on this machine — the ladder has never actually run live.
- Verified: `autonomy.sh` also defines a sensitive-path denylist, a size ceiling, and the
  `STOP`/`AUTONOMY-OFF` kill files — these are independent of the ladder and are reused
  here as the harm floor (see Item 2), not retired.
- Verified (this session): `main` and `dev` had zero divergence in `main`'s favor (`dev`
  was a clean 28-commit fast-forward ahead) — `dev` was collapsed into `main` and deleted
  as this epic's step zero, tagged `pre-loop-redesign` beforehand.
- Assumed: the orchestrated dev-epic-workflow path (interactive session dispatching
  `work-item-executor` via the `Agent` tool) is unaffected by any of this — it doesn't
  touch the ladder/daemon code being retired. Confirmed by inspection, not exercised
  live in this epic.
- Assumed: the `loop` skill's `ScheduleWakeup` mechanism is suitable as the self-pacing
  primitive for Item 3 — not yet prototyped against a multi-hour, multi-issue run.

## Invariants
- The default interactive dev-epic-workflow (plan → approve → dispatch → verify → merge,
  one human-supervised step at a time) keeps working unchanged for every session that
  hasn't explicitly started the loop. Full autonomy is opt-in per session, never ambient.
- The loop only ever admits an issue that carries explicit, human-authored detailed
  requirements and detailed acceptance criteria. An issue missing either is drafted and
  parked, not autonomously executed — it isn't "admitted" in the sense this epic means.
- The harm check (Item 2) runs before every merge and every chain action, with no
  exception, even at full autonomy.
- No API keys, no background daemon, no per-repo promotion-record files are introduced.
  The loop only ever runs inside a live, already-authenticated interactive session.
- Auto-filed issues are deduplicated by fingerprint before filing — the loop never floods
  the tracker with repeats of the same discovered failure.

## Work items

### 0. Reconcile the divergent branch (step zero, not a work item) — DONE
`dev` carried epic 19's 7 merged items (ladder extension, phase-session harness,
verify-item, approval/merge/close gates) that `main` didn't have. Tagged `main`'s prior
commit as `pre-loop-redesign`, fast-forwarded `main` to `dev`'s tip, pushed, and deleted
`dev` (local and remote) — matching this repo's own convention that `main` is both the
integration and live branch. Completed at filing time, 2026-09-10.

### 1. Retire the promotion-ladder and daemon-trigger surface — DONE (PR #106, merged ceb5c80)
- **Branch:** `refactor/retire-autonomy-ladder`
- **Depends on:** none (after step 0)
- **Scope:** In `autonomy.sh`, remove the L0/L1/L3 tiers, the promotion-record
  read/write functions, and `autonomy_may_approve`/`_merge`/`_chain`; keep the denylist,
  size-ceiling, and `STOP`/`AUTONOMY-OFF` functions intact — they become the harm floor
  in Item 2. Retire `dispatch.sh`'s L2 exact-match daemon path and the
  `com.jonathanstevenson.epic-loop.plist`/unattended-intake launchd wiring.
  Retire `phase-session.sh`'s role as the phase-chaining mechanism (its `claude -p`
  spawn+poll function may be kept as a drafting-phase utility — decide in-item, don't
  carry it forward by default). Retire `epic-loop.sh`'s single-pass state machine as the
  daemon entry point (its phase gate logic is source material for Item 3, not code that
  survives unchanged). Set epic 11's and epic 19's plan headers to `closed`, each with a
  one-paragraph retro noting supersession by this epic.
- **Touches:**
  - `Skills/dev-epic-workflow/assets/claude-config/bin/autonomy.sh`
  - `Skills/dev-epic-workflow/assets/claude-config/bin/dispatch.sh`
  - `Skills/dev-epic-workflow/assets/claude-config/bin/phase-session.sh`
  - `Skills/dev-epic-workflow/assets/claude-config/bin/epic-loop.sh`
  - `Skills/dev-epic-workflow/assets/claude-config/launchd/com.jonathanstevenson.epic-loop.plist`
  - `Skills/dev-epic-workflow/references/autonomy-control-surface.md`
  - `Skills/dev-epic-workflow/references/l2-dispatch.md`
  - `docs/epics/11-l2-autonomous-dispatch/plan.md`
  - `docs/epics/19-epic-loop/plan.md`
- **Not in scope:** touching the orchestrated `Agent`-tool dispatch path or
  `work-item-executor.md` — unaffected by the ladder's removal.
- **Definition of done:** no code under `bin/` reads or writes a promotion-record path;
  `autonomy_may_approve/_merge/_chain` no longer exist; no launchd plist references
  epic-loop; both superseded plans show `**Status:** closed` with a retro.
- **Verification:** `grep -rn "promotion" Skills/dev-epic-workflow/assets/claude-config/bin/` returns nothing; `grep -rln "may_approve\|may_merge\|may_chain"` returns nothing.
- **Rollback:** revert the merge commit; `pre-loop-redesign` tag restores prior state.

### 2. Define the harm floor — DONE (PR #107, merged 4569c56)
- **Branch:** `feat/harm-floor-check`
- **Depends on:** item 1
- **Scope:** A single callable (e.g. `autonomy_harm_check()`) combining the surviving
  denylist, size-ceiling, and STOP checks from Item 1 with two new guards: an
  irreversible-git-op guard (refuses force-push or hard-reset against any shared branch)
  and a cross-epic collision guard (refuses acting on a branch/worktree another in-flight
  epic owns). Returns pass/fail plus a human-readable reason.
- **Not in scope:** any judgment-based ("does this look risky") layer — that's the cold
  verifier in Item 3/5, not this deterministic floor.
- **Definition of done:** the function exists, is called from a single well-known entry
  point, and each guard has a fixture proving it fires.
- **Verification:** fixtures pass for each of: denylist hit, size ceiling exceeded, STOP
  present, force-push attempt, cross-epic collision.
- **Rollback:** drop the branch; nothing else depends on it yet.

### 3. The loop entry point — session-scoped driver — DONE (PR #108, merged e25ba20)
- **Branch:** `feat/session-loop-driver`
- **Depends on:** items 1, 2
- **Scope:** A new entry (skill or slash command) that, invoked in a live session
  ("start the loop on `<repo>`"), begins continuously processing admitted issues for that
  repo: polls `gh issue list` for issues carrying detailed requirements + acceptance
  criteria, drafts a plan in-session for any that don't have one yet (reusing
  unattended-intake's drafting logic directly, not headlessly), dispatches each work item
  via the existing orchestrated `work-item-executor` path — unchanged — runs Item 2's
  harm check before every merge/chain, auto-merges on pass, auto-chains within the issue
  and then to the next admitted issue, and self-paces across turns using the `loop`
  skill's `ScheduleWakeup` pattern so it survives until Jonathan says stop or the session
  ends. No approval stop between draft and dispatch — starting the loop is the approval.
- **Not in scope:** headless/unattended operation; multi-repo simultaneous loops (one
  loop, one repo, one live session, per Jonathan's own framing).
- **Definition of done:** given one admitted issue, the loop drafts, dispatches every
  item, verifies, harm-checks, merges, chains, closes the issue, and moves to the next
  admitted issue without stopping for Jonathan; a spoken/typed stop halts it before the
  next action.
- **Verification:** dry-run against ≥2 seeded issues shows correct chaining and a clean
  stop.
- **Rollback:** the entry point is additive; removing it restores today's manual dispatch
  flow untouched.

### 4. Failure-driven issue filing — DONE (PR #109, merged b4789da)
- **Branch:** `feat/loop-files-failure-issues`
- **Depends on:** item 3
- **Scope:** When a gate fails in a way that's out of the current item's own scope —
  persistent failure after retry, or something discovered incidentally while working a
  different item — file a new GitHub issue: search open issues labeled
  `epic-loop-filed` for a matching fingerprint first and skip if found; otherwise file
  with a body naming the discovering issue/item, the failing check, and evidence, labeled
  `epic-loop-filed`. This automates the workflow's existing "scope grows mid-item → split
  into a new item" rule instead of the loop stopping to ask.
- **Not in scope:** auto-fixing the discovery — filing is the terminal action; the fix is
  a future loop cycle picking up the new issue.
- **Definition of done:** a seeded failure produces exactly one filed issue; re-seeding
  the same failure produces zero new issues.
- **Verification:** fixture run demonstrates both cases.
- **Rollback:** drop the branch; the loop falls back to surfacing failures in its own
  run log only.

### 5. Per-issue integration testing — DONE (PR #110, merged f2b581b)
- **Branch:** `feat/per-issue-integration-test`
- **Depends on:** items 1, 4
- **Scope:** After all of an issue's items are merged and before it's closed, run one
  integration/e2e check for the issue as a whole — reusing the worktree-provisioning
  "declared gate" pattern: a repo declares its integration-test command; where none is
  declared, run the stack's existing gates as the closest available check and note the
  gap in Deferred rather than inventing a check. A failure here routes through Item 4's
  filing path.
- **Definition of done:** a repo with a declared integration command gets it run once per
  issue, post-merge, pre-close; failure produces a filed issue via Item 4.
- **Verification:** one seeded pass and one seeded fail, on a repo with a declared
  command.
- **Rollback:** drop the branch; issues close without the extra check, as today.

### 6. Runbook and live proof
- **Branch:** `docs/loop-runbook-and-live-proof`
- **Depends on:** items 3, 4, 5
- **Scope:** Write `DOCS/runbooks/session-loop.md` — how to start/stop the loop, what the
  harm floor checks, what gets auto-filed and why, and the admission precondition
  (requirements + acceptance criteria required). Add the reference to `SKILL.md`. Run one
  real end-to-end issue on claude-skills through the full pipeline — draft, dispatch,
  verify, harm-check, merge, chain, close — with one deliberately seeded failure
  correctly filed as a new issue and not duplicated.
- **Definition of done:** the runbook exists and is accurate against the live proof run;
  the live proof issue closes cleanly; the seeded failure exists as exactly one filed
  issue.
- **Verification:** the live proof issue and its filed follow-up issue, inspected
  directly on GitHub.
- **Rollback:** n/a — documentation and a live run, nothing to revert structurally.

## Sequence
0 (branch reconciliation, done) → 1 → 2 → 3 → 4 → 5 → 6. Mostly serial: each item's
driver or filing logic assumes the previous item's primitive already exists.

## Risks
| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Retiring shared skill code (Item 1) breaks another repo's interactive dispatch | Low | High — affects every repo running dev-epic-workflow | Only the unused ladder/promotion/daemon paths are removed; the orchestrated `Agent`-tool dispatch path every repo actually uses today is untouched |
| Harm floor under-defined lets a bad merge through | Medium | High | Item 2 ships with a fixture per guard; Item 6's live proof exercises it for real before this is trusted |
| Auto-filed issues flood the tracker | Medium | Medium | Item 4's dedup-by-fingerprint check runs before every filing |
| Full autonomy without a plan-approval stop is a real departure from the skill's normal human-gate default | Medium | Medium | Strictly scoped to sessions where Jonathan explicitly started the loop (Invariants); default sessions are unaffected |

## Deferred / out of scope
- Headless/unattended loop operation (the exact thing being retired) — may resurface as
  its own epic later if a real need appears; not reintroduced here.
- Multiple repos looping simultaneously from one session.
- Auto-fixing incidentally discovered failures rather than filing them.
- Issues filed by `issue-filer.sh` (Item 4) carry only `epic-loop-filed`, not the
  `epic-loop-ready` admission label — a future loop cycle can't autonomously pick one back
  up without a human adding requirements/acceptance-criteria and the admission label. The
  plan's "the fix is a future loop cycle picking up the new issue" line assumes that gap
  closes somehow; needs a decision before Item 6's live-proof run treats it as closed-loop.
- `run-all-fixtures.sh` hangs indefinitely on `active-epic-fixtures.sh` (observed during
  Item 4's verification, unrelated to that item's diff) — flagged, not diagnosed or fixed.
- A repo that declares neither `integration-test` nor any `gates.<type>` gets no per-issue
  integration check at all (Item 5) — the loop notes the gap at runtime but nothing closes
  it short of the repo owner declaring one.
- `worktree-provision-fixtures.sh` carries 2 pre-existing failures on `main`, independently
  reconfirmed unchanged (178→192 cases, still 2 failures) across Item 5 — same finding as
  Item 3's cold-verification note; still not filed as a tracked follow-on.

## Log
- 2026-09-10 — plan approved and filed as epic 21. Step 0 (branch reconciliation)
  completed at filing time: `main` fast-forwarded to absorb `dev`'s 28 commits, tagged
  `pre-loop-redesign` beforehand, `dev` deleted.
