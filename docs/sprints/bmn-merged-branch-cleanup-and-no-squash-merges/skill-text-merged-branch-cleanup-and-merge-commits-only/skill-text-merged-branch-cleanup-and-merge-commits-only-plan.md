# Plan: Skill text: delete every merged branch and its worktrees, merge commits only (1.6.0)

**Story:** `skill-text-merged-branch-cleanup-and-merge-commits-only` · **Run:** `bmn-merged-branch-cleanup-and-no-squash-merges`
**Branch:** `wip/merged-branch-cleanup-and-no-squash-merges/skill-text-merged-branch-cleanup-and-merge-commits-only` off `feat/merged-branch-cleanup-and-no-squash-merges`
**Paths:** `P = Skills/dev-bother-me-nope`, `S = $P/skills/dev-bother-me-nope`

## 1. Approach

Markdown/JSON-only change plus one text-presence pytest file. Strict TDD: write
`test_skill_text_rules.py` first (all red against 1.5.0 text), then edit the six files until it
is green, then run the full suite. Skill guidance applied (the two python-library-quality skills
were not installed in the planner's session either, so their rules are followed as the story
restates them):
- *keeping-git-repos-clean*: a merged branch is deleted with **every** worktree on it, locally
  and on origin, right after its last merge; deletion is proven by `merge-base --is-ancestor`
  inside the one tested helper (`merged-branch-cleanup.py`) instead of prose re-described in
  four places (DRY); history is kept with `--no-ff` merge commits, never squash.
- *guarding-destructive-operations*: never `--force`; dirty/locked worktrees, the main checkout
  and unproven branches are left and recorded with a reason; every delete is reported
  (`deleted`/`left` → `bmn.json.cleanup` → report). The PR form uses `--repo` so `gh` never
  touches a local checkout.

## 2. Files

| # | File | Change |
| - | --- | --- |
| 1 | `$P/assets/tests/test_skill_text_rules.py` | **new** — stdlib-only (re, json, pathlib) text-presence tests for AC1-AC13, plus 2 guard tests (§6). No subprocess, no import/exec of either helper script. |
| 2 | `$P/.claude-plugin/plugin.json` | `version` 1.5.0 → 1.6.0; `description` gains one sentence: "Merges are merge commits only, never squash: every merged branch is deleted with every worktree that has it checked out, locally and on origin, and every PR merge deletes its source branch." |
| 3 | `$S/SKILL.md` | (a) *Branches and worktrees* table *Deleted* column + scope sentence + `--force` never-sentence; (b) *Cleanup is a step* paragraph rewritten to call `${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo … --branch … --target …`; (c) **new** `## Merge commits only — never squash (Jonathan's rule, 2026-10-03)` right after *Merging never builds*; (d) `bmn.json` schema gains `"repo_policy"`; (e) *Leftover sweep* becomes its own paragraph naming the script and targets; (f) *Orchestrator discipline*: `${CLAUDE_PLUGIN_ROOT}` is filled like a placeholder; (g) INTAKE new step 5 (repo-merge-policy), old 5 → 6; (h) step 3 integrator paragraph, step 4 MERGE→dev①, step 7 FIX①, step 10b CLEANUP steps 1-2 call the script. |
| 4 | `$S/references/briefs.md` | Common preamble: one merge-rule bullet. Integrator: per merged branch run the script `--target origin/{integration}`; harness rule kept. Merger: `--no-ff`, never squash, PR form, doesn't delete the run branch. Cleaner: steps 1-2 call the script (`origin/{integration}` / `origin/dev`), `integration_pushed` gate kept, step 3 unchanged. |
| 5 | `$S/references/move-computers.md` | MOVE-IN step 5: replace "their `wip/` branches stay on origin until CLEANUP deletes them" with the already-deleted wording (AC11). |
| 6 | `$S/references/report-template.md` | **new** `## Repo merge settings` section (from `repo_policy`); *Git cleanup* lists deleted refs and removed worktrees per branch (incl. ones bmn didn't create) and every `left` entry with its reason. |
| 7 | `$P/agents/bmn-worker.md` | New bullet: merge commits only + PR form. Deletion bullet extended: removing every worktree with a brief-named merged branch checked out is part of that branch's cleanup. |

Not touched (other stories / out of scope): `deploy-guard.py`, `test_deploy_guard.py`,
`references/deploy-guards.md`, `assets/bin/*.py` helpers, `stack-routing.md`, `hooks/hooks.json`,
marketplace.json, README, pipeline diagram (SKILL.md 15-16) and the "one reviewable PR" sizing
lines (sizing, not merging).

### Exact wording the tests pin (coder keeps these substrings; prose around them is free)

- SKILL.md new section heading: `## Merge commits only — never squash (Jonathan's rule, 2026-10-03)`.
  Body must contain: `--no-ff`, `git merge --squash`, `gh pr merge`, `merge_method=squash`,
  `--delete-branch`, `deploy guard`, `2026-10-03`, `never squash`, `merge commit`, `history`,
  `while a run is active`, the PR form `gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`,
  `deletes only the remote head branch`, `leaves every local checkout alone`,
  `merged-branch-cleanup.py`. Also one sentence (not pinned): gh skips the remote delete for
  `--auto` and cross-repo PRs (cli/cli `pkg/cmd/pr/merge/merge.go` `deleteRemoteBranch`), so bmn
  never uses `--auto`; `delete_branch_on_merge=true` is the backstop. Rebase merges are not
  mentioned beyond "left as they are".
- *Branches and worktrees* table rows: temp row *Deleted* = `as soon as the integrator has merged it — local, origin and every worktree on it`;
  run row *Deleted* = `at CLEANUP, after its last merge to `dev` — not after MERGE→dev①, because FIX① still branches from it`.
  Scope sentence replacing "Cleanup only ever touches those.": `Cleanup only ever touches those refs, plus every worktree that has one of them checked out (from `git worktree list --porcelain`), even one bmn didn't create; the main checkout is never removed or switched.`
  `--force` sentence contains "never" ("…never with `--force`").
- *Cleanup is a step*: `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/merged-branch-cleanup.py --repo <path> --branch <branch> --target <ref>`,
  `deleted`, `left`, `bmn.json.cleanup`, `Git cleanup`; must NOT contain `git branch -D` or
  `git push origin --delete`. Exit 2 (refused) is recorded in `left` with the error as `why`.
- INTAKE step 5 (a `^\d+\. ` item): `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/repo-merge-policy.py --repo-path {run_worktree}`,
  `bmn.json.repo_policy`, `already set` (skip on resume), `skipped`, `failed`, `assumptions`,
  `never` + `blocker`, `allow_squash_merge=false`, `delete_branch_on_merge=true`,
  `standing instruction`, `2026-10-03`.
- Schema JSON block (must still `json.loads`): `"repo_policy": null` placed after `"cleanup"`,
  with the helper's shape described in the INTAKE step.
- Orchestrator discipline: `${CLAUDE_PLUGIN_ROOT}` + `{skill_dir}/../..` + `absolute` in one
  bullet: the orchestrator fills it with the absolute plugin root in every brief and in its own
  Bash calls when the variable is empty.
- *Leftover sweep* paragraph: `merged-branch-cleanup.py`, `--target origin/dev`.
- 10b CLEANUP: `merged-branch-cleanup.py`, `--target origin/{integration}` (temp refs, run first,
  `--repo <main checkout>`), `--target origin/dev` (run branch), `integration_pushed`,
  harness rule `git rev-list` kept.
- briefs.md integrator: `merged-branch-cleanup.py`, `--target origin/{integration}`,
  `--repo {run_worktree}`, `git rev-list <harness> --not --exclude=refs/heads/<harness> --branches --remotes`,
  `deleted[]`, `left[{ref, why}]`.
- briefs.md merger: `git merge --no-ff`, `never squash`, `gh pr merge <n> --merge --delete-branch --repo <owner>/<repo>`,
  `doesn't delete {integration}` + `CLEANUP`. Any `--squash` only in a never-line.
- briefs.md cleaner: `merged-branch-cleanup.py`, `--repo {repo_path}`, `--target origin/{integration}`,
  `--target origin/dev`, `integration_pushed`; step 3 keeps `worktree add --detach`,
  `git.deploymentEnabled`, `phase: blocked`, `chore(bmn): record git cleanup for {run_slug}`.
- briefs.md common preamble bullet: `git merge --no-ff`, `never squash`, `gh pr merge <n> --merge --delete-branch`.
- move-computers.md: no `stay on origin until CLEANUP`; has `already deleted`,
  `when the integrator merged them`, `only unmerged`.
- report-template.md: `## Repo merge settings` with `repo_policy`, `allow_squash_merge`,
  `delete_branch_on_merge`, `→`, `unchanged: {reason}`; *Git cleanup* has `per branch`,
  `worktree`, `didn't create`, `Left`, `why`.
- bmn-worker.md: bullet with `merge commits only`, `--no-ff`, `never squash`,
  `gh pr merge <n> --merge --delete-branch`; deletion bullet with `every worktree` + `checked out`.
- **Every** line containing `squash` in SKILL.md, briefs.md, move-computers.md,
  report-template.md, bmn-worker.md must also carry `never`/`no `/`not`/`block`/`forbidden`
  after `allow_squash_merge` is stripped — wrap lines so the negation sits on the same line.

## 3. Test plan (written first)

File: `Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py` (all **unit**, pytest,
stdlib only). Helpers: `_read(rel)`, `_section(text, heading_substr)` (from the matching `#` line
to the next heading of the same or higher level), `_brief(name)` (briefs.md `## <name>` section),
`_paragraph(text, lead)` (from a bold lead like `**Cleanup is a step` to the next blank line),
`_numbered_item(section, needle)` (the `^\d+\. ` item containing needle), `_has_negation(line)`.

| AC | Test(s) |
| --- | --- |
| 1 | `test_plugin_json_is_version_1_6_0`, `test_plugin_description_names_merge_commits_and_branch_cleanup` |
| 2 | `test_skill_has_never_squash_section_with_forbidden_forms`, `test_never_squash_section_says_guard_blocks_while_run_active` |
| 3 | `test_pr_merge_form_in_skill_and_merger_brief`, `test_skill_explains_repo_form_keeps_local_checkouts` |
| 4 | `test_branches_section_names_cleanup_script_and_every_worktree`, `test_branches_table_deleted_column_timing`, `test_cleanup_scope_sentence_covers_every_worktree`, `test_force_only_appears_in_never_sentences_in_branches_section` |
| 5 | `test_cleanup_is_a_step_runs_script_and_records_json`, `test_cleanup_is_a_step_drops_hand_written_delete_sequence` |
| 6 | `test_integrator_brief_runs_cleanup_script_per_merged_branch`, `test_integrator_brief_keeps_harness_rule_and_return_shape` |
| 7 | `test_cleaner_brief_uses_script_with_both_targets`, `test_cleaner_brief_record_step_unchanged`, `test_skill_cleanup_step_and_leftover_sweep_name_script_and_targets` |
| 8 | `test_merger_brief_merges_no_ff_and_never_squashes`, `test_merger_brief_leaves_run_branch_to_cleanup` |
| 9 | `test_intake_runs_repo_merge_policy_once`, `test_intake_records_policy_as_assumption_never_blocker`, `test_bmn_json_schema_has_repo_policy_key` (json.loads the schema block), `test_intake_names_enforced_settings_and_standing_instruction` |
| 10 | `test_report_template_has_repo_merge_settings`, `test_report_git_cleanup_lists_worktrees_per_branch_and_left_reasons` |
| 11 | `test_move_computers_drops_stale_wip_sentence`, `test_move_computers_says_merged_wip_branches_already_deleted` |
| 12 | `test_worker_agent_has_merge_commits_only_bullet`, `test_worker_agent_deletion_bullet_covers_every_worktree` |
| 13 | `test_squash_is_only_ever_forbidden` (parametrized over the 5 owned Markdown files) |
| 14 | `test_rules_file_never_runs_helper_scripts` (own source has no `subprocess`, `runpy`, `importlib`, `exec(`) + gate: full suite green |
| extra | `test_common_preamble_states_merge_rule` (briefs.md preamble), `test_orchestrator_fills_plugin_root_for_workers` (risk 1) |

Totals: **33 test functions** (37 collected cases with the 5-file parametrization), 1 new file.
No browser, API or MCP surface: no Playwright tests.

## 4. Data

None. No models, no migrations, no RLS. `bmn.json` gains an optional `repo_policy` key
(helper JSON verbatim; missing = "not run yet", only acted on at INTAKE).

## 5. Config / env and deploy_pending

- Env (names only, read, not new): `CLAUDE_PLUGIN_ROOT`.
- No new config files. `plugin.json` version → 1.6.0.
- `deploy_pending`: **none** (`vercel: []`, `supabase_migrations: []`). Plugin users pick up
  1.6.0 through the local marketplace update once it lands on `dev`/`main` (Jonathan's call).

## 6. Risks and gates

1. **`${CLAUDE_PLUGIN_ROOT}` is unset in a worker's Bash** (verified: empty in this bmn-worker
   on 2026-10-03). A brief that says `python3 ${CLAUDE_PLUGIN_ROOT}/assets/bin/…` would run
   `/assets/bin/…`. Mitigation: SKILL.md *Orchestrator discipline* says the orchestrator fills
   `${CLAUDE_PLUGIN_ROOT}` in every brief (and its own calls when empty) with the absolute plugin
   root, `{skill_dir}/../..` resolved. Tested by `test_orchestrator_fills_plugin_root_for_workers`.
2. **AC13 line wrapping**: a reflowed paragraph can push `squash` onto a line without its
   negation. The coder runs the AC13 test after each file edit.
3. **gh behaviour** verified against cli/cli source with `gh search code` / `gh api`:
   `opts.CanDeleteLocalBranch = !cmd.Flags().Changed("repo")` (local delete skipped with
   `--repo`); remote delete runs unless `crossRepoPR` or `autoMerge`. Text states both.
4. **CLEANUP removing the run worktree**: the script is run with `--repo {repo_path}` (main
   checkout, read-only for files/branches) so it never removes the worktree it runs from; the
   record step keeps using the detached `{dev_worktree}`. Temp refs are cleaned before the run
   branch, while `origin/{integration}` still resolves (the script exits 2 on an unresolvable
   target; that is recorded in `left`).
5. **Parallel stories**: text cites the fixed CLI contracts verbatim; tests never execute the
   scripts, so merge order of the three stories doesn't matter. `deploy-guards.md` is linked,
   not edited.
6. **Live plugin**: the checkout is loaded live by the local marketplace; nothing reaches other
   repos until the run merges to `dev` and Jonathan updates the plugin.
7. Existing 106 guard tests must stay green (no shared fixtures touched).

Gates (from the run worktree root):
```bash
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests/test_skill_text_rules.py -q   # red first, then green
uv run --quiet --with pytest python -m pytest Skills/dev-bother-me-nope/assets/tests -q                            # full suite
uv run --quiet --with ruff ruff check Skills/dev-bother-me-nope
python3 -c "import json; json.load(open('Skills/dev-bother-me-nope/.claude-plugin/plugin.json'))"
```

## Assumptions

1. The python-library-quality skills (`keeping-git-repos-clean`,
   `guarding-destructive-operations`) are not installed in this session (Skill tool: unknown
   skill); the plan follows the rules the story restates.
2. Research-and-reuse: no PyPI package is added for Markdown parsing (e.g. markdown-it-py). The
   gate runs `uv run --with pytest` only, and heading/paragraph slicing with `re` is ~20 lines.
3. `${CLAUDE_PLUGIN_ROOT}` stays the spelling in all text (fixed contract, same as
   dev-story-flow); the orchestrator substitutes it when filling briefs (risk 1).
4. Integrator runs the script with `--repo {run_worktree}`; cleaner with `--repo {repo_path}`.
   Each call fetches by default; no `--no-fetch` (simpler, one fetch per branch is cheap).
5. If `integration_pushed` is false and `origin/{integration}` exists anyway, the cleaner skips
   the script for the run branch and records "origin copy not pushed by this run" (keeps
   today's gate; the script has no local-only switch).
6. Harness branches: the script runs first (ancestry); when it leaves one as not merged, the
   existing "no commits unique to it" rule decides, deleting with `git branch -D` (worktree
   already removed by the wip branch's cleanup). That prose stays in the integrator and
   cleaner briefs only.
7. A common-preamble bullet and the plugin-root bullet go beyond the ACs; both are one line
   and each has a test.
8. The pipeline diagram and "one reviewable PR" sizing lines are left unchanged.
