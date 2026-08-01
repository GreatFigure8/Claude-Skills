---
name: dev-epic-workflow
description: Jonathan's development process for any code change — plan first as an epic, one branch per work item, commit early and often, sync early and often, verify what actually landed. Use this whenever work involves writing, changing, refactoring, restructuring, or shipping code in his repos (FastAPI/FastMCP services, Oracle Fusion MCP tooling, OIC integrations, Next.js/Shadcn UIs, OCI-hosted apps, Supabase/pgvector), or whenever he says "plan", "epic", "work item", "branch", "PR", "let's build", "refactor", "restructure", "migrate", or asks how to sequence a change. Trigger even when the request sounds like a single small change — the point of this skill is that "small" changes still get a plan, a branch, and a commit trail. Also trigger when reviewing or resuming an in-flight epic, when a branch outgrows its plan, when confirming a previous step really landed, or at the loop's tail — merging approved PRs, deleting merged branches (remote and local), pruning stale branches, or resetting for the next item.
---

# Development Epic Workflow

This encodes how Jonathan works: **plan → branch → commit → sync → verify → close**. The plan is the contract; branches are the unit of delivery; commits are the audit trail; verification is what keeps the plan honest.

The failure modes this exists to prevent, in order of how much damage they do:

1. **Coding before the plan is agreed.** Cost: rework, and a diff nobody can review.
2. **A branch that outgrows its work item.** Cost: an unreviewable PR and a mixed-concern history.
3. **Claiming a step landed when it silently didn't.** This has actually happened — an alignment change was reported complete and did not land, and it was only caught PRs later. Verification against the real diff is non-negotiable.
4. **Long-lived branches drifting from the integration branch.** Cost: merge archaeology.

## Phase 0 — Ground the work before proposing anything

Never plan from recall. Before writing a plan, read the actual thing: the repo tree, the modules being touched, migrations, the tool contracts, the CI config, `git log`/`git branch -a` for where the branch lines currently sit. For Oracle Fusion, OIC, or Anthropic-product specifics, consult the relevant skill or live documentation rather than memory — and where a live environment or MCP tool can confirm a fact, confirm it.

State what was checked and what remains an assumption. An unverified assumption belongs in the plan's **Open questions**, not silently baked into a work item.

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

**On approval, file the plan.** Move the approved plan into the repo under `docs/epics/`, in a numbered folder ordered by implementation sequence, starting at `01`: `docs/epics/01-<epic-slug>/plan.md`, `docs/epics/02-<epic-slug>/plan.md`, and so on. The number is assigned when the plan is approved (next available number), not when it's drafted. This folder is the epic's home for the life of the epic — status updates, the Deferred parking lot, and the closing retro all land in this same plan doc, and any supporting artifacts for the epic live beside it in the folder. Committing the filed plan is the first commit of the epic.

Sizing heuristic: a work item that can't be described in a few sentences, or whose diff would exceed a few hundred meaningful lines, is two work items. Splitting is cheap; unsplitting is not.

## Phase 2 — Set the branch line

Establish, explicitly, before item 1:

- Which branch is **live/cutover** (untouched during the epic).
- Which branch is **integration** (where work items merge and get exercised together).
- Whether a **tag** is warranted first. Tag before any restructure, platform migration, or anything that would be painful to reconstruct — `pre-<epic-slug>` on the current live commit, pushed.

If the epic starts from a divergent state, reconcile it as step zero of the plan (collapse the stale branch, tag, then branch fresh) rather than carrying divergence into every item.

## Phase 3 — Execute one work item at a time

Per item:

1. **Refresh the base first**: `git switch <integration> && git pull --ff-only`. Never branch item N+1 from a stale local integration — the previous item's merge must be your starting commit.
2. Branch from the freshly-synced integration branch — `git switch -c <branch>` — using the naming in `references/git-conventions.md`.
3. **Push the branch on the very first commit**, before it's finished. An unpushed branch is unbacked work.
4. Commit early, commit often. Each commit is one reversible idea with a working tree that at least imports and passes typecheck. Commit before every context switch, before every sync, and before ending a session — never leave a session with uncommitted work.
5. **Keep pure moves separate from behavior changes.** A rename/move/restructure commit contains zero logic change and says so; the behavior change is its own commit. This is what makes a big restructure reviewable.
6. Sync early and often: rebase onto the integration branch at least daily and always immediately before opening the PR. Resolve drift while it's small.
7. Run the stack gates in `references/stack-gates.md` before opening the PR — they're per-stack (uv/ruff/mypy/pytest, Alembic pairing, MCP tool-contract stability, Next.js typecheck/lint/build, OCI/OIC config).
8. Open the PR against the integration branch with a body that maps to the plan: which work item, what's in scope, what was deliberately left out, how it was verified.
9. **On approval, merge** — a merge commit into the integration branch (not a rebase onto it), so the landing point is preserved and merge-revert stays available as rollback. Approval means merge now; an approved-but-unmerged PR is drift waiting to happen.
10. **Land and reset — the branch dies with the merge.** Immediately after merging:
    - `git switch <integration> && git pull --ff-only` — confirm the merge commit is actually there (`git log --oneline -3`).
    - Delete the work-item branch **remotely**: `git push origin --delete <branch>` (skip if the platform auto-deletes on merge).
    - Delete it **locally**: `git branch -d <branch>` — use `-d`, not `-D`; if `-d` refuses, that's a signal something didn't land, so stop and check before forcing.
    - `git fetch --prune` so stale remote-tracking refs disappear.
    The next work item starts back at step 1 from this clean state. A merged branch that still exists is clutter; an unmerged branch that got deleted is lost work — the `-d`/prune discipline is what tells the two apart.

**When scope grows mid-item**, don't grow the branch. Split: land the agreed slice as PR A, and put the remainder in a follow-on item (PR B) with its own branch and its own approval — the way a transport extraction splits into "client extraction" then "async conversion." Announce the split and update the plan.

## Phase 4 — Verify what landed, not what was claimed

Before marking any work item done, check the real artifact:

- `git log --oneline <base>..HEAD` and `git diff --stat <base>...HEAD` — does the diff match the stated scope, nothing more, nothing less?
- Grep for the specific symbols/paths the item promised to add, change, or delete. If the item said something was deleted, confirm it's gone.
- Deleted-scaffolding items are the easiest to fake and the most important to check.
- Run the gates on the merged integration branch, not just the feature branch.

Report the verification, then update the plan: mark the item done, move any discoveries into Deferred, and re-present the plan's current state so the next item starts from truth. If a previous item's claim doesn't hold up, say so plainly and re-open it before building on top of it.

## Phase 5 — Close the epic

- Every work item verified done or explicitly deferred.
- Temporary scaffolding actually deleted (legacy shims, compat shims, feature flags that served the migration). Scaffolding is temporary by design; leaving it converts a migration into permanent maintenance.
- Integration branch exercised as a whole, then merged to live as a drop-in replacement — stable external contracts (tool names, endpoints, schemas) so existing installs don't notice.
- Tag the release, then write the short retro into the plan doc: what got split, what got deferred, what surprised us.

## Reference files

- `references/plan-template.md` — the plan document structure, plus a worked example.
- `references/git-conventions.md` — branch naming, commit message format, sync/rebase rules, tags, PR body template.
- `references/stack-gates.md` — pre-PR gates per stack: Python/FastAPI/FastMCP, uv monorepo, migrations, MCP tool contracts, Next.js/Shadcn, OCI + OIC ID Domains, Supabase/pgvector.

## Working style notes

- Don't hand back a fragment and ask for it to be merged into a document by hand. Apply the edit and present the full updated artifact.
- Don't assert that something works, exists, or landed without having looked. "I haven't verified this yet" is a complete and acceptable sentence.
- Prefer doing the mechanical step over describing it — run the command, read the file, check the log.
