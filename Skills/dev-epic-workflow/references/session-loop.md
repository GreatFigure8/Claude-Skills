# The session-scoped issue loop

Jonathan opens a live session, names one repo, and says **"start the loop"**. From that
point the session itself — not a daemon, not a subprocess chain, not an API-keyed
background process — continuously works admitted GitHub issues end to end: draft a plan,
dispatch each work item, verify it, harm-check, merge, chain to the next item and then the
next issue, close out, repeat. It runs until Jonathan says stop or the session ends.

**Starting the loop is the grant of full autonomy for that session and that repo.** There
is no approval stop between draft and dispatch, and no promotion ladder — the ladder was
retired in epic 21 item 1 precisely because a per-repo grant record nobody ever wrote was
standing in for a decision Jonathan makes by speaking. The only in-flight brake is the
**harm floor** (item 2) before every merge and every chain.

Full autonomy is **opt-in per session and never ambient**: a session that has not started
the loop runs the ordinary interactive workflow — plan, approve, dispatch, verify, merge,
one human-supervised step at a time — completely unchanged.

## The two halves, and where the brake lives

| `bin/session-loop.sh` — deterministic | the live session — judgement |
|---|---|
| which issues are **admitted** | drafting a plan for one |
| which **action** comes next | running a work item (`work-item-executor`) |
| the **harm check** in front of it | judging a diff (`acceptance-verifier`) |
| the **stop** signal | the PR body, the retro, the plan edits |
| the per-issue state + `ledger.jsonl` | talking to Jonathan |

The brake is on the deterministic side deliberately. `--next` runs the harm floor
**itself** before it will name a merge, a chain or a close, and answers `blocked` or
`halt` instead when the floor refuses. So the epic's invariant — *the harm check runs
before every merge and every chain action, with no exception* — is enforced by what the
driver will tell the session to do, not by what the session was asked to remember.

**Nothing here is headless.** The driver never invokes `claude`; there is no `CLAUDE_BIN`
in it and a fixture keeps it that way. Every judgement step is an `Agent`-tool dispatch
inside the live, already-authenticated session. `unattended-intake.sh` and
`phase-session.sh` are the retired headless path — their *logic* is reused, their
*mechanism* is not.

## Starting

```
/loop <repo>                      # or: "start the loop on <repo>"
```

The session then, once:

1. `session-loop.sh --start --repo <path>` — binds the loop to one checkout. A `--start`
   naming a **different** repo while another loop is bound is refused: one loop, one repo,
   one live session. Multi-repo looping is out of scope for this epic by name.
2. Confirms in one line what it is about to do autonomously — repo, admitted issue count
   from `--admit`, and that it will merge and chain without asking again. This is a
   statement, not a question; the loop does not wait for an answer.
3. Enters the turn cycle below.

## The turn cycle — one wakeup, one action

Each turn, in this order and nothing else:

1. `session-loop.sh --next --repo <path>`. It prints `action`, `reason`, `wake-in` and
   whatever context that action needs (`issue`, `epic`, `plan`, `item`, `branch`, `pr`).
   For any action that is not `poll` or `stop`, **the harm floor has already cleared it**
   at the moment it was printed.
2. Perform exactly that one action (below).
3. `session-loop.sh --record --repo <path> --issue N --state <s> [--item I] [--branch B]
   --detail "<what happened>"` — this is what advances the state machine; `--next` reads
   nothing else.
4. Self-pace: call **`ScheduleWakeup`** with the delay the driver printed on `wake-in`
   (seconds), and end the turn. That wakeup is what lets the loop survive across turns
   without holding a session hostage in a blocking `sleep`.

Never busy-wait in Bash. A blocking `sleep` burns the session's turn for nothing and
cannot be interrupted by Jonathan typing stop; a scheduled wakeup can.

*If `ScheduleWakeup` is not available in this session*, say so once, then keep taking
actions back-to-back within the turn. What is lost is pacing, not autonomy — the loop
still never stops for approval.

### Output discipline while looping

The loop is long-running and its transcript is not read live. Per turn, produce visible
text only for: a **blocked/halt** action, something that changes the shape of the work, or
the **model table** every dispatch owes (below). The `ledger.jsonl`, the status files and
the commit stream are the progress channel. A running commentary on a multi-hour loop is
re-billed on every remaining turn of the session and is the single most expensive habit
available here.

## The actions

### `draft` — an admitted issue with no epic

Dispatch **one** drafting subagent (`model: "sonnet"`) with the brief in
`references/issue-intake.md`'s **Unattended intake** section — *that* is "reusing
unattended-intake's drafting logic directly". Same Phase 0 grounding, same
`plan-template.md` structure, same **supplied header facts** rule (live and integration
branches are handed over as facts and copied verbatim, never re-derived), same
`**Touches:**` rule, same **`**Recommendation:**`** vocabulary.

It departs from the headless contract in exactly three named ways, and no others:

1. **Mechanism.** An `Agent`-tool subagent in this session, not a `claude -p` subprocess.
2. **No parking at `planning`, and no proposal PR.** The plan is filed the way Phase 1
   files an approved plan: `docs/epics/<NN>-<slug>/plan.md` at **`**Status:** approved`**
   with the next available number, committed to the integration branch, with the
   `Source: GH #<n>` header. Starting the loop is the approval, so there is nothing for a
   proposal branch to propose.
3. **The two hard stops the loop's own approval covers are lifted** — it may approve, and
   it may dispatch. **Every other stop stands**: the drafting step still writes no code
   outside the epic folder, still never merges anything, still never closes an issue.

Then the Phase 1 tracker touch, in the same turn: comment the plan path on the issue, add
the work-item checklist, and label it **`epic:planned`**. That label is what stops
unattended intake drafting a competing proposal over the epic the loop just filed.

**The Recommendation vocabulary is retained in full, including its routing obligations**,
which `issue-intake.md` says every later consumer inherits verbatim:

- A `no-work` or `needs-decision` plan is **never dispatched and never auto-approved**.
- A `needs-decision`'s stated choice is **never resolved by the machine**, not even by
  taking the option listed first.
- A `no-work` issue is **never auto-closed**. "Nothing to do here" is a claim a human
  checks.

The loop records the issue `parked`, comments the recommendation on it, and takes the next
admitted issue. This is not an approval stop between draft and dispatch: it is the drafter
reporting that there is nothing to dispatch.

### `dispatch` — the next undispatched work item

The **existing orchestrated path, unchanged**: Phase 3 steps 1–2 as dispatch setup, then
the `work-item-executor` subagent with `isolation: "worktree"`, the `.claude/signals/active-epic`
pointer written first, the plan header set to `**Status:** in flight (item N of M)`, and
the tracker moved to `epic:in-progress`. The executor runs steps 3–8 and stops at
`pr-opened`; the loop never asks it to merge.

The **model table is still owed**, in the same turn the executor starts — one row, with
the Model column. Jonathan is paying for these contexts whether or not he is watching.

An executor that returns `blocked` is not retried. Record the issue `blocked`, quote the
`status.json` detail on the tracker item, and chain to the next admitted issue: the loop
steps past what it cannot resolve rather than stopping on it.

### `verify` — the item's four deterministic gates are clean

The driver has already run `verify_item_deterministic_gates` (status.json shows
`pr-opened`, the declared-paths gate is clean, `gh pr checks` is green, the real diff
clears the denylist). What remains is the **cold** judgement: dispatch the
`acceptance-verifier` agent (`model: "opus"`) with the item's DoD verbatim from the plan,
the source issue's body, and the PR's real diff — and nothing else. It has no memory of
the executor that built the PR; that isolation is the whole point.

`pass` → record `verified`. `fail` → record `blocked`, comment the verdict on the PR, and
chain past it. **Never auto-retry a failed verdict.**

### `merge` — verified, and the harm floor cleared the real diff

Merge to the integration branch (a merge commit, never a rebase onto it), then Phase 3
step 10's land-and-reset in full: pull, delete the branch remotely and locally with `-d`,
remove the worktree, prune, tick the item's checklist on the tracker, clean the item's
control-plane state. Record `merged`.

### `close` — every work item has landed

Phase 5: plan header to `**Status:** closed` merged into the canonical checkout **first**,
then the scaffolding (`status/`, `CANCEL`, the `active-epic` pointer), the retro in the
plan, the retro comment on the issue, and `gh issue close`. Record `closed` — which
releases the loop record's active issue, and the next `--next` chains to the next admitted
issue.

### `poll` — nothing is ready

An executor is still running, or no admitted issue is workable. Schedule the longer
wakeup and end the turn. Polling is not idling: the loop keeps watching until Jonathan
says stop.

### `blocked` / `halt` — the harm floor refused

- **`halt`** means `STOP` is present. The machine stops: report it in one line and do not
  schedule another wakeup.
- **`blocked`** means one action was refused — a denylist hit, a size ceiling, a
  cross-epic branch collision, an irreversible git op. Report it, leave the PR open for a
  human, record the issue `blocked`, and chain to the next admitted issue.

The distinction is load-bearing: STOP stops everything; every other refusal stops one
thing.

## Admission — what the loop may work on

An issue is **admitted** only when both hold, and the driver checks both:

1. it carries the **`epic-loop-ready`** label — the constant the `author-issue` skill
   applies to everything it files; and
2. its **body** carries a `Requirements` section and an `Acceptance criteria` section,
   each with real content, per `Skills/author-issue/references/issue-body.md`.

Both, because the label is a claim and the body is the evidence. `Derived acceptance
criteria` — Claude's half of that skeleton — never admits anything; letting it would let
the machine satisfy its own admission test. The `## Loop admission` checkboxes are
self-reported and read as documentation, never as the gate.

An issue failing either half is **parked, not executed**, and the loop steps over it. It
is not silently ignored: `--admit` names the reason for every open labelled issue, and the
dry-run preview shows it.

## Stopping

Any of these halts the loop **before its next action**:

- Jonathan says stop (spoken, typed, any phrasing that means it). The session runs
  `session-loop.sh --stop --repo <path>` and stops scheduling wakeups.
- `session-loop.sh --stop` from any other terminal.
- `~/.config/claude-intake/STOP` — the harm floor refuses, `--next` answers `halt`.
- The session ends or the client closes. The loop is session-scoped; it dies with it.

A clean stop leaves everything already pushed safe — the executor pushes on its first
commit — and states in one line exactly where things stand: last action, active issue, and
any PR left open for a human.

## Previewing it

```
session-loop.sh --next --repo <path> --dry-run
```

prints the projected happy path for every admitted issue in filing order: which are
admitted, which are parked and why, and where the harm floor gates each merge and chain.
It is **a preview of the shape, not a claim about permission** — the floor runs for real
at every merge and every chain and can refuse any step in it.

## What this loop never does

- **Headless or unattended operation.** Retired in item 1, not reintroduced. The loop only
  ever runs inside a live, already-authenticated interactive session.
- **Two repos at once.** One loop, one repo, one live session.
- **Resolve a `needs-decision`, or close a `no-work`.**
- **Retry a failed verifier verdict or a blocked executor.**
- **Merge without the harm floor.** There is no flag, label or issue body that turns it
  off.
- **Introduce an API key, a daemon, a launchd job, or a promotion record.**

## Known consequence — the loop cannot merge its own control plane

The harm floor's built-in denylist covers `*/claude-config/bin/*`,
`*/claude-config/hooks/*`, `install.sh`, `.github/*` and the credential classes. A work
item whose diff touches any of them will be refused at `merge` and left for a human. On
most repos this never comes up; **on `claude-skills` it is the common case**, because this
control plane *is* what that repo contains. That is correct behaviour, not a defect —
autonomous machinery that may rewrite its own brakes has no brakes — but it means the
epic's live-proof run (item 6) needs an issue whose diff stays outside those paths.

## Where the rest of the epic attaches

- **Item 4 — failure-driven issue filing.** Today a gate failure out of the item's scope
  is reported and the loop chains past it. Item 4 makes that a filed GitHub issue,
  deduplicated by fingerprint against open `epic-loop-filed` issues.
- **Item 5 — per-issue integration testing.** Today `close` runs no whole-issue check.
  Item 5 adds one between the last merge and the close, routing a failure through item 4.

## Files

- `assets/claude-config/bin/session-loop.sh` — the deterministic driver.
- `assets/claude-config/commands/loop.md` — the `/loop` entry point.
- `assets/claude-config/hooks/tests/session-loop-fixtures.sh` — the fixture suite.
- `assets/claude-config/bin/autonomy.sh` — `autonomy_harm_check`, the harm floor.
- `references/issue-intake.md` — the drafting contract this loop reuses.
- `references/executor-control-plane.md` — the dispatch/status contract it dispatches into.
