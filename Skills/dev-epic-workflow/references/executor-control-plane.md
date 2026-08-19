# Executor Control Plane

How orchestrated work-item execution stays observable, stoppable, and honest. Three
layers: **telemetry** (know what the executor is doing), a **kill switch** (stop it
deterministically), and **reconciliation** (trust nothing until verified). The design
principle throughout: control never depends on the model noticing or cooperating —
every guarantee is enforced by a hook or read from disk.

## Roles

- **Orchestrator** — the interactive session Jonathan sits in. Holds `plan.md`,
  sequencing, dispatch decisions, and Phase 4 verification. Plan-level state only;
  its context grows slowly, so `/handoff` + `/clear` demotes from per-item to rare
  (end of day, or per-epic).
- **Executor** — the `work-item-executor` subagent (`.claude/agents/work-item-executor.md`).
  One dispatch = one work item = one executor life. Its context evaporates when it
  returns — the subagent's death *is* the session reset that used to cost a keystroke.
- **Jonathan** — watches whatever he wants (or nothing), cancels by touching a file,
  and makes dispatch/merge decisions. Those decisions are the only recurring keystrokes
  left.

## Runtime state on disk (all gitignored)

```
docs/epics/<NN>-<slug>/
  status/<branch-slug>.json    ← the status contract (executor overwrites at milestones)
  status/<branch-slug>.log     ← tool-call telemetry (PostToolUse hook appends)
  CANCEL                       ← cancel sentinel for this epic (create to cancel)
.claude/signals/
  cancel                       ← project-wide cancel sentinel
  subagent-active-<id>         ← lifecycle markers (SubagentStart/Stop hook maintains);
                                 <id> is also the selector you write into a sentinel
```

Repo-mode installs gitignore these automatically. With a user-level install, add the
three lines (`.claude/signals/`, `docs/epics/*/status/`, `docs/epics/*/CANCEL`) to the
repo's `.gitignore` when filing the plan — Phase 1's "file the plan" step includes it.

## Layer 1 — Telemetry

Three independent feeds, cheapest first:

1. **The commit stream is the truest feed.** "Push on the very first commit" means
   `git log origin/<branch>` is live progress that cannot be faked by prose. Watch it
   with `git fetch -q && git log --oneline origin/<branch>`, or just glance at the PR
   as it forms.
2. **`status/<branch-slug>.json` — the milestone contract.** The executor overwrites
   it atomically at each milestone:
   `grounding → branched → first-push → implementing → gates-running → gates-passed → pr-opened`,
   with `blocked` and `cancelled` as exceptional terminals. Fields: `item`, `branch`,
   `state`, `detail` (one line — PR URL, gate failure, or the blocking question),
   `commit`, `updated`. The SubagentStop hook stamps `terminal: true` when the
   executor's run actually ends, whatever the model last wrote.
3. **`status/<branch-slug>.log` — the deterministic tool-call stream.** The PostToolUse
   hook appends one line per executor tool call (timestamp | tool | command/file),
   bracketed by SUBAGENT START/STOP lines from the lifecycle hook. It logs only calls
   that carry an `agent_id` — i.e. calls made inside a subagent — so orchestrator
   activity never pollutes it. Tail it live: `tail -f docs/epics/<NN>-<slug>/status/<branch>.log`.

On top of these, Claude Code's own surfaces (`/tasks`, the agent view) show status and
progress for background agents — use them freely, but never as the source of truth
(see Layer 3).

## Layer 2 — Kill switch

Two tiers:

- **Human tier:** Esc interrupts a foreground run; background agents can be stopped
  from the agent view / task manager.
- **Deterministic tier (the one to trust):** create a sentinel file and the PreToolUse
  cancel gate denies every further tool call from any active executor — it cannot run
  commands, edit files, or push, regardless of what it believes it is doing.

  ```bash
  touch docs/epics/<NN>-<slug>/CANCEL          # cancel this epic's executors
  touch .claude/signals/cancel                  # cancel all executors in this project dir
  ls .claude/signals/subagent-active-*          # what's running, and its agent id
  echo "a71a4bb0c9d2" >> docs/epics/<NN>-<slug>/CANCEL   # cancel ONE executor, by agent id
  ```

  Semantics: an **empty** sentinel — or one holding nothing but blank lines and
  `#` comments — cancels every active executor. A sentinel with content cancels only the
  executors it names, one selector per line:

  - an **agent id**, exact or any prefix of 8+ characters. Read it from
    `.claude/signals/subagent-active-<id>` or from the `SUBAGENT START (<id>)` bracket in
    the status log. This is the granular form, and the only one that works under worktree
    dispatch.
  - a **branch name**, honoured only in direct (single-checkout) dispatch, where the
    project dir's branch genuinely is the executor's. Under worktree dispatch branch
    selectors are ignored by design: hooks always resolve `CLAUDE_PROJECT_DIR` — the
    orchestrator's checkout — so the item branch would never match, and the
    orchestrator's branch would match every executor at once.

  **The orchestrator is never gated**, because attribution is per call rather than per
  session: `PreToolUse` input carries `agent_id` only inside a subagent, so its absence
  identifies the main session and the gate allows the call before it even looks for a
  sentinel. The lifecycle markers are deliberately not consulted — a marker proves only
  that *some* executor is running, which is exactly why the gate used to deny the
  orchestrator too and left the sentinel unremovable from inside the session. Cleanup is
  therefore always possible. **Remove the sentinel** once the situation is resolved, or the
  next dispatched executor dies on its first tool call — that failure mode is loud and
  harmless, but annoying.

  The gate fails open by construction: malformed hook input, `jq` and `python3` both
  missing, no git, an unreadable sentinel — every error path allows the call. All of that
  is exercised by `assets/claude-config/hooks/tests/cancel-gate-fixtures.sh`, which builds
  a throwaway sandbox and never touches a real repo. Run it after changing either hook,
  **before** `install.sh` puts the change live.

  Cancellation is loss-free by construction: everything pushed is safe, and the executor
  pushed on its first commit. After a cancel, the orchestrator decides: re-dispatch with
  amended instructions, split the item, or update the plan.

## Layer 3 — Reconciliation

- **The repo decides, not the task list.** Claude Code's task/agent UI can lag or stick
  after long-running subagent work completes. The rule that makes the workflow immune:
  an item's truth is `status.json` + `origin`. If `state: pr-opened` and the PR exists,
  the item is ready for review no matter what any sidebar claims; if the marker file is
  gone and `terminal: true` is stamped, the run is over.
- **Phase 4 runs cold, always.** The orchestrator never shared the executor's context,
  so it verifies the return summary against `git log <base>..HEAD`,
  `git diff --stat <base>...HEAD`, and greps for the promised symbols — the same
  discipline as before, now structurally guaranteed because the verifier *cannot* have
  inherited the executor's beliefs.
- **`blocked` is a feature.** The executor must stop and return on any ambiguity rather
  than guess. The orchestrator resolves the question (with Jonathan if needed) and
  re-dispatches — decisions stay in the session Jonathan actually sits in.

## Dispatch conventions (orchestrator side)

A dispatch names: epic folder, work item number, branch name, and any decisions resolved
since the plan was filed — and instructs the executor to read `plan.md` itself. One
executor per item; items that the plan sequences as dependent are never in flight
together.

**Every dispatch gets its own git worktree**, created before the executor starts
(`git worktree add ../<repo>-<branch-slug> -b <branch> <integration>`, Phase 2) and removed
at land-and-reset (Phase 3 step 10). This is not a parallel-mode optimisation: the
orchestrator keeps committing to the epic folder — plan amendments, handoffs, the next
dispatch's prep — while the executor owns the item branch, so concurrency exists at one
item, not just at two. In a shared checkout those orchestrator commits land on the item
branch; that is epic 01's GH #3, observed, not theorised. Parallel independent items simply
repeat the rule — one worktree each, executors as background tasks. Foreground dispatch
into a worktree is fine for single-item flow — Esc is then also a cancel tier.

**Interim limitation (until epic 02 item 3 lands).** The hooks resolve `CLAUDE_PROJECT_DIR`
— the orchestrator's checkout — not the calling agent's worktree. Cancellation no longer
depends on that (sentinels select by agent id), but `status/<branch-slug>.json` and `.log`
are still written under the *orchestrator's* branch slug rather than the item's, so parallel
worktree executors would overwrite each other's status. Dispatch serially until item 3 keys
those paths on the epic plus the item.

After the executor returns: Phase 4 verification → merge (orchestrator's job, per Phase 3
steps 9–10) → land-and-reset → dispatch the next item. The orchestrator does **not**
accumulate executor transcripts; if its own context starts filling across a long epic,
that's what `/handoff` still exists for.

## Failure modes and what catches them

| Failure | Caught by |
|---|---|
| Executor claims a milestone it didn't reach | Phase 4 cold verification; commit stream disagrees with `status.json` |
| Executor hangs or dies mid-item | `status.json` `updated` goes stale while marker is armed; log stream stops; branch is pushed so nothing is lost |
| Task UI stuck "in progress" after real completion | `terminal: true` stamp + "repo decides" rule |
| Cancel ignored by the model | Impossible — PreToolUse denial is system-level, not advisory |
| Stale marker after a crashed run | Harmless to the gate and logger — both attribute per call by `agent_id` and never read markers; SubagentStop still clears markers >24h old, and they are safe to delete by hand |
| Scope grows mid-item | Executor's hard boundary: finish the agreed slice, propose the split in its return summary |
