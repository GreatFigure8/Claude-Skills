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
