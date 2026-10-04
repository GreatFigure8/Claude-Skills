# Validation — merged-branch-cleanup-and-repo-merge-policy-scripts

## TEST1 (unit/integration, after BUILD) — base `origin/dev` 4d26d44

Surface: unit/integration (no browser/api/mcp surface in this run).

Commands:
- `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/bin --cov-report=term-missing` — **338 passed** (Python 3.13.13).
- `uv run --quiet --python /usr/bin/python3 --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q` — **336 passed, 2 failed** (Python 3.9.6), `evidence/py39-failures.log`.
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` — All checks passed.
- End-to-end smoke in a tmp dir (`evidence/integration-smoke.log`, 13 of 13 checks pass): bare origin + clone, `feat/run` with a clean worktree, merged `--no-ff` into dev and pushed, `feat/tmp` (also merged) in a dirty worktree, `feat/unmerged` with a pushed origin copy. `merged-branch-cleanup.py --repo <clone> --branch B --target origin/dev`:
  - `--dry-run`: exit 0, JSON `dry_run: true`, plan lists clean worktree + local + origin, nothing changed.
  - `feat/unmerged`: exit 0, `deleted: []`, worktree/local/origin each in `left` with "not merged into origin/dev"; all three still exist.
  - `feat/run`: clean worktree removed, local branch deleted, origin copy deleted, `left: []`.
  - `feat/tmp`: dirty worktree left ("uncommitted changes ... never forced", file intact), local branch left ("checked out in worktree ..."), merged origin copy deleted (matches the contract: origin deleted once it is an ancestor of `origin/dev`).
  - `--branch dev`: exit 2, `{"error": "branch 'dev' is protected ..."}`.

Coverage (`evidence/coverage.txt`; the plain `--cov` run shows 0-38% because the tests execute the scripts as subprocesses, so subprocess coverage was injected): `merged-branch-cleanup.py` 94% (250 stmts, 14 missed), `repo-merge-policy.py` 94% (188 stmts, 11 missed), target 80%.

| AC | Test | Result |
| --- | --- | --- |
| 1 merged branch in two worktrees | `test_merged_branch_in_two_worktrees_removes_both_and_deletes_local_and_origin`, `test_deleting_local_branch_drops_its_config_section` | PASS |
| 2 dirty worktree never forced | `test_dirty_worktree_is_left_byte_identical_and_never_forced`; smoke | PASS |
| 3 locked worktree | `test_locked_worktree_is_left_locked_with_lock_reason` | PASS |
| 4 unmerged branch | `test_unmerged_branch_deletes_nothing`; smoke | PASS |
| 5 origin ahead of target | `test_origin_ahead_of_target_keeps_origin_copy_only`, `test_origin_copy_moved_after_check_is_not_deleted` | PASS |
| 6 main checkout | `test_main_checkout_is_never_removed_or_switched` | PASS |
| 7 remote-only branch | `test_remote_only_branch_deletes_origin_copy` | PASS |
| 8 stale worktree pruned | `test_stale_worktree_entry_is_pruned_before_scan` | PASS |
| 9 dry run | `test_dry_run_lists_plan_and_changes_no_refs_or_worktrees`; smoke | PASS |
| 10 fetch / --no-fetch | `test_fetches_with_prune_by_default`, `test_no_fetch_runs_no_fetch` | PASS |
| 11 refusals | `test_refuses_*` (protected names, remote default, target branch, invalid names, unresolvable target, non-work-tree, unconfigured remote), `test_missing_required_args_exit_2_with_json_error`; smoke (dev refused) | PASS |
| 12 safe execution | `test_subprocess_calls_are_argument_lists_without_shell`, `test_every_git_call_is_dash_c_and_never_switches_branches`, `test_plan_keeps_local_branch_while_any_worktree_holds_it`, `test_parse_worktree_porcelain_reads_locked_prunable_detached_entries` | PASS |
| 13 changes needed: one typed PATCH + read-back | `test_changes_needed_sends_one_typed_patch_and_confirms` | PASS |
| 14 already compliant | `test_already_compliant_sends_no_patch`, `test_already_compliant_takes_precedence_over_missing_admin` | PASS |
| 15 merge commits kept possible | `test_merge_commits_turned_on_in_same_patch_rebase_never_sent` | PASS |
| 16 no admin rights | `test_no_admin_rights_skips_without_patch` | PASS |
| 17 no usable gh | `test_gh_missing_from_path_skips`, `test_gh_not_authenticated_skips`, `test_no_github_remote_skips`, `test_skip_reasons_are_distinct` | PASS |
| 18 rejected / not applied | `test_rejected_patch_fails_with_first_error_line`, `test_read_back_with_old_values_fails`, `test_failure_reason_never_contains_token_or_auth_header` | PASS |
| 19 policy dry run | `test_dry_run_plans_changes_without_patch` | PASS |
| 20 repo resolution + validation | `test_malformed_repo_argument_exits_2`, `test_repo_path_that_is_not_a_directory_exits_2`, `test_repo_name_comes_from_gh_repo_view_in_repo_path`, `test_invalid_repo_view_output_skips`, `test_invalid_api_json_skips_without_traceback`, `test_failed_first_read_is_skipped_not_failed` | PASS |
| 21 quality gates | ruff clean; files 393 and 298 lines (<400); executable + env-python3 shebang, docstring, functions <50 lines, no mutable module state, no shell=True all pass on 3.13 and 3.9; **`test_script_imports_stdlib_only` fails on Python 3.9** | **FAIL (3.9 only)** |

Result: 20 PASS, 1 FAIL.

### Failure — AC21 stdlib-only test is not 3.9 compatible

- Tests: `test_helper_script_quality.py::test_script_imports_stdlib_only[merged-branch-cleanup.py]` and `[repo-merge-policy.py]`.
- Error: `AttributeError: module 'sys' has no attribute 'stdlib_module_names'` (that attribute exists from Python 3.10; `/usr/bin/python3` is 3.9.6).
- Repro: `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_helper_script_quality.py -q -k stdlib_only`.
- Cause: a defect in the test, not the scripts. Both scripts import only stdlib modules (`argparse json os re shutil subprocess sys dataclasses collections __future__`) and every behaviour test of them passes on 3.9. The plugin's hook and helper scripts are run with the system `python3` (3.9.6), so the quality suite should also be runnable there. Fix: guard the check with `getattr(sys, "stdlib_module_names", None)` and fall back to an explicit allowlist of the stdlib modules the scripts import.

## Assumptions

- The smoke's "origin copy kept" expectation for the dirty-worktree case was first written too strictly; the story and stack contract delete the origin copy once it is an ancestor of `origin/dev`, independent of the local worktree, so the smoke asserts that.
