# Epic: L2 — approved work reaches a pull request without a human

**Status:** in flight (item 1 of 4)
**Source:** GH #39 — the third epic on this issue. Epic 08 designed the ladder and stopped at its
measurement on a NO-GO; epic 09 fixed the four defects that verdict named; this one builds the
one rung the evidence actually supports.
**Live branch:** `main`   **Integration branch:** `main`   **Pre-epic tag:** `pre-l2-dispatch` — required; this epic changes what the machine may do unsupervised

## Outcome

An epic that a human has approved runs to a pull request without one. A scheduled runner finds the
next undispatched work item of an approved epic, admits or refuses it against a policy, cuts its
worktree, invokes `work-item-executor` headlessly, and **stops at the pull request**. Every cycle
is written to a ledger a human can read with `cat`, and the whole thing can be revoked with a
single file that answers to `ls`.

**L1 and L3 are explicitly not built here.** The runner never approves a plan and never merges a
pull request. Approval stays a human act because it is the one thing still measured NO-GO;
merging stays a human act because L3 without L2's track record is an accelerator before brakes.

## Grounding

Verified on 2026-08-21. Each line names how.

- **Verified — the ladder's design exists and was never built.** `docs/epics/08-autonomous-mode/plan.md`
  items 2–8 carry full scope and definitions of done, marked `NOT DISPATCHED` and preserved
  verbatim as the design record. This epic is items 2, 3, 4 and 6 of that record, re-scoped: L1
  (its item 5) is skipped, and L3 (item 7) and the digest (item 8) are deferred.
- **Verified — the headless-runner pattern already works in this repo.** `unattended-intake.sh`
  invokes `claude -p` inside a git worktree under a narrow `--allowed-tools` allowlist and has
  been running on a timer all day without incident. The L2 runner is that shape with a wider
  allowlist, which is precisely why it needs its own admission policy rather than inheriting one.
- **Verified — `claude -p` accepts `--agent <name>`.** So the runner invokes `work-item-executor`
  **by name** and does not re-inline or fork its contract. Confirmed from `claude --help`.
- **Verified — the automation is user-level and sourced from this repo.** `~/.claude/hooks/` and
  `~/.claude/agents/work-item-executor.md` are installed; LODE's own `.claude/` carries only
  `launch.json` and no hooks. The launchd agent executes **this repo's working copy** directly, so
  **a merge to `main` is a deploy** — items 2, 3, 4, 6, 7 and 8 of epic 09 all went live that way
  today.
- **Verified — LODE is ready to be the first target.** Integration `dev`, live `main`, gate
  `bash scripts/test-both.sh`, both containers (`fieldwire-adb`, `fieldwire-pg`) up and healthy.
  **Five approved, undispatched epics are queued** — 174, 175, 178, 179, 182 — and two are in
  flight. The queue is real work, not a fixture.
- **Verified — there is no machine-readable record of which work items are done.** LODE marks it
  in prose: `### 1. The UI knows the template's family — DONE (PR #842)`. **The runner must not
  parse that**, and item 3 says what it does instead.
- **Verified — a concurrency hazard exists and may already be fixed.** LODE's `CLAUDE.md` warns
  that concurrent executors collide on the local Oracle container during `test-both.sh`. GH #801
  merged today as `fix/801-serialize-the-test-database`. **Whether that fully removes the hazard
  is NOT verified**, and this epic does not depend on it: serialization is a design decision here,
  not a workaround.
- **Verified — the executor evidence, stated with its sample size.** **Eight** work items have now
  been executed by `work-item-executor` subagents on `claude-skills`: seven landed (items 1, 2, 3,
  4, 6, 7, 8 of epic 09) and one correctly returned `blocked` rather than resolving an ambiguous
  plan clause. Three contradicted their own dispatch instructions where the instructions were
  wrong. Gates went 879 → 1297 cases with zero failures at every merge. **This is all on one repo
  and one stack.** The first LODE dispatch was in flight when this plan was written and its result
  is **not** part of this evidence.
- **Assumed — that an executor which behaves on bash-and-fixtures behaves on pnpm/TypeScript with a
  real database.** Unproven. Item 3's definition of done requires it to be proven on LODE before
  the rung is enabled anywhere.

## Invariants

- **The runner never approves and never merges.** Approval and merge remain human acts for the
  whole life of this epic. Any commit that weakens this is a defect, not a feature.
- **Ships inert.** A repo with no autonomy configuration behaves byte-identically to today, and
  L0 unattended drafting keeps working throughout.
- **The kill switch answers to `ls`.** Revocation must never require opening a session, reading
  config, or knowing which repo is configured.
- **No rung above L0 without config *and* evidence.** A level set without a promotion record is
  refused, naming what is missing — brakes are structural, not disciplinary.
- **The live branch is never written to.** L2's ceiling is a pull request against the
  integration branch.
- **One item at a time.** Serialized by design, not by accident of load.

## Work items

### 1. The control surface, shipped inert
- **Branch:** `feat/autonomy-control-surface`
- **Depends on:** none
- **Scope:** Per-repo autonomy level in the intake config, and the policy that governs it:
  required labels, forbidden labels, an **explicit sensitive-path denylist**, and a size ceiling.
  Plus two controls that are not the same thing and must not be merged: a **global override file**
  whose mere presence pins every repo to L0 while leaving drafting alive, and a **cycle stop file**
  that prevents a cycle starting at all. Plus a per-cycle budget (max items dispatched, max
  wall-clock). Everything is parsed, validated and logged; **nothing reads it to act yet.**
- **The denylist must be checked against the real diff, not a declaration.** A work item's plan
  says what it intends to touch in prose, and epic 10 exists because that is not machine-readable.
  So the denylist is enforced **after the executor returns and before the PR is opened**, against
  `git diff --name-only`. A declaration-based check would be checking the wrong thing.
- **Not in scope:** acting on any level; the ledger (item 2). This item defines the promotion-record
  contract item 2 will write and item 3 will read.
- **Definition of done:** config parses with clear errors on malformed input; an unconfigured repo
  is byte-identical to today, proven by fixture; the global override forces L0 from any configured
  level, proven by fixture; the stop file prevents a cycle and is loud in the log; a diff touching
  a denylisted path is refused with the path named.
- **Verification:** fixtures for each control; a `--dry-run` across all four configured repos
  showing every one still resolving and still at L0.
- **Rollback:** revert; nothing read the config anyway.

### 2. The ledger, and a status surface that needs no session
- **Branch:** `feat/autonomy-ledger`
- **Depends on:** 1
- **Scope:** An append-only `~/.config/claude-intake/ledger.jsonl`, outside any repo, one record
  per state transition: cycle start, item admitted, item refused with reason, executor started,
  executor returned, PR opened, error. Plus a `--status` view that renders it without a session.
  **This is how a human watches the thing run**, and it is the source of truth for the promotion
  records item 1 defined.
- **Not in scope:** the digest (deferred); any UI.
- **Definition of done:** every transition appears exactly once; the ledger survives a killed run
  mid-cycle without corruption; `--status` is accurate against the repo and the ledger together;
  a refused item states which policy refused it.
- **Verification:** fixtures including a `SIGKILL` mid-cycle; a replay comparing ledger against
  actual branches and PRs.
- **Rollback:** revert; the log file remains and is harmless.

### 2b. A dispatched worktree can actually run the gates
- **Branch:** `feat/autonomy-worktree-provisioning`
- **Depends on:** 1
- **Why this exists — measured on the first LODE dispatch, 2026-08-21, not anticipated.** A fresh
  `git worktree add` on LODE produces a checkout that **cannot run the test suite**: `.env` is
  gitignored (`.gitignore:100`, verified) and `api/config.py` reads it from the repo root, and
  `node_modules` is per-worktree and absent. The attended executor hit
  `7 failed, 1554 passed, 9 errors — RuntimeError: DB_PASSWORD is not set` on its first gate run
  and recovered by copying `.env` and installing. **An unattended executor would not have that
  nerve.** The failure looks exactly like a broken change, so the likely outcomes are a false
  `blocked`, a false red PR, or — worst — a run that reports "gates skipped" and opens the PR
  anyway. This is the single biggest blocker to unattended dispatch on this repo.
- **Scope:** worktree provisioning as an explicit, per-repo, declared step: copy the gitignored
  environment files the repo names, run the repo's declared install command, and **verify the gate
  can run before the executor is invoked** — a smoke check, not a hope. A repo that declares
  nothing gets today's behaviour: a bare worktree.
- **Second finding, same dispatch: the gate set is per item type, not per repo.** LODE's
  `scripts/test-both.sh` is `ruff` + `pytest` twice and covers **zero TypeScript** (verified by
  reading it). It runs none of the tests covering a `.tsx` item; every test that could catch a
  regression there is in `pnpm --filter web test`. **My own dispatch brief said "the gate is
  `test-both.sh`" and was wrong**, and the executor ran the right gates from repo precedent rather
  than from instruction. An unattended runner has no such judgement, so the gate set must be
  declared per item type and passed in the brief.
- **Not in scope:** the executor's own gate discipline; changing any repo's gate scripts.
- **Definition of done:** a freshly-created LODE worktree runs `bash scripts/test-both.sh` **and**
  `pnpm --filter web test` green with no manual step; the pre-flight smoke check fails loudly and
  refuses to dispatch when provisioning did not work; a repo declaring no provisioning is
  byte-identical to today.
- **Verification:** create a worktree from clean, run the declared gates, and diff the result
  against the attended run's numbers (oracle 2385 / postgres 2384 / web 1166).
- **Rollback:** revert; worktrees are bare again and unattended dispatch is refused rather than
  silently broken.

### 3. L2 — dispatch to a pull request, and stop
- **Branch:** `feat/autonomy-l2-dispatch`
- **Depends on:** 1, 2, 2b
- **Scope:** At L2, for each configured repo in turn, find the **next undispatched work item of an
  epic at `Status: approved` or `in flight`**, admit it against item 1's policy, cut its worktree
  from the integration branch, invoke `claude -p --agent work-item-executor` with the item's
  dispatch brief, wait, enforce the denylist against the real diff, and open the PR. **Then stop.**
  One item per cycle, serialized — no parallel executors, because the gate contends on a shared
  database container.
- **How "undispatched" is decided, and it is not by parsing prose.** Every work item's plan entry
  carries a `- **Branch:** \`name\`` line, which **is** machine-readable. An item is dispatchable
  iff no branch of that name exists on `origin` **and** no open-or-merged PR has it as head. This
  reuses exactly the signals epic 09 items 7 and 8 already built and tested, and it means a
  `DONE (PR #842)` prose marker is never read. If the `Branch:` line is missing, the item is
  **refused**, not guessed at.
- **Not in scope:** approving a plan (L1), merging a PR (L3), closing an issue, chaining to a new
  issue (L4), and the digest. The runner stops at `pr-opened` exactly as a dispatched executor does
  today.
- **Definition of done:** a full unattended cycle on **LODE** takes one approved epic's next item
  from queue to open PR against `dev` with no human action, with the gate actually run; an item
  whose diff touches a denylisted path is refused after execution and its branch left for a human;
  an executor returning `blocked` is recorded and the epic is left alone rather than retried; the
  budget stops a cycle mid-queue and says so; the global override reduces the whole thing to L0
  mid-flight; **and the first LODE run is compared against the same item executed attended.**
- **Verification:** the live LODE cycle end to end, plus fixtures for refusal, blocked, budget and
  override. The PR it opens is reviewed cold by a human against the plan, exactly as an attended
  item is.
- **Rollback:** set the repo's level to L0, or drop the global override file in place. Both revoke
  without touching code. Reverting the merge is the permanent version.

## Sequence

**1 → (2 ∥ 2b) → 3.** Serial where it matters, and the order is the point: **brakes before accelerator.** The
control surface and the ledger both ship inert and are worth nothing on their own — which is
exactly why they must land before the thing that acts, rather than after it in a follow-up nobody
prioritises once the feature works.

Item 3 is the only item that changes behaviour. It is also the only one that can do damage, and it
is last.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| An unattended executor writes bad code | **High** — it will happen | A bad PR against the integration branch | The PR *is* the gate. Nothing merges. This is the whole reason L3 is not in this epic |
| An executor touches a sensitive path | Medium | Migrations, CI or deploy config changed unattended | Denylist enforced against the **real diff** before the PR opens; the branch is left for a human rather than deleted |
| Runaway — the runner dispatches the whole queue | Medium | Token spend; many open PRs | Per-cycle budget (items and wall-clock); one item per cycle; serialized |
| Concurrent gate runs corrupt the shared container | Medium | A false red, or a wedged database | Serialization is a design invariant here, not a reliance on GH #801 being fixed |
| The runner mis-identifies which item is next and re-dispatches done work | Medium | A duplicate branch and PR | Branch-and-PR existence, never prose parsing. Refuse rather than guess when the `Branch:` line is absent |
| **Evidence is from one repo and one stack** | **Known-real** | L2 enabled on a stack where the executor has never worked | Item 3's DoD requires a proven LODE cycle; the first LODE dispatch is deliberately excluded from the evidence base above |
| A merge to `main` deploys this instantly | **Certain** | The runner changes under a live timer | Ships inert behind config; the global override is one `touch` away; and the pre-epic tag exists |
| Autonomy creeps upward once L2 works | Medium | L3 or L1 enabled without their own evidence | Enablement requires a promotion record, written by a human action and never by the automation |

## Open questions

- **What should a cycle do when an executor returns `blocked`?** Leaning: record it, leave the epic
  alone, and move to the next repo — never retry, because the block is by definition something the
  automation cannot resolve. An unattended retry loop on an ambiguous plan is the worst available
  behaviour.
- **One epic at a time, or one item from each of several epics?** Leaning one item per cycle
  overall, which is the most conservative reading of "serialized" and the easiest to watch.
- **Does a refused item get its label or state changed**, or is refusal ledger-only? A skip that is
  invisible in the tracker repeats the "silent skip" defect epic 09 spent four items removing.
- **How many clean L2 cycles constitute the promotion record for L3?** Needs a number before L3 is
  ever filed, and it should be chosen before anyone wants the answer to be small.

## Deferred / out of scope

- **L1 — auto-approve and file.** Epic 08's item 5. Still measured NO-GO, and epic 09 item 5 cannot
  re-measure it because no genuinely under-specified briefs exist in either backlog. Not built
  here, and not on a schedule.
- **L3 — auto-merge on green with automatic revert**, and **L4 — chaining**. Epic 08 items 7 and
  the L4 rung. Both wait on L2 having a track record.
- **The digest.** Epic 08 item 8. The ledger plus `--status` covers watching it run; a periodic
  summary is a convenience, not a control.
- **Machine-readable declared paths.** Epic 10 (`docs/epics/10-declared-paths/`) — it would let the
  denylist be checked *before* execution rather than after, which is strictly better. This epic
  works without it deliberately, so the two are not coupled.
- **Whether GH #801 fully fixed the container contention.** Unverified and deliberately not relied
  on.

## Log
- 2026-08-21 — drafted and filed. Scope set by three decisions Jonathan made before drafting:
  **ceiling at L2** (dispatch, code, test, PR, stop), **admission = approved epics minus sensitive
  paths**, and **serialized, one item at a time**. Grounded by reading epic 08's preserved design
  record, `unattended-intake.sh`'s headless pattern, `claude --help` for `--agent`, LODE's epic
  queue and gate, and the install layout. **Two grounding findings shaped work items rather than
  footnotes:** `claude -p --agent` means the executor contract is invoked by name and never forked,
  and there is no machine-readable record of which work items are done — so item 3 decides
  dispatchability from the `Branch:` line plus branch/PR existence, reusing epic 09 items 7 and 8,
  instead of parsing `DONE (PR #842)` out of prose.
- 2026-08-21 — **the first executor run on LODE landed at `pr-opened` (PR #857) and produced four
  findings that became requirements, not footnotes.** Verified cold: 2 files, +291/−54, base `dev`,
  `Part of #832` once, no closing keyword; `LoadPanel.test.tsx` re-run by the orchestrator gives
  46/46. **(1)** A fresh worktree cannot run the gates — `.env` is gitignored and `node_modules` is
  per-worktree — which became **item 2b**. **(2)** `test-both.sh` covers zero TypeScript, so the
  gate set is per item type and the dispatch brief that said otherwise was mine and was wrong;
  also item 2b. **(3)** `dev` moved under the executor mid-item: epic 180 item 4 (PR #854) merged
  and rewrote both files, forcing a 3-conflict rebase. **Epics 179 and 180 both own
  `LoadPanel.tsx`, and 179 items 2 and 3 will collide with 180 again** — epic 09 item 4's collision
  detection covers *proposals*, not two in-flight epics, so this is uncovered. **(4)** The plan's
  `:60` line anchor was stale before the item started, pushed to ~`:119` by epic 180. Line-number
  anchors in plans rot within days on an active file.
- 2026-08-21 — **the assumption item 3 rests on is now supported rather than assumed.** An executor
  proven on bash-and-fixtures did behave on pnpm/TypeScript against a real database: it recovered
  from a provisioning failure instead of reporting a false blocked, ran the correct gates despite
  being told the wrong ones, survived a mid-item rebase into the same file, and reported all four
  problems unprompted. **n=1 on this stack.** That is enough to keep building and not enough to
  enable the rung, which is exactly what item 3's definition of done already says.
