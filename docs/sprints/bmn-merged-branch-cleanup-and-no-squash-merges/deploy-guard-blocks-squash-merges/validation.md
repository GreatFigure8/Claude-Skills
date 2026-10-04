# Validation — deploy-guard-blocks-squash-merges

## TEST1 (unit/integration, after BUILD) — base `origin/dev` 4d26d44

Surface: unit (no browser/api/mcp surface in this run).

Commands:
- `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=...` — **338 passed** (Python 3.13.13).
- same suite under `/usr/bin/python3` 3.9.6 — **336 passed, 2 failed**. The guard (`deploy-guard.py`) runs and every guard test passes under 3.9; the two failures are in `test_helper_script_quality.py` (see the scripts story).
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` — All checks passed.
- Integration smoke (`evidence/integration-smoke.log`): `deploy-guard.py` run under `/usr/bin/python3` with PreToolUse JSON payloads and an active bmn run fixture (`docs/sprints/bmn-demo/bmn.json`, phase build) in a tmp repo:
  - `git merge --squash x` → exit 2, stderr "Blocked by dev-bother-me-nope merge guard: ..." (block)
  - `gh pr merge 5 --squash` → exit 2 (block)
  - `gh pr merge 5 --merge` → exit 2, "without `--delete-branch` leaves the merged source branch" (block)
  - `gh pr merge 5 --merge --delete-branch` → exit 0 (allow)
  - `git merge --squash x` in a repo with no active run → exit 0 (allow)

Coverage (`evidence/coverage.txt`, subprocess coverage): `deploy-guard.py` 94% (416 stmts, 27 missed), target 80%.

| AC | Test (`test_merge_guard.py` unless noted) | Result |
| --- | --- | --- |
| 1 git squash blocked | `test_blocks_git_squash_merges[...]` | PASS |
| 2 gh pr merge squash blocked, value flags parsed | `test_blocks_gh_pr_squash_merges[...]`, `test_allows_pr_merges_that_delete_the_branch_and_other_gh[...]` (incl. `-t "-s fix"`), `test_git_value_flags_are_skipped_not_read_as_options` | PASS |
| 3 PR merge that keeps branch blocked | `test_blocks_pr_merges_that_keep_the_source_branch[...]`, `test_allows_pr_merges_that_delete_the_branch_and_other_gh[...]` | PASS |
| 4 gh api squash blocked | `test_blocks_api_squash_merges[...]`, `test_allows_api_calls_that_do_not_squash[...]` | PASS |
| 5 MCP squash blocked | `test_blocks_mcp_squash_merges[...]`, `test_allows_mcp_merges_that_do_not_squash[...]`, `test_mcp_squash_on_other_tools_is_ignored`; existing MCP tests in `test_deploy_guard.py` unchanged and passing | PASS |
| 6 text and lookalikes allowed | `test_merge_lookalikes_are_allowed[...]` | PASS |
| 7 approval prefix does not unlock | `test_approval_prefix_does_not_unlock_merge_rules[...]`, `test_approval_still_passes_deploys_through_a_shell`, `test_user_approved_prefix_lets_a_deploy_through` | PASS |
| 8 messages | `test_merge_block_message_names_the_allowed_forms[...]`, `test_merge_block_message_for_mcp`, `test_deploy_block_message_is_unchanged` | PASS |
| 9 scope: idle outside an active run | `test_merge_rules_idle_outside_an_active_run[...]`; smoke: no-run repo allows squash | PASS |
| 10 branch cleanup never blocked | `test_branch_cleanup_is_never_blocked[...]`, `test_compare_and_delete_of_a_remote_branch_is_allowed[...]`, `test_push_delete_of_a_protected_branch_stays_blocked`; all 106 pre-existing tests pass | PASS |
| 11 docs | `test_deploy_guards_doc_lists_merge_rules`, `test_guard_docstring_mentions_merge_rules` | PASS |
| 12 gates | ruff clean; `deploy-guard.py` 620 lines (<800); `test_guard_stays_under_800_lines`, `test_every_guard_function_is_under_50_lines`, `test_merge_rule_functions_do_not_mutate`; full suite 338 passed on 3.13 | PASS |

Result: 12 PASS, 0 FAIL.

## FIX① — review ① findings R1-5 and R1-6

Branch `wip/merged-branch-cleanup-and-no-squash-merges/deploy-guard-blocks-squash-merges-fix`, from
`origin/feat/merged-branch-cleanup-and-no-squash-merges` (784f54d). Each item was reproduced first:
57 new tests failed against the unfixed guard (covering both items and the doc), then all pass.

| Id | Result | Test (`test_merge_guard.py`) |
| --- | --- | --- |
| R1-5 | **fixed** | `test_blocks_merges_behind_wrappers_that_take_options[...]` (28 commands: `timeout 60`, `timeout -k 5 60`, `sudo -u me`, `nice -n 5`, `nohup`, `env -u`, `command`, `xargs -n1`, `sh -ec`, `bash -lc`, `bash -o pipefail -c`, nested), `test_blocks_deploys_behind_wrappers_that_take_options[...]` (`timeout 60 git push origin main`, `sudo -u me vercel --prod`, ...), `test_allows_wrapped_commands_that_are_not_blocked_unwrapped[...]`, `test_approval_prefix_does_not_unlock_wrapped_merges[...]`, `test_approval_still_passes_wrapped_deploys[...]`, `test_doc_names_the_unwrapped_wrappers`, `test_doc_blind_spots_no_longer_claim_covered_shell_wrappers` |
| R1-6 (owner run) | **fixed** | `test_blocks_deleting_protected_branches_on_origin[...]` (20 forms: `--delete dev/develop/staging`, `:dev`, `+:dev`, `refs/heads/dev`, `-d`, `--de`, with `--force-with-lease`, behind wrappers, plus the production names), `test_blocks_deleting_the_default_branch[...]`, `test_allows_deleting_wip_and_run_branches_and_pushing_dev[...]` (wip/run branches, the `--force-with-lease=<ref>:<sha>` compare-and-delete, `git push origin dev`), `test_default_branch_rule_leaves_other_pushes_alone[...]`, `test_a_repo_without_a_default_branch_ref_still_guards_the_named_ones`, `test_protected_delete_message_names_the_branch_spec`, `test_doc_lists_the_protected_branch_deletes` |

What changed in `assets/bin/deploy-guard.py`:
- `unwrap` now strips a wrapper's own flags **and the values of its value flags** through
  `skip_wrapper_args` (table `WRAPPER_VALUE_FLAGS`; `timeout` also drops its DURATION). `timeout` is a new wrapper.
- `shell_command_string` reads `sh|bash|zsh|dash|ksh|fish` command strings from `-c` anywhere in a flag cluster
  (`-ec`, `-lc`, `-o pipefail -c`), and no longer treats a `-c` after a script name as a command string.
- `check_git` now blocks `git push` that deletes (`--delete`, `--de`, `-d`, `:ref`, `+:ref`) a name in
  `DELETE_PROTECTED` (`PROTECTED_BRANCHES` + `dev`, `develop`, `staging`) or the remote's default branch
  (`refs/remotes/<remote>/HEAD`), case-insensitively. Existing messages are byte-identical
  (`test_deploy_block_message_is_unchanged` passes); the new reason is
  "`git push … <spec>` deletes a protected branch".
- `references/deploy-guards.md`: wrapper and protected-delete rules documented; the "Known blind spots" list drops
  `bash -lc` and now names what stays open (`eval`, `doas`/`ionice`/`stdbuf`/`setsid`/`caffeinate`/`watch`/`script -c`,
  `env -S '<string>'`, value flags of `uv run`/`poetry run`/`pnpm exec`/`npx -y`, local `git branch -D` of a protected branch).

Gates:
- `uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q` — **441 passed** (3.13).
- same suite under `uv run --python /usr/bin/python3` (3.9.6) — 439 passed, 2 failed, both
  `test_helper_script_quality.py::test_script_imports_stdlib_only[...]` (the pre-existing `sys.stdlib_module_names`
  failure, R1-4, another fixer's). Every guard test passes under 3.9.
- `ruff check` on `deploy-guard.py`, `test_merge_guard.py`, `test_deploy_guard.py` — All checks passed.
- `deploy-guard.py` 724 lines (<800), every function <50 lines, merge-rule functions (incl. the new pure helpers) do not mutate.

Assumptions:
- The protected-delete block belongs to the deploy-guard family (it extends `check_git`'s protected-push rule), so it
  shares the deploy pass-through: `BMN_USER_APPROVED_DEPLOY=1` (set only when Jonathan said "deploy") lifts it like a
  push to `main`. The merge rules are untouched by it.
- The default branch is read offline from the local `refs/remotes/<remote>/HEAD` (falling back to `origin`), the same
  source `merged-branch-cleanup.py` uses; a repo without that ref still guards the named protected branches (R1-9
  covers the helper's side of that gap).
- `git branch -D <protected>` locally stays allowed (the brief scopes R1-6 to `git push --delete` / `:ref`); the helper
  refuses protected names itself. Recorded in the doc's blind spots.
- Wrapper value-flag tables are not exhaustive; wrappers outside the list are named as blind spots in the doc.

## TEST2 (unit/integration, after FIX①) — base `origin/dev` 190ff8e

Surface: unit/integration (no browser/api/mcp surface in this run). Branch `wip/merged-branch-cleanup-and-no-squash-merges/tests-unit-2`.

Commands:
- `uv run --quiet --with pytest --with coverage python -m coverage run --rcfile=<scratch> -m pytest Skills/dev-bother-me-nope/assets/tests -q` (`patch = subprocess`, `include = */assets/bin/*.py`): **476 passed** in 107.5 s (Python 3.13.13).
- `uv run --quiet --python /usr/bin/python3 --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q`: **476 passed** in 112.3 s (Python 3.9.6). TEST1's two 3.9 failures are gone.
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope`: All checks passed.
- Integration smoke (`evidence/test2-integration-smoke.txt`, **8 of 8** checks): `deploy-guard.py` run under `/usr/bin/python3` with PreToolUse JSON in a tmp repo with an active run fixture (`docs/sprints/bmn-demo/bmn.json`, phase build):
  - block (exit 2): `git merge --squash x`, `timeout 60 gh pr merge 5 --squash`, `sh -ec 'git merge --squash x'`, `gh pr merge 5 --merge`, `git push origin --delete dev`
  - allow (exit 0): `gh pr merge 5 --merge --delete-branch`, `git push origin --delete wip/x/y`, and `git merge --squash x` in a repo with no active run.

Evidence and coverage: `evidence/test2-coverage.txt`, `evidence/test2-integration-smoke.txt`. `deploy-guard.py` **93%** (476 stmts, 32 missed; 724 lines), target 80%. TEST1 measured 94% of 416 stmts; FIX① added the wrapper and protected-delete code, and the 32 missed lines are defensive branches rather than rules.

| AC | Test (`test_merge_guard.py` unless noted) | TEST2 |
| --- | --- | --- |
| 1 git squash blocked | `test_blocks_git_squash_merges[...]`; smoke `git merge --squash x`, `sh -ec '...'` | PASS |
| 2 gh pr merge squash blocked | `test_blocks_gh_pr_squash_merges[...]`, `test_allows_pr_merges_that_delete_the_branch_and_other_gh[...]`; smoke `timeout 60 gh pr merge 5 --squash` | PASS |
| 3 PR merge that keeps the branch blocked | `test_blocks_pr_merges_that_keep_the_source_branch[...]`; smoke `--merge` blocks, `--merge --delete-branch` allows | PASS |
| 4 gh api squash blocked | `test_blocks_api_squash_merges[...]`, `test_allows_api_calls_that_do_not_squash[...]` | PASS |
| 5 MCP squash blocked | `test_blocks_mcp_squash_merges[...]`, `test_allows_mcp_merges_that_do_not_squash[...]`, `test_mcp_squash_on_other_tools_is_ignored` | PASS |
| 6 text and lookalikes allowed | `test_merge_lookalikes_are_allowed[...]` | PASS |
| 7 approval prefix does not unlock | `test_approval_prefix_does_not_unlock_merge_rules[...]`, `test_approval_prefix_does_not_unlock_wrapped_merges[...]`, `test_approval_still_passes_wrapped_deploys[...]` | PASS |
| 8 messages | `test_merge_block_message_names_the_allowed_forms[...]`, `test_merge_block_message_for_mcp`, `test_deploy_block_message_is_unchanged`, `test_protected_delete_message_names_the_branch_spec` | PASS |
| 9 idle outside an active run | `test_merge_rules_idle_outside_an_active_run[...]`; smoke: no-run repo allows squash | PASS |
| 10 branch cleanup never blocked | `test_branch_cleanup_is_never_blocked[...]`, `test_compare_and_delete_of_a_remote_branch_is_allowed[...]`, `test_allows_deleting_wip_and_run_branches_and_pushing_dev[...]`; smoke `git push origin --delete wip/x/y` allows | PASS |
| 11 docs | `test_deploy_guards_doc_lists_merge_rules`, `test_guard_docstring_mentions_merge_rules`, `test_doc_names_the_unwrapped_wrappers`, `test_doc_lists_the_protected_branch_deletes` | PASS |
| 12 gates | ruff clean; `test_guard_stays_under_800_lines` (724), `test_every_guard_function_is_under_50_lines`, `test_merge_rule_functions_do_not_mutate`; 476 passed on 3.13 and 3.9 | PASS |

FIX① items, re-checked at TEST2:

| Id | Check | TEST2 |
| --- | --- | --- |
| R1-5 wrappers with options | smoke `timeout 60 gh pr merge 5 --squash` and `sh -ec 'git merge --squash x'` block; `test_blocks_merges_behind_wrappers_that_take_options[...]`, `test_blocks_deploys_behind_wrappers_that_take_options[...]` | PASS |
| R1-6 protected branch deletes | smoke `git push origin --delete dev` blocks, `--delete wip/x/y` allows; `test_blocks_deleting_protected_branches_on_origin[...]`, `test_blocks_deleting_the_default_branch[...]` | PASS |

Result: 12 PASS, 0 FAIL (plus R1-5 and R1-6 PASS).

### TEST2 Assumptions

- Coverage comes from the 3.13 run. The 3.9 run is pass/fail only, as in TEST1.
- The smoke `git push origin --delete dev` runs in a tmp repo with no `refs/remotes/origin/HEAD`, so it exercises the named-branch rule (`dev` in `DELETE_PROTECTED`), not the remote-default-branch rule. `test_blocks_deleting_the_default_branch[...]` covers the latter.
