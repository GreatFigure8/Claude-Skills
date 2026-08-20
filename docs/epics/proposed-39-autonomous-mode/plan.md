# Epic: autonomous mode — from label to merged code without a human gate

**Status:** planning
**Source:** GH #39
**Live branch:** per-repo (`main` here, `main` for LODE)   **Integration branch:** per-repo (`main` here, `dev` for LODE)   **Pre-epic tag:** `pre-autonomous-mode` (required — this epic changes what the machine may do unsupervised)

## Outcome

The workflow gains a **configurable autonomy level**, per repo, that lets the machine carry an
issue from label to merged code on the integration branch with no human decision in the path —
while remaining continuously observable from outside any session and cheaply reversible after
the fact. The human stops being a *gate* and becomes a *reviewer of record*: nothing waits on
them, everything is visible to them, and anything they dislike is one command to undo.

Autonomy is a **ladder, not a switch**. Each rung is separately enabled, defaults off, and is
meant to be earned by the rung below it running clean. Turning every rung off yields exactly
today's behaviour.

## Grounding

Verified against the repo on 2026-08-20, not recalled:

- **Verified:** the existing control plane already supplies most of the machinery autonomy
  needs — the status contract (`status/<branch-slug>.json`, milestones `grounding → branched →
  first-push → implementing → gates-running → gates-passed → pr-opened`, plus `blocked` /
  `cancelled`), the per-agent tool log, the `terminal` ownership stamp, and a deterministic
  PreToolUse cancel gate. Autonomy should *consume* this, not reinvent it.
- **Verified:** the runner already enforces the hard stops mechanically — never approves, never
  dispatches, never writes code outside the proposal folder, never merges, never closes an
  issue. Autonomy is precisely the project of relaxing those five, one at a time, each behind
  its own rung.
- **Verified:** `unattended-intake.sh` is single-pass with one lock for the whole run, resolves
  every binary absolutely, refuses to start on a credential problem (`rc=3`), and confines all
  writes to `~/Source`. It is a sound base to build on.
- **Verified:** telemetry lands under the epic *in flight*, resolved by the `active-epic`
  pointer then by plan state, never by mtime, and never into a `closed` epic. Multiple epics
  can therefore be queued while one runs — a precondition for chaining work autonomously.
- **Verified:** `blocked` already exists as a first-class terminal state whose contract is
  "stop and return rather than guess."
- **Verified:** seven unattended-drafted plans exist (#732, #733, #735, #738, #739, #740, #741)
  and **none has been reviewed by anyone**. The drafting mechanism is proven; the drafting
  *judgement* is entirely unmeasured.
- **Verified:** the epic-06 retro records that `--allowed-tools` is not a sandbox — `find`
  executes inside a compound command beginning with an allowed binary. Any autonomy control
  that depends on tool allowlisting as a boundary is unsound; boundaries must be enforced by
  something that cannot be composed around.
- **Assumed:** LODE remains the primary proving ground, with `dev` as the integration branch and
  `main` untouched. Not yet confirmed for any other repo.

## The autonomy ladder

The organising idea of the epic. Each level is a per-repo config value; unset means `L0`.

| Level | The machine may… | Human still owns |
|---|---|---|
| **L0** | draft a proposal PR and stop *(today)* | approval, dispatch, merge |
| **L1** | assign the epic number, file it, set `Status: approved` | dispatch, merge |
| **L2** | dispatch executors, open the PR, stop before merging | merge |
| **L3** | merge to the **integration** branch when every gate is green | promotion to live |
| **L4** | chain — pick the next admitted issue without being asked | promotion to live |

Two properties make this safe to walk up:

- **Every rung is independently revocable.** Dropping from L3 to L2 is a config edit and takes
  effect on the next cycle; it never leaves work in an invalid state, because each rung's
  output is a legitimate resting state of the rung below.
- **No rung ever reaches the live branch.** L3's ceiling is the integration branch. Promotion
  to live is out of scope for this epic and should stay a human act indefinitely.

## Invariants

These hold at every level, and a violation is a defect regardless of how convenient the
behaviour is:

- **The live branch is never written to.** Not by the runner, not by an executor, not by a
  merge. The integration branch is the ceiling.
- **History is never rewritten.** No force-push, no rebase of a pushed branch, no branch
  deletion with unmerged commits.
- **Every automated merge is a merge commit**, so `git revert -m 1 <sha>` is always a complete
  undo of one landed item.
- **Gates are blockers, never advisory.** A red gate means no merge, no exceptions, no
  "retry until green" loop that mistakes flakiness for success.
- **`blocked` escalates; ambiguity is never resolved by guessing.** Autonomy must not convert
  "I am not sure" into "I picked one."
- **The issue — not the plan — is the external reference.** When the machine writes the plan and
  then verifies against it, verification is circular. Acceptance criteria trace to the
  human-authored issue.
- **The kill switch works without a session** and is honoured *before* new work starts, not only
  mid-flight.
- **Budgets are hard stops.** Exceeding a cap stops new work; it never degrades the work to fit.
- **A path outside the allowlist forces human review at any level** — CI config, workflow
  files, credential handling, `install.sh`, the control-plane hooks themselves, and anything
  matching the repo's declared sensitive paths.
- **Autonomy is per repo and defaults to today's behaviour** when unconfigured. Silence means
  L0.
- **The automation may never modify its own autonomy config**, nor the admission policy, nor
  this plan. A system that can widen its own permissions has no permissions.

## Work items

### 1. Measure drafting quality — the prerequisite, and possibly the stopper
- **Branch:** `chore/autonomy-draft-baseline`
- **Depends on:** none
- **Scope:** Review all seven existing unattended-drafted LODE plans against a written rubric
  (is the grounding real and checkable? does the scope match the issue? are the DoDs
  falsifiable? is the risk table honest? would a competent engineer accept this as a contract?).
  Score each, record the results in this epic's folder, and state a verdict: is unattended
  drafting good enough to approve without a human reading it?
- **Not in scope:** any code, any config, any change to the runner.
- **Definition of done:** a rubric, seven scored reviews, and an explicit go / no-go on L1 with
  reasons. A "no-go" is a legitimate and possibly correct outcome that ends the epic here.
- **Verification:** the scores are reproducible by a second reader against the same rubric.
- **Rollback:** n/a — no change is made.

### 2. The autonomy ladder as configuration, with no behaviour change
- **Branch:** `feat/autonomy-levels`
- **Depends on:** 1 (go verdict)
- **Scope:** Per-repo autonomy level in the intake config (extend the `repos` line format, or a
  sibling file — decide at implementation). Admission policy defining which issues are eligible:
  required labels, forbidden labels, area allowlist, an explicit sensitive-path denylist, and a
  size ceiling. Every existing code path reads the level; every path defaults to L0. Ships
  **inert** — the switchboard, wired to nothing.
- **Not in scope:** actually acting on any level above L0.
- **Definition of done:** config parsed and validated with clear errors; an unconfigured repo
  behaves byte-identically to today; a fixture proves an issue failing admission is skipped with
  a logged reason; the full existing guard battery still passes.
- **Verification:** dry-run across a multi-repo list with mixed levels showing correct
  classification and zero behaviour change.
- **Rollback:** revert; config is ignored.

### 3. The run ledger and a status surface that needs no session
- **Branch:** `feat/autonomy-ledger`
- **Depends on:** 2
- **Scope:** An append-only ledger (`~/.config/claude-intake/ledger.jsonl`, outside any repo
  because it spans repos) recording every state transition with timestamp, repo, issue, epic,
  item, level, actor, and outcome. A `status` subcommand rendering: what is running now, what
  landed since a given time, what is blocked and waiting on a human, and what was refused by
  admission. Extend the SessionStart injection to surface autonomous activity since the last
  session.
- **Not in scope:** notifications; any web UI; any autonomy above L0.
- **Definition of done:** every transition appears exactly once; the ledger survives a killed
  run; `status` answers "what happened while I was away" and "what needs me" without opening
  Claude; rendering is correct when the ledger is empty, huge, or truncated mid-line.
- **Verification:** kill a run mid-item and confirm the ledger and `status` both describe
  reality rather than the last thing anyone intended.
- **Rollback:** revert; the ledger is additive and ignoring it costs nothing.

### 4. Global kill switch, budgets, and rate limits
- **Branch:** `feat/autonomy-brakes`
- **Depends on:** 3
- **Scope:** A machine-wide stop file honoured **before** a cycle starts (distinct from the
  per-epic `CANCEL`, which stops executors mid-flight). Caps: max concurrent epics, max epics
  per day, max executor wall-clock per item, and a token/usage budget with a hard stop. Optional
  permitted time windows. All caps logged to the ledger when they bite.
- **Not in scope:** autonomy above L0 — the brakes ship before the accelerator.
- **Definition of done:** stop file blocks a cycle from starting and is loud in the log; each cap
  independently provable by a fixture; hitting a cap stops new work and never truncates work in
  progress; caps cannot be raised by the automation itself.
- **Verification:** fixtures for each cap plus a live test that the stop file halts the next
  scheduled cycle.
- **Rollback:** revert; caps default to unlimited, which is today's behaviour.

### 5. L1 — auto-approve and file
- **Branch:** `feat/autonomy-l1-approve`
- **Depends on:** 4
- **Scope:** At L1, an admitted issue's proposal is numbered (next available), the folder renamed
  from `proposed-<issue>-<slug>` to `<NN>-<slug>`, `Status` set to `approved`, and the PR merged
  to the integration branch. Number assignment must be collision-safe under concurrency — the
  reason numbering was moved to approval time in epic 06 is that draft-time reservation collided.
- **Not in scope:** dispatch; writing any code.
- **Definition of done:** two issues admitted in one cycle produce two epics with distinct
  numbers; an epic filed at `approved` is visible to the session hook under *awaiting dispatch*;
  a failed merge leaves the proposal intact and re-runnable; L0 repos are unaffected.
- **Verification:** live, on this repo, with two issues at once.
- **Rollback:** revert the merge; the epic returns to a proposal.

### 6. L2 — auto-dispatch
- **Branch:** `feat/autonomy-l2-dispatch`
- **Depends on:** 5
- **Scope:** At L2, an unattended orchestrator dispatches `work-item-executor` per item into its
  own worktree, sets the `active-epic` pointer and `Status: in flight (item N of M)`, honours the
  plan's sequence, and stops at `pr-opened`. Consumes the existing control plane unchanged.
  `blocked` writes to the ledger and waits for a human — it must never auto-resolve.
- **Not in scope:** merging.
- **Definition of done:** an epic runs items in sequence unattended; parallel-safe items get
  separate worktrees; `blocked` halts that epic and surfaces in `status`; cancel sentinels stop
  executors mid-flight; Phase 4 verification runs cold and its result is recorded.
- **Verification:** a real two-item epic end to end on this repo, verified from the repo rather
  than from the executor's summary.
- **Rollback:** revert; unmerged item branches are left pushed and intact.

### 7. L3 — auto-merge on green, with automatic revert
- **Branch:** `feat/autonomy-l3-merge`
- **Depends on:** 6
- **Scope:** At L3, an item whose stack gates are green **and** whose cold Phase 4 verification
  passes is merged to the integration branch as a merge commit, then the integration branch is
  re-gated *post-merge*. A post-merge failure triggers automatic `git revert -m 1`, records both
  events in the ledger, and drops the repo to L2 until a human clears it.
- **Not in scope:** promotion to the live branch — permanently out of scope.
- **Definition of done:** a red gate never merges; a post-merge red auto-reverts and demotes; the
  revert is itself verified to have restored the pre-merge tree; a sensitive-path diff blocks the
  merge regardless of level; every merge is revertible with one command recorded in the digest.
- **Verification:** deliberately land a failing change in a sandbox repo and prove the
  revert-and-demote path, not just the happy path.
- **Rollback:** drop to L2 by config; already-merged work is reverted individually.

### 8. The digest — the human's actual interface
- **Branch:** `feat/autonomy-digest`
- **Depends on:** 7
- **Scope:** A periodic digest (daily by default) of what landed, what was refused, what is
  blocked, and what each item cost — each landed item paired with its one-command revert. This is
  the artifact that makes "out of the loop but not out of the picture" true rather than
  aspirational.
- **Not in scope:** L4 chaining.
- **Definition of done:** the digest is accurate against the ledger and the repo; it is readable
  in under two minutes; every landed item carries a working revert command; an empty period
  produces a short "nothing happened" rather than silence.
- **Verification:** compare a digest against `git log` on the integration branch for the same
  window.
- **Rollback:** revert; purely additive.

## Sequence

1 gates everything — a no-go verdict ends the epic honestly. Then **the brakes and the
instruments before the accelerator**: 2 (switchboard), 3 (ledger), 4 (kill switch and caps) all
ship inert, before any rung is enabled. Then the ladder in order, 5 → 6 → 7, each proven live
before the next. 8 lands with or immediately after 7, because L3 without a digest is autonomy
nobody can review.

**L4 (chaining) is deliberately not a work item.** It should be considered only after L3 has run
for a sustained period, and it deserves its own epic with its own risk analysis — compounding
autonomy is a different problem from single-issue autonomy.

## Risks

| Risk | Likelihood | Blast radius | Mitigation |
|---|---|---|---|
| Auto-approved plans are subtly wrong, and executors faithfully build the wrong thing | **High** | Wasted work that looks legitimate in the log | Item 1 measures this *first*; admission policy confines autonomy to issue classes where scope is obvious; the issue stays the reference for acceptance |
| Verification becomes circular — machine writes the plan, machine checks against the plan | Certain if unaddressed | Green results that mean nothing | Acceptance criteria trace to the human-authored issue; Phase 4 greps for symbols named in the **issue** |
| Gate flakiness read as failure, or retried until green | Medium | Either stalled autonomy or a false pass | Distinguish flake from failure explicitly; never retry a gate more than once; a second red is final |
| Auto-merge lands a breaking change on the integration branch | Medium | Everyone on `dev` blocked | Post-merge re-gate, automatic revert, automatic demotion to L2 |
| Compounding — a bad epic spawns follow-on work | Low at L3, **high at L4** | Multiplying wrong work | L4 excluded from this epic; caps on epics/day bound the damage at any level |
| The automation widens its own permissions | Low | Total loss of control | Invariant: it may never modify autonomy config, admission policy, or this plan; enforce as a sensitive path |
| Tool allowlists mistaken for a sandbox | Certain if assumed | A control believed to exist that does not | Epic 06 proved `find` runs inside a compound command; boundaries must be enforced by something uncomposable — path checks and gates, not tool names |
| Usage cost runs away unattended | Medium | Budget | Hard token/usage cap in item 4, shipped **before** any rung is enabled |
| Silent success — everything works and nobody looks | Medium | Unreviewed code accumulating on `dev` | The digest (item 8), and a soak period before promotion to live |

## Open questions

- **What issue classes are actually safe to admit?** "Bug with clear repro and a named component"
  is plausible; "feature request" almost certainly is not. Needs a real answer before item 2,
  probably informed by item 1.
- **Should a soak window gate promotion to live** — e.g. auto-merged work must sit on `dev` for
  N hours and appear in one digest before it is eligible? Leaning yes.
- **What happens to `blocked` items nobody unblocks?** A timeout that closes the epic and
  re-labels the issue, or indefinite waiting with digest nagging?
- **One ledger across repos, or one per repo?** Cross-repo is easier to review; per-repo is easier
  to reason about and to delete.
- **Does the runner become a long-lived orchestrator at L2+**, or stay single-pass with state
  resumed from the ledger each cycle? Single-pass is far easier to reason about and to kill, and
  is the current design's strength — leaning strongly toward keeping it.

## Deferred / out of scope

- **Promotion to the live branch.** Permanently a human act.
- **L4 chaining.** Its own epic, after L3 has soaked.
- Any web dashboard. The `status` subcommand and the digest are the surface.
- Autonomy for repos other than this one and LODE.
- Notifications (push, email, Slack) — the digest first; alerting is a separate concern.

## Log
- 2026-08-20 — filed from GH #39 as a **proposal**, at Jonathan's explicit request to plan and
  file without implementing. Phase 0 grounded against the existing control plane, the runner's
  hard stops, and the epic-06 retro. Two findings shaped the design: the seven existing drafted
  plans have never been reviewed (making item 1 a prerequisite rather than a nicety), and
  `--allowed-tools` is not a sandbox (making tool-name-based controls unsound as boundaries).
  Not approved, not numbered, not dispatchable.
