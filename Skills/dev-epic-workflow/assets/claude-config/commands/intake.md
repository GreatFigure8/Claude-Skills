---
description: Turn a GitHub/Azure DevOps issue into a filed epic (or file the issue first from a description), link both ways, and hand to the orchestrator
allowed-tools: Bash(git:*), Bash(gh:*), Bash(az:*), Bash(ls:*), Bash(find:*), Bash(date:*), Read, Write, Edit, Glob, Grep
argument-hint: [issue ref, URL, or a free-text problem description — e.g. "#123", "AB#4571", "bug: OIC retry loop double-applies receipts"]
---

Run the intake process from the dev-epic-workflow skill (`references/issue-intake.md`).
Execute every step yourself — do not describe steps for the user to run. The tracker is
the system of record for what and why; the epic folder is the record of how.

## 1. Detect the tracker and verify access

- `git remote get-url origin` → github.com = GitHub (`gh`), dev.azure.com /
  visualstudio.com = Azure DevOps (`az boards`). If the repo's `CLAUDE.md` declares a
  `Tracker:` line, that wins. If neither resolves it, ask once and offer to record the
  answer in `CLAUDE.md`.
- Verify auth (`gh auth status` / a trivial `az boards query`). If unauthenticated,
  report exactly what's missing and stop — do not half-run intake.

## 2. Classify $ARGUMENTS

- **A ref or URL** (`#123`, `123`, `AB#4571`, an issue/work-item URL) → **Pickup**: go
  to step 3.
- **A description** (anything else, e.g. prefixed `bug:` / `issue:` / `feature:`) →
  **Report**: create the tracker item FIRST — title as an imperative summary; body with
  observed behavior, expected behavior, evidence, and stated constraints (facts Jonathan
  gave, not invented detail). Confirm the new ref in one line ("Filed as GH #124" /
  "Filed as AB#4571"), then continue to step 3 with that ref.
- **Empty** → list open items (`gh issue list` / `az boards query` per the reference),
  present a recommended pickup order (dependencies and blast radius, not recency), and
  ask which to intake. Then continue with the chosen ref.

## 3. Fetch and ground (Phase 0)

- Fetch the full item — body, labels/type, comments (comments are requirements context).
- Ground against the actual repo per Phase 0: the issue says what hurts; the repo says
  what's true. Material discrepancies go into the plan's Open questions AND back to the
  tracker as one terse comment.

## 4. Draft the plan (Phase 1)

- Draft `plan.md` per `references/plan-template.md`, with `Source: GH #<n>` or
  `Source: AB#<n>` directly under the title. Acceptance criteria from the issue map into
  the work items' definitions of done. Scale to the issue — a one-line bug gets a
  proportionally small plan, never a skipped one.
- Present the full plan and stop for approval. Do not touch code, the tracker state, or
  `docs/epics/` numbering until approval.

## 5. On approval: file and link back (same turn)

- File the plan at `docs/epics/<NN>-<slug>/plan.md` (next available number), ensure the
  runtime-state gitignore lines exist, commit as the epic's first commit, push.
- Link back per the intake reference's contract:
  - **GitHub**: comment the plan permalink on the issue; add label `epic:planned`
    (create it if absent); add the work-item checklist (`<item NN>: <name> (<branch>)`).
  - **Azure DevOps**: set the source item `Active` with a discussion comment carrying the
    plan link; create one child Task per work item, parent-related to the source item.

## 6. Hand to the orchestrator (Phase 3)

- This session IS the orchestrator unless one is already running elsewhere. State the
  dispatch order, then dispatch the first work item to the `work-item-executor` subagent
  per Phase 3 — epic folder, item number, branch name, resolved decisions — and apply
  the intake status mapping as boundaries are crossed (`epic:in-progress` / Task
  `Active` on dispatch; checklist tick / Task `Closed` on merge).
- Reply with: the source ref, the epic path, the work-item list with branches, and which
  item was dispatched. Nothing narrative beyond that.
