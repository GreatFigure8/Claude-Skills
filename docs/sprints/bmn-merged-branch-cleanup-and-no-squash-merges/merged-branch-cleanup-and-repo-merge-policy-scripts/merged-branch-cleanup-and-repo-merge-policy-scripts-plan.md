# Plan — merged-branch-cleanup-and-repo-merge-policy-scripts

Story: `story.md` (same folder). Plugin: `Skills/dev-bother-me-nope/`. Kind: library (python3 stdlib
scripts + pytest). No UI, no Supabase, no Vercel.

## 1. Approach

Two standalone python3-stdlib scripts in `assets/bin/`, same shape as `deploy-guard.py`: a module
docstring for the contract, small pure functions, argv-list `subprocess.run`, JSON on stdout. Each one
works in three steps: **survey** (read-only git/gh) → **plan** (a pure function returns frozen tuples of
actions and `left` entries) → **execute**. `--dry-run` prints the plan and stops before execute. The
`guarding-destructive-operations` rules the story restates are applied as follows (the skill itself was not installed, see Assumptions):
refuse before touching anything (protected names, default branch, target's own branch); prove ancestry
before every delete; no `--force` on worktree or branch calls; make each delete a compare-and-swap on the
SHA that was checked (`update-ref -d <ref> <sha>`, `push --force-with-lease=<ref>:<sha> --delete`), so a
branch that moves after the check is kept; dirty, locked and main-checkout worktrees are kept and listed
in `left`. The `keeping-git-repos-clean` rules applied: prune stale worktree entries, remove *every* worktree that
has the branch, and drop the branch's config section. Tests drive real throwaway repos (a bare `origin`
and a clone in `tmp_path`) through a logging `git` shim and a fixture-driven fake `gh`. They never use this repo or the network.
Reuse check: PyPI has `git-delete-merged-branches` 7.6.1, `git-sweep` 0.1.1, `GitPython` 3.2.0 and
`PyGithub` 2.10.0. All are rejected: the scripts must be stdlib-only (AC 21, deploy-guard precedent), and
none of them handles "every linked worktree holding the branch" or a CAS delete. Using `gh` keeps the user's
existing auth.

## 2. Files

| File | Purpose |
| --- | --- |
| `Skills/dev-bother-me-nope/assets/bin/merged-branch-cleanup.py` (new, `chmod +x`) | Deletes one merged branch with all its worktrees, plus its local and `<remote>` copies. Fixed contract in story.md. |
| `Skills/dev-bother-me-nope/assets/bin/repo-merge-policy.py` (new, `chmod +x`) | Sets the GitHub repo to `allow_squash_merge=false` and `delete_branch_on_merge=true` (and `allow_merge_commit=true` if it was off), then reads the values back. Fixed contract. |
| `Skills/dev-bother-me-nope/assets/tests/conftest.py` (new) | Shared fixtures: isolated git env, `GitWorld` builder (bare origin + clone + linked worktrees), `git` shim with argv log, fake `gh` with fixture/state/log, `load_script()` (importlib for hyphenated names), `unit`/`integration` markers. |
| `Skills/dev-bother-me-nope/assets/tests/test_merged_branch_cleanup.py` (new) | AC 1-12. |
| `Skills/dev-bother-me-nope/assets/tests/test_repo_merge_policy.py` (new) | AC 13-20. |
| `Skills/dev-bother-me-nope/assets/tests/test_helper_script_quality.py` (new) | AC 21 static checks (parametrized over both scripts). |

`deploy-guard.py`, `test_deploy_guard.py`, SKILL.md, briefs.md, plugin.json and the other references are not touched. Other stories own them.

### merged-branch-cleanup.py — design

- `parse_args`: an argparse subclass whose `error()` prints `{"error": msg}` to stdout and exits 2.
- `run_git(cwd, *args, timeout)` → frozen `GitResult(code, out, err)`. It runs `["git", "-C", cwd, *args]` with `env={**os.environ, "GIT_TERMINAL_PROMPT": "0"}`
  and a timeout (`GIT_READ_TIMEOUT_S=30`, `GIT_NETWORK_TIMEOUT_S=120`). A timeout or OSError becomes a non-zero result and never raises.
  `git` is resolved through `PATH` on each call so the shim is used.
- **Refusals** (exit 2, nothing but read-only git). Static checks first: empty name, a leading `-`, a leading
  `refs/`, or a casefolded match with `PROTECTED = frozenset({main, master, dev, develop, prod,
  production, release, staging})`. Then git checks: `rev-parse --is-inside-work-tree` must be `true`;
  `check-ref-format --branch <b>` must succeed and echo `<b>` back unchanged (otherwise `@{-1}` expands to
  another branch; this was verified with git 2.54); `--remote` must not start with `-` and must be listed by `git remote`;
  `symbolic-ref --quiet --short refs/remotes/<remote>/HEAD` with the remote prefix stripped must not equal `<b>`;
  `--target` must not start with `-` and must pass `rev-parse --verify --quiet --end-of-options <target>^{commit}`;
  the target's branch name (from `rev-parse --symbolic-full-name`, with `refs/heads/` or
  `refs/remotes/<any>/` stripped, and from the raw string with `<remote>/` stripped) must not equal `<b>`.
- **Survey**. If neither `--no-fetch` nor `--dry-run` is set, run `fetch --prune <remote>`. On failure, record the reason; the
  remote copy is then left. If `--dry-run` is not set, run `worktree prune`. Re-resolve the target SHA. Read the local
  SHA from `refs/heads/<b>` and the remote SHA from `refs/remotes/<remote>/<b>`, and check each with
  `merge-base --is-ancestor <sha> <target_sha>` (exit 0 means merged, 1 means not merged, anything else means "could not prove
  merged: <line>"). Parse `worktree list --porcelain -z` into `Worktree(path, branch, is_main, locked,
  prunable)`. The first entry is the main checkout. Entries marked `prunable` are ignored, since a real run has
  already pruned them. For each linked worktree that holds the branch and is neither main nor locked, run
  `status --porcelain` (ignored files don't count).
- **Plan** (pure; returns new tuples and never mutates its input):
  - If the local copy exists and isn't merged, nothing is deleted. Every holding worktree, `local:<b>` and
    `<remote>:<b>` go into `left` with "not merged into <target>". The exception is a merged remote copy while the local copy is
    unmerged: that copy is also left, with "kept with unmerged local:<b>".
  - Otherwise, holding worktrees are handled like this: the main checkout goes into `left` ("main checkout is never removed or switched");
    a locked one goes into `left` ("locked: <reason>", never unlocked); a dirty one goes into `left` ("uncommitted changes, never
    forced"); every other one is removed. The local branch is deleted only if every holding worktree is removed.
    Otherwise it is left with "checked out in the main checkout" or "checked out in worktree <path>".
  - Remote copy: it is deleted if it exists, is an ancestor, and the fetch didn't fail. If the local copy is merged but the remote one isn't,
    the reason is "<remote> has commits not in <target>". If there is no local copy, the reason is "not merged into <target>".
- **Execute**. All mutating calls run as `git -C <main checkout path>`. First, `worktree remove <path>` for each
  removable worktree. A failure moves it to `left` with git's first stderr line, and the local branch is then left too.
  Next, `update-ref -d refs/heads/<b> <local_sha>` (compare-and-swap) followed by `config --remove-section
  branch.<b>`. The second call is best-effort: its failure is ignored and not reported. Last,
  `push <remote> --delete --force-with-lease=refs/heads/<b>:<remote_sha> refs/heads/<b>`. A lease mismatch is
  rejected (`(stale info)`, verified on a scratch repo), and the copy goes into `left` with that line.
- The script never runs `checkout`, `switch`, `reset`, `stash`, `merge`, `rebase`, `pull`, `branch -D`, `worktree unlock`, or
  `worktree remove --force`/`-f`.

### repo-merge-policy.py — design

- `parse_args`: usage errors exit 2 with `{"error": …}`. That covers `--repo` failing `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`,
  an owner or name of `.` or `..`, and a `--repo-path` that isn't a directory.
- `run_gh(args, cwd)` → `GhResult(code, out, err)`. It uses an argv list, `env={**os.environ,
  "GH_PROMPT_DISABLED": "1", "GH_NO_UPDATE_NOTIFIER": "1"}` and `GH_TIMEOUT_S=60`, and never raises.
- `first_error_line(err)`: returns the first non-empty line, with `gh[pousr]_…`/`github_pat_…` tokens, `Authorization: …`
  and `token|bearer <x>` replaced by `[redacted]`.
- Flow: if `shutil.which("gh")` finds nothing, the result is skipped ("gh CLI not found on PATH"). If `gh auth status` exits non-zero, it is skipped
  ("gh is not authenticated"); that command's output is never echoed. The repo name comes from `--repo` or `gh repo view --json nameWithOwner -q
  .nameWithOwner` (cwd=`--repo-path`). A non-zero exit is skipped ("no GitHub repository at <path>: <line>"), and output
  that fails the regex is skipped ("gh repo view returned no valid nameWithOwner"). Then `gh api repos/O/N`.
  A non-zero exit is skipped. JSON that is invalid, not an object, or missing a boolean field is skipped ("unexpected gh api
  response: <field>"). The pure `plan_changes(current)` yields `{field: {old, new}}` in the order
  `allow_squash_merge`, `delete_branch_on_merge`, `allow_merge_commit` (the last one only when it is false).
  `allow_rebase_merge` is never touched. Status order: no changes → `already-set`. `permissions.admin` false →
  `skipped` ("missing admin rights on O/N"). `--dry-run` → `dry-run`. Otherwise there is **one** `gh api -X
  PATCH repos/O/N -F <field>=<true|false> …` carrying only the changed fields. A non-zero exit → `failed` (first
  line). Then a read-back GET. A mismatch → `failed` ("read-back still shows <field>=<old>"); a match → `changed`.
- Exit 0 in every non-usage case. `main()` turns `ValueError`/`KeyError`/`TypeError` from gh output into a
  `skipped` result, so a traceback never reaches the caller.

## 3. Test plan (written first; every test RED before the code)

Fixtures (conftest.py): `isolated_git_env` (`GIT_CONFIG_GLOBAL` = tmp file with user, `init.defaultBranch=trunk`,
`commit.gpgsign=false`; `GIT_CONFIG_NOSYSTEM=1`; `HOME`=tmp). `git_world` gives a bare `origin.git`, clone `clone/`,
the default branch `trunk` pushed, `git remote set-head origin --auto`, and `feat/r` pushed. It provides helpers `worktree(name, branch)`,
`merge_no_ff(src, into)`, `refs(path)` (for-each-ref snapshot) and `worktrees()`. `run_cleanup(*args)` runs the script
with `sys.executable`, puts a `git` shim (absolute `sys.executable` shebang, logs argv JSON lines, then
`os.execv` real git) first on `PATH`, and after **every** run asserts that each logged call is `git -C <path> …` and
that no subcommand in {checkout, switch, reset, stash, merge, rebase, pull} appears (AC 12, across every
integration test). `fake_gh(fixture)` writes a fake `gh` (logs argv+cwd, keeps the repo state in a JSON file, and lets a PATCH
mutate that state unless `patch_applies: false`). Its `PATH` holds only the fake's directory, and it asserts
`shutil.which("gh", path=PATH)` is the fake (it fails otherwise). Paths are compared after `Path.resolve()` (macOS `/var` → `/private/var`).

| AC | Test (file :: name) | Type |
| --- | --- | --- |
| 1 | `test_merged_branch_cleanup.py::test_merged_branch_in_two_worktrees_removes_both_and_deletes_local_and_origin` | integration |
| 2 | `…::test_dirty_worktree_is_left_byte_identical_and_never_forced` (modified tracked + untracked file, bytes compared; clean worktree removed; local `why` names the dirty path; origin deleted; the shim shows no `--force`/`-f`/`-ff` on `worktree remove`/`branch`) | integration |
| 3 | `…::test_locked_worktree_is_left_locked_with_lock_reason` (`worktree list` still shows `locked`) | integration |
| 4 | `…::test_unmerged_branch_deletes_nothing` | integration |
| 5 | `…::test_origin_ahead_of_target_keeps_origin_copy_only` | integration |
| 5 (CAS) | `…::test_origin_copy_moved_after_check_is_not_deleted` (`--no-fetch`, stale tracking ref, the lease rejects the delete) | integration |
| 6 | `…::test_main_checkout_is_never_removed_or_switched` (main `branch --show-current` unchanged) | integration |
| 7 | `…::test_remote_only_branch_deletes_origin_copy` | integration |
| 8 | `…::test_stale_worktree_entry_is_pruned_before_scan` | integration |
| 9 | `…::test_dry_run_lists_plan_and_changes_no_refs_or_worktrees` (snapshots of the clone refs, origin refs and `worktree list --porcelain`) | integration |
| 10 | `…::test_fetches_with_prune_by_default`, `…::test_no_fetch_runs_no_fetch` | integration |
| 11 | `…::test_refuses_protected_branch_names[main,master,dev,develop,prod,production,release,staging,Main,DEV]`, `…::test_refuses_remote_default_branch`, `…::test_refuses_branch_equal_to_target_branch[origin/feat/r,refs/remotes/origin/feat/r,feat/r]`, `…::test_refuses_invalid_branch_names[-rf,--all,a..b,a b,@{-1},refs/heads/x,""]`, `…::test_refuses_unresolvable_target`, `…::test_refuses_repo_that_is_not_a_git_work_tree`, `…::test_missing_required_args_exit_2_with_json_error[no-repo,no-branch,no-target,unknown-flag]`, `…::test_refuses_unconfigured_remote`. Every refusal goes through `assert_refused()`: exit 2, stdout `{"error": str}`, and shim log subcommands ⊂ {rev-parse, check-ref-format, symbolic-ref, remote}. | unit |
| 12 | `…::test_subprocess_calls_are_argument_lists_without_shell` (AST: every `subprocess.run` has a list/tuple/starred argv and no truthy `shell`; no `os.system`/`os.popen`), `…::test_every_git_call_is_dash_c_and_never_switches_branches` (AC 1 scenario, explicit log assertions; the same check also runs inside `run_cleanup`) | unit |
| 12 (support) | `…::test_parse_worktree_porcelain_reads_locked_prunable_detached_entries`, `…::test_plan_keeps_local_branch_while_any_worktree_holds_it` (pure functions via `load_script`) | unit |
| 13 | `test_repo_merge_policy.py::test_changes_needed_sends_one_typed_patch_and_confirms` | integration |
| 14 | `…::test_already_compliant_sends_no_patch` | integration |
| 15 | `…::test_merge_commits_turned_on_in_same_patch_rebase_never_sent` | integration |
| 16 | `…::test_no_admin_rights_skips_without_patch` | integration |
| 17 | `…::test_gh_missing_from_path_skips`, `…::test_gh_not_authenticated_skips`, `…::test_no_github_remote_skips`, `…::test_skip_reasons_are_distinct` | integration |
| 18 | `…::test_rejected_patch_fails_with_first_error_line[403,422]`, `…::test_read_back_with_old_values_fails`, `…::test_failure_reason_never_contains_token_or_auth_header` | integration |
| 19 | `…::test_dry_run_plans_changes_without_patch` | unit |
| 20 | `…::test_malformed_repo_argument_exits_2[noslash,a/b/c,a/b;x,a b/c,../..,""]`, `…::test_repo_name_comes_from_gh_repo_view_in_repo_path` (fake logs cwd), `…::test_invalid_repo_view_output_skips[empty,null,42,two words]`, `…::test_invalid_api_json_skips_without_traceback[not-json,list,no-permissions,admin-str,field-missing]` (stderr has no `Traceback`) | unit |
| 21 | `test_helper_script_quality.py::test_script_is_executable_with_env_python3_shebang`, `::test_script_imports_stdlib_only` (AST ⊂ `sys.stdlib_module_names`), `::test_script_under_400_lines`, `::test_module_docstring_states_purpose_contract_and_safety`, `::test_functions_under_50_lines`, `::test_no_global_statements_or_mutable_module_constants` (each parametrized over both scripts) + the ruff and full-suite gates below | unit |

Totals: 46 test functions (24 cleanup, 16 policy, 6 quality), about 85 cases once parametrized. No browser, API or MCP surface,
so there are no Playwright tests.

## 4. Data

None. There are no models, migrations or RLS, and no Supabase.

## 5. Config / env / deploy_pending

- The scripts read no new env vars. They set `GIT_TERMINAL_PROMPT`, `GH_PROMPT_DISABLED` and `GH_NO_UPDATE_NOTIFIER` on child-process
  env copies only. The tests use `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, `HOME`, `PATH`, `GIT_SHIM_LOG`,
  `FAKE_GH_FIXTURE`, `FAKE_GH_STATE` and `FAKE_GH_LOG`, all on per-test tmp values.
- deploy_pending: **none** (`vercel: []`, `supabase_migrations: []`).

## 6. Risks and gates

- **The guard sees only the outer command line.** The script's own refusals (protected names, casefold, `refs/`,
  default branch, target branch, `@{-N}`) are what stop it from deleting a protected branch. They are
  covered by the AC 11 tests. The push uses the full `refs/heads/<b>` so it can't match a different ref.
- **`--force-with-lease` reads like a force.** On a delete it is a compare-and-swap that only narrows what gets deleted. AC 2's
  no-force rule covers the `worktree remove` and `branch` calls, and the script makes no `branch` call at all.
- **The caller's cwd is inside a removed worktree.** The shell's cwd goes stale, but no data is lost. The skill-text story should run
  the cleaner from the main checkout. That is noted here and is not this story's file.
- **Ignored files** (e.g. `node_modules`, `.venv`) are deleted with a clean worktree, as `git worktree remove` already does.
- **Case-insensitive macOS refs**: `Main` resolves to `main` there, so protected names are casefolded.
- **User git config leaking into fixtures** (hooks, gpgsign, defaultBranch) is handled by the isolated env above. Clones of an empty
  bare repo get no `origin/HEAD`, so the fixture runs `remote set-head --auto`.
- **Three planners in one worktree.** No other story creates `conftest.py` (checked all three story.md files).

Gates:
```
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
test -x Skills/dev-bother-me-nope/assets/bin/merged-branch-cleanup.py && test -x Skills/dev-bother-me-nope/assets/bin/repo-merge-policy.py
wc -l Skills/dev-bother-me-nope/assets/bin/*.py   # each new script < 400
```
(No `.sh` changes, so shellcheck is not needed.)

## Assumptions

1. The skills `python-library-quality:keeping-git-repos-clean` and `…:guarding-destructive-operations` were not
   available in this session (Skill tool: "Unknown skill"). The plan follows the rules story.md restates.
2. `--dry-run` runs neither `fetch` nor `worktree prune`, because both mutate refs or admin files and AC 9 requires everything identical.
   It reports from the current local view and ignores `prunable` entries.
3. The local copy is deleted with `update-ref -d refs/heads/<b> <sha>` plus `config --remove-section branch.<b>`, not
   `git branch -d/-D`. `-d` checks HEAD or the upstream rather than `--target`, and `-D` is a force delete. The CAS keeps a branch that moved after the check.
4. The remote copy is deleted with `push <remote> --delete --force-with-lease=refs/heads/<b>:<sha> refs/heads/<b>`. A scratch-repo probe
   confirmed that a mismatched lease rejects the delete.
5. A failed fetch leaves the remote copy (with the reason). The local and worktree cleanup still runs against the local target.
6. An unconfigured `--remote` is a refusal (exit 2), and so is a `--target` that stops resolving after the fetch. In the second case the fetch is
   the only thing that has run.
7. Branch names starting with `refs/` are refused, as are names that `check-ref-format --branch` rewrites (`@{-N}`).
   Protected names are matched casefolded.
8. When the local copy is unmerged, its worktrees are also listed in `left`, and so is a main checkout holding the branch (it is
   the reason the branch stays).
9. Ignored files don't count as uncommitted changes. This matches `git worktree remove`'s own rule.
10. Mutating git calls run as `git -C <main checkout>`, so `--repo` may itself be a worktree that gets removed.
11. repo-merge-policy: `already-set` takes precedence over `skipped` (no admin) and over `dry-run` when nothing needs changing. A failed first
    GET is `skipped` (failed is for PATCH or read-back). The PATCH sends only the fields that change. An owner or name of `.`/`..` is a usage
    error even though the regex matches it (`repos/../..` would hit another API path). A missing `--repo-path` is a usage error.
    Usage errors print `{"error": …}` like the cleanup script.
12. The deploy guard (installed 1.5.0) blocked a planning probe's `git push origin main` in a scratch repo. That path was
    dropped. The probe was re-run with a `trunk` default branch, and all test fixtures use `trunk` and never push a
    protected name.
13. `conftest.py` and the pytest markers `unit` and `integration` (registered in `pytest_configure`) belong to this story.
14. Plans are not committed by this planner. The orchestrator commits all three together (run context).
