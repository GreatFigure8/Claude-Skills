# Skill text: delete every merged branch and its worktrees, merge commits only (1.6.0)

**Slug:** `skill-text-merged-branch-cleanup-and-merge-commits-only`
**Run:** `bmn-merged-branch-cleanup-and-no-squash-merges` · plugin `Skills/dev-bother-me-nope/`

## Story

**As** Jonathan,
**I want** the dev-bother-me-nope skill, briefs and report to say, and to run, that
whenever bmn merges a working branch it deletes that branch and **every** worktree on it,
locally and on origin, that every PR merge deletes its source branch, and that bmn never
squash-merges,
**so that** each run leaves no stale branches or worktrees, and `dev` keeps the full
history of every change.

## Context

Input: "when code is merged to dev from a working branch, ALL worktrees on that branch and
the branch are to be deleted from local. If an origin branch is merged it should be deleted
from origin. Each PR should delete the source branch from the remote. NO MORE SQUASH
MERGING. I want history from here on out."

Touchpoints (stack.md; paths under `Skills/dev-bother-me-nope/`):
- `skills/dev-bother-me-nope/SKILL.md`: pipeline (15-16), *Branches and worktrees* table and
  *Cleanup is a step* (74-97), *Merging never builds* (99-130), the `bmn.json` schema
  (151-168), leftover sweep (186-187), INTAKE (224-245), BUILD integrator (299-306),
  MERGE→dev① (308-314), FIX①/MERGE②/REPORT (361-387), CLEANUP 10b (398-420).
- `skills/dev-bother-me-nope/references/briefs.md`: integrator (206-226), merger (229-246),
  cleaner (249-279).
- `skills/dev-bother-me-nope/references/move-computers.md` (29-32, 65-69), which says
  `wip/` branches "stay on origin until CLEANUP deletes them". That is stale once the
  integrator deletes merged branches right away.
- `skills/dev-bother-me-nope/references/report-template.md` (6, 67-70: *Git cleanup*).
- `agents/bmn-worker.md` (17-19), `.claude-plugin/plugin.json` (`version` 1.5.0).

Decisions this story writes down (stack.md assumptions 2-6, not reopened):
- Temp branches (`wip/<run-slug>/*`): the integrator deletes each one right after merging it
  into the run branch (target `origin/{integration}`). The run branch is **not** deleted
  after MERGE→dev①, because FIX① still branches from it. It goes at CLEANUP, after its final
  merge to `dev` (target `origin/dev`).
- "Deleted" means every worktree that has the branch checked out, from
  `git worktree list --porcelain`, not only the ones in `bmn.json`. It also means the local
  branch, and the origin copy once it is an ancestor of the target. Never `--force`. Dirty
  or locked worktrees, the main checkout, and branches not proven merged are left and
  recorded in `cleanup.left`.
- No squash, ever: `git merge --no-ff` only. Any PR bmn merges uses
  `gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`.
- INTAKE runs the repo-merge-policy helper once and records the result. Skipped or failed
  is an assumption, never a blocker.

Fixed helper contracts (built by story `merged-branch-cleanup-and-repo-merge-policy-scripts`;
the text calls them exactly like this):

```
python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <path> --branch <name> --target <ref> [--remote origin] [--no-fetch] [--dry-run]
  → {"branch","target","dry_run","deleted":["worktree:<path>","local:<b>","origin:<b>"],"left":[{"ref","why"}]}; exit 0 ran, 2 refused
python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py [--repo-path <dir>] [--repo OWNER/NAME] [--dry-run]
  → {"repo","status":"changed|already-set|dry-run|skipped|failed","changes":{field:{old,new}},"reason"}; exit 0 (2 = usage)
```

## Acceptance criteria

Each criterion is checked by a pytest in the new file
`Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py`. The tests read the
Markdown/JSON and assert that the named section exists and contains the required strings.
Section lookup is by heading text, so the tests survive line shifts.

1. **[unit]** `.claude-plugin/plugin.json` parses as JSON and has `"version": "1.6.0"`. Its
   `description` mentions merge commits only / never squash and deleting merged branches with
   their worktrees.
2. **[unit]** SKILL.md has a section whose heading contains "never squash" (e.g.
   `## Merge commits only — never squash (Jonathan's rule, 2026-10-03)`). Its body
   contains `--no-ff`, `git merge --squash`, `gh pr merge`, `merge_method=squash`,
   `--delete-branch`, the words "deploy guard", and `2026-10-03`. It says that bmn never
   squashes, that its merges are merge commits that keep history, and that the guard blocks
   squash merges while a run is active.
3. **[unit]** PR rule: both SKILL.md and briefs.md (merger section) contain
   `gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`. SKILL.md explains that
   the `--repo` form deletes only the remote head branch and leaves every local checkout
   alone, and that local copies go through `merged-branch-cleanup.py`.
4. **[unit]** *Branches and worktrees*: the section contains `merged-branch-cleanup.py`,
   `git worktree list --porcelain`, "every worktree", "main checkout" and "`--force`" in a
   never/without sentence. The *Deleted* column of the table says temp branches go
   "as soon as the integrator has merged it" (local, origin and every worktree on it), and
   that the run branch goes at CLEANUP after its last merge to `dev`, not after MERGE→dev①,
   because FIX① still branches from it. The sentence "Cleanup only ever touches those" is
   replaced by one that also covers every worktree that has a recorded branch checked out.
5. **[unit]** *Cleanup is a step*: the paragraph runs
   `${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py` with `--repo`, `--branch` and
   `--target`, and says its `deleted`/`left` JSON goes into `bmn.json.cleanup` and the
   report's *Git cleanup* section. The old hand-written sequence (`git branch -D` then
   `git push origin --delete`) no longer appears as the procedure.
6. **[unit]** briefs.md integrator section: for each branch it merged, it runs
   `merged-branch-cleanup.py` with `--target origin/{integration}`. The paired
   harness-branch rule ("no commits unique to it") stays. It still returns
   `deleted[]`/`left[{ref, why}]`.
7. **[unit]** briefs.md cleaner section: temp refs are cleaned with `merged-branch-cleanup.py`
   `--target origin/{integration}`, and the run branch with `--target origin/dev`, gated as
   today on `integration_pushed` for the origin copy. The record step (dev worktree commit,
   `deploymentEnabled` key removal, `phase: done|blocked`) is unchanged. SKILL.md 10b
   CLEANUP and the *leftover sweep* paragraph name the same script and targets.
8. **[unit]** briefs.md merger section: it merges with `git merge --no-ff`, states it never
   squashes (`--squash` appears only in a never-sentence), and states it doesn't delete the
   run branch (CLEANUP does).
9. **[unit]** INTAKE: a numbered INTAKE step runs
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py --repo-path {run_worktree}`
   once per run (not on resume when `repo_policy` is already set). It writes the JSON to
   `bmn.json.repo_policy`. A `skipped`/`failed` status is added to `assumptions`, never to
   `blocker`. The `bmn.json` schema block includes a `"repo_policy"` key. The text names the
   two settings it enforces (`allow_squash_merge=false`, `delete_branch_on_merge=true`) and
   records that this is Jonathan's standing instruction of 2026-10-03.
10. **[unit]** report-template.md has a *Repo merge settings* line or section, filled from
    `repo_policy`, that shows `allow_squash_merge` and `delete_branch_on_merge` old → new,
    or "unchanged: <reason>". *Git cleanup* lists the removed worktrees per branch, including
    ones bmn didn't create, and every `left` entry with its reason.
11. **[unit]** move-computers.md no longer contains "stay on origin until CLEANUP". It says
    merged `wip/` branches were already deleted (local, origin, worktrees) when the
    integrator merged them, and that only unmerged ones remain on origin.
12. **[unit]** agents/bmn-worker.md has a bullet saying merges are merge commits only
    (`--no-ff`, never squash), and that any PR merge is
    `gh pr merge <n> --merge --delete-branch`. The deletion bullet says that removing every
    worktree that has a brief-named merged branch checked out is part of that branch's
    cleanup.
13. **[unit]** Squash is only ever forbidden: every line in the files this story owns
    (SKILL.md, briefs.md, move-computers.md, report-template.md, bmn-worker.md) that
    contains `squash` (case-insensitive), once the setting name `allow_squash_merge` is
    removed from the line, also contains one of `never`, `no `, `not`, `block`, `blocks`,
    `blocked`, `forbidden`.
14. **[unit]** The full suite
    `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
    passes. The new test file doesn't import or exec either helper script, so it doesn't
    depend on the parallel scripts story landing first.

## Out of scope

- The helper scripts themselves (story `merged-branch-cleanup-and-repo-merge-policy-scripts`).
- `deploy-guard.py`, its tests and `references/deploy-guards.md` (story
  `deploy-guard-blocks-squash-merges`). This story only describes the guard's merge rule in
  SKILL.md.
- `references/stack-routing.md`, `hooks/hooks.json`, the repo-root marketplace.json and README.
- dev-epic-workflow (`epic-loop.sh` uses `gh pr merge --merge` without `--delete-branch`),
  dev-story-sprint and dev-story-flow. The orchestrator names them in the report (stack.md
  assumption 1).
- Changing this repository's GitHub settings now. The first run of 1.6.0 INTAKE does it.

## Deps

None. The helper CLIs and guard behaviour are fixed contracts above. The tests only read
text, so this story builds in the same wave as the other two.

## Assumptions

- The python-library-quality skills named in the run brief weren't installed in the
  splitter's session. The planner and coder load them if available.
- This story owns the `plugin.json` bump to 1.6.0 and every skill Markdown file except
  `references/deploy-guards.md`. That keeps the three stories on disjoint files.
- Markdown criteria are verified by text-presence tests (orchestrator's instruction). The
  tests check required commands and phrases within the named section, not exact prose.
- The `--repo` form of `gh pr merge` skips local branch deletion, so bmn's PR merges never
  switch or delete anything in Jonathan's main checkout. The planner verifies this against
  the gh source (`pkg/cmd/pr/merge/merge.go`, `CanDeleteLocalBranch` is false when `--repo`
  is set) with `gh search code` before writing it down. If that's wrong, the text says to
  run `gh pr merge` from outside any checkout instead.
- `bmn.json.repo_policy` is a new key holding the helper's JSON verbatim. Older runs without
  it are fine, and resume treats a missing key as "not run yet" only during INTAKE.
