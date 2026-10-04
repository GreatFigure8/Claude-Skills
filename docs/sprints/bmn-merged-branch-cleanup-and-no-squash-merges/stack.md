# Stack — bmn-merged-branch-cleanup-and-no-squash-merges

- **Kind:** library (Markdown skills + one Python PreToolUse hook + shell). No UI, no Supabase, no Vercel, no CI, no LLM calls.
- **Target:** the dev-bother-me-nope plugin, source `Skills/dev-bother-me-nope/` ("bother me not" in the story). Plugin version `Skills/dev-bother-me-nope/.claude-plugin/plugin.json` is 1.5.0 → bump to **1.6.0** in the feature commits (no CHANGELOG; marketplace.json has no version).
- **dev_push_deploys:** false — no `.github/workflows`, no vercel.json, no supabase/.
- **Default branch:** main. `origin/dev` exists (2aa149b = dev_base).
- **GitHub repo (GreatFigure8/Claude-Skills), read-only:** delete_branch_on_merge=false, allow_squash_merge=true, allow_merge_commit=true, allow_rebase_merge=true.

## Routing
- Build skills: `python-library-quality:keeping-git-repos-clean`, `python-library-quality:guarding-destructive-operations`.
- Review lenses: guarding-destructive-operations, keeping-git-repos-clean, auditing-python-security.
- Test surfaces: pytest on `Skills/dev-bother-me-nope/assets/tests` (deploy-guard.py). No browser/api/mcp surface.

## Gates
- test: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` (106 passing at dev_base; bare python3 has no pytest)
- lint: `shellcheck` on any changed `.sh`; `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` on changed Python
- types: none

## Touchpoints (from the scout)
- SKILL.md: pipeline diagram (15-16), *Branches and worktrees* + *Cleanup is a step* (74-97), *Merging never builds* (99-130), leftover sweep (186-187), INTAKE (224-245), "one reviewable PR" (279), BUILD integrator (299-306), MERGE→dev① (308-314), FIX①/MERGE②/report merge (361-387), CLEANUP 10b (398-420).
- references/briefs.md: integrator (206-226), merger (229-246), cleaner (249-279), splitter "one reviewable PR" (113).
- references/move-computers.md (29-32, 65-69), references/report-template.md (6, 67-70), agents/bmn-worker.md (17-19).
- assets/tests/test_deploy_guard.py (allow-case `git push origin --delete wip/demo/story-a`, line 107); deploy-guard.py has no `gh` handling today.
- No "squash" anywhere in Skills/dev-bother-me-nope/. bmn never opens a PR today; it merges with `--no-ff`.

## Assumptions (orchestrator, INTAKE)
1. Scope is dev-bother-me-nope only. dev-epic-workflow's `epic-loop.sh` (`gh pr merge --merge`, no `--delete-branch`) and dev-story-sprint are out of scope and named in the report.
2. "Merged to dev from a working branch" = every branch bmn merges into `dev` (the run branch). After its final merge to `dev`, **every** worktree that has that branch checked out (not only the run worktree bmn recorded) is removed, the local branch is deleted, and the origin copy is deleted once it is an ancestor of `origin/dev`. Same for every temp branch merged into the run branch. The run branch is not deleted after MERGE①, because FIX① still branches from it; it goes at CLEANUP, after the last merge.
3. Safety stays: no `--force` worktree removal. A worktree with uncommitted changes is left and recorded (it may hold Jonathan's work), as are branches not proven merged with `merge-base --is-ancestor`.
4. "Each PR should delete the source branch from the remote": any PR bmn opens or merges uses `gh pr merge --merge --delete-branch`. INTAKE also sets the GitHub repo's `delete_branch_on_merge=true` so PRs merged by anyone (UI included) delete their head branch — Jonathan's explicit standing instruction, 2026-10-03. The old→new values are recorded in bmn.json and the report.
5. "NO MORE SQUASH MERGING": bmn never squashes (`git merge --squash`, `gh pr merge --squash`/`-s`, `merge_method=squash`); its merges stay `--no-ff` merge commits. The plugin's PreToolUse guard blocks squash merges while a run is active. INTAKE sets the repo's `allow_squash_merge=false` (with 4, recorded). Rebase merges are not mentioned in the story and are left as they are.
6. Repo-setting changes need admin rights on the repo; without them (or if `gh` isn't authenticated) INTAKE records it and continues — not a blocker.
