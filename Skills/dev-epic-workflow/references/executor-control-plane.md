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
docs/epics/<NN>-<slug>/                  ← always in the CANONICAL repo root (see below)
  status/<branch-slug>.json    ← the status contract, one per ITEM (executor overwrites
                                 at milestones; hooks add agent_id + terminal)
  status/agent-<id>.log        ← one per executor LIFE: SUBAGENT START/STOP brackets
                                 (SubagentStart/Stop) + tool lines (PostToolUse)
  status/.agents/<id>.json     ← owner record written at SubagentStart (hook-private:
                                 who started, when, on what branch, which log)
  CANCEL                       ← cancel sentinel for this epic (create to cancel)
.claude/signals/                         ← sentinels and markers: CLAUDE_PROJECT_DIR
  cancel                       ← project-wide cancel sentinel
  subagent-active-<id>         ← lifecycle markers (SubagentStart/Stop hook maintains);
                                 <id> is also the selector you write into a sentinel
  active-epic                  ← WHICH epic is in flight: the orchestrator writes it at
                                 dispatch setup and removes it at close. Read from the
                                 CANONICAL root, not CLAUDE_PROJECT_DIR (see below)
```

**One status tree, and it is the main checkout's.** Hooks and executors alike resolve
`docs/epics/` from the *canonical* repo root:

```bash
REPO_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
```

From inside a linked worktree `--git-common-dir` still names the main checkout's `.git`,
so every agent — orchestrator, executor, hook — lands in the same directory. Before this,
under worktree dispatch the executor wrote `status/<item-branch>.json` inside its worktree
while the hooks wrote `status/<orchestrator-branch>.log` in the main checkout, and
`SubagentStop` looked for a third path that existed nowhere: `terminal` was never stamped
at all, which made Layer 3's "terminal + PR on origin = done" rule unsatisfiable in the
mode that is now the default (GH #5). Sentinels and markers deliberately stay in
`CLAUDE_PROJECT_DIR`, because only hooks read them and every hook runs there.

Paths key on the **item** (`<branch-slug>.json`) and the **agent** (`agent-<id>.log`),
never on the branch the hook happens to observe — the executor branches at step 2 of every
item, which used to split each agent's own bracket pair across two files.

**Which epic, decided explicitly.** Knowing the root is only half the address; the hooks
also have to pick the epic. They resolve, in order:

1. **The pointer** — `$REPO_ROOT/.claude/signals/active-epic`, holding an epic folder
   name (`03-active-epic-resolution`), a repo-relative path, or an absolute path;
   blank lines and `#` comments are skipped, and a trailing `/plan.md` or `/` is
   tolerated. Used whenever it names a directory that exists **and whose plan does not
   read `closed`**.
2. **The newest `plan.md` whose `**Status:**` line reads `in flight`.**
3. **The newest `plan.md` that is open but not started** — `planning`, `approved`, or no
   parseable `**Status:**` line at all.
4. **Nothing.** Both hooks exit 0, write nothing, print nothing.

**State is the primary key; mtime only breaks ties within a state**, and no step can
reach a closed epic. That ordering is what makes it safe to plan ahead: epics are filed
in numbered folders as `**Status:** approved` while another epic is being worked, and a
just-filed plan is by construction the newest `plan.md` in the repo. While the rule was
"the newest plan that is not closed", filing epic 06 during epic 05 handed 05's live
executor telemetry to 06 — brackets, tool log, owner record and `terminal` stamp all
landed in a folder nobody was working in (GH #11). Being open and being in flight are
different states, and only the second one is an address.

The state test reads the documented Status vocabulary of `references/plan-template.md`
(`planning | approved | in flight (item N of M) | closed`) from the line's first **two**
words, case-insensitively, and tolerates anything after the phrase — `in flight (items
1-2 of 2, parallel)` is in flight. It deliberately does not key on the first word alone,
which truncates `in flight` to `in`; that truncation is exactly why `approved` and
`in flight` were once indistinguishable. Marking a plan `**Status:** in flight` at
dispatch is therefore load-bearing, not bookkeeping — Phase 3 sets it, Phase 5 sets
`closed`.

A plan with no parseable `**Status:**` line counts as **open**: the failure direction is
"write the telemetry somewhere" rather than "silently lose it" — but open is not in
flight, so a Status-less plan still loses to a running epic. A pointer to a deleted or
misspelled epic simply falls through to (2)/(3), so a stale pointer degrades instead of
breaking; so does a pointer naming an epic whose plan reads `closed`, because Phase 5
removes the pointer at close and one that outlived the close is a missed cleanup, not an
intent. A pointer to a directory with no readable `plan.md` is still honoured — only a
plan that actually says `closed` disqualifies it. The pointer is read from the
**canonical root**, deliberately not `CLAUDE_PROJECT_DIR` — a hook firing inside an
executor's worktree finds the pointer the orchestrator wrote in the main checkout,
without either path having to coincide.

It used to be bare mtime — `ls -t docs/epics/*/plan.md | head -1` — which answers
"whichever plan file was touched last", not "the epic in flight". During epic 02 an
executor legitimately edited **epic 01's** `plan.md` (a retro correction), making that
**closed** epic newest, and two `SUBAGENT STOP` brackets were written into epic 01's
`status/` while epic 02 was live: one dispatch's telemetry split across two epic folders
(GH #9). The resolution block is byte-identical in `subagent-lifecycle.sh` and
`subagent-tool-logger.sh` — between `BEGIN/END active-epic resolution` markers — so the
two can never disagree about which epic is live; `hooks/tests/active-epic-fixtures.sh`
asserts both the byte-identity and that both hooks choose the same directory, across all
three parser variants (`jq`, `python3`-only, and neither).

Repo-mode installs gitignore these automatically. With a user-level install, add the
three lines (`.claude/signals/`, `docs/epics/*/status/`, `docs/epics/*/CANCEL`) to the
repo's `.gitignore` when filing the plan — Phase 1's "file the plan" step includes it.
The pointer needs no fourth line: it lives under `.claude/signals/`.

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
   `commit`, `updated`. Two fields are the hooks': `agent_id` records which executor owns
   the item, and `terminal: true` is stamped by SubagentStop when that agent's run actually
   ends, whatever the model last wrote.

   **Ownership, and why it is not optional.** The stamp used to be applied to whatever
   status file matched the current branch, by whichever agent happened to stop — epic 01
   saw three STOP brackets against one START, two of them from agents that never started,
   while the real executor was demonstrably still working (GH #5). Now an agent may stamp
   only what it owns. Binding happens the moment the executor writes its own status file
   (the PostToolUse hook sees the path in that agent's own tool call and records
   `agent_id`), or failing that at stop, for an unowned file modified during the agent's
   life *when that agent is the only live executor*. Anything ambiguous is left unstamped
   rather than guessed, and a stop from an agent with no start record stamps nothing at all.
3. **`status/agent-<id>.log` — the deterministic tool-call stream.** The PostToolUse
   hook appends one line per executor tool call (timestamp | tool | command/file),
   bracketed by SUBAGENT START/STOP lines from the lifecycle hook — one file per executor
   life, so the pair is co-located even though the executor changes branch mid-run. It logs
   only calls that carry an `agent_id` — i.e. calls made inside a subagent — so orchestrator
   activity never pollutes it. Tail it live:
   `tail -f docs/epics/<NN>-<slug>/status/agent-*.log`; map an agent back to its item with
   `grep -l '"agent_id"' docs/epics/<NN>-<slug>/status/*.json`.

Feeds 2 and 3 land under the **epic in flight** — the one the pointer names, else the
one whose plan says `in flight` — never under an epic that is merely filed and waiting.
So the queue can grow while a dispatch is running and `tail -f` keeps working (see
"Which epic, decided explicitly" above).

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
  a throwaway sandbox and never touches a real repo. It is one of several harnesses under
  `assets/claude-config/hooks/tests/`; the control-plane ones are
  `cancel-gate-fixtures.sh` (the kill switch), `lifecycle-fixtures.sh` (brackets,
  ownership, terminal stamping), `active-epic-fixtures.sh` (which epic the telemetry goes
  to, including that the reserved intake tree is never one) and
  `intake-control-plane-fixtures.sh` (the unattended runner's own reporting). Run **the
  whole directory** after changing any control-plane hook, **before** `install.sh` puts
  the change live; each builds and destroys its own sandbox, so they are safe to run at
  any time. `session-start-fixtures.sh` needs `INTAKE_REPO_LIST=/nonexistent` so it cannot
  read a real machine's intake config.

  Cancellation is loss-free by construction: everything pushed is safe, and the executor
  pushed on its first commit. After a cancel, the orchestrator decides: re-dispatch with
  amended instructions, split the item, or update the plan.

## Layer 3 — Reconciliation

- **The repo decides, not the task list.** Claude Code's task/agent UI can lag or stick
  after long-running subagent work completes. The rule that makes the workflow immune:
  an item's truth is `status.json` + `origin`. If `state: pr-opened` and the PR exists,
  the item is ready for review no matter what any sidebar claims; if the marker file is
  gone and `terminal: true` is stamped, the run is over.
- **And within that pair, `origin` outranks `status.json`. Status is a convenience view;
  the branch and the PR are the truth.** This is load-bearing rather than a nicety. On
  2026-08-21 an executor clobbered a **sibling epic's** `status.json` — a well-formed
  write that simply went to the wrong file — and it cost nothing, *because nobody was
  acting on the status file* (GH #63). The moment anything starts trusting `status.json`
  over the repo, that same class of bug becomes expensive. Making telemetry easier to
  read — which is exactly what surfacing it at SessionStart does — must not make it
  authoritative.
- **`state: unknown` means "do not trust this record".** It is a defined out-of-band
  value, deliberately outside the milestone vocabulary so nothing can read it as
  progress, and it is what a writer uses when it knows its record may not reflect
  reality — a clobber, a refused write, a reconstruction it could not verify. **A
  wrong-but-plausible status is worse than an obviously-broken one, because the
  orchestrator acts on the plausible one.** Never repair a suspect record into a
  plausible state; write `unknown` with a `detail` saying what happened, and reconcile
  from `git log`, `git diff --stat` and the PR.
- **The target path must be visible at the call site.** The clobber above went through a
  helper whose command line did not show the file it wrote. Correct resolution and
  *invisible* resolution are independent properties, and only the second one causes that
  bug — so a helper that takes an epic-relative name and resolves the full path
  internally is the hazard **however correct its resolution is**. Write status with the
  resolved path visible in the command you run (the temp-file-then-`mv` the executor
  contract specifies does exactly that); that is also how the PostToolUse hook binds a
  status file to the agent that owns it.
- **`terminal` is now evidence, not decoration.** It is stamped only by the agent that
  owns the item, so its presence means *that executor's run ended* — it can no longer be
  produced by an unrelated stop. The converse is weaker on purpose: an absent stamp with a
  gone marker means the run ended without a binding (concurrent executors where nobody
  named its own status file), so fall back to the commit stream and the PR rather than
  concluding the executor is alive. Marker gone + PR on origin + `state: pr-opened` is a
  complete answer on its own.
- **Phase 4 runs cold, always.** The orchestrator never shared the executor's context,
  so it verifies the return summary against `git log <base>..HEAD`,
  `git diff --stat <base>...HEAD`, and greps for the promised symbols — the same
  discipline as before, now structurally guaranteed because the verifier *cannot* have
  inherited the executor's beliefs.
- **`blocked` is a feature.** The executor must stop and return on any ambiguity rather
  than guess. The orchestrator resolves the question (with Jonathan if needed) and
  re-dispatches — decisions stay in the session Jonathan actually sits in.

## The unattended intake control plane

**One control plane, not two.** Until epic 11 item 2 there were two telemetry universes
and only one of them was visible from a session. The orchestrated executor wrote
`status.json` milestones and an `agent-<id>.log` into the canonical status tree, where the
hooks, `/tasks` and SessionStart could all see them. The unattended runner
(`references/issue-intake.md`) wrote **zero** control-plane records and this hook made
**zero** references to a running cycle: watching it draft nine proposals meant knowing
`~/.config/claude-intake/intake.log` exists and `tail -f`-ing it by hand. An automation
nobody can see is not automation, it is a background process — so the runner now reports
where the orchestrator already looks.

**A drafting run has no epic yet, and that is the design problem.** A proposal is being
*written*; there is no `docs/epics/<NN>-<slug>/` to report into. So an intake cycle reports
into a **reserved tree**, resolved by the same rule as everything else here — the canonical
root, never a worktree:

```
<repo-root>/<epics-dir>/.intake/
  .gitignore                   `*`, which git applies to this file too, so the whole
                               directory is invisible to `git status` in the target repo
  README                       says, in the tree, that it is not an epic
  status/cycle.json            the cycle, status.json-SHAPED (item/branch/state/detail/
                               commit/updated) plus cycle id, pid, lock, issue, queue
  status/<branch-slug>.json    one per issue, named exactly as an executor's is
  status/agent-<cycle>.log     one per CYCLE, in the same `<ts> | ── … ──` shape
                               subagent-lifecycle.sh writes, so one reader reads both
  status/ledger.jsonl          the durable audit trail underneath — append-only, one line
                               per transition and never more than one. Not the interface
```

`branch` and `commit` are `null` in a cycle record, always and on purpose: a drafting cycle
is not on a branch and has no HEAD of its own, and writing a plausible value there would be
the same class of lie as a plausible-but-wrong plan header.

**It must never be mistaken for an epic**, because GH #9 and GH #11 are what that mistake
costs. Three independent guarantees, any one of which suffices:

1. **The name begins with a dot.** Every resolver globs `docs/epics/*/plan.md` or
   `docs/epics/*/`, and a shell `*` does not match a leading dot — so the active-epic
   resolver, the epic-queue section, the handoff and autosnapshot globs and the session-end
   guard cannot see it at all. (A **gitignore** `*` *does* match a leading dot, which is why
   `docs/epics/*/status/` already covers it in this repo.)
2. **It never contains a `plan.md`.** Resolution paths (b) and (c) require a readable
   `plan.md`, so no plan means no candidacy — and `bin/intake-status.sh` **refuses the tree
   outright** if one ever appears rather than writing into a directory that could steal a
   live executor's telemetry.
3. **Nothing in the runner writes `.claude/signals/active-epic`.** Pointer resolution is an
   orchestrator act at dispatch setup, and the unattended runner is not an orchestrator.

`hooks/tests/active-epic-fixtures.sh` section O proves guarantee 1 against the **real**
resolver in both hooks and across all three parser variants — including with an
`in flight` `plan.md` planted inside the reserved tree, which it still cannot select.

**Watching is the default.** `session-start-context.sh` reads `cycle.json` and tells any
session that opens whether a cycle is in flight, which issue is drafting, how many are done
and queued, and where to `tail` it. It costs no fork beyond the two `git rev-parse` calls
that find the canonical root: the record is written one key per line in a fixed order
precisely so a reader with neither `jq` nor `python3` can parse it with builtins. Writer and
reader are a **matched pair** — change the shape in `bin/intake-status.sh` and change it in
the hook; `hooks/tests/intake-control-plane-fixtures.sh` is what tells you that you did not.

**Is a cycle still running?** Two conditions, both builtins: the recorded `pid` answers
`kill -0`, **and** the recorded `lock` directory still exists. Requiring the lock is what
stops a recycled pid reading as a live cycle. The three ways a cycle can die are not the
same thing and are not reported as though they were:

| how it ended | what runs | what the record says |
|---|---|---|
| normally | the runner's own close | `finished`, or `failed` if an issue failed |
| abnormal exit, or a fatal untrapped signal such as **SIGHUP** | the EXIT trap | `interrupted`, with the reason |
| **SIGTERM** / SIGINT | the trap returns and the runner **carries on**, as it did before this item | the signal is recorded in the log and the ledger; the state is **not** changed |
| **SIGKILL** | nothing at all | stays non-terminal — and the *reader* infers it: a non-terminal state whose pid is gone **did not finish** |

That last row is the point of the whole design. A record reading `drafting` forever is
indistinguishable from a cycle still working, and one reading `finished` when the process
died is worse — wrong *and* plausible, which is the one a reader acts on.

**The flat log survives underneath** and now names the resolved control plane once per repo
(`control plane: <abs path>`), so a human who still tails `intake.log` is told where the
records they should be reading instead now live.

**It reports; it does not act.** Nothing in this path approves a plan, dispatches an item,
merges a PR or closes an issue, and no decision in the runner reads a telemetry variable —
proven by running the same cycle with the library removed and requiring the `gh` and
`claude` call streams, the drafted plan, the issue comments and stdout to be identical.

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

**Dispatch setup writes the pointer.** Alongside creating the worktree, in the main
checkout:

```bash
printf '%s\n' '<NN>-<slug>' > .claude/signals/active-epic   # which epic the hooks feed
```

One line, overwritten at every dispatch, `rm -f`'d at Phase 5 close. It is the precision
layer, not the safety net — forget it and resolution falls back to the newest **open**
`plan.md`, which is already correct in the observed failure case. What it buys is the case
the fallback cannot decide: two epics open at once, or an epic whose plan is being edited
while another epic's executor runs. Nothing consumes the pointer — the hooks only read it,
so it stays valid for the whole epic.

**Status survives the worktree split.** Hooks still resolve `CLAUDE_PROJECT_DIR` for
sentinels and markers, but every status path now resolves the canonical repo root, so the
executor's own writes and the hooks' writes land in one directory and key on the item and
the agent rather than on whichever branch a hook observed. Parallel worktree executors no
longer overwrite each other's status, and each item's `terminal` stamp is owner-matched.

**Residual limitation.** A **branch-name** selector in a cancel sentinel is still a no-op
under worktree dispatch — the gate compares against the orchestrator's branch, so the item
branch never matches (and, deliberately, the orchestrator's branch no longer matches every
executor at once). Cancel one executor by its **agent id**. The owner record now written at
`SubagentStart` makes a branch→agent mapping possible; restoring branch-selector granularity
on top of it is a recorded follow-on, not a shipped behaviour.

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
| A stop event from an agent that never started declaring someone's item finished | Owner-matched stamping: no start record, no stamp — and the stray stop lands in its own `agent-<id>.log`, so the real executor's bracket pair stays intact |
| Telemetry landing in an old or closed epic because its `plan.md` was edited most recently | Explicit `active-epic` pointer, and a fallback that only ever considers epics whose `**Status:**` is not `closed` (GH #9) |
| The pointer goes stale after an epic closes | Phase 5 removes it; a pointer to a missing directory falls back rather than erroring; the next dispatch overwrites it |
| Cancel ignored by the model | Impossible — PreToolUse denial is system-level, not advisory |
| Stale marker after a crashed run | Harmless to the gate and logger — both attribute per call by `agent_id` and never read markers; SubagentStop still clears markers >24h old, and they are safe to delete by hand |
| Scope grows mid-item | Executor's hard boundary: finish the agreed slice, propose the split in its return summary |
| An unattended drafting cycle running unseen | SessionStart reads `<epics-dir>/.intake/status/cycle.json` and says so to every session that opens |
| A cycle SIGKILLed mid-flight leaving a record that looks finished | The record keeps `pid` and `lock`; a non-terminal state whose pid is gone reads as **did not finish**, never as progress |
| A status write landing in the wrong epic | The writer takes an already-resolved path and refuses anything that is not a direct child of the tree it bound to; the reserved intake tree cannot address an epic folder at all |
| A record that may not reflect reality | `state: unknown` — out of band, so nothing reads it as progress — plus the rule that `origin` outranks `status.json` |
