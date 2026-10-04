# Stack — bmn-harden-merged-branch-cleanup-and-merge-guard

Same repo and stack as `bmn-merged-branch-cleanup-and-no-squash-merges` (finished 2026-10-04): see
`docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/stack.md`. Library (skill Markdown + Python hook +
stdlib helpers), no UI, no Supabase, no Vercel, no CI. Target: `Skills/dev-bother-me-nope/` (plugin 1.6.0 → **1.6.1**).

## Scope — the six REVIEW② items left open by the previous run
Full text (file:line, failure scenario): REVIEW2 section of
`docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/review.md`.
- **R2-1 HIGH**: the local-only cleanup for an unpushed run branch (SKILL.md ~482, briefs.md ~285) hand-runs `git worktree remove`, which deletes ignored files (.env) and skips the rebase/bisect check.
- **R2-2 MEDIUM**: `assets/bin/merged-branch-cleanup.py` CACHE_DIRS too narrow (next-env.d.ts, *.tsbuildinfo, test-results/, playwright-report/, .coverage, .DS_Store keep worktrees forever).
- **R2-3 LOW**: cleaner text still runs a repo-wide `git worktree prune` (SKILL.md ~474, briefs.md ~277).
- **R2-4 LOW**: `BMN_USER_APPROVED_DEPLOY=1 git push origin --delete dev` passes the guard.
- **R2-5 LOW**: `xargs --replace git merge --squash x` and `fish --command='…'` pass the guard.
- **R2-6 LOW**: protected-branch lists in deploy-guard.py and merged-branch-cleanup.py are kept by hand with no parity check.

## Routing and gates
- Build skills: python-library-quality:keeping-git-repos-clean, python-library-quality:guarding-destructive-operations (not installed on this machine; workers follow the rules the stories restate).
- Review lenses: guarding-destructive-operations, keeping-git-repos-clean, auditing-python-security.
- Gates: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`; the same under `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest …` (the hook runs on 3.9.6); `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`.
- Test surface: unit/integration only.

## Assumptions (orchestrator, INTAKE)
1. The stack is unchanged since the previous run hours ago, so its classification is reused instead of a new stack-scout.
2. The other three asks (merge policy on GreatFigure8/Claude-Skills, plugin update, repo-wide merged-branch cleanup) are operations, not code; the orchestrator does them outside this run. The merge policy was applied at intake: allow_squash_merge true→false, delete_branch_on_merge false→true.
3. R2-1 is fixed by routing the unpushed-branch case through the helper (a local-only mode), not by more hand-run text, so it inherits every safety check.
4. R2-4: deleting a protected branch on origin is never a deploy step, so `BMN_USER_APPROVED_DEPLOY=1` does not lift that block.
5. Briefs come from the 1.6.0 plugin cache; `${CLAUDE_PLUGIN_ROOT}` = `/Users/jonathanstevenson/.claude/plugins/cache/claude-skills/dev-bother-me-nope/1.6.0`.
6. SPLIT through REVIEW② runs as one workflow; the orchestrator writes bmn.json at intake and after the workflow returns. A crash mid-workflow resumes with the workflow's own resume, not the bmn phase.
