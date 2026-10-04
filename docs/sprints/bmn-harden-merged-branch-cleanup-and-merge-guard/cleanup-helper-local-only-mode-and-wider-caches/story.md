# Cleanup helper: local-only mode, wider cache list, no repo-wide prune (plugin 1.6.1)

**As** Jonathan, **I want** every run-branch cleanup (including the case where this run never
pushed the origin copy) to go through `merged-branch-cleanup.py`, and that helper to tell
regenerable tool output from real files, **so that** cleanup never deletes an ignored `.env`,
never skips the rebase/bisect check, never prunes other branches' worktrees, and doesn't leave
every Next.js/Playwright worktree behind forever.

## Context

Closes REVIEW② items R2-1, R2-2 and R2-3 of `bmn-merged-branch-cleanup-and-no-squash-merges`
(full text, file:line and reproduced scenarios: the REVIEW2 section of
`docs/sprints/bmn-merged-branch-cleanup-and-no-squash-merges/review.md`), and bumps the plugin.

- **R2-1 (HIGH).** CLEANUP step 2 in `skills/dev-bother-me-nope/SKILL.md` (~line 475-487) and
  step 2 of the cleaner brief in `references/briefs.md` (~line 278-290) tell the cleaner to run
  the local half of the cleanup by hand when `integration_pushed` is false and
  `origin/<integration>` exists: `git worktree remove <path>` without `--force`, then
  `update-ref -d`. Git does not refuse a worktree whose only extra files are ignored — it
  deletes them (`.env` gone, reproduced), and the hand path skips the helper's rebase/bisect
  check (`busy_with`). Root fix (stack.md assumption 3): give the helper a local-only mode that
  never touches the remote copy, and route that case through it.
- **R2-2 (MEDIUM).** `assets/bin/merged-branch-cleanup.py` `CACHE_DIRS` (line ~39) only knows
  seven directory names, and `is_cache` only matches directory components, so ignored
  regenerable outputs — `next-env.d.ts`, `*.tsbuildinfo`, `test-results/`,
  `playwright-report/`, `.coverage`, `.DS_Store`, `*.egg-info/` — make every worktree "dirty"
  and it is kept forever (the leftover sweep reruns the same check and keeps it again).
- **R2-3 (LOW).** The same CLEANUP step 2 text (SKILL.md ~474, briefs.md ~277) still ends with
  a repo-wide `git worktree prune`, which the helper deliberately dropped (R1-8): it would
  discard another branch's worktree admin data when that worktree sits on an unmounted volume.
- **Plugin bump.** `.claude-plugin/plugin.json` 1.6.0 → **1.6.1**.

Paths are relative to `Skills/dev-bother-me-nope/` unless they start with `docs/`.

Build skills: `python-library-quality:keeping-git-repos-clean` and
`python-library-quality:guarding-destructive-operations` are named for this run but are not
installed on this machine; their rules that apply here are restated in the criteria below
(prove before deleting, never `--force`, ignored files are data, keep what you can't prove,
report every kept item with a reason, argument-list subprocesses, stdlib only).

## Acceptance criteria

### R2-1 — local-only mode in the helper

1. [integration] `merged-branch-cleanup.py` accepts a new flag `--local-only`. With it, the
   helper never deletes, pushes to or leases the remote copy: no `git push` of any kind is run
   (asserted through the `git_shim` call log), and the bare origin's
   `refs/heads/<branch>` SHA is unchanged afterwards — also when that origin copy is merged
   into `--target`.
2. [integration] With `--local-only`, when `<remote>/<branch>` exists the JSON `left` contains
   exactly one entry `{"ref": "<remote>:<branch>", "why": "origin copy kept: --local-only"}`
   (whether or not that copy is merged), and `deleted` never contains a `<remote>:` entry.
   When no remote copy exists, `left` has no `<remote>:` entry.
3. [integration] **Reproduces R2-1.** A linked worktree on the merged run branch holding an
   ignored, uncommitted `.env` (gitignored in the repo), run with `--local-only`: exit 0, the
   worktree directory and its `.env` (same bytes) still exist, `left` has
   `worktree:<path>` with a reason naming the ignored file, and the local branch is kept with
   `local:<branch>` in `left`. Fails today because the documented hand path removes it.
4. [integration] With `--local-only`, a clean linked worktree on a merged branch is removed
   (no `--force`), the local branch is deleted compare-and-swap on the checked SHA, and
   `deleted` lists `worktree:<path>` and `local:<branch>` — the same local behaviour as a run
   without the flag.
5. [integration] With `--local-only`, a branch with a rebase or bisect in progress in one of
   its worktrees keeps its local branch with the same reason the default mode gives (the
   `busy_with` check runs in this mode too), and an unmerged local branch is kept with
   "not merged into <target>" — the existing safety checks are not bypassed.
6. [integration] `--local-only --dry-run` prints a plan with no `<remote>:` entry in
   `deleted` and the `left` entry from criterion 2, runs no fetch and changes nothing (every
   ref and worktree identical before and after).
7. [unit] The module docstring's Contract line lists `[--local-only]` and says what it
   does (the remote copy is never touched and is reported in `left`); `--help` text names it.
   Every refusal (protected name, bad target, default branch) still applies with the flag
   (one parametrized test re-running the existing refusal cases with `--local-only`).
8. [unit] SKILL.md CLEANUP step 2 and the cleaner brief step 2 route the
   `integration_pushed: false` case through the helper:
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <main checkout> --branch <integration> --target origin/dev --local-only`
   (brief: `{repo_path}` / `{integration}` placeholders). The hand-run sequence is gone from
   both: neither step contains `worktree remove <path>`, `update-ref -d`,
   `merge-base --is-ancestor "$sha"`, `sha=$(` or "the helper has no flag". Both still say the
   origin copy stays and goes into `left` as `origin:<integration>`, "origin copy not pushed
   by this run" (the cleaner rewrites the helper's `--local-only` reason to that text), and
   that the local branch and every worktree on it are still deleted. The existing
   `test_unpushed_run_branch_names_the_local_only_steps` is rewritten to assert this instead
   of the old commands; `test_unpushed_run_branch_is_still_deleted_locally` keeps passing.
9. [unit] The *Leftover sweep* paragraph in SKILL.md (~line 221-224) passes `--local-only`
   when the run's `integration_pushed` is false, so a later sweep never deletes an origin copy
   the run didn't push. Every helper invocation still uses the
   `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/` form (existing
   `test_every_helper_invocation_uses_the_plugin_root_form` passes).

### R2-2 — regenerable outputs count as cache

10. [unit] **Reproduces R2-2.** `is_cache` returns True for these ignored status entries:
    `!! next-env.d.ts`, `!! web/next-env.d.ts`, `!! tsconfig.tsbuildinfo`,
    `!! app/tsconfig.app.tsbuildinfo`, `!! test-results/`, `!! e2e/test-results/x.png`,
    `!! playwright-report/`, `!! .coverage`, `!! .coverage.host.123.456`, `!! .DS_Store`,
    `!! docs/.DS_Store`, `!! src/pkg.egg-info/`, `!! pkg.egg-info/PKG-INFO`, `!! htmlcov/`,
    `!! .tox/`, `!! .nox/`, `!! .turbo/`, `!! .parcel-cache/`, `!! .eslintcache`. Each fails
    today.
11. [unit] `is_cache` still returns False for every entry already in `CACHE_VERDICTS`
    (`.env`, `config/.env`, a *file* named `.venv`, `build/`, untracked `?? node_modules/`,
    a modified tracked file) and for new near-misses: `!! .env.local`, `!! secrets.pem`,
    `!! next-env.d.ts.bak`, `!! notes.tsbuildinfo.txt`, `?? next-env.d.ts`,
    `?? .DS_Store`, ` M test-results/keep.txt`, `!! dist/`, `!! coverage.json`. Matching is
    exact and case-sensitive (`fnmatch.fnmatchcase` or equality), never substring.
12. [unit] Cache rules are named immutable constants: directory names/patterns (matched
    against any directory component, as `CACHE_DIRS` is today) and file names/patterns
    (matched against the entry's last component only). No mutable module-level state
    (existing `test_no_global_statements_or_mutable_module_constants` passes).
13. [integration] A linked worktree on a merged branch whose only extra files are ignored
    `next-env.d.ts`, `tsconfig.tsbuildinfo`, `test-results/`, `playwright-report/`,
    `.coverage` and `.DS_Store` is removed and its branch deleted; the same worktree plus an
    ignored `.env` is kept with the `.env` intact.

### R2-3 — no repo-wide prune in the cleaner text

14. [unit] **Reproduces R2-3.** Neither SKILL.md's `10b · CLEANUP` section nor the cleaner
    brief contains `git worktree prune` (or `worktree prune`) except inside a sentence that
    says never to run it; the existing helper docstring's "never … prunes other worktrees"
    stays. A grep test over both sections fails today on "then `git worktree prune`".

### Plugin

15. [unit] `.claude-plugin/plugin.json` `version` is `1.6.1`; the existing version test in
    `assets/tests/test_skill_text_rules.py` is updated to 1.6.1 (and its module docstring's
    "1.6.0 rules" wording left or generalized — no other assertion weakened).
16. [unit] Gates pass: `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
    on the default Python and under `--python /usr/bin/python3` (3.9.6 — no 3.10+ syntax or
    stdlib), and
    `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`. The quality
    limits in `assets/tests/test_helper_script_quality.py` are not relaxed: the helper stays
    under 400 lines and every function under 50 lines (it is at 397 today, so trim the
    docstring/code or move the cache rules into a stdlib-only sibling module in
    `assets/bin/` that is added to that test's `SCRIPTS` list).

## Out of scope

- `assets/bin/deploy-guard.py`, `assets/tests/test_deploy_guard.py`,
  `assets/tests/test_merge_guard.py`, `references/deploy-guards.md` and the new
  protected-branch parity test — owned by story
  `deploy-guard-protected-deletes-and-wrapper-gaps`.
- The helper's `PROTECTED` set: unchanged in this story (the parity test in the other story
  reads it as-is).
- Running cleanup on this repo, the repo merge policy and the plugin update/reinstall —
  operations the orchestrator does (stack.md assumption 2).
- Treating `build/` or `dist/` as cache (kept blocking, as the previous run decided).

## Files owned

`assets/bin/merged-branch-cleanup.py` (and any new sibling cache-rules module),
`assets/tests/test_merged_branch_cleanup.py`, `assets/tests/test_skill_text_rules.py`,
`assets/tests/test_helper_script_quality.py` (only to add a new module to `SCRIPTS`),
`skills/dev-bother-me-nope/SKILL.md`, `skills/dev-bother-me-nope/references/briefs.md`,
`.claude-plugin/plugin.json`.

## Deps

None. Builds in parallel with `deploy-guard-protected-deletes-and-wrapper-gaps` (disjoint
files).

## Assumptions

1. The flag is named `--local-only` (it says what it keeps local; `--keep-remote` reads as a
   remote name). The helper reports the kept copy itself rather than staying silent, so the
   report's *Git cleanup* section can never miss it; the cleaner rewrites the reason text to
   "origin copy not pushed by this run" because that is the run-level fact.
2. `--local-only` still runs `git fetch --prune` (unless `--no-fetch`): ancestry is proved
   against `origin/dev`, which must be current. Fetching changes no branch.
3. The new cache entries are limited to outputs their tools regenerate on the next run and
   that never hold hand-written work: Next.js `next-env.d.ts`, TypeScript `*.tsbuildinfo`,
   Playwright `test-results/` and `playwright-report/`, coverage.py `.coverage` /
   `.coverage.*` and `htmlcov/`, macOS `.DS_Store`, setuptools `*.egg-info/`, tox/nox envs,
   Turborepo `.turbo/`, Parcel `.parcel-cache/`, ESLint `.eslintcache`. `build/`, `dist/` and
   `coverage.json` stay blocking.
4. Only *ignored* entries (`!! `) can be cache; an untracked or modified file with a cache
   name still blocks, as today.
5. The Leftover sweep change (criterion 9) is part of R2-1: it is the same CLEANUP run step
   rerun later, and without it a sweep would delete the origin copy the run chose to keep.
