---
description: Turn a GitHub/Azure DevOps issue into a filed epic (or file the issue first from a description), link both ways, and stop — this is an intake session, it never dispatches
allowed-tools: Bash(git:*), Bash(gh:*), Bash(az:*), Bash(ls:*), Bash(find:*), Bash(date:*), Read, Write, Edit, Glob, Grep
argument-hint: [issue ref, URL, or a free-text problem description — e.g. "#123", "AB#4571", "bug: OIC retry loop double-applies receipts"]
---

Run the intake process from the dev-epic-workflow skill (`references/issue-intake.md`).
Execute every step yourself — do not describe steps for the user to run. The tracker is
the system of record for what and why; the epic folder is the record of how.

**This command declares an intake session** (dev-epic-workflow's Session mode). Scope is
grounding and planning only — never touch code, never create a branch or worktree, never
dispatch a work item, and never offer to. That holds across every issue this session
intakes, not just the first; a session that runs `/intake` repeatedly stays in planning mode
the whole way through.

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

## 6. Stop — dispatch is a coding-session action, not this one

- Intake ends at filing and linking. Do **not** dispatch the first work item, create a
  worktree, or touch code — not even for a one-item epic that looks trivial. Phase 3
  dispatch happens in a coding session: later in this same session only if Jonathan
  explicitly says to switch modes ("go ahead and build it"), otherwise in a fresh session
  that picks up the approved epic.
- Reply with: the source ref, the epic path, and the work-item list with branches. Nothing
  narrative beyond that, and no offer to start building.
