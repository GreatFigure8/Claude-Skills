---
name: dev-epic-workflow
description: Jonathan's development process for any code change — plan first as an epic, one branch per work item, one session per work item, commit early and often, sync early and often, verify what actually landed. Use this whenever work involves writing, changing, refactoring, restructuring, or shipping code in his repos (FastAPI/FastMCP services, Oracle Fusion MCP tooling, OIC integrations, Next.js/Shadcn UIs, OCI-hosted apps, Supabase/pgvector), or whenever he says "plan", "epic", "work item", "branch", "PR", "let's build", "refactor", "restructure", "migrate", or asks how to sequence a change. Trigger even when the request sounds like a single small change — the point of this skill is that "small" changes still get a plan, a branch, and a commit trail. Also trigger when reviewing or resuming an in-flight epic, when a branch outgrows its plan, when confirming a previous step really landed, or at the loop's tail — merging approved PRs, deleting merged branches (remote and local), pruning stale branches, or resetting for the next item. Also trigger when a session's context is filling or has just compacted, when handing off or resuming a coding session ("handoff", "checkpoint", "resume where we left off", "/clear", "compact", "new session"), or when setting up parallel sessions or git worktrees.
---

# Development Epic Workflow

This encodes how Jonathan works: **plan → branch → commit → sync → verify → close**. The plan is the contract; branches are the unit of delivery; commits are the audit trail; verification is what keeps the plan honest. Sessions are disposable; the epic folder is not.

The failure modes this exists to prevent, in order of how much damage they do:

1. **Coding before the plan is agreed.** Cost: rework, and a diff nobody can review.
2. **A branch that outgrows its work item.** Cost: an unreviewable PR and a mixed-concern history.
3. **Claiming a step landed when it silently didn't.** This has actually happened — an alignment change was reported complete and did not land, and it was only caught PRs later. Verification against the real diff is non-negotiable.
4. **Long-lived branches drifting from the integration branch.** Cost: merge archaeology.
5. **Conversational state outliving its session.** A compaction summary's memory of file state is an unverified claim — the same failure class as #3, at the session boundary. State that matters gets written to disk before it's needed, not summarized after it's lost.

## Phase 0 — Ground the work before proposing anything

Never plan from recall. Before writing a plan, read the actual thing: the repo tree, the modules being touched, migrations, the tool contracts, the CI config, `git log`/`git branch -a` for where the branch lines currently sit. For Oracle Fusion, OIC, or Anthropic-product specifics, consult the relevant skill or live documentation rather than memory — and where a live environment or MCP tool can confirm a fact, confirm it.

State what was checked and what remains an assumption. An unverified assumption belongs in the plan's **Open questions**, not silently baked into a work item.

**Phase 0 applies to session resumes, not just new epics.** When a session starts inside an in-flight epic (the SessionStart hook will have injected the current handoff — see Phase 3.5), read `plan.md` and `handoff.md`, then re-ground from disk: `git log`, `git status`, `git diff`, and a grep for whatever the handoff claims was last done. The handoff describes where the previous session *believed* it was; the repo is where the work actually *is*. Verify before building on top.

## Phase 1 — Write the plan (the epic)

One epic = one coherent outcome, decomposed into work items that each land independently. Use the structure in `references/plan-template.md`. The essentials:

- **Outcome** — what is true when the epic is done, in one paragraph.
- **Grounding** — what was inspected, and what's assumed.
- **Invariants** — what must not break while the epic is in flight (live installs keep working, tool names and contracts stay stable, no credential material in the repo, migrations stay forward-compatible).
- **Work items** — numbered, each with: branch name, scope, files/modules touched, definition of done, and what it explicitly does *not* do.
- **Sequence and dependencies** — which items unblock which.
- **Risk and rollback** — per item: how to undo it.
- **Deferred / out of scope** — the parking lot. Anything discovered mid-epic that isn't strictly needed goes here instead of into the current branch.

Then stop and get explicit approval before touching code. Approval is per-epic; if the shape changes, re-present the whole updated plan — never hand over a fragment to merge mentally. When it's an edit to an existing plan, apply the change and re-present the full revised plan document.

**On approval, file the plan.** Move the approved plan into the repo under `docs/epics/`, in a numbered folder ordered by implementation sequence, starting at `01`: `docs/epics/01-<epic-slug>/plan.md`, `docs/epics/02-<epic-slug>/plan.md`, and so on. The number is assigned when the plan is approved (next available number), not when it's drafted. This folder is the epic's home for the life of the epic — status updates, the Deferred parking lot, the session handoff, and the closing retro all land in this folder, and any supporting artifacts for the epic live beside it. Committing the filed plan is the first commit of the epic.

Sizing heuristic: a work item that can't be described in a few sentences, or whose diff would exceed a few hundred meaningful lines, is two work items. **An item whose execution regularly spans more than one session's context is also two work items** — context exhaustion mid-item is a sizing signal, not a fact of life. Splitting is cheap; unsplitting is not.

## Phase 2 — Set the branch line

Establish, explicitly, before item 1:

- Which branch is **live/cutover** (untouched during the epic).
- Which branch is **integration** (where work items merge and get exercised together).
- Whether a **tag** is warranted first. Tag before any restructure, platform migration, or anything that would be painful to reconstruct — `pre-<epic-slug>` on the current live commit, pushed.

If the epic starts from a divergent state, reconcile it as step zero of the plan (collapse the stale branch, tag, then branch fresh) rather than carrying divergence into every item.

**When work items will run in parallel sessions**, give each parallel item its own **git worktree** (`git worktree add ../<repo>-<branch-slug> <branch>`) so every Claude Code session has its own checked-out branch and working tree — no two sessions fighting over one checkout. One session per worktree, one worktree per in-flight work item. Worktrees share the repo's committed `.claude/` config, so hooks and commands work identically in each. Items that depend on each other per the plan's sequence do not run in parallel — parallelism is for independent items only.

## Phase 3 — Execute one work item at a time

**One session per work item.** A work item's session begins when its branch is created and ends at land-and-reset (step 10). Do not carry a session across work items — the merged item's context is dead weight and stale-state risk for the next one, and on large context windows it is also the most expensive habit available: every turn re-processes the full accumulated context.

Per item:

1. **Refresh the base first**: `git switch <integration> && git pull --ff-only`. Never branch item N+1 from a stale local integration — the previous item's merge must be your starting commit.
2. Branch from the freshly-synced integration branch — `git switch -c <branch>` — using the naming in `references/git-conventions.md`. (In parallel mode: create the worktree instead — `git worktree add ../<repo>-<branch-slug> -b <branch> <integration>` — and start the session there.)
3. **Push the branch on the very first commit**, before it's finished. An unpushed branch is unbacked work.
4. Commit early, commit often. Each commit is one reversible idea with a working tree that at least imports and passes typecheck. Commit before every context switch, before every sync, and before ending a session — never leave a session with uncommitted work.
5. **Keep pure moves separate from behavior changes.** A rename/move/restructure commit contains zero logic change and says so; the behavior change is its own commit. This is what makes a big restructure reviewable.
6. Sync early and often: rebase onto the integration branch at least daily and always immediately before opening the PR. Resolve drift while it's small.
7. Run the stack gates in `references/stack-gates.md` before opening the PR — they're per-stack (uv/ruff/mypy/pytest, Alembic pairing, MCP tool-contract stability, Next.js typecheck/lint/build, OCI/OIC config).
8. Open the PR against the integration branch using `references/pr-template.md` — the body maps to the plan: which work item, what's in scope, what was deliberately left out, how it was verified. When a repo doesn't yet have `.github/PULL_REQUEST_TEMPLATE.md`, adding it (from that same reference) is a one-commit chore item.
9. **On approval, merge** — a merge commit into the integration branch (not a rebase onto it), so the landing point is preserved and merge-revert stays available as rollback. Approval means merge now; an approved-but-unmerged PR is drift waiting to happen.
10. **Land and reset — the branch dies with the merge, and the session dies with the branch.** Immediately after merging:
    - `git switch <integration> && git pull --ff-only` — confirm the merge commit is actually there (`git log --oneline -3`).
    - Delete the work-item branch **remotely**: `git push origin --delete <branch>` (skip if the platform auto-deletes on merge).
    - Delete it **locally**: `git branch -d <branch>` — use `-d`, not `-D`; if `-d` refuses, that's a signal something didn't land, so stop and check before forcing.
    - If the item ran in a worktree: `git worktree remove ../<repo>-<branch-slug>` then `git worktree prune`.
    - `git fetch --prune` so stale remote-tracking refs disappear.
    - Remove `handoff.md` from the epic folder if the completed item's handoff is still there (a handoff for a merged item is stale state), commit that cleanup, and **prompt Jonathan to end the session** — the next work item starts in a fresh session from this clean state.
    A merged branch that still exists is clutter; an unmerged branch that got deleted is lost work — the `-d`/prune discipline is what tells the two apart.

**When scope grows mid-item**, don't grow the branch. Split: land the agreed slice as PR A, and put the remainder in a follow-on item (PR B) with its own branch and its own approval — the way a transport extraction splits into "client extraction" then "async conversion." Announce the split and update the plan.

## Phase 3.5 — Session boundaries and context checkpoints

Sessions end at work-item boundaries by default (step 10). When a session must end **mid-item** — context filling, degradation symptoms, end of the working day, or a deliberate switch to another parallel item — it ends through a **checkpoint**, never through reliance on auto-compaction. Full protocol, templates, and the automation that backs this phase: `references/session-handoff.md`.

**Checkpoint triggers.** Checkpoint when any of these appear:
- The work item is done and merged (step 10 — the normal case).
- Context has visibly filled past roughly half the window on a session expected to continue substantially, or the statusline shows it climbing fast. On a large (1M-class) window the trigger is rarely the limit itself — it's cost and quality: every turn re-pays the whole context, and attention degrades before the window is full.
- Degradation symptoms: re-reading files already read this session, forgetting a decision made earlier in the session, drifting from the plan, re-proposing something already rejected.
- Any long agentic run is about to start that could push the session into auto-compact territory.
- The session is ending for the day. "Commit before ending a session" (Phase 3 step 4) and "checkpoint before ending a session" are the same ritual.

**Checkpoint ritual** (automated as the `/handoff` command — see references):
1. Commit and push the branch. No exceptions — an unpushed checkpoint is not a checkpoint.
2. Write (overwrite, don't append) `docs/epics/<NN-slug>/handoff.md` per the template in `references/session-handoff.md`: active work item and branch, last commit hash, what is **verified** vs. merely **claimed**, in-flight hypothesis if debugging, exact next action, live environment state (running services, applied migrations, env vars, tunnels).
3. Commit the handoff (`chore(epic): session handoff — <item>`) and push.
4. Tell Jonathan it's safe to `/clear` or close the terminal. Ending the session is his keystroke; everything on both sides of it is automated.

The handoff is a **snapshot, not a log** — each checkpoint overwrites it. It captures only the mid-item delta that lives in conversation; epic-level truth stays in `plan.md`, durable conventions stay in `CLAUDE.md`, and everything else is on disk in git. Small handoff, fast resume.

**Resume ritual.** The SessionStart hook injects the current handoff and git state automatically at session start. Then Phase 0's resume rule applies: verify the handoff's claims against the repo before building on them. If the handoff says a test passed, the fast path is running it, not believing it.

**Compaction is the narrow exception, never the default.** Guided `/compact <focus instructions>` is acceptable only mid-debug, when the hypothesis chain genuinely lives in conversation and the next stable checkpoint hasn't been reached — and it is followed by a real checkpoint at the next stable point. Auto-compact firing is treated as an incident, not a workflow: the PreCompact hook snapshots state to disk first, and the post-compact session re-grounds from disk exactly as a resume would, trusting nothing the summary claims about file state.

**Bootstrap chore item.** Any repo that lacks the session automation gets it installed as a one-commit chore item, exactly like the PR-template rule in Phase 3 step 8: copy `assets/claude-config/` from this skill into the repo's `.claude/` (hooks scripts, `settings.json` hook wiring, the `/handoff` command, the statusline), `chmod +x` the scripts, commit. From then on the behavior in this phase is deterministically enforced by hooks, not just remembered by Claude.

## Phase 4 — Verify what landed, not what was claimed

Before marking any work item done, check the real artifact:

- `git log --oneline <base>..HEAD` and `git diff --stat <base>...HEAD` — does the diff match the stated scope, nothing more, nothing less?
- Grep for the specific symbols/paths the item promised to add, change, or delete. If the item said something was deleted, confirm it's gone.
- Deleted-scaffolding items are the easiest to fake and the most important to check.
- Run the gates on the merged integration branch, not just the feature branch.

Report the verification, then update the plan: mark the item done, move any discoveries into Deferred, and re-present the plan's current state so the next item starts from truth. If a previous item's claim doesn't hold up, say so plainly and re-open it before building on top of it.

## Phase 5 — Close the epic

- Every work item verified done or explicitly deferred.
- Temporary scaffolding actually deleted (legacy shims, compat shims, feature flags that served the migration, **the epic's `handoff.md` and any `handoff-autosnapshot.md`**). Scaffolding is temporary by design; leaving it converts a migration into permanent maintenance.
- Stale worktrees removed (`git worktree list` should show only the main checkout and any worktrees belonging to a *different* in-flight epic).
- Integration branch exercised as a whole, then merged to live as a drop-in replacement — stable external contracts (tool names, endpoints, schemas) so existing installs don't notice.
- Tag the release, then write the short retro into the plan doc: what got split, what got deferred, what surprised us.

## Reference files

- `references/plan-template.md` — the plan document structure, plus a worked example.
- `references/git-conventions.md` — branch naming, commit message format, sync/rebase rules, tags.
- `references/pr-template.md` — the canonical PR body; also drops into repos as `.github/PULL_REQUEST_TEMPLATE.md`.
- `references/stack-gates.md` — pre-PR gates per stack: Python/FastAPI/FastMCP, uv monorepo, migrations, MCP tool contracts, Next.js/Shadcn, OCI + OIC ID Domains, Supabase/pgvector.
- `references/session-handoff.md` — the session-boundary protocol: handoff template, checkpoint/resume rituals, worktree quick reference, and installation of the automation.
- `assets/claude-config/` — the drop-in repo automation: hook scripts (SessionStart context injection, PreCompact snapshot, SessionEnd guard, statusline), `settings.json` hook wiring, and the `/handoff` slash command. Installed into repos as the Phase 3.5 bootstrap chore item.

## Working style notes

- Don't hand back a fragment and ask for it to be merged into a document by hand. Apply the edit and present the full updated artifact.
- Don't assert that something works, exists, or landed without having looked. "I haven't verified this yet" is a complete and acceptable sentence.
- Prefer doing the mechanical step over describing it — run the command, read the file, check the log.
- At a land-and-reset or a checkpoint, proactively offer the next step (end the session, start the next item fresh) rather than silently continuing in a heavy session.
