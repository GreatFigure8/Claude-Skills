---
description: Checkpoint this session — commit + push, write the repo's one handoff, make it safe to /clear
allowed-tools: Bash(git:*), Bash(ls:*), Bash(find:*), Bash(date:*), Read, Write, Edit, Glob, Grep
argument-hint: [optional in-flight note, e.g. "chasing 401 on OIC connection test"]
---

Perform the full session checkpoint ritual from the dev-epic-workflow skill (Phase 3.5). Execute every step yourself — do not describe steps for the user to run.

## 1. Commit and push work-in-progress

- Run `git status --short` and `git branch --show-current`.
- If the tree is dirty, commit everything on the current work-item branch with a real message describing the state (WIP is acceptable as a prefix only if the message still says what's in flight). If changes span unrelated concerns, make separate commits.
- Push the branch. If it has no upstream, push with `-u origin <branch>`.
- If the tree was already clean and pushed, note that and continue.

## 2. Locate the ONE handoff file

**Every handoff in a repo is written to a single file: `docs/epics/handoff.md`** (use the repo's existing case for that folder — e.g. `DOCS/EPICS/handoff.md`). There is exactly one, at the root of the epics folder.

**Never write a handoff into an epic folder.** Per-epic handoffs make the next session hunt across every epic for the live one and pay for the search; one known path is the whole point. If `docs/epics/<NN-slug>/handoff.md` files exist from before this rule, fold anything still live into the single file and `git rm` them as part of this checkpoint.

Still identify the **active epic folder** (the folder under `docs/epics/` whose `plan.md` names a work item matching the current branch; if ambiguous, the most recently modified epic folder; if still ambiguous, ask). It goes in the `**Epic:**` field below so the next session can open the plan without searching. A session that touched no epic — intake, orchestration, a question — writes `none` there rather than guessing.

## 3. Write the handoff

Overwrite (never append) `docs/epics/handoff.md` using exactly this structure:

```markdown
# Session Handoff — <epic slug, or session kind> / work item <N>

**Written:** <ISO 8601 timestamp, from `date -u +%Y-%m-%dT%H:%M:%SZ`>
**Epic:** <path to the epic folder, e.g. docs/epics/12-oauth-refresh-rotation — or "none">
**Branch:** <branch> (pushed: yes)
**Last commit:** <short-hash> <subject>
**Worktree:** <output of `git rev-parse --show-toplevel`, or "main checkout">

## Verified this session
- <only facts actually checked against the repo, gates, or a live system, each with how it was checked>

## Claimed but NOT yet verified
- <anything believed done this session but not re-checked — be honest; this list is what the next session verifies first>

## In-flight (debugging / hypothesis state)
- <only when mid-debug; include $ARGUMENTS here if provided; otherwise omit this section>

## Exact next action
- <one imperative sentence>

## Environment state
- <running services, applied-but-unmerged migrations, env vars set this session, tunnels, seeded test data — or "none">

## Open questions for Jonathan
- <or "none">
```

Honesty rules: nothing goes under "Verified" without a command, diff, or gate that actually confirmed it this session. When in doubt, it goes under "Claimed but NOT yet verified". An empty Verified section is acceptable; an inflated one is not.

Overwrite rules: the handoff is a **snapshot of this session**, not a log — the previous session's copy is replaced, and its history stays in `git log docs/epics/handoff.md`. Carry a prior session's item forward only when it is genuinely still live (unmerged branch, unanswered question, unverified claim). If work described in the old handoff has since merged and nothing else is in flight, the new handoff simply doesn't mention it.

- If a `handoff-autosnapshot.md` exists at `docs/epics/handoff-autosnapshot.md` or `.claude/handoff-autosnapshot.md` (or, from before this rule, inside an epic folder), fold anything still relevant into the handoff and delete the autosnapshot — it is superseded.

## 4. Commit and push the handoff

- `git add` the handoff (plus any deleted autosnapshot or migrated per-epic handoffs), commit as `chore(epic): session handoff — <epic slug> item <N>`, and push.

## 5. Confirm

Reply with exactly: the branch, the last commit hash, the handoff path, and the line **"Checkpoint complete — safe to /clear or close this session. Next session will pick this up automatically."** Nothing else. Do not continue working after a handoff.
