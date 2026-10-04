# Merged-branch cleanup and repo merge-policy helper scripts

**Slug:** `merged-branch-cleanup-and-repo-merge-policy-scripts`
**Run:** `bmn-merged-branch-cleanup-and-no-squash-merges` · plugin `Skills/dev-bother-me-nope/`

## Story

**As** Jonathan, who runs dev-bother-me-nope (bmn) on many repos,
**I want** two small, deterministic helpers — one that deletes a merged branch together with
**every** worktree that has it checked out (locally and on origin), and one that switches the
GitHub repo to "no squash merges, delete the head branch on merge" —
**so that** merged work never leaves stale worktrees or branches behind, history is kept as
real merge commits, and the skill text can call one tested command instead of re-describing
a fragile multi-step git procedure to every worker.

## Context

- Today the integrator, merger and cleaner briefs
  (`skills/dev-bother-me-nope/references/briefs.md` 206-279) and SKILL.md *Cleanup is a step*
  (93-97) / 10b CLEANUP (398-420) describe deletion as prose: `merge-base --is-ancestor`,
  `git worktree remove` (no `--force`), `git branch -D`, `git push origin --delete`. They
  touch only the worktrees recorded in `bmn.json`, so a second worktree that has the same
  branch checked out (Jonathan's, or a harness worktree that wasn't recorded) is left behind.
- stack.md assumption 2: after a branch's final merge, every worktree with that branch
  checked out is removed, the local branch is deleted, and the origin copy is deleted once it
  is an ancestor of the merge target. Assumption 3: never `--force`; dirty worktrees and
  branches not proven merged are left and recorded.
- stack.md assumptions 4-6: INTAKE sets the GitHub repo's `delete_branch_on_merge=true` and
  `allow_squash_merge=false`, records old → new, and treats missing admin rights or a missing
  / unauthenticated `gh` as "record and continue", never a blocker.
- The plugin ships executables under `Skills/dev-bother-me-nope/assets/bin/` (today only
  `deploy-guard.py`, python3 stdlib only) and tests under `assets/tests/` (pytest, run with
  `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`).
  Skill text reaches scripts as `${CLAUDE_PLUGIN_ROOT}/assets/bin/<name>` (the dev-story-flow
  plugin does the same with `sprint-state.sh`).
- The deploy guard only sees the Bash command line (`python3 …/merged-branch-cleanup.py …`),
  not the git commands the script runs, so the script must not become a way around the
  guard's protected-branch rule.

### Fixed contracts (the skill-text story calls these exactly; do not change them)

```
python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py \
    --repo <path> --branch <name> --target <ref> [--remote origin] [--no-fetch] [--dry-run]
stdout: {"branch": "...", "target": "...", "dry_run": false,
         "deleted": ["worktree:<abs path>", "local:<branch>", "<remote>:<branch>"],
         "left": [{"ref": "worktree:<abs path>|local:<branch>|<remote>:<branch>", "why": "..."}]}
exit 0 = ran (inspect "left"); exit 2 = refused or usage error, stdout {"error": "..."}, nothing touched

python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py \
    [--repo-path <dir>] [--repo OWNER/NAME] [--dry-run]
stdout: {"repo": "OWNER/NAME"|null,
         "status": "changed|already-set|dry-run|skipped|failed",
         "changes": {"<field>": {"old": <bool>, "new": <bool>}},
         "reason": null|"..."}
exit 0 in every non-usage case (skipped/failed are recorded, never blocking); exit 2 = usage error
```

## Acceptance criteria

Every integration test builds real throwaway repos under `tmp_path`: a bare `origin`, a main
checkout cloned from it, and linked worktrees. No test touches the network or the real `gh`.

### merged-branch-cleanup.py

1. **[integration]** Merged branch in two linked worktrees: `wip/r/a` is merged `--no-ff` into
   `feat/r`, both pushed, and `wip/r/a` is checked out in two linked worktrees (neither is the
   main checkout). `--branch wip/r/a --target origin/feat/r` removes both worktrees, deletes
   the local branch and `origin/wip/r/a`, prints `deleted` containing both
   `worktree:<abs path>` entries plus `local:wip/r/a` and `origin:wip/r/a`, an empty `left`,
   and exits 0. Afterwards `git worktree list --porcelain` names neither path and both refs
   are gone.
2. **[integration]** Dirty worktree is never forced: one of the two worktrees has a modified
   tracked file and an untracked file. That worktree is left with a `why` naming uncommitted
   changes, and both files are byte-identical afterwards. The clean worktree is removed. The
   local branch is left with a `why` naming the worktree that still has it checked out. The
   merged origin copy is still deleted. A `git` shim on `PATH` records every argv, and no
   recorded `worktree remove` or `branch` call contains `--force`, `-f` or a doubled `-ff`.
3. **[integration]** Locked worktree: a worktree locked with `git worktree lock` is left with a
   `why` naming the lock and is not unlocked. The local branch is left with it.
4. **[integration]** Unmerged branch: when the branch has a commit that isn't in `--target`,
   nothing is deleted. `left` has `local:<branch>` with "not merged into <target>" and the
   origin copy with the same reason when it exists. Exit 0.
5. **[integration]** Origin ahead of target: the local copy is merged but `origin/<branch>` has
   an extra commit that isn't in the target. The local copy and its clean worktrees are deleted.
   The origin copy is left with "origin has commits not in <target>".
6. **[integration]** Main checkout: when the main checkout (the first entry of
   `git worktree list --porcelain`) has the branch checked out, it is never removed or
   switched. The local branch is left with "checked out in the main checkout". The merged
   origin copy is still deleted.
7. **[integration]** Remote-only branch: after a machine move there is no local ref, only
   `origin/<branch>`, which is an ancestor of the target. The origin copy is deleted and
   reported as `origin:<branch>`.
8. **[integration]** Stale worktree entries are pruned first: when a worktree's directory was
   deleted by hand, `git worktree prune` runs before the scan, so that entry doesn't block
   deleting the local branch.
9. **[integration]** `--dry-run`: the output lists what would be deleted and left, using the
   same JSON shape with `"dry_run": true`. Local refs, `origin` refs and
   `git worktree list --porcelain` are identical before and after.
10. **[integration]** Fetch: by default the script runs `git fetch --prune <remote>` before
    checking ancestry. `--no-fetch` skips it, and the git shim confirms no fetch ran.
11. **[unit]** Refusals (exit 2, `{"error": …}` on stdout, nothing run but read-only git):
    the names `main`, `master`, `dev`, `develop`, `prod`, `production`, `release` and
    `staging`; the remote's default branch (`refs/remotes/<remote>/HEAD`); a branch equal to
    the target's branch name; names starting with `-` or failing
    `git check-ref-format --branch`; a `--target` ref that doesn't resolve; a `--repo` that
    isn't a git work tree; missing required args.
12. **[unit]** Safe execution: every git call is a `subprocess.run` argument list (never
    `shell=True`) and runs as `git -C <path> …`. The script never runs `checkout`, `switch`,
    `reset`, `stash`, `merge`, `rebase` or `pull` in any worktree; the git-shim argv log
    across the integration tests confirms this.

### repo-merge-policy.py

All tests put a fake `gh` (a small Python script driven by a JSON fixture, logging argv)
first on `PATH`. A fixture fails the test if any other `gh` would be found first.

13. **[integration]** Changes needed: the fake repo reports `allow_squash_merge: true`,
    `delete_branch_on_merge: false`, `allow_merge_commit: true` and `permissions.admin: true`.
    Exactly one `gh api -X PATCH repos/OWNER/NAME` call sends typed booleans
    (`-F allow_squash_merge=false -F delete_branch_on_merge=true`). The values are then read
    back and confirmed. The output has `status: "changed"` and `changes` showing old → new
    for both fields. Exit 0.
14. **[integration]** Already compliant: no PATCH call, `status: "already-set"`,
    `changes: {}`.
15. **[integration]** Merge commits kept possible: when `allow_merge_commit` is false, the
    same single PATCH also sets `allow_merge_commit=true` and records it in `changes`.
    `allow_rebase_merge` is never sent.
16. **[integration]** No admin rights (`permissions.admin: false`): no PATCH,
    `status: "skipped"`, and a `reason` naming missing admin rights on OWNER/NAME. Exit 0.
17. **[integration]** No usable gh: `gh` is not on `PATH`, `gh auth status` exits non-zero,
    or `gh repo view` fails because there is no GitHub remote. Each gives
    `status: "skipped"` with a distinct `reason` and exit 0.
18. **[integration]** Rejected or not applied: the PATCH exits non-zero (e.g. HTTP 403/422
    text), or the read-back still shows the old values. Either gives `status: "failed"` and a
    `reason` holding the first line of gh's error, with no token or auth header text. Exit 0.
19. **[unit]** `--dry-run`: no PATCH, `status: "dry-run"`, and `changes` shows the planned
    old → new.
20. **[unit]** Repo resolution: `--repo` must match `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`, and
    anything else exits 2. Without `--repo`, the name comes from
    `gh repo view --json nameWithOwner -q .nameWithOwner` run in `--repo-path` (default: the
    current directory). The gh JSON is validated: a missing field or wrong type gives
    `status: "skipped"` with a reason, never a traceback.

### Both

21. **[unit]** Quality gates: `uv run --quiet --with ruff ruff check
    Skills/dev-bother-me-nope` is clean. Both scripts are python3-stdlib-only, executable
    (`chmod +x`, `#!/usr/bin/env python3`), under 400 lines each, with a module docstring
    stating purpose, contract and safety rules. Functions stay under 50 lines and nothing
    mutates shared state in place. The full suite
    `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
    passes.

## Out of scope

- Wiring the scripts into SKILL.md, briefs.md, report-template.md, move-computers.md or
  bmn-worker.md, and the `plugin.json` version bump. Story
  `skill-text-merged-branch-cleanup-and-merge-commits-only` owns those files.
- The deploy guard and `references/deploy-guards.md` (story
  `deploy-guard-blocks-squash-merges`).
- Harness-branch deletion by the "no commits unique to it" rule. That stays as prose in
  the briefs. The script deletes one named branch by ancestry only.
- Running either script against a real repo or the real GitHub API, including this repo's
  settings.
- dev-epic-workflow / dev-story-sprint / dev-story-flow (stack.md assumption 1).

## Deps

None. The contracts above are fixed, so the skill-text story builds in parallel.

## Assumptions

- The python-library-quality skills named in the run brief (`keeping-git-repos-clean`,
  `guarding-destructive-operations`) were not installed in the splitter's session. The
  planner and coder load them if available; otherwise they follow the rules restated here
  (no `--force`, ancestry proof before delete, dry-run, refusal list, argv-only subprocess).
- A dedicated cleanup script was added beyond the orchestrator's examples. "Every worktree
  that has the branch checked out" needs `git worktree list --porcelain` parsing, and that
  is only reliably testable as code, not as brief prose.
- The protected-name list copies deploy-guard.py's `PROTECTED_BRANCHES` and adds `dev`,
  `develop` and `staging`. It is duplicated rather than imported because `deploy-guard.py`
  has a hyphenated name and must stay importable-free and standalone.
- `left` never makes the script fail. Exit 2 is reserved for refusals and usage errors, so
  callers can record `left` straight into `bmn.json.cleanup.left`.
- When `allow_merge_commit` is false, repo-merge-policy also turns it on. GitHub needs at
  least one merge method enabled, and merge commits are how bmn keeps history. Rebase-merge
  settings are left as they are (stack.md assumption 5).
- A status of `failed` or `skipped` still exits 0, because repo settings are never a
  blocker (stack.md assumption 6).
