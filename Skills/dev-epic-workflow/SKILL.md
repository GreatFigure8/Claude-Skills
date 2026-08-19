---
name: dev-epic-workflow
description: Jonathan's development process for any code change — plan first as an epic, one branch and one executor context per work item, commit early and often, verify what actually landed. Use whenever work involves writing, changing, refactoring, or shipping code in his repos (FastAPI/FastMCP, Oracle Fusion MCP tooling, OIC, Next.js, OCI, Supabase), or on "plan", "epic", "work item", "branch", "PR", "let's build", "refactor", "migrate". Also trigger for issue intake — picking up or filing GitHub issues / Azure DevOps work items ("pick up issue 123", "AB#", "file this as a bug", "/intake") — and for orchestrated execution — dispatching, monitoring, cancelling, or reconciling a work-item-executor subagent, status.json, "orchestrator", "is it blocked". Also for resuming an in-flight epic, verifying a step landed, merging approved PRs, deleting merged branches, and when context is filling or has compacted — "handoff", "checkpoint", "resume where we left off", "/clear", "new session", parallel sessions, git worktrees.
---

# Development Epic Workflow

This encodes how Jonathan works: **plan → branch → commit → sync → verify → close**. The plan is the contract; branches are the unit of delivery; commits are the audit trail; verification is what keeps the plan honest. Execution contexts are disposable; the epic folder is not. By default, work items run in **dispatched executor subagents** whose context dies when the item lands — the orchestrator session Jonathan sits in holds only plan-level state, so the old per-item handoff-and-clear ritual disappears.

The failure modes this exists to prevent, in order of how much damage they do:

1. **Coding before the plan is agreed.** Cost: rework, and a diff nobody can review.
2. **A branch that outgrows its work item.** Cost: an unreviewable PR and a mixed-concern history.
3. **Claiming a step landed when it silently didn't.** This has actually happened — an alignment change was reported complete and did not land, and it was only caught PRs later. Verification against the real diff is non-negotiable.
4. **Long-lived branches drifting from the integration branch.** Cost: merge archaeology.
5. **Conversational state outliving its context.** A compaction summary's — or an executor's return summary's — memory of file state is an unverified claim: the same failure class as #3, at a context boundary. State that matters gets written to disk before it's needed, not summarized after it's lost.

## Intake — issues in, epics out

Work can enter this workflow from an issue tracker, in both directions, with the tracker as the system of record for *what and why* and the epic folder as the record of *how*. Full mechanics — tracker detection (GitHub via `gh`, Azure DevOps via `az boards`), the linking contract, status mapping, batch pickup — live in `references/issue-intake.md`; the `/intake` command automates the whole path.

**Entry points are equivalent — the description always comes first, never the command.** Three ways in: (1) natural language mid-conversation ("bug: …", "file this as a work item", "pick up issue 123") — this triggers intake with no command at all and is the normal path; (2) `/intake <ref or description>` — the argument carries everything, and the classifier routes a ref to Pickup and free text to Report; (3) `/intake` with no argument — the only "command-first" case, and it doesn't precede a description: it lists the open backlog with a recommended pickup order and asks which item to take. There is never a step where `/intake` must be invoked before describing a problem; the command exists so the full ritual (tracker-first creation, linking, dispatch) runs deterministically, not as a gate in front of it.

- **Pickup**: Jonathan names or reports a GitHub issue / ADO work item ("pick up issue 123", "AB#4571", a pasted URL). Fetch the full item including comments, then run Phase 0 and Phase 1 as normal with the item as the requirements source; on approval, file the plan with a `Source:` ref in its header, link the epic back to the tracker item (comment + label/state + work-item checklist or child Tasks), and hand to Phase 3 for dispatch.
- **Report**: the problem arrives in conversation first ("bug: …", "file this as a work item"). Create the tracker item *first* — observed/expected/evidence, from stated facts only — confirm the ref in one line, then run Pickup with it.

Every epic born from intake keeps the tracker updated at phase boundaries (planned → in-progress → item ticks → closed), one terse comment per boundary — the fine grain stays in the commit stream and `status/`. A problem reported mid-epic that belongs to the current epic is not intake; it's Phase 3's scope rule plus a checklist line or child Task on the existing source item.

## Phase 0 — Ground the work before proposing anything

Never plan from recall. Before writing a plan, read the actual thing: the repo tree, the modules being touched, migrations, the tool contracts, the CI config, `git log`/`git branch -a` for where the branch lines currently sit. For Oracle Fusion, OIC, or Anthropic-product specifics, consult the relevant skill or live documentation rather than memory — and where a live environment or MCP tool can confirm a fact, confirm it.

State what was checked and what remains an assumption. An unverified assumption belongs in the plan's **Open questions**, not silently baked into a work item.

**Phase 0 applies to session resumes, not just new epics.** When a session starts inside an in-flight epic (the SessionStart hook will have injected the current handoff — see Phase 3.5), read `plan.md` and `handoff.md`, then re-ground from disk: `git log`, `git status`, `git diff`, and a grep for whatever the handoff claims was last done. The handoff describes where the previous session *believed* it was; the repo is where the work actually *is*. Verify before building on top. The same rule applies to an executor's return summary — it describes what the executor *believed* it did.

## Phase 1 — Write the plan (the epic)

One epic = one coherent outcome, decomposed into work items that each land independently. Use the structure in `references/plan-template.md`. The essentials:

- **Outcome** — what is true when the epic is done, in one paragraph.
- **Source** — the tracker ref (`Source: GH #<n>` / `Source: AB#<n>`) when the epic came through intake; omit only for untracked internal work.
- **Grounding** — what was inspected, and what's assumed.
- **Invariants** — what must not break while the epic is in flight (live installs keep working, tool names and contracts stay stable, no credential material in the repo, migrations stay forward-compatible).
- **Work items** — numbered, each with: branch name, scope, files/modules touched, definition of done, and what it explicitly does *not* do.
- **Sequence and dependencies** — which items unblock which.
- **Risk and rollback** — per item: how to undo it.
- **Deferred / out of scope** — the parking lot. Anything discovered mid-epic that isn't strictly needed goes here instead of into the current branch.

Then stop and get explicit approval before touching code. Approval is per-epic; if the shape changes, re-present the whole updated plan — never hand over a fragment to merge mentally. When it's an edit to an existing plan, apply the change and re-present the full revised plan document.

**On approval, file the plan.** Move the approved plan into the repo under `docs/epics/`, in a numbered folder ordered by implementation sequence, starting at `01`: `docs/epics/01-<epic-slug>/plan.md`, `docs/epics/02-<epic-slug>/plan.md`, and so on. The number is assigned when the plan is approved (next available number), not when it's drafted. This folder is the epic's home for the life of the epic — status updates, the Deferred parking lot, the runtime control-plane state (`status/`, `CANCEL`), any session handoff, and the closing retro all land in this folder, and any supporting artifacts for the epic live beside it. Committing the filed plan is the first commit of the epic. **When filing, also ensure the repo's `.gitignore` covers the runtime state**: `.claude/signals/`, `docs/epics/*/status/`, `docs/epics/*/CANCEL` (repo-mode installs of the automation add these automatically).

Sizing heuristic: a work item that can't be described in a few sentences, or whose diff would exceed a few hundred meaningful lines, is two work items. **An item whose execution regularly exhausts one executor's context is also two work items** — context exhaustion mid-item is a sizing signal, not a fact of life. Splitting is cheap; unsplitting is not.

## Phase 2 — Set the branch line

Establish, explicitly, before item 1:

- Which branch is **live/cutover** (untouched during the epic).
- Which branch is **integration** (where work items merge and get exercised together).
- Whether a **tag** is warranted first. Tag before any restructure, platform migration, or anything that would be painful to reconstruct — `pre-<epic-slug>` on the current live commit, pushed.

If the epic starts from a divergent state, reconcile it as step zero of the plan (collapse the stale branch, tag, then branch fresh) rather than carrying divergence into every item.

**Give every dispatched executor its own git worktree** (`git worktree add ../<repo>-<branch-slug> -b <branch> <integration>`) — the default for *every* dispatch, not a parallel-mode special case. **Concurrency exists at one item, not just at two:** while the executor owns the item branch, the orchestrator keeps working in the main checkout — amending `plan.md`, writing the handoff, committing the epic folder — and in a shared checkout those commits land on whatever branch the executor last switched to. This is not theoretical. It happened in epic 01 (GH #3): an orchestrator commit was silently diverted onto the item branch, and a `git push origin main` reported success while landing nothing. One executor per worktree, one worktree per in-flight work item; the worktree is created before dispatch and removed at land-and-reset (Phase 3 step 10). Worktrees share the repo's committed `.claude/` config, so hooks, the cancel gate, and commands work identically in each.

**Parallel items relax nothing** — each parallel item still gets its own worktree, and parallel executors run as background tasks, one per worktree. Items that depend on each other per the plan's sequence do not run in parallel; parallelism is for independent items only.

**Interim limitation — remove when the control-plane fix lands (epic 02, items 2–3).** The control-plane hooks resolve "current branch" from the orchestrator's checkout, not from the executor's worktree. In worktree mode that means branch-scoped cancel sentinels match nothing (the empty, cancel-everything sentinel still works), and each executor's `status/` files land under the *orchestrator's* branch slug instead of the item's. Until that is fixed, **dispatch serially** — one worktree executor at a time — so per-item status cannot collide.

## Phase 3 — Execute one work item at a time

**One executor context per work item.** The default execution mode is **orchestrated**: the interactive session Jonathan sits in is the *orchestrator* — it holds `plan.md`, sequencing, dispatch decisions, and verification, and it does not write item code. Each work item is dispatched to the **`work-item-executor` subagent** (installed at `.claude/agents/work-item-executor.md`), which runs the item in its own context and returns a summary; that context evaporates on return, which *is* the reset that previously required a handoff and a `/clear`. Do not carry an item's execution context into the next item — a merged item's context is dead weight and stale-state risk, and on large context windows it is also the most expensive habit available.

**Dispatch** names the epic folder, the work item number, the branch name, and any decisions resolved since the plan was filed, and instructs the executor to read `plan.md` itself. While an executor runs, the **control plane** keeps it observable and stoppable — status contract, telemetry feeds, deterministic cancel sentinel, reconciliation rules: `references/executor-control-plane.md`. Cancel = touch a file; watch = tail the status log or the commit stream, or don't watch at all.

**Direct mode** (the orchestrator-less fallback — executing an item in the interactive session itself) remains valid when Jonathan wants to drive an item hands-on, or when subagents aren't available. In direct mode the old rule applies unchanged: one session per work item, ending at land-and-reset via Phase 3.5's checkpoint.

The item lifecycle, whoever executes it — **in orchestrated mode the orchestrator performs steps 1–2 as dispatch setup (refresh the base, create the item's worktree), the executor runs steps 3–8 in that worktree and stops, and steps 9–10 belong to the orchestrator** (in direct mode, one session does all ten):

1. **Refresh the base first**, in the main checkout: `git switch <integration> && git pull --ff-only`. Never branch item N+1 from a stale local integration — the previous item's merge must be your starting commit.
2. **Create the item's worktree, branched from the freshly-synced integration branch** — `git worktree add ../<repo>-<branch-slug> -b <branch> <integration>`, using the naming in `references/git-conventions.md` — and dispatch the executor into that directory. This is the path for **every** dispatch, single-item flow included (Phase 2): the orchestrator keeps the main checkout, the executor owns the worktree, and neither can commit onto the other's branch. An executor that arrives in a prepared worktree **verifies** its branch (`git branch --show-current`) rather than re-creating it. *(Direct mode — one session doing all ten steps, no second agent, so no concurrency to isolate — needs no worktree: `git switch -c <branch>` in the main checkout is enough.)*
3. **Push the branch on the very first commit**, before it's finished. An unpushed branch is unbacked work — and the pushed commit stream is also the truest live telemetry the control plane has.
4. Commit early, commit often. Each commit is one reversible idea with a working tree that at least imports and passes typecheck. Commit before every context switch, before every sync, and before any context ends — never leave uncommitted work behind.
5. **Keep pure moves separate from behavior changes.** A rename/move/restructure commit contains zero logic change and says so; the behavior change is its own commit. This is what makes a big restructure reviewable.
6. Sync early and often: rebase onto the integration branch at least daily and always immediately before opening the PR. Resolve drift while it's small.
7. Run the stack gates in `references/stack-gates.md` before opening the PR — they're per-stack (uv/ruff/mypy/pytest, Alembic pairing, MCP tool-contract stability, Next.js typecheck/lint/build, OCI/OIC config).
8. Open the PR against the integration branch using `references/pr-template.md` — the body maps to the plan: which work item, what's in scope, what was deliberately left out, how it was verified — and, for intake epics, the tracker link (`Part of #<n>` / `AB#<n>`; `Closes #<n>` only on the epic's final item). When a repo doesn't yet have `.github/PULL_REQUEST_TEMPLATE.md`, adding it (from that same reference) is a one-commit chore item. *(Orchestrated mode: the executor reports `pr-opened` and returns here — it never merges.)*
9. **On approval, merge** — a merge commit into the integration branch (not a rebase onto it), so the landing point is preserved and merge-revert stays available as rollback. Approval means merge now; an approved-but-unmerged PR is drift waiting to happen. Before merging, the orchestrator runs Phase 4 verification cold against the executor's return summary.
10. **Land and reset — the branch dies with the merge, and the item's context dies with the branch.** Immediately after merging:
    - `git switch <integration> && git pull --ff-only` — confirm the merge commit is actually there (`git log --oneline -3`).
    - Delete the work-item branch **remotely**: `git push origin --delete <branch>` (skip if the platform auto-deletes on merge).
    - Delete it **locally**: `git branch -d <branch>` — use `-d`, not `-D`; if `-d` refuses, that's a signal something didn't land, so stop and check before forcing.
    - Remove the item's worktree — `git worktree remove ../<repo>-<branch-slug>` then `git worktree prune`. Every dispatched item has one, so this step is unconditional in orchestrated mode (direct mode has no worktree to remove).
    - `git fetch --prune` so stale remote-tracking refs disappear.
    - For intake epics: apply the merge touch from `references/issue-intake.md` — tick the item's checklist line (GH) or close the child Task (ADO).
    - Clean the item's control-plane state: remove `docs/epics/<NN-slug>/status/<branch-slug>.json` and `.log`, and any lingering `CANCEL` sentinel (all gitignored, so this is an `rm`, not a commit).
    - *(Orchestrated mode: dispatch the next item — the orchestrator session continues; no handoff, no clear.)* *(Direct mode: remove any stale `handoff.md` for the merged item, commit that cleanup, and **prompt Jonathan to end the session** — the next work item starts in a fresh session from this clean state.)*
    A merged branch that still exists is clutter; an unmerged branch that got deleted is lost work — the `-d`/prune discipline is what tells the two apart.

**When scope grows mid-item**, don't grow the branch. Split: land the agreed slice as PR A, and put the remainder in a follow-on item (PR B) with its own branch and its own approval — the way a transport extraction splits into "client extraction" then "async conversion." An executor proposes the split in its return summary and finishes the agreed slice; the orchestrator announces the split and updates the plan. An executor that hits genuine ambiguity reports `blocked` and returns — the orchestrator resolves it (with Jonathan if needed) and re-dispatches; decisions stay in the session Jonathan actually sits in.

## Phase 3.5 — Session boundaries and context checkpoints

In orchestrated mode, executor contexts end themselves — this phase now governs the **orchestrator session** (and any direct-mode session). The orchestrator carries only plan-level state, so its checkpoints are rare: end of the working day, an epic pause, or a long-running orchestrator that has genuinely filled. When a session must end, it ends through a **checkpoint**, never through reliance on auto-compaction. Full protocol, templates, and the automation that backs this phase: `references/session-handoff.md`.

**Checkpoint triggers.** Checkpoint when any of these appear:
- Direct mode only: the work item is done and merged (step 10 — the normal case for a direct-mode session).
- Context has visibly filled past roughly half the window on a session expected to continue substantially, or the statusline shows it climbing fast. On a large (1M-class) window the trigger is rarely the limit itself — it's cost and quality: every turn re-pays the whole context, and attention degrades before the window is full. An orchestrator that hits this trigger repeatedly is accumulating executor transcripts it shouldn't — dispatch summaries belong in the plan and the status files, not in conversation.
- Degradation symptoms: re-reading files already read this session, forgetting a decision made earlier in the session, drifting from the plan, re-proposing something already rejected.
- Any long agentic run is about to start that could push the session into auto-compact territory.
- The session is ending for the day. "Commit before ending a session" (Phase 3 step 4) and "checkpoint before ending a session" are the same ritual.

**Checkpoint ritual** (automated as the `/handoff` command — see references):
1. Commit and push the branch. No exceptions — an unpushed checkpoint is not a checkpoint. (An orchestrator with no item branch in flight commits the epic folder instead.)
2. Write (overwrite, don't append) `docs/epics/<NN-slug>/handoff.md` per the template in `references/session-handoff.md`: active work item and branch (or "between items"), last commit hash, what is **verified** vs. merely **claimed**, dispatch state (items in flight, blocked, awaiting merge), in-flight hypothesis if debugging, exact next action, live environment state (running services, applied migrations, env vars, tunnels).
3. Commit the handoff (`chore(epic): session handoff — <item>`) and push.
4. Tell Jonathan it's safe to `/clear` or close the terminal. Ending the session is his keystroke; everything on both sides of it is automated.

The handoff is a **snapshot, not a log** — each checkpoint overwrites it. It captures only the delta that lives in conversation; epic-level truth stays in `plan.md`, item-level runtime truth stays in `status/`, durable conventions stay in `CLAUDE.md`, and everything else is on disk in git. Small handoff, fast resume.

**Resume ritual.** The SessionStart hook injects the current handoff and git state automatically at session start. Then Phase 0's resume rule applies: verify the handoff's claims against the repo before building on them. If the handoff says a test passed, the fast path is running it, not believing it.

**Compaction is the narrow exception, never the default.** Guided `/compact <focus instructions>` is acceptable only mid-debug, when the hypothesis chain genuinely lives in conversation and the next stable checkpoint hasn't been reached — and it is followed by a real checkpoint at the next stable point. Auto-compact firing is treated as an incident, not a workflow: the PreCompact hook snapshots state to disk first, and the post-compact session re-grounds from disk exactly as a resume would, trusting nothing the summary claims about file state.

**Bootstrap — install the automation once, not per repo.** The default is a **user-level** install: `bash <skill-path>/assets/claude-config/install.sh --user` puts the hooks (session grounding, PreCompact snapshot, SessionEnd guard, statusline, **and the executor control plane: cancel gate, subagent lifecycle, tool logger**), the `work-item-executor` agent, and the `/handoff` and `/intake` commands into `~/.claude/`, where they apply to every repo and worktree on the machine with nothing committed into any repo (right for client repos). Run it once per machine. Use **repo mode** (`install.sh --commit`, run inside the repo, committed like the PR-template rule in Phase 3 step 8) only when the repo itself must carry the automation — cloud sessions, teammates, self-contained repos; repo mode also gitignores the control plane's runtime state. Never both for the same repo: hooks append, so both would fire and duplicate the injection. The installer merges into existing `settings.json` without clobbering and is idempotent — re-running it is also how updated scripts roll out. When Claude has shell access, Claude checks whether the automation is present (`~/.claude/hooks/session-start-context.sh` or `.claude/hooks/`) and runs the installer itself rather than describing it. **Updating**: skill content saved to the claude.ai account syncs to Claude Code (Cowork/cloud sessions automatically; local machines after a one-time `CLAUDE_CODE_SYNC_SKILLS=1 claude -p "ok"`) — but a local copy at `~/.claude/skills/dev-epic-workflow` overrides a synced one with the same name, so remove the local folder when switching to the synced path. Synced content does not by itself update `~/.claude/` hooks/agents/commands; whenever the skill version in context is newer than what is installed, Claude re-runs `install.sh` (idempotent) rather than assuming the payload matches.

## Phase 4 — Verify what landed, not what was claimed

Before marking any work item done, check the real artifact:

- `git log --oneline <base>..HEAD` and `git diff --stat <base>...HEAD` — does the diff match the stated scope, nothing more, nothing less?
- Grep for the specific symbols/paths the item promised to add, change, or delete. If the item said something was deleted, confirm it's gone.
- Deleted-scaffolding items are the easiest to fake and the most important to check.
- Run the gates on the merged integration branch, not just the feature branch.

In orchestrated mode this verification is structurally cold: the orchestrator never shared the executor's context, so it *cannot* have inherited the executor's belief that something landed — it checks the return summary against the repo the same way it would check a stranger's PR. **The repo decides, not the task list**: if the tasks/agent UI claims an executor is still running but `status.json` is terminal and the PR exists on origin, the item is done; a stuck sidebar never stalls the epic (see `references/executor-control-plane.md`, Layer 3).

Report the verification, then update the plan: mark the item done, move any discoveries into Deferred, and re-present the plan's current state so the next item starts from truth. If a previous item's claim doesn't hold up, say so plainly and re-open it before building on top of it.

## Phase 5 — Close the epic

- Every work item verified done or explicitly deferred.
- Temporary scaffolding actually deleted (legacy shims, compat shims, feature flags that served the migration, **the epic's `handoff.md`, any `handoff-autosnapshot.md`, and the epic's `status/` directory and any `CANCEL` sentinel**). Scaffolding is temporary by design; leaving it converts a migration into permanent maintenance.
- Every item worktree removed at its own land-and-reset (Phase 3 step 10), so at close `git worktree list` shows only the main checkout and any worktree belonging to a *different* in-flight epic. A surviving worktree for a merged item means step 10 was skipped — check the branch actually landed before removing it.
- Integration branch exercised as a whole, then merged to live as a drop-in replacement — stable external contracts (tool names, endpoints, schemas) so existing installs don't notice.
- For intake epics: close the loop in the tracker — retro summary comment on the source item; the final PR's `Closes #<n>` (GH) or a state transition to Resolved/Closed (ADO) retires it.
- Tag the release, then write the short retro into the plan doc: what got split, what got deferred, what surprised us.

## Reference files

- `references/plan-template.md` — the plan document structure, plus a worked example.
- `references/git-conventions.md` — branch naming, commit message format, sync/rebase rules, tags.
- `references/pr-template.md` — the canonical PR body; also drops into repos as `.github/PULL_REQUEST_TEMPLATE.md`.
- `references/stack-gates.md` — pre-PR gates per stack: Python/FastAPI/FastMCP, uv monorepo, migrations, MCP tool contracts, Next.js/Shadcn, OCI + OIC ID Domains, Supabase/pgvector.
- `references/session-handoff.md` — the session-boundary protocol: handoff template, checkpoint/resume rituals, worktree quick reference, and installation of the automation.
- `references/issue-intake.md` — tracker intake in both directions: GitHub/`gh` and Azure DevOps/`az boards` mechanics, the epic↔issue linking contract, status mapping at phase boundaries, batch pickup, and the report-first path.
- `references/executor-control-plane.md` — orchestrated execution: the status contract (`status.json` milestones), telemetry feeds (commit stream, status log, `/tasks`/agent view), the deterministic cancel protocol (sentinel files + PreToolUse gate), reconciliation rules, dispatch conventions, and the failure-mode table.
- `assets/claude-config/` — the drop-in automation: hook scripts (SessionStart context injection, PreCompact snapshot, SessionEnd guard, statusline, PreToolUse cancel gate, SubagentStart/Stop lifecycle, PostToolUse tool logger), `settings.json` hook wiring, the `/handoff` and `/intake` slash commands, the `work-item-executor` agent definition (`agents/`), and `install.sh`, the idempotent installer that puts it all into `~/.claude/` (user mode) or a repo's `.claude/` (repo mode) as the Phase 3.5 bootstrap.

## Working style notes

- Don't hand back a fragment and ask for it to be merged into a document by hand. Apply the edit and present the full updated artifact.
- Don't assert that something works, exists, or landed without having looked. "I haven't verified this yet" is a complete and acceptable sentence — for executors reporting status as much as for anyone else.
- Prefer doing the mechanical step over describing it — run the command, read the file, check the log.
- At a land-and-reset, the orchestrator proactively proposes the next dispatch (or the epic close) rather than idling; at a checkpoint, proactively offer the next step (end the session, resume fresh) rather than silently continuing in a heavy session.
