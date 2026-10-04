# Review — bmn-merged-branch-cleanup-and-no-squash-merges

## REVIEW1

**Scope:** `git diff 2aa149b...4d26d44` (whole run: 3 stories), every story.md, and the TEST① failure.
`/code-review` at high effort, then the guarding-destructive-operations,
keeping-git-repos-clean and auditing-python-security lenses (the python-library-quality skills
are not installed, so their rules were applied as the stories restate them). No TypeScript, no
migrations, no Supabase tables, and no design.md in the diff. I probed the cleanup helper and the
guard empirically, using throwaway repos in a scratchpad and the test helpers' `bash()`.

**Counts:** CRITICAL 0 · HIGH 1 · MEDIUM 5 · LOW 4

| Id | Sev | File:line | Owner | Finding and failure scenario |
| --- | --- | --- | --- | --- |
| R1-1 | HIGH | `assets/bin/merged-branch-cleanup.py:224` | merged-branch-cleanup-and-repo-merge-policy-scripts | `dirty_paths` decides "clean" with `git status --porcelain`, which has no `--ignored`, and `git worktree remove` deletes ignored files. Every worktree holding the branch is removed, including ones bmn didn't create, so Jonathan's gitignored `.env`, local DBs and similar files are destroyed. **Reproduced:** worktree on merged `wip/a` with an ignored `.env` → helper reports it deleted, and the `.env` is gone. |
| R1-2 | MEDIUM | `assets/bin/merged-branch-cleanup.py:180` | merged-branch-cleanup-and-repo-merge-policy-scripts | The "target is the branch itself" refusal compares names only, so a target that resolves to the branch tip (`wip/b~0`, its SHA, `wip/b@{0}`) passes and the ancestry proof is trivially true. **Reproduced:** unmerged `wip/b` with a unique commit, `--target wip/b~0` → `deleted: [local:wip/b]`. No test covers a non-name target. |
| R1-3 | MEDIUM | `assets/bin/merged-branch-cleanup.py:339` | merged-branch-cleanup-and-repo-merge-policy-scripts | `update-ref -d` skips git's "branch is being rebased/bisected" check. A worktree mid-rebase lists as `detached`, so it isn't a holder. **Reproduced:** worktree in an interactive rebase of `wip/a` → helper deletes `local:wip/a` and records nothing in `left`, so the rebase finishes onto a missing branch. |
| R1-4 | MEDIUM | `assets/tests/test_helper_script_quality.py:49` | merged-branch-cleanup-and-repo-merge-policy-scripts | `sys.stdlib_module_names` exists only on 3.10+, but the hook and scripts run under `python3` (3.9 on macOS). This is the TEST① failure: AttributeError on both scripts under `/usr/bin/python3`. |
| R1-5 | MEDIUM | `assets/bin/deploy-guard.py:178` | deploy-guard-blocks-squash-merges | `unwrap` doesn't strip wrappers that take options or values, and the shell `-c` must be a separate token. Probed, all exit 0: `timeout 60 git merge --squash x`, `sudo -u me git merge --squash x`, `sh -ec 'git merge --squash x'` (also `timeout 60 git push origin main`). deploy-guards.md's "Known blind spots" names only `bash -lc`, so the doc overstates coverage. |
| R1-6 | LOW | `assets/bin/deploy-guard.py:35` | run | Contracts disagree. The helper treats `dev`/`develop`/`staging` as protected, but the guard's `PROTECTED_BRANCHES` doesn't. **Probed:** `git push origin --delete dev` exits 0 in an active run, and the briefs now invite manual `git branch -D` / push-delete as fallbacks. |
| R1-7 | MEDIUM | `skills/dev-bother-me-nope/SKILL.md:473` (and `references/briefs.md:277`) | skill-text-merged-branch-cleanup-and-merge-commits-only | When `integration_pushed` is false but `origin/{integration}` exists, the cleaner skips the helper entirely. A run branch already merged into `origin/dev` then keeps its local branch and run worktree forever, against input.md ("ALL worktrees … and the branch are to be deleted from local"). Only the origin copy should be gated; a `--no-remote`-style mode or a local-only run is missing. |
| R1-8 | LOW | `assets/bin/merged-branch-cleanup.py:249` | merged-branch-cleanup-and-repo-merge-policy-scripts | Every non-dry run runs a repo-wide `git worktree prune`. It drops `.git/worktrees/*` admin data for any unlocked worktree whose directory is missing at that moment (unmounted volume, mid-move), which touches worktrees the run never named. |
| R1-9 | LOW | `assets/bin/merged-branch-cleanup.py:172` | merged-branch-cleanup-and-repo-merge-policy-scripts | The default-branch refusal reads only the local `refs/remotes/<remote>/HEAD`, which is absent in repos built with `git remote add` + push. In those repos a non-protected default branch (e.g. `trunk`) that is an ancestor of the target is deleted locally. |
| R1-10 | LOW | `skills/dev-bother-me-nope/SKILL.md:221` | skill-text-merged-branch-cleanup-and-merge-commits-only | The leftover-sweep command is bare `merged-branch-cleanup.py …`, while every other call site uses `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py`. The script isn't on PATH, so the sweep fails with "command not found". |

**Checked and found consistent:**
- **Helper calls match the scripts.** CLI flags, JSON keys (`deleted`/`left[{ref,why}]`, `repo_policy`, status enum) and exit codes (0 ran, 2 refused) are the same in SKILL.md, the briefs and both scripts.
- **The integrator and cleaner can't remove the worktree the helper runs from.** The integrator runs the helper with `--repo {run_worktree}` and `--target origin/{integration}`. The cleaner runs it from `{repo_path}` with `--repo {repo_path}`, and its mutating git runs via `-C <main checkout>`.
- **Guard blocks these:**
  - `git -c … merge --squash`, `git --no-pager/--git-dir … merge --squash`, `--squ`
  - `env`/`nice`/`xargs` prefixes, `$(…)`, `&&` chains
  - `gh pr -R o/r merge -s`, clustered `-sd`/`-ds`, `--squash=true`
  - `gh api` and MCP squash
  - the approval prefix (it does not unlock merge rules)
- **Guard allows the briefs' own commands:** `git pull --rebase=merges`, `git merge --no-ff -m '… squash …'`, `gh pr merge <n> --merge --delete-branch --repo o/r`, push `--delete` with a lease, and running the helper.
- **Standing checks:** no secrets, no `shell=True`, no SQL, and no swallowed errors beyond the documented best-effort `config --remove-section`.
