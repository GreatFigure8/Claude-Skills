# Merged-branch cleanup and no squash merges — dev-bother-me-nope report

**Run:** `bmn-merged-branch-cleanup-and-no-squash-merges` · **Finished:** 2026-10-04T02:51:00Z · **Outcome:** ✅ done, merged to `dev`, stopped for you
**Stack:** library (skill Markdown + Python hook + stdlib Python helpers) · skills used: python-library-quality:keeping-git-repos-clean, python-library-quality:guarding-destructive-operations (named in every brief; not installed in this session, so workers followed the rules the stories restate)
**Design:** no UI in this run
**Merged to dev:** `4d26d44` (MERGE①), `190ff8e` (MERGE②), plus the report merge

## Stopped for Jonathan — the run is done

code → review → fix → review → report. The run did REVIEW①, one fix round (FIX①) and
REVIEW②, then stopped. Nothing REVIEW② found was fixed. Nothing was released, promoted to
`main` or deployed, and no further round was started. Anything below is a **new goal, and
only you decide whether there is one**.

**Built:**
- *Skill text (plugin 1.6.0):* SKILL.md, briefs, move-computers, report template and the worker agent now say that once a branch is merged to `dev` (or a temp branch into the run branch), every worktree on it, the local branch and its merged origin copy are deleted. All merges are merge commits only (never squash), and any PR bmn merges uses `gh pr merge --merge --delete-branch`.
- *Deploy guard:* while a run is active it blocks `git merge --squash`, `gh pr merge --squash/-s`, `gh pr merge` without `--delete-branch`, `merge_method=squash` via `gh api`, and deleting `dev`/`main`/the default branch on origin. It also sees through `timeout`/`sudo`/`env`/`nice`/`nohup`/`xargs`/`sh -c` wrappers.
- *Helpers:* `assets/bin/merged-branch-cleanup.py` removes every worktree on a merged branch, then the local branch, then the origin copy (CAS-guarded). It keeps dirty, ignored-file-holding, rebasing or unmerged ones and records why. `assets/bin/repo-merge-policy.py` sets the GitHub repo's `delete_branch_on_merge=true` and `allow_squash_merge=false` at INTAKE when you have admin rights, and records old→new in `bmn.json.repo_policy`.

**FIX① fixed:** 10 of 10 REVIEW① findings + 1 TEST① failure — R1-1 … R1-10 (R1-4 was the TEST① failure)
**FIX① not reproducible / blocked:** none
**Left open:** REVIEW② C/H/M/L 0/1/1/4 + 0 TEST② failures + 0 REVIEW① items still open
or regressed. All of them are listed under *Left open* below, HIGH first.

**Decisions that are yours**
1. **Left-open items:** start a new goal for them, or accept them as they are. R2-1 (HIGH) only affects a run branch that was never pushed, which is rare, but it can delete an ignored `.env`.
2. **Release / promotion `dev` → `main`:** ready. Nothing is held back.
3. **Making 1.6.0 live:** the plugin's local marketplace reads the main checkout. That checkout is still on local `dev` at `2aa149b`, and bmn never touches it. To go live, fast-forward it to `origin/dev` and update the plugin. Until then every session keeps loading 1.5.0.
4. **This repo's GitHub settings are unchanged:** `delete_branch_on_merge=false` and `allow_squash_merge=true`. The next bmn INTAKE here applies the new policy, or it can be applied now on your word.
5. **Out of scope, left as they are:**
   - dev-epic-workflow `epic-loop.sh:507,841` runs `gh pr merge --merge` without `--delete-branch`.
   - Branches merged before this run, which bmn never names, were not touched: local `feat/bmn-as-plugin`, `feat/bmn-vercel-dev-rules`, `feat/dev-bother-me-nope`, `feat/fix-refresh-live-git-c-cwd-hook`, `fix/*`, `sprint/2026-09-11-00*`, ~27 `worktree-agent-*`, and their 3 origin copies.
6. **DB:** nothing.

## Deploy checklist — nothing was deployed to Vercel; Supabase MAIN untouched

**Vercel:** no Vercel project in this repo, so there is nothing to deploy.

**Supabase:** no Supabase in this repo; no migrations.

**Env vars / secrets to add:** none.

## Summary
You asked that bmn delete every worktree and the local branch once work is merged to `dev`,
delete merged origin branches, have PRs delete their source branch, and stop squash merging.
The run changed the dev-bother-me-nope plugin (1.5.0 → 1.6.0) in three stories: the skill
text and briefs, a guard that blocks squash and branch-keeping PR merges during a run, and two
helpers that do the cleanup and set the repo's merge policy. Everything is merged to `dev`
with merge commits. The suite went from 106 to 476 tests, all passing on Python 3.13 and on
the system Python 3.9, which the hook runs on. The helpers have about 94% coverage. Six
REVIEW② items are left open for you.

## Stories
| Story | Result | Tests (unit/int/browser) | REVIEW① C/H/M/L | Fixed in FIX① | Left open | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| skill-text-merged-branch-cleanup-and-merge-commits-only | ✅ merged | ~50 text checks / smoke / — | 0/0/1/1 | R1-7, R1-10 | R2-1 (H), R2-3 (L) | owns plugin.json bump to 1.6.0 |
| deploy-guard-blocks-squash-merges | ✅ merged | ~150 / 8 guard smoke / — | 0/0/1/0 (+R1-6 run) | R1-5, R1-6 | R2-4, R2-5 (L) | 93% coverage; fixed 12 pre-existing ruff errors |
| merged-branch-cleanup-and-repo-merge-policy-scripts | ✅ merged | ~170 / 14 cleanup smoke / — | 0/1/3/2 | R1-1, R1-2, R1-3, R1-4, R1-8, R1-9 | R2-2 (M) | 94% coverage each; stdlib-only, runs on 3.9 |

**Reviews (`/code-review` high, one pass each):** REVIEW① C/H/M/L 0/1/5/4 · REVIEW②
re-check 10 fixed / 0 still-open / 0 regressed / 0 not-reproducible · REVIEW② new C/H/M/L 0/1/1/4 ·
`docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/review.md`

## Assumptions I made instead of asking
1. "Bother me not" means the dev-bother-me-nope plugin only. dev-epic-workflow and dev-story-sprint are out of scope.
2. "Merged to dev from a working branch" means every branch bmn merges into `dev`, plus every temp branch merged into the run branch. The run branch is deleted at CLEANUP, after its last merge, not after MERGE①, because FIX① still branches from it.
3. Removal is never forced. Bmn keeps a worktree, and records why, when it:
   - has uncommitted changes,
   - holds ignored files other than regenerable caches (`__pycache__`, `.pytest_cache`, `.ruff_cache`, `.mypy_cache`, `.venv`, `node_modules`, `.next`),
   - is mid-rebase or mid-bisect,
   - or sits on a branch not proven merged with `merge-base --is-ancestor`.
4. "Each PR deletes its source branch":
   - bmn's PR merges use `gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`, never `--auto`, because gh doesn't delete the branch on auto-merge;
   - INTAKE also sets the repo's `delete_branch_on_merge=true`, so UI merges delete the branch too.
5. "No more squash merging" covers bmn's merges, which are always `--no-ff`, the guard, and the repo's `allow_squash_merge=false`. `allow_merge_commit` is turned on if it was off. Rebase merges are not mentioned in your story, so they are left alone.
6. Changing repo settings needs admin rights. Without them, or without gh auth, INTAKE records that and continues. It is not a blocker.
7. The helpers are invoked as `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/…`. `CLAUDE_PLUGIN_ROOT` is empty inside workers, so the orchestrator substitutes the full plugin path in every brief.
8. CLEANUP runs the helper from the main checkout (`git -C`), so it never removes the worktree it runs in. Temp branches are cleaned before the run branch.
9. Deletes are compare-and-swap: `update-ref -d <ref> <sha>` locally and `push --delete --force-with-lease=<ref>:<sha>` on origin. The guard allows both forms and the plain `push --delete` of wip and run branches.
10. `--target` must name a branch or tag. A SHA or a commit expression is refused.
11. When the run branch was never pushed, the cleaner does the local cleanup itself and skips the origin delete. R2-1 is about this path.
12. R1-6 was owned by `run` but lives in `deploy-guard.py`, so the guard's fixer took it to keep one writer per file.
13. `BMN_USER_APPROVED_DEPLOY=1` lifts the new protected-branch delete block, the same way it lifts a push to `main`. Squash and branch-keeping PR-merge blocks can't be lifted. R2-4 flags the first half of this.

## FIX① — what the fix round did
- **R1-1** (HIGH): fixed. `test_worktree_holding_an_ignored_file_is_kept_with_the_file`.
- **R1-2**: fixed. `test_refuses_target_that_is_a_commit_expression_not_a_ref[~0, @{0}, ^{commit}, sha]`.
- **R1-3**: fixed. `test_branch_being_rebased_or_bisected_keeps_local_branch[rebase, bisect]`.
- **R1-4 / TEST①** (`sys.stdlib_module_names` on 3.9): fixed. `test_script_imports_stdlib_only` passes on 3.9, and a fallback test was added.
- **R1-5**: fixed. `test_blocks_merges_behind_wrappers_that_take_options` (28 commands) and `test_blocks_deploys_behind_wrappers_that_take_options`.
- **R1-6**: fixed. `test_blocks_deleting_protected_branches_on_origin` (20 forms) and `test_blocks_deleting_the_default_branch`.
- **R1-7**: fixed. `test_unpushed_run_branch_is_still_deleted_locally` and `test_unpushed_run_branch_names_the_local_only_steps`.
- **R1-8**: fixed. `test_stale_entry_holding_the_branch_is_removed_and_other_stale_entries_kept`.
- **R1-9**: fixed. `test_refuses_default_branch_when_origin_head_is_not_set_locally` and `test_refuses_when_the_default_branch_cannot_be_determined`.
- **R1-10**: fixed. `test_every_helper_invocation_uses_the_plugin_root_form[SKILL.md]` and `test_the_skill_and_briefs_do_invoke_the_helpers`.

## Left open — not fixed by this run
- **R2-1 HIGH**, `SKILL.md:482` and `references/briefs.md:285`. The local-only cleanup for an unpushed run branch (the R1-7 fix) uses plain `git worktree remove` and claims git refuses a dirty worktree. Git doesn't refuse ignored files, it deletes them. So a never-pushed run branch whose worktree holds a `.env` loses it. This path also skips the rebase/bisect check. Reproduced by the reviewer.
- **R2-2 MEDIUM**, `assets/bin/merged-branch-cleanup.py:39`. `CACHE_DIRS` is too narrow. `next-env.d.ts`, `*.tsbuildinfo`, `test-results/`, `playwright-report/`, `.coverage` and `.DS_Store` each keep their worktree and branch, so Next.js and Playwright runs never finish their cleanup. The result is safe but leaves leftovers.
- **R2-3 LOW**, `SKILL.md:474` and `briefs.md:277`. The cleaner text still runs a repo-wide `git worktree prune`, so the R1-8 hazard survives through the cleaner's own text.
- **R2-4 LOW**, `assets/bin/deploy-guard.py:643`. `BMN_USER_APPROVED_DEPLOY=1 git push origin --delete dev` is allowed.
- **R2-5 LOW**, `assets/bin/deploy-guard.py:58`. `xargs --replace git merge --squash x` and `fish --command='…'` get past the guard, and the blind-spot list doesn't name them.
- **R2-6 LOW**, `assets/bin/deploy-guard.py:41` (owner run). The protected-branch lists in the guard and in the helper are kept by hand, and no test checks that they match.
- **Skipped:** the python-library-quality skills were not installed, so their lenses were applied from the rules the stories restate.

## Git cleanup
_Filled in by CLEANUP._

## Evidence
Run-level `review.md` (REVIEW① and REVIEW②), per-story `validation.md` (TEST①, FIX①, TEST②), coverage and smoke logs under `docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/<slug>/evidence/`.
