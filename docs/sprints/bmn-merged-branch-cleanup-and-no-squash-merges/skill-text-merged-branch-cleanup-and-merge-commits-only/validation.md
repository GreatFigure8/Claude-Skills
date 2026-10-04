# Validation — skill-text-merged-branch-cleanup-and-merge-commits-only

## TEST1 (unit/integration, after BUILD) — base `origin/dev` 4d26d44

Surface: unit (no browser/api/mcp surface in this run).

Commands:
- `uv run --quiet --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q --cov=Skills/dev-bother-me-nope/assets/bin --cov-report=term-missing` — **338 passed** (Python 3.13.13).
- `uv run --quiet --python /usr/bin/python3 --with pytest --with pytest-cov python -m pytest Skills/dev-bother-me-nope/assets/tests -q` — **336 passed, 2 failed** (Python 3.9.6). Neither failure is in this story's tests; see `merged-branch-cleanup-and-repo-merge-policy-scripts/validation.md` (test_script_imports_stdlib_only uses `sys.stdlib_module_names`, new in 3.10).
- `uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope` — All checks passed.

Evidence: `evidence/coverage.txt`. Coverage: this story changes Markdown and `plugin.json` only, so there are no Python statements to measure. Its tests (`test_skill_text_rules.py`) assert section headings and strings, and they pass under 3.13 and 3.9.

| AC | Test (`test_skill_text_rules.py`) | Result |
| --- | --- | --- |
| 1 plugin.json 1.6.0 + description | `test_plugin_json_is_version_1_6_0`, `test_plugin_description_names_merge_commits_and_branch_cleanup` | PASS |
| 2 never-squash section | `test_skill_has_never_squash_section_with_forbidden_forms`, `test_never_squash_section_sits_right_after_merging_never_builds`, `test_never_squash_section_says_guard_blocks_while_run_active` | PASS |
| 3 PR rule in SKILL.md + merger brief | `test_pr_merge_form_in_skill_and_merger_brief`, `test_skill_explains_repo_form_keeps_local_checkouts` | PASS |
| 4 Branches and worktrees | `test_branches_section_names_cleanup_script_and_every_worktree`, `test_branches_table_deleted_column_timing`, `test_cleanup_scope_sentence_covers_every_worktree`, `test_force_only_appears_in_never_sentences_in_branches_section` | PASS |
| 5 Cleanup is a step | `test_cleanup_is_a_step_runs_script_and_records_json`, `test_cleanup_is_a_step_drops_hand_written_delete_sequence` | PASS |
| 6 integrator brief | `test_integrator_brief_runs_cleanup_script_per_merged_branch`, `test_integrator_brief_keeps_harness_rule_and_return_shape` | PASS |
| 7 cleaner brief + CLEANUP + sweep | `test_cleaner_brief_uses_script_with_both_targets`, `test_cleaner_brief_record_step_unchanged`, `test_skill_cleanup_step_and_leftover_sweep_name_script_and_targets` | PASS |
| 8 merger brief | `test_merger_brief_merges_no_ff_and_never_squashes`, `test_merger_brief_leaves_run_branch_to_cleanup`, `test_common_preamble_states_merge_rule` | PASS |
| 9 INTAKE repo policy | `test_intake_runs_repo_merge_policy_once`, `test_intake_records_policy_as_assumption_never_blocker`, `test_bmn_json_schema_has_repo_policy_key`, `test_intake_names_enforced_settings_and_standing_instruction` | PASS |
| 10 report template | `test_report_template_has_repo_merge_settings`, `test_report_git_cleanup_lists_worktrees_per_branch_and_left_reasons` | PASS |
| 11 move-computers | `test_move_computers_drops_stale_wip_sentence`, `test_move_computers_says_merged_wip_branches_already_deleted` | PASS |
| 12 bmn-worker.md | `test_worker_agent_has_merge_commits_only_bullet`, `test_worker_agent_deletion_bullet_covers_every_worktree` | PASS |
| 13 squash only ever forbidden | `test_squash_is_only_ever_forbidden[...]` (one case per owned file) | PASS |
| 14 full suite passes; file never runs helper scripts | full suite 338 passed on 3.13 (the story's command), `test_rules_file_never_runs_helper_scripts` | PASS |

Extra: `test_orchestrator_fills_plugin_root_for_workers` PASS.

Result: 14 PASS, 0 FAIL.

## Assumptions

- AC14's "full suite passes" is judged by the story's own command (uv default interpreter, 3.13). The extra 3.9 run requested for the TEST1 brief shows 2 failures in the helper-script story's test file, so those are filed against that story.
