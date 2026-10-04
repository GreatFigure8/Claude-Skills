# Plan — cleanup-helper-local-only-mode-and-wider-caches

Story: `story.md` (closes R2-1, R2-2, R2-3; plugin 1.6.0 → 1.6.1). Paths are relative to
`Skills/dev-bother-me-nope/` unless they start with `docs/`.

## 1. Approach

- **R2-1, root fix.** Add `--local-only` to `merged-branch-cleanup.py` and route the
  `integration_pushed: false` case (CLEANUP step 2, cleaner brief step 2, Leftover sweep)
  through it, so the unpushed case gets every check the helper already makes (ancestry,
  `busy_with`, no `--force`, ignored files kept). The hand-run sequence is deleted, not patched.
- **One enforcement point.** `plan_cleanup(s, local_only=False)` builds the plan as today, then
  for `--local-only` returns `plan._replace(delete_remote=False, left=<every "<remote>:<branch>"
  entry dropped> + one kept entry)`. Pure and immutable; `execute` and `planned_deletions` need
  no change because they only act on `plan.delete_remote`. No `push`, delete or lease is
  reachable in that mode, whatever `plan_merged`/`plan_unmerged` decided.
- **R2-2.** Cache rules become two named immutable tuples matched with `fnmatch.fnmatchcase`
  (exact, case-sensitive): `CACHE_DIRS` against every directory component (as today) and new
  `CACHE_FILES` against the last component. Only `!! ` entries can be cache.
- **R2-3.** Delete "then `git worktree prune`" from both texts.
- Guidance applied (python-library-quality skills are not installed; the rules restated in the
  story are followed): prove before deleting, never `--force`, ignored files are data, keep what
  can't be proved and report it with a reason, argument-list subprocesses, stdlib only, 3.9-safe.
- **Line budget (the binding constraint).** The helper is at 397 of < 400 lines. A draft of
  every change below was built in a scratch copy and measured at **398 lines**; ruff clean;
  `test_merged_branch_cleanup.py` + `test_helper_script_quality.py` 85 passed on the default
  Python and on `/usr/bin/python3` (3.9.6). The sibling-module route was rejected (see
  Assumptions 1).

## 2. Files

| File | Change |
| --- | --- |
| `assets/bin/merged-branch-cleanup.py` | `--local-only`; `CACHE_FILES`, wider `CACHE_DIRS`, `fnmatch` `is_cache`; docstring Contract/Safety; trims to stay < 400 lines |
| `assets/tests/test_merged_branch_cleanup.py` | new local-only, cache and refusal tests (section 3) |
| `assets/tests/test_skill_text_rules.py` | version 1.6.1; rewrite `test_unpushed_run_branch_names_the_local_only_steps`; new sweep and no-prune tests; module docstring "1.6.0 rules" → "1.6.x rules" |
| `skills/dev-bother-me-nope/SKILL.md` | `10b · CLEANUP` step 2 and the **Leftover sweep** paragraph |
| `skills/dev-bother-me-nope/references/briefs.md` | cleaner brief step 2 |
| `.claude-plugin/plugin.json` | `"version": "1.6.1"` |

Not touched: `assets/tests/test_helper_script_quality.py` (no new module, so `SCRIPTS` is
unchanged), `deploy-guard.py`, `deploy-guards.md`, `PROTECTED` (other story).

### Helper edits (draft-verified; 397 → 398 lines)

Additions:
- `import fnmatch`.
- Constants (replace the 3-line `CACHE_DIRS` block; tuples are immutable):
  ```python
  # Ignored outputs tools regenerate (exact fnmatchcase): any directory of the path, or its file name.
  CACHE_DIRS = ("__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache", ".venv", "node_modules",
                ".next", ".tox", ".nox", ".turbo", ".parcel-cache", "htmlcov", "test-results",
                "playwright-report", "*.egg-info")
  CACHE_FILES = ("next-env.d.ts", "*.tsbuildinfo", ".coverage", ".coverage.*", ".DS_Store", ".eslintcache")
  ```
- `Options` fields `"repo branch target remote fetch dry_run local_only target_ref"`, drop
  `defaults=(None,)` and pass `None` explicitly from `parse_args` (keeps it one line).
- `parser.add_argument("--local-only", action="store_true", help="never touch the remote copy")`;
  `parse_args` returns `Options(..., args.dry_run, args.local_only, None)`.
- `is_cache`:
  ```python
  def is_cache(entry):
      """An ignored entry under a CACHE_DIRS directory or named like CACHE_FILES; exact, case-sensitive."""
      *dirs, name = entry[3:].split("/")
      checks = [(part, CACHE_DIRS) for part in dirs] + [(name, CACHE_FILES)]
      return entry.startswith("!! ") and any(fnmatch.fnmatchcase(text, pattern)
                                            for text, patterns in checks for pattern in patterns)
  ```
  (`!! .venv/` → dirs `[".venv"]`, name `""`; a *file* `.venv` → name only, not cache.)
- `plan_cleanup`:
  ```python
  def plan_cleanup(s, local_only=False):
      plan = plan_unmerged(s) if s.local.sha is not None and not s.local.merged else plan_merged(s)
      if not local_only:
          return plan
      # --local-only: the remote copy is never deleted; one that exists is reported once, in left
      ref = f"{s.remote}:{s.branch}"
      kept = (Left(ref, f"{s.remote} copy kept: --local-only"),) if s.remote_copy.sha else ()
      return plan._replace(delete_remote=False, left=tuple(i for i in plan.left if i.ref != ref) + kept)
  ```
  `main` calls `plan_cleanup(found, opts.local_only)`. Survey is unchanged (the existing unit
  test that builds a `Survey` by keyword keeps working; `plan_cleanup(survey)` still defaults).
- Docstring Contract: usage line gains `[--local-only]`; add "`--local-only` never touches the
  remote copy (no push, delete or lease); one that exists is kept and reported in "left"."
  Safety: "dirty: any ignored file `worktree remove` would delete except
  CACHE_DIRS/CACHE_FILES"; keep "Never forces, unlocks or prunes other worktrees".

Trims (behaviour-identical; all used in the draft):
1. Fold `git_result` into `run_git` (each branch sets `code, out, err`; one `return GitResult(...)`), and
   inline `env={**os.environ, "GIT_TERMINAL_PROMPT": "0"}` into the `subprocess.run` call.
2. `failure_line`: `telling = [...]`; `return (telling + lines + ["git failed with no output"])[0]`.
3. `blocker`: last two statements → one conditional return.
4. `plan_local`: inline `in_main` into the `why` expression.
5. `survey`: closing `)` on the `holders=…, busy=…` line.
6. Purpose paragraph 3 → 2 lines; `resolve_target` docstring → 1 line.
Lines stay ≤ 105 chars (file max is 103 today; ruff's default set has no E501).

## 3. Test plan (written first; each must fail before the code change)

`assets/tests/test_merged_branch_cleanup.py` (`git_world` + `run_cleanup` shim; `LOCAL_ONLY_WHY =
"origin copy kept: --local-only"`):

| AC | Test | Type |
| --- | --- | --- |
| 1, 2 | `test_local_only_never_pushes_and_keeps_a_merged_origin_copy` — merged branch, clean worktree; `"push" not in run.subcommands`; origin `refs/heads/wip/r/a` SHA unchanged; `left_map == {origin:wip/r/a: LOCAL_ONLY_WHY}`; no `origin:` in `deleted` | integration |
| 2 | `test_local_only_reports_an_unmerged_origin_copy_once` — `move_origin_ahead`; exactly one `origin:` entry, why `LOCAL_ONLY_WHY`; origin SHA == extra | integration |
| 2 | `test_local_only_without_an_origin_copy_leaves_no_remote_entry` — `add_branch` then `git push -q origin --delete wip/r/a`; `deleted == ["local:wip/r/a"]`, no `origin:` in `left` | integration |
| 3 | `test_local_only_keeps_worktree_holding_an_ignored_env` (**reproduces R2-1**) — `ignore(world, ".env")`, worktree with `.env` bytes; exit 0; dir and `.env` bytes intact; `worktree:<path>` why names `.env`/ignored; `local:wip/r/a` in `left` | integration |
| 4 | `test_local_only_removes_clean_worktree_and_deletes_branch_compare_and_swap` — `deleted` == `worktree:<p>`, `local:wip/r/a`; the `update-ref -d refs/heads/wip/r/a <tip>` call carries the checked SHA; no `--force` in any `worktree` call | integration |
| 5 | `test_local_only_keeps_branch_being_rebased_or_bisected` (parametrized `rebase`/`bisect`, as the existing test) — `local:` why has "rebase or bisect"; no `update-ref` | integration |
| 5 | `test_local_only_keeps_an_unmerged_local_branch` — `add_branch(merged=False)`; `local:` why "not merged into origin/feat/r"; snapshot unchanged | integration |
| 6 | `test_local_only_dry_run_plans_no_remote_delete_and_changes_nothing` — two worktrees; no `origin:` in `deleted`; `left` == `[{ref: origin:wip/r/a, why: LOCAL_ONLY_WHY}]`; `"fetch"` not run; snapshot identical; only `worktree list` | integration |
| 7 | `test_docstring_contract_and_help_name_local_only` — `load_script` docstring Contract section has `[--local-only]` and the "remote copy … left" sentence; `run_cleanup("--help")` exit 0, `--local-only` in stdout | unit |
| 7 | `test_refusals_still_apply_with_local_only` — parametrized: `main`, `DEV` (protected), `trunk` (default branch), `feat/r` vs `origin/feat/r` (own target), `origin/does-not-exist` and `wip/r/a~0` targets, `-rf`; each `assert_refused` + snapshot unchanged | unit |
| 10, 11 | `test_only_ignored_regenerable_outputs_count_as_cache` (renamed from `…inside_cache_directories…`) — `CACHE_VERDICTS` gains the 19 True entries of AC10 and the 9 False near-misses of AC11 | unit (param) |
| 12 | `test_cache_rules_are_named_immutable_string_tuples` — `CACHE_DIRS`, `CACHE_FILES` are tuples/frozensets of `str`; existing `test_no_global_statements_or_mutable_module_constants` passes | unit |
| 13 | `test_worktree_whose_only_ignored_files_are_regenerable_outputs_is_removed` — ignore + create `next-env.d.ts`, `tsconfig.tsbuildinfo`, `test-results/a.png`, `playwright-report/index.html`, `.coverage`, `.DS_Store`; worktree removed, `local:` + `origin:` deleted | integration |
| 13 | `test_regenerable_outputs_plus_ignored_env_keep_the_worktree` — same plus `.env`; worktree kept, `.env` intact | integration |

`assets/tests/test_skill_text_rules.py`:

| AC | Test | Type |
| --- | --- | --- |
| 8 | `test_unpushed_run_branch_names_the_local_only_steps` (rewritten) — step has the `--local-only` command (SKILL: `--repo <main checkout> --branch <integration> --target origin/dev --local-only`; brief: `{repo_path}`/`{integration}`); lacks `worktree remove <path>`, `update-ref -d`, `merge-base --is-ancestor "$sha"`, `sha=$(`, `the helper has no flag`, `git branch -D`; `test_unpushed_run_branch_is_still_deleted_locally` unchanged and passing | unit |
| 9 | `test_leftover_sweep_passes_local_only_when_the_run_did_not_push` — sweep paragraph has `--local-only`, `integration_pushed`, `--target origin/dev` | unit |
| 14 | `test_cleanup_text_never_runs_a_repo_wide_worktree_prune` (**reproduces R2-3**) — parametrized SKILL `10b · CLEANUP` / cleaner brief: every `_sentences` item containing `worktree prune` matches `\bnever\b` | unit |
| 15 | `test_plugin_json_is_version_1_6_1` (renamed from `…1_6_0`) | unit |

No browser criteria. AC16 = the gates in section 6.

### Text for SKILL.md / briefs (step 2)

Step 2 runs the helper as today when `integration_pushed` is true, and with `--local-only`
appended when it is false. Replace the "Then `git worktree prune`" clause and the whole
hand-run paragraph with: only the origin copy is gated on `integration_pushed`; with
`--local-only` the helper keeps `origin:<integration>` and lists it in `left`, which the cleaner
records as "origin copy not pushed by this run" (replacing the helper's reason); the local
branch and every worktree on it are still deleted with all the helper's checks. Do not mention
`worktree prune` at all, or only in a sentence with "never". Leftover sweep: append "adding
`--local-only` when that run's `integration_pushed` is false". Every call keeps the
`python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/` form.

## 4. Data

None: no models, migrations, Supabase or RLS.

## 5. Config / deploy_pending

No env vars. `deploy_pending: []`. The plugin bump to 1.6.1 needs a plugin update/reinstall,
which the orchestrator does after the run (stack.md assumption 2), not a deploy.

## 6. Risks and gates

- **Line budget**: 398 of < 400 in the draft; any extra line needs another trim from section 2.
  `test_functions_under_50_lines` is not at risk (largest touched function ~20 lines).
- **3.9.6**: no `match`, `X | Y`, `removeprefix` is 3.9 (already used); the draft passed the
  cache and plan checks on `/usr/bin/python3`.
- **Parallel story** edits `deploy-guard.py` and its tests only; no shared file.
- **Behaviour drift from trims**: `failure_line`/`run_git` keep the same outputs; the existing
  suite covers both (timeouts, rejected push reason via `stale info`).

Gates:
- `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
- `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope/assets`

## Assumptions (planner)

1. No sibling cache module: the helper importing one would fail
   `test_script_imports_stdlib_only` (its imports must be stdlib) and `load_script` loads the
   file without `assets/bin` on `sys.path`, so that route needs the quality test relaxed, which
   the story forbids. Trimming fits (draft: 398 lines).
2. The kept-copy reason is `f"{remote} copy kept: --local-only"`; with the default remote it is
   exactly the story's `"origin copy kept: --local-only"`.
3. `--local-only` is applied after planning (drop every `<remote>:` entry, add one), so the
   unmerged and fetch-failed paths also give exactly one remote entry with the local-only reason.
4. The cleaner passes `--local-only` whenever `integration_pushed` is false, whether or not
   `origin/<integration>` exists (with no remote copy the flag changes nothing).
5. AC3 ignores `.env` through the shared `info/exclude` (the existing `ignore()` helper) rather
   than a committed `.gitignore`; git treats both as ignored, which is what R2-1 is about.
6. `deploy-guards.md` still lists `git worktree prune` as a guarded command; it is out of scope
   here (owned by the other story) and is not cleaner text.
